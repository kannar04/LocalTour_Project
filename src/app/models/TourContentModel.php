<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Nội dung hiển thị trên trang chi tiết: lịch trình, phụ thu/tùy chọn, đánh giá đã duyệt và chính sách hủy (WBS 3.2.6 – Nguyễn Tuấn Khôi).
 * Procedure: NTK_sp_tour_itinerary_list, NTK_sp_tour_extra_list, NTK_sp_tour_review_list, NTK_sp_tour_cancellation_policy.
 */
final class TourContentModel
{
    public const REVIEW_LIMIT = 5;

    /**
     * Các điểm lịch trình theo đúng thứ tự stop_order; [] nếu tour chưa có lịch trình.
     *
     * @return list<array<string, mixed>>
     */
    public function itinerary(string $tourId): array
    {
        return Database::call('NTK_sp_tour_itinerary_list', [$tourId]);
    }

    /**
     * Phụ thu và hoạt động tùy chọn (phụ thu trước), tách riêng khỏi giá vé; [] nếu tour chưa có.
     *
     * @return list<array<string, mixed>>
     */
    public function extras(string $tourId): array
    {
        return Database::call('NTK_sp_tour_extra_list', [$tourId]);
    }

    /**
     * Đánh giá đã duyệt, chuyến đi gần nhất trước.
     *
     * @return list<array<string, mixed>>
     */
    public function reviews(string $tourId, int $limit = self::REVIEW_LIMIT): array
    {
        return Database::call('NTK_sp_tour_review_list', [$tourId, $limit]);
    }

    /**
     * Chính sách hủy mới nhất (version cao nhất); null nếu tour chưa có.
     *
     * @return array<string, mixed>|null
     */
    public function cancellationPolicy(string $tourId): ?array
    {
        $rows = Database::call('NTK_sp_tour_cancellation_policy', [$tourId]);

        return $rows[0] ?? null;
    }
}
