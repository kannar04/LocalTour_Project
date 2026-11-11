<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;
use PDOException;

/**
 * Vị trí điểm khởi hành của tour (Nguyễn Tuấn Khôi): bản đồ ở trang chi tiết tour, trang /ban-do và trang quản trị.
 * Procedure: NTK_sp_tour_location, NTK_sp_tour_location_list, NTK_sp_admin_tour_location,
 *            NTK_sp_admin_tour_set_location (file 23_map_places_NTK.sql).
 * Chưa chạy file 23 (thiếu cột / procedure): các hàm đọc của trang khách trả null và ghi error_log,
 * trang vẫn hiển thị nhưng không có bản đồ.
 */
final class TourLocationModel
{
    /** Khung tọa độ Việt Nam dùng để kiểm tra (giống NTK_sp_admin_tour_set_location). */
    public const LAT_MIN = 8.0;
    public const LAT_MAX = 23.5;
    public const LNG_MIN = 102.0;
    public const LNG_MAX = 110.0;

    /**
     * Điểm khởi hành của tour đang hiển thị; null nếu tour chưa có vị trí, không hiển thị hoặc chưa chạy file 23.
     *
     * @return array{tour_id: string, title: string, lat: float, lng: float, pickup_mode: string, meeting_point: string}|null
     */
    public function point(string $tourId): ?array
    {
        $rows = self::safeCall('NTK_sp_tour_location', [$tourId]);
        $row = $rows[0] ?? null;
        if ($row === null || $row['latitude'] === null || $row['longitude'] === null) {
            return null;
        }

        return self::pointRow($row);
    }

    /**
     * Các tour đang hiển thị đã có vị trí (trang /ban-do); null khi chưa chạy file 23 hoặc lỗi đọc dữ liệu.
     *
     * @return list<array<string, mixed>>|null
     */
    public function published(): ?array
    {
        $rows = self::safeCall('NTK_sp_tour_location_list', []);
        if ($rows === null) {
            return null;
        }

        return array_map(static fn (array $row): array => self::pointRow($row) + [
            'destination_name' => (string) ($row['destination_name'] ?? ''),
            'category_name' => (string) ($row['category_name'] ?? ''),
            'duration_minutes' => (int) ($row['duration_minutes'] ?? 0),
            'cover_image_url' => $row['cover_image_url'] === null ? null : (string) $row['cover_image_url'],
            'cover_alt_text' => (string) ($row['cover_alt_text'] ?? ''),
        ], $rows);
    }

    /**
     * Vị trí của tour ở mọi trạng thái (trang quản trị); null nếu không có tour.
     * Ném PDOException khi chưa chạy file 23 (controller báo cho quản trị viên).
     *
     * @return array<string, mixed>|null
     */
    public function adminFind(string $tourId): ?array
    {
        return Database::call('NTK_sp_admin_tour_location', [$tourId])[0] ?? null;
    }

    /**
     * Đặt vị trí (hai chuỗi số đã kiểm tra) hoặc xóa (hai null).
     *
     * @return array{result: string, field: string|null}
     */
    public function setLocation(string $actorUserId, string $tourId, ?string $latitude, ?string $longitude): array
    {
        $rows = Database::call('NTK_sp_admin_tour_set_location', [$actorUserId, $tourId, $latitude, $longitude]);
        $row = $rows[0] ?? [];

        return ['result' => (string) ($row['result'] ?? 'not_found'), 'field' => isset($row['field']) ? (string) $row['field'] : null];
    }

    /** Tọa độ nằm trong khung Việt Nam. */
    public static function inBounds(float $lat, float $lng): bool
    {
        return $lat >= self::LAT_MIN && $lat <= self::LAT_MAX && $lng >= self::LNG_MIN && $lng <= self::LNG_MAX;
    }

    /**
     * @param array<string, mixed> $row
     * @return array{tour_id: string, title: string, lat: float, lng: float, pickup_mode: string, meeting_point: string}
     */
    private static function pointRow(array $row): array
    {
        return [
            'tour_id' => (string) $row['tour_id'],
            'title' => (string) $row['title'],
            'lat' => (float) $row['latitude'],
            'lng' => (float) $row['longitude'],
            'pickup_mode' => (string) $row['pickup_mode'],
            'meeting_point' => trim((string) ($row['meeting_point'] ?? '')),
        ];
    }

    /**
     * Gọi procedure đọc; lỗi SQL (thiếu procedure / cột vì chưa chạy file 23) → null và ghi error_log.
     * Mất kết nối cơ sở dữ liệu (Core\DatabaseException) vẫn ném ra như các trang khác.
     *
     * @param list<int|string|null> $params
     * @return list<array<string, mixed>>|null
     */
    private static function safeCall(string $procedure, array $params): ?array
    {
        try {
            return Database::call($procedure, $params);
        } catch (PDOException $exception) {
            error_log('Bản đồ tour: không đọc được vị trí (' . $procedure . '), có thể chưa chạy database/23_map_places_NTK.sql: '
                . $exception->getMessage());

            return null;
        }
    }
}
