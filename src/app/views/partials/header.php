<?php declare(strict_types=1); ?>
<?php
/*
 * Header (Lê Trung Phong): logo, ô tìm kiếm (GET /tours?q=), tài khoản, "Menu".
 * Chế độ khách: nút "Đăng nhập" (quay lại đúng trang đang xem sau khi đăng nhập) và "Đăng ký".
 * Đã đăng nhập: "Đơn của tôi" (tài khoản khách hàng), tên khách hàng và nút "Đăng xuất" (form POST kèm mã CSRF).
 * Trên trang danh sách, tour-list.js chặn submit và tải lại kết quả bằng AJAX.
 * "Menu" dưới 992px: mở/đóng thanh bên #lt-sidebar (Bootstrap collapse).
 * CR2 (Nguyễn Tuấn Khôi):
 *   - Nút "Menu" trên máy tính (.js-menu-desktop, app.js): trang có cột trái ($sidebarMode 'column', bảng tin) thì
 *     ẩn/hiện cột để nội dung rộng hơn (nhớ trong localStorage); trang khác mở ngăn menu nổi. Trang không có thanh
 *     bên (chưa gọi partials/sidebar.php) thì không có nút này. View chạy trước layout nên $sidebarMode đã có ở đây.
 *   - Ảnh đại diện: session có avatar_url (đường dẫn trong public/assets/uploads/avatars/) thì hiện ảnh, không thì
 *     chữ cái đầu tên; ảnh lỗi thì app.js đổi về chữ cái. Tài khoản khách hàng: bấm tên / ảnh để mở /tai-khoan.
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
// Chỉ nhận đường dẫn tương đối trong uploads/avatars/ (tên file do AccountController đặt).
$avatarPath = trim((string) ($currentUser['avatar_url'] ?? ''));
$avatarPath = preg_match('~^uploads/avatars/[A-Za-z0-9][A-Za-z0-9._-]*$~', $avatarPath) === 1 && !str_contains($avatarPath, '..')
    ? $avatarPath
    : '';
$isCustomerUser = ($currentUser['role'] ?? '') === 'customer';
$isAccountPage = $currentPath === '/tai-khoan' || str_starts_with($currentPath, '/tai-khoan/');
// null = trang không có thanh bên; 'column' = cột trái (bảng tin); 'drawer' = ngăn menu nổi trên máy tính.
$desktopMenuMode = isset($sidebarMode) ? ($sidebarMode === 'column' ? 'column' : 'drawer') : null;
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
<?php elseif ($currentUser['role'] === 'provider'): ?>
            <a class="lt-header-btn" href="<?= e(url('/host/tours')) ?>" aria-label="Tour của tôi"<?= str_starts_with($currentPath, '/host') ? ' aria-current="page"' : '' ?>>
                <span class="lt-icon lt-icon--verified" aria-hidden="true"></span>
                <span class="d-none d-md-inline" aria-hidden="true">Tour của tôi</span>
            </a>
<?php endif; ?>
<?php if ($isCustomerUser): ?>
            <a class="lt-header-user lt-header-user--link" href="<?= e(url('/tai-khoan')) ?>" title="Tài khoản · <?= e($currentUser['email']) ?>"<?= $isAccountPage ? ' aria-current="page"' : '' ?>>
<?php else: ?>
            <span class="lt-header-user" title="<?= e($currentUser['email']) ?>">
<?php endif; ?>
<?php if ($avatarPath !== ''): ?>
                <img class="lt-avatar lt-avatar--sm lt-avatar--img js-avatar-img" src="<?= e(asset($avatarPath)) ?>" alt="" width="34" height="34" data-initial="<?= e($userInitial) ?>">
<?php else: ?>
                <span class="lt-avatar lt-avatar--sm" aria-hidden="true"><?= e($userInitial) ?></span>
<?php endif; ?>
<?php if ($isCustomerUser): ?>
                <span class="sr-only d-md-none">Tài khoản của <?= e($currentUser['name']) ?></span>
                <span class="lt-header-user__name d-none d-md-inline"><span class="sr-only">Tài khoản: </span><?= e($currentUser['name']) ?></span>
            </a>
<?php else: ?>
                <span class="lt-header-user__name d-none d-md-inline"><span class="sr-only">Đang đăng nhập: </span><?= e($currentUser['name']) ?></span>
            </span>
<?php endif; ?>
            <form class="lt-header-logout" action="<?= e(url('/logout')) ?>" method="post">
                <?= csrf_field() ?>
                <button type="submit" class="lt-header-btn" title="Đăng xuất" aria-label="Đăng xuất">
                    <span class="lt-icon lt-icon--log-out" aria-hidden="true"></span>
                </button>
            </form>
<?php endif; ?>
<?php if ($desktopMenuMode !== null): ?>
            <button type="button" class="lt-header-btn d-none d-lg-inline-flex js-menu-desktop"
                    data-menu-mode="<?= e($desktopMenuMode) ?>" aria-controls="lt-sidebar"
                    aria-expanded="<?= $desktopMenuMode === 'column' ? 'true' : 'false' ?>"
                    aria-label="Menu" title="<?= $desktopMenuMode === 'column' ? 'Ẩn / hiện menu bên trái' : 'Mở menu' ?>">
                <span class="lt-icon lt-icon--menu" aria-hidden="true"></span>
                <span class="d-none d-xl-inline" aria-hidden="true">Menu</span>
            </button>
<?php endif; ?>
            <button type="button" class="lt-header-btn d-lg-none js-menu-toggle"
                    data-toggle="collapse" data-target="#lt-sidebar" aria-controls="lt-sidebar" aria-expanded="false">
                <span class="lt-icon lt-icon--menu" aria-hidden="true"></span>
                <span>Menu</span>
            </button>
        </div>
    </div>
</header>
