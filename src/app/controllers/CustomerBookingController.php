<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\BookingHistoryModel;
use App\Models\CustomerBookingModel;
use App\Models\PaymentModel;
use App\Models\PaymentResultModel;
use App\Services\VnpayGateway;
use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * "Đơn của tôi" (M4 mục 7, 8 – Nguyễn Tuấn Khôi): khách hàng xem các yêu cầu đặt tour đã gửi, trạng thái xử lý,
 * lý do từ chối / hủy, danh sách khách và chính sách hủy đã áp dụng.
 * Sprint 4: phụ thu / tùy chọn đã chọn, hạn và nút thanh toán, kết quả VNPay / VietQR (?pay=), voucher và lịch sử đơn.
 * Đơn quá hạn thanh toán được tự hủy trước khi mở trang (4.5.4.1).
 * Chế độ khách được chuyển tới đăng nhập; đơn của tài khoản khác hiện "Không tìm thấy đơn" (không lộ đơn).
 */
final class CustomerBookingController extends Controller
{
    /** Thông báo kết quả thanh toán trên trang đơn (?pay=). */
    private const PAY_NOTICES = [
        'success' => ['success', 'Thanh toán VNPay thành công. Đơn đã được xác nhận và voucher đã sẵn sàng.'],
        'transfer' => ['success', 'Đã ghi nhận bạn báo chuyển khoản. LocalTour sẽ đối chiếu rồi xác nhận đơn; đơn không bị tự hủy trong lúc chờ.'],
        'late' => ['error', 'VNPay báo đã trừ tiền nhưng đơn không còn chờ thanh toán. LocalTour sẽ hoàn tiền cho bạn.'],
        'amount' => ['error', 'Số tiền VNPay trả về không khớp với đơn nên chưa được ghi nhận. Vui lòng liên hệ LocalTour.'],
        'expired' => ['error', 'Đơn đã quá hạn thanh toán nên không thanh toán được nữa.'],
    ];

    /** Thông báo trên "Đơn của tôi" khi không xác định được đơn (?pay=). */
    private const LIST_NOTICES = [
        'invalid' => 'Kết quả thanh toán không hợp lệ (sai chữ ký VNPay) nên không được ghi nhận.',
        'notfound' => 'Không tìm thấy khoản thanh toán VNPay này.',
        'error' => 'Chưa ghi nhận được kết quả thanh toán. Vui lòng mở lại đơn sau ít phút.',
    ];

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

        PaymentResultModel::expireHoldsQuietly();
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
            'notice' => self::LIST_NOTICES[$this->query('pay')] ?? '',
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
            'extras' => $this->bookings->extras($userId, $code),
            'passengers' => $this->bookings->passengers($userId, $code),
            'payments' => (new PaymentModel())->list($userId, $code),
            'history' => (new BookingHistoryModel())->forCustomer($userId, $code),
            'justCreated' => $this->query('new') === '1',
            'payNotice' => $this->payNotice(),
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ]);
    }

    /** @return array{0: string, 1: string}|null [loại 'success' / 'error', nội dung] */
    private function payNotice(): ?array
    {
        $code = $this->query('pay');
        if ($code === 'failed') {
            $responseCode = $this->query('rc');

            return ['error', VnpayGateway::message(preg_match('/^\d{2}$/D', $responseCode) ? $responseCode : '99')
                . ' Bạn có thể thanh toán lại trước hạn giữ chỗ.'];
        }

        return self::PAY_NOTICES[$code] ?? null;
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
