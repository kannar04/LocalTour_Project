<?php declare(strict_types=1); ?>
<?php
/*
 * Header (Lê Trung Phong): logo, ô tìm kiếm (GET /tours?q=), tài khoản, "Menu".
 * Chế độ khách: nút "Đăng nhập" (quay lại đúng trang đang xem sau khi đăng nhập) và "Đăng ký".
 * Đã đăng nhập: "Đơn của tôi" (tài khoản khách hàng), tên khách hàng và nút "Đăng xuất" (form POST kèm mã CSRF).
 * Trên trang danh sách, tour-list.js chặn submit và tải lại kết quả bằng AJAX.
 * "Menu" chỉ hoạt động dưới 992px: mở/đóng thanh bên #lt-sidebar (Bootstrap collapse).
 */
$currentUser = current_user();
$requestUri = $_SERVER['REQUEST_URI'] ?? '/';
$currentPath = Core\Router::pathFromUri($requestUri);
$currentQuery = (string) parse_url($requestUri, PHP_URL_QUERY);
// Trên trang đăng nhập / đăng ký không gắn next để không quay vòng về chính trang đó.
$returnPath = in_array($currentPath, ['/login', '/register'], true)
    ? '/tours'
    : safe_next_path($currentPath . ($currentQuery !== '' ? '?' . $currentQuery : ''));
$loginHref = url('/login') . ($returnPath !== '/tours' ? '?next=' . rawurlencode($returnPath) : '');
$registerHref = url('/register') . ($returnPath !== '/tours' ? '?next=' . rawurlencode($returnPath) : '');
$userInitial = $currentUser === null ? '' : mb_strtoupper(mb_substr(trim($currentUser['name']), 0, 1));
?>
<header class="lt-header">
    <div class="container-xl lt-container lt-header__inner">
        <div class="lt-header__brand">
            <a class="lt-brand" href="<?= e(url('/tours')) ?>" aria-label="LocalTour – về bảng tin du lịch">
                <img class="lt-brand__mark" src="<?= e(asset('img/logo-mark.svg')) ?>" alt="" width="30" height="30">
                <span class="lt-brand__text">localtour</span>
            </a>
        </div>

        <form class="lt-search" id="header-search" action="<?= e(url('/tours')) ?>" method="get" role="search">
            <label class="sr-only" for="header-search-input">Tìm điểm đến, tour hoặc người dẫn</label>
            <span class="lt-icon lt-icon--search lt-search__icon" aria-hidden="true"></span>
            <input class="lt-search__input" type="search" id="header-search-input" name="q"
                   value="<?= e($initialQuery ?? '') ?>" maxlength="100" autocomplete="off" enterkeyhint="search"
                   placeholder="Tìm điểm đến, tour hoặc người dẫn...">
            <button class="lt-search__submit" type="submit">Tìm</button>
        </form>

        <div class="lt-header__actions">
<?php if ($currentUser === null): ?>
            <a class="lt-header-btn" href="<?= e($loginHref) ?>" aria-label="Đăng nhập">
                <span class="lt-icon lt-icon--log-in d-sm-none" aria-hidden="true"></span>
                <span class="d-none d-sm-inline" aria-hidden="true">Đăng nhập</span>
            </a>
            <a class="lt-btn lt-btn--primary lt-header-cta d-none d-sm-inline-flex" href="<?= e($registerHref) ?>">Đăng ký</a>
<?php else: ?>
<?php if ($currentUser['role'] === 'customer'): ?>
            <a class="lt-header-btn" href="<?= e(url('/bookings')) ?>" aria-label="Đơn của tôi"<?= str_starts_with($currentPath, '/bookings') ? ' aria-current="page"' : '' ?>>
                <span class="lt-icon lt-icon--clipboard" aria-hidden="true"></span>
                <span class="d-none d-md-inline" aria-hidden="true">Đơn của tôi</span>
            </a>
<?php endif; ?>
            <span class="lt-header-user" title="<?= e($currentUser['email']) ?>">
                <span class="lt-avatar lt-avatar--sm" aria-hidden="true"><?= e($userInitial) ?></span>
                <span class="lt-header-user__name d-none d-md-inline"><span class="sr-only">Đang đăng nhập: </span><?= e($currentUser['name']) ?></span>
            </span>
            <form class="lt-header-logout" action="<?= e(url('/logout')) ?>" method="post">
                <?= csrf_field() ?>
                <button type="submit" class="lt-header-btn" title="Đăng xuất" aria-label="Đăng xuất">
                    <span class="lt-icon lt-icon--log-out" aria-hidden="true"></span>
                </button>
            </form>
<?php endif; ?>
            <button type="button" class="lt-header-btn d-none d-lg-inline-flex" disabled title="Sắp có" aria-label="Menu (sắp có trên máy tính)">
                <span class="lt-icon lt-icon--menu" aria-hidden="true"></span>
                <span aria-hidden="true">Menu</span>
            </button>
            <button type="button" class="lt-header-btn d-lg-none js-menu-toggle"
                    data-toggle="collapse" data-target="#lt-sidebar" aria-controls="lt-sidebar" aria-expanded="false">
                <span class="lt-icon lt-icon--menu" aria-hidden="true"></span>
                <span>Menu</span>
            </button>
        </div>
    </div>
</header>
