<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\UserModel;
use App\Services\SocialLogin;
use App\Services\SocialLoginException;
use Core\Auth;
use Core\Controller;

/**
 * Đăng nhập bằng Google / Facebook cho tài khoản khách hàng (Nguyễn Tuấn Khôi).
 * GET /auth/{google|facebook}?next= : tạo mã state rồi chuyển sang trang đăng nhập của nhà cung cấp.
 * GET /auth/{google|facebook}/callback : kiểm tra state, đổi code lấy thông tin tài khoản, liên kết / tạo tài khoản
 * (NTK_sp_social_login) rồi đăng nhập như AuthController. Mọi lỗi đều quay về /login kèm thông báo, không có trang lỗi.
 * Không cần captcha: nhà cung cấp đã xác thực người dùng.
 */
final class SocialAuthController extends Controller
{
    private const CODE_MAX_LENGTH = 2048;

    private UserModel $users;

    public function __construct()
    {
        header('Cache-Control: no-store');
        $this->users = new UserModel();
    }

    /** GET /auth/google?next= */
    public function google(): void
    {
        $this->start('google');
    }

    /** GET /auth/google/callback?code=&state= (hoặc ?error=access_denied&state= khi khách hủy) */
    public function googleCallback(): void
    {
        $this->finish('google');
    }

    /** GET /auth/facebook?next= */
    public function facebook(): void
    {
        $this->start('facebook');
    }

    /** GET /auth/facebook/callback?code=&state= (hoặc ?error=access_denied&error_reason=user_denied&state=) */
    public function facebookCallback(): void
    {
        $this->finish('facebook');
    }

    private function start(string $provider): never
    {
        $next = safe_next_path($this->query('next'));
        if (Auth::check()) {
            $this->redirect($next);
        }
        if (!SocialLogin::enabled($provider)) {
            $this->fail($provider, 'disabled', $next);
        }

        try {
            $redirectUri = SocialLogin::redirectUri($provider);
        } catch (SocialLoginException $exception) {
            error_log($exception->getMessage());
            $this->fail($provider, 'unavailable', $next);
        }

        $state = SocialLogin::rememberState($provider, $next, $redirectUri);
        header('Location: ' . SocialLogin::authorizeUrl($provider, $state, $redirectUri), true, 303);
        exit;
    }

    private function finish(string $provider): never
    {
        $entry = SocialLogin::takeState($provider, $this->query('state'));
        $next = safe_next_path($entry['next'] ?? null);

        $error = $this->query('error');
        if ($error !== '') {
            $this->fail($provider, $error === 'access_denied' ? 'cancelled' : 'denied', $next);
        }
        if ($entry === null) {
            $this->fail($provider, 'state', $next);
        }
        if (!SocialLogin::enabled($provider)) {
            $this->fail($provider, 'disabled', $next);
        }

        $code = $this->query('code');
        if ($code === '' || strlen($code) > self::CODE_MAX_LENGTH) {
            $this->fail($provider, 'token', $next);
        }

        try {
            $profile = SocialLogin::fetchProfile($provider, $code, $entry['redirect_uri']);
        } catch (SocialLoginException $exception) {
            error_log($exception->getMessage());
            $this->fail($provider, $exception->reason() === 'network' ? 'network' : 'token', $next);
        }

        if ($profile['email'] === '') {
            $this->fail($provider, 'no_email', $next);
        }
        if (!$profile['email_verified']) {
            $this->fail($provider, 'unverified', $next);
        }

        $account = $this->users->socialLogin($provider, $profile['id'], $profile['email'], $profile['name']);
        $result = (string) ($account['result'] ?? '');
        if (!in_array($result, ['existing', 'linked', 'created'], true)) {
            $this->fail($provider, in_array($result, ['not_customer', 'locked'], true) ? $result : 'unavailable', $next);
        }

        // Giống đăng nhập bằng mật khẩu: đổi session id, ghi tài khoản vào session, mã CSRF mới.
        Auth::login($account);
        $this->redirect($next);
    }

    /** Quay về trang đăng nhập (thiếu email: trang đăng ký) kèm thông báo, giữ trang quay lại. */
    private function fail(string $provider, string $reason, string $next): never
    {
        SocialLogin::flash(self::message($provider, $reason));
        $page = $reason === 'no_email' ? '/register' : '/login';

        $this->redirect($page . ($next !== '/tours' ? '?next=' . rawurlencode($next) : ''));
    }

    private static function message(string $provider, string $reason): string
    {
        $label = SocialLogin::LABELS[$provider] ?? $provider;

        return match ($reason) {
            'disabled' => 'Đăng nhập bằng ' . $label . ' đang tạm ngưng. Vui lòng đăng nhập bằng email.',
            'cancelled' => 'Bạn đã hủy đăng nhập bằng ' . $label . '. Bạn có thể thử lại hoặc đăng nhập bằng email.',
            'denied' => $label . ' chưa cho phép đăng nhập. Vui lòng thử lại hoặc đăng nhập bằng email.',
            'state' => 'Phiên đăng nhập bằng ' . $label . ' đã hết hạn hoặc không hợp lệ. Vui lòng thử lại.',
            'network' => 'Không kết nối được tới ' . $label . '. Vui lòng kiểm tra mạng rồi thử lại.',
            'token' => $label . ' không xác nhận được lần đăng nhập này. Vui lòng thử lại hoặc đăng nhập bằng email.',
            'no_email' => 'Tài khoản ' . $label . ' của bạn không cung cấp email nên chưa đăng nhập được. Vui lòng đăng ký bằng email.',
            'unverified' => 'Email của tài khoản ' . $label . ' này chưa được xác minh. Vui lòng xác minh email với ' . $label
                . ' hoặc đăng ký bằng email.',
            'not_customer' => 'Email này thuộc tài khoản quản trị viên hoặc đơn vị tổ chức nên không đăng nhập ở đây được.',
            'locked' => 'Tài khoản LocalTour gắn với email này đang bị khóa. Vui lòng liên hệ LocalTour để được hỗ trợ.',
            default => 'Chưa đăng nhập được bằng ' . $label . ' lúc này. Vui lòng thử lại sau hoặc đăng nhập bằng email.',
        };
    }
}
