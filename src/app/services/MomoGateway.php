<?php

declare(strict_types=1);

namespace App\Services;

use DateTimeImmutable;

/**
 * Cổng thanh toán MoMo, API v2 (https://developers.momo.vn/v3/docs/payment/api/collection-link/) – Nguyễn Tuấn Khôi.
 * requestType = payWithMethod: trang MoMo cho khách chọn ví MoMo (quét QR), thẻ ATM nội địa hoặc thẻ quốc tế,
 * nên người kiểm thử thanh toán được ngay trên trình duyệt bằng thẻ ATM thử của MoMo.
 * Mọi yêu cầu và kết quả ký HMAC-SHA256 bằng secret key trên chuỗi key=value theo thứ tự cố định của MoMo
 * (giá trị để nguyên, không mã hóa URL).
 */
final class MomoGateway
{
    public const REQUEST_TYPE = 'payWithMethod';

    /** Giới hạn số tiền của payWithMethod: tối đa 50.000.000đ; thẻ ATM / thẻ quốc tế cần tối thiểu 10.000đ. */
    public const MIN_VND = 10000;
    public const MAX_VND = 50000000;

    /** Thời gian khách được ở trang MoMo cho một lần thanh toán (orderExpireTime, phút). */
    private const ATTEMPT_MINUTES = 15;

    /** Thời gian chờ gọi API MoMo (giây). */
    private const CONNECT_TIMEOUT = 10;
    private const TOTAL_TIMEOUT = 20;

    /** resultCode chưa phải kết quả cuối (đang chờ khách / đang xử lý) hoặc lỗi của yêu cầu tra cứu. */
    private const PENDING_CODES = [1000, 7000, 7002, 9000];

    /** Thứ tự trường trong chữ ký của trang trả về (redirectUrl) và IPN. */
    private const RESULT_FIELDS = [
        'amount', 'extraData', 'message', 'orderId', 'orderInfo', 'orderType', 'partnerCode', 'payType',
        'requestId', 'responseTime', 'resultCode', 'transId',
    ];

    /** Thứ tự trường trong chữ ký của kết quả API query. */
    private const QUERY_FIELDS = [
        'amount', 'extraData', 'message', 'orderId', 'partnerCode', 'payType', 'requestId', 'responseTime',
        'resultCode', 'transId',
    ];

    /** @param array<string, string> $config config/payment.php */
    public static function enabled(array $config): bool
    {
        return ($config['momo_partner_code'] ?? '') !== '' && ($config['momo_access_key'] ?? '') !== ''
            && ($config['momo_secret_key'] ?? '') !== '' && function_exists('curl_init')
            && preg_match('#^https://[A-Za-z0-9.\-]+(:\d{1,5})?(/|$)#', (string) ($config['momo_endpoint'] ?? '')) === 1;
    }

    public static function amountAllowed(int $amountVnd): bool
    {
        return $amountVnd >= self::MIN_VND && $amountVnd <= self::MAX_VND;
    }

