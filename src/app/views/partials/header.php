<?php declare(strict_types=1); ?>
<?php
/*
 * Header (Nguyễn Tuấn Khôi): logo, ô tìm kiếm (GET /tours?q=), "Thông báo" (sắp có), "Menu".
 * Trên trang danh sách, tour-list.js chặn submit và tải lại kết quả bằng AJAX.
 * "Menu" chỉ hoạt động dưới 992px: mở/đóng thanh bên #lt-sidebar (Bootstrap collapse).
 */
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
            <button type="button" class="lt-header-btn" disabled title="Sắp có" aria-label="Thông báo (sắp có)">
                <span class="lt-icon lt-icon--bell" aria-hidden="true"></span>
                <span class="d-none d-md-inline" aria-hidden="true">Thông báo</span>
                <span class="lt-soon d-none d-xl-inline-flex" aria-hidden="true">Sắp có</span>
            </button>
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
