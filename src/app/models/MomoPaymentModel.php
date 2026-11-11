<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;
use Throwable;

/**
 * Thanh toán MoMo (môi trường thử – Nguyễn Tuấn Khôi): tạo khoản MoMo cho đơn "Chờ thanh toán", ghi kết quả MoMo đã
 * xác minh (idempotent) và danh sách khoản MoMo chưa rõ kết quả cho quản trị viên.
 * Procedure: NTK_sp_payment_momo_start, NTK_sp_payment_momo_result, NTK_sp_admin_momo_queue
 * (database/22_payment_momo_NTK.sql).
 */
final class MomoPaymentModel
{
    /** orderId gửi MoMo: mã thanh toán (mã đơn + P + số thứ tự) + '-' + 10 ký tự hex. */
    public const ORDER_ID_PATTERN = '/^LT\d{6}P\d{1,4}-[0-9a-f]{10}$/D';

    /**
     * Tạo khoản MoMo mới. Trả dòng kết quả: result (ok, not_found, not_payable, expired, awaiting_reconciliation,
     * invalid_amount), payment_id, reference, order_id, amount_vnd, expires_at.
     *
     * @return array<string, mixed>
     */
    public function start(string $userId, string $code, int $minVnd, int $maxVnd): array
    {
        return Database::call('NTK_sp_payment_momo_start', [$userId, $code, $minVnd, $maxVnd])[0] ?? ['result' => 'not_found'];
    }

    /**
     * Ghi kết quả MoMo đã xác minh. $source: return, ipn, admin, create. Trả dòng kết quả: result (ok, failed, already,
     * not_found, invalid_amount), booking_code, payment_status, booking_status.
     *
     * @return array<string, mixed>
     */
    public function result(string $orderId, int $amountVnd, string $resultCode, string $transId, string $payType, string $source): array
    {
        $rows = Database::call('NTK_sp_payment_momo_result', [
            $orderId,
            $amountVnd,
            mb_substr($resultCode, 0, 10),
            mb_substr($transId, 0, 100),
            mb_substr($payType, 0, 20),
            $source,
        ]);

        return $rows[0] ?? ['result' => 'not_found'];
    }

    /**
     * Khoản MoMo chưa rõ kết quả (MoMo chưa báo gì sau 15 phút, hoặc bị hệ thống đóng khi đơn quá hạn / bị hủy).
     * Chưa chạy file SQL 22 thì trả [] (trang quản trị vẫn mở được).
     *
     * @return list<array<string, mixed>>
     */
    public function queue(?string $bookingId = null, ?string $paymentId = null): array
    {
        try {
            return Database::call('NTK_sp_admin_momo_queue', [$bookingId, $paymentId]);
        } catch (Throwable $exception) {
            error_log('LocalTour: không đọc được khoản MoMo chưa rõ kết quả: ' . $exception->getMessage());

            return [];
        }
    }
}
