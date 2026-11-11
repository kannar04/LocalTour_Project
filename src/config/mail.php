<?php

declare(strict_types=1);

use Core\Env;

/*
 * Cấu hình gửi email qua SMTP (email "Đặt tour thành công" – Nguyễn Tuấn Khôi).
 * Giá trị thật chỉ nằm trong src/.env (không commit). Xem src/.env.example.
 * MAIL_HOST trống = tắt gửi email (đơn vẫn xác nhận bình thường, nhật ký ghi "skipped").
 * encryption: tls = STARTTLS (cổng 587), ssl = TLS ngay khi kết nối (cổng 465), none = không mã hóa (chỉ để thử trên máy).
 */
$encryption = strtolower(trim(Env::get('MAIL_ENCRYPTION', 'tls')));
$defaultPorts = ['tls' => 587, 'ssl' => 465, 'none' => 25];
$port = trim(Env::get('MAIL_PORT'));
$host = trim(Env::get('MAIL_HOST'));
$password = Env::get('MAIL_PASSWORD');
// Mật khẩu ứng dụng Gmail hiện dạng "abcd efgh ijkl mnop": khoảng trắng chỉ để dễ đọc, bỏ đi.
if (preg_match('/(^|\.)(gmail|googlemail)\.com$/i', $host)) {
    $password = str_replace(' ', '', $password);
}

return [
    'host' => $host,
    'encryption' => $encryption === '' ? 'tls' : $encryption,
    'port' => ctype_digit($port) ? (int) $port : ($defaultPorts[$encryption] ?? 587),
    'username' => trim(Env::get('MAIL_USERNAME')),
    'password' => $password,
    'from_address' => trim(Env::get('MAIL_FROM_ADDRESS')),
    'from_name' => trim(Env::get('MAIL_FROM_NAME', 'LocalTour')) ?: 'LocalTour',
];
