<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Dữ liệu chi tiết một tour theo UUID (WBS 3.2.4 – Nguyễn Minh Thức).
 * Procedure: NMT_sp_tour_detail, NMT_sp_tour_schedule_list, NMT_sp_tour_ticket_list, NMT_sp_tour_image_list.
 */
final class TourDetailModel
{
    /**
     * Thông tin tour, nhà cung cấp, điểm đánh giá và giá thấp nhất; null nếu tour không tồn tại hoặc không công khai.
     *
     * @return array<string, mixed>|null
     */
    public function find(string $tourId): ?array
    {
        $rows = Database::call('NMT_sp_tour_detail', [$tourId]);

        return $rows[0] ?? null;
    }

    /**
     * Lịch khởi hành còn đặt được (sắp tới, đang mở, còn chỗ).
     *
     * @return list<array<string, mixed>>
     */
    public function schedules(string $tourId): array
    {
        return Database::call('NMT_sp_tour_schedule_list', [$tourId]);
    }

    /**
     * Loại vé đang bán của các lịch khởi hành trên.
     *
     * @return list<array<string, mixed>>
     */
    public function tickets(string $tourId): array
    {
        return Database::call('NMT_sp_tour_ticket_list', [$tourId]);
    }

    /**
     * Ảnh của chính tour này theo sort_order (bảng tour_images); [] nếu tour chưa có ảnh.
     *
     * @return list<array<string, mixed>>
     */
    public function images(string $tourId): array
    {
        return Database::call('NMT_sp_tour_image_list', [$tourId]);
    }
}