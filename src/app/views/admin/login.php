<?php declare(strict_types=1); ?>
<?php
/*
 * Trang "Đăng nhập quản trị" (/admin/login), dùng chung style với trang đăng nhập khách hàng (auth.css).
 * Biến: $next (trang quản trị quay lại sau khi đăng nhập), $email (giữ lại khi nhập sai), $error ('' = không lỗi).
 * Không bao giờ in lại mật khẩu.
 */
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-auth" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <section class="lt-auth__card" aria-labelledby="admin-login-title">
            <h1 class="lt-auth__title" id="admin-login-title">Đăng nhập quản trị</h1>
            <p class="lt-auth__lead">Dành cho tài khoản quản trị viên LocalTour.</p>

<?php if ($error !== ''): ?>
            <div class="lt-auth__alert" role="alert">
                <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                <span><?= e($error) ?></span>
            </div>
<?php endif; ?>

            <form class="lt-auth__form" action="<?= e(url('/admin/login')) ?>" method="post" novalidate>
                <?= csrf_field() ?>
                <input type="hidden" name="next" value="<?= e($next) ?>">

                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="admin-login-email">Email</label>
                    <input class="lt-auth__input" type="email" id="admin-login-email" name="email" value="<?= e($email) ?>"
                           maxlength="150" autocomplete="email" required<?= $email === '' ? ' autofocus' : '' ?>>
                </div>

                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="admin-login-password">Mật khẩu</label>
                    <input class="lt-auth__input" type="password" id="admin-login-password" name="password"
                           maxlength="72" autocomplete="current-password" required<?= $email !== '' ? ' autofocus' : '' ?>>
                </div>

                <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Đăng nhập</button>
            </form>

            <p class="lt-auth__switch">Bạn là khách hàng? <a href="<?= e(url('/login')) ?>">Đăng nhập tài khoản khách hàng</a></p>
        </section>
    </div>
</main>
