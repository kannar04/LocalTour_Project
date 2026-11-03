<?php

declare(strict_types=1);

namespace App\Services;

/**
 * Mã VietQR (NAPAS 247) chuyển khoản vào tài khoản nhận tiền trong config/payment.php
 * (Sprint 4, 4.5.3.1 – Nguyễn Minh Thức). Ứng dụng ngân hàng, MoMo, ZaloPay quét mã sẽ điền sẵn
 * tài khoản, số tiền và nội dung chuyển khoản.
 */
final class VietQr
{
    /** @param array<string, string> $config */
    public static function enabled(array $config): bool
    {
        return preg_match('/^[A-Za-z0-9]{2,20}$/D', $config['bank_id']) === 1
            && preg_match('/^[A-Za-z0-9]{4,19}$/D', $config['account_no']) === 1;
    }

    /**
     * Ảnh mã QR từ đường dẫn nhanh miễn phí của VietQR.
     *
     * @param array<string, string> $config
     */
    public static function imageUrl(array $config, int $amount, string $reference): string
    {
        $query = http_build_query(
            ['amount' => (string) $amount, 'addInfo' => $reference, 'accountName' => $config['account_name']],
            '',
            '&',
            PHP_QUERY_RFC3986
        );

        return 'https://img.vietqr.io/image/' . rawurlencode($config['bank_id']) . '-' . rawurlencode($config['account_no'])
            . '-compact2.png?' . $query;
    }
}
