<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Đối chiếu chuyển khoản VietQR của quản trị viên (Sprint 4, 4.5.3.2 – Nguyễn Minh Thức, Nguyễn Tuấn Khôi).
 * Procedure: NMT_sp_admin_payment_queue, NMT_sp_admin_payment_decide.
 */
final class AdminPaymentModel
{
    public const DECISIONS = ['confirm', 'reject'];
    public const NOTE_MAX_LENGTH = 255;

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
}
