<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminProviderModel;
use App\Models\AdminTourFormModel;

/**
 * Thêm tour và sửa thông tin tour (FR-13, NFR-07, Nguyễn Minh Thức).
 * Tour mới ở trạng thái "Chờ duyệt" (duyệt ở trang chi tiết tour); sửa thông tin giữ nguyên trạng thái duyệt.
 * "Đã xác minh" cần nguồn tham khảo; ngày xác minh = ngày chuyển sang "Đã xác minh".
 * Ảnh, lịch trình, dịch vụ bao gồm, dịch vụ thêm và chính sách hủy chưa sửa được ở đây.
 */
final class AdminTourFormController extends AdminController
{
    /** Số ký tự tối đa của các ô chữ (ô 255 / 500 theo cột trong bảng tours). */
    public const MAX_LENGTHS = [
        'title' => 200, 'description' => 5000, 'language_codes' => 50,
        'meeting_point' => 255, 'transport' => 255, 'guide_info' => 255, 'dropoff_point' => 255,
        'document_terms' => 2000, 'meal_terms' => 2000, 'voucher_terms' => 2000, 'reschedule_terms' => 2000,
        'source_url' => 500,
    ];

    public const DURATION_MIN = 15;
    public const DURATION_MAX = 10080;
    public const GROUP_MAX = 500;

    /** Ô nhiều dòng: đổi \r\n thành \n trước khi kiểm tra độ dài và lưu. */
    private const MULTILINE = ['description', 'document_terms', 'meal_terms', 'voucher_terms', 'reschedule_terms'];

    private const DEFAULTS = [
        'provider_id' => '', 'destination_id' => '', 'category_id' => '', 'title' => '', 'description' => '',
        'duration_minutes' => '', 'max_group_size' => '', 'language_codes' => 'vi', 'pickup_mode' => 'meeting_point',
        'meeting_point' => '', 'transport' => '', 'guide_info' => '', 'dropoff_point' => '', 'document_terms' => '',
        'meal_terms' => '', 'voucher_terms' => '', 'reschedule_terms' => '', 'source_url' => '',
        'verification_status' => 'unverified',
    ];

    private AdminTourFormModel $tours;

    public function __construct()
    {
        parent::__construct();
        $this->tours = new AdminTourFormModel();
    }

    /** GET /admin/tours/new */
    public function create(): void
    {
        $this->renderForm(null, self::DEFAULTS, []);
    }

    /** POST /admin/tours/new – các ô trong AdminTourFormModel::FIELDS, _csrf */
    public function store(): void
    {
        $old = $this->old();
        if (!$this->csrfValid()) {
            $this->renderForm(null, $old, ['form' => self::CSRF_FAILED], 403);
            return;
        }

        $options = $this->options();
        $errors = self::validate($old, $options);
        if ($errors !== []) {
            $this->renderForm(null, $old, $errors, 422, $options);
            return;
        }

        $row = $this->tours->create($this->actorId(), $old);
        match ((string) $row['result']) {
            'ok' => $this->redirect('/admin/tours/' . $row['tour_id'] . '?msg=created'),
            'forbidden' => self::forbidden(),
            default => $this->renderForm(null, $old, self::fieldError($row['field'] ?? null), 422, $options),
        };
    }

    /** GET /admin/tours/{id}/edit */
    public function edit(string $id): void
    {
        $tour = $this->findOrFail($id);
        $old = [];
        foreach (array_keys(self::DEFAULTS) as $field) {
            $old[$field] = (string) ($tour[$field] ?? '');
        }

        $this->renderForm($tour, $old, []);
    }

