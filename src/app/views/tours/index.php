<?php declare(strict_types=1); ?>
<?php
/*
 * Bảng tin du lịch – khung trang danh sách tour (UIEx1, Nguyễn Tuấn Khôi).
 * Không in dữ liệu tour ở đây: tour-list.js tải /api/destinations và /api/tours bằng AJAX.
 * Biến: $title, $initialQuery (string), $initialDestination (int|null).
 */
?>
<div class="container-xl lt-container lt-page" id="tour-list-page"
     data-initial-query="<?= e($initialQuery ?? '') ?>"
     data-initial-destination="<?= e($initialDestination ?? '') ?>">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php $sidebarMode = 'column'; require __DIR__ . '/../partials/sidebar.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-col-feed" tabindex="-1" aria-labelledby="feed-title">
            <header class="lt-feed-head">
                <h1 class="lt-feed-head__title" id="feed-title">Bảng tin du lịch</h1>
                <p class="lt-feed-head__subtitle">Gợi ý tour và câu chuyện từ người địa phương</p>
            </header>

            <div class="lt-filters" role="group" aria-label="Bộ lọc tour">
                <div class="lt-filter lt-filter--select">
                    <span class="lt-icon lt-icon--pin lt-filter__icon" aria-hidden="true"></span>
                    <label class="lt-filter__label" for="filter-destination">Điểm đến:</label>
                    <select class="lt-filter__select" id="filter-destination" name="destination">
                        <option value="">Tất cả</option>
                    </select>
                    <span class="lt-icon lt-icon--chevron-down lt-filter__chevron" aria-hidden="true"></span>
                </div>
                <button type="button" class="lt-filter lt-filter--soon" disabled title="Sắp có">
                    <span class="lt-icon lt-icon--calendar lt-filter__icon" aria-hidden="true"></span>
                    <span class="lt-filter__label">Ngày đi:</span>
                    <span class="lt-filter__value">Chọn ngày</span>
                    <span class="lt-soon">Sắp có</span>
                </button>
                <button type="button" class="lt-filter lt-filter--soon" disabled title="Sắp có">
                    <span class="lt-icon lt-icon--sliders lt-filter__icon" aria-hidden="true"></span>
                    <span class="lt-filter__value">Bộ lọc</span>
                    <span class="lt-soon">Sắp có</span>
                </button>
            </div>

            <div class="lt-sortbar">
                <div class="lt-tabs" role="group" aria-label="Sắp xếp bảng tin">
                    <button type="button" class="lt-tab js-sort-tab is-active" data-sort="recommended" aria-pressed="true">Dành cho bạn</button>
                    <button type="button" class="lt-tab" disabled title="Sắp có">Đang theo dõi <span class="lt-soon">Sắp có</span></button>
                    <button type="button" class="lt-tab js-sort-tab" data-sort="newest" aria-pressed="false">Mới nhất</button>
                </div>
                <div class="lt-sort-price">
                    <label class="lt-sort-price__label" for="sort-price">Giá</label>
                    <select class="lt-sort-price__select" id="sort-price">
                        <option value="">Mặc định</option>
                        <option value="price_asc">Thấp đến cao</option>
                        <option value="price_desc">Cao đến thấp</option>
                    </select>
                </div>
            </div>

            <p class="lt-result-count" id="tour-count" aria-live="polite">Đang tải tour…</p>

            <div class="lt-state-loading" id="tour-loading" role="status">
                <span class="sr-only">Đang tải danh sách tour…</span>
<?php for ($skeleton = 0; $skeleton < 2; $skeleton++): ?>
                <div class="lt-skeleton-card" aria-hidden="true">
                    <div class="lt-skeleton-card__head">
                        <span class="lt-skeleton lt-skeleton--circle"></span>
                        <span class="lt-skeleton-card__lines">
                            <span class="lt-skeleton lt-skeleton--line" style="width: 42%"></span>
                            <span class="lt-skeleton lt-skeleton--line lt-skeleton--thin" style="width: 28%"></span>
                        </span>
                    </div>
                    <span class="lt-skeleton lt-skeleton--title"></span>
                    <span class="lt-skeleton lt-skeleton--line" style="width: 86%"></span>
                    <span class="lt-skeleton lt-skeleton--media"></span>
                    <span class="lt-skeleton lt-skeleton--line" style="width: 54%"></span>
                    <div class="lt-skeleton-card__foot">
                        <span class="lt-skeleton lt-skeleton--line" style="width: 34%"></span>
                        <span class="lt-skeleton lt-skeleton--button"></span>
                    </div>
                </div>
