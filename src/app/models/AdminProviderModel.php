<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Đơn vị tổ chức (FR-13, Nguyễn Minh Thức): danh sách, thêm, sửa thông tin và trạng thái hợp tác.
 * Procedure: NMT_sp_admin_provider_list, NMT_sp_admin_provider_detail, NMT_sp_admin_provider_create,
 *            NMT_sp_admin_provider_update (file 13).
 */
final class AdminProviderModel
{
    public const NAME_MAX_LENGTH = 150;
    public const EMAIL_MAX_LENGTH = 150;

    /** Trạng thái hợp tác (providers.approval_status) theo thứ tự hiển thị trong form. */
    public const STATUSES = ['approved', 'pending', 'rejected'];

    /** @return list<array<string, mixed>> */
    public function list(): array
    {
        return Database::call('NMT_sp_admin_provider_list');
    }

    /** @return array<string, mixed>|null */
    public function find(string $providerId): ?array
    {
        return Database::call('NMT_sp_admin_provider_detail', [$providerId])[0] ?? null;
    }

    /**
     * @param array{business_name: string, contact_phone: string, email: string, approval_status: string} $data
     * @return array<string, mixed> result (ok, forbidden, invalid, email_taken), field, provider_id
     */
    public function create(string $actorUserId, array $data): array
    {
        $rows = Database::call('NMT_sp_admin_provider_create', [
            $actorUserId, $data['business_name'], $data['contact_phone'], $data['email'], $data['approval_status'],
        ]);

        return $rows[0] ?? ['result' => 'invalid', 'field' => null];
    }

    /**
     * @param array{business_name: string, contact_phone: string, email: string, approval_status: string} $data
     * @return array<string, mixed> result (ok, unchanged, forbidden, not_found, invalid, email_taken), field
     */
    public function update(string $actorUserId, string $providerId, array $data): array
    {
        $rows = Database::call('NMT_sp_admin_provider_update', [
            $actorUserId, $providerId, $data['business_name'], $data['contact_phone'], $data['email'], $data['approval_status'],
        ]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }
}
