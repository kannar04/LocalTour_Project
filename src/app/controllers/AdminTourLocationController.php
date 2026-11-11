<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourLocationModel;
use PDOException;

/**
 * Vị trí điểm khởi hành của tour trên bản đồ (Nguyễn Tuấn Khôi): quản trị viên nhập vĩ độ / kinh độ hoặc bấm lên
 * bản đồ nhỏ để đặt điểm, hoặc xóa vị trí (tour không còn hiện bản đồ). Có cả hai tọa độ hoặc không có cả hai,
 * tọa độ phải nằm trong khung Việt Nam. Mở từ trang chi tiết tour và trang sửa thông tin tour.
 *   GET  /admin/tours/{id}/location
 *   POST /admin/tours/{id}/location – latitude, longitude, intent ('save' | 'clear'), _csrf
 */
final class AdminTourLocationController extends AdminController
{
    private const MESSAGES = [
        'saved' => 'Đã lưu vị trí điểm khởi hành.',
        'cleared' => 'Đã xóa vị trí điểm khởi hành. Trang tour không còn hiện bản đồ.',
        'unchanged' => 'Vị trí không thay đổi.',
    ];

    private TourLocationModel $locations;

    public function __construct()
    {
        parent::__construct();
        $this->locations = new TourLocationModel();
    }

    /** GET /admin/tours/{id}/location */
    public function edit(string $id): void
    {
        $tour = $this->findOrFail($id);
        if ($tour === null) {
            $this->renderUnavailable();
            return;
        }

        $this->renderForm($tour, [
            'latitude' => $tour['latitude'] === null ? '' : self::trimCoord((string) $tour['latitude']),
            'longitude' => $tour['longitude'] === null ? '' : self::trimCoord((string) $tour['longitude']),
        ], [], $this->flash(self::MESSAGES));
    }

    /** POST /admin/tours/{id}/location */
    public function update(string $id): void
    {
        $tour = $this->findOrFail($id);
        if ($tour === null) {
            $this->renderUnavailable();
            return;
        }

        $clear = $this->input('intent') === 'clear';
        $old = $clear ? ['latitude' => '', 'longitude' => ''] : [
            'latitude' => $this->input('latitude'),
            'longitude' => $this->input('longitude'),
        ];
        if (!$this->csrfValid()) {
            $this->renderForm($tour, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        [$latitude, $longitude, $errors] = self::validate($old['latitude'], $old['longitude']);
        if ($errors !== []) {
            $this->renderForm($tour, $old, $errors, '', 422);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->locations->setLocation($this->actorId(), $tourId, $latitude, $longitude);
        match ($row['result']) {
            'ok' => $this->redirect('/admin/tours/' . $tourId . '/location?msg=saved'),
            'cleared' => $this->redirect('/admin/tours/' . $tourId . '/location?msg=cleared'),
            'unchanged' => $this->redirect('/admin/tours/' . $tourId . '/location?msg=unchanged'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->renderForm($tour, $old, self::fieldError($row['field']), '', 422),
        };
    }

    /**
     * "21,0317" hoặc "21.0317" → chuỗi số 6 chữ số thập phân; hai ô trống = xóa vị trí.
     *
     * @return array{0: string|null, 1: string|null, 2: array<string, string>}
     */
    public static function validate(string $latitude, string $longitude): array
    {
        $latitude = str_replace(',', '.', trim($latitude));
        $longitude = str_replace(',', '.', trim($longitude));
        if ($latitude === '' && $longitude === '') {
            return [null, null, []];
        }

        $errors = [];
        $number = '/^-?\d{1,3}(\.\d{1,10})?$/';
        if ($latitude === '') {
            $errors['latitude'] = 'Nhập cả vĩ độ và kinh độ, hoặc để trống cả hai để xóa vị trí.';
        } elseif (!preg_match($number, $latitude)) {
            $errors['latitude'] = 'Vĩ độ là số thập phân, ví dụ 21.0285.';
        } elseif ((float) $latitude < TourLocationModel::LAT_MIN || (float) $latitude > TourLocationModel::LAT_MAX) {
            $errors['latitude'] = 'Vĩ độ phải từ 8 đến 23,5 (trong lãnh thổ Việt Nam).';
        }
        if ($longitude === '') {
            $errors['longitude'] = 'Nhập cả vĩ độ và kinh độ, hoặc để trống cả hai để xóa vị trí.';
        } elseif (!preg_match($number, $longitude)) {
            $errors['longitude'] = 'Kinh độ là số thập phân, ví dụ 105.8542.';
        } elseif ((float) $longitude < TourLocationModel::LNG_MIN || (float) $longitude > TourLocationModel::LNG_MAX) {
            $errors['longitude'] = 'Kinh độ phải từ 102 đến 110 (trong lãnh thổ Việt Nam).';
        }

        if ($errors !== []) {
            return [null, null, $errors];
        }

        return [number_format((float) $latitude, 6, '.', ''), number_format((float) $longitude, 6, '.', ''), []];
    }

    /** "21.031704" → "21.031704", "16.068500" → "16.0685" */
    private static function trimCoord(string $value): string
    {
        return str_contains($value, '.') ? rtrim(rtrim($value, '0'), '.') : $value;
    }

    /** @return array<string, string> */
    private static function fieldError(?string $field): array
    {
        return match ($field) {
            'latitude' => ['latitude' => 'Vĩ độ phải từ 8 đến 23,5 (trong lãnh thổ Việt Nam).'],
            'longitude' => ['longitude' => 'Kinh độ phải từ 102 đến 110 (trong lãnh thổ Việt Nam).'],
            default => ['form' => 'Không lưu được vị trí, vui lòng kiểm tra lại.'],
        };
    }

    /**
     * Tour theo mã (404 nếu sai mã / không có); null khi chưa chạy file 23 (thiếu procedure).
     *
     * @return array<string, mixed>|null
     */
    private function findOrFail(string $id): ?array
    {
        $tourId = self::parseUuid($id);
        if ($tourId === null) {
            self::notFound();
        }

        try {
            $tour = $this->locations->adminFind($tourId);
        } catch (PDOException $exception) {
            error_log('Bản đồ tour: chưa đọc được vị trí tour, có thể chưa chạy database/23_map_places_NTK.sql: ' . $exception->getMessage());

            return null;
        }

        return $tour ?? self::notFound();
    }

    /**
     * @param array<string, mixed> $tour
     * @param array{latitude: string, longitude: string} $old
     * @param array<string, string> $errors
     */
    private function renderForm(array $tour, array $old, array $errors, string $success, int $status = 200): void
    {
        $this->render('admin/tours/location', [
            'title' => 'Điểm khởi hành trên bản đồ',
            'adminNav' => 'tours',
            'tour' => $tour,
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'ready' => true,
            'pageStyles' => ['css/admin.css', 'css/tour-map.css'],
            'pageScripts' => ['js/tour-map.js'],
        ], $status);
    }

    private function renderUnavailable(): void
    {
        $this->render('admin/tours/location', [
            'title' => 'Điểm khởi hành trên bản đồ',
            'adminNav' => 'tours',
            'tour' => null,
            'old' => ['latitude' => '', 'longitude' => ''],
            'errors' => [],
            'success' => '',
            'ready' => false,
            'pageStyles' => ['css/admin.css'],
        ], 503);
    }
}
