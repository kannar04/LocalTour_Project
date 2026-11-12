<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminProviderModel;
use App\Models\HostModel;
use App\Models\UserModel;
use App\Services\Recaptcha;
use Core\Auth;
use Core\Controller;

/**
 * Đăng ký, đăng nhập và đăng xuất đơn vị tổ chức ở /host/register, /host/login (Nguyễn Tuấn Khôi).
 * Chỉ tài khoản role 'provider', đang hoạt động, có mật khẩu và đơn vị đang hợp tác mới đăng nhập được.
 * Đơn vị có tài khoản theo 2 cách: tự đăng ký ở /host/register (đơn vị ở trạng thái "Chờ duyệt" cho tới khi quản trị
 * viên duyệt ở "Đơn vị tổ chức"), hoặc quản trị viên thêm đơn vị rồi cấp mật khẩu. Tài khoản đơn vị tách riêng với
 * tài khoản khách hàng (mỗi email một tài khoản). Khách hàng đăng nhập ở /login, quản trị viên ở /admin/login.
 */
final class HostAuthController extends Controller
{
    private const LOGIN_FAILED = 'Email hoặc mật khẩu không đúng.';
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';
    private const NOT_ACTIVE = 'Đơn vị chưa được duyệt hoặc đã ngừng hợp tác nên chưa đăng nhập được. Vui lòng liên hệ quản trị viên LocalTour.';
    private const PENDING = 'Đơn vị đang chờ quản trị viên LocalTour duyệt. Sau khi được duyệt, bạn đăng nhập bằng email và mật khẩu đã đăng ký.';
    private const REGISTERED = 'Đã gửi đăng ký. Quản trị viên LocalTour sẽ duyệt đơn vị; sau khi được duyệt, bạn đăng nhập bằng email và mật khẩu vừa đặt.';
    private const EMAIL_TAKEN = 'Email này đã có tài khoản. Vui lòng dùng một email khác cho đơn vị.';
    /** Lỗi theo ô khi procedure từ chối dữ liệu (đã qua kiểm tra của PHP). */
    private const FIELD_ERRORS = [
        'business_name' => 'Tên đơn vị không hợp lệ.',
        'contact_phone' => 'Số điện thoại không hợp lệ.',
        'email' => 'Email không hợp lệ.',
    ];

    private UserModel $users;

    public function __construct()
    {
        header('Cache-Control: no-store');
        $this->users = new UserModel();
    }

