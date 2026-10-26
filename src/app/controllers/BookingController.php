<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\BookingAvailabilityModel;
use App\Models\BookingModel;
use App\Models\TourContentModel;
use App\Models\TourDetailModel;
use App\Models\UserModel;
use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * Đặt tour (M4 mục 6, 8 – Lê Trung Phong): trang "Hoàn tất thông tin đặt tour" và API lưu yêu cầu đặt tour.
 * Chỉ tài khoản khách hàng đặt được; chế độ khách được chuyển tới đăng nhập rồi quay lại đúng trang.
 * Đơn mới ở trạng thái 'pending' (Chờ xác nhận), chưa giữ chỗ và chưa thu tiền (thanh toán thuộc M5).
 */
final class BookingController extends Controller
{
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng tải lại trang và thử lại.';
    private const PHONE_PATTERN = '/^(?=.{8,20}$)\+?[0-9 ]+$/';

    private TourDetailModel $details;
    private TourContentModel $content;
    private BookingModel $bookings;
    private BookingAvailabilityModel $availability;

    public function __construct()
    {
        $this->details = new TourDetailModel();
        $this->content = new TourContentModel();
        $this->bookings = new BookingModel();
        $this->availability = new BookingAvailabilityModel();
    }

    /** GET /tours/{id}/book?schedule_id=&tickets[<mã vé>]=<số khách> (lịch và số khách chọn ở trang chi tiết) */
    public function create(string $id): void
    {
        $user = Auth::user();
        if ($user === null) {
            $this->redirect('/login?next=' . rawurlencode(self::currentPath()));
        }
        if ($user['role'] !== 'customer') {
            $this->renderNotCustomer();
            return;
        }

        $tourId = self::parseUuid($id);
        $tour = $tourId === null ? null : $this->details->find($tourId);
        if ($tour === null) {
            $this->render('tours/not-found', [
                'title' => 'Không tìm thấy tour',
                'pageStyles' => ['css/tour-detail.css'],
            ], 404);
            return;
        }

        $schedules = $this->details->schedules($tourId);
        $scheduleIds = array_map(static fn (array $schedule): string => (string) $schedule['schedule_id'], $schedules);

        // Lịch chọn ở trang chi tiết có thể vừa hết chỗ / đóng: chọn lịch đầu tiên và báo cho khách.
        $requested = self::parseUuid($this->query('schedule_id'));
        $selectedScheduleId = in_array($requested, $scheduleIds, true) ? $requested : ($scheduleIds[0] ?? null);
        $scheduleNotice = $requested !== null && $selectedScheduleId !== $requested && $schedules !== []
            ? 'Lịch bạn chọn đã hết chỗ hoặc không còn nhận khách. Vui lòng chọn ngày khác.'
            : '';

        $gallery = $this->details->images($tourId);

        $this->render('bookings/create', [
            'title' => 'Hoàn tất thông tin đặt tour',
            'tour' => $tour,
            'schedules' => $schedules,
            'tickets' => $this->details->tickets($tourId),
            'policy' => $this->content->cancellationPolicy($tourId),
            'coverUrl' => isset($gallery[0]) ? image_src((string) $gallery[0]['url']) : null,
            'selectedScheduleId' => $selectedScheduleId,
            'selectedTickets' => $this->selectedTickets(),
            'scheduleNotice' => $scheduleNotice,
            'contact' => ['name' => $user['name'], 'email' => $user['email'], 'phone' => ''],
            // Mỗi lần mở form một mã mới: gửi lại cùng form (bấm 2 lần, mạng chập chờn) chỉ tạo một đơn.
            'requestToken' => bin2hex(random_bytes(16)),
            'loginUrl' => url('/login') . '?next=' . rawurlencode(self::currentPath()),
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
            'pageScripts' => ['js/booking.js'],
        ]);
    }

    /**
     * POST /api/bookings – schedule_id, request_token, contact_name, contact_email, contact_phone,
     * passengers[i][ticket_type_id], passengers[i][full_name], special_request, expected_total, terms, _csrf.
     */
    public function store(): void
    {
        $user = Auth::user();
        if ($user === null) {
            $this->json(false, 'Vui lòng đăng nhập để đặt tour.', null, 401);
        }
        if ($user['role'] !== 'customer') {
            $this->json(false, 'Chỉ tài khoản khách hàng mới đặt được tour.', null, 403);
        }
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->json(false, self::CSRF_FAILED, null, 403);
        }

        [$form, $errors] = $this->validatedForm();
        if ($errors !== []) {
            $this->json(false, 'Vui lòng kiểm tra lại thông tin đặt tour.', ['errors' => $errors], 422);
        }

