<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Đánh giá sao (FR-16, CR3 – Nguyễn Tuấn Khôi): khách hàng đánh giá đơn đã hoàn thành, quản trị viên duyệt
 * trước khi đánh giá hiện trên trang tour.
 * Procedure: NTK_sp_review_get, NTK_sp_review_save, NTK_sp_review_state_list, NTK_sp_admin_review_list,
 *            NTK_sp_admin_review_summary, NTK_sp_admin_review_decide (file 36).
 */
final class ReviewModel
{
    public const RATING_MIN = 1;
    public const RATING_MAX = 5;
    public const CONTENT_MIN_LENGTH = 10;
    public const CONTENT_MAX_LENGTH = 1000;
    public const NOTE_MAX_LENGTH = 255;
    public const KEYWORD_MAX_LENGTH = 100;
    public const PAGE_SIZE = 20;

    /** Bộ lọc của trang quản trị: giá trị ?status= => nhãn. */
    public const FILTERS = ['pending' => 'Chờ duyệt', 'approved' => 'Đã duyệt', 'rejected' => 'Không được duyệt', 'all' => 'Tất cả'];

    /** Nhãn trạng thái kiểm duyệt cho khách hàng và quản trị viên. */
    public const STATUS_LABELS = ['pending' => 'Chờ duyệt', 'approved' => 'Đã đăng', 'rejected' => 'Không được duyệt'];

    /** Lời mô tả ngắn theo số sao (bộ chọn sao trên trang đơn). */
    public const RATING_WORDS = [1 => 'Tệ', 2 => 'Chưa tốt', 3 => 'Bình thường', 4 => 'Tốt', 5 => 'Tuyệt vời'];

    /**
     * Đơn của tài khoản kèm đánh giá (cột đánh giá NULL nếu chưa có); null nếu không có đơn này.
     *
     * @return array<string, mixed>|null
     */
    public function forBooking(string $userId, string $code): ?array
    {
        return Database::call('NTK_sp_review_get', [$userId, $code])[0] ?? null;
    }

    /**
     * Gửi mới hoặc sửa đánh giá.
     *
     * @return array<string, mixed> result (created, updated, forbidden, not_found, not_completed, locked, invalid), field
     */
    public function save(string $userId, string $code, int $rating, string $content): array
    {
        return Database::call('NTK_sp_review_save', [$userId, $code, $rating, $content])[0]
            ?? ['result' => 'not_found', 'field' => null];
    }

    /**
     * Trạng thái đánh giá theo đơn của tài khoản (chỉ đơn đã có đánh giá).
     *
     * @return array<string, string> booking_id => moderation_status
     */
    public function statesForUser(string $userId): array
    {
        $states = [];
        foreach (Database::call('NTK_sp_review_state_list', [$userId]) as $row) {
            $states[(string) $row['booking_id']] = (string) $row['moderation_status'];
        }

        return $states;
    }

    /**
     * Danh sách cho quản trị viên ('' = mọi trạng thái), chờ duyệt trước.
     *
     * @return list<array<string, mixed>>
     */
    public function adminList(string $status, string $keyword, int $page): array
    {
        $offset = (max(1, $page) - 1) * self::PAGE_SIZE;

        return Database::call('NTK_sp_admin_review_list', [$status === '' ? null : $status, $keyword, self::PAGE_SIZE, $offset]);
    }

    /**
     * Số đánh giá theo trạng thái (cùng từ khóa) và tổng số khớp bộ lọc hiện tại.
     *
     * @return array{total: int, pending: int, approved: int, rejected: int, all: int}
     */
    public function adminSummary(string $status, string $keyword): array
    {
        $row = Database::call('NTK_sp_admin_review_summary', [$status === '' ? null : $status, $keyword])[0] ?? [];

        return [
            'total' => (int) ($row['total'] ?? 0),
            'pending' => (int) ($row['pending_count'] ?? 0),
            'approved' => (int) ($row['approved_count'] ?? 0),
            'rejected' => (int) ($row['rejected_count'] ?? 0),
            'all' => (int) ($row['all_count'] ?? 0),
        ];
    }

    /**
     * Duyệt ('approved') hoặc từ chối / gỡ ('rejected', bắt buộc ghi chú).
     *
     * @return string ok, forbidden, not_found, invalid, note_required, invalid_transition
     */
    public function decide(string $actorUserId, string $reviewId, string $decision, string $note): string
    {
        $rows = Database::call('NTK_sp_admin_review_decide', [$actorUserId, $reviewId, $decision, $note]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /**
     * Nội dung khách nhập: bỏ ký tự điều khiển (giữ xuống dòng), gộp xuống dòng Windows, bỏ khoảng trắng hai đầu.
     */
    public static function cleanText(string $text): string
    {
        $text = str_replace(["\r\n", "\r"], "\n", $text);
        $text = (string) preg_replace('/[\x00-\x08\x0B-\x1F\x7F]/u', '', $text);

        return trim($text);
    }
}
