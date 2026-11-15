<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Bình luận trên trang tour và trang "Bình luận" của quản trị viên (CR3 – Nguyễn Minh Thức).
 * Procedure (file 35): NMT_sp_tour_comment_list, NMT_sp_tour_comment_count, NMT_sp_tour_comment_create,
 *            NMT_sp_tour_comment_delete_own, NMT_sp_admin_comment_list, NMT_sp_admin_comment_set_status.
 */
final class TourCommentModel
{
    public const CONTENT_MAX_LENGTH = 1000;
    public const REASON_MAX_LENGTH = 255;
    public const PAGE_SIZE = 10;
    public const ADMIN_PAGE_SIZE = 20;
    public const ADMIN_FILTERS = ['visible' => 'Đang hiển thị', 'hidden' => 'Đã ẩn', 'all' => 'Tất cả'];

    /**
     * Một trang bình luận đang hiển thị, mới nhất trước. $page bắt đầu từ 1.
     *
     * @return list<array<string, mixed>> comment_id, user_name, avatar_url, content, created_at, is_mine
     */
    public function list(string $tourId, ?string $viewerId, int $page): array
    {
        return Database::call('NMT_sp_tour_comment_list', [
            $tourId,
            $viewerId,
            self::PAGE_SIZE,
            ($page - 1) * self::PAGE_SIZE,
        ]);
    }

    /** @return array{tour_visible: int, total_count: int} */
    public function count(string $tourId): array
    {
        $row = Database::call('NMT_sp_tour_comment_count', [$tourId])[0] ?? [];

        return [
            'tour_visible' => (int) ($row['tour_visible'] ?? 0),
            'total_count' => (int) ($row['total_count'] ?? 0),
        ];
    }

    /**
     * @return array<string, mixed> result (ok, forbidden, not_found, invalid, rate_limited) và bình luận mới khi ok
     */
    public function create(string $userId, string $tourId, string $content): array
    {
        return Database::call('NMT_sp_tour_comment_create', [$userId, $tourId, $content])[0]
            ?? ['result' => 'invalid'];
    }

    /** @return array{affected_count: int, tour_id: ?string, total_count: ?int} */
    public function deleteOwn(string $commentId, string $userId): array
    {
        $row = Database::call('NMT_sp_tour_comment_delete_own', [$commentId, $userId])[0] ?? [];

        return [
            'affected_count' => (int) ($row['affected_count'] ?? 0),
            'tour_id' => isset($row['tour_id']) ? (string) $row['tour_id'] : null,
            'total_count' => isset($row['total_count']) ? (int) $row['total_count'] : null,
        ];
    }

    /**
     * Danh sách cho quản trị viên. $status '' = tất cả; $page bắt đầu từ 1.
     *
     * @return list<array<string, mixed>> kèm total_count (tổng số dòng khớp bộ lọc) ở mỗi dòng
     */
    public function adminList(string $status, string $keyword, int $page): array
    {
        return Database::call('NMT_sp_admin_comment_list', [
            $status === '' ? null : $status,
            $keyword === '' ? null : $keyword,
            self::ADMIN_PAGE_SIZE,
            ($page - 1) * self::ADMIN_PAGE_SIZE,
        ]);
    }

    /**
     * Ẩn ('hidden', cần lý do) hoặc hiện lại ('visible').
     *
     * @return string result: ok, forbidden, not_found, invalid, reason_required, unchanged
     */
    public function setStatus(string $commentId, string $adminId, string $status, ?string $reason): string
    {
        $row = Database::call('NMT_sp_admin_comment_set_status', [$commentId, $adminId, $status, $reason])[0] ?? [];

        return (string) ($row['result'] ?? 'not_found');
    }
}
