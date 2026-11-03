<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\PaymentResultModel;
use App\Services\VnpayGateway;
use Core\Controller;
use Throwable;

/**
 * Kết quả thanh toán VNPay (Sprint 4 – Lê Trung Phong).
 *   - 4.5.2.1 Return URL: VNPay chuyển khách về; kiểm tra chữ ký, mã thanh toán và số tiền rồi mở lại trang đơn.
 *   - 4.5.2.2 IPN: VNPay gọi thẳng máy chủ (cần địa chỉ công khai); trả JSON theo định dạng VNPay.
 * Hai đường cùng ghi qua LTP_sp_payment_vnpay_result nên kết quả chỉ được ghi một lần dù tới bằng đường nào trước.
 */
final class VnpayController extends Controller
{
    /** Mã thanh toán gửi VNPay (vnp_TxnRef): mã đơn + P + số thứ tự. */
    private const REFERENCE_PATTERN = '/^LT\d{6}P\d{1,4}$/D';

    /** GET /payments/vnpay/return */
    public function result(): void
    {
        header('Cache-Control: no-store');
        $config = require BASE_PATH . '/config/payment.php';
        if (!VnpayGateway::verify($config, $_GET)) {
            $this->redirect('/bookings?pay=invalid');
        }

        try {
            $result = $this->record($_GET);
        } catch (Throwable $exception) {
            error_log('LocalTour: không ghi được kết quả VNPay: ' . $exception->getMessage());
            $this->redirect('/bookings?pay=error');
        }

        $code = (string) ($result['booking_code'] ?? '');
        if ($result['result'] === 'not_found' || $code === '') {
            $this->redirect('/bookings?pay=notfound');
        }
        if ($result['result'] === 'invalid_amount') {
            $this->redirect('/bookings/' . $code . '?pay=amount');
        }
        if ($result['payment_status'] !== 'paid') {
            $responseCode = self::field($_GET, 'vnp_ResponseCode');
            $this->redirect('/bookings/' . $code . '?pay=failed&rc=' . rawurlencode(preg_match('/^\d{2}$/D', $responseCode) ? $responseCode : '99'));
        }
        // Tiền tới sau khi đơn đã bị hủy / không còn chờ thanh toán: đã tạo yêu cầu hoàn tiền.
        $this->redirect('/bookings/' . $code . '?pay=' . (in_array($result['booking_status'], ['confirmed', 'completed'], true) ? 'success' : 'late'));
    }

    /** GET /payments/vnpay/ipn */
    public function ipn(): never
    {
        $config = require BASE_PATH . '/config/payment.php';
        $answer = ['RspCode' => '99', 'Message' => 'Unknow error'];

        if (!VnpayGateway::verify($config, $_GET)) {
            $answer = ['RspCode' => '97', 'Message' => 'Invalid signature'];
        } else {
            try {
                $result = $this->record($_GET);
                $answer = [
                    'ok' => ['RspCode' => '00', 'Message' => 'Confirm Success'],
                    'already' => ['RspCode' => '02', 'Message' => 'Order already confirmed'],
                    'not_found' => ['RspCode' => '01', 'Message' => 'Order not found'],
                    'invalid_amount' => ['RspCode' => '04', 'Message' => 'invalid amount'],
                ][$result['result']] ?? $answer;
            } catch (Throwable $exception) {
                error_log('LocalTour: IPN VNPay lỗi: ' . $exception->getMessage());
            }
        }

        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode($answer);
        exit;
    }

    /**
     * Ghi kết quả đã xác minh chữ ký. vnp_Amount là số tiền × 100; giá trị lạ được gửi -1 để procedure báo
     * invalid_amount.
     *
     * @param array<mixed> $input
     * @return array<string, mixed>
     */
    private function record(array $input): array
    {
        $reference = self::field($input, 'vnp_TxnRef');
        if (!preg_match(self::REFERENCE_PATTERN, $reference)) {
            return ['result' => 'not_found'];
        }

        $amount = self::field($input, 'vnp_Amount');
        $amountVnd = preg_match('/^\d{3,15}$/D', $amount) && str_ends_with($amount, '00') ? intdiv((int) $amount, 100) : -1;

        return (new PaymentResultModel())->vnpayResult(
            $reference,
            $amountVnd,
            mb_substr(self::field($input, 'vnp_ResponseCode'), 0, 10),
            mb_substr(self::field($input, 'vnp_TransactionStatus'), 0, 10),
            mb_substr(self::field($input, 'vnp_TransactionNo'), 0, 50),
            mb_substr(self::field($input, 'vnp_BankCode'), 0, 20)
        );
    }

    /** @param array<mixed> $input */
    private static function field(array $input, string $key): string
    {
        $value = $input[$key] ?? '';

        return is_string($value) ? trim($value) : '';
    }
}
