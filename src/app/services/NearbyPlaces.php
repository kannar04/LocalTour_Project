<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\PlaceCacheModel;
use RuntimeException;

/**
 * Địa điểm du lịch quanh điểm khởi hành của tour (Nguyễn Tuấn Khôi), chia 4 nhóm:
 * an_uong (quán ăn), bar, giai_tri (giải trí), quan_nuoc (cà phê, trà, trà sữa, nước ép, kem).
 * Nguồn: Overpass API (dữ liệu © OpenStreetMap contributors), lưu ở map_place_cache theo điểm làm tròn
 * 4 chữ số thập phân (khoảng 11 m):
 *   - kết quả còn hạn (7 ngày) → dùng luôn, không gọi mạng (source 'cache');
 *   - hết hạn / chưa có → gọi Overpass (source 'live'); lỗi → dùng kết quả cũ (source 'stale') hoặc
 *     trả danh sách rỗng kèm thông báo (source 'none'); sau khi lỗi 10 phút mới gọi lại.
 * Lỗi SQL (chưa chạy file 23) được ném ra cho controller.
 */
final class NearbyPlaces
{
    public const GROUPS = ['an_uong' => 'Quán ăn', 'bar' => 'Bar', 'giai_tri' => 'Giải trí', 'quan_nuoc' => 'Quán nước'];
    public const MESSAGE_FAILED = 'Chưa tải được địa điểm, thử lại sau.';

    private const PAYLOAD_VERSION = 1;

    /** @var array<string, mixed> */
    private array $config;
    private PlaceCacheModel $cache;
    private OverpassClient $client;

    /** @param array<string, mixed>|null $config mặc định config/map.php */
    public function __construct(?array $config = null, ?PlaceCacheModel $cache = null, ?OverpassClient $client = null)
    {
        $this->config = $config ?? require BASE_PATH . '/config/map.php';
        $this->cache = $cache ?? new PlaceCacheModel();
        $this->client = $client ?? new OverpassClient($this->config);
    }

    /**
     * @return array{radius_m: int, source: string, fetched_at: string|null, message: string,
     *               labels: array<string, string>, counts: array<string, int>, groups: array<string, list<array<string, mixed>>>}
     */
    public function around(float $lat, float $lng): array
    {
        $radius = (int) $this->config['radius_m'];
        $centerLat = round($lat, 4);
        $centerLng = round($lng, 4);
        $key = sprintf('%.4F,%.4F,%d', $centerLat, $centerLng, $radius);

        $row = $this->cache->get($key);
        $cached = $row === null ? null : self::decode($row['payload'] ?? null);
        $fetchedAt = $row === null || $row['fetched_at'] === null ? null : (string) $row['fetched_at'];

        if ($cached !== null && $row['age_seconds'] !== null && (int) $row['age_seconds'] < (int) $this->config['cache_ttl']) {
            return $this->result($cached, $lat, $lng, 'cache', $fetchedAt, '');
        }

        $failedRecently = $row !== null && $row['failed_seconds'] !== null
            && (int) $row['failed_seconds'] < (int) $this->config['retry_after'];
        if (!$failedRecently) {
            try {
                $fetched = $this->client->fetch($centerLat, $centerLng, $radius);
                $groups = self::group($fetched['elements'], $centerLat, $centerLng, (int) $this->config['per_group']);
                $payload = json_encode(
                    ['v' => self::PAYLOAD_VERSION, 'groups' => $groups],
                    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
                );
                if ($payload === false) {
                    throw new RuntimeException('không mã hóa được JSON địa điểm');
                }
                $count = array_sum(array_map('count', $groups));
                $this->cache->save($key, $centerLat, $centerLng, $radius, $payload, $count, $fetched['source']);

                return $this->result($groups, $lat, $lng, 'live', date('Y-m-d H:i:s'), '');
            } catch (RuntimeException $exception) {
                error_log('Bản đồ tour: ' . $exception->getMessage() . ' [' . $key . ']');
                $this->cache->fail($key, $centerLat, $centerLng, $radius);
            }
        }

        if ($cached !== null) {
            $message = 'Chưa cập nhật được địa điểm mới, đang hiển thị dữ liệu lưu'
                . ($fetchedAt !== null ? ' ngày ' . format_date($fetchedAt) : '') . '.';

            return $this->result($cached, $lat, $lng, 'stale', $fetchedAt, $message);
        }

        return $this->result(array_fill_keys(array_keys(self::GROUPS), []), $lat, $lng, 'none', null, self::MESSAGE_FAILED);
    }

