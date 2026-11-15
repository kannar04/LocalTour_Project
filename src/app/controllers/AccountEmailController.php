<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AccountModel;
use App\Models\EmailVerificationModel;
use App\Models\UserModel;
use App\Services\VerificationMail;
use Core\Auth;
use Core\Controller;
use Throwable;

/**
 * Xác minh email và đổi email ở trang "Tài khoản" của khách hàng (Nguyễn Tuấn Khôi – NTK).
 * Chức năng thêm, chỉ có khi đã cấu hình gửi email (VerificationMail::enabled(): MAIL_HOST trong .env): routes/web.php
 * chỉ đăng ký 4 đường dẫn POST dưới đây khi bật, và partial views/account/partials/email_verify.php (gọi viewData())
 * chỉ hiện khi bật; tắt thì trang "Tài khoản" giữ nguyên ô email chỉ đọc.
 *
 *   POST /tai-khoan/email/code            gửi mã 6 chữ số tới email hiện tại
 *   POST /tai-khoan/email/verify          code → email hiện tại "Đã xác minh" (users.email_verified_at)
 *   POST /tai-khoan/email/change          new_email, current_password (khi tài khoản có mật khẩu) → gửi mã tới email mới
 *   POST /tai-khoan/email/change/confirm  code → đổi email đăng nhập sang email mới (đã xác minh), cập nhật session
 *
 * Chỉ tài khoản khách hàng (như cả trang). Mọi POST kiểm tra CSRF, xong chuyển hướng (303) về /tai-khoan#email kèm
 * thông báo một lần trong session; partial đọc rồi xóa thông báo.
 * Bảo mật: mã sinh bằng random_int, database chỉ lưu password_hash() của mã, so bằng password_verify() (thời gian cố
 * định). Hết hạn 15 phút, mỗi mã nhập tối đa 5 lần, gửi lại sau 60 giây, tối đa 5 mã mỗi tài khoản trong 1 giờ, mã mới
 * thay mã cũ cùng mục đích: database giữ các giới hạn này (40_email_verify_NTK.sql). Mã không bao giờ có trong phản hồi
 * hay nhật ký; lỗi database chỉ ghi thông báo lỗi.
 */
final class AccountEmailController extends Controller
{
    private const FLASH_KEY = 'account_email_flash';
    private const CODE_LENGTH = 6;
    private const MAX_ATTEMPTS = 5;
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';
    private const SAVE_FAILED = 'Chưa xử lý được, vui lòng thử lại.';
    private const SEND_FAILED = 'Chưa gửi được email, vui lòng thử lại sau.';

    private AccountModel $accounts;
    private EmailVerificationModel $codes;

    /** @var array{user_id: string, name: string, email: string, role: string, avatar_url?: string|null} */
    private array $user;

    public function __construct()
    {
        header('Cache-Control: no-store');
        $user = Auth::user();
        if ($user === null) {
            $this->redirect('/login?next=' . rawurlencode('/tai-khoan'));
        }
        // Tắt gửi email hoặc không phải khách hàng: trang "Tài khoản" tự hiện đúng nội dung (403 / ô email như cũ).
        if (!VerificationMail::enabled() || $user['role'] !== 'customer') {
            $this->redirect('/tai-khoan');
        }
        $this->user = $user;
        $this->accounts = new AccountModel();
        $this->codes = new EmailVerificationModel();
    }

    /** POST /tai-khoan/email/code – _csrf */
    public function sendCode(): void
    {
        $account = $this->accountOrLeave();
        $this->requireCsrf(EmailVerificationModel::PURPOSE_VERIFY);
        $this->issueAndSend($account, EmailVerificationModel::PURPOSE_VERIFY, null);
    }

    /** POST /tai-khoan/email/verify – code, _csrf */
    public function verify(): void
    {
        $account = $this->accountOrLeave();
        $this->requireCsrf(EmailVerificationModel::PURPOSE_VERIFY);
        $this->checkCode($account, EmailVerificationModel::PURPOSE_VERIFY);
        $this->leave(EmailVerificationModel::PURPOSE_VERIFY, ['success' => 'Đã xác minh email.']);
    }

