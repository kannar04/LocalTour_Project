<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AccountModel;
use App\Models\UserModel;
use Core\Auth;
use Core\Controller;
use DateTimeImmutable;
use finfo;
use GdImage;

/**
 * Trang "Tài khoản" của khách hàng (CR3 – Lê Trung Phong): ảnh đại diện, thông tin cá nhân (họ tên, số điện thoại,
 * số CCCD, ngày sinh, giới tính, địa chỉ) và mật khẩu.
 * Chỉ tài khoản khách hàng; chế độ khách được chuyển tới đăng nhập (quay lại /tai-khoan), tài khoản quản trị viên /
 * đơn vị tổ chức thấy trang 403 như "Đơn của tôi". Email không đổi được (dùng để đăng nhập).
 * Form gửi lên rồi chuyển hướng về /tai-khoan?msg=... khi lưu xong; lỗi thì hiện lại trang kèm lỗi từng ô.
 *
 * Thông tin cá nhân (đều không bắt buộc trừ họ tên): số CCCD đúng 12 chữ số; ngày sinh là ngày có thật từ năm 1900,
 * không ở tương lai và đủ MIN_AGE (10) tuổi; giới tính Nam / Nữ / Khác (trống = không nêu); địa chỉ tối đa 255 ký tự.
 * Số CCCD là thông tin nhạy cảm: chỉ hiện cho chủ tài khoản ở trang này, không có trong thông báo lỗi hay nhật ký.
 *
 * Ảnh đại diện: JPG / PNG / WebP tối đa 2 MB, cạnh 64–4096 px (kiểm tra bằng finfo + getimagesize, không tin đuôi
 * file hay loại do trình duyệt gửi). Lưu ở public/assets/uploads/avatars/<32 ký tự hex>.<đuôi> (thư mục tự tạo khi
 * chưa có). Máy có thư viện GD: cắt vuông ở giữa, thu về tối đa 256 × 256 px và lưu lại (bỏ thông tin EXIF, xoay đúng
 * chiều ảnh chụp điện thoại); không có GD thì giữ nguyên file đã kiểm tra. Đổi hoặc xóa ảnh thì xóa file cũ.
 */
final class AccountController extends Controller
{
    public const AVATAR_MAX_BYTES = 2 * 1024 * 1024;
    public const AVATAR_MIN_SIDE = 64;
    public const AVATAR_MAX_SIDE = 4096;
    /** Cạnh ảnh sau khi cắt vuông (khi có GD). */
    private const AVATAR_OUTPUT_SIDE = 256;
    private const NAME_MIN_LENGTH = 2;
    /** Tuổi tối thiểu theo ngày sinh. */
    public const MIN_AGE = 10;
    public const BIRTH_YEAR_MIN = 1900;
    public const ADDRESS_MAX_LENGTH = 255;
    /** Giá trị users.gender → nhãn; '' (không chọn) = không nêu. */
    public const GENDERS = ['male' => 'Nam', 'female' => 'Nữ', 'other' => 'Khác'];
    /** Các ô của form thông tin cá nhân. */
    private const PROFILE_FIELDS = ['name', 'phone', 'citizen_id', 'date_of_birth', 'gender', 'address'];
    private const AVATAR_DIR = 'uploads/avatars';
    /** MIME (finfo) → đuôi file và loại ảnh của getimagesize(). */
    private const AVATAR_TYPES = [
        'image/jpeg' => ['jpg', IMAGETYPE_JPEG],
        'image/png' => ['png', IMAGETYPE_PNG],
        'image/webp' => ['webp', IMAGETYPE_WEBP],
    ];

    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';
    private const SAVE_FAILED = 'Chưa lưu được, vui lòng thử lại.';

    /** Thông báo sau khi lưu (?msg=). */
    private const MESSAGES = [
        'profile' => 'Đã lưu thông tin cá nhân.',
        'avatar' => 'Đã cập nhật ảnh đại diện.',
        'avatar_removed' => 'Đã xóa ảnh đại diện.',
        'password' => 'Đã đổi mật khẩu.',
        'password_set' => 'Đã đặt mật khẩu. Từ nay bạn đăng nhập bằng email và mật khẩu này.',
    ];

