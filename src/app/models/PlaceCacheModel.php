<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Bộ nhớ đệm địa điểm quanh một điểm (Nguyễn Tuấn Khôi), bảng map_place_cache.
 * Procedure: NTK_sp_place_cache_get, NTK_sp_place_cache_save, NTK_sp_place_cache_fail (file 23_map_places_NTK.sql).
 * Lỗi SQL (chưa chạy file 23) được ném ra để NearbyPlaces xử lý.
 */
final class PlaceCacheModel
{
    /**
     * Dòng bộ nhớ đệm hoặc null: payload (JSON | null), source, fetched_at, age_seconds, failed_seconds (null = chưa có).
     *
     * @return array<string, mixed>|null
     */
    public function get(string $key): ?array
    {
        return Database::call('NTK_sp_place_cache_get', [$key])[0] ?? null;
    }

    public function save(string $key, float $lat, float $lng, int $radius, string $payload, int $count, string $source): void
    {
        Database::call('NTK_sp_place_cache_save', [$key, self::coord($lat), self::coord($lng), $radius, $payload, $count, $source]);
    }

    public function fail(string $key, float $lat, float $lng, int $radius): void
    {
        Database::call('NTK_sp_place_cache_fail', [$key, self::coord($lat), self::coord($lng), $radius]);
    }

    private static function coord(float $value): string
    {
        return number_format($value, 6, '.', '');
    }
}
