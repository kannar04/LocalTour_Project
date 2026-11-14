<?php declare(strict_types=1); ?>
<?php
/*
 * Thông số vận hành (Nguyễn Tuấn Khôi): % phí dịch vụ LocalTour, thời gian giữ chỗ, hạn nhận đặt và hạn nhận VietQR.
 * Biến: $saved (NTK_sp_setting_list theo tên: value, updated_at, updated_by_name), $old (giá trị đang nhập theo tên),
 *       $errors (lỗi theo tên thông số; 'form' = lỗi chung), $success ('' = không có),
 *       $payoutsFrom (mốc bắt đầu lập khoản chi trả 'Y-m-d H:i:s', chỉ đọc; null = không có mốc).
 */
use App\Models\SettingModel;

$focusField = array_key_first(array_diff_key($errors, ['form' => true]));
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Thông số vận hành</h1>
                <p class="lt-admin__subtitle">Các mức áp dụng chung cho toàn bộ LocalTour. Mỗi lần đổi đều được ghi lại người sửa và thời điểm sửa.</p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="settings-form-title">
                        <h2 class="lt-panel__title" id="settings-form-title">Phí dịch vụ và hạn đặt tour</h2>
                        <form class="lt-admin-form" action="<?= e(url('/admin/settings')) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
<?php foreach (SettingModel::FIELDS as $name => $field): ?>
<?php
    $id = 'setting-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
    $row = $saved[$name] ?? null;
?>
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="<?= e($id) ?>"><?= e($field['label']) ?> (<?= e($field['unit']) ?>)</label>
                                <input class="lt-admin-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="text" inputmode="<?= $name === 'commission_percent' ? 'decimal' : 'numeric' ?>"
                                       id="<?= e($id) ?>" name="<?= e($name) ?>" value="<?= e($old[$name]) ?>" maxlength="6" autocomplete="off" required
                                       aria-describedby="<?= e($id) ?>-hint<?= $error !== '' ? ' ' . e($id) . '-error' : '' ?>"<?= $error !== '' ? ' aria-invalid="true"' : '' ?><?= $name === $focusField ? ' autofocus' : '' ?>>
                                <p class="lt-admin-hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?> Từ <?= e($field['min']) ?> đến <?= e($field['max']) ?>.<?php if ($row !== null && $row['updated_by_name'] !== null): ?> Sửa lần cuối <?= e(format_datetime((string) $row['updated_at'])) ?> bởi <?= e($row['updated_by_name']) ?>.<?php endif; ?></p>
<?php if ($error !== ''): ?>
                                <p class="lt-admin-error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                            </div>
<?php endforeach; ?>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Lưu thông số</button>
                        </form>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="settings-note-title">
                        <h2 class="lt-panel__title" id="settings-note-title">Phí dịch vụ được tính thế nào</h2>
                        <p class="lt-admin__text">Khách trả đúng giá niêm yết cho LocalTour. Sau khi lịch khởi hành kết thúc, LocalTour giữ lại phí dịch vụ trên tiền thực thu của từng đơn (đã trừ tiền hoàn cho khách) và chi trả phần còn lại cho đơn vị tổ chức.</p>
                        <p class="lt-admin__text">Mức phí được chụp vào đơn lúc khách đặt, nên đổi mức phí không làm đổi các đơn đã có. Xem các khoản phải chi trả ở trang <a href="<?= e(url('/admin/payouts')) ?>">Chi trả đơn vị tổ chức</a>.</p>
<?php if ($payoutsFrom !== null): ?>
                        <p class="lt-admin__text">Chi trả được lập cho các lịch kết thúc từ <?= e(format_datetime($payoutsFrom)) ?> (thời điểm bật tính năng chi trả; không sửa ở đây).</p>
<?php endif; ?>
                    </section>
                </div>
            </div>
        </main>
    </div>
</div>
