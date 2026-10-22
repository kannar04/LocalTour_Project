<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourListModel;
use Core\Controller;

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

    /** GET / và /tours – khung trang; danh sách được tải bằng AJAX từ /api/tours. */
    public function index(): void
    {
        $this->render('tours/index', [
            'title' => 'Bảng tin du lịch',
            'initialQuery' => mb_substr($this->query('q'), 0, TourListModel::KEYWORD_MAX_LENGTH),
            'initialDestination' => mb_substr($this->query('destination'), 0, TourListModel::DESTINATION_MAX_LENGTH),
            'pageStyles' => ['css/tour-list.css'],
            'pageScripts' => ['js/tour-list.js'],
        ]);
    }

    /** GET /api/tours?q=&destination=&sort= */
    public function apiIndex(): void
    {
        $keyword = $this->query('q');
        if (mb_strlen($keyword) > TourListModel::KEYWORD_MAX_LENGTH) {
            $this->json(false, 'Từ khóa tìm kiếm tối đa 100 ký tự.', null, 400);
        }

        $destination = $this->query('destination');
        if (mb_strlen($destination) > TourListModel::DESTINATION_MAX_LENGTH) {
            $this->json(false, 'Điểm đến không hợp lệ.', null, 400);
        }

        $sort = $this->query('sort');
        $rows = $this->tours->search($keyword, $destination, $sort === '' ? TourListModel::DEFAULT_SORT : $sort);
        $tours = array_map([$this, 'presentTour'], $rows);

        $this->json(
            true,
            $tours === [] ? 'Không có tour phù hợp.' : '',
            ['tours' => $tours, 'total' => count($tours)]
        );
    }

    /** GET /api/destinations */
    public function apiDestinations(): void
    {
        $destinations = array_map([$this, 'presentDestination'], $this->tours->destinations());

        $this->json(true, '', ['destinations' => $destinations]);
    }

    /**
     * @param array<string, mixed> $row
     * @return array{name: string, tour_count: int}
     */
    private function presentDestination(array $row): array
    {
        return [
            'name' => (string) $row['destination'],
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
            'destination' => $row['destination'],
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
