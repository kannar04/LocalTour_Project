<?php

declare(strict_types=1);

namespace Core;

/**
 * Phiên đăng nhập của khách hàng và mã CSRF cho mọi form POST (WBS 3.2.8 – Lê Trung Phong).
 * Chưa đăng nhập = chế độ khách: chỉ xem tour, không đặt được.
 * Session chỉ lưu thông tin hiển thị của tài khoản (user_id, name, email, role, avatar_url), không lưu mật khẩu.
 * CR2 (Lê Trung Phong): thêm avatar_url (ảnh đại diện, đường dẫn trong public/assets/, null = chưa có ảnh) và
 * refresh() để trang "Tài khoản" cập nhật họ tên / ảnh trong session sau khi lưu.
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
     * @return array{user_id: string, name: string, email: string, role: string, avatar_url?: string|null}|null
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
     *        Thiếu avatar_url (tài khoản vừa đăng ký, đăng nhập Google / Facebook) = chưa có ảnh.
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
            'avatar_url' => self::avatarOrNull($user['avatar_url'] ?? null),
        ];
        // Phiên mới thì mã CSRF mới.
        unset($_SESSION[self::CSRF_KEY]);
    }

    /**
     * Cập nhật thông tin hiển thị của tài khoản đang đăng nhập (sau khi sửa ở trang "Tài khoản").
     * Chỉ nhận khóa 'name' và 'avatar_url'; chưa đăng nhập thì không làm gì.
     *
     * @param array{name?: string, avatar_url?: string|null} $changes
     */
    public static function refresh(array $changes): void
    {
        self::start();
        if (!is_array($_SESSION[self::USER_KEY] ?? null)) {
            return;
        }
        if (array_key_exists('name', $changes) && is_string($changes['name']) && $changes['name'] !== '') {
            $_SESSION[self::USER_KEY]['name'] = $changes['name'];
        }
        if (array_key_exists('avatar_url', $changes)) {
            $_SESSION[self::USER_KEY]['avatar_url'] = self::avatarOrNull($changes['avatar_url']);
        }
    }

    /**
     * Đổi session id, giữ nguyên tài khoản đăng nhập (vd. sau khi đổi mật khẩu): phiên cũ bị lộ không còn dùng được.
     */
    public static function regenerate(): void
    {
        self::start();
        session_regenerate_id(true);
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

    /** avatar_url hợp lệ để in ra: chuỗi không rỗng; còn lại null (giao diện hiện chữ cái đầu tên). */
    private static function avatarOrNull(mixed $value): ?string
    {
        return is_string($value) && trim($value) !== '' ? $value : null;
    }

    private static function isHttps(): bool
    {
        $https = $_SERVER['HTTPS'] ?? '';

        return ($https !== '' && strtolower((string) $https) !== 'off') || (int) ($_SERVER['SERVER_PORT'] ?? 0) === 443;
    }
}