    private AccountModel $accounts;

    /** @var array{user_id: string, name: string, email: string, role: string, avatar_url?: string|null} */
    private array $user;

    public function __construct()
    {
        // Trang có thông tin cá nhân: trình duyệt không được lưu cache.
        header('Cache-Control: no-store');
        $this->accounts = new AccountModel();

        $user = Auth::user();
        if ($user === null) {
            // Gửi form khi phiên đã hết cũng quay về trang tài khoản sau khi đăng nhập.
            $this->redirect('/login?next=' . rawurlencode('/tai-khoan'));
        }
        $this->user = $user;
    }

    /** GET /tai-khoan?msg= */
    public function show(): void
    {
        $account = $this->accountOrLeave();
        $this->renderPage($account, [], self::MESSAGES[$this->query('msg')] ?? '');
    }

    /** POST /tai-khoan/profile – name, phone, citizen_id, date_of_birth, gender, address, _csrf */
    public function updateProfile(): void
    {
        $account = $this->accountOrLeave();
        $old = [];
        foreach (self::PROFILE_FIELDS as $field) {
            $old[$field] = $this->input($field);
        }
        // Trình duyệt không có ô chọn ngày gửi dd/mm/yyyy: đổi về yyyy-mm-dd (giá trị của <input type="date">).
        $old['date_of_birth'] = self::parseDate($old['date_of_birth'])?->format('Y-m-d') ?? $old['date_of_birth'];

        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderPage($account, ['form' => self::CSRF_FAILED], '', 403, $old);
            return;
        }

        $errors = self::validateProfile($old);
        if ($errors !== []) {
            $this->renderPage($account, ['profile' => $errors], '', 422, $old);
            return;
        }

        if (!$this->accounts->updateProfile($account['user_id'], $old)) {
            $this->renderPage($account, ['profile' => ['form' => self::SAVE_FAILED]], '', 500, $old);
            return;
        }