    /**
     * Tạo giao dịch MoMo. Trả ['ok' => true, 'pay_url' => ...] hoặc ['ok' => false, 'result_code' => int|null
     * (null = không nhận được trả lời của MoMo), 'message' => ...].
     *
     * @param array<string, string> $config
     * @param array{order_id: string, amount_vnd: int, booking_code: string, expires_at: ?string} $order
     * @return array<string, mixed>
     */
    public static function create(array $config, array $order, string $returnUrl, string $ipnUrl, DateTimeImmutable $now): array
    {
        $minutes = self::ATTEMPT_MINUTES;
        if (($order['expires_at'] ?? null) !== null) {
            $left = intdiv((new DateTimeImmutable((string) $order['expires_at']))->getTimestamp() - $now->getTimestamp(), 60);
            $minutes = max(1, min($minutes, $left));
        }

        $fields = [
            'accessKey' => $config['momo_access_key'],
            'amount' => (string) $order['amount_vnd'],
            'extraData' => '',
            'ipnUrl' => $ipnUrl,
            'orderId' => $order['order_id'],
            'orderInfo' => 'Thanh toan don ' . $order['booking_code'],
            'partnerCode' => $config['momo_partner_code'],
            'redirectUrl' => $returnUrl,
            'requestId' => $order['order_id'],
            'requestType' => self::REQUEST_TYPE,
        ];
        $body = [
            'partnerCode' => $fields['partnerCode'],
            'partnerName' => 'LocalTour',
            'storeId' => 'LocalTour',
            'requestId' => $fields['requestId'],
            'amount' => (int) $order['amount_vnd'],
            'orderId' => $fields['orderId'],
            'orderInfo' => $fields['orderInfo'],
            'redirectUrl' => $returnUrl,
            'ipnUrl' => $ipnUrl,
            'requestType' => self::REQUEST_TYPE,
            'extraData' => '',
            'autoCapture' => true,
            'orderExpireTime' => $minutes,
            'lang' => 'vi',
            'signature' => self::sign($config, self::rawSignature($fields)),
        ];

        $answer = self::post($config, '/v2/gateway/api/create', $body);
        if ($answer === null) {
            return ['ok' => false, 'result_code' => null, 'message' => 'Không gọi được API tạo giao dịch MoMo.'];
        }
        $code = self::intField($answer, 'resultCode');
        $payUrl = is_string($answer['payUrl'] ?? null) ? $answer['payUrl'] : '';
        if ($code === 0 && str_starts_with($payUrl, 'https://') && ($answer['orderId'] ?? null) === $order['order_id']) {
            return ['ok' => true, 'pay_url' => $payUrl];
        }

        return ['ok' => false, 'result_code' => $code, 'message' => is_string($answer['message'] ?? null) ? $answer['message'] : ''];
    }

    /**
     * Tra cứu trạng thái giao dịch bằng API query có chữ ký. Trả null nếu không gọi được, trả lời không hợp lệ hoặc
     * sai chữ ký; ngược lại ['result_code' => int, 'amount_vnd' => int, 'trans_id' => string, 'pay_type' => string,
     * 'outcome' => 'paid' | 'failed' | 'pending'].
     *
     * @param array<string, string> $config
     * @return array<string, mixed>|null
     */
    public static function query(array $config, string $orderId): ?array
    {
        $requestId = 'Q' . time() . bin2hex(random_bytes(6));
        $raw = 'accessKey=' . $config['momo_access_key'] . '&orderId=' . $orderId
            . '&partnerCode=' . $config['momo_partner_code'] . '&requestId=' . $requestId;
        $answer = self::post($config, '/v2/gateway/api/query', [
            'partnerCode' => $config['momo_partner_code'],
            'requestId' => $requestId,
            'orderId' => $orderId,
            'lang' => 'vi',
            'signature' => self::sign($config, $raw),
        ]);
        if ($answer === null || ($answer['orderId'] ?? null) !== $orderId
            || ($answer['partnerCode'] ?? null) !== $config['momo_partner_code'] || ($answer['requestId'] ?? null) !== $requestId) {
            return null;
        }
        // Trả lời tới qua HTTPS đã kiểm tra chứng chỉ; có chữ ký thì chữ ký phải khớp.
        if (isset($answer['signature']) && !self::signatureMatches($config, $answer, self::QUERY_FIELDS)) {
            error_log('LocalTour: kết quả tra cứu MoMo sai chữ ký, orderId ' . $orderId);

            return null;
        }
        $code = self::intField($answer, 'resultCode');
        if ($code === null) {
            return null;
        }

        return [
            'result_code' => $code,
            'amount_vnd' => self::intField($answer, 'amount') ?? -1,
            'trans_id' => self::stringField($answer, 'transId'),
            'pay_type' => self::stringField($answer, 'payType'),
            'outcome' => self::outcome($code),
        ];
    }

    /**
     * Đúng khi dữ liệu trang trả về (query string) hoặc IPN (JSON) mang chữ ký MoMo của đúng partner này.
     *
     * @param array<string, string> $config
     * @param array<mixed> $input
     */
    public static function verifyResult(array $config, array $input): bool
    {
        if (!self::enabled($config) || self::stringField($input, 'partnerCode') !== $config['momo_partner_code']) {
            return false;
        }

        return self::signatureMatches($config, $input, self::RESULT_FIELDS);
    }

    /** resultCode → 'paid' (0), 'pending' (chưa có kết quả cuối) hoặc 'failed'. */
    public static function outcome(int $code): string
    {
        if ($code === 0) {
            return 'paid';
        }

        // Mã dưới 98 là lỗi của chính yêu cầu (sai định dạng, trùng requestId...), không phải kết quả giao dịch.
        return in_array($code, self::PENDING_CODES, true) || $code < 98 ? 'pending' : 'failed';
    }

