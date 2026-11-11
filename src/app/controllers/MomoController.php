<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\CustomerBookingModel;
use App\Models\MomoPaymentModel;
use App\Models\PaymentResultModel;
use App\Services\BookingMail;
use App\Services\MomoGateway;
use Core\Auth;
use Core\Controller;
use DateTimeImmutable;
use Throwable;

/**
 * Thanh toán MoMo, môi trường thử (Nguyễn Tuấn Khôi):
 *   - POST /payments/momo/{code}: tạo khoản MoMo cho đơn "Chờ thanh toán" rồi chuyển khách sang trang MoMo.
 *   - GET /payments/momo/return: MoMo chuyển khách về; kiểm tra chữ ký, tra cứu lại giao dịch bằng API query có chữ
 *     ký (IPN không tới được localhost), rồi mới ghi kết quả.
 *   - POST /payments/momo/ipn: MoMo gọi thẳng máy chủ (cần địa chỉ công khai); JSON, trả 204.
 * Các đường cùng ghi qua NTK_sp_payment_momo_result nên kết quả chỉ được ghi một lần.
 */
final class MomoController extends Controller
{
    /** Kích thước tối đa của nội dung IPN (byte). */
    private const IPN_MAX_BYTES = 16384;

    /** POST /payments/momo/{code} – _csrf */
    public function start(string $code): void
    {
        header('Cache-Control: no-store');
        $user = Auth::user();
        $code = strtoupper(trim($code));
        if ($user === null) {
            $this->redirect('/login?next=' . rawurlencode(preg_match(CustomerBookingModel::CODE_PATTERN, $code) ? '/bookings/' . $code . '/pay' : '/bookings'));
        }
        if ($user['role'] !== 'customer') {
            $this->redirect('/bookings');
        }
        if (!preg_match(CustomerBookingModel::CODE_PATTERN, $code)) {
            $this->notFound();
        }
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->redirect('/bookings/' . $code . '/pay?error=csrf');
        }
        $config = self::config();
        if (!MomoGateway::enabled($config)) {
            $this->redirect('/bookings/' . $code . '/pay?error=unavailable');
        }

        PaymentResultModel::expireHoldsQuietly();
        $model = new MomoPaymentModel();
        try {
            $returnUrl = self::absoluteUrl($config['momo_return_url'], '/payments/momo/return');
            $ipnUrl = self::absoluteUrl($config['momo_ipn_url'], '/payments/momo/ipn');
            $payment = $model->start($user['user_id'], $code, MomoGateway::MIN_VND, MomoGateway::MAX_VND);
        } catch (Throwable $exception) {
            error_log('LocalTour: không tạo được khoản MoMo: ' . $exception->getMessage());
            $this->redirect('/bookings/' . $code . '/pay?error=momo');
        }

        match ((string) $payment['result']) {
            'ok' => null,
            'invalid_amount' => $this->redirect('/bookings/' . $code . '/pay?error=momo_amount'),
            'expired' => $this->redirect('/bookings/' . $code . '?pay=expired'),
            'awaiting_reconciliation' => $this->redirect('/bookings/' . $code . '/pay/vietqr'),
            'not_found' => $this->notFound(),
            default => $this->redirect('/bookings/' . $code),
        };

        $orderId = (string) $payment['order_id'];
        $amountVnd = (int) $payment['amount_vnd'];
        $created = MomoGateway::create($config, [
            'order_id' => $orderId,
            'amount_vnd' => $amountVnd,
            'booking_code' => $code,
            'expires_at' => $payment['expires_at'] === null ? null : (string) $payment['expires_at'],
        ], $returnUrl, $ipnUrl, new DateTimeImmutable());

        if (!$created['ok']) {
            error_log('LocalTour: MoMo không tạo giao dịch ' . $orderId . ': ' . ($created['result_code'] ?? 'không có trả lời')
                . ' ' . $created['message']);
            // MoMo đã trả lời "không tạo" (mã khác 0): đóng khoản này để không còn khoản "Chưa thanh toán" treo.
            if ($created['result_code'] !== null && $created['result_code'] !== 0) {
                try {
                    $model->result($orderId, $amountVnd, (string) $created['result_code'], '', '', 'create');
                } catch (Throwable $exception) {
                    error_log('LocalTour: không đóng được khoản MoMo ' . $orderId . ': ' . $exception->getMessage());
                }
            }
            $this->redirect('/bookings/' . $code . '/pay?error=momo');
        }

