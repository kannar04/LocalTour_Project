<?php

declare(strict_types=1);

use App\Controllers\AdminAuthController;
use App\Controllers\AdminBookingController;
use App\Controllers\AdminDashboardController;
use App\Controllers\AdminPaymentController;
use App\Controllers\AdminTourController;
use App\Controllers\AuthController;
use App\Controllers\BookingController;
use App\Controllers\CustomerBookingController;
use App\Controllers\PaymentController;
use App\Controllers\ScheduleController;
use App\Controllers\TourDetailController;
use App\Controllers\TourListController;
use App\Controllers\VnpayController;
use App\Controllers\VoucherController;
use Core\Router;

$router = new Router();

// Danh sách tour (WBS 3.2.3)
$router->get('/', [TourListController::class, 'index']);
$router->get('/tours', [TourListController::class, 'index']);
$router->get('/api/tours', [TourListController::class, 'apiIndex']);
$router->get('/api/destinations', [TourListController::class, 'apiDestinations']);
$router->get('/api/categories', [TourListController::class, 'apiCategories']);

// Chi tiết tour theo ID (WBS 3.2.4)
$router->get('/tours/{id}', [TourDetailController::class, 'show']);
$router->get('/api/tours/{id}', [TourDetailController::class, 'apiShow']);

// Đặt tour (M4): trang hoàn tất thông tin, kiểm tra chỗ trống của lịch, lưu yêu cầu đặt tour.
$router->get('/tours/{id}/book', [BookingController::class, 'create']);
$router->get('/api/schedules/{id}/availability', [ScheduleController::class, 'apiAvailability']);
$router->post('/api/bookings', [BookingController::class, 'store']);

// Đơn của tôi (M4): yêu cầu đặt tour đã gửi của tài khoản đang đăng nhập.
$router->get('/bookings', [CustomerBookingController::class, 'index']);
$router->get('/bookings/{code}', [CustomerBookingController::class, 'show']);

// Thanh toán (Sprint 4): chọn VNPay / VietQR, kết quả VNPay (Return URL, IPN), voucher.
$router->get('/bookings/{code}/pay', [PaymentController::class, 'checkout']);
$router->post('/bookings/{code}/pay/vnpay', [PaymentController::class, 'startVnpay']);
$router->post('/bookings/{code}/pay/vietqr', [PaymentController::class, 'startVietqr']);
$router->get('/bookings/{code}/pay/vietqr', [PaymentController::class, 'transfer']);
$router->post('/bookings/{code}/pay/vietqr/submit', [PaymentController::class, 'submitTransfer']);
$router->get('/payments/vnpay/return', [VnpayController::class, 'result']);
$router->get('/payments/vnpay/ipn', [VnpayController::class, 'ipn']);
$router->get('/bookings/{code}/voucher', [VoucherController::class, 'show']);

// Tài khoản khách hàng: đăng ký, đăng nhập, đăng xuất (WBS 3.2.8). Chưa đăng nhập = chế độ khách.
$router->get('/login', [AuthController::class, 'showLogin']);
$router->post('/login', [AuthController::class, 'login']);
$router->get('/register', [AuthController::class, 'showRegister']);
$router->post('/register', [AuthController::class, 'register']);
$router->post('/logout', [AuthController::class, 'logout']);

// Trang quản trị (FR-19 → FR-25): đăng nhập riêng, chỉ tài khoản quản trị viên.
$router->get('/admin/login', [AdminAuthController::class, 'showLogin']);
$router->post('/admin/login', [AdminAuthController::class, 'login']);
$router->post('/admin/logout', [AdminAuthController::class, 'logout']);
$router->get('/admin', [AdminDashboardController::class, 'index']);
$router->get('/admin/tours', [AdminTourController::class, 'index']);
$router->get('/admin/tours/{id}', [AdminTourController::class, 'show']);
$router->post('/admin/tours/{id}/approve', [AdminTourController::class, 'approve']);
$router->post('/admin/tours/{id}/reject', [AdminTourController::class, 'reject']);
$router->get('/admin/bookings', [AdminBookingController::class, 'index']);
$router->get('/admin/bookings/{id}', [AdminBookingController::class, 'show']);
$router->post('/admin/bookings/{id}/status', [AdminBookingController::class, 'updateStatus']);
$router->get('/admin/payments', [AdminPaymentController::class, 'index']);
$router->post('/admin/payments/{id}/decide', [AdminPaymentController::class, 'decide']);

return $router;
