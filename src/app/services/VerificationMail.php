<?php

declare(strict_types=1);

namespace App\Services;

use Throwable;

/**
 * Email chứa mã xác minh 6 chữ số (xác minh email / đổi email ở trang "Tài khoản") – Nguyễn Tuấn Khôi (NTK).
 * Chức năng thêm, chỉ bật khi đã cấu hình gửi email: cùng điều kiện với email "Đặt tour thành công"
 * (SmtpMailer::enabled(), tức MAIL_HOST trong .env không trống). MAIL_HOST trống thì không có đường dẫn nào của
 * chức năng này (routes/web.php) và trang "Tài khoản" giữ nguyên ô email chỉ đọc.
 * Gửi đồng bộ qua SmtpMailer (tối đa 15 giây). Không ném lỗi: gửi lỗi trả false và ghi lý do vào
 * storage/logs/app.log; nhật ký không bao giờ có mã (SmtpMailer không ghi nội dung email).
 */
final class VerificationMail
{
    /** Thời hạn của mã (phút), giống NTK_sp_email_verify_issue trong 40_email_verify_NTK.sql. */
    public const CODE_TTL_MINUTES = 15;

    /** @var array<string, mixed>|null */
    private static ?array $config = null;

    /** Đã cấu hình gửi email (MAIL_HOST) chưa: chưa thì chức năng xác minh email ẩn hoàn toàn. */
    public static function enabled(): bool
    {
        return SmtpMailer::enabled(self::config());
    }

    /**
     * Gửi mã tới $toAddress. $purpose 'verify' (xác minh email đang dùng) hoặc 'change' (đổi sang email này).
     * true khi máy chủ SMTP đã nhận email.
     */
    public static function sendCode(string $toAddress, string $name, string $code, string $purpose): bool
    {
        if (!self::enabled() || filter_var($toAddress, FILTER_VALIDATE_EMAIL) === false) {
            return false;
        }
        $mail = self::compose(trim($name), $code, $purpose);
        try {
            (new SmtpMailer(self::config()))->send($toAddress, $name, $mail['subject'], $mail['text'], $mail['html']);

            return true;
        } catch (Throwable $exception) {
            // Chỉ thông báo lỗi của SmtpMailer (bước SMTP, mã trả lời), không ghi cả exception: tham số có mã.
            error_log('LocalTour: gửi mã xác minh email không thành công: ' . $exception->getMessage());

            return false;
        }
    }

    /**
     * @return array{subject: string, text: string, html: string}
     */
    private static function compose(string $name, string $code, string $purpose): array
    {
        $greeting = 'Chào ' . ($name !== '' ? $name : 'bạn') . ',';
        $use = $purpose === 'change'
            ? 'Nhập mã này ở trang "Tài khoản" của LocalTour để đổi email đăng nhập sang địa chỉ này.'
            : 'Nhập mã này ở trang "Tài khoản" của LocalTour để xác minh email của bạn.';
        $ttl = 'Mã có hiệu lực ' . self::CODE_TTL_MINUTES . ' phút. Không chia sẻ mã với bất kỳ ai, kể cả nhân viên LocalTour.';
        $ignore = 'Nếu bạn không yêu cầu mã này, hãy bỏ qua email.';
        $footer = 'Email này được LocalTour gửi tự động. Vui lòng không trả lời email này.';

        $text = implode("\r\n", [
            $greeting, '',
            'Mã xác minh email LocalTour của bạn: ' . $code, '',
            $use,
            $ttl,
            $ignore, '',
            '--',
            $footer,
        ]) . "\r\n";

        $font = "font-family:'Be Vietnam Pro',Arial,Helvetica,sans-serif;";
        $html = '<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mã xác minh email</title>
</head>
<body style="margin:0;padding:0;background:#f3f3f3;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f3f3;">
<tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#ffffff;border:1px solid #e3e5e8;border-radius:8px;">
<tr><td style="' . $font . 'background:#176b5f;color:#ffffff;padding:16px 24px;border-radius:8px 8px 0 0;font-size:20px;font-weight:bold;">LocalTour</td></tr>
<tr><td style="' . $font . 'padding:24px;color:#1f2328;font-size:15px;line-height:1.6;">
<p style="' . $font . 'margin:0 0 12px;">' . e($greeting) . '</p>
<p style="' . $font . 'margin:0 0 8px;">Mã xác minh email LocalTour của bạn:</p>
<p style="' . $font . 'margin:0 0 16px;font-size:30px;font-weight:bold;letter-spacing:6px;color:#176b5f;">' . e($code) . '</p>
<p style="' . $font . 'margin:0 0 8px;">' . e($use) . '</p>
<p style="' . $font . 'margin:0 0 8px;">' . e($ttl) . '</p>
<p style="' . $font . 'margin:0;color:#6b7280;">' . e($ignore) . '</p>
</td></tr>
<tr><td style="' . $font . 'padding:16px 24px;border-top:1px solid #e3e5e8;color:#6b7280;font-size:12px;line-height:1.6;">' . e($footer) . '</td></tr>
</table>
</td></tr>
</table>
</body>
</html>
';

        return ['subject' => 'LocalTour – mã xác minh email', 'text' => $text, 'html' => $html];
    }

    /** @return array<string, mixed> config/mail.php */
    private static function config(): array
    {
        return self::$config ??= require BASE_PATH . '/config/mail.php';
    }
}
