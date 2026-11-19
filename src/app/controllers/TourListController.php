<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourListModel;
use Core\Controller;
use DateTimeImmutable;
use Throwable;

/**
 * Trang danh sách tour và các endpoint JSON cấp dữ liệu cho nó (WBS 3.2.3 – Lê Trung Phong).
 */
final class TourListController extends Controller
{
    /** Độ dài tối đa của đoạn mô tả ngắn trên thẻ tour. */
    private const EXCERPT_LENGTH = 180;

    private TourListModel $tours;

    public function __construct()
    {
        $this->tours = new TourListModel();
    }

    /**
     * GET / và /tours – khung trang; danh sách được tải bằng AJAX từ /api/tours.
     * Bộ lọc nâng cao (CR2) được tour-list.js đọc từ URL; ở đây chỉ đưa lựa chọn cho ô "Ngày đi" và "Bộ lọc".
     */
    public function index(): void
    {
        $today = new DateTimeImmutable('today');
        try {
            $languages = $this->tours->languageOptions();
        } catch (Throwable) {
            // Không đọc được CSDL: vẫn hiện khung trang (tour-list.js tự báo lỗi), bộ lọc dùng danh sách đầy đủ.
            $languages = TourListModel::LANGUAGES;
        }

        $this->render('tours/index', [
            'title' => 'Bảng tin du lịch',
            'initialQuery' => mb_substr($this->query('q'), 0, TourListModel::KEYWORD_MAX_LENGTH),
            'initialDestinationId' => self::parseUuid($this->query('destination_id')) ?? '',
            'initialCategoryId' => self::parseUuid($this->query('category_id')) ?? '',
            'dateMin' => $today->format('Y-m-d'),
            'dateMax' => $today->modify('+' . TourListModel::DATE_MAX_DAYS . ' days')->format('Y-m-d'),
            'durationOptions' => TourListModel::DURATIONS,
            'languageOptions' => $languages,
            'allLanguages' => TourListModel::LANGUAGES,
            'priceMax' => TourListModel::PRICE_MAX,
            'pageStyles' => ['css/tour-list.css', 'css/compare.css', 'css/tour-social.css'],
            'pageScripts' => ['js/compare.js', 'js/tour-social.js', 'js/tour-list.js'],
        ]);
    }

    /**
     * GET /api/tours?q=&destination_id=&category_id=&sort=
     *   &date=YYYY-MM-DD&price_min=&price_max=&duration=short|medium|long&language=&hotel_pickup=1 (CR2)
     */
    public function apiIndex(): void
    {
        $keyword = $this->query('q');
        if (mb_strlen($keyword) > TourListModel::KEYWORD_MAX_LENGTH) {
            $this->json(false, 'Từ khóa tìm kiếm tối đa 100 ký tự.', null, 400);
        }

        // '' = tất cả; có giá trị thì phải là UUID.
        $destinationId = $this->query('destination_id');
        if ($destinationId !== '' && self::parseUuid($destinationId) === null) {
            $this->json(false, 'Điểm đến không hợp lệ.', null, 400);
        }

        $categoryId = $this->query('category_id');
        if ($categoryId !== '' && self::parseUuid($categoryId) === null) {
            $this->json(false, 'Loại hình không hợp lệ.', null, 400);
        }

        $sort = $this->query('sort');
        $rows = $this->tours->search(
            $keyword,
            self::parseUuid($destinationId),
            self::parseUuid($categoryId),
            $sort === '' ? TourListModel::DEFAULT_SORT : $sort,
            $this->advancedFilters()
        );
        $tours = array_map([$this, 'presentTour'], $rows);

        $this->json(
            true,
            $tours === [] ? 'Không có tour phù hợp.' : '',
            ['tours' => $tours, 'total' => count($tours)]
        );
    }

    /**
     * Ngày đi + bộ lọc nâng cao của /api/tours (CR2, Lê Trung Phong). Tham số rỗng = không lọc;
     * giá trị sai thì trả 422 kèm thông báo và dừng.
     *
     * @return array{date: ?string, price_min: ?int, price_max: ?int, duration: ?string, language: ?string, hotel_pickup: bool}
     */
    private function advancedFilters(): array
    {
        $filters = ['date' => null, 'price_min' => null, 'price_max' => null, 'duration' => null, 'language' => null, 'hotel_pickup' => false];

        $date = $this->query('date');
        if ($date !== '') {
            $day = DateTimeImmutable::createFromFormat('!Y-m-d', $date);
            if ($day === false || $day->format('Y-m-d') !== $date) {
                $this->json(false, 'Ngày đi không hợp lệ.', null, 422);
            }
            $today = new DateTimeImmutable('today');
            if ($day < $today || $day > $today->modify('+' . TourListModel::DATE_MAX_DAYS . ' days')) {
                $this->json(false, 'Ngày đi phải từ hôm nay đến ' . TourListModel::DATE_MAX_DAYS . ' ngày tới.', null, 422);
            }
            $filters['date'] = $date;
        }

        foreach (['price_min', 'price_max'] as $key) {
            $value = $this->query($key);
            if ($value === '') {
                continue;
            }
            if (!preg_match('/^\d{1,9}$/', $value) || (int) $value > TourListModel::PRICE_MAX) {
                $this->json(false, 'Giá phải là số nguyên từ 0 đến ' . format_vnd(TourListModel::PRICE_MAX) . '.', null, 422);
            }
            $filters[$key] = (int) $value;
        }
        if ($filters['price_min'] !== null && $filters['price_max'] !== null && $filters['price_min'] > $filters['price_max']) {
            $this->json(false, 'Giá thấp nhất không được lớn hơn giá cao nhất.', null, 422);
        }

        $duration = $this->query('duration');
        if ($duration !== '') {
            if (!array_key_exists($duration, TourListModel::DURATIONS)) {
                $this->json(false, 'Thời lượng không hợp lệ.', null, 422);
            }
            $filters['duration'] = $duration;
        }

        $language = $this->query('language');
        if ($language !== '') {
            if (!array_key_exists($language, TourListModel::LANGUAGES)) {
                $this->json(false, 'Ngôn ngữ hướng dẫn không hợp lệ.', null, 422);
            }
            $filters['language'] = $language;
        }

        $pickup = $this->query('hotel_pickup');
        if ($pickup !== '' && $pickup !== '0' && $pickup !== '1') {
            $this->json(false, 'Lựa chọn đón tại khách sạn không hợp lệ.', null, 422);
        }
        $filters['hotel_pickup'] = $pickup === '1';

        return $filters;
    }