    /** Thông báo cho khách theo resultCode của MoMo. */
    public static function message(string $code): string
    {
        return [
            '1006' => 'Bạn đã hủy giao dịch ở MoMo.',
            '1005' => 'Giao dịch MoMo đã hết hạn.',
            '1001' => 'Tài khoản không đủ số dư.',
            '1002' => 'Ngân hàng hoặc nguồn tiền đã từ chối giao dịch.',
            '1003' => 'Giao dịch MoMo đã bị hủy.',
            '1004' => 'Giao dịch vượt hạn mức thanh toán.',
            '1007' => 'Tài khoản MoMo chưa kích hoạt hoặc không tồn tại.',
            '1017' => 'Giao dịch MoMo đã bị hủy.',
            '4001' => 'Tài khoản MoMo đang bị hạn chế.',
            '4100' => 'Đăng nhập MoMo không thành công.',
        ][$code] ?? 'Thanh toán MoMo không thành công.';
    }

    /**
     * Chuỗi MoMo ký: accessKey rồi các trường theo $fields, dạng key=value nối bằng '&'.
     *
     * @param array<string, string> $fields Đã có accessKey và đúng thứ tự của MoMo.
     */
    public static function rawSignature(array $fields): string
    {
        $pairs = [];
        foreach ($fields as $key => $value) {
            $pairs[] = $key . '=' . $value;
        }

        return implode('&', $pairs);
    }

    /** @param array<string, string> $config */
    public static function sign(array $config, string $raw): string
    {
        return hash_hmac('sha256', $raw, $config['momo_secret_key']);
    }

    /**
     * @param array<string, string> $config
     * @param array<mixed> $input
     * @param list<string> $order
     */
    private static function signatureMatches(array $config, array $input, array $order): bool
    {
        $received = $input['signature'] ?? '';
        if (!is_string($received) || !preg_match('/^[0-9a-f]{64}$/iD', $received) || $config['momo_secret_key'] === '') {
            return false;
        }

        $fields = ['accessKey' => $config['momo_access_key']];
        foreach ($order as $key) {
            $value = $input[$key] ?? '';
            if (!is_string($value) && !is_int($value)) {
                return false;
            }
            $fields[$key] = (string) $value;
        }

        return hash_equals(self::sign($config, self::rawSignature($fields)), strtolower($received));
    }

    /**
     * Gửi JSON tới API MoMo; trả mảng JSON của MoMo hoặc null (lỗi mạng, hết thời gian, không phải JSON).
     *
     * @param array<string, string> $config
     * @param array<string, mixed> $body
     * @return array<string, mixed>|null
     */
    private static function post(array $config, string $path, array $body): ?array
    {
        $base = preg_replace('#/v2/gateway/api/(create|query)/?$#', '', rtrim($config['momo_endpoint'], '/'));
        $curl = curl_init($base . $path);
        if ($curl === false) {
            return null;
        }
        curl_setopt_array($curl, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => (string) json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            CURLOPT_HTTPHEADER => ['Content-Type: application/json; charset=UTF-8'],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => self::CONNECT_TIMEOUT,
            CURLOPT_TIMEOUT => self::TOTAL_TIMEOUT,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);
        $response = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $error = curl_error($curl);
        curl_close($curl);

        if (!is_string($response) || $response === '') {
            error_log('LocalTour: gọi API MoMo ' . $path . ' lỗi: ' . ($error !== '' ? $error : 'HTTP ' . $status));

            return null;
        }
        $data = json_decode($response, true);
        if (!is_array($data)) {
            error_log('LocalTour: API MoMo ' . $path . ' trả về HTTP ' . $status . ' không phải JSON.');

            return null;
        }

        return $data;
    }

    /** @param array<mixed> $input */
    private static function intField(array $input, string $key): ?int
    {
        $value = $input[$key] ?? null;
        if (is_int($value)) {
            return $value;
        }

        return is_string($value) && preg_match('/^-?\d{1,18}$/D', $value) ? (int) $value : null;
    }

    /** @param array<mixed> $input */
    private static function stringField(array $input, string $key): string
    {
        $value = $input[$key] ?? '';

        return is_string($value) || is_int($value) ? trim((string) $value) : '';
    }
}
