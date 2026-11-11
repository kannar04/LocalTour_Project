<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourLocationModel;
use App\Services\NearbyPlaces;
use Core\Controller;
use PDOException;

/**
 * Bản đồ tour (Nguyễn Tuấn Khôi):
 *   GET /ban-do                  – điểm khởi hành của mọi tour đang hiển thị, bấm một điểm để xem địa điểm quanh đó;
 *   GET /api/tours/{id}/places   – quán ăn, bar, giải trí, quán nước quanh điểm khởi hành (NearbyPlaces).
 * Chưa chạy database/23_map_places_NTK.sql: trang /ban-do báo bản đồ chưa sẵn sàng, API trả 503.
 */
final class TourMapController extends Controller
{
    private TourLocationModel $locations;

    public function __construct()
    {
        $this->locations = new TourLocationModel();
    }

    /** GET /ban-do?tour=<mã tour, không bắt buộc> */
    public function index(): void
    {
        $tours = $this->locations->published();
        $points = [];
        foreach ($tours ?? [] as $tour) {
            $points[] = self::pointData($tour) + [
                'destination' => $tour['destination_name'],
                'category' => $tour['category_name'],
                'duration' => format_duration($tour['duration_minutes']),
                'image' => $tour['cover_image_url'] === null ? '' : image_src($tour['cover_image_url']),
                'imageAlt' => $tour['cover_alt_text'] !== '' ? $tour['cover_alt_text'] : $tour['title'],
            ];
        }

        $selected = self::parseUuid($this->query('tour'));
        if ($selected !== null && !in_array($selected, array_column($points, 'id'), true)) {
            $selected = null;
        }

        $this->render('tours/map', [
            'title' => 'Bản đồ tour',
            'mapReady' => $tours !== null,
            'points' => $points,
            'selectedId' => $selected,
            'activeNav' => 'map',
            'pageStyles' => ['css/tour-detail.css', 'css/tour-map.css'],
            'pageScripts' => $points !== [] ? ['js/tour-map.js'] : [],
        ]);
    }

    /** GET /api/tours/{id}/places */
    public function apiPlaces(string $id): void
    {
        $tourId = self::parseUuid($id);
        if ($tourId === null) {
            $this->json(false, 'Mã tour không hợp lệ.', null, 400);
        }

        $point = $this->locations->point($tourId);
        if ($point === null) {
            $this->json(false, 'Tour không có vị trí điểm khởi hành trên bản đồ.', null, 404);
        }

        try {
            $places = (new NearbyPlaces())->around($point['lat'], $point['lng']);
        } catch (PDOException $exception) {
            error_log('Bản đồ tour: không đọc / ghi được map_place_cache, có thể chưa chạy database/23_map_places_NTK.sql: '
                . $exception->getMessage());
            $this->json(false, NearbyPlaces::MESSAGE_FAILED, null, 503);
        }

        $this->json(true, $places['message'], ['tour' => self::pointData($point)] + $places);
    }

    /**
     * Dữ liệu một điểm khởi hành cho JS.
     *
     * @param array{tour_id: string, title: string, lat: float, lng: float, pickup_mode: string, meeting_point: string} $point
     * @return array{id: string, title: string, url: string, lat: float, lng: float, departure: string, isPickup: bool}
     */
    public static function pointData(array $point): array
    {
        return [
            'id' => $point['tour_id'],
            'title' => $point['title'],
            'url' => url('/tours/' . $point['tour_id']),
            'lat' => $point['lat'],
            'lng' => $point['lng'],
            'departure' => self::departureLabel($point['pickup_mode'], $point['meeting_point']),
            'isPickup' => $point['pickup_mode'] === 'hotel_pickup',
        ];
    }

    /** "Điểm hẹn: Chùa Cầu…" / "Khu vực đón (đón tại khách sạn): …". */
    public static function departureLabel(string $pickupMode, string $meetingPoint): string
    {
        if ($pickupMode === 'hotel_pickup') {
            return 'Khu vực đón (đón tại khách sạn)' . ($meetingPoint !== '' ? ': ' . $meetingPoint : '');
        }

        return 'Điểm hẹn: ' . or_missing($meetingPoint);
    }
}
