<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\HostModel;
use App\Models\UserModel;
use App\Services\Recaptcha;
use Core\Auth;
use Core\Controller;

/**
 * Đăng nhập và đăng xuất đơn vị tổ chức ở /host/login (Nguyễn Tuấn Khôi).
 * Chỉ tài khoản role 'provider', đang hoạt động, có mật khẩu và đơn vị đang hợp tác mới đăng nhập được.
 * Đơn vị không tự đăng ký: quản trị viên thêm đơn vị ở trang "Đơn vị tổ chức" rồi cấp mật khẩu. Tài khoản đơn vị
 * tách riêng với tài khoản khách hàng (mỗi email một tài khoản). Khách hàng đăng nhập ở /login, quản trị viên ở
 * /admin/login.
 */
final class HostAuthController extends Controller
{
    private const LOGIN_FAILED = 'Email hoặc mật khẩu không đúng.';
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';
    private const NOT_ACTIVE = 'Đơn vị chưa được duyệt hoặc đã ngừng hợp tác nên chưa đăng nhập được. Vui lòng liên hệ quản trị viên LocalTour.';
    private const PENDING = 'Đơn vị đang chờ quản trị viên LocalTour duyệt. Sau khi được duyệt, bạn đăng nhập bằng email và mật khẩu quản trị viên đã cấp.';

    private UserModel $users;

    public function __construct()
    {
        header('Cache-Control: no-store');
        $this->users = new UserModel();
    }

    /** GET /host/login?next=&stopped=1 */
    public function showLogin(): void
    {
        $next = self::hostNext($this->query('next'));
        if ((Auth::user()['role'] ?? null) === 'provider') {
            $this->redirect($next);
        }

        // stopped=1: phiên vừa bị kết thúc vì đơn vị ngừng hợp tác hoặc tài khoản bị khóa (AdminController).
        $this->renderLogin($next, '', $this->query('stopped') === '1' ? self::NOT_ACTIVE : '');
    }

    /** POST /host/login – email, password, next, _csrf */
    public function login(): void
    {
        $next = self::hostNext($this->input('next'));
        $email = mb_strtolower($this->input('email'));

        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderLogin($next, $email, self::CSRF_FAILED, 403);
            return;
        }

        $password = $this->input('password', false);
        if ($email === '' || $password === '') {
            $this->renderLogin($next, $email, 'Vui lòng nhập email và mật khẩu.', 422);
            return;
        }
        // Kiểm tra ô "không phải robot" (khi đã cấu hình reCAPTCHA) trước khi kiểm tra mật khẩu.
        $captcha = Recaptcha::check();
        if ($captcha !== null) {
            $this->renderLogin($next, $email, $captcha['message'], $captcha['code']);
            return;
        }

        $user = mb_strlen($email) <= UserModel::EMAIL_MAX_LENGTH ? $this->users->findByEmail($email) : null;
        // Sai email, sai mật khẩu, chưa có mật khẩu, tài khoản bị khóa hay không phải đơn vị tổ chức: cùng một thông báo.
        if (!self::canLogIn($user, $password)) {
            $this->renderLogin($next, $email, self::LOGIN_FAILED, 401);
            return;
        }
        // Đúng mật khẩu nhưng đơn vị đang chờ duyệt hoặc đã ngừng hợp tác.
        $profile = (new HostModel())->profile((string) $user['user_id']);
        if (!HostModel::isActive($profile)) {
            $isPending = ($profile['approval_status'] ?? '') === 'pending';
            $this->renderLogin($next, $email, $isPending ? self::PENDING : self::NOT_ACTIVE, 403);
            return;
        }

        // Đăng nhập đơn vị thay phiên hiện tại (kể cả khi đang đăng nhập tài khoản khác).
        Auth::login($user);
        $this->redirect($next);
    }

    /** POST /host/logout – _csrf */
    public function logout(): void
    {
        if (Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            Auth::logout();
        }

        $this->redirect('/host/login');
    }

    /** Chỉ quay lại trang trong khu đơn vị tổ chức; còn lại về /host. */
    private static function hostNext(string $next): string
    {
        $next = safe_next_path($next);
        $path = (string) parse_url($next, PHP_URL_PATH);
        $isHostPage = ($path === '/host' || str_starts_with($path, '/host/')) && $path !== '/host/login';

        return $isHostPage ? $next : '/host';
    }

    /** @param array<string, mixed>|null $user */
    private static function canLogIn(?array $user, string $password): bool
    {
        if ($user === null || $user['role'] !== 'provider' || $user['status'] !== 'active') {
            return false;
        }

        $hash = $user['password_hash'];

        return is_string($hash) && $hash !== '' && password_verify($password, $hash);
    }

    private function renderLogin(string $next, string $email, string $error, int $status = 200): void
    {
        $this->render('host/login', [
            'title' => 'Đăng nhập đơn vị tổ chức',
            'next' => $next,
            'email' => $email,
            'error' => $error,
            'recaptchaSiteKey' => Recaptcha::siteKey(),
            'pageStyles' => ['css/auth.css'],
        ], $status);
    }
}
