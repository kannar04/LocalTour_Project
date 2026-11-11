<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\UserModel;
use Core\Auth;

/**
 * Đăng nhập bằng Google / Facebook cho khách hàng, OAuth 2.0 authorization code (Nguyễn Tuấn Khôi).
 * Google: https://developers.google.com/identity/protocols/oauth2/web-server (scope openid email profile).
 * Facebook: https://developers.facebook.com/docs/facebook-login/guides/advanced/manual-flow (Graph API v27.0).
 * Mỗi lần bắt đầu đăng nhập tạo một mã state ngẫu nhiên lưu trong session (dùng một lần, hết hạn sau 10 phút)
 * cùng trang quay lại (next) và địa chỉ trả về đã dùng.
 */
final class SocialLogin
{
    public const LABELS = ['google' => 'Google', 'facebook' => 'Facebook'];

    private const STATE_KEY = 'social_login_states';
    private const STATE_TTL_SECONDS = 600;
    private const STATE_MAX = 5;
    private const FLASH_KEY = 'auth_flash';

    /** Nhà cung cấp có đủ mã ứng dụng và khóa bí mật trong .env. */
    public static function enabled(string $provider): bool
    {
        $config = self::config($provider);

        return $config !== null && $config['client_id'] !== '' && $config['client_secret'] !== '';
    }

    /**
     * Nút "Tiếp tục với …" cho trang đăng nhập / đăng ký; chỉ nhà cung cấp đang bật.
     *
     * @return list<array{provider: string, label: string, href: string}>
     */
    public static function buttons(string $next): array
    {
        $buttons = [];
        foreach (self::LABELS as $provider => $label) {
            if (self::enabled($provider)) {
                $buttons[] = [
                    'provider' => $provider,
                    'label' => 'Tiếp tục với ' . $label,
                    'href' => url('/auth/' . $provider) . ($next !== '/tours' ? '?next=' . rawurlencode($next) : ''),
                ];
            }
        }

        return $buttons;
    }

    /**
     * Địa chỉ nhà cung cấp trả khách về: *_REDIRECT_URI nếu có, ngược lại theo địa chỉ khách đang mở
     * (giống VNPAY_RETURN_URL). Phải trùng với địa chỉ đã khai báo ở Google Cloud / Facebook.
     *
     * @throws SocialLoginException
     */
    public static function redirectUri(string $provider): string
    {
        $configured = self::config($provider)['redirect_uri'] ?? '';
        if ($configured !== '') {
            return $configured;
        }

        $path = url('/auth/' . $provider . '/callback');
        if (preg_match('#^https?://#i', $path)) {
            return $path;
        }
        $host = (string) ($_SERVER['HTTP_HOST'] ?? '');
        if (!preg_match('/^[A-Za-z0-9.\-]+(:\d{1,5})?$/D', $host)) {
            throw new SocialLoginException('config', 'Không xác định được địa chỉ trang web để ' . $provider . ' trả kết quả.');
        }
        $https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';

        return ($https ? 'https://' : 'http://') . $host . $path;
    }

    /** Địa chỉ trang đăng nhập của nhà cung cấp (bước 1). */
    public static function authorizeUrl(string $provider, string $state, string $redirectUri): string
    {
        $config = self::config($provider) ?? [];
        $params = [
            'client_id' => $config['client_id'] ?? '',
            'redirect_uri' => $redirectUri,
            'response_type' => 'code',
            'state' => $state,
        ];
        if ($provider === 'google') {
            $params += ['scope' => 'openid email profile', 'prompt' => 'select_account'];
        } else {
            // rerequest: khách từng bỏ chọn quyền email thì Facebook hỏi lại.
            $params += ['scope' => 'public_profile,email', 'auth_type' => 'rerequest'];
        }
        $url = $config['authorize_url'] ?? '';

        return $url . (str_contains($url, '?') ? '&' : '?') . http_build_query($params, '', '&', PHP_QUERY_RFC3986);
    }

