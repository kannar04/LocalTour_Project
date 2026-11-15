<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Dữ liệu cho trang danh sách tour (WBS 3.2.3 – Lê Trung Phong).
 * Procedure: LTP_sp_tour_list, LTP_sp_destination_list, LTP_sp_category_list.
 */
final class TourListModel
{
    public const SORTS = ['recommended', 'upcoming', 'price_asc', 'price_desc'];
    public const DEFAULT_SORT = 'recommended';
    public const KEYWORD_MAX_LENGTH = 100;

    /** Bộ lọc nâng cao (CR3): khoảng giá tối đa nhận được (VND) và số ngày tới tối đa cho "Ngày đi". */
    public const PRICE_MAX = 100000000;
    public const DATE_MAX_DAYS = 365;

    /** Mã thời lượng → nhãn (ngưỡng nằm trong LTP_sp_tour_list). */
    public const DURATIONS = [
        'short' => 'Đến 3 giờ',
        'medium' => 'Trên 3 – 4 giờ',
        'long' => 'Trên 4 giờ',
    ];

    /** Mã ngôn ngữ hướng dẫn (tours.language_codes) → tên hiển thị trong bộ lọc. */
    public const LANGUAGES = [
        'vi' => 'Tiếng Việt',
        'en' => 'Tiếng Anh',
        'fr' => 'Tiếng Pháp',
        'zh' => 'Tiếng Trung',
        'ko' => 'Tiếng Hàn',
        'ja' => 'Tiếng Nhật',
    ];

    /**
     * Tour đang công khai, lọc theo từ khóa, điểm đến và loại hình (UUID, null = tất cả) rồi sắp xếp.
     * $filters (CR3, đã kiểm tra ở controller; thiếu khóa = không lọc):
     *   date (Y-m-d), price_min, price_max (int VND), duration (khóa của DURATIONS),
     *   language (khóa của LANGUAGES), hotel_pickup (bool).
     *
     * @param array{date?: ?string, price_min?: ?int, price_max?: ?int, duration?: ?string, language?: ?string, hotel_pickup?: bool} $filters
     * @return list<array<string, mixed>>
     */
    public function search(string $keyword, ?string $destinationId, ?string $categoryId, string $sort, array $filters = []): array
    {
        if (!in_array($sort, self::SORTS, true)) {
            $sort = self::DEFAULT_SORT;
        }

        return Database::call('LTP_sp_tour_list', [
            $keyword === '' ? null : $keyword,
            $destinationId,
            $categoryId,
            $sort,
            $filters['date'] ?? null,
            $filters['price_min'] ?? null,
            $filters['price_max'] ?? null,
            $filters['duration'] ?? null,
            $filters['language'] ?? null,
            !empty($filters['hotel_pickup']) ? 1 : null,
        ]);
    }

    /**
     * Ngôn ngữ hướng dẫn có trong các tour đang công khai, theo thứ tự của LANGUAGES (mã → tên).
     *
     * @return array<string, string>
     */
    public function languageOptions(): array
    {
        $codes = [];
        foreach ($this->search('', null, null, self::DEFAULT_SORT) as $row) {
            foreach (explode(',', strtolower((string) $row['language_codes'])) as $code) {
                $codes[trim($code)] = true;
            }
        }

        return array_filter(
            self::LANGUAGES,
            static fn (string $code): bool => isset($codes[$code]),
            ARRAY_FILTER_USE_KEY
        );
    }

    /**
     * Điểm đến (bảng destinations) đang có tour công khai, kèm số tour.
     *
     * @return list<array<string, mixed>>
     */
    public function destinations(): array
    {
        return Database::call('LTP_sp_destination_list');
    }

    /**
     * Loại hình (bảng categories) đang có tour công khai, kèm số tour.
     *
     * @return list<array<string, mixed>>
     */
    public function categories(): array
    {
        return Database::call('LTP_sp_category_list');
    }
}
