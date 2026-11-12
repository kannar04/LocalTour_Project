<?php declare(strict_types=1); ?>
<?php
/*
 * Trang "Đăng ký đơn vị tổ chức" (/host/register, Nguyễn Tuấn Khôi), dùng chung style với trang đăng ký khách hàng (auth.css).
 * Biến: $old (business_name, contact_phone, email đã nhập), $errors (lỗi theo ô: business_name, contact_phone, email,
 *       password, password_confirm; 'form' = lỗi chung như hết phiên, captcha), $recaptchaSiteKey ('' = không có captcha).
 * Gửi xong đơn vị ở trạng thái "Chờ duyệt": quản trị viên duyệt ở "Đơn vị tổ chức" rồi đơn vị mới đăng nhập được.
 * Không bao giờ in lại mật khẩu.
 */
$fields = [
    ['name' => 'business_name', 'label' => 'Tên đơn vị', 'type' => 'text', 'maxlength' => 150, 'autocomplete' => 'organization', 'hint' => ''],
    ['name' => 'contact_phone', 'label' => 'Số điện thoại liên hệ', 'type' => 'tel', 'maxlength' => 20, 'autocomplete' => 'tel', 'hint' => ''],
    ['name' => 'email', 'label' => 'Email liên hệ', 'type' => 'email', 'maxlength' => 150, 'autocomplete' => 'email',
        'hint' => 'Dùng để đăng nhập. Email đã có tài khoản khách hàng thì không dùng lại được.'],
    ['name' => 'password', 'label' => 'Mật khẩu', 'type' => 'password', 'maxlength' => 72, 'autocomplete' => 'new-password', 'hint' => 'Tối thiểu 8 ký tự.'],
    ['name' => 'password_confirm', 'label' => 'Nhập lại mật khẩu', 'type' => 'password', 'maxlength' => 72, 'autocomplete' => 'new-password', 'hint' => ''],
];
// Đưa con trỏ vào ô lỗi đầu tiên (hoặc ô đầu tiên khi mới mở trang).
$focusField = array_key_first(array_diff_key($errors, ['form' => true])) ?? 'business_name';
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-auth" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <section class="lt-auth__card" aria-labelledby="host-register-title">
            <h1 class="lt-auth__title" id="host-register-title">Đăng ký đơn vị tổ chức</h1>
            <p class="lt-auth__lead">Đăng ký để đăng tour của đơn vị bạn trên LocalTour. Quản trị viên LocalTour duyệt đơn vị trước, sau đó bạn đăng nhập và đăng tour.</p>

<?php if (isset($errors['form'])): ?>
            <div class="lt-auth__alert" role="alert">
                <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                <span><?= e($errors['form']) ?></span>
            </div>
<?php elseif ($errors !== []): ?>
            <div class="lt-auth__alert" role="alert">
                <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                <span>Vui lòng kiểm tra lại các ô được đánh dấu.</span>
            </div>
<?php endif; ?>

            <form class="lt-auth__form" action="<?= e(url('/host/register')) ?>" method="post" novalidate>
                <?= csrf_field() ?>

<?php foreach ($fields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'host-register-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
    $describedBy = trim(($field['hint'] !== '' ? $id . '-hint ' : '') . ($error !== '' ? $id . '-error' : ''));
    $isPassword = $field['type'] === 'password';
?>
                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
                    <input class="lt-auth__input<?= $error !== '' ? ' is-invalid' : '' ?>" type="<?= e($field['type']) ?>"
                           id="<?= e($id) ?>" name="<?= e($name) ?>" value="<?= $isPassword ? '' : e($old[$name] ?? '') ?>"
                           maxlength="<?= e($field['maxlength']) ?>" autocomplete="<?= e($field['autocomplete']) ?>"
                           required <?= $error !== '' ? 'aria-invalid="true"' : '' ?>
                           <?= $describedBy !== '' ? 'aria-describedby="' . e($describedBy) . '"' : '' ?> <?= $name === $focusField ? 'autofocus' : '' ?>>
<?php if ($field['hint'] !== ''): ?>
                    <p class="lt-auth__hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php endif; ?>
<?php if ($error !== ''): ?>
                    <p class="lt-auth__error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                </div>
<?php endforeach; ?>

<?php require __DIR__ . '/../partials/auth-recaptcha.php'; ?>
                <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Gửi đăng ký</button>
            </form>

            <p class="lt-auth__switch">Đã có tài khoản đơn vị? <a href="<?= e(url('/host/login')) ?>">Đăng nhập đơn vị tổ chức</a></p>
            <p class="lt-auth__switch">Bạn muốn đặt tour? <a href="<?= e(url('/register')) ?>">Đăng ký tài khoản khách hàng</a></p>
        </section>
    </div>
</main>