    /**
     * Đổi mã xác thực (code) lấy access token rồi đọc thông tin tài khoản (bước 2, 3).
     * email = '' khi nhà cung cấp không trả email hợp lệ.
     *
     * @return array{id: string, email: string, email_verified: bool, name: string}
     * @throws SocialLoginException
     */
    public static function fetchProfile(string $provider, string $code, string $redirectUri): array
    {
        $config = self::config($provider);
        if ($config === null) {
            throw new SocialLoginException('config', 'Nhà cung cấp không hợp lệ: ' . $provider);
        }

        return $provider === 'google'
            ? self::googleProfile($config, $code, $redirectUri)
            : self::facebookProfile($config, $code, $redirectUri);
    }

    /**
     * Tạo mã state cho một lần đăng nhập và lưu vào session cùng trang quay lại.
     * Giữ tối đa 5 lần đăng nhập đang dở (nhiều tab), bỏ mã đã hết hạn.
     */
    public static function rememberState(string $provider, string $next, string $redirectUri): string
    {
        Auth::start();
        $now = time();
        $states = is_array($_SESSION[self::STATE_KEY] ?? null) ? $_SESSION[self::STATE_KEY] : [];
        $states = array_filter(
            $states,
            static fn (mixed $entry): bool => is_array($entry) && ($entry['at'] ?? 0) > $now - self::STATE_TTL_SECONDS
        );
        $states = array_slice($states, -(self::STATE_MAX - 1), null, true);

        $state = bin2hex(random_bytes(32));
        $states[$state] = ['provider' => $provider, 'next' => $next, 'redirect_uri' => $redirectUri, 'at' => $now];
        $_SESSION[self::STATE_KEY] = $states;

        return $state;
    }

    /**
     * Lấy và xóa (dùng một lần) lần đăng nhập ứng với mã state; null khi mã sai, đã dùng, hết hạn
     * hoặc thuộc nhà cung cấp khác.
     *
     * @return array{provider: string, next: string, redirect_uri: string, at: int}|null
     */
    public static function takeState(string $provider, string $state): ?array
    {
        Auth::start();
        $states = is_array($_SESSION[self::STATE_KEY] ?? null) ? $_SESSION[self::STATE_KEY] : [];
        if ($state === '' || !preg_match('/^[0-9a-f]{64}$/D', $state) || !isset($states[$state])) {
            return null;
        }

        $entry = $states[$state];
        unset($states[$state]);
        $_SESSION[self::STATE_KEY] = $states;

        $valid = is_array($entry) && ($entry['provider'] ?? null) === $provider
            && is_string($entry['next'] ?? null) && is_string($entry['redirect_uri'] ?? null)
            && (int) ($entry['at'] ?? 0) > time() - self::STATE_TTL_SECONDS;

        return $valid ? $entry : null;
    }

    /** Thông báo hiện một lần ở trang đăng nhập / đăng ký sau khi chuyển hướng. */
    public static function flash(string $message): void
    {
        Auth::start();
        $_SESSION[self::FLASH_KEY] = $message;
    }

    public static function pullFlash(): string
    {
        Auth::start();
        $message = $_SESSION[self::FLASH_KEY] ?? '';
        unset($_SESSION[self::FLASH_KEY]);

        return is_string($message) ? $message : '';
    }

    /**
     * @param array<string, string> $config
     * @return array{id: string, email: string, email_verified: bool, name: string}
     */
    private static function googleProfile(array $config, string $code, string $redirectUri): array
    {
        $token = HttpClient::postForm($config['token_url'], [
            'code' => $code,
            'client_id' => $config['client_id'],
            'client_secret' => $config['client_secret'],
            'redirect_uri' => $redirectUri,
            'grant_type' => 'authorization_code',
        ]);
        $accessToken = self::accessToken('Google', $token);

        $data = self::profileJson('Google', HttpClient::get($config['userinfo_url'], [], ['Authorization: Bearer ' . $accessToken]));
        $email = self::email($data['email'] ?? null);
        $verified = $data['email_verified'] ?? false;

        return [
            'id' => self::subject('Google', $data['sub'] ?? null),
            'email' => $email,
            'email_verified' => $verified === true || $verified === 'true',
            'name' => self::name($data['name'] ?? null, $email),
        ];
    }

