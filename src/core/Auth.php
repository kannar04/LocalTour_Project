<?php

declare(strict_types=1);

namespace Core;

/**
 * Phiên đăng nhập của khách hàng và mã CSRF cho mọi form POST (WBS 3.2.8 – Lê Trung Phong).
 * Chưa đăng nhập = chế độ khách: chỉ xem tour, không đặt được.
 * Session chỉ lưu thông tin hiển thị của tài khoản (user_id, name, email, role), không lưu mật khẩu.
 */
final class Auth
{
    private const USER_KEY = 'auth_user';
    private const CSRF_KEY = 'csrf_token';

    /** Mở session (nếu chưa mở) với cookie httponly, SameSite=Lax; secure khi chạy HTTPS. */
    public static function start(): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) {
            return;
        }

        ini_set('session.use_strict_mode', '1');
        ini_set('session.use_only_cookies', '1');
        session_name('localtour_session');
        session_set_cookie_params([
            'lifetime' => 0,
            'path' => base_path_prefix() . '/',
            'secure' => self::isHttps(),
            'httponly' => true,
            'samesite' => 'Lax',
        ]);
        session_start();
    }

    /**
     * Tài khoản đang đăng nhập; null = chế độ khách.
     *
     * @return array{user_id: string, name: string, email: string, role: string}|null
     */
    public static function user(): ?array
    {
        self::start();
        $user = $_SESSION[self::USER_KEY] ?? null;

        return is_array($user) ? $user : null;
    }

    public static function check(): bool
    {
        return self::user() !== null;
    }

    /**
     * Ghi tài khoản vào session sau khi kiểm tra mật khẩu. Đổi session id để chống chiếm phiên (session fixation).
     *
     * @param array<string, mixed> $user Dòng từ NTK_sp_user_find_by_email (hoặc tài khoản vừa đăng ký).
     */
    public static function login(array $user): void
    {
        self::start();
        session_regenerate_id(true);
        $_SESSION[self::USER_KEY] = [
            'user_id' => (string) $user['user_id'],
            'name' => (string) $user['name'],
            'email' => (string) $user['email'],
            'role' => (string) $user['role'],
        ];
        // Phiên mới thì mã CSRF mới.
        unset($_SESSION[self::CSRF_KEY]);
    }

    /** Xóa toàn bộ session và cookie phiên. */
    public static function logout(): void
    {
        self::start();
        $_SESSION = [];

        $cookie = session_get_cookie_params();
        setcookie(session_name(), '', [
            'expires' => time() - 3600,
            'path' => $cookie['path'],
            'secure' => $cookie['secure'],
            'httponly' => $cookie['httponly'],
            'samesite' => $cookie['samesite'],
        ]);
        session_destroy();
    }

    /** Mã CSRF của phiên hiện tại (tạo mới nếu chưa có). */
    public static function csrfToken(): string
    {
        self::start();
        if (!is_string($_SESSION[self::CSRF_KEY] ?? null)) {
            $_SESSION[self::CSRF_KEY] = bin2hex(random_bytes(32));
        }

        return $_SESSION[self::CSRF_KEY];
    }

    /** So mã CSRF gửi lên với mã trong session (so sánh thời gian cố định). */
    public static function verifyCsrf(mixed $token): bool
    {
        self::start();
        $expected = $_SESSION[self::CSRF_KEY] ?? null;

        return is_string($token) && $token !== '' && is_string($expected) && hash_equals($expected, $token);
    }

    private static function isHttps(): bool
    {
        $https = $_SERVER['HTTPS'] ?? '';

        return ($https !== '' && strtolower((string) $https) !== 'off') || (int) ($_SERVER['SERVER_PORT'] ?? 0) === 443;
    }
}
