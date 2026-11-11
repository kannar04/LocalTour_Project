<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\CustomerBookingModel;
use App\Models\EmailLogModel;
use App\Models\PaymentModel;
use DateTimeImmutable;
use RuntimeException;
use Throwable;

/**
 * Email "Đặt tour thành công" gửi cho khách khi đơn vừa chuyển sang "Đã xác nhận" (Nguyễn Tuấn Khôi).
 * Chỉ gọi ngay sau lần chuyển trạng thái thật, không gọi khi kết quả đã được ghi từ trước (vd. VNPay trả 'already'):
 *   - VnpayController: Return URL và IPN (LTP_sp_payment_vnpay_result trả ok + paid + confirmed),
 *   - AdminPaymentController: "Đã nhận tiền" (VietQR) và "Có giao dịch thành công" (VNPay chưa rõ kết quả),
 *   - AdminBookingController: quản trị viên chuyển "Chờ thanh toán" → "Đã xác nhận",
 *   - cổng thanh toán khác (vd. MoMo): BookingMail::sendConfirmed($bookingCode).
 * Không bao giờ ném lỗi và không làm hỏng luồng thanh toán: lỗi chỉ ghi vào email_logs và storage/logs/app.log.
 * Gửi đồng bộ, tối đa 15 giây (SmtpMailer). Mỗi đơn nhận tối đa một email gửi thành công (NTK_sp_email_log_start).
 * MAIL_HOST trống = tắt gửi, nhật ký ghi "skipped". Đơn không còn "Đã xác nhận" thì không gửi, không ghi nhật ký.
 * Dữ liệu trong email đọc bằng procedure của trang "Đơn của tôi" (chi tiết đơn, dòng vé, các khoản thanh toán).
 */
final class BookingMail
{
    public const KIND_CONFIRMED = 'booking_confirmed';

