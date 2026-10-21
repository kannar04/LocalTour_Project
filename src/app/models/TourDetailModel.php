<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Dữ liệu chi tiết một tour theo ID (WBS 3.2.4 – Nguyễn Minh Thức).
 * Procedure: NMT_sp_tour_detail, NMT_sp_tour_schedule_list, NMT_sp_tour_itinerary_list.
 */
final class TourDetailModel
{
    /**
     * Thông tin tour, nhà tổ chức và điểm đánh giá; null nếu ID không tồn tại hoặc tour không công khai.
     *
     * @return array<string, mixed>|null
     */
    public function find(int $tourId): ?array
    {
        $rows = Database::call('NMT_sp_tour_detail', [$tourId]);

        return $rows[0] ?? null;
    }

    /**
     * Lịch khởi hành sắp tới còn chỗ.
     *
     * @return list<array<string, mixed>>
     */
    public function schedules(int $tourId): array
    {
        return Database::call('NMT_sp_tour_schedule_list', [$tourId]);
    }

    /**
     * Các mốc lịch trình trong ngày tour.
     *
     * @return list<array<string, mixed>>
     */
    public function itinerary(int $tourId): array
    {
        return Database::call('NMT_sp_tour_itinerary_list', [$tourId]);
    }
}
