<?php declare(strict_types=1); ?>
<?php
/*
 * Thanh bên (Nguyễn Tuấn Khôi).
 * $sidebarMode = 'column' (mặc định, trang danh sách): cột trái trên desktop, panel thu gọn trên mobile;
 *                'mobile' (trang chi tiết / không tìm thấy): chỉ là panel thu gọn dưới 992px.
 * Mục: Bảng tin, "Đơn của tôi" (chỉ tài khoản khách hàng), "So sánh tour" (FR-15, Sprint 5: compare.js gắn
 * các tour đã chọn vào link .js-compare-link) và "Bản đồ" (/ban-do, điểm khởi hành của các tour).
 * Danh sách #sidebar-destinations được JS điền từ /api/destinations
 * (tour-list.js ở chế độ 'column', app.js tải khi mở panel ở chế độ 'mobile').
 */
$sidebarMode = $sidebarMode ?? 'column';
$isColumn = $sidebarMode === 'column';
$isFeedActive = ($activeNav ?? 'feed') === 'feed';
$isBookingsActive = ($activeNav ?? 'feed') === 'bookings';
$isCompareActive = ($activeNav ?? 'feed') === 'compare';
$isMapActive = ($activeNav ?? 'feed') === 'map';
$isCustomer = (current_user()['role'] ?? '') === 'customer';
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
            <li>
                <a class="lt-nav__link js-compare-link<?= $isCompareActive ? ' is-active' : '' ?>" href="<?= e(url('/compare')) ?>"<?= $isCompareActive ? ' aria-current="page"' : '' ?>>
                    <span class="lt-icon lt-icon--columns" aria-hidden="true"></span>
                    <span class="lt-nav__label">So sánh tour</span>
                </a>
            </li>
            <li>
                <a class="lt-nav__link<?= $isMapActive ? ' is-active' : '' ?>" href="<?= e(url('/ban-do')) ?>"<?= $isMapActive ? ' aria-current="page"' : '' ?>>
                    <span class="lt-icon lt-icon--map" aria-hidden="true"></span>
                    <span class="lt-nav__label">Bản đồ</span>
                </a>
            </li>
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