    /**
     * @param array<string, string> $config
     * @return array{id: string, email: string, email_verified: bool, name: string}
     */
    private static function facebookProfile(array $config, string $code, string $redirectUri): array
    {
        $token = HttpClient::get($config['token_url'], [
            'client_id' => $config['client_id'],
            'redirect_uri' => $redirectUri,
            'client_secret' => $config['client_secret'],
            'code' => $code,
        ]);
        $accessToken = self::accessToken('Facebook', $token);

        $data = self::profileJson('Facebook', HttpClient::get($config['userinfo_url'], [
            'fields' => 'id,name,email',
            'access_token' => $accessToken,
            'appsecret_proof' => hash_hmac('sha256', $accessToken, $config['client_secret']),
        ]));
        $email = self::email($data['email'] ?? null);

        // Facebook chỉ trả email chính đã xác nhận của tài khoản; không có thì không trả trường email.
        return [
            'id' => self::subject('Facebook', $data['id'] ?? null),
            'email' => $email,
            'email_verified' => $email !== '',
            'name' => self::name($data['name'] ?? null, $email),
        ];
    }

    /** @param array{status: int, json: array<string, mixed>|null} $response */
    private static function accessToken(string $label, array $response): string
    {
        if ($response['status'] === 0) {
            throw new SocialLoginException('network', $label . ': không kết nối được khi đổi mã lấy token.');
        }

        $token = $response['json']['access_token'] ?? null;
        if ($response['status'] !== 200 || !is_string($token) || $token === '') {
            // Google: error là chuỗi (invalid_grant...); Facebook: error là object có message.
            $error = $response['json']['error'] ?? null;
            $detail = is_string($error) ? $error : (is_string($error['message'] ?? null) ? $error['message'] : '');
            throw new SocialLoginException('token', $label . ': đổi mã lấy token thất bại (HTTP ' . $response['status']
                . ($detail !== '' ? ', ' . mb_substr($detail, 0, 200) : '') . ').');
        }

        return $token;
    }

    /**
     * @param array{status: int, json: array<string, mixed>|null} $response
     * @return array<string, mixed>
     */
    private static function profileJson(string $label, array $response): array
    {
        if ($response['status'] === 0) {
            throw new SocialLoginException('network', $label . ': không kết nối được khi đọc thông tin tài khoản.');
        }
        if ($response['status'] !== 200 || $response['json'] === null) {
            throw new SocialLoginException('profile', $label . ': không đọc được thông tin tài khoản (HTTP ' . $response['status'] . ').');
        }

        return $response['json'];
    }

    private static function subject(string $label, mixed $value): string
    {
        $value = is_int($value) ? (string) $value : $value;
        if (!is_string($value) || !preg_match('/^[A-Za-z0-9_.\-]{1,255}$/D', $value)) {
            throw new SocialLoginException('profile', $label . ': mã tài khoản không hợp lệ.');
        }

        return $value;
    }

    /** Email chữ thường; '' khi thiếu hoặc không hợp lệ. */
    private static function email(mixed $value): string
    {
        if (!is_string($value) || !mb_check_encoding($value, 'UTF-8')) {
            return '';
        }
        $email = mb_strtolower(trim($value));

        return mb_strlen($email) <= UserModel::EMAIL_MAX_LENGTH && filter_var($email, FILTER_VALIDATE_EMAIL) !== false ? $email : '';
    }

    /** Tên hiển thị (tối đa 100 ký tự); thiếu tên thì lấy phần trước @ của email. */
    private static function name(mixed $value, string $email): string
    {
        $name = is_string($value) && mb_check_encoding($value, 'UTF-8')
            ? trim((string) preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $value))
            : '';
        if ($name === '') {
            $name = (string) strstr($email, '@', true);
        }

        return mb_substr($name, 0, UserModel::NAME_MAX_LENGTH);
    }

    /** @return array<string, string>|null */
    private static function config(string $provider): ?array
    {
        static $config = null;
        if (!isset(self::LABELS[$provider])) {
            return null;
        }
        $config ??= require BASE_PATH . '/config/auth.php';

        return $config[$provider];
    }
}
