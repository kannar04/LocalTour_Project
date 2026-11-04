<?php

declare(strict_types=1);

/*
 * Tự hủy đơn quá hạn thanh toán và nhả chỗ (Sprint 4, 4.5.4.1 – Lê Trung Phong).
 * Đơn "Chờ thanh toán" quá hold_expires_at (24 giờ từ lúc xác nhận chỗ) bị hủy, trừ đơn có khoản VietQR chờ đối chiếu.
 * Chạy định kỳ bằng Task Scheduler (Windows), ví dụ mỗi 15 phút:
 *   C:\xampp\php\php.exe <thư mục dự án>\src\scripts\expire_holds.php
 * Trang "Đơn của tôi" và trang quản trị cũng tự chạy bước này trước khi hiển thị.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require dirname(__DIR__) . '/core/bootstrap.php';

$expired = (new App\Models\PaymentResultModel())->expireHolds();
echo date('Y-m-d H:i:s') . ' – đã hủy ' . $expired . ' đơn quá hạn thanh toán.' . PHP_EOL;
