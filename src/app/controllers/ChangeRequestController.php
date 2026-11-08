<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\ChangeRequestModel;
use App\Models\CustomerBookingModel;
use App\Models\PaymentResultModel;
use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * Đổi ngày / hủy tour (US14-S5-02, FR-12 – Lê Trung Phong): khách xem chính sách hủy đã áp dụng lúc đặt, số tiền
 * dự kiến được hoàn và gửi yêu cầu đổi ngày hoặc hủy tour kèm lý do.
 * Yêu cầu chờ quản trị viên xử lý thủ công (AdminChangeRequestController); hệ thống chưa tự động hoàn tiền.
 * Chỉ tài khoản khách hàng, chỉ đơn của chính mình; đơn của tài khoản khác hiện "Không tìm thấy đơn".
 * Mỗi đơn chỉ có một yêu cầu chờ xử lý; tour đã khởi hành hoặc đơn đã đóng thì không gửi được.
 */
final class ChangeRequestController extends Controller
{
    private const EMPTY_FORM = ['type' => '', 'schedule_id' => '', 'reason' => ''];

    private const MESSAGES = [
        'sent' => 'Đã gửi yêu cầu. LocalTour sẽ xử lý và cập nhật kết quả trên trang này. Tiền hoàn (nếu có) được LocalTour chuyển lại thủ công.',
    ];

    private const BLOCKED = [
        'status' => 'Đơn đã đóng (bị từ chối, đã hủy hoặc đã hoàn thành) nên không đổi ngày hay hủy được nữa.',
        'departed' => 'Tour đã khởi hành nên không đổi ngày hay hủy được nữa.',
        'pending_request' => 'Đơn đang có một yêu cầu chờ LocalTour xử lý. Vui lòng chờ kết quả trước khi gửi yêu cầu mới.',
    ];

    private ChangeRequestModel $requests;

    /** @var array{user_id: string, name: string, email: string, role: string} */
    private array $user;

    public function __construct()
    {
        header('Cache-Control: no-store');
        $this->requests = new ChangeRequestModel();

        $user = Auth::user();
        if ($user === null) {
            $uri = $_SERVER['REQUEST_URI'] ?? '/bookings';
            $this->redirect('/login?next=' . rawurlencode(Router::pathFromUri($uri)));
        }
        if ($user['role'] !== 'customer') {
            $this->redirect('/bookings');
        }
        $this->user = $user;

        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /bookings/{code}/change */
    public function create(string $code): void
    {
        $quote = $this->findQuote($code);
        if ($quote === null) {
            $this->renderNotFound();
            return;
        }

        $this->renderForm($quote, self::EMPTY_FORM, [], self::MESSAGES[$this->query('msg')] ?? '');
    }

    /** POST /bookings/{code}/change – type (cancel | change_date), schedule_id (khi đổi ngày), reason, _csrf */
    public function store(string $code): void
    {
        $quote = $this->findQuote($code);
        if ($quote === null) {
            $this->renderNotFound();
            return;
        }

        $old = [
            'type' => $this->input('type'),
            'schedule_id' => $this->input('schedule_id'),
            'reason' => $this->input('reason'),
        ];
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->renderForm($quote, $old, ['form' => 'Phiên làm việc đã hết hạn, vui lòng thử lại.'], '', 403);
            return;
        }
        if ((int) $quote['can_request'] !== 1) {
            $this->renderForm($quote, $old, ['form' => self::BLOCKED[(string) $quote['block_reason']] ?? self::BLOCKED['status']], '', 409);
            return;
        }

        $errors = self::validate($old);
        if ($errors !== []) {
            $this->renderForm($quote, $old, $errors, '', 422);
            return;
        }

        $bookingCode = (string) $quote['booking_code'];
        $scheduleId = $old['type'] === 'change_date' ? self::parseUuid($old['schedule_id']) : null;
        $row = $this->requests->create($this->user['user_id'], $bookingCode, $old['type'], $scheduleId, $old['reason']);

        match ((string) $row['result']) {
            'ok' => $this->redirect('/bookings/' . $bookingCode . '/change?msg=sent'),
            'forbidden' => $this->redirect('/bookings'),
            'not_found' => $this->renderNotFound(),
            'invalid' => $this->renderForm($quote, $old, self::fieldError($row['field'] ?? null), '', 422),
            // Lịch hoặc đơn vừa thay đổi: tải lại thông tin mới nhất rồi báo lỗi.
            'schedule_unavailable' => $this->renderFresh($bookingCode, $old, ['schedule_id' => 'Lịch này không còn nhận khách, vui lòng chọn ngày khác.']),
            'no_seats' => $this->renderFresh($bookingCode, $old, ['schedule_id' => 'Lịch này không còn đủ chỗ cho ' . (int) $quote['people'] . ' khách, vui lòng chọn ngày khác.']),
            'departed' => $this->renderFresh($bookingCode, $old, ['form' => self::BLOCKED['departed']]),
            'pending_exists' => $this->renderFresh($bookingCode, $old, ['form' => self::BLOCKED['pending_request']]),
            default => $this->renderFresh($bookingCode, $old, ['form' => self::BLOCKED['status']]),
        };
    }

