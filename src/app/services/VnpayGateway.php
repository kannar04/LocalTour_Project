<?php

declare(strict_types=1);

namespace App\Services;

use DateTimeImmutable;
use DateTimeZone;

/**
 * Cổng thanh toán VNPay, API 2.1.0 (https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html).
 * Sprint 4: 4.5.1.2 tạo yêu cầu có chữ ký (Nguyễn Minh Thức), 4.5.2.1 kiểm tra chữ ký kết quả (Lê Trung Phong).
 * Yêu cầu và kết quả được ký HMAC-SHA512 trên các trường vnp_* sắp theo tên và mã hóa URL.
 */
final class VnpayGateway
{
    /** Thời gian khách được ở trang VNPay cho một lần thanh toán. */
    private const ATTEMPT_MINUTES = 15;

    /** @param array<string, string> $config config/payment.php */
    public static function enabled(array $config): bool
    {
        return $config['vnpay_tmn_code'] !== '' && $config['vnpay_hash_secret'] !== ''
            && filter_var($config['vnpay_pay_url'], FILTER_VALIDATE_URL) !== false;
    }

    /**
     * Địa chỉ chuyển khách sang VNPay cho một khoản thanh toán. Hết hạn sau 15 phút, hoặc sớm hơn nếu hạn giữ chỗ đến trước.
     *
     * @param array<string, string> $config
     * @param array{reference: string, amount_vnd: int|string, booking_code: string, expires_at: ?string} $payment
     */
    public static function paymentUrl(array $config, array $payment, string $returnUrl, string $clientIp, DateTimeImmutable $now): string
    {
        $zone = new DateTimeZone('Asia/Ho_Chi_Minh');
        $now = $now->setTimezone($zone);
        $expires = $now->modify('+' . self::ATTEMPT_MINUTES . ' minutes');
        if (($payment['expires_at'] ?? null) !== null) {
            $holdUntil = new DateTimeImmutable((string) $payment['expires_at'], $zone);
            $expires = min($expires, $holdUntil);
        }

        $fields = [
            'vnp_Version' => '2.1.0',
            'vnp_Command' => 'pay',
            'vnp_TmnCode' => $config['vnpay_tmn_code'],
            'vnp_Amount' => (string) ((int) $payment['amount_vnd'] * 100),
            'vnp_CurrCode' => 'VND',
            'vnp_TxnRef' => (string) $payment['reference'],
            'vnp_OrderInfo' => 'Thanh toan don ' . $payment['booking_code'],
            'vnp_OrderType' => 'other',
            'vnp_Locale' => 'vn',
            'vnp_ReturnUrl' => $returnUrl,
            'vnp_IpAddr' => $clientIp,
            'vnp_CreateDate' => $now->format('YmdHis'),
            'vnp_ExpireDate' => $expires->format('YmdHis'),
        ];
        $query = self::signedData($fields);

        return $config['vnpay_pay_url'] . '?' . $query . '&vnp_SecureHash=' . hash_hmac('sha512', $query, $config['vnpay_hash_secret']);
    }

    /**
     * Đúng khi các trường vnp_* (query của Return URL hoặc IPN) mang chữ ký VNPay của đúng website này.
     *
     * @param array<string, string> $config
     * @param array<mixed> $input
     */
    public static function verify(array $config, array $input): bool
    {
        $received = $input['vnp_SecureHash'] ?? '';
        if (!is_string($received) || $received === '' || $config['vnpay_hash_secret'] === '') {
            return false;
        }

        $fields = [];
        foreach ($input as $key => $value) {
            if (!is_string($key) || !str_starts_with($key, 'vnp_') || $key === 'vnp_SecureHash' || $key === 'vnp_SecureHashType') {
                continue;
            }
            if (!is_string($value)) {
                return false;
            }
            $fields[$key] = $value;
        }
        if (($fields['vnp_TmnCode'] ?? '') !== $config['vnpay_tmn_code']) {
            return false;
        }

        return hash_equals(hash_hmac('sha512', self::signedData($fields), $config['vnpay_hash_secret']), strtolower($received));
    }

    /**
     * Chuỗi VNPay ký: các cặp key=value sắp theo key, cả hai mã hóa URL, nối bằng '&'.
     *
     * @param array<string, string> $fields
     */
    public static function signedData(array $fields): string
    {
        ksort($fields);
        $pairs = [];
        foreach ($fields as $key => $value) {
            $pairs[] = urlencode((string) $key) . '=' . urlencode((string) $value);
        }

        return implode('&', $pairs);
    }

    /** Thông báo cho khách theo mã kết quả VNPay (vnp_ResponseCode). */
    public static function message(string $code): string
    {
        return [
            '24' => 'Bạn đã hủy giao dịch ở VNPay.',
            '11' => 'Đã hết thời gian chờ thanh toán ở VNPay.',
            '51' => 'Tài khoản không đủ số dư.',
            '13' => 'Sai mã OTP.',
            '12' => 'Thẻ hoặc tài khoản đang bị khóa.',
            '09' => 'Thẻ hoặc tài khoản chưa đăng ký Internet Banking.',
            '10' => 'Xác thực thông tin thẻ hoặc tài khoản sai quá 3 lần.',
            '65' => 'Tài khoản đã vượt hạn mức giao dịch trong ngày.',
            '75' => 'Ngân hàng thanh toán đang bảo trì.',
        ][$code] ?? 'Thanh toán VNPay không thành công.';
    }
}