        $row = $this->bookings->create(
            $user['user_id'],
            $form['schedule_id'],
            $form['request_token'],
            $form['contact'],
            $form['passengers'],
            $form['special_request'],
            $form['expected_total']
        );
        $result = (string) $row['result'];
        $code = (string) ($row['booking_code'] ?? '');
        $remaining = (int) ($row['remaining'] ?? 0);
        $maxGroup = (int) ($row['max_group_size'] ?? 0);

        match ($result) {
            'ok' => $this->json(true, 'Đã gửi yêu cầu đặt tour.', [
                'code' => $code,
                'url' => url('/bookings/' . $code) . '?new=1',
            ], 201),
            'duplicate' => $this->json(true, 'Yêu cầu này đã được gửi trước đó.', [
                'code' => $code,
                'url' => url('/bookings/' . $code),
            ]),
            'forbidden' => $this->json(false, 'Tài khoản của bạn hiện không đặt tour được.', null, 403),
            'invalid' => $this->json(false, 'Vui lòng kiểm tra lại thông tin đặt tour.', ['errors' => []], 422),
            'schedule_unavailable' => $this->conflict($result, 'Lịch này không còn nhận đặt. Vui lòng chọn ngày khác.'),
            'group_limit' => $this->conflict($result, 'Mỗi nhóm tối đa ' . $maxGroup . ' khách.', ['max_group_size' => $maxGroup]),
            'no_seats' => $this->conflict(
                $result,
                $remaining > 0
                    ? 'Lịch này chỉ còn ' . $remaining . ' chỗ. Vui lòng giảm số khách hoặc chọn ngày khác.'
                    : 'Lịch này vừa hết chỗ. Vui lòng chọn ngày khác.',
                ['remaining' => $remaining]
            ),
            'tickets_changed' => $this->conflict($result, 'Loại vé của lịch này vừa thay đổi. Vui lòng chọn lại số khách.', [
                'tickets' => $this->ticketOptions($form['schedule_id']),
            ]),
            'price_changed' => $this->conflict(
                $result,
                'Giá vé vừa thay đổi, tổng tiền mới là ' . format_vnd((int) $row['total_vnd']) . '. Vui lòng xem lại trước khi gửi.',
                ['total_vnd' => (int) $row['total_vnd'], 'tickets' => $this->ticketOptions($form['schedule_id'])]
            ),
            default => $this->conflict('retry', 'Chưa gửi được yêu cầu, vui lòng bấm gửi lại.'),
        };
    }

    /**
     * Đọc và kiểm tra form đặt tour. Trả [dữ liệu đã chuẩn hóa, lỗi theo từng ô]; lỗi của khách thứ i có khóa "passengers.i".
     *
     * @return array{0: array<string, mixed>, 1: array<string, string>}
     */
    private function validatedForm(): array
    {
        $errors = [];
        $contact = [
            'name' => $this->input('contact_name'),
            'email' => mb_strtolower($this->input('contact_email')),
            'phone' => $this->input('contact_phone'),
        ];

        $scheduleId = self::parseUuid($this->input('schedule_id'));
        if ($scheduleId === null) {
            $errors['schedule_id'] = 'Vui lòng chọn ngày tham gia.';
        }

        // Mã yêu cầu và tổng tiền do trang tạo ra: sai dạng nghĩa là trang đã cũ hoặc bị sửa.
        $requestToken = $this->input('request_token');
        $expectedTotal = $this->input('expected_total');
        if (!preg_match('/^[0-9a-f]{32}$/', $requestToken) || !preg_match('/^\d{1,15}$/', $expectedTotal)) {
            $errors['form'] = 'Trang đặt tour đã cũ, vui lòng tải lại trang.';
        }

        if ($contact['name'] === '') {
            $errors['contact_name'] = 'Vui lòng nhập họ tên người liên hệ.';
        } elseif (mb_strlen($contact['name']) > UserModel::NAME_MAX_LENGTH) {
            $errors['contact_name'] = 'Họ tên tối đa ' . UserModel::NAME_MAX_LENGTH . ' ký tự.';
        }

        if ($contact['email'] === '') {
            $errors['contact_email'] = 'Vui lòng nhập email.';
        } elseif (mb_strlen($contact['email']) > UserModel::EMAIL_MAX_LENGTH || filter_var($contact['email'], FILTER_VALIDATE_EMAIL) === false) {
            $errors['contact_email'] = 'Email không hợp lệ.';
        }

        if ($contact['phone'] === '') {
            $errors['contact_phone'] = 'Vui lòng nhập số điện thoại.';
        } elseif (!preg_match(self::PHONE_PATTERN, $contact['phone'])) {
            $errors['contact_phone'] = 'Số điện thoại không hợp lệ.';
        }

        $passengers = [];
        $entries = array_values($this->inputArray('passengers'));
        if ($entries === []) {
            $errors['passengers'] = 'Vui lòng chọn ít nhất 1 khách.';
        } elseif (count($entries) > BookingModel::PASSENGERS_MAX) {
            $errors['passengers'] = 'Mỗi đơn tối đa ' . BookingModel::PASSENGERS_MAX . ' khách.';
        } else {
            foreach ($entries as $index => $entry) {
                $ticketId = self::parseUuid(self::stringValue($entry, 'ticket_type_id'));
                $fullName = self::stringValue($entry, 'full_name');
                $number = $index + 1;

                if ($ticketId === null) {
                    $errors['passengers.' . $index] = 'Loại vé của khách ' . $number . ' không hợp lệ, vui lòng chọn lại số khách.';
                } elseif ($fullName === '') {
                    $errors['passengers.' . $index] = 'Vui lòng nhập họ tên khách ' . $number . '.';
                } elseif (mb_strlen($fullName) > BookingModel::PASSENGER_NAME_MAX_LENGTH) {
                    $errors['passengers.' . $index] = 'Họ tên khách tối đa ' . BookingModel::PASSENGER_NAME_MAX_LENGTH . ' ký tự.';
                }
                $passengers[] = ['ticket_type_id' => (string) $ticketId, 'full_name' => $fullName];
            }
        }

        $specialRequest = $this->input('special_request');
        if (mb_strlen($specialRequest) > BookingModel::SPECIAL_REQUEST_MAX_LENGTH) {
            $errors['special_request'] = 'Yêu cầu đặc biệt tối đa ' . BookingModel::SPECIAL_REQUEST_MAX_LENGTH . ' ký tự.';
        }

        if ($this->input('terms') !== '1') {
            $errors['terms'] = 'Vui lòng đồng ý điều kiện đặt tour và chính sách hủy.';
        }

        return [[
            'schedule_id' => (string) $scheduleId,
            'request_token' => $requestToken,
            'contact' => $contact,
            'passengers' => $passengers,
            'special_request' => $specialRequest,
            'expected_total' => (int) $expectedTotal,
        ], $errors];
    }

    /**
     * Số khách theo loại vé từ query string (?tickets[<mã vé>]=2); bỏ mã vé sai dạng và số không hợp lệ.
     *
     * @return array<string, int>
     */
    private function selectedTickets(): array
    {
        $selected = [];
        foreach ($this->queryArray('tickets') as $ticketId => $quantity) {
            $ticketId = self::parseUuid((string) $ticketId);
            $quantity = is_string($quantity) ? filter_var($quantity, FILTER_VALIDATE_INT, [
                'options' => ['min_range' => 0, 'max_range' => BookingModel::PASSENGERS_MAX],
            ]) : false;
            if ($ticketId !== null && $quantity !== false) {
                $selected[$ticketId] = $quantity;
            }
        }

        return $selected;
    }

    /**
     * Giá vé hiện tại của lịch, để trang cập nhật lại khi giá hoặc loại vé vừa đổi.
     *
     * @return list<array{id: string, label: string, ages: string, price: int}>
     */
    private function ticketOptions(string $scheduleId): array
    {
        return array_map('ticket_option', $this->availability->tickets($scheduleId));
    }

    /** 409: lịch, số chỗ hoặc giá đã đổi từ lúc khách mở trang; reason cho JS biết cần cập nhật gì. */
    private function conflict(string $reason, string $message, array $data = []): never
    {
        $this->json(false, $message, ['reason' => $reason] + $data, 409);
    }

    /** Tài khoản quản trị đang đăng nhập mở trang đặt tour. */
    private function renderNotCustomer(): void
    {
        $this->render('bookings/message', [
            'title' => 'Không đặt tour được',
            'errorCode' => 'Lỗi 403',
            'heading' => 'Tài khoản này không đặt tour được',
            'text' => 'Chỉ tài khoản khách hàng mới đặt được tour. Vui lòng đăng xuất và đăng nhập bằng tài khoản khách hàng.',
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ], 403);
    }

    /** Một ô chuỗi trong phần tử của mảng form (vd. passengers[0][full_name]); thiếu hoặc không phải chuỗi UTF-8 → ''. */
    private static function stringValue(mixed $entry, string $key): string
    {
        $value = is_array($entry) ? ($entry[$key] ?? '') : '';

        return is_string($value) && mb_check_encoding($value, 'UTF-8') ? trim($value) : '';
    }

    /** Đường dẫn trang đang mở (kèm query string) để quay lại sau khi đăng nhập. */
    private static function currentPath(): string
    {
        $uri = $_SERVER['REQUEST_URI'] ?? '/tours';
        $query = (string) parse_url($uri, PHP_URL_QUERY);

        return Router::pathFromUri($uri) . ($query !== '' ? '?' . $query : '');
    }
}
