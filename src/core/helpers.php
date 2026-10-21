<?php

declare(strict_types=1);

/*
 * Hàm tiện ích dùng chung cho controller và view: escape HTML, tạo URL, định dạng giá/ngày/giờ.
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

/** URL trong ứng dụng: url('/tours/5'). APP_URL trong .env (nếu có) được ưu tiên. */
function url(string $path = '/'): string
{
    static $base = null;
    if ($base === null) {
        $config = require BASE_PATH . '/config/app.php';
        $base = $config['url'] !== '' ? $config['url'] : base_path_prefix();
    }

    return $base . '/' . ltrim($path, '/');
}

/** URL tài nguyên tĩnh trong public/assets, kèm phiên bản theo thời gian sửa file để tránh cache cũ. */
function asset(string $path): string
{
    $path = ltrim($path, '/');
    $file = BASE_PATH . '/public/assets/' . $path;
    $version = is_file($file) ? '?v=' . filemtime($file) : '';

    return url('/assets/' . $path) . $version;
}

/** URL ảnh tour lưu trong DB (đường dẫn tương đối trong public/), null nếu chưa có ảnh. */
function tour_image_url(?string $path): ?string
{
    $path = trim((string) $path);
    if ($path === '' || !str_starts_with($path, 'assets/') || str_contains($path, '..')) {
        return null;
    }

    return url('/' . $path);
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

/** "4.0" → "4 giờ", "1.5" → "1,5 giờ" */
function format_duration(int|float|string $hours): string
{
    $value = round((float) $hours, 1);
    $text = floor($value) === $value
        ? (string) (int) $value
        : str_replace('.', ',', (string) $value);

    return $text . ' giờ';
}

/** "2026-10-24" → "24/10/2026" */
function format_date(?string $date): string
{
    if ($date === null || $date === '') {
        return '';
    }

    $parsed = DateTimeImmutable::createFromFormat('!Y-m-d', substr($date, 0, 10));

    return $parsed ? $parsed->format('d/m/Y') : '';
}

/** "17:00:00" → "17:00" */
function format_time(?string $time): string
{
    return $time === null ? '' : substr($time, 0, 5);
}
