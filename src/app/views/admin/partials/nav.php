<?php declare(strict_types=1); ?>
<?php
/*
 * Thanh bên của trang quản trị: cột trái trên desktop, panel thu gọn (nút "Menu" ở header) dưới 992px.
 * Biến: $adminNav = 'dashboard' | 'tours' | 'bookings' (mục đang mở).
 */
$adminNav = $adminNav ?? 'dashboard';
$adminItems = [
    ['key' => 'dashboard', 'href' => '/admin', 'icon' => 'home', 'label' => 'Tổng quan'],
    ['key' => 'tours', 'href' => '/admin/tours', 'icon' => 'verified', 'label' => 'Duyệt tour'],
    ['key' => 'bookings', 'href' => '/admin/bookings', 'icon' => 'calendar', 'label' => 'Yêu cầu đặt tour'],
    ['key' => 'payments', 'href' => '/admin/payments', 'icon' => 'clipboard', 'label' => 'Đối chiếu thanh toán'],
];
?>
<nav id="lt-sidebar" class="collapse lt-sidebar d-lg-block lt-sidebar--column" aria-label="Điều hướng trang quản trị">
    <div class="lt-sidebar__inner">
        <p class="lt-sidebar__heading">Quản trị LocalTour</p>

        <ul class="lt-nav">
<?php foreach ($adminItems as $item): ?>
<?php $isActive = $adminNav === $item['key']; ?>
            <li>
                <a class="lt-nav__link<?= $isActive ? ' is-active' : '' ?>" href="<?= e(url($item['href'])) ?>"<?= $isActive ? ' aria-current="page"' : '' ?>>
                    <span class="lt-icon lt-icon--<?= e($item['icon']) ?>" aria-hidden="true"></span>
                    <span class="lt-nav__label"><?= e($item['label']) ?></span>
                </a>
            </li>
<?php endforeach; ?>
        </ul>

        <div class="lt-sidebar__section">
            <ul class="lt-nav">
                <li>
                    <a class="lt-nav__link" href="<?= e(url('/tours')) ?>">
                        <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                        <span class="lt-nav__label">Về trang khách</span>
                    </a>
                </li>
                <li>
                    <form action="<?= e(url('/admin/logout')) ?>" method="post">
                        <?= csrf_field() ?>
                        <button type="submit" class="lt-nav__link lt-admin-logout">
                            <span class="lt-icon lt-icon--log-out" aria-hidden="true"></span>
                            <span class="lt-nav__label">Đăng xuất</span>
                        </button>
                    </form>
                </li>
            </ul>
        </div>
    </div>
</nav>
