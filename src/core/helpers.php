<?php

declare(strict_types=1);

/*
 * Hàm tiện ích dùng chung cho controller và view: escape HTML, tạo URL, tài khoản đăng nhập, định dạng giá/ngày/giờ.
 */

/** Escape giá trị trước khi in ra HTML. */
function e(mixed $value): string
{
    return htmlspecialchars((string) ($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Thư mục gốc của ứng dụng trên URL, '' khi chạy ở gốc domain (php -S), vd. '/LocalTour_Project/src/public' trong htdocs. */
function base_path_prefix(): string
{
    static $prefix = null;
    if ($prefix === null) {
        $directory = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/'));
        $prefix = ($directory === '/' || $directory === '.') ? '' : rtrim($directory, '/');
    }

    return $prefix;
}

/** URL trong ứng dụng: url('/tours'). APP_URL trong .env (nếu có) được ưu tiên. */
function url(string $path = '/'): string
{
    static $base = null;
    if ($base === null) {
        $config = require BASE_PATH . '/config/app.php';
        $base = $config['url'] !== '' ? $config['url'] : base_path_prefix();
    }

    return $base . '/' . ltrim($path, '/');
}

/**
 * Đường dẫn quay lại sau khi đăng nhập / đăng ký (tham số next). Chỉ nhận đường dẫn trong ứng dụng
 * như "/tours/<uuid>"; link ra ngoài ("//...", "https://...", "\...") hoặc rỗng → "/tours".
 */
function safe_next_path(?string $next): string
{
    $next = trim((string) $next);
    if ($next === '' || $next[0] !== '/' || str_starts_with($next, '//') || str_contains($next, '\\')
        || preg_match('/[\x00-\x1F\x7F]/', $next)) {
        return '/tours';
    }

    return $next;
}

/**
 * Tài khoản đang đăng nhập; null = chế độ khách.
 *
 * @return array{user_id: string, name: string, email: string, role: string}|null
 */
function current_user(): ?array
{
    return Core\Auth::user();
}

/** Ô ẩn chứa mã CSRF, đặt trong mọi form POST. */
function csrf_field(): string
{
    return '<input type="hidden" name="_csrf" value="' . e(Core\Auth::csrfToken()) . '">';
}

/** URL tài nguyên tĩnh trong public/assets, kèm phiên bản theo thời gian sửa file để tránh cache cũ. */
function asset(string $path): string
{
    $path = ltrim($path, '/');
    $file = BASE_PATH . '/public/assets/' . $path;
    $version = is_file($file) ? '?v=' . filemtime($file) : '';

    return url('/assets/' . $path) . $version;
}

/** URL ảnh lưu trong tour_images: link http(s) giữ nguyên, đường dẫn tương đối nằm trong public/assets. */
function image_src(string $url): string
{
    return preg_match('#^https?://#i', $url) ? $url : asset($url);
}

/** Giá trị rỗng/thiếu → "Chưa cập nhật" (không tự suy diễn dữ liệu). */
function or_missing(?string $value): string
{
    $value = trim((string) $value);

    return $value === '' ? 'Chưa cập nhật' : $value;
}

/** 650000 → "650.000đ" */
function format_vnd(int|string|null $amount): string
{
    return number_format((int) $amount, 0, ',', '.') . 'đ';
}

/** "4.8" → "4,8"; null khi tour chưa có đánh giá. */
function format_rating(int|float|string|null $rating): ?string
{
    if ($rating === null || $rating === '') {
        return null;
    }

    return number_format((float) $rating, 1, ',', '');
}

/** 240 → "4 giờ", 210 → "3 giờ 30 phút", 45 → "45 phút" */
function format_duration(int|string $minutes): string
{
    $minutes = max(0, (int) $minutes);
    $hours = intdiv($minutes, 60);
    $rest = $minutes % 60;

    if ($hours === 0) {
        return $rest . ' phút';
    }

    return $hours . ' giờ' . ($rest > 0 ? ' ' . $rest . ' phút' : '');
}

/** "vi,en" → "Tiếng Việt / Anh"; mã chưa biết giữ nguyên dạng chữ hoa. */
function format_languages(?string $codes): string
{
    $names = ['vi' => 'Tiếng Việt', 'en' => 'Anh', 'fr' => 'Pháp', 'ko' => 'Hàn', 'zh' => 'Trung', 'ja' => 'Nhật'];
    $labels = [];
    foreach (explode(',', (string) $codes) as $code) {
        $code = strtolower(trim($code));
        if ($code !== '') {
            $labels[] = $names[$code] ?? strtoupper($code);
        }
    }

    return implode(' / ', $labels);
}

/** pickup_mode của tour → nhãn hiển thị. */
function pickup_label(?string $mode): string
{
    return $mode === 'hotel_pickup' ? 'Đón tại khách sạn' : 'Gặp tại điểm hẹn';
}

/** Dòng điểm đón ngắn cho thẻ tour: "Gặp tại Chùa Cầu" / "Đón tại khách sạn". */
function pickup_text(?string $mode, ?string $meetingPoint): string
{
    $meetingPoint = trim((string) $meetingPoint);
    if ($mode === 'hotel_pickup' || $meetingPoint === '') {
        return pickup_label($mode);
    }

    return 'Gặp tại ' . $meetingPoint;
}

/** Nơi khởi hành: tên điểm hẹn, "Đón tại khách sạn", hoặc "Chưa cập nhật" khi tour không ghi điểm hẹn. */
function departure_text(?string $mode, ?string $meetingPoint): string
{
    return $mode === 'hotel_pickup' ? 'Đón tại khách sạn' : or_missing($meetingPoint);
}

/** Tên loại vé (adult, child...) → nhãn tiếng Việt; tên khác giữ nguyên. */
function ticket_label(string $name): string
{
    $labels = ['adult' => 'Người lớn', 'child' => 'Trẻ em', 'infant' => 'Em bé', 'senior' => 'Người cao tuổi'];

    return $labels[strtolower($name)] ?? $name;
}

/** (12, null) → "Từ 12 tuổi", (4, 11) → "4–11 tuổi", (null, 3) → "Đến 3 tuổi", (null, null) → "" */
function age_range_text(int|string|null $min, int|string|null $max): string
{
    $min = $min === null || $min === '' ? null : (int) $min;
    $max = $max === null || $max === '' ? null : (int) $max;

    if ($min !== null && $max !== null) {
        return $min . '–' . $max . ' tuổi';
    }
    if ($min !== null) {
        return 'Từ ' . $min . ' tuổi';
    }

    return $max !== null ? 'Đến ' . $max . ' tuổi' : '';
}

/**
 * Một loại vé (dòng có ticket_type_id, name, min_age, max_age, price_vnd) → dữ liệu cho JS chọn số khách.
 *
 * @param array<string, mixed> $ticket
 * @return array{id: string, label: string, ages: string, price: int}
 */
function ticket_option(array $ticket): array
{
    return [
        'id' => (string) $ticket['ticket_type_id'],
        'label' => ticket_label((string) $ticket['name']),
        'ages' => age_range_text($ticket['min_age'], $ticket['max_age']),
        'price' => (int) $ticket['price_vnd'],
    ];
}

/**
 * Tách văn bản thành các đoạn (ngăn bởi dòng trống); mỗi đoạn vẫn có thể chứa xuống dòng đơn.
 *
 * @return list<string>
 */
function text_paragraphs(?string $text): array
{
    $text = str_replace("\r\n", "\n", trim((string) $text));
    $paragraphs = array_map('trim', preg_split('/\n\s*\n/u', $text) ?: []);

    return array_values(array_filter($paragraphs, static fn (string $part): bool => $part !== ''));
}

/**
 * Các dòng không rỗng của văn bản (vd. điều kiện tour: mỗi dòng một ý).
 *
 * @return list<string>
 */
function text_lines(?string $text): array
{
    $lines = array_map('trim', preg_split('/\R/u', (string) $text) ?: []);

    return array_values(array_filter($lines, static fn (string $line): bool => $line !== ''));
}

/** "2026-10-24" hoặc "2026-10-24 17:00:00" → "24/10/2026" */
function format_date(?string $date): string
{
    if ($date === null || $date === '') {
        return '';
    }

    $parsed = DateTimeImmutable::createFromFormat('!Y-m-d', substr($date, 0, 10));

    return $parsed ? $parsed->format('d/m/Y') : '';
}

/** "17:00:00" hoặc "2026-10-24 17:00:00" → "17:00" */
function format_time(?string $time): string
{
    if ($time === null || $time === '') {
        return '';
    }

    return strlen($time) > 8 ? substr($time, 11, 5) : substr($time, 0, 5);
}

/** Giờ của một lịch khởi hành: "17:00 – 21:00"; thêm ngày kết thúc nếu tour qua ngày hôm sau. */
function schedule_time_text(?string $startsAt, ?string $endsAt): string
{
    $start = (string) $startsAt;
    $end = (string) $endsAt;
    $text = format_time($start) . ' – ' . format_time($end);
    if ($end !== '' && substr($end, 0, 10) !== substr($start, 0, 10)) {
        $text .= ' (' . format_date($end) . ')';
    }

    return $text;
}

/**
 * Chính sách hủy → các câu hiển thị (giống thẻ giá ở trang chi tiết tour).
 * $freeBeforeHours null = không có mốc hủy miễn phí.
 *
 * @return list<string>
 */
function cancellation_policy_lines(int|string|null $freeBeforeHours, int|string|null $refundPercent): array
{
    $refundPercent = (int) $refundPercent;
    if ($freeBeforeHours === null || $freeBeforeHours === '') {
        return [$refundPercent > 0 ? 'Hủy tour được hoàn ' . $refundPercent . '% tiền tour.' : 'Tour không hoàn tiền khi hủy.'];
    }

    $freeBeforeHours = (int) $freeBeforeHours;

    return [
        $freeBeforeHours > 0 ? 'Hủy miễn phí trước giờ khởi hành ' . $freeBeforeHours . ' giờ.' : 'Hủy miễn phí đến giờ khởi hành.',
        $refundPercent > 0 ? 'Sau thời điểm này hoàn ' . $refundPercent . '% tiền tour.' : 'Sau thời điểm này không hoàn tiền.',
    ];
}

/** "2026-10-24 17:05:00" → "24/10/2026 17:05"; '' khi không có giá trị. */
function format_datetime(?string $value): string
{
    if ($value === null || $value === '') {
        return '';
    }

    return trim(format_date($value) . ' ' . format_time($value));
}

/** Trạng thái yêu cầu đặt tour (bookings.status) → nhãn tiếng Việt. */
function booking_status_label(?string $status): string
{
    $labels = [
        'pending' => 'Chờ xác nhận',
        'awaiting_payment' => 'Chờ thanh toán',
        'confirmed' => 'Đã xác nhận',
        'rejected' => 'Từ chối',
        'cancelled' => 'Đã hủy',
        'completed' => 'Đã hoàn thành',
    ];

    return $labels[(string) $status] ?? (string) $status;
}

/** Trạng thái thanh toán (payments.status) → nhãn; null = chưa có khoản thanh toán nào. */
function payment_status_label(?string $status): string
{
    $labels = [
        'pending' => 'Chưa thanh toán',
        'processing' => 'Đang xử lý',
        'awaiting_reconciliation' => 'Chờ đối chiếu',
        'paid' => 'Thành công',
        'failed' => 'Thất bại',
    ];

    return $status === null ? 'Chưa thanh toán' : ($labels[$status] ?? $status);
}

/** Phương thức thanh toán (payments.method) → nhãn. */
function payment_method_label(?string $method): string
{
    $labels = ['vnpay' => 'VNPay', 'vietqr' => 'VietQR (chuyển khoản)'];

    return $labels[(string) $method] ?? (string) $method;
}

/**
 * Một dòng lịch sử đơn (LTP_sp_booking_history, LTP_sp_customer_booking_history) → tiêu đề tiếng Việt.
 * Đổi trạng thái hiện "A → B"; thao tác khác hiện tên thao tác.
 *
 * @param array<string, mixed> $event
 */
function booking_history_title(array $event): string
{
    $labels = [
        'created' => 'Gửi yêu cầu đặt tour',
        'booking_total' => 'Chốt tổng giá',
        'transfer_submitted' => 'Báo đã chuyển khoản VietQR',
        'payment_confirm' => 'Đối chiếu: đã nhận tiền chuyển khoản',
        'payment_reject' => 'Đối chiếu: chuyển khoản không khớp',
        'vnpay_paid' => 'Thanh toán VNPay thành công',
        'vnpay_failed' => 'Thanh toán VNPay không thành công',
        'hold_expired' => 'Quá hạn thanh toán, đơn tự hủy',
        'voucher_issued' => 'Cấp voucher',
        'refund_requested' => 'Tạo yêu cầu hoàn tiền',
    ];
    $action = (string) ($event['action'] ?? '');
    $from = $event['from_status'] ?? null;
    $to = $event['to_status'] ?? null;
    if ($action === 'booking_status' && $to !== null) {
        return ($from !== null ? booking_status_label((string) $from) . ' → ' : '') . booking_status_label((string) $to);
    }

    return $labels[$action] ?? $action;
}

/** Người thực hiện một dòng lịch sử đơn (booking_events.actor hoặc 'admin') → nhãn. */
function booking_history_actor(?string $actor): string
{
    $labels = ['customer' => 'Khách hàng', 'system' => 'Hệ thống', 'vnpay' => 'VNPay', 'admin' => 'LocalTour'];

    return $labels[(string) $actor] ?? (string) $actor;
}

/** Trạng thái duyệt tour (tours.approval_status) → nhãn tiếng Việt. */
function tour_status_label(?string $status): string
{
    $labels = ['draft' => 'Nháp', 'pending' => 'Chờ duyệt', 'approved' => 'Đã duyệt', 'rejected' => 'Bị từ chối'];

    return $labels[(string) $status] ?? (string) $status;
}
