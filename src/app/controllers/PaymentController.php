<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\CustomerBookingModel;
use App\Models\PaymentModel;
use App\Models\PaymentResultModel;
use App\Services\VietQr;
use App\Services\VnpayGateway;
use Core\Auth;
use Core\Controller;
use Core\Router;
use DateTimeImmutable;
use Throwable;

/**
 * Thanh toán đơn đặt tour của khách hàng (Sprint 4 – Nguyễn Minh Thức): chọn phương thức (4.5.1.1), tạo yêu cầu
 * VNPay có chữ ký đúng đơn, số tiền và hạn (4.5.1.2, FR-17), mã VietQR đúng số tiền và mã thanh toán (4.5.3.1)
 * rồi báo đã chuyển khoản để quản trị viên đối chiếu (4.5.3.2).
 * Chỉ đơn "Chờ thanh toán" còn hạn giữ chỗ mới thanh toán được; số tiền là tổng giá quản trị viên đã chốt.
 */
final class PaymentController extends Controller
{
    private const PAGE_STYLES = ['css/tour-detail.css', 'css/booking.css'];

    /** Lỗi hiện trên trang chọn phương thức (?error=). */
    private const ERRORS = [
        'csrf' => 'Phiên làm việc đã hết hạn, vui lòng thử lại.',
        'unavailable' => 'Phương thức này đang tạm ngưng, vui lòng chọn phương thức khác.',
        'vnpay' => 'Chưa tạo được yêu cầu thanh toán VNPay, vui lòng thử lại.',
    ];

    private CustomerBookingModel $bookings;
    private PaymentModel $payments;

    /** @var array{user_id: string, name: string, email: string, role: string} */
    private array $user;

    public function __construct()
    {
        header('Cache-Control: no-store');
        $this->bookings = new CustomerBookingModel();
        $this->payments = new PaymentModel();

        $user = Auth::user();
        if ($user === null) {
            $uri = $_SERVER['REQUEST_URI'] ?? '/bookings';
            $this->redirect('/login?next=' . rawurlencode(Router::pathFromUri($uri)));
        }
        if ($user['role'] !== 'customer') {
            $this->redirect('/bookings');
        }
        $this->user = $user;

        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /bookings/{code}/pay – chọn VNPay hoặc VietQR. */
    public function checkout(string $code): void
    {
        $booking = $this->findOrFail($code);
        $code = (string) $booking['code'];
        if ($booking['status'] !== 'awaiting_payment') {
            $this->redirect('/bookings/' . $code);
        }
        $transfer = $this->payments->latest($this->user['user_id'], $code, 'vietqr');
        if ($transfer !== null && $transfer['status'] === 'awaiting_reconciliation') {
            $this->redirect('/bookings/' . $code . '/pay/vietqr');
        }

        $config = self::config();
        $this->render('payments/checkout', [
            'title' => 'Thanh toán đơn ' . $code,
            'activeNav' => 'bookings',
            'booking' => $booking,
            'lines' => $this->bookings->lines($this->user['user_id'], $code),
            'extras' => $this->bookings->extras($this->user['user_id'], $code),
            'vnpayEnabled' => VnpayGateway::enabled($config),
            'vietqrEnabled' => VietQr::enabled($config),
            'error' => self::ERRORS[$this->query('error')] ?? '',
            'pageStyles' => self::PAGE_STYLES,
        ]);
    }

    /** POST /bookings/{code}/pay/vnpay – tạo khoản VNPay mới rồi chuyển khách sang cổng VNPay. */
    public function startVnpay(string $code): void
    {
        $booking = $this->findOrFail($code);
        $code = (string) $booking['code'];
        $config = self::config();
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->redirect('/bookings/' . $code . '/pay?error=csrf');
        }
        if (!VnpayGateway::enabled($config)) {
            $this->redirect('/bookings/' . $code . '/pay?error=unavailable');
        }

        try {
            $returnUrl = self::returnUrl($config);
        } catch (Throwable $exception) {
            error_log('LocalTour: ' . $exception->getMessage());
            $this->redirect('/bookings/' . $code . '/pay?error=vnpay');
        }

        $payment = $this->payments->start($this->user['user_id'], $code, 'vnpay');
        if ($payment['result'] !== 'ok') {
            $this->redirectResult($code, (string) $payment['result']);
        }

        $target = VnpayGateway::paymentUrl($config, [
            'reference' => (string) $payment['reference'],
            'amount_vnd' => (int) $payment['amount_vnd'],
            'booking_code' => $code,
            'expires_at' => $payment['expires_at'] === null ? null : (string) $payment['expires_at'],
        ], $returnUrl, self::clientIp(), new DateTimeImmutable());

        header('Location: ' . $target, true, 303);
        exit;
    }

    /** POST /bookings/{code}/pay/vietqr – lấy (hoặc tạo) khoản VietQR rồi mở trang mã QR. */
    public function startVietqr(string $code): void
    {
        $booking = $this->findOrFail($code);
        $code = (string) $booking['code'];
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->redirect('/bookings/' . $code . '/pay?error=csrf');
        }
        if (!VietQr::enabled(self::config())) {
            $this->redirect('/bookings/' . $code . '/pay?error=unavailable');
        }