    /** POST /tai-khoan/email/change – new_email, current_password (khi tài khoản có mật khẩu), _csrf */
    public function change(): void
    {
        $account = $this->accountOrLeave();
        $this->requireCsrf(EmailVerificationModel::PURPOSE_CHANGE);

        $email = mb_strtolower($this->input('new_email'));
        $password = $this->input('current_password', false);
        $errors = [];
        if ($email === '') {
            $errors['new_email'] = 'Vui lòng nhập email mới.';
        } elseif (mb_strlen($email) > UserModel::EMAIL_MAX_LENGTH || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            $errors['new_email'] = 'Email không hợp lệ.';
        } elseif ($email === mb_strtolower($account['email'])) {
            $errors['new_email'] = 'Email mới trùng với email hiện tại.';
        }
        if ($account['has_password']) {
            $hash = $this->accounts->passwordHash($account['user_id']);
            if ($password === '') {
                $errors['current_password'] = 'Vui lòng nhập mật khẩu hiện tại.';
            } elseif ($hash === null || !password_verify($password, $hash)) {
                $errors['current_password'] = 'Mật khẩu hiện tại không đúng.';
            }
        }
        if ($errors !== []) {
            $this->leave(EmailVerificationModel::PURPOSE_CHANGE, ['errors' => $errors, 'new_email' => $email]);
        }

        $this->issueAndSend($account, EmailVerificationModel::PURPOSE_CHANGE, $email);
    }

    /** POST /tai-khoan/email/change/confirm – code, _csrf */
    public function confirmChange(): void
    {
        $account = $this->accountOrLeave();
        $this->requireCsrf(EmailVerificationModel::PURPOSE_CHANGE);
        $confirmed = $this->checkCode($account, EmailVerificationModel::PURPOSE_CHANGE);
        $email = (string) $confirmed['email'];

        // Đăng nhập lại với email mới: header / tiêu đề hiện email mới, session id mới sau khi đổi thông tin đăng nhập.
        Auth::login([
            'user_id' => $this->user['user_id'],
            'name' => $this->user['name'],
            'email' => $email,
            'role' => $this->user['role'],
            'avatar_url' => $this->user['avatar_url'] ?? null,
        ]);
        $this->leave(EmailVerificationModel::PURPOSE_CHANGE, ['success' => 'Đã đổi email đăng nhập sang ' . $email . '.']);
    }

    /**
     * Dữ liệu cho partial account/partials/email_verify.php; null = không hiện chức năng (chưa cấu hình gửi email,
     * database chưa chạy 40_email_verify_NTK.sql, tài khoản không còn hoạt động). Đọc xong thì xóa thông báo một lần.
     *
     * @param array<string, mixed> $account Dòng của AccountModel::find()
     * @return array{state: array<string, mixed>, panel: string, success: string, errors: array<string, string>,
     *               new_email: string, has_password: bool, max_attempts: int}|null
     */
    public static function viewData(array $account): ?array
    {
        if (!VerificationMail::enabled()) {
            return null;
        }
        try {
            $state = (new EmailVerificationModel())->state((string) $account['user_id']);
        } catch (Throwable $exception) {
            error_log('LocalTour: xác minh email: không đọc được tình trạng (database đã chạy 40_email_verify_NTK.sql chưa?): ' . $exception->getMessage());
            return null;
        }
        if ($state === null) {
            return null;
        }

        Auth::start();
        $flash = $_SESSION[self::FLASH_KEY] ?? null;
        unset($_SESSION[self::FLASH_KEY]);
        if (!is_array($flash) || ($flash['user_id'] ?? null) !== $account['user_id']) {
            $flash = [];
        }

        return [
            'state' => $state,
            'panel' => (string) ($flash['panel'] ?? ''),
            'success' => (string) ($flash['success'] ?? ''),
            'errors' => is_array($flash['errors'] ?? null) ? $flash['errors'] : [],
            'new_email' => (string) ($flash['new_email'] ?? ''),
            'has_password' => (bool) $account['has_password'],
            'max_attempts' => self::MAX_ATTEMPTS,
        ];
    }

    /**
     * Ghi mã mới rồi gửi email. Luôn chuyển hướng về trang "Tài khoản".
     *
     * @param array<string, mixed> $account
     */
    private function issueAndSend(array $account, string $purpose, ?string $newEmail): never
    {
        $code = str_pad((string) random_int(0, 10 ** self::CODE_LENGTH - 1), self::CODE_LENGTH, '0', STR_PAD_LEFT);
        try {
            $issued = $this->codes->issue($account['user_id'], $purpose, $newEmail, password_hash($code, PASSWORD_DEFAULT));
        } catch (Throwable $exception) {
            error_log('LocalTour: xác minh email: không ghi được mã: ' . $exception->getMessage());
            $this->leave($purpose, ['errors' => ['form' => self::SAVE_FAILED], 'new_email' => (string) $newEmail]);
        }

        $field = $purpose === EmailVerificationModel::PURPOSE_CHANGE ? 'new_email' : 'form';
        $error = match ($issued['result']) {
            'ok' => null,
            'already' => 'Email đã được xác minh.',
            'same' => 'Email mới trùng với email hiện tại.',
            'taken' => 'Email này đã được dùng.',
            'cooldown' => 'Vui lòng chờ ' . $issued['wait_seconds'] . ' giây rồi gửi lại mã.',
            'limit' => 'Bạn đã gửi 5 mã trong 1 giờ. Vui lòng thử lại sau ' . max(1, (int) ceil($issued['wait_seconds'] / 60)) . ' phút.',
            'not_found' => $this->redirect('/tai-khoan'),
            default => self::SAVE_FAILED,
        };
        if ($error !== null) {
            $key = in_array($issued['result'], ['same', 'taken'], true) ? $field : 'form';
            $this->leave($purpose, ['errors' => [$key => $error], 'new_email' => (string) $newEmail]);
        }

        $to = (string) $issued['email'];
        if (!VerificationMail::sendCode($to, $issued['name'], $code, $purpose)) {
            try {
                $this->codes->cancel((string) $issued['verification_id'], $account['user_id']);
            } catch (Throwable $exception) {
                error_log('LocalTour: xác minh email: không hủy được mã gửi lỗi: ' . $exception->getMessage());
            }
            $this->leave($purpose, ['errors' => ['form' => self::SEND_FAILED], 'new_email' => (string) $newEmail]);
        }

        $this->leave($purpose, ['success' => $purpose === EmailVerificationModel::PURPOSE_CHANGE
            ? 'Đã gửi mã tới ' . $to . '. Nhập mã để đổi email.'
            : 'Đã gửi mã xác minh tới ' . $to . '. Mã có hiệu lực ' . VerificationMail::CODE_TTL_MINUTES . ' phút.']);
    }

