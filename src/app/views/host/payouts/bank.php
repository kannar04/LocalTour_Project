<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: "Tài khoản nhận tiền" (Nguyễn Tuấn Khôi) – đơn vị tự khai tài khoản ngân hàng để LocalTour chuyển
 * khoản các khoản chi trả.
 * Biến: $host (đơn vị đang đăng nhập), $old (bank_name, bank_account_no, bank_account_name đang nhập),
 *       $errors (lỗi theo ô; 'form' = lỗi chung), $success ('' = không có).
 */
use App\Models\PayoutModel;

$fields = [
    ['name' => 'bank_name', 'label' => 'Ngân hàng', 'maxlength' => PayoutModel::BANK_NAME_MAX_LENGTH, 'inputmode' => 'text', 'hint' => 'Tên ngân hàng và chi nhánh nếu cần, ví dụ: Vietcombank - CN Hà Nội.'],
    ['name' => 'bank_account_no', 'label' => 'Số tài khoản', 'maxlength' => 30, 'inputmode' => 'numeric', 'hint' => 'Chỉ gồm chữ số, từ ' . PayoutModel::BANK_NO_MIN_LENGTH . ' đến ' . PayoutModel::BANK_NO_MAX_LENGTH . ' chữ số.'],
    ['name' => 'bank_account_name', 'label' => 'Tên chủ tài khoản', 'maxlength' => PayoutModel::BANK_NAME_MAX_LENGTH, 'inputmode' => 'text', 'hint' => 'Đúng như tên đăng ký tại ngân hàng.'],
];
$isEmpty = $old['bank_name'] === '' && $old['bank_account_no'] === '' && $old['bank_account_name'] === '';
$focusField = array_key_first(array_diff_key($errors, ['form' => true]));
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Tài khoản nhận tiền</h1>
                <p class="lt-admin__subtitle"><?= e($host['business_name']) ?> · LocalTour chuyển các khoản chi trả vào tài khoản này</p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php elseif ($isEmpty): ?>
            <div class="lt-alert lt-alert--warning" role="note"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Đơn vị chưa khai tài khoản nhận tiền. LocalTour chỉ chuyển khoản được sau khi đơn vị khai đủ 3 ô bên dưới.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="bank-form-title">
                        <h2 class="lt-panel__title" id="bank-form-title">Tài khoản ngân hàng</h2>
                        <form class="lt-admin-form" action="<?= e(url('/host/bank')) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
<?php foreach ($fields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'bank-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
?>
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
                                <input class="lt-admin-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="text" inputmode="<?= e($field['inputmode']) ?>"
                                       id="<?= e($id) ?>" name="<?= e($name) ?>" value="<?= e($old[$name]) ?>" maxlength="<?= e($field['maxlength']) ?>" autocomplete="off" required
                                       aria-describedby="<?= e($id) ?>-hint<?= $error !== '' ? ' ' . e($id) . '-error' : '' ?>"<?= $error !== '' ? ' aria-invalid="true"' : '' ?><?= $name === $focusField ? ' autofocus' : '' ?>>
                                <p class="lt-admin-hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php if ($error !== ''): ?>
                                <p class="lt-admin-error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                            </div>
<?php endforeach; ?>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Lưu tài khoản</button>
                        </form>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="bank-note-title">
                        <h2 class="lt-panel__title" id="bank-note-title">Lưu ý</h2>
                        <p class="lt-admin__text">Kiểm tra kỹ số tài khoản và tên chủ tài khoản: LocalTour chuyển khoản theo đúng thông tin đơn vị khai ở đây.</p>
                        <p class="lt-admin__text">Đổi tài khoản chỉ áp dụng cho các khoản chưa chi trả. Khoản đã chi trả giữ nguyên tài khoản đã nhận tiền, xem ở <a href="<?= e(url('/host/payouts')) ?>">Doanh thu &amp; chi trả</a>.</p>
                    </section>
                </div>
            </div>
        </main>
    </div>
</div>
