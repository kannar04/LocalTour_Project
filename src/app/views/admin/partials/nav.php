<?php declare(strict_types=1); ?>
<?php
/*
 * Thanh bên của trang quản trị: cột trái trên desktop, panel thu gọn (nút "Menu" ở header) dưới 992px.
 * Biến: $adminNav = 'dashboard' | 'tours' | 'providers' | 'bookings' | 'change-requests' | 'payments' | 'payouts' |
 *       'settings' (mục đang mở).
 * Khu đơn vị tổ chức (/host): $host = đơn vị đang đăng nhập → chỉ có "Tour của tôi", "Thêm tour", "Đơn đặt tour",
 * "Doanh thu & chi trả" và "Tài khoản nhận tiền" ($adminNav = 'tours' | 'tour-new' | 'bookings' | 'payouts' | 'bank'),
 * đăng xuất ở /host/logout.
 */
$adminNav = $adminNav ?? 'dashboard';
$navHost = $host ?? null;
$adminItems = [
    ['key' => 'dashboard', 'href' => '/admin', 'icon' => 'home', 'label' => 'Tổng quan'],
    ['key' => 'tours', 'href' => '/admin/tours', 'icon' => 'verified', 'label' => 'Duyệt tour'],
    ['key' => 'providers', 'href' => '/admin/providers', 'icon' => 'user', 'label' => 'Đơn vị tổ chức'],
    ['key' => 'bookings', 'href' => '/admin/bookings', 'icon' => 'calendar', 'label' => 'Đơn đặt tour'],
    ['key' => 'change-requests', 'href' => '/admin/change-requests', 'icon' => 'message', 'label' => 'Đổi ngày / hủy tour'],
    ['key' => 'payments', 'href' => '/admin/payments', 'icon' => 'clipboard', 'label' => 'Đối chiếu thanh toán'],
    ['key' => 'payouts', 'href' => '/admin/payouts', 'icon' => 'share', 'label' => 'Chi trả đơn vị tổ chức'],
    ['key' => 'settings', 'href' => '/admin/settings', 'icon' => 'sliders', 'label' => 'Thông số vận hành'],
];
if ($navHost !== null) {
    $adminItems = [
        ['key' => 'tours', 'href' => '/host/tours', 'icon' => 'verified', 'label' => 'Tour của tôi'],
        ['key' => 'tour-new', 'href' => '/host/tours/new', 'icon' => 'plus', 'label' => 'Thêm tour'],
        ['key' => 'bookings', 'href' => '/host/bookings', 'icon' => 'calendar', 'label' => 'Đơn đặt tour'],
        ['key' => 'payouts', 'href' => '/host/payouts', 'icon' => 'clipboard', 'label' => 'Doanh thu & chi trả'],
        ['key' => 'bank', 'href' => '/host/bank', 'icon' => 'shield', 'label' => 'Tài khoản nhận tiền'],
    ];
}
?>
<nav id="lt-sidebar" class="collapse lt-sidebar d-lg-block lt-sidebar--column" aria-label="<?= $navHost !== null ? 'Điều hướng khu đơn vị tổ chức' : 'Điều hướng trang quản trị' ?>">
    <div class="lt-sidebar__inner">
        <p class="lt-sidebar__heading"><?= $navHost !== null ? e($navHost['business_name']) : 'Quản trị LocalTour' ?></p>

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
                    <form action="<?= e(url($navHost !== null ? '/host/logout' : '/admin/logout')) ?>" method="post">
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
