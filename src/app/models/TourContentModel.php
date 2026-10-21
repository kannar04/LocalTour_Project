<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Nội dung hiển thị trên trang chi tiết: ảnh, dịch vụ bao gồm, đánh giá (WBS 3.2.6 – Nguyễn Tuấn Khôi).
 * Procedure: NTK_sp_tour_image_list, NTK_sp_tour_inclusion_list, NTK_sp_tour_review_list.
 */
final class TourContentModel
{
    public const REVIEW_LIMIT = 5;

    /**
     * @return list<array<string, mixed>>
     */
    public function images(int $tourId): array
    {
        return Database::call('NTK_sp_tour_image_list', [$tourId]);
    }

    /**
     * Dịch vụ đã bao gồm (is_included = 1) trước, chưa bao gồm sau.
     *
     * @return list<array<string, mixed>>
     */
    public function inclusions(int $tourId): array
    {
        return Database::call('NTK_sp_tour_inclusion_list', [$tourId]);
    }

    /**
     * Đánh giá mới nhất của khách.
     *
     * @return list<array<string, mixed>>
     */
    public function reviews(int $tourId, int $limit = self::REVIEW_LIMIT): array
    {
        return Database::call('NTK_sp_tour_review_list', [$tourId, $limit]);
    }
}
