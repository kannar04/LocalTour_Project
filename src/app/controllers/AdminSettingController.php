<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\SettingModel;

/**
 * Thông số vận hành (Nguyễn Tuấn Khôi): quản trị viên xem và đổi % phí dịch vụ LocalTour, thời gian giữ chỗ, hạn nhận
 * đặt trước giờ khởi hành và hạn nhận chuyển khoản VietQR. Mỗi lần đổi được ghi người sửa và admin_logs (file 30).
 */
final class AdminSettingController extends AdminController
{
    private const MESSAGES = [
        'saved' => 'Đã lưu thông số vận hành.',
        'unchanged' => 'Không có thay đổi nào.',
    ];

    private SettingModel $settings;

    public function __construct()
    {
        parent::__construct();
        $this->settings = new SettingModel();
    }

    /** GET /admin/settings */
    public function index(): void
    {
        $saved = $this->settings->all();
        $old = [];
        // Thiếu dòng thông số: hiện giá trị mặc định mà các procedure đang dùng, không để ô trống.
        foreach (SettingModel::FIELDS as $name => $field) {
            $old[$name] = (string) ($saved[$name]['value'] ?? $field['default']);
        }
        $old['commission_percent'] = str_replace('.', ',', $old['commission_percent']);

        $this->renderForm($saved, $old, [], $this->flash(self::MESSAGES));
    }

    /** POST /admin/settings – commission_percent, hold_minutes, booking_cutoff_minutes, vietqr_cutoff_hours, _csrf */
    public function save(): void
    {
        $old = [];
        foreach (array_keys(SettingModel::FIELDS) as $name) {
            $old[$name] = $this->input($name);
        }
        if (!$this->csrfValid()) {
            $this->renderForm($this->settings->all(), $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $errors = self::validate($old);
        if ($errors !== []) {
            $this->renderForm($this->settings->all(), $old, $errors, '', 422);
            return;
        }

        $row = $this->settings->save(
            $this->actorId(),
            str_replace(',', '.', $old['commission_percent']),
            (int) $old['hold_minutes'],
            (int) $old['booking_cutoff_minutes'],
            (int) $old['vietqr_cutoff_hours']
        );
        match ($row['result']) {
            'ok' => $this->redirect('/admin/settings?msg=saved'),
            'unchanged' => $this->redirect('/admin/settings?msg=unchanged'),
            'forbidden' => self::forbidden(),
            default => $this->renderForm($this->settings->all(), $old, self::fieldError($row['field']), '', 422),
        };
    }

    /**
     * Lỗi theo từng thông số; [] khi hợp lệ.
     *
     * @param array<string, string> $old
     * @return array<string, string>
     */
    private static function validate(array $old): array
    {
        $errors = [];
        foreach (SettingModel::FIELDS as $name => $field) {
            $value = $old[$name];
            if ($name === 'commission_percent') {
                // Số từ 0 đến 100, tối đa 2 chữ số thập phân; nhận cả dấu phẩy và dấu chấm.
                $valid = preg_match('/^\d{1,3}([.,]\d{1,2})?$/', $value) === 1 && (float) str_replace(',', '.', $value) <= 100;
            } else {
                $valid = ctype_digit($value) && strlen($value) <= 4 && (int) $value >= $field['min'] && (int) $value <= $field['max'];
            }
            if (!$valid) {
                $errors[$name] = self::rangeError($name);
            }
        }

        return $errors;
    }

    private static function rangeError(string $name): string
    {
        $field = SettingModel::FIELDS[$name];

        return $name === 'commission_percent'
            ? 'Nhập số từ 0 đến 100, tối đa 2 chữ số thập phân (ví dụ 10 hoặc 12,5).'
            : 'Nhập số nguyên từ ' . $field['min'] . ' đến ' . $field['max'] . ' ' . $field['unit'] . '.';
    }

    /** @return array<string, string> */
    private static function fieldError(?string $field): array
    {
        return isset(SettingModel::FIELDS[(string) $field])
            ? [(string) $field => self::rangeError((string) $field)]
            : ['form' => 'Không lưu được, vui lòng kiểm tra lại thông tin.'];
    }

    /**
     * @param array<string, array<string, mixed>> $saved
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderForm(array $saved, array $old, array $errors, string $success, int $status = 200): void
    {
        $this->render('admin/settings/index', [
            'title' => 'Thông số vận hành',
            'adminNav' => 'settings',
            'saved' => $saved,
            'payoutsFrom' => $this->settings->payoutsFrom(),
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
