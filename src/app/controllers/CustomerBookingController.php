<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\CustomerBookingModel;
use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * "Đơn của tôi" (M4 mục 7, 8 – Nguyễn Tuấn Khôi): khách hàng xem các yêu cầu đặt tour đã gửi, trạng thái xử lý,
 * lý do từ chối / hủy, danh sách khách và chính sách hủy đã áp dụng.
 * Chế độ khách được chuyển tới đăng nhập; đơn của tài khoản khác hiện "Không tìm thấy đơn" (không lộ đơn).
 */
final class CustomerBookingController extends Controller
{
    private CustomerBookingModel $bookings;

    /** @var array{user_id: string, name: string, email: string, role: string} */
    private array $user;

    public function __construct()
    {
        // Trang có thông tin cá nhân của khách: trình duyệt không được lưu cache.
        header('Cache-Control: no-store');
        $this->bookings = new CustomerBookingModel();

        $user = Auth::user();
        if ($user === null) {
            $uri = $_SERVER['REQUEST_URI'] ?? '/bookings';
            $this->redirect('/login?next=' . rawurlencode(Router::pathFromUri($uri)));
        }
        $this->user = $user;
    }

    /** GET /bookings */
    public function index(): void
    {
        if ($this->user['role'] !== 'customer') {
            $this->renderNotCustomer();
            return;
        }

        $this->render('bookings/index', [
            'title' => 'Đơn của tôi',
            'activeNav' => 'bookings',
            'bookings' => $this->bookings->list($this->user['user_id']),
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ]);
    }

    /** GET /bookings/{code}?new=1 (new=1: vừa gửi yêu cầu xong) */
    public function show(string $code): void
    {
        if ($this->user['role'] !== 'customer') {
            $this->renderNotCustomer();
            return;
        }

        $code = strtoupper(trim($code));
        $userId = $this->user['user_id'];
        $booking = preg_match(CustomerBookingModel::CODE_PATTERN, $code) ? $this->bookings->find($userId, $code) : null;
        if ($booking === null) {
            $this->render('bookings/message', [
                'title' => 'Không tìm thấy đơn',
                'activeNav' => 'bookings',
                'errorCode' => 'Lỗi 404',
                'heading' => 'Không tìm thấy đơn',
                'text' => 'Mã đơn không đúng hoặc đơn không thuộc tài khoản của bạn.',
                'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
            ], 404);
            return;
        }

        $this->render('bookings/show', [
            'title' => 'Đơn ' . $booking['code'],
            'activeNav' => 'bookings',
            'booking' => $booking,
            'lines' => $this->bookings->lines($userId, $code),
            'passengers' => $this->bookings->passengers($userId, $code),
            'justCreated' => $this->query('new') === '1',
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ]);
    }

    /** Tài khoản quản trị mở "Đơn của tôi": không có đơn khách hàng. */
    private function renderNotCustomer(): void
    {
        $this->render('bookings/message', [
            'title' => 'Không có đơn',
            'errorCode' => 'Lỗi 403',
            'heading' => 'Tài khoản này không có đơn đặt tour',
            'text' => '"Đơn của tôi" chỉ dành cho tài khoản khách hàng. Yêu cầu đặt tour được quản lý ở trang quản trị.',
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ], 403);
    }
}