    /** GET /host/login?next=&stopped=1&registered=1 */
    public function showLogin(): void
    {
        $next = self::hostNext($this->query('next'));
        if ((Auth::user()['role'] ?? null) === 'provider') {
            $this->redirect($next);
        }

        // stopped=1: phiên vừa bị kết thúc vì đơn vị ngừng hợp tác hoặc tài khoản bị khóa (AdminController).
        // registered=1: vừa gửi đăng ký ở /host/register.
        $this->renderLogin(
            $next,
            '',
            $this->query('stopped') === '1' ? self::NOT_ACTIVE : '',
            200,
            $this->query('registered') === '1' ? self::REGISTERED : ''
        );
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
        // Đúng mật khẩu nhưng đơn vị đang chờ duyệt (vừa tự đăng ký) hoặc đã ngừng hợp tác.
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

    /** GET /host/register */
    public function showRegister(): void
    {
        if ((Auth::user()['role'] ?? null) === 'provider') {
            $this->redirect('/host');
        }

        $this->renderRegister(['business_name' => '', 'contact_phone' => '', 'email' => ''], []);
    }

    /**
     * POST /host/register – business_name, contact_phone, email, password, password_confirm, _csrf.
     * Đăng ký xong chưa đăng nhập: đơn vị ở trạng thái "Chờ duyệt", quản trị viên duyệt rồi mới đăng nhập được.
     */
    public function register(): void
    {
        $old = [
            'business_name' => $this->input('business_name'),
            'contact_phone' => $this->input('contact_phone'),
            'email' => mb_strtolower($this->input('email')),
        ];

        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderRegister($old, ['form' => self::CSRF_FAILED], 403);
            return;
        }

        $password = $this->input('password', false);
        $errors = self::validateRegistration($old, $password, $this->input('password_confirm', false));
        if ($errors !== []) {
            $this->renderRegister($old, $errors, 422);
            return;
        }
        $captcha = Recaptcha::check();
        if ($captcha !== null) {
            $this->renderRegister($old, ['form' => $captcha['message']], $captcha['code']);
            return;
        }

        $result = (new HostModel())->register($old['business_name'], $old['contact_phone'], $old['email'], password_hash($password, PASSWORD_DEFAULT));
        if ($result['result'] === 'ok') {
            $this->redirect('/host/login?registered=1');
        }
        if ($result['result'] === 'email_taken') {
            $this->renderRegister($old, ['email' => self::EMAIL_TAKEN], 409);
            return;
        }

        $field = (string) $result['field'];
        $this->renderRegister($old, isset(self::FIELD_ERRORS[$field])
            ? [$field => self::FIELD_ERRORS[$field]]
            : ['form' => 'Không gửi được đăng ký, vui lòng kiểm tra lại thông tin.'], 422);
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
        $isHostPage = ($path === '/host' || str_starts_with($path, '/host/')) && !in_array($path, ['/host/login', '/host/register'], true);

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

    /**
     * Lỗi theo từng ô của form đăng ký đơn vị; [] khi hợp lệ. Tên, số điện thoại, email theo quy tắc của trang
     * "Đơn vị tổ chức" (AdminProviderController); mật khẩu theo quy tắc đăng ký khách hàng (AuthController).
     *
     * @param array{business_name: string, contact_phone: string, email: string} $old
     * @return array<string, string>
     */
    private static function validateRegistration(array $old, string $password, string $passwordConfirm): array
    {
        $errors = [];

        if ($old['business_name'] === '') {
            $errors['business_name'] = 'Vui lòng nhập tên đơn vị.';
        } elseif (mb_strlen($old['business_name']) > AdminProviderModel::NAME_MAX_LENGTH) {
            $errors['business_name'] = 'Tên đơn vị tối đa ' . AdminProviderModel::NAME_MAX_LENGTH . ' ký tự.';
        }

        if ($old['contact_phone'] === '') {
            $errors['contact_phone'] = 'Vui lòng nhập số điện thoại.';
        } elseif (!preg_match('/^(?=.{8,20}$)\+?[0-9 ]+$/', $old['contact_phone'])) {
            $errors['contact_phone'] = 'Số điện thoại gồm 8–20 ký tự: chữ số, khoảng trắng, có thể bắt đầu bằng +.';
        }

        if ($old['email'] === '') {
            $errors['email'] = 'Vui lòng nhập email liên hệ.';
        } elseif (mb_strlen($old['email']) > AdminProviderModel::EMAIL_MAX_LENGTH || filter_var($old['email'], FILTER_VALIDATE_EMAIL) === false) {
            $errors['email'] = 'Email không hợp lệ.';
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

    private function renderLogin(string $next, string $email, string $error, int $status = 200, string $notice = ''): void
    {
        $this->render('host/login', [
            'title' => 'Đăng nhập đơn vị tổ chức',
            'next' => $next,
            'email' => $email,
            'error' => $error,
            'notice' => $notice,
            'recaptchaSiteKey' => Recaptcha::siteKey(),
            'pageStyles' => ['css/auth.css'],
        ], $status);
    }

    /**
     * @param array{business_name: string, contact_phone: string, email: string} $old
     * @param array<string, string> $errors
     */
    private function renderRegister(array $old, array $errors, int $status = 200): void
    {
        $this->render('host/register', [
            'title' => 'Đăng ký đơn vị tổ chức',
            'old' => $old,
            'errors' => $errors,
            'recaptchaSiteKey' => Recaptcha::siteKey(),
            'pageStyles' => ['css/auth.css'],
        ], $status);
    }
}
