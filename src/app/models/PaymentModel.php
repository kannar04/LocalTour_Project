<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Thanh toán của khách hàng (Sprint 4: 4.5.1.2, 4.5.3.1 – Nguyễn Minh Thức): bắt đầu khoản VNPay / VietQR,
 * xem các khoản của đơn và báo đã chuyển khoản VietQR. Mọi procedure nhận user_id từ session.
 * Procedure: NMT_sp_payment_list, NMT_sp_payment_start, NMT_sp_payment_get, NMT_sp_payment_transfer_submit.
 */
final class PaymentModel
{
    public const METHODS = ['vnpay', 'vietqr'];

    /**
     * Các khoản thanh toán của đơn, mới trước.
     *
     * @return list<array<string, mixed>>
     */
    public function list(string $userId, string $code): array
    {
        return Database::call('NMT_sp_payment_list', [$userId, $code]);
    }

    /**
     * Bắt đầu thanh toán. Trả dòng kết quả: result (ok, not_found, not_payable, expired, awaiting_reconciliation,
     * invalid), payment_id, reference, amount_vnd, expires_at.
     *
     * @return array<string, mixed>
     */
    public function start(string $userId, string $code, string $method): array
    {
        return Database::call('NMT_sp_payment_start', [$userId, $code, $method])[0] ?? ['result' => 'not_found'];
    }

    /**
     * Khoản mới nhất của đơn theo phương thức; null nếu chưa có.
     *
     * @return array<string, mixed>|null
     */
    public function latest(string $userId, string $code, string $method): ?array
    {
        return Database::call('NMT_sp_payment_get', [$userId, $code, $method])[0] ?? null;
    }

    /** Báo đã chuyển khoản VietQR. Trả result: ok, already, not_found, not_payable, expired. */
    public function submitTransfer(string $userId, string $code, string $paymentId): string
    {
        $rows = Database::call('NMT_sp_payment_transfer_submit', [$userId, $code, $paymentId]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }
}
