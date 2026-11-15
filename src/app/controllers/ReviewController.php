<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\CustomerBookingModel;
use App\Models\ReviewModel;
use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * Đánh giá sao của khách hàng (FR-16, CR3 – Nguyễn Tuấn Khôi): gửi hoặc sửa đánh giá cho đơn đã hoàn thành.
 * Form nằm trên trang chi tiết đơn (bookings/show.php, thẻ "Đánh giá tour"); gửi xong quay lại trang đơn kèm thông báo.
 * Thông báo và nội dung khách đã nhập (khi có lỗi) được giữ một lần trong session (pullFlash()), không đưa lên URL.
 * Đánh giá mới hoặc vừa sửa chờ quản trị viên duyệt (AdminReviewController); đánh giá đã duyệt không sửa được.
 */
final class ReviewController extends Controller
{
    private const FLASH_KEY = 'lt_review_flash';

    private const RESULT_MESSAGES = [
        'created' => ['success', 'Đã gửi đánh giá. Đánh giá sẽ hiện trên trang tour sau khi LocalTour duyệt.'],
        'updated' => ['success', 'Đã cập nhật đánh giá. Đánh giá đang chờ LocalTour duyệt lại.'],
        'not_completed' => ['error', 'Chỉ đánh giá được đơn đã hoàn thành.'],
        'locked' => ['error', 'Đánh giá này đã được đăng nên không sửa được nữa.'],
        'forbidden' => ['error', 'Tài khoản của bạn hiện không gửi được đánh giá.'],
    ];

    /** @var array{user_id: string, name: string, email: string, role: string} */
    private array $user;

    public function __construct()
    {
        header('Cache-Control: no-store');

        $user = Auth::user();
        if ($user === null) {
            $uri = $_SERVER['REQUEST_URI'] ?? '/bookings';
            $this->redirect('/login?next=' . rawurlencode(preg_replace('#/review$#', '', Router::pathFromUri($uri)) ?? '/bookings'));
        }
        $this->user = $user;
    }

    /** POST /bookings/{code}/review – rating (1–5), content (10–1000 ký tự), _csrf */
    public function save(string $code): void
    {
        if ($this->user['role'] !== 'customer') {
            $this->render('bookings/message', [
                'title' => 'Không gửi được đánh giá',
                'errorCode' => 'Lỗi 403',
                'heading' => 'Tài khoản này không gửi được đánh giá',
                'text' => 'Chỉ tài khoản khách hàng đã đi tour mới đánh giá được.',
                'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
            ], 403);
            return;
        }

        $code = strtoupper(trim($code));
        if (!preg_match(CustomerBookingModel::CODE_PATTERN, $code)) {
            $this->redirect('/bookings');
        }
        $back = '/bookings/' . $code . '#danh-gia-tour';

        $ratingText = $this->input('rating');
        $content = ReviewModel::cleanText($this->input('content', false));
        // Giữ lại nội dung đã nhập để khách sửa tiếp (cắt bớt nếu dài bất thường, form chỉ cho 1000 ký tự).
        $old = ['rating' => $ratingText, 'content' => mb_substr($content, 0, ReviewModel::CONTENT_MAX_LENGTH * 2)];

        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            self::putFlash($code, 'error', 'Phiên làm việc đã hết hạn, vui lòng gửi lại.', [], $old);
            $this->redirect($back);
        }

        $errors = self::validate($ratingText, $content);
        if ($errors !== []) {
            self::putFlash($code, 'error', 'Vui lòng kiểm tra lại đánh giá.', $errors, $old);
            $this->redirect($back);
        }

        $row = (new ReviewModel())->save($this->user['user_id'], $code, (int) $ratingText, $content);
        $result = (string) ($row['result'] ?? 'not_found');

        if ($result === 'not_found') {
            // Mã đơn không thuộc tài khoản này: trang đơn tự hiện "Không tìm thấy đơn".
            $this->redirect('/bookings/' . $code);
        }
        if ($result === 'invalid') {
            $field = $row['field'] === 'rating' ? 'rating' : 'content';
            self::putFlash($code, 'error', 'Vui lòng kiểm tra lại đánh giá.', [$field => self::fieldMessage($field)], $old);
            $this->redirect($back);
        }

        [$type, $message] = self::RESULT_MESSAGES[$result] ?? ['error', 'Chưa gửi được đánh giá, vui lòng thử lại.'];
        self::putFlash($code, $type, $message, [], $type === 'error' ? $old : []);
        $this->redirect($back);
    }

    /**
     * Thông báo một lần của form đánh giá cho đơn $code (null nếu không có): type ('success' | 'error'), message,
     * errors (theo ô: rating, content), old (rating, content khách đã nhập).
     *
     * @return array{type: string, message: string, errors: array<string, string>, old: array<string, string>}|null
     */
    public static function pullFlash(string $code): ?array
    {
        Auth::start();
        $flash = $_SESSION[self::FLASH_KEY] ?? null;
        unset($_SESSION[self::FLASH_KEY]);

        if (!is_array($flash) || ($flash['code'] ?? '') !== $code) {
            return null;
        }

        return [
            'type' => (string) $flash['type'],
            'message' => (string) $flash['message'],
            'errors' => is_array($flash['errors']) ? $flash['errors'] : [],
            'old' => is_array($flash['old']) ? $flash['old'] : [],
        ];
    }

    /**
     * @param array<string, string> $errors
     * @param array<string, string> $old
     */
    private static function putFlash(string $code, string $type, string $message, array $errors, array $old): void
    {
        Auth::start();
        $_SESSION[self::FLASH_KEY] = [
            'code' => $code,
            'type' => $type,
            'message' => $message,
            'errors' => $errors,
            'old' => $old,
        ];
    }

    /** @return array<string, string> */
    private static function validate(string $ratingText, string $content): array
    {
        $errors = [];
        if (!preg_match('/^[1-5]$/D', $ratingText)) {
            $errors['rating'] = self::fieldMessage('rating');
        }
        $length = mb_strlen($content);
        if ($length < ReviewModel::CONTENT_MIN_LENGTH || $length > ReviewModel::CONTENT_MAX_LENGTH) {
            $errors['content'] = self::fieldMessage('content');
        }

        return $errors;
    }

    private static function fieldMessage(string $field): string
    {
        return $field === 'rating'
            ? 'Vui lòng chọn từ 1 đến 5 sao.'
            : 'Nhận xét cần từ ' . ReviewModel::CONTENT_MIN_LENGTH . ' đến ' . ReviewModel::CONTENT_MAX_LENGTH . ' ký tự.';
    }
}