    /** POST /admin/tours/{id}/edit – các ô trong AdminTourFormModel::FIELDS, _csrf */
    public function update(string $id): void
    {
        $tour = $this->findOrFail($id);
        $old = $this->old();
        if (!$this->csrfValid()) {
            $this->renderForm($tour, $old, ['form' => self::CSRF_FAILED], 403);
            return;
        }

        $options = $this->options();
        $errors = self::validate($old, $options);
        if ($errors !== []) {
            $this->renderForm($tour, $old, $errors, 422, $options);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        $row = $this->tours->update($this->actorId(), $tourId, $old);
        match ((string) $row['result']) {
            'ok' => $this->redirect('/admin/tours/' . $tourId . '?msg=updated'),
            'unchanged' => $this->redirect('/admin/tours/' . $tourId . '?msg=unchanged'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->renderForm($tour, $old, self::fieldError($row['field'] ?? null), 422, $options),
        };
    }

    /** @return array<string, string> */
    private function old(): array
    {
        $old = [];
        foreach (array_keys(self::DEFAULTS) as $field) {
            $value = $this->input($field);
            $old[$field] = in_array($field, self::MULTILINE, true) ? str_replace(["\r\n", "\r"], "\n", $value) : $value;
        }

        // "vi, EN ,en" → "vi,en"
        $codes = array_filter(array_map('trim', explode(',', mb_strtolower($old['language_codes']))), static fn (string $code): bool => $code !== '');
        $old['language_codes'] = implode(',', array_unique($codes));

        return $old;
    }

    /**
     * Danh sách chọn của form: mã → nhãn.
     *
     * @return array{providers: array<string, string>, destinations: array<string, string>, categories: array<string, string>}
     */
    private function options(): array
    {
        $providers = [];
        foreach ((new AdminProviderModel())->list() as $provider) {
            $label = (string) $provider['business_name'];
            if ($provider['approval_status'] !== 'approved') {
                $label .= ' (' . provider_status_label($provider['approval_status']) . ')';
            }
            $providers[(string) $provider['provider_id']] = $label;
        }

        $destinations = [];
        foreach ($this->tours->destinations() as $destination) {
            $destinations[(string) $destination['destination_id']] = (string) $destination['name'];
        }

        $categories = [];
        foreach ($this->tours->categories() as $category) {
            $categories[(string) $category['category_id']] = (string) $category['name'];
        }

        return ['providers' => $providers, 'destinations' => $destinations, 'categories' => $categories];
    }

    /**
     * Lỗi theo từng ô; [] khi hợp lệ.
     *
     * @param array<string, string> $old
     * @param array{providers: array<string, string>, destinations: array<string, string>, categories: array<string, string>} $options
     * @return array<string, string>
     */
    private static function validate(array $old, array $options): array
    {
        $errors = [];

        if (!isset($options['providers'][$old['provider_id']])) {
            $errors['provider_id'] = 'Vui lòng chọn đơn vị tổ chức.';
        }
        if (!isset($options['destinations'][$old['destination_id']])) {
            $errors['destination_id'] = 'Vui lòng chọn điểm đến.';
        }
        if ($old['category_id'] !== '' && !isset($options['categories'][$old['category_id']])) {
            $errors['category_id'] = 'Loại hình không hợp lệ.';
        }

        if ($old['title'] === '') {
            $errors['title'] = 'Vui lòng nhập tên tour.';
        }
        if ($old['description'] === '') {
            $errors['description'] = 'Vui lòng nhập mô tả tour.';
        }

        if (!self::intBetween($old['duration_minutes'], self::DURATION_MIN, self::DURATION_MAX)) {
            $errors['duration_minutes'] = 'Thời lượng là số phút từ ' . self::DURATION_MIN . ' đến ' . number_format(self::DURATION_MAX, 0, ',', '.') . ' (7 ngày).';
        }
        if (!self::intBetween($old['max_group_size'], 1, self::GROUP_MAX)) {
            $errors['max_group_size'] = 'Số khách tối đa từ 1 đến ' . self::GROUP_MAX . '.';
        }

        if ($old['language_codes'] === '') {
            $errors['language_codes'] = 'Vui lòng nhập ít nhất một mã ngôn ngữ.';
        } elseif (!preg_match('/^[a-z]{2}(,[a-z]{2})*$/', $old['language_codes'])) {
            $errors['language_codes'] = 'Mã ngôn ngữ gồm 2 chữ cái, cách nhau bằng dấu phẩy (vd. vi,en).';
        }

        if (!in_array($old['pickup_mode'], ['meeting_point', 'hotel_pickup'], true)) {
            $errors['pickup_mode'] = 'Vui lòng chọn hình thức đón khách.';
        } elseif ($old['pickup_mode'] === 'meeting_point' && $old['meeting_point'] === '') {
            $errors['meeting_point'] = 'Vui lòng nhập điểm hẹn khi khách tự đến điểm hẹn.';
        }

        if ($old['source_url'] !== '' && (!preg_match('~^https?://\S+$~i', $old['source_url']) || parse_url($old['source_url'], PHP_URL_HOST) === null)) {
            $errors['source_url'] = 'Nguồn tham khảo phải là đường dẫn bắt đầu bằng http:// hoặc https://.';
        }

        if (!in_array($old['verification_status'], ['unverified', 'verified'], true)) {
            $errors['verification_status'] = 'Vui lòng chọn trạng thái xác minh.';
        } elseif ($old['verification_status'] === 'verified' && $old['source_url'] === '' && !isset($errors['source_url'])) {
            // NFR-07: thiếu nguồn thì để "Chưa xác minh".
            $errors['source_url'] = 'Cần nguồn tham khảo để đánh dấu "Đã xác minh".';
        }

        foreach (self::MAX_LENGTHS as $field => $max) {
            if (!isset($errors[$field]) && mb_strlen($old[$field]) > $max) {
                $errors[$field] = 'Tối đa ' . number_format($max, 0, ',', '.') . ' ký tự.';
            }
        }

        return $errors;
    }

    private static function intBetween(string $value, int $min, int $max): bool
    {
        return ctype_digit($value) && strlen($value) <= 6 && (int) $value >= $min && (int) $value <= $max;
    }

    /** @return array<string, string> */
    private static function fieldError(mixed $field): array
    {
        $field = (string) $field;

        return isset(self::DEFAULTS[$field])
            ? [$field => 'Giá trị không hợp lệ, vui lòng kiểm tra lại.']
            : ['form' => 'Không lưu được, vui lòng kiểm tra lại thông tin.'];
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $id): array
    {
        $tourId = self::parseUuid($id);
        $tour = $tourId === null ? null : $this->tours->find($tourId);

        return $tour ?? self::notFound();
    }

    /**
     * $tour null = form thêm tour.
     *
     * @param array<string, mixed>|null $tour
     * @param array<string, string> $old
     * @param array<string, string> $errors
     * @param array{providers: array<string, string>, destinations: array<string, string>, categories: array<string, string>}|null $options
     */
    private function renderForm(?array $tour, array $old, array $errors, int $status = 200, ?array $options = null): void
    {
        $this->render('admin/tours/form', [
            'title' => $tour === null ? 'Thêm tour' : 'Sửa thông tin tour',
            'adminNav' => 'tours',
            'tour' => $tour,
            'old' => $old,
            'errors' => $errors,
            'options' => $options ?? $this->options(),
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
