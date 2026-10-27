<?php declare(strict_types=1); ?>
<?php
/*
 * Trang đăng nhập tài khoản khách hàng (Nguyễn Tuấn Khôi).
 * Biến: $next (đường dẫn quay lại sau khi đăng nhập), $email (giữ lại khi nhập sai), $error ('' = không lỗi).
 * Không bao giờ in lại mật khẩu. Khách có thể bỏ qua và tiếp tục xem tour ở chế độ khách.
 */
$registerHref = url('/register') . ($next !== '/tours' ? '?next=' . rawurlencode($next) : '');
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-auth" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <section class="lt-auth__card" aria-labelledby="login-title">
            <h1 class="lt-auth__title" id="login-title">Đăng nhập</h1>
            <p class="lt-auth__lead">Đăng nhập tài khoản khách hàng để đặt tour.</p>

<?php if ($error !== ''): ?>
            <div class="lt-auth__alert" role="alert">
                <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                <span><?= e($error) ?></span>
            </div>
<?php endif; ?>

            <form class="lt-auth__form" action="<?= e(url('/login')) ?>" method="post" novalidate>
                <?= csrf_field() ?>
                <input type="hidden" name="next" value="<?= e($next) ?>">

                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="login-email">Email</label>
                    <input class="lt-auth__input" type="email" id="login-email" name="email" value="<?= e($email) ?>"
                           maxlength="150" autocomplete="email" required<?= $email === '' ? ' autofocus' : '' ?>>
                </div>

                <div class="lt-auth__field">
                    <label class="lt-auth__label" for="login-password">Mật khẩu</label>
                    <input class="lt-auth__input" type="password" id="login-password" name="password"
                           maxlength="72" autocomplete="current-password" required<?= $email !== '' ? ' autofocus' : '' ?>>
                </div>

                <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Đăng nhập</button>
            </form>

            <p class="lt-auth__switch">Chưa có tài khoản? <a href="<?= e($registerHref) ?>">Đăng ký</a></p>

            <div class="lt-auth__guest">
                <p class="lt-auth__divider"><span>hoặc</span></p>
                <a class="lt-btn lt-btn--soft lt-btn--block" href="<?= e(url($next)) ?>">Tiếp tục với tư cách khách</a>
                <p class="lt-auth__note">Ở chế độ khách, bạn vẫn xem được danh sách và chi tiết tour nhưng chưa đặt tour được.</p>
            </div>
        </section>
    </div>
</main>
