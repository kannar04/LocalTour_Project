<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\UserModel;
use Core\Auth;
use Core\Controller;

/**
 * Đăng nhập / đăng xuất quản trị viên ở trang riêng /admin/login (NFR-04).
 * Chỉ tài khoản role 'admin', đang hoạt động và đã đặt mật khẩu mới đăng nhập được.
 * Khách hàng đăng nhập ở /login (AuthController).
 */
final class AdminAuthController extends Controller
{
    private const LOGIN_FAILED = 'Email hoặc mật khẩu không đúng.';
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';

    private UserModel $users;

    public function __construct()
    {
        header('Cache-Control: no-store');
        $this->users = new UserModel();
    }

    /** GET /admin/login?next= */
    public function showLogin(): void
    {
        $next = self::adminNext($this->query('next'));
        if ((Auth::user()['role'] ?? null) === 'admin') {
            $this->redirect($next);
        }

        $this->renderLogin($next, '', '');
    }

    /** POST /admin/login – email, password, next, _csrf */
    public function login(): void
    {
        $next = self::adminNext($this->input('next'));
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

        $user = mb_strlen($email) <= UserModel::EMAIL_MAX_LENGTH ? $this->users->findByEmail($email) : null;
        // Sai email, sai mật khẩu, tài khoản bị khóa hay không phải quản trị viên đều cùng một thông báo.
        if (!self::canLogIn($user, $password)) {
            $this->renderLogin($next, $email, self::LOGIN_FAILED, 401);
            return;
        }

        // Đăng nhập quản trị thay phiên hiện tại (kể cả khi đang đăng nhập tài khoản khách hàng).
        Auth::login($user);
        $this->redirect($next);
    }

    /** POST /admin/logout – _csrf */
    public function logout(): void
    {
        if (Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            Auth::logout();
        }

        $this->redirect('/admin/login');
    }

    /** Chỉ quay lại trang trong khu quản trị; còn lại về /admin. */
    private static function adminNext(string $next): string
    {
        $next = safe_next_path($next);
        $path = (string) parse_url($next, PHP_URL_PATH);
        $isAdminPage = ($path === '/admin' || str_starts_with($path, '/admin/')) && $path !== '/admin/login';

        return $isAdminPage ? $next : '/admin';
    }

    /** @param array<string, mixed>|null $user */
    private static function canLogIn(?array $user, string $password): bool
    {
        if ($user === null || $user['role'] !== 'admin' || $user['status'] !== 'active') {
            return false;
        }

        $hash = $user['password_hash'];

        return is_string($hash) && $hash !== '' && password_verify($password, $hash);
    }

    private function renderLogin(string $next, string $email, string $error, int $status = 200): void
    {
        $this->render('admin/login', [
            'title' => 'Đăng nhập quản trị',
            'next' => $next,
            'email' => $email,
            'error' => $error,
            'pageStyles' => ['css/auth.css'],
        ], $status);
    }
}
