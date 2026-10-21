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
    private TourListModel $tours;

    public function __construct()
    {
        $this->tours = new TourListModel();
    }

    /** GET / và /tours – khung trang; danh sách được tải bằng AJAX từ /api/tours. */
    public function index(): void
    {
        $destination = $this->query('destination');

        $this->render('tours/index', [
            'title' => 'Bảng tin du lịch',
            'initialQuery' => mb_substr($this->query('q'), 0, TourListModel::KEYWORD_MAX_LENGTH),
            'initialDestination' => $destination === '' ? null : self::parseId($destination),
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

        $destinationParam = $this->query('destination');
        $destinationId = null;
        if ($destinationParam !== '') {
            $destinationId = self::parseId($destinationParam);
            if ($destinationId === null) {
                $this->json(false, 'Điểm đến không hợp lệ.', null, 400);
            }
        }

        $sort = $this->query('sort');
        $rows = $this->tours->search($keyword, $destinationId, $sort === '' ? TourListModel::DEFAULT_SORT : $sort);
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
     * @return array{destination_id: int, name: string, slug: string, tour_count: int}
     */
    private function presentDestination(array $row): array
    {
        return [
            'destination_id' => (int) $row['destination_id'],
            'name' => $row['name'],
            'slug' => $row['slug'],
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
        $ratingAvg = $row['rating_avg'] === null ? null : (float) $row['rating_avg'];

        return [
            'tour_id' => (int) $row['tour_id'],
            'title' => $row['title'],
            'summary' => $row['summary'],
            'url' => url('/tours/' . $row['tour_id']),
            'destination_id' => (int) $row['destination_id'],
            'destination_name' => $row['destination_name'],
            'category_name' => $row['category_name'],
            'provider_name' => $row['provider_name'],
            'provider_verified' => (bool) $row['provider_verified'],
            'duration_hours' => (float) $row['duration_hours'],
            'duration_text' => format_duration((string) $row['duration_hours']),
            'max_group_size' => (int) $row['max_group_size'],
            'languages' => $row['languages'],
            'price_per_person' => (int) $row['price_per_person'],
            'price_text' => format_vnd($row['price_per_person']),
            'meeting_point' => $row['meeting_point'],
            'cover_image_url' => tour_image_url($row['cover_image']),
            'cover_caption' => $row['cover_caption'] ?? $row['title'],
            'rating_avg' => $ratingAvg,
            'rating_text' => format_rating($ratingAvg),
            'review_count' => (int) $row['review_count'],
            'next_departure_date' => $row['next_departure_date'],
            'next_departure_text' => $row['next_departure_date'] === null ? null : format_date($row['next_departure_date']),
        ];
    }
}