        header('Location: ' . $created['pay_url'], true, 303);
        exit;
    }

    /** GET /payments/momo/return */
    public function result(): void
    {
        header('Cache-Control: no-store');
        $config = self::config();
        if (!MomoGateway::verifyResult($config, $_GET)) {
            $this->redirect('/bookings?pay=momo_invalid');
        }
        $orderId = self::field($_GET, 'orderId');
        if (!preg_match(MomoPaymentModel::ORDER_ID_PATTERN, $orderId)) {
            $this->redirect('/bookings?pay=momo_notfound');
        }
        $code = substr($orderId, 0, 8);

        // Chữ ký đúng mới tra cứu lại với MoMo; kết quả ghi theo MoMo trả lời, không theo query string.
        $status = MomoGateway::query($config, $orderId);
        if ($status === null || $status['outcome'] === 'pending') {
            $this->redirect('/bookings/' . $code . '?pay=momo_pending');
        }

        try {
            $row = (new MomoPaymentModel())->result($orderId, (int) $status['amount_vnd'], (string) $status['result_code'],
                (string) $status['trans_id'], (string) $status['pay_type'], 'return');
        } catch (Throwable $exception) {
            error_log('LocalTour: không ghi được kết quả MoMo: ' . $exception->getMessage());
            $this->redirect('/bookings?pay=error');
        }

        $code = (string) ($row['booking_code'] ?? '');
        if ($row['result'] === 'not_found' || $code === '') {
            $this->redirect('/bookings?pay=momo_notfound');
        }
        if ($row['result'] === 'invalid_amount') {
            $this->redirect('/bookings/' . $code . '?pay=momo_amount');
        }
        if ($row['payment_status'] !== 'paid') {
            $this->redirect('/bookings/' . $code . '?pay=momo_failed&rc=' . rawurlencode((string) $status['result_code']));
        }
        if ($row['result'] === 'ok' && $row['booking_status'] === 'confirmed') {
            BookingMail::sendConfirmed($code);
        }
        // Tiền tới sau khi đơn đã bị hủy / không còn chờ thanh toán: đã tạo yêu cầu hoàn tiền.
        $this->redirect('/bookings/' . $code . '?pay=' . (in_array($row['booking_status'], ['confirmed', 'completed'], true) ? 'momo' : 'momo_late'));
    }

    /** POST /payments/momo/ipn – JSON của MoMo; trả 204 khi đã nhận (kể cả đã ghi trước đó). */
    public function ipn(): never
    {
        header('Cache-Control: no-store');
        $raw = (string) file_get_contents('php://input', false, null, 0, self::IPN_MAX_BYTES + 1);
        $input = strlen($raw) <= self::IPN_MAX_BYTES ? json_decode($raw, true) : null;
        $config = self::config();

        if (!is_array($input) || !MomoGateway::verifyResult($config, $input)) {
            error_log('LocalTour: IPN MoMo sai chữ ký hoặc sai định dạng.');
            self::answer(400);
        }

        $orderId = self::field($input, 'orderId');
        $resultCode = self::field($input, 'resultCode');
        $amount = self::field($input, 'amount');
        if (!preg_match(MomoPaymentModel::ORDER_ID_PATTERN, $orderId) || !ctype_digit($resultCode)
            || MomoGateway::outcome((int) $resultCode) === 'pending') {
            // Không phải khoản của LocalTour hoặc chưa có kết quả cuối: không có gì để ghi.
            self::answer(204);
        }

        try {
            $row = (new MomoPaymentModel())->result($orderId, ctype_digit($amount) ? (int) $amount : -1, $resultCode,
                self::field($input, 'transId'), self::field($input, 'payType'), 'ipn');
        } catch (Throwable $exception) {
            error_log('LocalTour: IPN MoMo lỗi: ' . $exception->getMessage());
            // MoMo sẽ gửi lại khi không nhận được 204.
            self::answer(500);
        }

        if (($row['result'] ?? '') === 'ok' && ($row['booking_status'] ?? '') === 'confirmed') {
            BookingMail::sendConfirmed((string) $row['booking_code']);
        }
        self::answer(204);
    }

    private static function answer(int $status): never
    {
        http_response_code($status);
        exit;
    }

    private function notFound(): never
    {
        $this->render('bookings/message', [
            'title' => 'Không tìm thấy đơn',
            'activeNav' => 'bookings',
            'errorCode' => 'Lỗi 404',
            'heading' => 'Không tìm thấy đơn',
            'text' => 'Mã đơn không đúng hoặc đơn không thuộc tài khoản của bạn.',
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ], 404);
        exit;
    }

    /** @return array<string, string> */
    private static function config(): array
    {
        return require BASE_PATH . '/config/payment.php';
    }

    /**
     * Địa chỉ đầy đủ gửi MoMo: giá trị trong .env nếu có, ngược lại theo địa chỉ khách đang mở
     * (như Return URL của VNPay, chạy được cả localhost lẫn máy khác trong mạng nhóm).
     */
    private static function absoluteUrl(string $configured, string $path): string
    {
        if ($configured !== '') {
            return $configured;
        }
        $url = url($path);
        if (preg_match('#^https?://#i', $url)) {
            return $url;
        }
        $host = (string) ($_SERVER['HTTP_HOST'] ?? '');
        if (!preg_match('/^[A-Za-z0-9.\-]+(:\d{1,5})?$/D', $host)) {
            throw new \RuntimeException('Không xác định được địa chỉ trang web để MoMo trả kết quả.');
        }
        $https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';

        return ($https ? 'https://' : 'http://') . $host . $url;
    }

    /** @param array<mixed> $input */
    private static function field(array $input, string $key): string
    {
        $value = $input[$key] ?? '';

        return is_string($value) || is_int($value) ? trim((string) $value) : '';
    }
}
