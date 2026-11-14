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

// Đặt tour (M4): trang hoàn tất thông tin, kiểm tra chỗ trống của lịch, tạo đơn đặt tour (giữ chỗ ngay).
$router->get('/tours/{id}/book', [BookingController::class, 'create']);
$router->get('/api/schedules/{id}/availability', [ScheduleController::class, 'apiAvailability']);
$router->post('/api/bookings', [BookingController::class, 'store']);

// Đơn của tôi (M4): đơn đặt tour của tài khoản đang đăng nhập.
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
// Thanh toán MoMo (môi trường thử) đang ẩn: chỉ có các đường dẫn này khi config/payment.php bật momo_enabled.
// '/payments/momo/ipn' đặt trước '/payments/momo/{code}'.
$momoOn = (require BASE_PATH . '/config/payment.php')['momo_enabled'] === true;
if ($momoOn) {
    $router->get('/payments/momo/return', [\App\Controllers\MomoController::class, 'result']);
    $router->post('/payments/momo/ipn', [\App\Controllers\MomoController::class, 'ipn']);
    $router->post('/payments/momo/{code}', [\App\Controllers\MomoController::class, 'start']);
}

// Đổi ngày / hủy tour (Sprint 5, US14): khách gửi yêu cầu, quản trị viên xử lý thủ công.
$router->get('/bookings/{code}/change', [ChangeRequestController::class, 'create']);
$router->post('/bookings/{code}/change', [ChangeRequestController::class, 'store']);

// Tài khoản khách hàng: đăng ký, đăng nhập, đăng xuất (WBS 3.2.8). Chưa đăng nhập = chế độ khách.
$router->get('/login', [AuthController::class, 'showLogin']);
$router->post('/login', [AuthController::class, 'login']);
$router->get('/register', [AuthController::class, 'showRegister']);
$router->post('/register', [AuthController::class, 'register']);
$router->post('/logout', [AuthController::class, 'logout']);

// Đăng nhập bằng Google (OAuth 2.0) cho tài khoản khách hàng. Thiếu khóa trong .env thì nút bị ẩn.
// Facebook đang ẩn: chỉ có đường dẫn khi config/auth.php bật facebook.enabled.
$router->get('/auth/google', [App\Controllers\SocialAuthController::class, 'google']);
$router->get('/auth/google/callback', [App\Controllers\SocialAuthController::class, 'googleCallback']);
if ((require BASE_PATH . '/config/auth.php')['facebook']['enabled'] === true) {
    $router->get('/auth/facebook', [App\Controllers\SocialAuthController::class, 'facebook']);
    $router->get('/auth/facebook/callback', [App\Controllers\SocialAuthController::class, 'facebookCallback']);
}

// Bản đồ và địa điểm quanh điểm khởi hành (Nguyễn Tuấn Khôi): trang /ban-do và quán ăn, bar, giải trí, quán nước
// quanh điểm khởi hành của tour (Overpass API gọi từ máy chủ, lưu đệm 7 ngày).
$router->get('/ban-do', [\App\Controllers\TourMapController::class, 'index']);
$router->get('/api/tours/{id}/places', [\App\Controllers\TourMapController::class, 'apiPlaces']);

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
// Thanh toán MoMo (đang ẩn): quản trị viên tra cứu lại khoản MoMo chưa rõ kết quả.
if ($momoOn) {
    $router->post('/admin/payments/{id}/momo', [AdminPaymentController::class, 'momoCheck']);
}

// Dòng tiền sau tour (Nguyễn Tuấn Khôi): khoản chi trả cho đơn vị tổ chức (hệ thống tự lập sau khi lịch khởi hành kết
// thúc, quản trị viên chuyển khoản ngoài hệ thống rồi ghi nhận đã chi trả), ghi "Đã hoàn tiền" cho khoản hoàn của khách,
// và thông số vận hành (% phí dịch vụ LocalTour, thời gian giữ chỗ, hạn nhận đặt, hạn nhận VietQR).
$router->get('/admin/payouts', [\App\Controllers\AdminPayoutController::class, 'index']);
$router->get('/admin/payouts/{id}', [\App\Controllers\AdminPayoutController::class, 'show']);
$router->post('/admin/payouts/{id}/pay', [\App\Controllers\AdminPayoutController::class, 'pay']);
// Quản trị viên xác minh tài khoản nhận tiền đơn vị đang khai (kiểm tra ngoài hệ thống rồi bấm "Xác minh"):
// chưa xác minh thì không ghi nhận được khoản chi trả; đơn vị đổi tài khoản thì phải xác minh lại.
$router->post('/admin/payouts/{id}/bank/verify', [\App\Controllers\AdminPayoutController::class, 'verifyBank']);
$router->post('/admin/refunds/{id}/complete', [\App\Controllers\AdminPayoutController::class, 'completeRefund']);
$router->get('/admin/settings', [\App\Controllers\AdminSettingController::class, 'index']);
$router->post('/admin/settings', [\App\Controllers\AdminSettingController::class, 'save']);

