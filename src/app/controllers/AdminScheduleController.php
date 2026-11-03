<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminScheduleModel;
use App\Models\AdminTourModel;
use App\Models\PaymentResultModel;
use DateTimeImmutable;

/**
 * Lịch khởi hành, sức chứa và giá vé theo lịch (FR-14, Nguyễn Minh Thức).
 * Số chỗ đang giữ = sức chứa - số chỗ còn nhận (đơn "Chờ xác nhận" chưa giữ chỗ).
 * Sửa lịch: chỉ đổi giờ khi lịch chưa khởi hành, sức chứa không nhỏ hơn số chỗ đang giữ,
 * không hủy lịch khi còn yêu cầu đặt tour đang xử lý. Đổi giá không đổi giá của đơn đã đặt.
 */
final class AdminScheduleController extends AdminController
{
    private const MESSAGES = [
        'created' => 'Đã thêm lịch khởi hành.',
        'updated' => 'Đã lưu lịch khởi hành.',
        'unchanged' => 'Không có thay đổi nào.',
    ];

    private const EMPTY_FORM = ['starts_at' => '', 'ends_at' => '', 'capacity' => '', 'adult_price' => '', 'child_price' => '', 'status' => 'open'];

    private const PRICE_ERROR = 'Giá vé phải lớn hơn 0đ và không quá 100.000.000đ.';

    private AdminScheduleModel $schedules;

