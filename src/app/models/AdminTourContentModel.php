<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Nội dung tour ở trang quản trị (US07-S5-01, FR-13 – Nguyễn Minh Thức): ảnh, lịch trình, dịch vụ bao gồm /
 * không bao gồm, chính sách hủy theo phiên bản; xóa tour (chưa có đơn) hoặc ngừng hiển thị (đã có đơn) và hiển thị lại.
 * Procedure: NMT_sp_admin_image_*, NMT_sp_admin_itinerary_*, NMT_sp_admin_inclusion_*, NMT_sp_admin_policy_*,
 *            NMT_sp_admin_tour_delete, NMT_sp_admin_tour_restore (file 21).
 */
final class AdminTourContentModel
{
    public const IMAGE_MAX = 12;
    public const IMAGE_MAX_BYTES = 2 * 1024 * 1024;
    public const ALT_MAX_LENGTH = 255;
    public const ITINERARY_MAX = 30;
    public const ITINERARY_TEXT_MAX_LENGTH = 255;
    public const INCLUSION_MAX = 40;
    public const INCLUSION_TEXT_MAX_LENGTH = 150;
    public const POLICY_HOURS_MAX = 720;
    public const POLICY_TERMS_MAX_LENGTH = 2000;
    public const SORT_MAX = 999;

    /** @return list<array<string, mixed>> image_id, url, alt_text, sort_order, is_cover */
    public function images(string $tourId): array
    {
        return Database::call('NMT_sp_admin_image_list', [$tourId]);
    }

    /** @return array<string, mixed> result (ok, forbidden, not_found, invalid, limit), field, image_id */
    public function addImage(string $actorUserId, string $tourId, string $url, string $altText): array
    {
        $rows = Database::call('NMT_sp_admin_image_add', [$actorUserId, $tourId, $url, $altText === '' ? null : $altText]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }

    /** @return array<string, mixed> result (ok, forbidden, not_found), url (để xóa file đã tải lên) */
    public function deleteImage(string $actorUserId, string $tourId, string $imageId): array
    {
        return Database::call('NMT_sp_admin_image_delete', [$actorUserId, $tourId, $imageId])[0] ?? ['result' => 'not_found'];
    }

    /** @return array<string, mixed> result (ok, unchanged, forbidden, not_found) */
    public function setCover(string $actorUserId, string $tourId, string $imageId): array
    {
        return Database::call('NMT_sp_admin_image_set_cover', [$actorUserId, $tourId, $imageId])[0] ?? ['result' => 'not_found'];
    }

    /** @return list<array<string, mixed>> item_id, start_time, description, sort_order */
    public function itinerary(string $tourId): array
    {
        return Database::call('NMT_sp_admin_itinerary_list', [$tourId]);
    }

    /**
     * Thêm ($itemId null) hoặc sửa một mục lịch trình. $startTime 'HH:MM:SS' hoặc null (không ghi giờ).
     *
     * @return array<string, mixed> result (ok, unchanged, forbidden, not_found, invalid, limit), field, item_id
     */
    public function saveItinerary(
        string $actorUserId,
        string $tourId,
        ?string $itemId,
        ?string $startTime,
        string $description,
        int $sortOrder
    ): array {
        $rows = Database::call('NMT_sp_admin_itinerary_save', [$actorUserId, $tourId, $itemId, $startTime, $description, $sortOrder]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }

    /** @return array<string, mixed> result (ok, forbidden, not_found) */
    public function deleteItinerary(string $actorUserId, string $tourId, string $itemId): array
    {
        return Database::call('NMT_sp_admin_itinerary_delete', [$actorUserId, $tourId, $itemId])[0] ?? ['result' => 'not_found'];
    }

    /** @return list<array<string, mixed>> inclusion_id, item_text, is_included, sort_order */
    public function inclusions(string $tourId): array
    {
        return Database::call('NMT_sp_admin_inclusion_list', [$tourId]);
    }

    /** @return array<string, mixed> result (ok, forbidden, not_found, invalid, limit), field, inclusion_id */
    public function addInclusion(string $actorUserId, string $tourId, string $text, bool $included): array
    {
        $rows = Database::call('NMT_sp_admin_inclusion_add', [$actorUserId, $tourId, $text, $included ? 1 : 0]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }

    /** @return array<string, mixed> result (ok, forbidden, not_found) */
    public function deleteInclusion(string $actorUserId, string $tourId, string $inclusionId): array
    {
        return Database::call('NMT_sp_admin_inclusion_delete', [$actorUserId, $tourId, $inclusionId])[0] ?? ['result' => 'not_found'];
    }

    /** Các phiên bản chính sách hủy, mới nhất trước, kèm số đơn đặt theo từng phiên bản. @return list<array<string, mixed>> */
    public function policies(string $tourId): array
    {
        return Database::call('NMT_sp_admin_policy_list', [$tourId]);
    }

    /**
     * Thêm phiên bản chính sách mới (đơn cũ giữ phiên bản lúc đặt). $freeBeforeHours null = không có mốc hủy miễn phí.
     *
     * @return array<string, mixed> result (ok, unchanged, forbidden, not_found, invalid), field, version
     */
    public function addPolicy(string $actorUserId, string $tourId, ?int $freeBeforeHours, int $refundPercent, string $terms): array
    {
        $rows = Database::call('NMT_sp_admin_policy_add', [$actorUserId, $tourId, $freeBeforeHours, $refundPercent, $terms]);

        return $rows[0] ?? ['result' => 'not_found', 'field' => null];
    }

    /**
     * Xóa tour chưa có đơn; tour đã có đơn thì chuyển 'archived' (ngừng hiển thị). Còn đơn đang xử lý thì không đổi gì.
     *
     * @return array<string, mixed> result (deleted, archived, already_archived, has_bookings, forbidden, not_found),
     *         title, active_bookings
     */
    public function deleteTour(string $actorUserId, string $tourId): array
    {
        return Database::call('NMT_sp_admin_tour_delete', [$actorUserId, $tourId])[0] ?? ['result' => 'not_found'];
    }

    /** Tour ngừng hiển thị → chờ duyệt lại. @return array<string, mixed> result (ok, forbidden, not_found, invalid_transition) */
    public function restoreTour(string $actorUserId, string $tourId): array
    {
        return Database::call('NMT_sp_admin_tour_restore', [$actorUserId, $tourId])[0] ?? ['result' => 'not_found'];
    }
}
