<?php

declare(strict_types=1);

namespace App\Services;

use RuntimeException;

/**
 * Gọi Overpass API từ máy chủ (Nguyễn Tuấn Khôi): một truy vấn lấy các địa điểm có tên quanh một điểm.
 * Dùng extension curl, có thời gian chờ ngắn; máy chủ đầu lỗi thì thử máy chủ dự phòng (config/map.php).
 * Trình duyệt không bao giờ gọi Overpass trực tiếp.
 */
final class OverpassClient
{
    /** Giá trị thẻ OSM được lấy, theo khóa. */
    public const TAGS = [
        'amenity' => ['restaurant', 'fast_food', 'food_court', 'bar', 'pub', 'nightclub', 'biergarten',
            'cafe', 'ice_cream', 'juice_bar', 'cinema', 'theatre', 'arts_centre'],
        'tourism' => ['attraction', 'museum', 'gallery', 'theme_park', 'zoo', 'aquarium'],
        'leisure' => ['park', 'water_park'],
        'shop' => ['tea', 'bubble_tea', 'juice'],
    ];

    /** Giây tối thiểu còn lại để thử thêm một máy chủ. */
    private const MIN_ATTEMPT_SECONDS = 4;

    /** @param array<string, mixed> $config config/map.php */
    public function __construct(private readonly array $config)
    {
    }

    /** Truy vấn Overpass QL: node / way / relation có tên, trong bán kính $radius mét quanh ($lat, $lng). */
    public static function query(float $lat, float $lng, int $radius): string
    {
        $around = sprintf('(around:%d,%.6F,%.6F)', $radius, $lat, $lng);
        $lines = ['[out:json][timeout:15];', '('];
        foreach (self::TAGS as $key => $values) {
            $lines[] = sprintf('  nwr["%s"~"^(%s)$"]["name"]%s;', $key, implode('|', $values), $around);
        }
        $lines[] = ');';
        $lines[] = 'out center tags;';

        return implode("\n", $lines);
    }

    /**
     * @return array{elements: list<array<string, mixed>>, source: string}
     * @throws RuntimeException khi mọi máy chủ Overpass đều lỗi
     */
    public function fetch(float $lat, float $lng, int $radius): array
    {
        if (!function_exists('curl_init')) {
            throw new RuntimeException('PHP chưa bật extension curl.');
        }

        $query = self::query($lat, $lng, $radius);
        $errors = [];
        // Tổng thời gian cho mọi máy chủ không quá 'timeout' giây: máy dự phòng chỉ được thử khi máy chính lỗi
        // nhanh (từ chối kết nối, HTTP 429 / 5xx) và còn ít nhất MIN_ATTEMPT_SECONDS.
        $deadline = microtime(true) + (int) $this->config['timeout'];
        foreach ($this->config['overpass_urls'] as $url) {
            $host = (string) (parse_url($url, PHP_URL_HOST) ?: $url);
            $remaining = (int) floor($deadline - microtime(true));
            if ($remaining < self::MIN_ATTEMPT_SECONDS) {
                $errors[] = $host . ': bỏ qua, hết thời gian chờ';
                break;
            }
            try {
                return ['elements' => $this->post($url, $query, $remaining), 'source' => $host];
            } catch (RuntimeException $exception) {
                $errors[] = $host . ': ' . $exception->getMessage();
            }
        }

        throw new RuntimeException('Không gọi được Overpass (' . implode('; ', $errors) . ')');
    }

    /** @return list<array<string, mixed>> */
    private function post(string $url, string $query, int $timeout): array
    {
        $curl = curl_init($url);
        if ($curl === false) {
            throw new RuntimeException('curl_init lỗi');
        }

        curl_setopt_array($curl, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query(['data' => $query], '', '&'),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_PROTOCOLS => CURLPROTO_HTTP | CURLPROTO_HTTPS,
            CURLOPT_CONNECTTIMEOUT => min((int) $this->config['connect_timeout'], $timeout),
            CURLOPT_TIMEOUT => $timeout,
            CURLOPT_USERAGENT => (string) $this->config['user_agent'],
            CURLOPT_HTTPHEADER => ['Accept: application/json'],
            CURLOPT_ENCODING => '',
        ]);

        $body = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $error = curl_error($curl);
        curl_close($curl);

        if (!is_string($body)) {
            throw new RuntimeException('curl: ' . $error);
        }
        if ($status !== 200) {
            throw new RuntimeException('HTTP ' . $status);
        }

        $data = json_decode($body, true);
        if (!is_array($data) || !isset($data['elements']) || !is_array($data['elements'])) {
            throw new RuntimeException('dữ liệu trả về không phải JSON Overpass');
        }

        // Overpass trả 200 kèm "remark" khi truy vấn hết giờ / hết bộ nhớ: kết quả có thể thiếu, coi là lỗi.
        $remark = (string) ($data['remark'] ?? '');
        if ($remark !== '' && stripos($remark, 'error') !== false) {
            throw new RuntimeException('Overpass: ' . mb_substr($remark, 0, 200));
        }

        return array_values(array_filter($data['elements'], 'is_array'));
    }
}
