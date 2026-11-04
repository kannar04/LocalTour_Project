<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Đối chiếu chuyển khoản VietQR của quản trị viên (Sprint 4, 4.5.3.2 – Nguyễn Minh Thức, Nguyễn Tuấn Khôi) và giao
 * dịch VNPay chưa rõ kết quả (Nguyễn Tuấn Khôi).
 * Procedure: NMT_sp_admin_payment_queue, NMT_sp_admin_payment_decide, NTK_sp_admin_vnpay_queue,
 * NTK_sp_admin_vnpay_decide.
 */
final class AdminPaymentModel
{
    public const DECISIONS = ['confirm', 'reject'];
    public const NOTE_MAX_LENGTH = 255;
    /** Mã giao dịch tại VNPay (vnp_TransactionNo): chữ số. */
    public const TXN_PATTERN = '/^[0-9]{1,20}$/';

    /**
     * Khoản VietQR khách đã báo chuyển khoản, báo trước lên trước.
     *
     * @return list<array<string, mixed>>
     */
    public function queue(): array
    {
        return Database::call('NMT_sp_admin_payment_queue');
    }

    /**
     * Đã nhận tiền ('confirm') hoặc không khớp ('reject', bắt buộc lý do). Trả dòng kết quả: result (ok, forbidden,
     * not_found, invalid, note_required, not_payable), booking_id.
     *
     * @return array<string, mixed>
     */
    public function decide(string $paymentId, string $decision, string $actorUserId, string $note): array
    {
        $rows = Database::call('NMT_sp_admin_payment_decide', [$paymentId, $decision, $actorUserId, $note === '' ? null : $note]);

        return $rows[0] ?? ['result' => 'not_found', 'booking_id' => null];
    }

    /**
     * Khoản VNPay chưa rõ kết quả (Return URL và IPN đều không về): quá 15 phút vẫn "Chưa thanh toán", hoặc bị hệ
     * thống đóng khi đơn quá hạn / bị hủy. $bookingId = null: mọi đơn.
     *
     * @return list<array<string, mixed>>
     */
    public function vnpayQueue(?string $bookingId = null): array
    {
        return Database::call('NTK_sp_admin_vnpay_queue', [$bookingId]);
    }

    /**
     * Kết quả quản trị viên tra trên cổng VNPay: 'confirm' (có giao dịch thành công, bắt buộc mã giao dịch VNPay) hoặc
     * 'reject' (không có giao dịch, bắt buộc lý do). Trả dòng kết quả: result (ok, forbidden, not_found, invalid,
     * txn_required, note_required, not_payable), booking_id.
     *
     * @return array<string, mixed>
     */
    public function vnpayDecide(string $paymentId, string $decision, string $actorUserId, string $txnNo, string $note): array
    {
        $rows = Database::call('NTK_sp_admin_vnpay_decide', [
            $paymentId, $decision, $actorUserId, $txnNo === '' ? null : $txnNo, $note === '' ? null : $note,
        ]);

        return $rows[0] ?? ['result' => 'not_found', 'booking_id' => null];
    }
}
