<?php

declare(strict_types=1);

use App\Controllers\AdminAuthController;
use App\Controllers\AdminBookingController;
use App\Controllers\AdminChangeRequestController;
use App\Controllers\AdminDashboardController;
use App\Controllers\AdminPackageController;
use App\Controllers\AdminPaymentController;
use App\Controllers\AdminProviderController;
use App\Controllers\AdminScheduleController;
use App\Controllers\AdminTourContentController;
use App\Controllers\AdminTourController;
use App\Controllers\AdminTourFormController;
use App\Controllers\AuthController;
use App\Controllers\BookingController;
use App\Controllers\ChangeRequestController;
use App\Controllers\CompareController;
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

// So sánh tour (Sprint 5, US04): tối đa 3 tour, danh sách chọn lưu ở trình duyệt.
$router->get('/compare', [CompareController::class, 'index']);
$router->get('/api/compare', [CompareController::class, 'apiIndex']);

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

// Đổi ngày / hủy tour (Sprint 5, US14): khách gửi yêu cầu, quản trị viên xử lý thủ công.
$router->get('/bookings/{code}/change', [ChangeRequestController::class, 'create']);
$router->post('/bookings/{code}/change', [ChangeRequestController::class, 'store']);

// Tài khoản khách hàng: đăng ký, đăng nhập, đăng xuất (WBS 3.2.8). Chưa đăng nhập = chế độ khách.
$router->get('/login', [AuthController::class, 'showLogin']);
$router->post('/login', [AuthController::class, 'login']);
$router->get('/register', [AuthController::class, 'showRegister']);
$router->post('/register', [AuthController::class, 'register']);
$router->post('/logout', [AuthController::class, 'logout']);

// Đăng nhập bằng Google / Facebook (OAuth 2.0) cho tài khoản khách hàng. Thiếu khóa trong .env thì nút bị ẩn.
$router->get('/auth/google', [App\Controllers\SocialAuthController::class, 'google']);
$router->get('/auth/google/callback', [App\Controllers\SocialAuthController::class, 'googleCallback']);
$router->get('/auth/facebook', [App\Controllers\SocialAuthController::class, 'facebook']);
$router->get('/auth/facebook/callback', [App\Controllers\SocialAuthController::class, 'facebookCallback']);

// Trang quản trị (FR-19 → FR-25): đăng nhập riêng, chỉ tài khoản quản trị viên.
$router->get('/admin/login', [AdminAuthController::class, 'showLogin']);
$router->post('/admin/login', [AdminAuthController::class, 'login']);
$router->post('/admin/logout', [AdminAuthController::class, 'logout']);
$router->get('/admin', [AdminDashboardController::class, 'index']);
$router->get('/admin/revenue', [AdminDashboardController::class, 'revenuePayments']);

// CRUD nền tảng (FR-13, FR-14): đơn vị tổ chức, thêm / sửa tour, lịch khởi hành và giá vé.
// Đặt trước '/admin/tours/{id}' để '/admin/tours/new' không bị hiểu là mã tour.
$router->get('/admin/providers', [AdminProviderController::class, 'index']);
$router->get('/admin/providers/new', [AdminProviderController::class, 'create']);
$router->post('/admin/providers/new', [AdminProviderController::class, 'store']);
$router->get('/admin/providers/{id}/edit', [AdminProviderController::class, 'edit']);
$router->post('/admin/providers/{id}/edit', [AdminProviderController::class, 'update']);
$router->post('/admin/providers/{id}/delete', [AdminProviderController::class, 'delete']);
$router->get('/admin/tours/new', [AdminTourFormController::class, 'create']);
$router->post('/admin/tours/new', [AdminTourFormController::class, 'store']);
$router->get('/admin/tours/{id}/edit', [AdminTourFormController::class, 'edit']);
$router->post('/admin/tours/{id}/edit', [AdminTourFormController::class, 'update']);
$router->get('/admin/tours/{id}/schedules', [AdminScheduleController::class, 'index']);
$router->post('/admin/tours/{id}/schedules', [AdminScheduleController::class, 'store']);
$router->get('/admin/schedules/{id}/edit', [AdminScheduleController::class, 'edit']);
$router->post('/admin/schedules/{id}/edit', [AdminScheduleController::class, 'update']);

// Gói tour (Sprint 5, US06) và nội dung tour: ảnh, lịch trình, dịch vụ, chính sách hủy, xóa / ngừng hiển thị (US07).
$router->get('/admin/tours/{id}/packages', [AdminPackageController::class, 'index']);
$router->post('/admin/tours/{id}/packages', [AdminPackageController::class, 'save']);
$router->get('/admin/tours/{id}/content', [AdminTourContentController::class, 'index']);
$router->post('/admin/tours/{id}/content/images', [AdminTourContentController::class, 'addImage']);
$router->post('/admin/tours/{id}/content/images/{imageId}/delete', [AdminTourContentController::class, 'deleteImage']);
$router->post('/admin/tours/{id}/content/images/{imageId}/cover', [AdminTourContentController::class, 'setCover']);
$router->post('/admin/tours/{id}/content/itinerary', [AdminTourContentController::class, 'saveItinerary']);
$router->post('/admin/tours/{id}/content/itinerary/{itemId}/delete', [AdminTourContentController::class, 'deleteItinerary']);
$router->post('/admin/tours/{id}/content/inclusions', [AdminTourContentController::class, 'addInclusion']);
$router->post('/admin/tours/{id}/content/inclusions/{inclusionId}/delete', [AdminTourContentController::class, 'deleteInclusion']);
$router->post('/admin/tours/{id}/content/policy', [AdminTourContentController::class, 'addPolicy']);
$router->post('/admin/tours/{id}/delete', [AdminTourContentController::class, 'deleteTour']);
$router->post('/admin/tours/{id}/restore', [AdminTourContentController::class, 'restoreTour']);

$router->get('/admin/tours', [AdminTourController::class, 'index']);
$router->get('/admin/tours/{id}', [AdminTourController::class, 'show']);
$router->post('/admin/tours/{id}/approve', [AdminTourController::class, 'approve']);
$router->post('/admin/tours/{id}/reject', [AdminTourController::class, 'reject']);
$router->get('/admin/bookings', [AdminBookingController::class, 'index']);
$router->get('/admin/bookings/{id}', [AdminBookingController::class, 'show']);
$router->post('/admin/bookings/{id}/status', [AdminBookingController::class, 'updateStatus']);
$router->get('/admin/change-requests', [AdminChangeRequestController::class, 'index']);
$router->get('/admin/change-requests/{id}', [AdminChangeRequestController::class, 'show']);
$router->post('/admin/change-requests/{id}/decide', [AdminChangeRequestController::class, 'decide']);
$router->get('/admin/payments', [AdminPaymentController::class, 'index']);
$router->post('/admin/payments/{id}/decide', [AdminPaymentController::class, 'decide']);
$router->post('/admin/payments/{id}/vnpay', [AdminPaymentController::class, 'vnpayDecide']);

return $router;