        $payment = $this->payments->start($this->user['user_id'], $code, 'vietqr');
        $this->redirectResult($code, (string) $payment['result'], '/bookings/' . $code . '/pay/vietqr');
    }

    /** GET /bookings/{code}/pay/vietqr – mã QR, thông tin chuyển khoản và nút "Tôi đã chuyển khoản". */
    public function transfer(string $code): void
    {
        $booking = $this->findOrFail($code);
        $code = (string) $booking['code'];
        $payment = $this->payments->latest($this->user['user_id'], $code, 'vietqr');
        $waiting = $payment !== null && $payment['status'] === 'awaiting_reconciliation';
        $payable = $payment !== null && $payment['status'] === 'pending' && $booking['status'] === 'awaiting_payment'
            && (int) $booking['hold_expired'] === 0 && (int) $payment['amount_vnd'] === (int) $booking['total_vnd'];
        if (!$waiting && !$payable) {
            $this->redirect($booking['status'] === 'awaiting_payment' ? '/bookings/' . $code . '/pay' : '/bookings/' . $code);
        }

        $config = self::config();
        $this->render('payments/transfer', [
            'title' => 'Chuyển khoản VietQR · ' . $code,
            'activeNav' => 'bookings',
            'booking' => $booking,
            'payment' => $payment,
            'waiting' => $waiting,
            'bank' => $config,
            'qrUrl' => VietQr::enabled($config) ? VietQr::imageUrl($config, (int) $payment['amount_vnd'], (string) $payment['reference']) : '',
            'error' => self::ERRORS[$this->query('error')] ?? '',
            'pageStyles' => self::PAGE_STYLES,
        ]);
    }

    /** POST /bookings/{code}/pay/vietqr/submit – payment_id, _csrf: khách báo đã chuyển khoản. */
    public function submitTransfer(string $code): void
    {
        $booking = $this->findOrFail($code);
        $code = (string) $booking['code'];
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->redirect('/bookings/' . $code . '/pay/vietqr?error=csrf');
        }

        $paymentId = self::parseUuid($this->input('payment_id'));
        $result = $paymentId === null ? 'not_found' : $this->payments->submitTransfer($this->user['user_id'], $code, $paymentId);

        match ($result) {
            'ok', 'already' => $this->redirect('/bookings/' . $code . '?pay=transfer'),
            'expired' => $this->redirect('/bookings/' . $code . '?pay=expired'),
            'not_payable' => $this->redirect('/bookings/' . $code),
            default => $this->redirect('/bookings/' . $code . '/pay'),
        };
    }

    /** Kết quả NMT_sp_payment_start khác 'ok' (hoặc 'ok' với $okPath) → trang phù hợp. */
    private function redirectResult(string $code, string $result, string $okPath = ''): never
    {
        match ($result) {
            'ok' => $this->redirect($okPath !== '' ? $okPath : '/bookings/' . $code . '/pay'),
            'expired' => $this->redirect('/bookings/' . $code . '?pay=expired'),
            'awaiting_reconciliation' => $this->redirect('/bookings/' . $code . '/pay/vietqr'),
            'not_found' => $this->notFound(),
            default => $this->redirect('/bookings/' . $code),
        };
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $code): array
    {
        $code = strtoupper(trim($code));
        $booking = preg_match(CustomerBookingModel::CODE_PATTERN, $code) ? $this->bookings->find($this->user['user_id'], $code) : null;

        return $booking ?? $this->notFound();
    }

    private function notFound(): never
    {
        $this->render('bookings/message', [
            'title' => 'Không tìm thấy đơn',
            'activeNav' => 'bookings',
            'errorCode' => 'Lỗi 404',
            'heading' => 'Không tìm thấy đơn',
            'text' => 'Mã đơn không đúng hoặc đơn không thuộc tài khoản của bạn.',
            'pageStyles' => self::PAGE_STYLES,
        ], 404);
        exit;
    }

    /** @return array<string, string> */
    private static function config(): array
    {
        return require BASE_PATH . '/config/payment.php';
    }

    /**
     * Địa chỉ VNPay trả khách về: VNPAY_RETURN_URL nếu có, ngược lại theo địa chỉ khách đang mở
     * (chạy được cả localhost lẫn máy khác trong mạng nhóm).
     *
     * @param array<string, string> $config
     */
    private static function returnUrl(array $config): string
    {
        if ($config['vnpay_return_url'] !== '') {
            return $config['vnpay_return_url'];
        }
        $path = url('/payments/vnpay/return');
        if (preg_match('#^https?://#i', $path)) {
            return $path;
        }
        $host = (string) ($_SERVER['HTTP_HOST'] ?? '');
        if (!preg_match('/^[A-Za-z0-9.\-]+(:\d{1,5})?$/D', $host)) {
            throw new \RuntimeException('Không xác định được địa chỉ trang web để VNPay trả kết quả.');
        }
        $https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';

        return ($https ? 'https://' : 'http://') . $host . $path;
    }

    private static function clientIp(): string
    {
        $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '');

        return filter_var($ip, FILTER_VALIDATE_IP) !== false ? $ip : '127.0.0.1';
    }
}