    /**
     * Phần tử Overpass → nhóm địa điểm có tên, gần nhất trước, tối đa $perGroup mỗi nhóm.
     *
     * @param list<array<string, mixed>> $elements
     * @return array<string, list<array<string, mixed>>>
     */
    public static function group(array $elements, float $lat, float $lng, int $perGroup): array
    {
        $groups = array_fill_keys(array_keys(self::GROUPS), []);
        $seen = [];

        foreach ($elements as $element) {
            $tags = is_array($element['tags'] ?? null) ? $element['tags'] : [];
            $name = trim((string) ($tags['name'] ?? ''));
            $pointLat = $element['lat'] ?? ($element['center']['lat'] ?? null);
            $pointLng = $element['lon'] ?? ($element['center']['lon'] ?? null);
            $kind = self::classify($tags);
            if ($name === '' || !is_numeric($pointLat) || !is_numeric($pointLng) || $kind === null) {
                continue;
            }

            [$group, $type] = $kind;
            $pointLat = round((float) $pointLat, 6);
            $pointLng = round((float) $pointLng, 6);
            // Cùng tên, cùng nhóm, cách nhau vài chục mét (vd. điểm và tòa nhà của cùng một quán) → giữ một.
            $dedupe = $group . '|' . mb_strtolower($name) . '|' . round($pointLat, 3) . '|' . round($pointLng, 3);
            if (isset($seen[$dedupe])) {
                continue;
            }
            $seen[$dedupe] = true;

            $place = [
                'name' => mb_substr($name, 0, 120),
                'lat' => $pointLat,
                'lng' => $pointLng,
                'distance_m' => self::distance($lat, $lng, $pointLat, $pointLng),
                'type' => $type,
            ];
            $address = self::address($tags);
            if ($address !== '') {
                $place['address'] = $address;
            }
            $hours = trim((string) ($tags['opening_hours'] ?? ''));
            if ($hours !== '') {
                $place['opening_hours'] = mb_substr($hours, 0, 120);
            }
            if (isset($element['type'], $element['id'])) {
                $place['osm'] = $element['type'] . '/' . $element['id'];
            }
            $groups[$group][] = $place;
        }

        foreach ($groups as $group => $places) {
            usort($places, static fn (array $a, array $b): int => $a['distance_m'] <=> $b['distance_m']);
            $groups[$group] = array_slice($places, 0, $perGroup);
        }

        return $groups;
    }

    /**
     * Thẻ OSM → [nhóm, nhãn loại] hoặc null nếu không thuộc nhóm nào.
     *
     * @param array<string, mixed> $tags
     * @return array{0: string, 1: string}|null
     */
    public static function classify(array $tags): ?array
    {
        $amenity = (string) ($tags['amenity'] ?? '');
        $cuisine = strtolower(trim(explode(';', (string) ($tags['cuisine'] ?? ''))[0]));
        $drinks = ['bubble_tea' => 'Trà sữa', 'juice' => 'Nước ép, sinh tố', 'smoothie' => 'Nước ép, sinh tố',
            'tea' => 'Quán trà', 'coffee_shop' => 'Quán cà phê'];

        $food = ['restaurant' => 'Nhà hàng', 'fast_food' => 'Đồ ăn nhanh', 'food_court' => 'Khu ẩm thực'];
        if (isset($food[$amenity])) {
            // Quán ghi là nhà hàng / đồ ăn nhanh nhưng món chính là đồ uống → quán nước.
            return $amenity !== 'food_court' && isset($drinks[$cuisine]) ? ['quan_nuoc', $drinks[$cuisine]] : ['an_uong', $food[$amenity]];
        }

        $bars = ['bar' => 'Bar', 'pub' => 'Quán pub', 'nightclub' => 'Hộp đêm', 'biergarten' => 'Vườn bia'];
        if (isset($bars[$amenity])) {
            return ['bar', $bars[$amenity]];
        }

        if ($amenity === 'cafe') {
            return ['quan_nuoc', $drinks[$cuisine] ?? 'Quán cà phê'];
        }
        $drinkAmenities = ['ice_cream' => 'Kem', 'juice_bar' => 'Nước ép, sinh tố'];
        if (isset($drinkAmenities[$amenity])) {
            return ['quan_nuoc', $drinkAmenities[$amenity]];
        }

        $shows = ['cinema' => 'Rạp chiếu phim', 'theatre' => 'Nhà hát', 'arts_centre' => 'Trung tâm nghệ thuật'];
        if (isset($shows[$amenity])) {
            return ['giai_tri', $shows[$amenity]];
        }

        $shops = ['tea' => 'Trà', 'bubble_tea' => 'Trà sữa', 'juice' => 'Nước ép, sinh tố'];
        $shop = (string) ($tags['shop'] ?? '');
        if (isset($shops[$shop])) {
            return ['quan_nuoc', $shops[$shop]];
        }

        $tourism = ['attraction' => 'Điểm tham quan', 'museum' => 'Bảo tàng', 'gallery' => 'Phòng tranh',
            'theme_park' => 'Khu vui chơi', 'zoo' => 'Vườn thú', 'aquarium' => 'Thủy cung'];
        $tourismTag = (string) ($tags['tourism'] ?? '');
        if (isset($tourism[$tourismTag])) {
            return ['giai_tri', $tourism[$tourismTag]];
        }

        $leisure = ['park' => 'Công viên', 'water_park' => 'Công viên nước'];
        $leisureTag = (string) ($tags['leisure'] ?? '');
        if (isset($leisure[$leisureTag])) {
            return ['giai_tri', $leisure[$leisureTag]];
        }

        return null;
    }

