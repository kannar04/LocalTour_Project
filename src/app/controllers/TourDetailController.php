<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourContentModel;
use App\Models\TourDetailModel;
use Core\Controller;

/**
 * Trang chi tiết tour theo ID và endpoint JSON tương ứng (WBS 3.2.4 – Nguyễn Minh Thức).
 * ID sai định dạng hoặc không tồn tại đều hiển thị trạng thái "Không tìm thấy tour" (HTTP 404).
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
        $tourId = self::parseId($id);
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
            'schedules' => $this->details->schedules($tourId),
            'itinerary' => $this->details->itinerary($tourId),
            'images' => $this->content->images($tourId),
            'inclusions' => $this->content->inclusions($tourId),
            'reviews' => $this->content->reviews($tourId),
            'pageStyles' => ['css/tour-detail.css'],
            'pageScripts' => ['js/tour-detail.js'],
        ]);
    }

    /** GET /api/tours/{id} */
    public function apiShow(string $id): void
    {
        $tourId = self::parseId($id);
        if ($tourId === null) {
            $this->json(false, 'Mã tour không hợp lệ.', null, 400);
        }

        $tour = $this->details->find($tourId);
        if ($tour === null) {
            $this->json(false, 'Không tìm thấy tour.', null, 404);
        }

        $images = $this->content->images($tourId);
        foreach ($images as $index => $image) {
            $images[$index]['image_url'] = tour_image_url($image['image_path']);
        }

        $this->json(true, '', [
            'tour' => $tour + [
                'url' => url('/tours/' . $tourId),
                'price_text' => format_vnd($tour['price_per_person']),
                'duration_text' => format_duration((string) $tour['duration_hours']),
                'rating_text' => format_rating($tour['rating_avg']),
            ],
            'schedules' => $this->details->schedules($tourId),
            'itinerary' => $this->details->itinerary($tourId),
            'images' => $images,
            'inclusions' => $this->content->inclusions($tourId),
            'reviews' => $this->content->reviews($tourId),
        ]);
    }
}