    /**
     * @param array<string, string> $old
     * @return array<string, string>
     */
    private static function validate(array $old): array
    {
        $errors = [];
        if (!in_array($old['type'], ChangeRequestModel::TYPES, true)) {
            $errors['type'] = 'Vui lòng chọn hủy tour hoặc đổi ngày.';
        } elseif ($old['type'] === 'change_date' && self::parseUuid($old['schedule_id']) === null) {
            $errors['schedule_id'] = 'Vui lòng chọn ngày muốn đổi sang.';
        }

        if ($old['reason'] === '') {
            $errors['reason'] = 'Vui lòng nhập lý do.';
        } elseif (mb_strlen($old['reason']) > ChangeRequestModel::REASON_MAX_LENGTH) {
            $errors['reason'] = 'Lý do tối đa ' . ChangeRequestModel::REASON_MAX_LENGTH . ' ký tự.';
        }

        return $errors;
    }

    /** @return array<string, string> */
    private static function fieldError(mixed $field): array
    {
        $field = (string) $field;

        return isset(self::EMPTY_FORM[$field])
            ? [$field => 'Giá trị không hợp lệ, vui lòng kiểm tra lại.']
            : ['form' => 'Chưa gửi được yêu cầu, vui lòng kiểm tra lại thông tin.'];
    }

    /** @return array<string, mixed>|null */
    private function findQuote(string $code): ?array
    {
        $code = strtoupper(trim($code));

        return preg_match(CustomerBookingModel::CODE_PATTERN, $code) ? $this->requests->quote($this->user['user_id'], $code) : null;
    }

    /**
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderFresh(string $code, array $old, array $errors): void
    {
        $quote = $this->findQuote($code);
        if ($quote === null) {
            $this->renderNotFound();
            return;
        }
        $this->renderForm($quote, $old, $errors, '', 409);
    }

    /**
     * @param array<string, mixed> $quote
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderForm(array $quote, array $old, array $errors, string $success, int $status = 200): void
    {
        $code = (string) $quote['booking_code'];
        $userId = $this->user['user_id'];
        $this->render('bookings/change', [
            'title' => 'Đổi ngày / hủy tour · ' . $code,
            'activeNav' => 'bookings',
            'quote' => $quote,
            'options' => (int) $quote['can_request'] === 1 ? $this->requests->scheduleOptions($userId, $code) : [],
            'requests' => $this->requests->history($userId, $code),
            'blockedMessage' => self::BLOCKED[(string) ($quote['block_reason'] ?? '')] ?? '',
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
            'pageScripts' => ['js/change-request.js'],
        ], $status);
    }

    private function renderNotFound(): void
    {
        $this->render('bookings/message', [
            'title' => 'Không tìm thấy đơn',
            'activeNav' => 'bookings',
            'errorCode' => 'Lỗi 404',
            'heading' => 'Không tìm thấy đơn',
            'text' => 'Mã đơn không đúng hoặc đơn không thuộc tài khoản của bạn.',
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ], 404);
    }
}
