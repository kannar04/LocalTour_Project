<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Quản lý gói tour ở trang quản trị (US06-S5-01 – Lê Trung Phong): thêm, sửa giá, ngừng bán / bán lại.
 * Gói không bị xóa vì đơn cũ còn tham chiếu; gói ngừng bán không hiện cho khách.
 * Procedure: LTP_sp_admin_package_list, LTP_sp_admin_package_save (file 18).
 */
final class AdminPackageModel
{
    public const NAME_MAX_LENGTH = 100;
    public const DESCRIPTION_MAX_LENGTH = 500;
    public const PRICE_MAX = 100000000;
    public const SORT_MAX = 999;

    /**
     * Mọi gói của tour (cả gói ngừng bán), kèm số đơn đã đặt theo gói.
     *
     * @return list<array<string, mixed>> package_id, name, description, adult_price_vnd, child_price_vnd, active,
     *         sort_order, created_at, updated_at, booking_count, active_booking_count
     */
    public function list(string $tourId): array
    {
        return Database::call('LTP_sp_admin_package_list', [$tourId]);
    }

    /**
     * Thêm gói ($packageId null) hoặc sửa gói.
     *
     * @param array{name: string, description: string, adult_price: int, child_price: ?int, active: bool, sort_order: int} $data
     * @return array<string, mixed> result (ok, unchanged, forbidden, not_found, invalid, duplicate), field, package_id
     */
    public function save(string $actorUserId, string $tourId, ?string $packageId, array $data): array
    {
        $rows = Database::call('LTP_sp_admin_package_save', [
            $actorUserId,
            $tourId,
            $packageId,
            $data['name'],
            $data['description'] === '' ? null : $data['description'],
            $data['adult_price'],
            $data['child_price'],
            $data['active'] ? 1 : 0,
            $data['sort_order'],
        ]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }
}
