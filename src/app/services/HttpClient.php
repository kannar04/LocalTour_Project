<?php

declare(strict_types=1);

namespace App\Services;

/**
 * Gọi API bên ngoài (Google, Facebook, reCAPTCHA) bằng curl, nhận JSON (Nguyễn Tuấn Khôi).
 * Thời gian chờ ngắn để trang không bị treo khi mạng chậm; không tự đi theo chuyển hướng.
 * Không ghi URL đầy đủ vào log vì URL có thể chứa khóa bí mật.
 */
final class HttpClient
{
    private const CONNECT_TIMEOUT_SECONDS = 5;
    private const TIMEOUT_SECONDS = 10;

    /**
     * POST dạng form (application/x-www-form-urlencoded).
     *
     * @param array<string, string> $fields
     * @param list<string> $headers
     * @return array{status: int, json: array<string, mixed>|null} status 0 = không kết nối được hoặc quá thời gian chờ
     */
    public static function postForm(string $url, array $fields, array $headers = []): array
    {
        return self::send($url, http_build_query($fields, '', '&'), $headers);
    }

    /**
     * GET, tham số $query được nối vào URL.
     *
     * @param array<string, string> $query
     * @param list<string> $headers
     * @return array{status: int, json: array<string, mixed>|null}
     */
    public static function get(string $url, array $query = [], array $headers = []): array
    {
        if ($query !== []) {
            $url .= (str_contains($url, '?') ? '&' : '?') . http_build_query($query, '', '&', PHP_QUERY_RFC3986);
        }

        return self::send($url, null, $headers);
    }

    /**
     * @param list<string> $headers
     * @return array{status: int, json: array<string, mixed>|null}
     */
    private static function send(string $url, ?string $body, array $headers): array
    {
        $host = (string) parse_url($url, PHP_URL_HOST);
        if (!function_exists('curl_init') || !preg_match('#^https?://#i', $url) || $host === '') {
            error_log('HttpClient: không gọi được ' . ($host !== '' ? $host : 'địa chỉ không hợp lệ') . ' (thiếu curl hoặc URL sai).');

            return ['status' => 0, 'json' => null];
        }

        $handle = curl_init($url);
        $options = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_CONNECTTIMEOUT => self::CONNECT_TIMEOUT_SECONDS,
            CURLOPT_TIMEOUT => self::TIMEOUT_SECONDS,
            CURLOPT_HTTPHEADER => array_merge(['Accept: application/json'], $headers),
            CURLOPT_USERAGENT => 'LocalTour/1.0',
        ];
        if ($body !== null) {
            $options[CURLOPT_POST] = true;
            $options[CURLOPT_POSTFIELDS] = $body;
        }
        curl_setopt_array($handle, $options);

        $response = curl_exec($handle);
        if (!is_string($response)) {
            error_log('HttpClient: lỗi kết nối tới ' . $host . ': ' . curl_error($handle));

            return ['status' => 0, 'json' => null];
        }

        $json = json_decode($response, true);

        return [
            'status' => (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE),
            'json' => is_array($json) ? $json : null,
        ];
    }
}
