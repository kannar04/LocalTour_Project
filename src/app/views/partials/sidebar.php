<?php declare(strict_types=1); ?>
<?php
/*
 * Thanh bên (Nguyễn Tuấn Khôi).
 * $sidebarMode = 'column' (mặc định, trang danh sách): cột trái trên desktop, panel thu gọn trên mobile;
 *                'mobile' (trang chi tiết / không tìm thấy): chỉ là panel thu gọn dưới 992px.
 * Mục: Bảng tin, "Đơn của tôi" (chỉ tài khoản khách hàng) và "So sánh tour" (FR-15, sắp có).
 * Danh sách #sidebar-destinations được JS điền từ /api/destinations
 * (tour-list.js ở chế độ 'column', app.js tải khi mở panel ở chế độ 'mobile').
 */
$sidebarMode = $sidebarMode ?? 'column';
$isColumn = $sidebarMode === 'column';
$isFeedActive = ($activeNav ?? 'feed') === 'feed';
$isBookingsActive = ($activeNav ?? 'feed') === 'bookings';
$isCustomer = (current_user()['role'] ?? '') === 'customer';
$comingSoonItems = [
    ['icon' => 'columns', 'label' => 'So sánh tour'],
];
?>
<?php if (!$isColumn): ?>
<div class="container-xl lt-container d-lg-none">
<?php endif; ?>
<nav id="lt-sidebar"
     class="collapse lt-sidebar <?= $isColumn ? 'd-lg-block lt-sidebar--column' : 'lt-sidebar--mobile' ?>"
     aria-label="Điều hướng LocalTour"
     data-destination-mode="<?= $isColumn ? 'filter' : 'link' ?>">
    <div class="lt-sidebar__inner">
        <p class="lt-sidebar__heading">Khám phá cùng localtour</p>

        <ul class="lt-nav">
            <li>
                <a class="lt-nav__link<?= $isFeedActive ? ' is-active' : '' ?>" href="<?= e(url('/tours')) ?>"<?= ($isColumn && $isFeedActive) ? ' aria-current="page"' : '' ?>>
                    <span class="lt-icon lt-icon--home" aria-hidden="true"></span>
                    <span class="lt-nav__label">Bảng tin</span>
                </a>
            </li>
<?php if ($isCustomer): ?>
            <li>
                <a class="lt-nav__link<?= $isBookingsActive ? ' is-active' : '' ?>" href="<?= e(url('/bookings')) ?>"<?= $isBookingsActive ? ' aria-current="page"' : '' ?>>
                    <span class="lt-icon lt-icon--clipboard" aria-hidden="true"></span>
                    <span class="lt-nav__label">Đơn của tôi</span>
                </a>
            </li>
<?php endif; ?>
<?php foreach ($comingSoonItems as $item): ?>
            <li>
                <button type="button" class="lt-nav__link" disabled title="Sắp có">
                    <span class="lt-icon lt-icon--<?= e($item['icon']) ?>" aria-hidden="true"></span>
                    <span class="lt-nav__label"><?= e($item['label']) ?></span>
                    <span class="lt-soon">Sắp có</span>
                </button>
            </li>
<?php endforeach; ?>
        </ul>

        <div class="lt-sidebar__section">
            <h2 class="lt-sidebar__eyebrow" id="sidebar-destinations-title">Điểm đến</h2>
            <ul class="lt-dest-list" id="sidebar-destinations" aria-labelledby="sidebar-destinations-title">
                <li class="lt-dest-list__status">Đang tải điểm đến…</li>
            </ul>
        </div>

        <div class="lt-sidebar__footer">
            <button type="button" class="lt-linklike" disabled title="Sắp có">Trợ giúp</button>
            <span aria-hidden="true">·</span>
            <button type="button" class="lt-linklike" disabled title="Sắp có">Điều khoản</button>
        </div>
    </div>
</nav>
<?php if (!$isColumn): ?>
</div>
<?php endif; ?>
