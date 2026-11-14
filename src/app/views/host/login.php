<?php declare(strict_types=1); ?>
<?php
/*
 * Trang "Đăng nhập đơn vị tổ chức" (/host/login, Nguyễn Tuấn Khôi), dùng chung style với các trang đăng nhập khác (auth.css).
 * Biến: $next (trang khu /host quay lại sau khi đăng nhập), $email (giữ lại khi nhập sai), $error ('' = không lỗi),
 *       $recaptchaSiteKey ('' = không có captcha).
 * Không bao giờ in lại mật khẩu. Đơn vị không tự đăng ký: quản trị viên thêm đơn vị rồi cấp mật khẩu.
 */
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-auth" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <section class="lt-auth__card" aria-labelledby="host-login-title">
            <h1 class="lt-auth__title" id="host-login-title">Đăng nhập đơn vị tổ chức</h1>
            <p class="lt-auth__lead">Dành cho đơn vị tổ chức tour đang hợp tác với LocalTour: đăng tour, lịch khởi hành và giá vé của đơn vị.</p>

<?php if ($error !== ''): ?>
            <div class="lt-auth__alert" role="alert">
                <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                <span><?= e($error) ?></span>
            </div>
<?php endif; ?>

            <form class="lt-auth__form" action="<?= e(url('/host/login')) ?>" method="post" novalidate>
                <?= csrf_field() ?>
                <input type="hidden" name="next" value="<?= e($next) ?>">

                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="host-login-email">Email liên hệ của đơn vị</label>
                    <input class="lt-auth__input" type="email" id="host-login-email" name="email" value="<?= e($email) ?>"
                           maxlength="150" autocomplete="email" required<?= $email === '' ? ' autofocus' : '' ?>>
                </div>

                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="host-login-password">Mật khẩu</label>
                    <input class="lt-auth__input" type="password" id="host-login-password" name="password"
                           maxlength="72" autocomplete="current-password" required<?= $email !== '' ? ' autofocus' : '' ?>>
                </div>

<?php require __DIR__ . '/../partials/auth-recaptcha.php'; ?>
                <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Đăng nhập</button>
            </form>

            <p class="lt-auth__switch">Chưa có tài khoản đơn vị? Liên hệ quản trị viên LocalTour để được cấp tài khoản.</p>
            <p class="lt-auth__switch">Bạn là khách hàng? <a href="<?= e(url('/login')) ?>">Đăng nhập tài khoản khách hàng</a></p>
        </section>
    </div>
</main>