    private const WEEKDAYS = ['Chủ nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

    /** Gửi email "Đặt tour thành công" cho đơn $bookingCode (LTxxxxxx) vừa được xác nhận. Không ném lỗi. */
    public static function sendConfirmed(string $bookingCode): void
    {
        $code = strtoupper(trim($bookingCode));
        if (!preg_match(CustomerBookingModel::CODE_PATTERN, $code)) {
            error_log('LocalTour: email xác nhận: mã đơn không hợp lệ.');
            return;
        }

        self::dispatch(null, $code);
    }

    /** Như sendConfirmed(), theo booking_id (trang quản trị chỉ có mã UUID của đơn). Không ném lỗi. */
    public static function sendConfirmedForBooking(string $bookingId): void
    {
        self::dispatch($bookingId, null);
    }

    /**
     * Dòng tình trạng email xác nhận ở trang chi tiết yêu cầu của quản trị viên: "đã gửi lúc …", "chưa gửi", "lỗi …".
     * null = không hiện (đơn chưa xác nhận và chưa có lượt gửi nào, hoặc database chưa chạy 25_email_NTK.sql).
     */
    public static function adminStatusLine(string $bookingId, string $bookingStatus): ?string
    {
        try {
            $log = (new EmailLogModel())->latest($bookingId, self::KIND_CONFIRMED);
        } catch (Throwable $exception) {
            error_log('LocalTour: không đọc được nhật ký email: ' . $exception->getMessage());
            return null;
        }
        if ($log === null) {
            return in_array($bookingStatus, ['confirmed', 'completed'], true) ? 'chưa gửi' : null;
        }

        $at = format_datetime((string) ($log['finished_at'] ?? $log['created_at']));
        $error = mb_strimwidth((string) $log['error'], 0, 200, '…');

        return match ((string) $log['status']) {
            'sent' => 'đã gửi lúc ' . $at . ' tới ' . $log['to_email'],
            'sending' => 'đang gửi (bắt đầu lúc ' . format_datetime((string) $log['created_at']) . ')',
            'skipped' => 'chưa gửi – ' . $error,
            default => 'lỗi lúc ' . $at . ' – ' . $error,
        };
    }

    private static function dispatch(?string $bookingId, ?string $code): void
    {
        try {
            $logs = new EmailLogModel();
            $booking = $logs->booking($bookingId, $code);
            if ($booking === null) {
                error_log('LocalTour: email xác nhận: không tìm thấy đơn ' . ($code ?? (string) $bookingId) . '.');
                return;
            }
            // VNPay / quản trị viên ghi tiền tới muộn cho đơn đã hủy: đơn không "Đã xác nhận" thì không gửi.
            if ($booking['status'] !== 'confirmed') {
                return;
            }
            $claim = $logs->start((string) $booking['booking_id'], self::KIND_CONFIRMED, trim((string) $booking['contact_email']));
            if ($claim['result'] !== 'ok' || $claim['email_log_id'] === null) {
                // duplicate: khách đã nhận email này; busy: một yêu cầu khác đang gửi.
                return;
            }
        } catch (Throwable $exception) {
            error_log('LocalTour: email xác nhận: không ghi được nhật ký email (database đã chạy 25_email_NTK.sql chưa?): ' . $exception->getMessage());
            return;
        }

        [$status, $error, $messageId] = self::deliver($booking);
        if ($status === 'failed') {
            error_log('LocalTour: gửi email xác nhận đơn ' . $booking['code'] . ' không thành công: ' . $error);
        }

        try {
            $logs->finish($claim['email_log_id'], $status, $error, $messageId);
        } catch (Throwable $exception) {
            error_log('LocalTour: email xác nhận: không ghi được kết quả gửi: ' . $exception->getMessage());
        }
    }

    /**
     * Dựng và gửi email. Trả [trạng thái (sent, failed, skipped), lỗi / lý do, Message-ID].
     *
     * @param array<string, mixed> $target Dòng của NTK_sp_email_booking_get.
     * @return array{0: string, 1: ?string, 2: ?string}
     */
    private static function deliver(array $target): array
    {
        try {
            $config = require BASE_PATH . '/config/mail.php';
            if (!SmtpMailer::enabled($config)) {
                return ['skipped', 'Chưa cấu hình MAIL_HOST trong .env: gửi email đang tắt.', null];
            }
            $to = trim((string) $target['contact_email']);
            if (filter_var($to, FILTER_VALIDATE_EMAIL) === false) {
                return ['failed', 'Email liên hệ của đơn không hợp lệ.', null];
            }

            $mail = self::compose($target);
            $messageId = (new SmtpMailer($config))->send($to, (string) $target['contact_name'], $mail['subject'], $mail['text'], $mail['html']);

            return ['sent', null, $messageId];
        } catch (Throwable $exception) {
            return ['failed', mb_substr($exception->getMessage(), 0, 1000), null];
        }
    }

    /**
     * Nội dung email: tiêu đề, văn bản thuần và HTML.
     *
     * @param array<string, mixed> $target Dòng của NTK_sp_email_booking_get.
     * @return array{subject: string, text: string, html: string}
     */
    private static function compose(array $target): array
    {
        $userId = (string) $target['user_id'];
        $code = (string) $target['code'];
        $bookings = new CustomerBookingModel();
        $booking = $bookings->find($userId, $code) ?? throw new RuntimeException('Không đọc được chi tiết đơn ' . $code . '.');
        $lines = $bookings->lines($userId, $code);

        $paid = null;
        foreach ((new PaymentModel())->list($userId, $code) as $payment) {
            if ($payment['status'] === 'paid') {
                $paid = $payment;
                break;
            }
        }

        $meetingPoint = trim((string) ($booking['meeting_point'] ?? ''));
        $place = departure_text((string) $booking['pickup_mode'], $meetingPoint);
        if ($booking['pickup_mode'] === 'hotel_pickup' && $meetingPoint !== '') {
            $place .= ' – khu vực đón: ' . $meetingPoint;
        }

        $guests = [];
        foreach ($lines as $line) {
            $guests[] = ticket_label((string) $line['ticket_name']) . ' × ' . (int) $line['quantity'];
        }

        $method = '';
        if ($paid !== null) {
            $method = self::methodLabel((string) $paid['method']);
            if ($paid['paid_at'] !== null) {
                $method .= ' · ' . format_datetime((string) $paid['paid_at']);
            }
        }

        $rows = ['Mã đơn' => $code, 'Tour' => (string) $booking['tour_title']];
        if (trim((string) ($booking['package_name'] ?? '')) !== '') {
            $rows['Gói tour'] = (string) $booking['package_name'];
        }
        $rows += [
            'Ngày khởi hành' => self::dateText((string) $booking['starts_at']),
            'Giờ' => schedule_time_text((string) $booking['starts_at'], (string) $booking['ends_at']),
            ($booking['pickup_mode'] === 'hotel_pickup' ? 'Điểm đón' : 'Điểm gặp') => $place,
            'Số khách' => (int) $booking['people'] . ' khách (' . implode(', ', $guests) . ')',
            'Tổng tiền đã thanh toán' => format_vnd($booking['total_vnd']),
            'Phương thức thanh toán' => or_missing($method),
        ];
        if ($booking['voucher_code'] !== null) {
            $rows['Mã voucher'] = (string) $booking['voucher_code'];
        }
        $rows['Đơn vị tổ chức'] = (string) $booking['provider_name'];

        $links = ['Xem đơn của bạn' => self::absoluteUrl('/bookings/' . $code)];
        if ($booking['voucher_code'] !== null) {
            $links['Xem và in voucher'] = self::absoluteUrl('/bookings/' . $code . '/voucher');
        }

        $name = trim((string) $booking['contact_name']);

        return [
            'subject' => 'Đặt tour thành công – ' . $code . ' · ' . mb_strimwidth((string) $booking['tour_title'], 0, 70, '…'),
            'text' => self::text($name, $code, $rows, $links),
            'html' => self::html($name, $code, $rows, $links),
        ];
    }

    /**
     * @param array<string, string> $rows
     * @param array<string, string> $links
     */
    private static function text(string $name, string $code, array $rows, array $links): string
    {
        $out = ['LocalTour – Đặt tour thành công', '', 'Chào ' . ($name !== '' ? $name : 'bạn') . ',', '',
            'LocalTour đã nhận thanh toán và xác nhận đơn ' . $code . '. Chuyến đi của bạn đã sẵn sàng.', ''];
        foreach ($rows as $label => $value) {
            $out[] = $label . ': ' . $value;
        }
        $out[] = '';
        foreach ($links as $label => $link) {
            $out[] = $label . ': ' . $link;
        }
        $out[] = '';
        $out[] = 'Đưa mã voucher cho hướng dẫn viên khi tới điểm hẹn. Có mặt trước giờ khởi hành 15 phút.';
        $out[] = 'Muốn đổi ngày hoặc hủy tour, mở trang đơn và chọn "Đổi ngày / hủy tour".';
        $out[] = '';
        $out[] = '--';
        $out[] = 'Email này được LocalTour gửi tự động vì địa chỉ này là email liên hệ của đơn ' . $code . '. Vui lòng không trả lời email này.';

        return implode("\r\n", $out) . "\r\n";
    }

    /**
     * HTML đơn giản, style viết thẳng trong thẻ (trình đọc email không tải CSS ngoài), màu theo trang web.
     *
     * @param array<string, string> $rows
     * @param array<string, string> $links
     */
    private static function html(string $name, string $code, array $rows, array $links): string
    {
        $font = "font-family:'Be Vietnam Pro',Arial,Helvetica,sans-serif;";
        $rowHtml = '';
        foreach ($rows as $label => $value) {
            $strong = in_array($label, ['Mã đơn', 'Tour', 'Tổng tiền đã thanh toán', 'Mã voucher'], true);
            $rowHtml .= '<tr>'
                . '<td style="' . $font . 'padding:8px 12px 8px 0;border-top:1px solid #e3e5e8;color:#6b7280;font-size:14px;vertical-align:top;white-space:nowrap;">' . e($label) . '</td>'
                . '<td style="' . $font . 'padding:8px 0;border-top:1px solid #e3e5e8;color:#1f2328;font-size:14px;vertical-align:top;' . ($strong ? 'font-weight:bold;' : '') . '">' . e($value) . '</td>'
                . "</tr>\n";
        }

        $buttons = '';
        $primary = true;
        foreach ($links as $label => $link) {
            $style = $primary
                ? 'background:#176b5f;color:#ffffff;border:1px solid #176b5f;'
                : 'background:#ffffff;color:#176b5f;border:1px solid #176b5f;';
            $buttons .= '<a href="' . e($link) . '" style="' . $font . $style . 'display:inline-block;padding:10px 18px;margin:0 8px 8px 0;border-radius:6px;font-size:14px;font-weight:bold;text-decoration:none;">' . e($label) . "</a>\n";
            $primary = false;
        }
        $plainLinks = '';
        foreach ($links as $label => $link) {
            $plainLinks .= e($label) . ': <a href="' . e($link) . '" style="color:#176b5f;">' . e($link) . '</a><br>' . "\n";
        }

        return '<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Đặt tour thành công – ' . e($code) . '</title>
</head>
<body style="margin:0;padding:0;background:#f3f3f3;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f3f3;">
<tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border:1px solid #e3e5e8;border-radius:8px;">
<tr><td style="' . $font . 'background:#176b5f;color:#ffffff;padding:16px 24px;border-radius:8px 8px 0 0;font-size:20px;font-weight:bold;">LocalTour</td></tr>
<tr><td style="' . $font . 'padding:24px;color:#1f2328;">
<p style="margin:0 0 4px;"><span style="' . $font . 'display:inline-block;background:#e3f1ee;color:#176b5f;border-radius:999px;padding:4px 12px;font-size:13px;font-weight:bold;">Đã xác nhận</span></p>
<h1 style="' . $font . 'margin:12px 0 16px;font-size:22px;color:#1f2328;">Đặt tour thành công</h1>
<p style="' . $font . 'margin:0 0 12px;font-size:15px;line-height:1.6;">Chào ' . e($name !== '' ? $name : 'bạn') . ',</p>
<p style="' . $font . 'margin:0 0 20px;font-size:15px;line-height:1.6;">LocalTour đã nhận thanh toán và xác nhận đơn <strong>' . e($code) . '</strong>. Chuyến đi của bạn đã sẵn sàng.</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin:0 0 20px;">
' . $rowHtml . '</table>
<div style="margin:0 0 12px;">
' . $buttons . '</div>
<p style="' . $font . 'margin:0 0 20px;font-size:13px;line-height:1.6;color:#6b7280;">' . $plainLinks . '</p>
<p style="' . $font . 'margin:0 0 8px;padding:12px 14px;background:#f6ead6;color:#7a4a0c;border-radius:6px;font-size:14px;line-height:1.6;">Đưa mã voucher cho hướng dẫn viên khi tới điểm hẹn. Có mặt trước giờ khởi hành 15 phút.</p>
<p style="' . $font . 'margin:12px 0 0;font-size:14px;line-height:1.6;color:#3b4250;">Muốn đổi ngày hoặc hủy tour, mở trang đơn và chọn “Đổi ngày / hủy tour”.</p>
</td></tr>
<tr><td style="' . $font . 'padding:16px 24px;border-top:1px solid #e3e5e8;color:#6b7280;font-size:12px;line-height:1.6;">Email này được LocalTour gửi tự động vì địa chỉ này là email liên hệ của đơn ' . e($code) . '. Vui lòng không trả lời email này.</td></tr>
</table>
</td></tr>
</table>
</body>
</html>
';
    }

    /** "2026-11-14 17:00:00" → "Thứ Bảy, 14/11/2026" */
    private static function dateText(string $startsAt): string
    {
        $date = DateTimeImmutable::createFromFormat('!Y-m-d', substr($startsAt, 0, 10));

        return $date ? self::WEEKDAYS[(int) $date->format('w')] . ', ' . $date->format('d/m/Y') : format_date($startsAt);
    }

    /** Nhãn phương thức; mã chưa có nhãn chung (vd. momo trước khi thêm vào helpers) dùng nhãn riêng. */
    private static function methodLabel(string $method): string
    {
        $label = payment_method_label($method);

        return $label !== $method ? $label : (['momo' => 'Ví MoMo'][$method] ?? strtoupper($method));
    }

    /**
     * Liên kết tuyệt đối: APP_URL nếu có, ngược lại scheme + host + thư mục gốc của request đang chạy (giống Return URL
     * VNPay trong PaymentController), nên đúng cả khi khách quay về từ VNPay lẫn khi VNPay gọi IPN.
     */
    private static function absoluteUrl(string $path): string
    {
        $link = url($path);
        if (preg_match('#^https?://#i', $link)) {
            return $link;
        }
        $host = (string) ($_SERVER['HTTP_HOST'] ?? '');
        if (!preg_match('/^[A-Za-z0-9.\-]+(:\d{1,5})?$/D', $host)) {
            throw new RuntimeException('Không xác định được địa chỉ trang web cho liên kết trong email: đặt APP_URL trong .env.');
        }
        $https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';

        return ($https ? 'https://' : 'http://') . $host . $link;
    }
}