    /** GET /api/destinations */
    public function apiDestinations(): void
    {
        $destinations = array_map([$this, 'presentDestination'], $this->tours->destinations());

        $this->json(true, '', ['destinations' => $destinations]);
    }

    /** GET /api/categories */
    public function apiCategories(): void
    {
        $categories = array_map([$this, 'presentCategory'], $this->tours->categories());

        $this->json(true, '', ['categories' => $categories]);
    }

    /**
     * @param array<string, mixed> $row
     * @return array{destination_id: string, name: string, slug: string, tour_count: int}
     */
    private function presentDestination(array $row): array
    {
        return [
            'destination_id' => (string) $row['destination_id'],
            'name' => (string) $row['name'],
            'slug' => (string) $row['slug'],
            'tour_count' => (int) $row['tour_count'],
        ];
    }

    /**
     * @param array<string, mixed> $row
     * @return array{category_id: string, name: string, slug: string, tour_count: int}
     */
    private function presentCategory(array $row): array
    {
        return [
            'category_id' => (string) $row['category_id'],
            'name' => (string) $row['name'],
            'slug' => (string) $row['slug'],
            'tour_count' => (int) $row['tour_count'],
        ];
    }

    /**
     * Một tour trong danh sách: giữ giá trị gốc và thêm chuỗi đã định dạng để giao diện hiển thị trực tiếp.
     *
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private function presentTour(array $row): array
    {
        $tourId = (string) $row['tour_id'];
        $ratingAvg = $row['rating_avg'] === null ? null : (float) $row['rating_avg'];
        $price = $row['from_price_vnd'] === null ? null : (int) $row['from_price_vnd'];
        $nextStartsAt = $row['next_starts_at'] === null ? null : (string) $row['next_starts_at'];
        $coverUrl = $row['cover_image_url'] === null ? null : (string) $row['cover_image_url'];

        return [
            'tour_id' => $tourId,
            'title' => $row['title'],
            'excerpt' => self::excerpt((string) $row['description']),
            'url' => url('/tours/' . $tourId),
            'destination_id' => $row['destination_id'],
            'destination_name' => $row['destination_name'],
            'category_id' => $row['category_id'],
            'category_name' => $row['category_name'],
            'provider_name' => $row['provider_name'],
            'duration_minutes' => (int) $row['duration_minutes'],
            'duration_text' => format_duration($row['duration_minutes']),
            'max_group_size' => (int) $row['max_group_size'],
            'languages_text' => format_languages($row['language_codes']),
            'pickup_mode' => $row['pickup_mode'],
            'pickup_text' => pickup_text($row['pickup_mode'], $row['meeting_point']),
            'departure_text' => departure_text($row['pickup_mode'], $row['meeting_point']),
            'meeting_point' => $row['meeting_point'],
            'from_price_vnd' => $price,
            'price_text' => $price === null ? null : format_vnd($price),
            'cover_image_url' => $coverUrl === null ? null : image_src($coverUrl),
            'cover_caption' => trim((string) $row['cover_alt_text']) !== '' ? $row['cover_alt_text'] : $row['title'],
            'rating_avg' => $ratingAvg,
            'rating_text' => format_rating($ratingAvg),
            'review_count' => (int) $row['review_count'],
            'next_starts_at' => $nextStartsAt,
            'next_departure_text' => $nextStartsAt === null ? null : format_date($nextStartsAt) . ' · ' . format_time($nextStartsAt),
        ];
    }

    /** Đoạn đầu của mô tả, cắt gọn cho thẻ tour. */
    private static function excerpt(string $description): string
    {
        $text = preg_replace('/\s+/u', ' ', text_paragraphs($description)[0] ?? '') ?? '';
        if (mb_strlen($text) <= self::EXCERPT_LENGTH) {
            return $text;
        }

        return rtrim(mb_substr($text, 0, self::EXCERPT_LENGTH - 1)) . '…';
    }
}
