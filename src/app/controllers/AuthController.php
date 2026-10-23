<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\UserModel;
use Core\Auth;
use Core\Controller;

/**
 * Đăng ký, đăng nhập và đăng xuất tài khoản khách hàng (WBS 3.2.8 – Nguyễn Tuấn Khôi).
 * Chỉ tài khoản role 'customer' đăng nhập ở đây. Chưa đăng nhập = chế độ khách: xem tour, không đặt được.
 */
final class AuthController extends Controller
{
    private const LOGIN_FAILED = 'Email hoặc mật khẩu không đúng.';
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';

    private UserModel $users;

    public function __construct()
    {
        $this->users = new UserModel();
    }

    /** GET /login?next= */
    public function showLogin(): void
    {
        if (Auth::check()) {
            $this->redirect(safe_next_path($this->query('next')));
        }

        $this->renderLogin(safe_next_path($this->query('next')), '', '');
    }

    /** POST /login – email, password, next, _csrf */
    public function login(): void
    {
        $next = safe_next_path($this->input('next'));
        $email = mb_strtolower($this->input('email'));

        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderLogin($next, $email, self::CSRF_FAILED, 403);
            return;
        }
        if (Auth::check()) {
            $this->redirect($next);
        }

        $password = $this->input('password', false);
        if ($email === '' || $password === '') {
            $this->renderLogin($next, $email, 'Vui lòng nhập email và mật khẩu.', 422);
            return;
        }

        $user = mb_strlen($email) <= UserModel::EMAIL_MAX_LENGTH ? $this->users->findByEmail($email) : null;
        // Sai email, sai mật khẩu, tài khoản bị khóa hay không phải khách hàng đều cùng một thông báo.
        if (!self::canLogIn($user, $password)) {
            $this->renderLogin($next, $email, self::LOGIN_FAILED, 401);
            return;
        }

        Auth::login($user);
        $this->redirect($next);
    }

    /** GET /register?next= */
    public function showRegister(): void
    {
        if (Auth::check()) {
            $this->redirect(safe_next_path($this->query('next')));
        }

        $this->renderRegister(safe_next_path($this->query('next')), ['name' => '', 'email' => '', 'phone' => ''], []);
    }

    /** POST /register – name, email, phone (không bắt buộc), password, password_confirm, next, _csrf */
    public function register(): void
    {
        $next = safe_next_path($this->input('next'));
        $old = [
            'name' => $this->input('name'),
            'email' => mb_strtolower($this->input('email')),
            'phone' => $this->input('phone'),
        ];

        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderRegister($next, $old, ['form' => self::CSRF_FAILED], 403);
            return;
        }
        if (Auth::check()) {
            $this->redirect($next);
        }

        $password = $this->input('password', false);
        $errors = self::validateRegistration($old, $password, $this->input('password_confirm', false));
        if ($errors !== []) {
            $this->renderRegister($next, $old, $errors, 422);
            return;
        }

        $userId = $this->users->registerCustomer($old['name'], $old['email'], $old['phone'], password_hash($password, PASSWORD_DEFAULT));
        if ($userId === null) {
            $this->renderRegister($next, $old, ['email' => 'Email này đã được dùng.'], 409);
            return;
        }

        // Đăng ký xong thì đăng nhập luôn.
        Auth::login(['user_id' => $userId, 'name' => $old['name'], 'email' => $old['email'], 'role' => 'customer']);
        $this->redirect($next);
    }

    /** POST /logout – _csrf. Thiếu hoặc sai mã CSRF thì không đăng xuất (chặn trang khác tự đăng xuất khách). */
    public function logout(): void
    {
        if (Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            Auth::logout();
        }

        $this->redirect('/tours');
    }

    /** @param array<string, mixed>|null $user */
    private static function canLogIn(?array $user, string $password): bool
    {
        if ($user === null || $user['role'] !== 'customer' || $user['status'] !== 'active') {
            return false;
        }

        // password_hash NULL = tài khoản chưa đặt mật khẩu (vd. tài khoản mẫu), không đăng nhập được.
        $hash = $user['password_hash'];

        return is_string($hash) && $hash !== '' && password_verify($password, $hash);
    }

    /**
     * Lỗi theo từng ô của form đăng ký; [] khi hợp lệ.
     *
     * @param array{name: string, email: string, phone: string} $old
     * @return array<string, string>
     */
    private static function validateRegistration(array $old, string $password, string $passwordConfirm): array
    {
        $errors = [];

        if ($old['name'] === '') {
            $errors['name'] = 'Vui lòng nhập họ tên.';
        } elseif (mb_strlen($old['name']) > UserModel::NAME_MAX_LENGTH) {
            $errors['name'] = 'Họ tên tối đa ' . UserModel::NAME_MAX_LENGTH . ' ký tự.';
        }

        if ($old['email'] === '') {
            $errors['email'] = 'Vui lòng nhập email.';
        } elseif (mb_strlen($old['email']) > UserModel::EMAIL_MAX_LENGTH || filter_var($old['email'], FILTER_VALIDATE_EMAIL) === false) {
            $errors['email'] = 'Email không hợp lệ.';
        }

        // Số điện thoại không bắt buộc: 8–20 ký tự gồm chữ số và khoảng trắng, có thể bắt đầu bằng +.
        if ($old['phone'] !== '' && !preg_match('/^\+?[0-9 ]{8,19}$/', $old['phone'])) {
            $errors['phone'] = 'Số điện thoại không hợp lệ.';
        }

        if (mb_strlen($password) < UserModel::PASSWORD_MIN_LENGTH) {
            $errors['password'] = 'Mật khẩu tối thiểu ' . UserModel::PASSWORD_MIN_LENGTH . ' ký tự.';
        } elseif (strlen($password) > UserModel::PASSWORD_MAX_LENGTH) {
            $errors['password'] = 'Mật khẩu quá dài (tối đa ' . UserModel::PASSWORD_MAX_LENGTH . ' byte, mỗi chữ có dấu tính 2–3 byte).';
        } elseif ($password !== $passwordConfirm) {
            $errors['password_confirm'] = 'Mật khẩu nhập lại không khớp.';
        }

        return $errors;
    }

    private function renderLogin(string $next, string $email, string $error, int $status = 200): void
    {
        $this->render('auth/login', [
            'title' => 'Đăng nhập',
            'next' => $next,
            'email' => $email,
            'error' => $error,
            'pageStyles' => ['css/auth.css'],
        ], $status);
    }

    /**
     * @param array{name: string, email: string, phone: string} $old
     * @param array<string, string> $errors
     */
    private function renderRegister(string $next, array $old, array $errors, int $status = 200): void
    {
        $this->render('auth/register', [
            'title' => 'Đăng ký tài khoản',
            'next' => $next,
            'old' => $old,
            'errors' => $errors,
            'pageStyles' => ['css/auth.css'],
        ], $status);
    }
}
