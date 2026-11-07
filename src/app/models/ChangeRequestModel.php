<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Yêu cầu đổi ngày / hủy tour của khách (US14-S5-02, FR-12 – Lê Trung Phong).
 * Chỉ chủ đơn xem và gửi được; điều kiện theo chính sách hủy đã chụp lúc đặt (bookings.policy_version).
 * Quản trị viên xử lý thủ công (AdminChangeRequestModel); chưa tự động hoàn tiền.
 * Procedure: LTP_sp_change_quote, LTP_sp_change_schedule_options, LTP_sp_change_request_create,
 *            LTP_sp_change_request_list (file 19).
 */
final class ChangeRequestModel
{
    public const REASON_MAX_LENGTH = 500;
    public const TYPES = ['cancel', 'change_date'];

    /**
     * Thông tin đơn và chính sách để khách xem trước khi gửi; null nếu không có đơn này trong tài khoản.
     *
     * @return array<string, mixed>|null booking_*, tour_*, starts_at, policy_*, free_until, in_free_window, paid_vnd,
     *         pending_request_id, pending_request_type, block_reason ('status', 'departed', 'pending_request', null),
     *         estimated_refund_vnd, can_request
     */
    public function quote(string $userId, string $code): ?array
    {
        return Database::call('LTP_sp_change_quote', [$userId, $code])[0] ?? null;
    }

    /**
     * Lịch khác của cùng tour còn mở bán và đủ chỗ cho số khách của đơn.
     *
     * @return list<array<string, mixed>> schedule_id, starts_at, ends_at, remaining
     */
    public function scheduleOptions(string $userId, string $code): array
    {
        return Database::call('LTP_sp_change_schedule_options', [$userId, $code]);
    }

    /**
     * Gửi yêu cầu. $scheduleId chỉ dùng khi đổi ngày.
     *
     * @return array<string, mixed> result (ok, forbidden, not_found, invalid, not_allowed, departed, pending_exists,
     *         schedule_unavailable, no_seats), field, request_id, estimated_refund_vnd
     */
    public function create(string $userId, string $code, string $type, ?string $scheduleId, string $reason): array
    {
        $rows = Database::call('LTP_sp_change_request_create', [$userId, $code, $type, $scheduleId, $reason]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }

    /**
     * Các yêu cầu đã gửi cho đơn, mới nhất trước.
     *
     * @return list<array<string, mixed>>
     */
    public function history(string $userId, string $code): array
    {
        return Database::call('LTP_sp_change_request_list', [$userId, $code]);
    }
}
