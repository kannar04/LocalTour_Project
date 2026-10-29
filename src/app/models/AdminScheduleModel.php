<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Lịch khởi hành, sức chứa và giá vé theo lịch ở trang quản trị (FR-14, Nguyễn Minh Thức).
 * Procedure: NMT_sp_admin_schedule_list, NMT_sp_admin_schedule_detail, NMT_sp_admin_schedule_create,
 *            NMT_sp_admin_schedule_update, NMT_sp_admin_schedule_log_list (file 13).
 */
final class AdminScheduleModel
{
    public const CAPACITY_MAX = 500;
    public const PRICE_MAX = 100000000;

    /** Lịch của tour: chưa khởi hành trước, rồi lịch đã qua. @return list<array<string, mixed>> */
    public function list(string $tourId): array
    {
        return Database::call('NMT_sp_admin_schedule_list', [$tourId]);
    }

    /** @return array<string, mixed>|null */
    public function find(string $scheduleId): ?array
    {
        return Database::call('NMT_sp_admin_schedule_detail', [$scheduleId])[0] ?? null;
    }

    /** Lịch sử thêm / sửa các lịch của tour, mới nhất trước. @return list<array<string, mixed>> */
    public function logs(string $tourId): array
    {
        return Database::call('NMT_sp_admin_schedule_log_list', [$tourId]);
    }

    /**
     * @param array{starts_at: string, ends_at: string, capacity: int, adult_price: int, child_price: ?int} $data
     *        starts_at / ends_at dạng 'Y-m-d H:i:s'
     * @return array<string, mixed> result (ok, forbidden, not_found, invalid), field, schedule_id
     */
    public function create(string $actorUserId, string $tourId, array $data): array
    {
        $rows = Database::call('NMT_sp_admin_schedule_create', [
            $actorUserId, $tourId, $data['starts_at'], $data['ends_at'], $data['capacity'], $data['adult_price'], $data['child_price'],
        ]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }

    /**
     * @param array{starts_at: string, ends_at: string, capacity: int, adult_price: int, child_price: ?int, status: string} $data
     * @return array<string, mixed> result (ok, unchanged, forbidden, not_found, invalid, completed, departed,
     *         capacity_below_held, has_bookings), field, status, held, active_bookings
     */
    public function update(string $actorUserId, string $scheduleId, array $data): array
    {
        $rows = Database::call('NMT_sp_admin_schedule_update', [
            $actorUserId, $scheduleId, $data['starts_at'], $data['ends_at'], $data['capacity'],
            $data['adult_price'], $data['child_price'], $data['status'],
        ]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }
}