        Auth::refresh(['name' => $old['name']]);
        $this->redirect('/tai-khoan?msg=profile#thong-tin');
    }

    /** POST /tai-khoan/avatar – avatar (multipart), _csrf */
    public function uploadAvatar(): void
    {
        $account = $this->accountOrLeave();

        // Vượt post_max_size: PHP bỏ cả $_POST lẫn $_FILES (kể cả mã CSRF), báo là ảnh quá lớn thay vì "hết phiên".
        if ($_POST === [] && $_FILES === [] && (int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > 0) {
            $this->renderPage($account, ['avatar' => self::tooBigMessage()], '', 413);
            return;
        }
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderPage($account, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $file = $_FILES['avatar'] ?? null;
        if (!is_array($file) || is_array($file['error'] ?? null) || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
            $this->renderPage($account, ['avatar' => 'Vui lòng chọn ảnh.'], '', 422);
            return;
        }

        [$stored, $error] = self::storeAvatar($file);
        if ($stored === null) {
            $this->renderPage($account, ['avatar' => (string) $error], '', 422);
            return;
        }

        $result = $this->accounts->setAvatar($account['user_id'], $stored);
        if (!$result['ok']) {
            self::removeAvatarFile($stored);
            $this->renderPage($account, ['avatar' => self::SAVE_FAILED], '', 500);
            return;
        }

        if ($result['old_avatar_url'] !== null && $result['old_avatar_url'] !== $stored) {
            self::removeAvatarFile($result['old_avatar_url']);
        }
        Auth::refresh(['avatar_url' => $stored]);
        $this->redirect('/tai-khoan?msg=avatar#anh-dai-dien');
    }

    /** POST /tai-khoan/avatar/delete – _csrf */
    public function deleteAvatar(): void
    {
        $account = $this->accountOrLeave();
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderPage($account, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $result = $this->accounts->setAvatar($account['user_id'], null);
        if (!$result['ok']) {
            $this->renderPage($account, ['avatar' => self::SAVE_FAILED], '', 500);
            return;
        }

        if ($result['old_avatar_url'] !== null) {
            self::removeAvatarFile($result['old_avatar_url']);
        }
        Auth::refresh(['avatar_url' => null]);
        $this->redirect('/tai-khoan?msg=avatar_removed#anh-dai-dien');
    }

    /** POST /tai-khoan/password – current_password (khi đã có mật khẩu), password, password_confirm, _csrf */
    public function changePassword(): void
    {
        $account = $this->accountOrLeave();
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderPage($account, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $current = $this->input('current_password', false);
        $password = $this->input('password', false);
        $confirm = $this->input('password_confirm', false);
        $hash = $this->accounts->passwordHash($account['user_id']);

        $errors = [];
        if ($hash !== null) {
            if ($current === '') {
                $errors['current_password'] = 'Vui lòng nhập mật khẩu hiện tại.';
            } elseif (!password_verify($current, $hash)) {
                $errors['current_password'] = 'Mật khẩu hiện tại không đúng.';
            }
        }
        if (mb_strlen($password) < UserModel::PASSWORD_MIN_LENGTH) {
            $errors['password'] = 'Mật khẩu mới tối thiểu ' . UserModel::PASSWORD_MIN_LENGTH . ' ký tự.';
        } elseif (strlen($password) > UserModel::PASSWORD_MAX_LENGTH) {
            $errors['password'] = 'Mật khẩu quá dài (tối đa ' . UserModel::PASSWORD_MAX_LENGTH . ' byte, mỗi chữ có dấu tính 2–3 byte).';
        } elseif ($hash !== null && !isset($errors['current_password']) && password_verify($password, $hash)) {
            $errors['password'] = 'Mật khẩu mới phải khác mật khẩu hiện tại.';
        } elseif ($password !== $confirm) {
            $errors['password_confirm'] = 'Mật khẩu nhập lại không khớp.';
        }
        if ($errors !== []) {
            $this->renderPage($account, ['password' => $errors], '', 422);
            return;
        }

        if (!$this->accounts->setPassword($account['user_id'], password_hash($password, PASSWORD_DEFAULT))) {
            $this->renderPage($account, ['password' => ['form' => self::SAVE_FAILED]], '', 500);
            return;
        }

        // Giữ đăng nhập nhưng đổi session id của phiên này. Phiên đăng nhập ở trình duyệt khác không tự thoát.
        Auth::regenerate();
        $this->redirect('/tai-khoan?msg=' . ($hash === null ? 'password_set' : 'password') . '#mat-khau');
    }

    /**
     * Tài khoản khách hàng đang đăng nhập. Không phải khách hàng: trang 403. Tài khoản đã bị khóa (hoặc không còn)
     * sau khi đăng nhập: đăng xuất rồi về trang đăng nhập.
     *
     * @return array{user_id: string, email: string, name: string, phone: ?string, role: string,
     *               avatar_url: ?string, has_password: bool}
     */
    private function accountOrLeave(): array
    {
        if ($this->user['role'] !== 'customer') {
            $this->renderNotCustomer();
            exit;
        }

        $account = $this->accounts->find($this->user['user_id']);
        if ($account === null) {
            Auth::logout();
            $this->redirect('/login?next=' . rawurlencode('/tai-khoan'));
        }

        return $account;
    }

    /**
     * @param array<string, mixed> $account
     * @param array<string, mixed> $errors 'form' (lỗi chung), 'profile' / 'password' (lỗi theo ô), 'avatar' (chuỗi)
     * @param array<string, string>|null $old Giá trị vừa nhập ở form thông tin cá nhân (khóa = PROFILE_FIELDS)
     */
    private function renderPage(array $account, array $errors, string $success, int $status = 200, ?array $old = null): void
    {
        if ($old === null) {
            $old = [];
            foreach (self::PROFILE_FIELDS as $field) {
                $old[$field] = (string) ($account[$field] ?? '');
            }
        }
        $today = new DateTimeImmutable('today');

        $this->render('account/settings', [
            'title' => 'Tài khoản',
            'activeNav' => 'account',
            'account' => $account,
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'genders' => self::GENDERS,
            'birthMin' => self::BIRTH_YEAR_MIN . '-01-01',
            'birthMax' => $today->modify('-' . self::MIN_AGE . ' years')->format('Y-m-d'),
            'minAge' => self::MIN_AGE,
            'addressMaxLength' => self::ADDRESS_MAX_LENGTH,
            'avatarMaxBytes' => self::AVATAR_MAX_BYTES,
            'avatarMinSide' => self::AVATAR_MIN_SIDE,
            'avatarMaxSide' => self::AVATAR_MAX_SIDE,
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css', 'css/account.css'],
            'pageScripts' => ['js/account.js'],
        ], $status);
    }

    /** Tài khoản quản trị viên hoặc đơn vị tổ chức mở trang "Tài khoản" (giống "Đơn của tôi"). */
    private function renderNotCustomer(): void
    {
        $where = $this->user['role'] === 'provider'
            ? 'Đơn vị tổ chức quản lý thông tin của mình ở khu đơn vị tổ chức.'
            : 'Tài khoản quản trị được quản lý ở trang quản trị.';
        $this->render('bookings/message', [
            'title' => 'Không có trang tài khoản',
            'errorCode' => 'Lỗi 403',
            'heading' => 'Trang này dành cho tài khoản khách hàng',
            'text' => '"Tài khoản" chỉ dành cho tài khoản khách hàng. ' . $where,
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ], 403);
    }

    /**
     * Lỗi theo ô của form thông tin cá nhân; [] khi hợp lệ.
     *
     * Thông báo lỗi không bao giờ chứa giá trị đã nhập (số CCCD là thông tin nhạy cảm).
     *
     * @param array<string, string> $old Khóa = PROFILE_FIELDS; date_of_birth đã đổi về Y-m-d nếu đọc được
     * @return array<string, string>
     */
    private static function validateProfile(array $old): array
    {
        $errors = [];

        $nameLength = mb_strlen($old['name']);
        if ($nameLength === 0) {
            $errors['name'] = 'Vui lòng nhập họ tên.';
        } elseif ($nameLength < self::NAME_MIN_LENGTH || $nameLength > UserModel::NAME_MAX_LENGTH) {
            $errors['name'] = 'Họ tên từ ' . self::NAME_MIN_LENGTH . ' đến ' . UserModel::NAME_MAX_LENGTH . ' ký tự.';
        } elseif (preg_match('/[\x00-\x1F\x7F]/u', $old['name'])) {
            $errors['name'] = 'Họ tên có ký tự không hợp lệ.';
        }

        // Giống form đăng ký: không bắt buộc, 8–20 ký tự gồm chữ số và khoảng trắng, có thể bắt đầu bằng +.
        if ($old['phone'] !== '' && !preg_match('/^(?=.{8,20}$)\+?[0-9 ]+$/', $old['phone'])) {
            $errors['phone'] = 'Số điện thoại không hợp lệ.';
        }

        if ($old['citizen_id'] !== '' && !preg_match('/^[0-9]{12}$/D', $old['citizen_id'])) {
            $errors['citizen_id'] = 'Số CCCD gồm đúng 12 chữ số.';
        }

        if ($old['date_of_birth'] !== '') {
            $birth = self::parseDate($old['date_of_birth']);
            $today = new DateTimeImmutable('today');
            if ($birth === null) {
                $errors['date_of_birth'] = 'Ngày sinh không hợp lệ.';
            } elseif ((int) $birth->format('Y') < self::BIRTH_YEAR_MIN) {
                $errors['date_of_birth'] = 'Ngày sinh phải từ năm ' . self::BIRTH_YEAR_MIN . ' trở đi.';
            } elseif ($birth > $today) {
                $errors['date_of_birth'] = 'Ngày sinh không được ở tương lai.';
            } elseif ($birth > $today->modify('-' . self::MIN_AGE . ' years')) {
                $errors['date_of_birth'] = 'Bạn cần đủ ' . self::MIN_AGE . ' tuổi.';
            }
        }

        if ($old['gender'] !== '' && !array_key_exists($old['gender'], self::GENDERS)) {
            $errors['gender'] = 'Vui lòng chọn giới tính trong danh sách.';
        }

        if (mb_strlen($old['address']) > self::ADDRESS_MAX_LENGTH) {
            $errors['address'] = 'Địa chỉ tối đa ' . self::ADDRESS_MAX_LENGTH . ' ký tự.';
        } elseif (preg_match('/[\x00-\x1F\x7F]/u', $old['address'])) {
            $errors['address'] = 'Địa chỉ có ký tự không hợp lệ.';
        }

        return $errors;
    }

    /** Ngày có thật dạng yyyy-mm-dd (ô chọn ngày) hoặc dd/mm/yyyy; null khi sai dạng / không có ngày đó (vd. 31/02). */
    private static function parseDate(string $value): ?DateTimeImmutable
    {
        foreach (['Y-m-d', 'd/m/Y'] as $format) {
            $date = DateTimeImmutable::createFromFormat('!' . $format, $value);
            if ($date !== false && $date->format($format) === $value) {
                return $date;
            }
        }

        return null;
    }

    private static function tooBigMessage(): string
    {
        return 'Ảnh tối đa ' . (self::AVATAR_MAX_BYTES / 1024 / 1024) . ' MB.';
    }

    /**
     * Kiểm tra và lưu ảnh tải lên. Trả về [đường dẫn trong public/assets, null] hoặc [null, thông báo lỗi].
     *
     * @param array<string, mixed> $file Một phần tử của $_FILES
     * @return array{0: ?string, 1: ?string}
     */
    private static function storeAvatar(array $file): array
    {
        $error = (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE) {
            return [null, self::tooBigMessage()];
        }
        $tmp = (string) ($file['tmp_name'] ?? '');
        if ($error !== UPLOAD_ERR_OK || $tmp === '' || !is_uploaded_file($tmp)) {
            return [null, 'Không tải được ảnh lên, vui lòng thử lại.'];
        }
        if ((int) ($file['size'] ?? 0) > self::AVATAR_MAX_BYTES || filesize($tmp) > self::AVATAR_MAX_BYTES) {
            return [null, self::tooBigMessage()];
        }

        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($tmp);
        $type = self::AVATAR_TYPES[$mime] ?? null;
        $size = $type === null ? false : @getimagesize($tmp);
        if ($type === null || $size === false || (int) $size[2] !== $type[1]) {
            return [null, 'Chỉ nhận ảnh JPG, PNG hoặc WebP.'];
        }
        [$width, $height] = [(int) $size[0], (int) $size[1]];
        if (min($width, $height) < self::AVATAR_MIN_SIDE || max($width, $height) > self::AVATAR_MAX_SIDE) {
            return [null, 'Ảnh cần có cạnh từ ' . self::AVATAR_MIN_SIDE . ' đến ' . self::AVATAR_MAX_SIDE . ' px.'];
        }

        $dir = BASE_PATH . '/public/assets/' . self::AVATAR_DIR;
        if (!is_dir($dir) && !mkdir($dir, 0755, true) && !is_dir($dir)) {
            return [null, 'Chưa lưu được ảnh trên máy chủ, vui lòng thử lại.'];
        }
        $name = bin2hex(random_bytes(16)) . '.' . $type[0];
        $target = $dir . '/' . $name;

        if (self::canResize($type[1], $width, $height)) {
            if (!self::resizeSquare($tmp, $type[1], $width, $height, $target)) {
                @unlink($target);

                return [null, 'Không đọc được ảnh này, vui lòng chọn ảnh khác.'];
            }
        } elseif (!move_uploaded_file($tmp, $target)) {
            return [null, 'Chưa lưu được ảnh trên máy chủ, vui lòng thử lại.'];
        }

        return [self::AVATAR_DIR . '/' . $name, null];
    }

    /**
     * Có GD (đọc / ghi được đúng loại ảnh này) và đủ bộ nhớ để mở ảnh không. Ảnh lớn cần khoảng 5 byte mỗi điểm ảnh:
     * nâng memory_limit tạm thời cho lần xử lý này; không nâng được thì giữ nguyên file gốc (đã kiểm tra loại và
     * kích thước; thư mục uploads có .htaccess chặn chạy mã).
     */
    private static function canResize(int $type, int $width, int $height): bool
    {
        [$read, $write] = match ($type) {
            IMAGETYPE_JPEG => ['imagecreatefromjpeg', 'imagejpeg'],
            IMAGETYPE_PNG => ['imagecreatefrompng', 'imagepng'],
            IMAGETYPE_WEBP => ['imagecreatefromwebp', 'imagewebp'],
            default => ['', ''],
        };
        if (!extension_loaded('gd') || $read === '' || !function_exists($read) || !function_exists($write)
            || !function_exists('imagecreatetruecolor') || !function_exists('imagecopyresampled')) {
            return false;
        }

        $limit = self::bytes((string) ini_get('memory_limit'));
        if ($limit < 0) {
            return true;
        }
        $needed = memory_get_usage() + $width * $height * 5 + self::AVATAR_OUTPUT_SIDE ** 2 * 5 + 8 * 1024 * 1024;

        return $needed <= $limit || ini_set('memory_limit', (string) $needed) !== false;
    }

    /** "128M" → số byte; -1 = không giới hạn. */
    private static function bytes(string $value): int
    {
        $value = trim($value);
        if ($value === '' || $value === '-1') {
            return -1;
        }
        $number = (int) $value;

        return match (strtolower(substr($value, -1))) {
            'g' => $number * 1024 ** 3,
            'm' => $number * 1024 ** 2,
            'k' => $number * 1024,
            default => $number,
        };
    }

    /** Cắt vuông ở giữa, thu về tối đa 256 × 256 px rồi ghi ra $target cùng loại ảnh. false khi GD không đọc / ghi được. */
    private static function resizeSquare(string $source, int $type, int $width, int $height, string $target): bool
    {
        $image = match ($type) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($source),
            IMAGETYPE_PNG => @imagecreatefrompng($source),
            IMAGETYPE_WEBP => @imagecreatefromwebp($source),
            default => false,
        };
        if (!$image instanceof GdImage) {
            return false;
        }

        // Ảnh chụp điện thoại: xoay theo EXIF Orientation trước khi cắt (file mới không còn EXIF).
        if ($type === IMAGETYPE_JPEG) {
            $image = self::applyOrientation($image, $source);
            [$width, $height] = [imagesx($image), imagesy($image)];
        }

        $side = min($width, $height);
        $output = min($side, self::AVATAR_OUTPUT_SIDE);
        $canvas = imagecreatetruecolor($output, $output);
        if (!$canvas instanceof GdImage) {
            imagedestroy($image);

            return false;
        }
        if ($type !== IMAGETYPE_JPEG) {
            // Giữ nền trong suốt của PNG / WebP.
            imagealphablending($canvas, false);
            imagesavealpha($canvas, true);
            imagefill($canvas, 0, 0, imagecolorallocatealpha($canvas, 0, 0, 0, 127));
        }
        $copied = imagecopyresampled($canvas, $image, 0, 0, intdiv($width - $side, 2), intdiv($height - $side, 2),
            $output, $output, $side, $side);
        imagedestroy($image);

        $saved = $copied && match ($type) {
            IMAGETYPE_JPEG => imagejpeg($canvas, $target, 85),
            IMAGETYPE_PNG => imagepng($canvas, $target, 6),
            IMAGETYPE_WEBP => imagewebp($canvas, $target, 85),
            default => false,
        };
        imagedestroy($canvas);

        return $saved && is_file($target);
    }

    private static function applyOrientation(GdImage $image, string $source): GdImage
    {
        if (!function_exists('exif_read_data')) {
            return $image;
        }
        $exif = @exif_read_data($source);
        $angle = match ((int) (is_array($exif) ? ($exif['Orientation'] ?? 1) : 1)) {
            3 => 180,
            6 => -90,
            8 => 90,
            default => 0,
        };
        if ($angle === 0) {
            return $image;
        }
        $rotated = imagerotate($image, $angle, 0);
        if (!$rotated instanceof GdImage) {
            return $image;
        }
        imagedestroy($image);

        return $rotated;
    }

    /** Xóa file ảnh đại diện cũ (chỉ file do trang này tạo: uploads/avatars/<32 ký tự hex>.<đuôi>). */
    private static function removeAvatarFile(string $url): void
    {
        if (preg_match('#^' . self::AVATAR_DIR . '/[0-9a-f]{32}\.(jpg|png|webp)$#D', $url) !== 1) {
            return;
        }
        $path = BASE_PATH . '/public/assets/' . $url;
        if (is_file($path)) {
            @unlink($path);
        }
    }
}
