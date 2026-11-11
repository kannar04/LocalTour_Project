<?php

declare(strict_types=1);

namespace App\Services;

/**
 * reCAPTCHA v2 (ô "Tôi không phải người máy") ở /login, /register và /admin/login (Nguyễn Tuấn Khôi).
 * Tắt khi thiếu RECAPTCHA_SITE_KEY hoặc RECAPTCHA_SECRET_KEY: không hiện ô xác nhận, không kiểm tra.
 * Mã xác nhận trình duyệt gửi lên (g-recaptcha-response) được kiểm tra với Google
 * (https://developers.google.com/recaptcha/docs/verify) trước khi kiểm tra mật khẩu.
 */
final class Recaptcha
{
    public const FAILED_MESSAGE = 'Vui lòng xác nhận bạn không phải robot.';
    public const UNAVAILABLE_MESSAGE = 'Chưa kiểm tra được ô xác nhận "không phải robot" do lỗi kết nối. Vui lòng thử lại.';
    private const TOKEN_MAX_LENGTH = 4096;

    /** Khóa hiển thị ô xác nhận trên trang; '' = reCAPTCHA đang tắt. */
    public static function siteKey(): string
    {
        $config = self::config();

        return self::enabled($config) ? $config['site_key'] : '';
    }

    /**
     * Kiểm tra ô xác nhận của form vừa gửi. null = hợp lệ (hoặc reCAPTCHA đang tắt);
     * ngược lại là thông báo lỗi và mã HTTP để hiện lại form (422 chưa xác nhận / sai, 503 lỗi kết nối).
     *
     * @return array{message: string, code: int}|null
     */
    public static function check(): ?array
    {
        $config = self::config();
        if (!self::enabled($config)) {
            return null;
        }

        $token = $_POST['g-recaptcha-response'] ?? '';
        if (!is_string($token) || trim($token) === '' || strlen($token) > self::TOKEN_MAX_LENGTH) {
            return ['message' => self::FAILED_MESSAGE, 'code' => 422];
        }

        $fields = ['secret' => $config['secret_key'], 'response' => $token];
        $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '');
        if (filter_var($ip, FILTER_VALIDATE_IP) !== false) {
            $fields['remoteip'] = $ip;
        }

        $response = HttpClient::postForm($config['verify_url'], $fields);
        $json = $response['json'];
        if ($response['status'] === 0 || $response['status'] >= 500 || $json === null) {
            error_log('reCAPTCHA: không kiểm tra được (HTTP ' . $response['status'] . ').');

            return ['message' => self::UNAVAILABLE_MESSAGE, 'code' => 503];
        }
        if (($json['success'] ?? false) === true) {
            return null;
        }

        $errors = is_array($json['error-codes'] ?? null) ? array_filter($json['error-codes'], 'is_string') : [];
        if (array_intersect($errors, ['missing-input-secret', 'invalid-input-secret']) !== []) {
            error_log('reCAPTCHA: RECAPTCHA_SECRET_KEY trong .env không đúng.');
        }

        return ['message' => self::FAILED_MESSAGE, 'code' => 422];
    }

    /** @param array<string, string> $config */
    private static function enabled(array $config): bool
    {
        return $config['site_key'] !== '' && $config['secret_key'] !== '';
    }

    /** @return array<string, string> */
    private static function config(): array
    {
        static $config = null;
        $config ??= (require BASE_PATH . '/config/auth.php')['recaptcha'];

        return $config;
    }
}
