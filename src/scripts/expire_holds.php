<?php

declare(strict_types=1);

/*
 * Tự hủy đơn quá hạn thanh toán và nhả chỗ (Sprint 4, 4.5.4.1 – Lê Trung Phong).
 * Đơn "Chờ thanh toán" quá hold_expires_at (settings.hold_minutes phút từ lúc đặt; đơn cũ 24 giờ từ lúc quản trị viên xác
 * nhận chỗ) bị hủy, trừ đơn có khoản VietQR chờ đối chiếu.
 * Sau đó chạy việc sau tour (Nguyễn Tuấn Khôi, file 30): đơn của lịch đã kết thúc tự "Đã hoàn thành", lập khoản chi trả.
 * Hai bước độc lập: bước này lỗi thì bước kia vẫn chạy; có bước lỗi thì mã thoát là 1.
 * Chạy định kỳ mỗi 15 phút bằng Task Scheduler (Windows): đăng ký bằng register_expire_task.bat cùng thư mục
 * (xem src/README.md, Bước 9), task chạy: C:\xampp\php\php-win.exe <thư mục dự án>\src\scripts\expire_holds.php
 * Trang "Đơn của tôi" và trang quản trị cũng tự chạy bước này trước khi hiển thị.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require dirname(__DIR__) . '/core/bootstrap.php';

$failed = false;

try {
    $expired = (new App\Models\PaymentResultModel())->expireHolds();
    echo date('Y-m-d H:i:s') . ' – đã hủy ' . $expired . ' đơn quá hạn thanh toán.' . PHP_EOL;
} catch (Throwable $exception) {
    $failed = true;
    echo date('Y-m-d H:i:s') . ' – LỖI khi hủy đơn quá hạn thanh toán: ' . $exception->getMessage() . PHP_EOL;
}

// Dòng tiền sau tour (Nguyễn Tuấn Khôi, file 30): đơn của lịch đã kết thúc tự "Đã hoàn thành", lịch đã kết thúc
// "Đã hoàn thành", lập khoản chi trả cho đơn vị tổ chức khi lịch không còn gì dang dở.
try {
    $sweep = (new App\Models\PayoutModel())->sweep();
    echo date('Y-m-d H:i:s') . ' – đã tự hoàn thành ' . $sweep['completed'] . ' đơn, ' . $sweep['schedules_completed']
        . ' lịch khởi hành; đã lập ' . $sweep['payouts'] . ' khoản chi trả.' . PHP_EOL;
} catch (Throwable $exception) {
    $failed = true;
    echo date('Y-m-d H:i:s') . ' – LỖI khi chạy việc sau tour: ' . $exception->getMessage() . PHP_EOL;
}

exit($failed ? 1 : 0);