<?php endfor; ?>
            </div>

            <div class="lt-feed" id="tour-feed" hidden></div>

            <div class="lt-state" id="tour-empty" hidden>
                <span class="lt-state__icon" aria-hidden="true"><span class="lt-icon lt-icon--compass"></span></span>
                <h2 class="lt-state__title">Không có tour phù hợp</h2>
                <p class="lt-state__text" id="tour-empty-text">Thử từ khóa khác hoặc chọn điểm đến khác nhé.</p>
                <button type="button" class="lt-btn lt-btn--primary" id="tour-clear-filters">
                    <span class="lt-icon lt-icon--x" aria-hidden="true"></span>
                    Xóa bộ lọc
                </button>
            </div>

            <div class="lt-state lt-state--error" id="tour-error" role="alert" hidden>
                <span class="lt-state__icon" aria-hidden="true"><span class="lt-icon lt-icon--alert"></span></span>
                <h2 class="lt-state__title">Không tải được danh sách tour</h2>
                <p class="lt-state__text" id="tour-error-message">Máy chủ đang bận hoặc mất kết nối. Vui lòng thử lại sau ít phút.</p>
                <button type="button" class="lt-btn lt-btn--primary" id="tour-retry">
                    <span class="lt-icon lt-icon--refresh" aria-hidden="true"></span>
                    Thử lại
                </button>
            </div>

            <noscript>
                <div class="lt-state">
                    <h2 class="lt-state__title">Cần bật JavaScript</h2>
                    <p class="lt-state__text">Bảng tin tải danh sách tour bằng JavaScript. Hãy bật JavaScript rồi tải lại trang.</p>
                </div>
            </noscript>
        </main>

        <aside class="col-12 lt-col-aside d-none d-lg-block" aria-label="So sánh và gợi ý">
            <div class="lt-aside-sticky">
                <section class="lt-panel lt-compare" aria-labelledby="compare-title">
                    <div class="lt-panel__head">
                        <h2 class="lt-panel__title" id="compare-title">Tour đang so sánh</h2>
                        <span class="lt-soon">Sắp có</span>
                    </div>
                    <p class="lt-panel__text">Tính năng so sánh sẽ có ở Sprint sau</p>
                    <ol class="lt-compare__slots" aria-hidden="true">
<?php for ($slot = 1; $slot <= 3; $slot++): ?>
                        <li class="lt-compare__slot">
                            <span class="lt-compare__num"><?= $slot ?></span>
                            <span class="lt-compare__hint"><?= $slot === 1 ? 'Bấm “Thêm vào so sánh” trên thẻ tour' : 'Ô so sánh trống' ?></span>
                        </li>
<?php endfor; ?>
                    </ol>
                    <button type="button" class="lt-btn lt-btn--primary lt-btn--block" disabled title="Sắp có">
                        <span class="lt-icon lt-icon--columns" aria-hidden="true"></span>
                        So sánh tour
                    </button>
                    <p class="lt-panel__note">Tối đa 3 tour cùng điểm đến.</p>
                </section>

                <section class="lt-panel lt-tips" aria-labelledby="tips-title">
                    <h2 class="lt-panel__title" id="tips-title">Gợi ý từ cộng đồng</h2>
                    <ul class="lt-tips__list">
                        <li class="lt-tip">
                            <span class="lt-tip__icon" aria-hidden="true"><span class="lt-icon lt-icon--bulb"></span></span>
                            <div>
                                <p class="lt-tip__title">Lần đầu đến Hà Nội?</p>
                                <p class="lt-tip__text">Xem kinh nghiệm chọn tour đi bộ.</p>
                            </div>
                        </li>
                        <li class="lt-tip">
                            <span class="lt-tip__icon" aria-hidden="true"><span class="lt-icon lt-icon--pin"></span></span>
                            <div>
                                <p class="lt-tip__title">Chọn tour phù hợp</p>
                                <p class="lt-tip__text">Kiểm tra điểm đón và các khoản phí.</p>
                            </div>
                        </li>
                        <li class="lt-tip">
                            <span class="lt-tip__icon" aria-hidden="true"><span class="lt-icon lt-icon--users"></span></span>
                            <div>
                                <p class="lt-tip__title">Đi theo nhóm nhỏ</p>
                                <p class="lt-tip__text">Nhóm dưới 8 khách dễ trò chuyện với người dẫn hơn.</p>
                            </div>
                        </li>
                    </ul>
                    <p class="lt-panel__note">Gợi ý minh họa, chưa lấy từ cộng đồng thật.</p>
                </section>
            </div>
        </aside>
    </div>
</div>
