<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Duyệt tour của quản trị viên (FR-24, Lê Trung Phong).
 * Procedure: LTP_sp_admin_tour_list, LTP_sp_admin_tour_detail, LTP_sp_admin_tour_set_approval.
 */
final class AdminTourModel
{
    /**
     * Tour theo trạng thái duyệt ('' = mọi trạng thái), tour chờ duyệt trước.
     *
     * @return list<array<string, mixed>>
     */
    public function list(string $approvalStatus): array
    {
        return Database::call('LTP_sp_admin_tour_list', [$approvalStatus === '' ? null : $approvalStatus]);
    }

    /**
     * Tour ở mọi trạng thái duyệt; null nếu không có.
     *
     * @return array<string, mixed>|null
     */
    public function find(string $tourId): ?array
    {
        return Database::call('LTP_sp_admin_tour_detail', [$tourId])[0] ?? null;
    }

    /**
     * Phê duyệt ('approved') hoặc từ chối ('rejected', bắt buộc lý do) tour đang chờ duyệt.
     * Trả về result của procedure: ok, forbidden, not_found, invalid_transition, note_required.
     */
    public function setApproval(string $tourId, string $newStatus, string $actorUserId, string $note): string
    {
        $rows = Database::call('LTP_sp_admin_tour_set_approval', [$tourId, $newStatus, $actorUserId, $note === '' ? null : $note]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }
}
