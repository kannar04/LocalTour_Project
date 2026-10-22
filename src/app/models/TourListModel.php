<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Dữ liệu cho trang danh sách tour (WBS 3.2.3 – Lê Trung Phong).
 * Procedure: LTP_sp_tour_list, LTP_sp_destination_list.
 */
final class TourListModel
{
    public const SORTS = ['recommended', 'upcoming', 'price_asc', 'price_desc'];
    public const DEFAULT_SORT = 'recommended';
    public const KEYWORD_MAX_LENGTH = 100;
    public const DESTINATION_MAX_LENGTH = 100;

    /**
     * Tour đang công khai, lọc theo từ khóa / điểm đến (tên) và sắp xếp.
     *
     * @return list<array<string, mixed>>
     */
    public function search(string $keyword, string $destination, string $sort): array
    {
        if (!in_array($sort, self::SORTS, true)) {
            $sort = self::DEFAULT_SORT;
        }

        return Database::call('LTP_sp_tour_list', [
            $keyword === '' ? null : $keyword,
            $destination === '' ? null : $destination,
            $sort,
        ]);
    }

    /**
     * Điểm đến (lấy từ cột destination của tour) kèm số tour đang công khai.
     *
     * @return list<array<string, mixed>>
     */
    public function destinations(): array
    {
        return Database::call('LTP_sp_destination_list');
    }
}
