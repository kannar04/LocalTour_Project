<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Gửi duyệt tour và "bản sửa" của tour đã duyệt (khu /host, Sprint 6 – Nguyễn Tuấn Khôi).
 * Đơn vị tổ chức tạo tour ở trạng thái "Nháp", gửi duyệt thì tour bị khóa cho tới khi quản trị viên xử lý.
 * Tour đã duyệt không sửa trực tiếp: đơn vị tạo một bản sửa (dòng tours ẩn, revision_of = tour gốc), sửa trên đó
 * rồi gửi duyệt; tour gốc giữ nguyên cho khách tới khi bản sửa được duyệt.
 * Procedure: 32_procedures_NTK_tour_revision.sql.
 */
final class TourRevisionModel
{
    /** @return string ok, forbidden, not_found, invalid_transition, original_not_approved */
    public function submit(string $userId, string $tourId): string
    {
        $rows = Database::call('NTK_sp_host_tour_submit', [$userId, $tourId]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /** @return string ok, forbidden, not_found, invalid_transition, has_bookings */
    public function archive(string $userId, string $tourId): string
    {
        $rows = Database::call('NTK_sp_host_tour_archive', [$userId, $tourId]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /**
     * Tạo bản sửa của tour đã duyệt (mỗi tour tối đa một bản sửa đang mở).
     *
     * @return array<string, mixed> result (ok, exists, forbidden, not_found, invalid_transition), revision_id
     */
    public function start(string $userId, string $tourId): array
    {
        return Database::call('NTK_sp_host_tour_revision_start', [$userId, $tourId])[0]
            ?? ['result' => 'not_found', 'revision_id' => null];
    }

    /**
     * Hủy bản sửa chưa gửi duyệt hoặc bị từ chối.
     *
     * @return array<string, mixed> result (ok, forbidden, not_found, invalid_transition), original_id
     */
    public function discard(string $userId, string $revisionId): array
    {
        return Database::call('NTK_sp_host_tour_revision_discard', [$userId, $revisionId])[0]
            ?? ['result' => 'not_found', 'original_id' => null];
    }

    /**
     * Thông tin tour đang hiển thị và thông tin trong bản sửa, để quản trị viên so sánh.
     *
     * @return array{current: array<string, mixed>, proposed: array<string, mixed>}|null null = không phải bản sửa
     */
    public function compare(string $revisionId): ?array
    {
        $sides = [];
        foreach (Database::call('NTK_sp_admin_tour_revision_compare', [$revisionId]) as $row) {
            $sides[(string) $row['side']] = $row;
        }

        return isset($sides['current'], $sides['proposed'])
            ? ['current' => $sides['current'], 'proposed' => $sides['proposed']]
            : null;
    }

    /** Còn dòng ảnh nào dùng đường dẫn này không (bản sửa lúc đầu dùng chung file ảnh với tour gốc). */
    public function imageInUse(string $url): bool
    {
        $rows = Database::call('NTK_sp_tour_image_in_use', [$url]);

        return (int) ($rows[0]['in_use'] ?? 0) === 1;
    }
}