    /**
     * Kiểm tra mã người dùng nhập cho mã đang chờ của $purpose. Đúng: trả dòng của NTK_sp_email_verify_confirm
     * (result 'ok'); sai / hết hạn / hết lượt: chuyển hướng kèm lỗi.
     *
     * @param array<string, mixed> $account
     * @return array{result: string, purpose: ?string, email: ?string}
     */
    private function checkCode(array $account, string $purpose): array
    {
        // Mã dán từ email có thể kèm khoảng trắng.
        $code = (string) preg_replace('/\s+/u', '', $this->input('code'));
        if (!preg_match('/^[0-9]{' . self::CODE_LENGTH . '}$/D', $code)) {
            $this->leave($purpose, ['errors' => ['code' => 'Vui lòng nhập mã ' . self::CODE_LENGTH . ' chữ số.']]);
        }

        try {
            $attempt = $this->codes->attempt($account['user_id'], $purpose);
            $error = match ($attempt['result']) {
                'ok' => null,
                'locked' => 'Mã đã bị hủy vì nhập sai ' . self::MAX_ATTEMPTS . ' lần, vui lòng gửi mã mới.',
                'expired' => 'Mã đã hết hạn, vui lòng gửi mã mới.',
                'not_found' => $this->redirect('/tai-khoan'),
                default => 'Chưa có mã đang chờ, vui lòng gửi mã mới.',
            };
            if ($error === null && !password_verify($code, (string) $attempt['code_hash'])) {
                $error = $attempt['attempts_left'] > 0
                    ? 'Mã không đúng. Còn ' . $attempt['attempts_left'] . ' lần thử.'
                    : 'Mã không đúng. Mã đã bị hủy sau ' . self::MAX_ATTEMPTS . ' lần nhập sai, vui lòng gửi mã mới.';
            }
            if ($error === null) {
                $confirmed = $this->codes->confirm((string) $attempt['verification_id'], $account['user_id']);
                $error = match ($confirmed['result']) {
                    'ok' => null,
                    'taken' => 'Email này đã được dùng.',
                    default => 'Mã đã hết hạn, vui lòng gửi mã mới.',
                };
            }
        } catch (Throwable $exception) {
            error_log('LocalTour: xác minh email: không kiểm tra được mã: ' . $exception->getMessage());
            $error = self::SAVE_FAILED;
        }

        if ($error !== null) {
            $this->leave($purpose, ['errors' => ['code' => $error]]);
        }

        return $confirmed;
    }

    /**
     * Tài khoản khách hàng đang hoạt động; không còn (đã khóa, sai id) thì về trang "Tài khoản" (trang đó đăng xuất).
     *
     * @return array<string, mixed>
     */
    private function accountOrLeave(): array
    {
        return $this->accounts->find($this->user['user_id']) ?? $this->redirect('/tai-khoan');
    }

    private function requireCsrf(string $purpose): void
    {
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->leave($purpose, ['errors' => ['form' => self::CSRF_FAILED]]);
        }
    }

    /**
     * Lưu thông báo một lần cho partial rồi chuyển hướng về ô email của trang "Tài khoản".
     *
     * @param array{success?: string, errors?: array<string, string>, new_email?: string} $flash
     */
    private function leave(string $panel, array $flash): never
    {
        Auth::start();
        $_SESSION[self::FLASH_KEY] = ['user_id' => $this->user['user_id'], 'panel' => $panel] + $flash;
        $this->redirect('/tai-khoan#email');
    }
}