    public function __construct()
    {
        parent::__construct();
        $this->schedules = new AdminScheduleModel();
        // Hủy đơn quá hạn thanh toán trước để số chỗ đang giữ và đơn còn hiệu lực là số mới.
        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /admin/tours/{id}/schedules */
    public function index(string $id): void
    {
        $this->renderIndex($this->findTourOrFail($id), self::EMPTY_FORM, [], $this->flash(self::MESSAGES));
    }

    /** POST /admin/tours/{id}/schedules – starts_at, ends_at, capacity, adult_price, child_price, _csrf */
    public function store(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $old = $this->old();
        if (!$this->csrfValid()) {
            $this->renderIndex($tour, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        [$data, $errors] = self::validate($old, null);
        if ($errors !== []) {
            $this->renderIndex($tour, $old, $errors, '', 422);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->schedules->create($this->actorId(), $tourId, $data);
        match ((string) $row['result']) {
            'ok' => $this->redirect('/admin/tours/' . $tourId . '/schedules?msg=created'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->renderIndex($tour, $old, self::fieldError($row['field'] ?? null), '', 422),
        };
    }

    /** GET /admin/schedules/{id}/edit */
    public function edit(string $id): void
    {
        $schedule = $this->findScheduleOrFail($id);
        $this->renderEdit($schedule, self::oldFrom($schedule), []);
    }

    /** POST /admin/schedules/{id}/edit – starts_at, ends_at, capacity, adult_price, child_price, status, _csrf */
    public function update(string $id): void
    {
        $schedule = $this->findScheduleOrFail($id);
        $old = $this->old();
        if (!$this->csrfValid()) {
            $this->renderEdit($schedule, $old, ['form' => self::CSRF_FAILED], 403);
            return;
        }
        if ($schedule['status'] === 'completed') {
            $this->renderEdit($schedule, $old, ['form' => 'Lịch đã hoàn thành nên không sửa được nữa.'], 409);
            return;
        }

        [$data, $errors] = self::validate($old, $schedule);
        if ($errors !== []) {
            $this->renderEdit($schedule, $old, $errors, 422);
            return;
        }
        $conflicts = self::conflicts($data, $schedule);
        if ($conflicts !== []) {
            $this->renderEdit($schedule, $old, $conflicts, 409);
            return;
        }

        $scheduleId = (string) $schedule['schedule_id'];
        $back = '/admin/tours/' . $schedule['tour_id'] . '/schedules';
        $row = $this->schedules->update($this->actorId(), $scheduleId, $data);
        match ((string) $row['result']) {
            'ok' => $this->redirect($back . '?msg=updated'),
            'unchanged' => $this->redirect($back . '?msg=unchanged'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->renderRefused($scheduleId, $old, $row),
        };
    }

    /**
     * Procedure từ chối lưu: lịch vừa thay đổi (đơn mới được xác nhận, lịch tới giờ khởi hành...),
     * nên tải lại số liệu mới nhất rồi báo lỗi.
     *
     * @param array<string, string> $old
     * @param array<string, mixed> $row kết quả của NMT_sp_admin_schedule_update
     */
    private function renderRefused(string $scheduleId, array $old, array $row): void
    {
        $fresh = $this->findScheduleOrFail($scheduleId);
        match ((string) $row['result']) {
            'completed' => $this->renderEdit($fresh, $old, ['form' => 'Lịch đã hoàn thành nên không sửa được nữa.'], 409),
            'departed' => $this->renderEdit($fresh, $old, ['form' => 'Lịch đã khởi hành: không đổi được giờ khởi hành, giờ kết thúc hay trạng thái.'], 409),
            'capacity_below_held' => $this->renderEdit($fresh, $old, ['capacity' => self::capacityBelowHeld((int) $row['held'])], 409),
            'has_bookings' => $this->renderEdit($fresh, $old, ['status' => self::hasBookings((int) $row['active_bookings'])], 409),
            default => $this->renderEdit($fresh, $old, self::fieldError($row['field'] ?? null), 422),
        };
    }

    /** @return array<string, string> */
    private function old(): array
    {
        $old = [];
        foreach (array_keys(self::EMPTY_FORM) as $field) {
            $old[$field] = $this->input($field);
        }

        return $old;
    }

    /**
     * @param array<string, mixed> $schedule
     * @return array<string, string>
     */
    private static function oldFrom(array $schedule): array
    {
        return [
            'starts_at' => self::toInput((string) $schedule['starts_at']),
            'ends_at' => self::toInput((string) $schedule['ends_at']),
            'capacity' => (string) $schedule['capacity'],
            'adult_price' => (string) ($schedule['adult_price_vnd'] ?? ''),
            'child_price' => (int) $schedule['child_active'] === 1 ? (string) $schedule['child_price_vnd'] : '',
            'status' => $schedule['status'] === 'cancelled' ? 'cancelled' : 'open',
        ];
    }

    /**
     * Kiểm tra dữ liệu nhập của form thêm / sửa lịch (định dạng, giới hạn).
     *
     * @param array<string, string> $old
     * @param array<string, mixed>|null $schedule null = thêm lịch mới
     * @return array{0: array{starts_at: string, ends_at: string, capacity: int, adult_price: int, child_price: ?int, status: string}, 1: array<string, string>}
     */
    private static function validate(array $old, ?array $schedule): array
    {
        $errors = [];
        $now = (new DateTimeImmutable())->format('Y-m-d H:i:s');
        $departed = $schedule !== null && (int) $schedule['departed'] === 1;
        $startsAt = self::parseInput($old['starts_at']);
        $endsAt = self::parseInput($old['ends_at']);
        // Ô datetime-local chỉ có đến phút: giờ không đổi thì giữ đúng giá trị đang lưu.
        if ($schedule !== null) {
            $startsAt = self::sameMinute($startsAt, (string) $schedule['starts_at']) ? (string) $schedule['starts_at'] : $startsAt;
            $endsAt = self::sameMinute($endsAt, (string) $schedule['ends_at']) ? (string) $schedule['ends_at'] : $endsAt;
        }

        $timesChanged = $schedule === null || $startsAt !== $schedule['starts_at'] || $endsAt !== $schedule['ends_at'];

        if ($startsAt === null) {
            $errors['starts_at'] = 'Vui lòng chọn ngày giờ khởi hành.';
        } elseif ($timesChanged && !$departed && $startsAt <= $now) {
            $errors['starts_at'] = 'Giờ khởi hành phải sau thời điểm hiện tại.';
        }

        if ($endsAt === null) {
            $errors['ends_at'] = 'Vui lòng chọn ngày giờ kết thúc.';
        } elseif ($startsAt !== null && $endsAt <= $startsAt) {
            $errors['ends_at'] = 'Giờ kết thúc phải sau giờ khởi hành.';
        }

        $capacity = ctype_digit($old['capacity']) && strlen($old['capacity']) <= 4 ? (int) $old['capacity'] : 0;
        if ($capacity < 1 || $capacity > AdminScheduleModel::CAPACITY_MAX) {
            $errors['capacity'] = 'Sức chứa từ 1 đến ' . AdminScheduleModel::CAPACITY_MAX . ' chỗ.';
        }

        $adultPrice = self::parsePrice($old['adult_price']);
        if ($old['adult_price'] === '') {
            $errors['adult_price'] = 'Vui lòng nhập giá vé người lớn.';
        } elseif ($adultPrice === null) {
            $errors['adult_price'] = self::PRICE_ERROR;
        }

        $childPrice = self::parsePrice($old['child_price']);
        if ($old['child_price'] !== '' && $childPrice === null) {
            $errors['child_price'] = self::PRICE_ERROR;
        }

        $status = $schedule === null ? 'open' : $old['status'];
        if (!in_array($status, ['open', 'cancelled'], true)) {
            $errors['status'] = 'Vui lòng chọn trạng thái lịch.';
        }

        $data = [
            'starts_at' => (string) $startsAt,
            'ends_at' => (string) $endsAt,
            'capacity' => $capacity,
            'adult_price' => (int) $adultPrice,
            'child_price' => $childPrice,
            'status' => $status,
        ];

        return [$data, $errors];
    }

    /**
     * Kiểm tra theo tình trạng hiện tại của lịch (409): đã khởi hành, số chỗ đang giữ, yêu cầu đặt tour đang xử lý.
     * NMT_sp_admin_schedule_update kiểm tra lại trong transaction.
     *
     * @param array{starts_at: string, ends_at: string, capacity: int, adult_price: int, child_price: ?int, status: string} $data
     * @param array<string, mixed> $schedule
     * @return array<string, string>
     */
    private static function conflicts(array $data, array $schedule): array
    {
        $errors = [];
        $departed = (int) $schedule['departed'] === 1;
        $isCancelled = $schedule['status'] === 'cancelled';
        $activeBookings = (int) $schedule['active_booking_count'];

        if ($departed && ($data['starts_at'] !== $schedule['starts_at'] || $data['ends_at'] !== $schedule['ends_at'])) {
            $errors['starts_at'] = 'Lịch đã khởi hành nên không đổi được giờ khởi hành, giờ kết thúc.';
        }
        if ($data['capacity'] < (int) $schedule['held']) {
            $errors['capacity'] = self::capacityBelowHeld((int) $schedule['held']);
        }
        if ($departed && ($data['status'] === 'cancelled') !== $isCancelled) {
            $errors['status'] = 'Lịch đã khởi hành nên không đổi được trạng thái.';
        } elseif ($data['status'] === 'cancelled' && !$isCancelled && $activeBookings > 0) {
            $errors['status'] = self::hasBookings($activeBookings);
        }

        return $errors;
    }

    /** "2026-11-02T17:00" (ô datetime-local) → "2026-11-02 17:00:00"; null khi sai định dạng. */
    private static function parseInput(string $value): ?string
    {
        foreach (['!Y-m-d\TH:i', '!Y-m-d\TH:i:s'] as $format) {
            $parsed = DateTimeImmutable::createFromFormat($format, $value);
            if ($parsed !== false && $parsed->format(substr($format, 1)) === $value) {
                return $parsed->format('Y-m-d H:i:00');
            }
        }

        return null;
    }

    private static function sameMinute(?string $a, string $b): bool
    {
        return $a !== null && substr($a, 0, 16) === substr($b, 0, 16);
    }

    /** "2026-11-02 17:00:00" → "2026-11-02T17:00" (giá trị của ô datetime-local). */
    private static function toInput(string $value): string
    {
        return substr($value, 0, 10) . 'T' . substr($value, 11, 5);
    }

    /** "650.000", "650 000" hoặc "650000" → 650000; null khi không phải số tiền hợp lệ. */
    private static function parsePrice(string $value): ?int
    {
        $digits = str_replace(['.', ',', ' '], '', $value);
        if (!ctype_digit($digits) || strlen($digits) > 9) {
            return null;
        }

        $price = (int) $digits;

        return $price >= 1 && $price <= AdminScheduleModel::PRICE_MAX ? $price : null;
    }

    private static function capacityBelowHeld(int $held): string
    {
        return 'Sức chứa không được nhỏ hơn số chỗ đang giữ (' . $held . ' chỗ).';
    }

    private static function hasBookings(int $count): string
    {
        return 'Không hủy được lịch: còn ' . $count . ' yêu cầu đặt tour đang chờ xác nhận, chờ thanh toán hoặc đã xác nhận. '
            . 'Hãy từ chối hoặc hủy các yêu cầu này ở trang "Yêu cầu đặt tour" trước.';
    }

    /** @return array<string, string> */
    private static function fieldError(mixed $field): array
    {
        $field = (string) $field;

        return isset(self::EMPTY_FORM[$field])
            ? [$field => 'Giá trị không hợp lệ, vui lòng kiểm tra lại.']
            : ['form' => 'Không lưu được, vui lòng kiểm tra lại thông tin.'];
    }

    /** @return array<string, mixed> */
    private function findTourOrFail(string $id): array
    {
        $tourId = self::parseUuid($id);
        $tour = $tourId === null ? null : (new AdminTourModel())->find($tourId);

        return $tour ?? self::notFound();
    }

    /** @return array<string, mixed> */
    private function findScheduleOrFail(string $id): array
    {
        $scheduleId = self::parseUuid($id);
        $schedule = $scheduleId === null ? null : $this->schedules->find($scheduleId);

        return $schedule ?? self::notFound();
    }

    /**
     * @param array<string, mixed> $tour
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderIndex(array $tour, array $old, array $errors, string $success, int $status = 200): void
    {
        $tourId = (string) $tour['tour_id'];
        $this->render('admin/schedules/index', [
            'title' => 'Lịch khởi hành · ' . $tour['title'],
            'adminNav' => 'tours',
            'tour' => $tour,
            'schedules' => $this->schedules->list($tourId),
            'logs' => $this->schedules->logs($tourId),
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }

    /**
     * @param array<string, mixed> $schedule
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderEdit(array $schedule, array $old, array $errors, int $status = 200): void
    {
        $this->render('admin/schedules/edit', [
            'title' => 'Sửa lịch khởi hành',
            'adminNav' => 'tours',
            'schedule' => $schedule,
            'old' => $old,
            'errors' => $errors,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
