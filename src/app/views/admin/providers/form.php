<?php declare(strict_types=1); ?>
<?php
/*
 * Form thêm / sửa đơn vị tổ chức (FR-13, Nguyễn Minh Thức).
 * Biến: $provider (NMT_sp_admin_provider_detail; null = thêm mới), $old (business_name, contact_phone, email,
 *       approval_status đang nhập), $errors (lỗi theo ô; 'form' = lỗi chung như hết phiên),
 *       $history (lịch sử thêm / sửa, cũ trước; [] khi thêm mới).
 */
use App\Models\AdminProviderModel;

$isNew = $provider === null;
$action = $isNew ? '/admin/providers/new' : '/admin/providers/' . $provider['provider_id'] . '/edit';
$fields = [
    ['name' => 'business_name', 'label' => 'Tên đơn vị', 'type' => 'text', 'maxlength' => AdminProviderModel::NAME_MAX_LENGTH, 'autocomplete' => 'organization', 'hint' => ''],
    ['name' => 'contact_phone', 'label' => 'Số điện thoại liên hệ', 'type' => 'tel', 'maxlength' => 20, 'autocomplete' => 'tel', 'hint' => '8–20 ký tự: chữ số, khoảng trắng, có thể bắt đầu bằng +.'],
    ['name' => 'email', 'label' => 'Email liên hệ', 'type' => 'email', 'maxlength' => AdminProviderModel::EMAIL_MAX_LENGTH, 'autocomplete' => 'email', 'hint' => 'Mỗi email chỉ dùng cho một tài khoản.'],
];
$statusHints = [
    'approved' => 'Tour đã duyệt của đơn vị được hiển thị cho khách.',
    'pending' => 'Chưa hiển thị tour của đơn vị cho khách.',
    'rejected' => 'Ẩn mọi tour của đơn vị khỏi trang khách.',
];
$historyLabels = ['provider_create' => 'Thêm đơn vị', 'provider_update' => 'Sửa thông tin'];
$focusField = array_key_first(array_diff_key($errors, ['form' => true])) ?? 'business_name';
$statusError = $errors['approval_status'] ?? '';
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/admin/providers')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Danh sách đơn vị
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title"><?= $isNew ? 'Thêm đơn vị tổ chức' : e($provider['business_name']) ?></h1>
                <p class="lt-admin__subtitle">
<?php if ($isNew): ?>
                    Đơn vị chưa có tài khoản đăng nhập riêng: LocalTour quản lý tour và lịch khởi hành thay cho đơn vị.
<?php else: ?>
                    <span class="lt-badge lt-badge--<?= e($provider['approval_status']) ?>"><?= e(provider_status_label($provider['approval_status'])) ?></span>
                    <?= e($provider['tour_count']) ?> tour
<?php endif; ?>
                </p>
            </header>

<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="provider-form-title">
                        <h2 class="lt-panel__title" id="provider-form-title">Thông tin đơn vị</h2>
                        <form class="lt-admin-form" action="<?= e(url($action)) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
<?php foreach ($fields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'provider-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
    $describedBy = trim(($field['hint'] !== '' ? $id . '-hint ' : '') . ($error !== '' ? $id . '-error' : ''));
?>
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
                                <input class="lt-admin-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="<?= e($field['type']) ?>"
                                       id="<?= e($id) ?>" name="<?= e($name) ?>" value="<?= e($old[$name]) ?>"
                                       maxlength="<?= e($field['maxlength']) ?>" autocomplete="<?= e($field['autocomplete']) ?>" required
                                       <?= $error !== '' ? 'aria-invalid="true"' : '' ?>
                                       <?= $describedBy !== '' ? 'aria-describedby="' . e($describedBy) . '"' : '' ?> <?= $name === $focusField ? 'autofocus' : '' ?>>
<?php if ($field['hint'] !== ''): ?>
                                <p class="lt-admin-hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php endif; ?>
<?php if ($error !== ''): ?>
                                <p class="lt-admin-error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                            </div>
<?php endforeach; ?>

                            <fieldset class="lt-choices<?= $statusError !== '' ? ' is-invalid' : '' ?>"<?= $statusError !== '' ? ' aria-describedby="provider-status-error"' : '' ?>>
                                <legend class="lt-admin-label">Trạng thái hợp tác</legend>
<?php foreach (AdminProviderModel::STATUSES as $value): ?>
                                <label class="lt-choice">
                                    <input type="radio" name="approval_status" value="<?= e($value) ?>" required<?= $old['approval_status'] === $value ? ' checked' : '' ?>>
                                    <span><strong><?= e(provider_status_label($value)) ?></strong><br><span class="lt-muted"><?= e($statusHints[$value]) ?></span></span>
                                </label>
<?php endforeach; ?>
<?php if ($statusError !== ''): ?>
                                <p class="lt-admin-error" id="provider-status-error"><?= e($statusError) ?></p>
<?php endif; ?>
                            </fieldset>

                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit"><?= $isNew ? 'Thêm đơn vị' : 'Lưu thay đổi' ?></button>
                        </form>
                    </section>
                </div>

<?php if (!$isNew): ?>
                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="provider-history-title">
                        <h2 class="lt-panel__title" id="provider-history-title">Lịch sử thay đổi</h2>
<?php if ($history === []): ?>
                        <p class="lt-empty">Chưa có thay đổi nào được ghi lại.</p>
<?php else: ?>
                        <ol class="lt-history">
<?php foreach ($history as $log): ?>
                            <li class="lt-history__item">
                                <p class="lt-history__head">
                                    <?= e($historyLabels[$log['action']] ?? $log['action']) ?>:
<?php if ($log['from_status'] !== null && $log['from_status'] !== $log['to_status']): ?>
                                    <?= e(provider_status_label($log['from_status'])) ?> →
<?php endif; ?>
                                    <strong><?= e(provider_status_label($log['to_status'])) ?></strong>
                                </p>
                                <p class="lt-history__meta"><?= e(format_datetime($log['created_at'])) ?> · <?= e($log['actor_name']) ?></p>
<?php if ($log['note'] !== null): ?>
                                <p class="lt-history__note"><?= e($log['note']) ?></p>
<?php endif; ?>
                            </li>
<?php endforeach; ?>
                        </ol>
<?php endif; ?>
                    </section>
                </div>
<?php endif; ?>
            </div>
        </main>
    </div>
</div>
