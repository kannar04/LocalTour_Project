<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourContentModel;
use App\Models\TourDetailModel;
use Core\Controller;

/**
 * Trang chi tiết tour theo UUID và endpoint JSON tương ứng (WBS 3.2.4 – Nguyễn Minh Thức).
 * UUID sai định dạng hoặc tour không tồn tại / chưa duyệt đều hiển thị "Không tìm thấy tour" (HTTP 404).
 */
final class TourDetailController extends Controller
{
    private TourDetailModel $details;
    private TourContentModel $content;

    public function __construct()
    {
        $this->details = new TourDetailModel();
        $this->content = new TourContentModel();
    }

    /** GET /tours/{id} */
    public function show(string $id): void
    {
        $tourId = self::parseUuid($id);
        $tour = $tourId === null ? null : $this->details->find($tourId);

        if ($tour === null) {
            $this->render('tours/not-found', [
                'title' => 'Không tìm thấy tour',
                'pageStyles' => ['css/tour-detail.css'],
            ], 404);
            return;
        }

        $this->render('tours/show', [
            'title' => $tour['title'],
            'tour' => $tour,
            'pageStyles' => ['css/tour-detail.css'],
            'pageScripts' => ['js/tour-detail.js'],
        ] + $this->sections($tourId, $tour));
    }

    /** GET /api/tours/{id} */
    public function apiShow(string $id): void
    {
        $tourId = self::parseUuid($id);
        if ($tourId === null) {
            $this->json(false, 'Mã tour không hợp lệ.', null, 400);
        }

        $tour = $this->details->find($tourId);
        if ($tour === null) {
            $this->json(false, 'Không tìm thấy tour.', null, 404);
        }

        $price = $tour['from_price_vnd'] === null ? null : (int) $tour['from_price_vnd'];

        $this->json(true, '', [
            'tour' => $tour + [
                'url' => url('/tours/' . $tourId),
                'price_text' => $price === null ? null : format_vnd($price),
                'duration_text' => format_duration($tour['duration_minutes']),
                'languages_text' => format_languages($tour['language_codes']),
                'pickup_text' => pickup_text($tour['pickup_mode'], $tour['meeting_point']),
                'departure_text' => departure_text($tour['pickup_mode'], $tour['meeting_point']),
                'rating_text' => format_rating($tour['rating_avg']),
            ],
        ] + $this->sections($tourId, $tour));
    }

    /**
     * Các phần dùng chung cho trang HTML và JSON: lịch, vé, lịch trình, dịch vụ bao gồm / không bao gồm,
     * phụ thu/tùy chọn, đánh giá, chính sách và ảnh của chính tour.
     *
     * @param array<string, mixed> $tour
     * @return array<string, mixed>
     */
    private function sections(string $tourId, array $tour): array
    {
        $gallery = array_map(static fn (array $image): array => [
            'url' => image_src((string) $image['url']),
            'caption' => trim((string) $image['alt_text']) !== '' ? $image['alt_text'] : $tour['title'],
        ], $this->details->images($tourId));

        // Giờ bắt đầu "08:30" (null = mục không ghi giờ).
        $itinerary = array_map(static fn (array $item): array => [
            'item_id' => $item['item_id'],
            'start_time' => $item['start_time'],
            'time_text' => $item['start_time'] === null ? null : format_time((string) $item['start_time']),
            'description' => (string) $item['description'],
        ], $this->content->itinerary($tourId));

        $inclusions = ['included' => [], 'excluded' => []];
        foreach ($this->content->inclusions($tourId) as $inclusion) {
            $inclusions[(int) $inclusion['is_included'] === 1 ? 'included' : 'excluded'][] = (string) $inclusion['item_text'];
        }

        return [
            'schedules' => $this->details->schedules($tourId),
            'tickets' => $this->details->tickets($tourId),
            'itinerary' => $itinerary,
            'inclusions' => $inclusions,
            'extras' => $this->content->extras($tourId),
            'reviews' => $this->content->reviews($tourId),
            'policy' => $this->content->cancellationPolicy($tourId),
            'gallery' => $gallery,
        ];
    }
}
