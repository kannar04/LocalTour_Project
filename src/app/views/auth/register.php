<?php declare(strict_types=1); ?>
<?php
/*
 * Trang đăng ký tài khoản khách hàng (Nguyễn Tuấn Khôi).
 * Biến: $next, $old (name, email, phone đã nhập), $errors (lỗi theo ô: name, email, phone, password,
 *       password_confirm; 'form' = lỗi chung như hết phiên). Không bao giờ in lại mật khẩu.
 */
$loginHref = url('/login') . ($next !== '/tours' ? '?next=' . rawurlencode($next) : '');
$fields = [
    ['name' => 'name', 'label' => 'Họ tên', 'type' => 'text', 'maxlength' => 100, 'autocomplete' => 'name', 'required' => true, 'hint' => ''],
    ['name' => 'email', 'label' => 'Email', 'type' => 'email', 'maxlength' => 150, 'autocomplete' => 'email', 'required' => true, 'hint' => ''],
    ['name' => 'phone', 'label' => 'Số điện thoại (không bắt buộc)', 'type' => 'tel', 'maxlength' => 20, 'autocomplete' => 'tel', 'required' => false, 'hint' => ''],
    ['name' => 'password', 'label' => 'Mật khẩu', 'type' => 'password', 'maxlength' => 72, 'autocomplete' => 'new-password', 'required' => true, 'hint' => 'Tối thiểu 8 ký tự.'],
    ['name' => 'password_confirm', 'label' => 'Nhập lại mật khẩu', 'type' => 'password', 'maxlength' => 72, 'autocomplete' => 'new-password', 'required' => true, 'hint' => ''],
];
// Đưa con trỏ vào ô lỗi đầu tiên (hoặc ô đầu tiên khi mới mở trang).
$focusField = array_key_first(array_diff_key($errors, ['form' => true])) ?? 'name';
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-auth" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <section class="lt-auth__card" aria-labelledby="register-title">
            <h1 class="lt-auth__title" id="register-title">Đăng ký tài khoản</h1>
            <p class="lt-auth__lead">Tạo tài khoản khách hàng để đặt tour và xem lại đơn của bạn.</p>

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

            <form class="lt-auth__form" action="<?= e(url('/register')) ?>" method="post" novalidate>
                <?= csrf_field() ?>
                <input type="hidden" name="next" value="<?= e($next) ?>">

<?php foreach ($fields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'register-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
    $describedBy = trim(($field['hint'] !== '' ? $id . '-hint ' : '') . ($error !== '' ? $id . '-error' : ''));
    $isPassword = $field['type'] === 'password';
?>
                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
                    <input class="lt-auth__input<?= $error !== '' ? ' is-invalid' : '' ?>" type="<?= e($field['type']) ?>"
                           id="<?= e($id) ?>" name="<?= e($name) ?>" value="<?= $isPassword ? '' : e($old[$name] ?? '') ?>"
                           maxlength="<?= e($field['maxlength']) ?>" autocomplete="<?= e($field['autocomplete']) ?>"
                           <?= $field['required'] ? 'required' : '' ?> <?= $error !== '' ? 'aria-invalid="true"' : '' ?>
                           <?= $describedBy !== '' ? 'aria-describedby="' . e($describedBy) . '"' : '' ?> <?= $name === $focusField ? 'autofocus' : '' ?>>
<?php if ($field['hint'] !== ''): ?>
                    <p class="lt-auth__hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php endif; ?>
<?php if ($error !== ''): ?>
                    <p class="lt-auth__error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                </div>
<?php endforeach; ?>

                <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Tạo tài khoản</button>
            </form>

            <p class="lt-auth__switch">Đã có tài khoản? <a href="<?= e($loginHref) ?>">Đăng nhập</a></p>

            <div class="lt-auth__guest">
                <p class="lt-auth__divider"><span>hoặc</span></p>
                <a class="lt-btn lt-btn--soft lt-btn--block" href="<?= e(url($next)) ?>">Tiếp tục với tư cách khách</a>
            </div>
        </section>
    </div>
</main>
