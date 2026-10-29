<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;
use Throwable;

/**
 * Kết quả thanh toán và hạn giữ chỗ (Sprint 4 – Lê Trung Phong): ghi kết quả VNPay đã xác minh chữ ký
 * (4.5.2.1 Return URL, 4.5.2.2 IPN, idempotent) và tự hủy đơn quá hạn thanh toán 24 giờ (4.5.4.1).
 * Procedure: LTP_sp_payment_vnpay_result, LTP_sp_booking_expire_holds.
 */
final class PaymentResultModel
{
    /**
     * Ghi kết quả VNPay. Trả dòng kết quả: result (ok, already, not_found, invalid_amount), booking_code,
     * payment_status, booking_status.
     *
     * @return array<string, mixed>
     */
    public function vnpayResult(
        string $reference,
        int $amountVnd,
        string $responseCode,
        string $transactionStatus,
        string $transactionNo,
        string $bankCode
    ): array {
        $rows = Database::call('LTP_sp_payment_vnpay_result', [
            $reference,
            $amountVnd,
            $responseCode,
            $transactionStatus,
            $transactionNo,
            $bankCode,
        ]);

        return $rows[0] ?? ['result' => 'not_found'];
    }

    /** Hủy các đơn đã quá hạn giữ chỗ (trừ đơn có khoản VietQR chờ đối chiếu). Trả số đơn đã hủy. */
    public function expireHolds(): int
    {
        return (int) (Database::call('LTP_sp_booking_expire_holds')[0]['expired'] ?? 0);
    }

    /**
     * Chạy tự hủy trước khi mở trang đơn / trang quản trị, để trạng thái luôn đúng kể cả khi Task Scheduler
     * chưa chạy scripts/expire_holds.php. Lỗi chỉ ghi log, không làm hỏng trang.
     */
    public static function expireHoldsQuietly(): void
    {
        try {
            (new self())->expireHolds();
        } catch (Throwable $exception) {
            error_log('LocalTour: không tự hủy được đơn quá hạn: ' . $exception->getMessage());
        }
    }
}