    /** Khoảng cách theo đường chim bay (mét, công thức haversine). */
    public static function distance(float $lat1, float $lng1, float $lat2, float $lng2): int
    {
        $rad = M_PI / 180;
        $dLat = ($lat2 - $lat1) * $rad;
        $dLng = ($lng2 - $lng1) * $rad;
        $a = sin($dLat / 2) ** 2 + cos($lat1 * $rad) * cos($lat2 * $rad) * sin($dLng / 2) ** 2;

        return (int) round(6371000 * 2 * atan2(sqrt($a), sqrt(1 - $a)));
    }

    /** @param array<string, mixed> $tags */
    private static function address(array $tags): string
    {
        $full = trim((string) ($tags['addr:full'] ?? ''));
        if ($full === '') {
            $full = trim(trim((string) ($tags['addr:housenumber'] ?? '')) . ' ' . trim((string) ($tags['addr:street'] ?? '')));
        }

        return mb_substr($full, 0, 160);
    }

    /** @return array<string, list<array<string, mixed>>>|null */
    private static function decode(mixed $payload): ?array
    {
        if (!is_string($payload) || $payload === '') {
            return null;
        }

        $data = json_decode($payload, true);
        if (!is_array($data) || ($data['v'] ?? null) !== self::PAYLOAD_VERSION || !is_array($data['groups'] ?? null)) {
            return null;
        }

        $groups = [];
        foreach (array_keys(self::GROUPS) as $group) {
            $groups[$group] = array_values(array_filter((array) ($data['groups'][$group] ?? []), 'is_array'));
        }

        return $groups;
    }

    /**
     * Khoảng cách tính lại từ đúng điểm khởi hành của tour (khóa bộ nhớ đệm là điểm đã làm tròn).
     *
     * @param array<string, list<array<string, mixed>>> $groups
     * @return array{radius_m: int, source: string, fetched_at: string|null, message: string,
     *               labels: array<string, string>, counts: array<string, int>, groups: array<string, list<array<string, mixed>>>}
     */
    private function result(array $groups, float $lat, float $lng, string $source, ?string $fetchedAt, string $message): array
    {
        $counts = [];
        foreach ($groups as $group => $places) {
            foreach ($places as $index => $place) {
                $places[$index]['distance_m'] = self::distance($lat, $lng, (float) $place['lat'], (float) $place['lng']);
            }
            usort($places, static fn (array $a, array $b): int => $a['distance_m'] <=> $b['distance_m']);
            $groups[$group] = $places;
            $counts[$group] = count($places);
        }

        return [
            'radius_m' => (int) $this->config['radius_m'],
            'source' => $source,
            'fetched_at' => $fetchedAt,
            'message' => $message,
            'labels' => self::GROUPS,
            'counts' => $counts,
            'groups' => $groups,
        ];
    }
}
