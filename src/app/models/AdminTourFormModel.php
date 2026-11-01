<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Thêm / sửa thông tin tour ở trang quản trị (FR-13, NFR-07, Nguyễn Minh Thức).
 * Procedure: NMT_sp_admin_tour_form, NMT_sp_admin_tour_create, NMT_sp_admin_tour_update,
 *            NMT_sp_admin_destination_list, NMT_sp_admin_category_list (file 13).
 */
final class AdminTourFormModel
{
    /** Các ô của form theo đúng thứ tự tham số của procedure (sau actor / tour_id). */
    public const FIELDS = [
        'provider_id', 'destination_id', 'category_id', 'title', 'description', 'duration_minutes',
        'max_group_size', 'language_codes', 'pickup_mode', 'meeting_point', 'transport', 'guide_info',
        'dropoff_point', 'document_terms', 'meal_terms', 'voucher_terms', 'reschedule_terms', 'source_url',
        'verification_status',
    ];

    /** Giá trị gốc của tour để điền form sửa; null nếu không có. @return array<string, mixed>|null */
    public function find(string $tourId): ?array
    {
        return Database::call('NMT_sp_admin_tour_form', [$tourId])[0] ?? null;
    }

    /** @return list<array<string, mixed>> destination_id, name */
    public function destinations(): array
    {
        return Database::call('NMT_sp_admin_destination_list');
    }

    /** @return list<array<string, mixed>> category_id, name */
    public function categories(): array
    {
        return Database::call('NMT_sp_admin_category_list');
    }

    /**
     * @param array<string, string> $data các ô trong FIELDS, đã kiểm tra
     * @return array<string, mixed> result (ok, forbidden, invalid), field, tour_id
     */
    public function create(string $actorUserId, array $data): array
    {
        $rows = Database::call('NMT_sp_admin_tour_create', [$actorUserId, ...self::params($data)]);

        return $rows[0] ?? ['result' => 'invalid', 'field' => null];
    }

    /**
     * @param array<string, string> $data các ô trong FIELDS, đã kiểm tra
     * @return array<string, mixed> result (ok, unchanged, forbidden, not_found, invalid), field
     */
    public function update(string $actorUserId, string $tourId, array $data): array
    {
        $rows = Database::call('NMT_sp_admin_tour_update', [$actorUserId, $tourId, ...self::params($data)]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }

    /**
     * Ô để trống → NULL, số → int.
     *
     * @param array<string, string> $data
     * @return list<int|string|null>
     */
    private static function params(array $data): array
    {
        $params = [];
        foreach (self::FIELDS as $field) {
            $value = $data[$field] ?? '';
            if ($field === 'duration_minutes' || $field === 'max_group_size') {
                $params[] = (int) $value;
            } else {
                $params[] = $value === '' ? null : $value;
            }
        }

        return $params;
    }
}
