<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;
use App\Models\AdminProviderModel;

/**
 * Đơn vị tổ chức (FR-13, Nguyễn Minh Thức): danh sách, thêm, sửa thông tin và trạng thái hợp tác.
 * Đơn vị chưa có tài khoản đăng nhập riêng: thêm đơn vị = thêm tài khoản 'provider' không có mật khẩu.
 * Mỗi lần thêm / sửa được ghi lịch sử (admin_logs, target_type 'provider').
 */
final class AdminProviderController extends AdminController
{
    private const MESSAGES = [
        'created' => 'Đã thêm đơn vị tổ chức.',
        'updated' => 'Đã lưu thông tin đơn vị tổ chức.',
        'unchanged' => 'Không có thay đổi nào.',
    ];

    /** Lỗi khi procedure báo ô sai (đã kiểm tra ở PHP trước, đây là lớp chặn cuối). */
    private const FIELD_ERRORS = [
        'business_name' => 'Tên đơn vị không hợp lệ.',
        'contact_phone' => 'Số điện thoại không hợp lệ.',
        'email' => 'Email không hợp lệ.',
        'approval_status' => 'Vui lòng chọn trạng thái hợp tác.',
    ];

    private const EMAIL_TAKEN = 'Email này đã được dùng cho một tài khoản khác.';

    private AdminProviderModel $providers;

    public function __construct()
    {
        parent::__construct();
        $this->providers = new AdminProviderModel();
    }

    /** GET /admin/providers */
    public function index(): void
    {
        $this->render('admin/providers/index', [
            'title' => 'Đơn vị tổ chức',
            'adminNav' => 'providers',
            'providers' => $this->providers->list(),
            'success' => $this->flash(self::MESSAGES),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /admin/providers/new */
    public function create(): void
    {
        $this->renderForm(null, ['business_name' => '', 'contact_phone' => '', 'email' => '', 'approval_status' => 'pending'], []);
    }

    /** POST /admin/providers/new – business_name, contact_phone, email, approval_status, _csrf */
    public function store(): void
    {
        $old = $this->old();
        if (!$this->csrfValid()) {
            $this->renderForm(null, $old, ['form' => self::CSRF_FAILED], 403);
            return;
        }

        $errors = self::validate($old);
        if ($errors !== []) {
            $this->renderForm(null, $old, $errors, 422);
            return;
        }

        $row = $this->providers->create($this->actorId(), $old);
        match ((string) $row['result']) {
            'ok' => $this->redirect('/admin/providers?msg=created'),
            'forbidden' => self::forbidden(),
            'email_taken' => $this->renderForm(null, $old, ['email' => self::EMAIL_TAKEN], 409),
            default => $this->renderForm(null, $old, self::fieldError($row['field'] ?? null), 422),
        };
    }

    /** GET /admin/providers/{id}/edit */
    public function edit(string $id): void
    {
        $provider = $this->findOrFail($id);
        $this->renderForm($provider, self::oldFrom($provider), []);
    }

    /** POST /admin/providers/{id}/edit – business_name, contact_phone, email, approval_status, _csrf */
    public function update(string $id): void
    {
        $provider = $this->findOrFail($id);
        $old = $this->old();
        if (!$this->csrfValid()) {
            $this->renderForm($provider, $old, ['form' => self::CSRF_FAILED], 403);
            return;
        }

        $errors = self::validate($old);
        if ($errors !== []) {
            $this->renderForm($provider, $old, $errors, 422);
            return;
        }

        $providerId = (string) $provider['provider_id'];
        $row = $this->providers->update($this->actorId(), $providerId, $old);
        match ((string) $row['result']) {
            'ok' => $this->redirect('/admin/providers?msg=updated'),
            'unchanged' => $this->redirect('/admin/providers?msg=unchanged'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            // Email vừa được tài khoản khác dùng: tải lại thông tin mới nhất của đơn vị.
            'email_taken' => $this->renderForm($this->findOrFail($providerId), $old, ['email' => self::EMAIL_TAKEN], 409),
            default => $this->renderForm($provider, $old, self::fieldError($row['field'] ?? null), 422),
        };
    }

    /** @return array{business_name: string, contact_phone: string, email: string, approval_status: string} */
    private function old(): array
    {
        return [
            'business_name' => $this->input('business_name'),
            'contact_phone' => $this->input('contact_phone'),
            'email' => mb_strtolower($this->input('email')),
            'approval_status' => $this->input('approval_status'),
        ];
    }

    /**
     * @param array<string, mixed> $provider
     * @return array{business_name: string, contact_phone: string, email: string, approval_status: string}
     */
    private static function oldFrom(array $provider): array
    {
        return [
            'business_name' => (string) $provider['business_name'],
            'contact_phone' => (string) $provider['contact_phone'],
            'email' => (string) $provider['email'],
            'approval_status' => (string) $provider['approval_status'],
        ];
    }

    /**
     * Lỗi theo từng ô; [] khi hợp lệ.
     *
     * @param array{business_name: string, contact_phone: string, email: string, approval_status: string} $old
     * @return array<string, string>
     */
    private static function validate(array $old): array
    {
        $errors = [];

        if ($old['business_name'] === '') {
            $errors['business_name'] = 'Vui lòng nhập tên đơn vị.';
        } elseif (mb_strlen($old['business_name']) > AdminProviderModel::NAME_MAX_LENGTH) {
            $errors['business_name'] = 'Tên đơn vị tối đa ' . AdminProviderModel::NAME_MAX_LENGTH . ' ký tự.';
        }

        // Giống số điện thoại ở form đăng ký: 8–20 ký tự gồm chữ số và khoảng trắng, có thể bắt đầu bằng +.
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

        if (!in_array($old['approval_status'], AdminProviderModel::STATUSES, true)) {
            $errors['approval_status'] = 'Vui lòng chọn trạng thái hợp tác.';
        }

        return $errors;
    }

    /** @return array<string, string> */
    private static function fieldError(mixed $field): array
    {
        $field = (string) $field;

        return isset(self::FIELD_ERRORS[$field]) ? [$field => self::FIELD_ERRORS[$field]] : ['form' => 'Không lưu được, vui lòng kiểm tra lại thông tin.'];
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $id): array
    {
        $providerId = self::parseUuid($id);
        $provider = $providerId === null ? null : $this->providers->find($providerId);

        return $provider ?? self::notFound();
    }

    /**
     * $provider null = form thêm mới.
     *
     * @param array<string, mixed>|null $provider
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderForm(?array $provider, array $old, array $errors, int $status = 200): void
    {
        $this->render('admin/providers/form', [
            'title' => $provider === null ? 'Thêm đơn vị tổ chức' : 'Sửa đơn vị tổ chức',
            'adminNav' => 'providers',
            'provider' => $provider,
            'old' => $old,
            'errors' => $errors,
            'history' => $provider === null ? [] : (new AdminBookingModel())->history('provider', (string) $provider['provider_id']),
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
