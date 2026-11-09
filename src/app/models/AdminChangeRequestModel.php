<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Quản trị viên xem và xử lý thủ công yêu cầu đổi ngày / hủy tour (US14-S5-03, FR-12 – Lê Trung Phong).
 * Procedure: LTP_sp_admin_change_request_list, LTP_sp_admin_change_request_detail,
 *            LTP_sp_admin_change_request_decide (file 20).
 */
final class AdminChangeRequestModel
{
    public const NOTE_MAX_LENGTH = 500;
    public const FILTERS = ['pending' => 'Chờ xử lý', 'approved' => 'Đã đồng ý', 'rejected' => 'Đã từ chối', 'all' => 'Tất cả'];

    /**
     * Yêu cầu theo trạng thái ('' = tất cả) và theo đơn (null = mọi đơn): chờ xử lý trước.
     *
     * @return list<array<string, mixed>>
     */
    public function list(string $status = '', ?string $bookingId = null): array
    {
        return Database::call('LTP_sp_admin_change_request_list', [$status === '' ? null : $status, $bookingId]);
    }

    /** @return array<string, mixed>|null */
    public function find(string $requestId): ?array
    {
        return Database::call('LTP_sp_admin_change_request_detail', [$requestId])[0] ?? null;
    }

    /**
     * Đồng ý / từ chối. $refundVnd chỉ dùng khi đồng ý hủy (null = số dự kiến hoàn).
     *
     * @return array<string, mixed> result (ok, forbidden, not_found, invalid, already_handled, booking_closed,
     *         payment_in_review, schedule_unavailable, no_seats, tickets_missing), field, booking_status
     */
    public function decide(string $actorUserId, string $requestId, string $decision, string $note, ?int $refundVnd): array
    {
        $rows = Database::call('LTP_sp_admin_change_request_decide', [$actorUserId, $requestId, $decision, $note, $refundVnd]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }
}