// Bản đồ (Nguyễn Tuấn Khôi): quản trị viên đặt / xóa vị trí điểm khởi hành của tour.
$router->get('/admin/tours/{id}/location', [\App\Controllers\AdminTourLocationController::class, 'edit']);
$router->post('/admin/tours/{id}/location', [\App\Controllers\AdminTourLocationController::class, 'update']);

// Tài khoản đơn vị tổ chức (Nguyễn Tuấn Khôi): đơn vị không tự đăng ký; quản trị viên thêm đơn vị và cấp mật khẩu ở
// trang "Đơn vị tổ chức". Đơn vị đăng nhập ở /host/login và tự đăng tour, lịch khởi hành, giá vé, ảnh, lịch trình,
// dịch vụ, chính sách hủy của tour của mình.
// Vòng duyệt: tour mới là "Bản nháp"; đơn vị bấm "Gửi duyệt" (submit) thì tour "Chờ duyệt" và bị khóa cho tới khi
// quản trị viên duyệt / từ chối (/admin/tours). Tour đã duyệt không sửa trực tiếp: đơn vị tạo "bản sửa" (revision),
// tour đang hiển thị giữ nguyên cho tới khi quản trị viên duyệt bản sửa. Lịch khởi hành và giá vé không cần duyệt.
// '/host/tours/new' đặt trước '/host/tours/{id}'.
$router->post('/admin/providers/{id}/password', [AdminProviderController::class, 'password']);
$router->get('/host/login', [\App\Controllers\HostAuthController::class, 'showLogin']);
$router->post('/host/login', [\App\Controllers\HostAuthController::class, 'login']);
$router->post('/host/logout', [\App\Controllers\HostAuthController::class, 'logout']);
$router->get('/host', [\App\Controllers\HostTourController::class, 'index']);
$router->get('/host/tours', [\App\Controllers\HostTourController::class, 'index']);
$router->get('/host/tours/new', [\App\Controllers\HostTourFormController::class, 'create']);
$router->post('/host/tours/new', [\App\Controllers\HostTourFormController::class, 'store']);
$router->get('/host/tours/{id}', [\App\Controllers\HostTourController::class, 'show']);
$router->get('/host/tours/{id}/edit', [\App\Controllers\HostTourFormController::class, 'edit']);
$router->post('/host/tours/{id}/edit', [\App\Controllers\HostTourFormController::class, 'update']);
$router->post('/host/tours/{id}/submit', [\App\Controllers\HostTourController::class, 'submit']);
$router->post('/host/tours/{id}/archive', [\App\Controllers\HostTourController::class, 'archive']);
$router->post('/host/tours/{id}/revision', [\App\Controllers\HostTourController::class, 'startRevision']);
$router->post('/host/tours/{id}/revision/discard', [\App\Controllers\HostTourController::class, 'discardRevision']);
$router->get('/host/tours/{id}/schedules', [\App\Controllers\HostScheduleController::class, 'index']);
$router->post('/host/tours/{id}/schedules', [\App\Controllers\HostScheduleController::class, 'store']);
$router->get('/host/schedules/{id}/edit', [\App\Controllers\HostScheduleController::class, 'edit']);
$router->post('/host/schedules/{id}/edit', [\App\Controllers\HostScheduleController::class, 'update']);
$router->get('/host/tours/{id}/content', [\App\Controllers\HostTourContentController::class, 'index']);
$router->post('/host/tours/{id}/content/images', [\App\Controllers\HostTourContentController::class, 'addImage']);
$router->post('/host/tours/{id}/content/images/{imageId}/delete', [\App\Controllers\HostTourContentController::class, 'deleteImage']);
$router->post('/host/tours/{id}/content/images/{imageId}/cover', [\App\Controllers\HostTourContentController::class, 'setCover']);
$router->post('/host/tours/{id}/content/itinerary', [\App\Controllers\HostTourContentController::class, 'saveItinerary']);
$router->post('/host/tours/{id}/content/itinerary/{itemId}/delete', [\App\Controllers\HostTourContentController::class, 'deleteItinerary']);
$router->post('/host/tours/{id}/content/inclusions', [\App\Controllers\HostTourContentController::class, 'addInclusion']);
$router->post('/host/tours/{id}/content/inclusions/{inclusionId}/delete', [\App\Controllers\HostTourContentController::class, 'deleteInclusion']);
$router->post('/host/tours/{id}/content/policy', [\App\Controllers\HostTourContentController::class, 'addPolicy']);
// Đơn vị xem đơn đặt trên tour của mình (chỉ đọc, không có route POST): xử lý đơn vẫn ở /admin.
$router->get('/host/bookings', [\App\Controllers\HostBookingController::class, 'index']);
$router->get('/host/bookings/{id}', [\App\Controllers\HostBookingController::class, 'show']);
// Doanh thu & chi trả (Nguyễn Tuấn Khôi): đơn vị xem khoản chi trả của mình (chỉ đọc) và tự khai tài khoản nhận tiền.
$router->get('/host/payouts', [\App\Controllers\HostPayoutController::class, 'index']);
$router->get('/host/payouts/{id}', [\App\Controllers\HostPayoutController::class, 'show']);
$router->get('/host/bank', [\App\Controllers\HostPayoutController::class, 'bank']);
$router->post('/host/bank', [\App\Controllers\HostPayoutController::class, 'saveBank']);

return $router;
