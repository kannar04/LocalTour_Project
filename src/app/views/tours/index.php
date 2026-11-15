<?php declare(strict_types=1); ?>
<?php
/*
 * Bảng tin du lịch – khung trang danh sách tour (UIEx1, Nguyễn Tuấn Khôi).
 * Không in dữ liệu tour ở đây: tour-list.js tải /api/destinations, /api/categories và /api/tours bằng AJAX.
 * Biến: $title, $initialQuery (string), $initialDestinationId, $initialCategoryId (UUID, '' = tất cả).
 * Ngày đi + Bộ lọc nâng cao (CR3, Lê Trung Phong): $dateMin, $dateMax (Y-m-d), $durationOptions, $languageOptions
 * (mã → nhãn; ngôn ngữ đang có tour), $allLanguages (mọi mã hợp lệ), $priceMax. Giá trị đang lọc nằm trên URL,
 * tour-list.js đọc và điền vào các ô.
 */
?>
<div class="container-xl lt-container lt-page" id="tour-list-page"
     data-initial-query="<?= e($initialQuery ?? '') ?>"
     data-initial-destination-id="<?= e($initialDestinationId ?? '') ?>"
     data-initial-category-id="<?= e($initialCategoryId ?? '') ?>"
     data-date-min="<?= e($dateMin) ?>" data-date-max="<?= e($dateMax) ?>"
     data-price-max="<?= e($priceMax) ?>">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php $sidebarMode = 'column'; require __DIR__ . '/../partials/sidebar.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-col-feed" tabindex="-1" aria-labelledby="feed-title">
            <header class="lt-feed-head">
                <h1 class="lt-feed-head__title" id="feed-title">Bảng tin du lịch</h1>
                <p class="lt-feed-head__subtitle">Tìm tour địa phương theo điểm đến, lịch khởi hành và giá</p>
            </header>

            <div class="lt-filters" role="group" aria-label="Bộ lọc tour">
                <div class="lt-filter lt-filter--select">
                    <span class="lt-icon lt-icon--pin lt-filter__icon" aria-hidden="true"></span>
                    <label class="lt-filter__label" for="filter-destination">Điểm đến:</label>
                    <select class="lt-filter__select" id="filter-destination" name="destination_id">
                        <option value="">Tất cả</option>
                    </select>
                    <span class="lt-icon lt-icon--chevron-down lt-filter__chevron" aria-hidden="true"></span>
                </div>
                <div class="lt-filter lt-filter--select">
                    <span class="lt-icon lt-icon--compass lt-filter__icon" aria-hidden="true"></span>
                    <label class="lt-filter__label" for="filter-category">Loại hình:</label>
                    <select class="lt-filter__select" id="filter-category" name="category_id">
                        <option value="">Tất cả</option>
                    </select>
                    <span class="lt-icon lt-icon--chevron-down lt-filter__chevron" aria-hidden="true"></span>
                </div>
                <div class="lt-filter lt-filter--date">
                    <span class="lt-icon lt-icon--calendar lt-filter__icon" aria-hidden="true"></span>
                    <label class="lt-filter__label" for="filter-date">Ngày đi:</label>
                    <input type="date" class="lt-filter__date" id="filter-date" name="date"
                           min="<?= e($dateMin) ?>" max="<?= e($dateMax) ?>" aria-describedby="filter-date-hint">
                    <span class="sr-only" id="filter-date-hint">Chỉ hiện tour có lịch khởi hành trong ngày đã chọn.</span>
                    <button type="button" class="lt-filter__clear" id="filter-date-clear" aria-label="Bỏ chọn ngày đi" hidden>
                        <span class="lt-icon lt-icon--x" aria-hidden="true"></span>
                    </button>
                </div>
                <button type="button" class="lt-filter lt-filter--toggle" id="filter-more-toggle"
                        aria-expanded="false" aria-controls="filter-panel">
                    <span class="lt-icon lt-icon--sliders lt-filter__icon" aria-hidden="true"></span>
                    <span class="lt-filter__value">Bộ lọc</span>
                    <span class="lt-filter__badge" id="filter-more-count" hidden></span>
                </button>
            </div>

            <form class="lt-filter-panel" id="filter-panel" aria-labelledby="filter-panel-title" novalidate hidden>
                <div class="lt-filter-panel__head">
                    <h2 class="lt-filter-panel__title" id="filter-panel-title">Bộ lọc</h2>
                    <button type="button" class="lt-filter-panel__close" id="filter-panel-close" aria-label="Đóng bộ lọc">
                        <span class="lt-icon lt-icon--x" aria-hidden="true"></span>
                    </button>
                </div>

                <div class="lt-filter-panel__grid">
                    <fieldset class="lt-filter-group lt-filter-group--price">
                        <legend class="lt-filter-group__title">Giá vé người lớn</legend>
                        <div class="lt-chip-row">
                            <button type="button" class="lt-chip js-price-preset" data-min="" data-max="500000" aria-pressed="false">Đến 500.000đ</button>
                            <button type="button" class="lt-chip js-price-preset" data-min="500000" data-max="800000" aria-pressed="false">500.000đ – 800.000đ</button>
                            <button type="button" class="lt-chip js-price-preset" data-min="800000" data-max="" aria-pressed="false">Từ 800.000đ</button>
                        </div>
                        <div class="lt-price-range">
                            <label class="lt-price-range__field" for="filter-price-min">
                                <span class="lt-price-range__label">Từ</span>
                                <span class="lt-money-input">
                                    <input type="text" class="lt-money-input__control" id="filter-price-min" inputmode="numeric"
                                           autocomplete="off" maxlength="11" placeholder="0">
                                    <span class="lt-money-input__unit" aria-hidden="true">đ</span>
                                </span>
                            </label>
                            <span class="lt-price-range__dash" aria-hidden="true">–</span>
                            <label class="lt-price-range__field" for="filter-price-max">
                                <span class="lt-price-range__label">Đến</span>
                                <span class="lt-money-input">
                                    <input type="text" class="lt-money-input__control" id="filter-price-max" inputmode="numeric"
                                           autocomplete="off" maxlength="11" placeholder="Không giới hạn">
                                    <span class="lt-money-input__unit" aria-hidden="true">đ</span>
                                </span>
                            </label>
                        </div>
                        <p class="lt-filter-group__hint">Theo giá “Từ” trên thẻ tour. Tour chưa cập nhật giá không hiện khi lọc theo giá.</p>
                    </fieldset>

                    <fieldset class="lt-filter-group">
                        <legend class="lt-filter-group__title">Thời lượng</legend>
                        <div class="lt-chip-row">
                            <label class="lt-chip lt-chip--radio">
                                <input type="radio" class="lt-chip__input" name="duration" value="" checked>
                                <span>Tất cả</span>
                            </label>
<?php foreach ($durationOptions as $durationCode => $durationLabel): ?>
                            <label class="lt-chip lt-chip--radio">
                                <input type="radio" class="lt-chip__input" name="duration" value="<?= e($durationCode) ?>">
                                <span><?= e($durationLabel) ?></span>
                            </label>
<?php endforeach; ?>
                        </div>
                    </fieldset>

                    <div class="lt-filter-group">
                        <label class="lt-filter-group__title" for="filter-language">Ngôn ngữ hướng dẫn</label>
                        <div class="lt-select-box">
                            <select class="lt-select-box__control" id="filter-language"
                                    data-all-languages="<?= e(json_encode($allLanguages, JSON_UNESCAPED_UNICODE)) ?>">
                                <option value="">Tất cả</option>
<?php foreach ($languageOptions as $languageCode => $languageLabel): ?>
                                <option value="<?= e($languageCode) ?>"><?= e($languageLabel) ?></option>
<?php endforeach; ?>
                            </select>
                            <span class="lt-icon lt-icon--chevron-down lt-select-box__chevron" aria-hidden="true"></span>
                        </div>
                    </div>

                    <fieldset class="lt-filter-group">
                        <legend class="lt-filter-group__title">Điểm đón</legend>
                        <label class="lt-check" for="filter-hotel-pickup">
                            <input type="checkbox" class="lt-check__input" id="filter-hotel-pickup">
                            <span>Có đón tại khách sạn</span>
                        </label>
                    </fieldset>
                </div>

                <p class="lt-filter-panel__error" id="filter-panel-error" role="alert" hidden></p>

                <div class="lt-filter-panel__foot">
                    <button type="button" class="lt-btn lt-btn--outline" id="filter-panel-reset">
                        <span class="lt-icon lt-icon--x" aria-hidden="true"></span>
                        Xóa bộ lọc
                    </button>
                    <button type="submit" class="lt-btn lt-btn--primary">
                        <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
                        Áp dụng
                    </button>
                </div>
            </form>

            <div class="lt-sortbar">
                <div class="lt-tabs" role="group" aria-label="Sắp xếp bảng tin">
                    <button type="button" class="lt-tab js-sort-tab is-active" data-sort="recommended" aria-pressed="true">Nổi bật</button>
                    <button type="button" class="lt-tab js-sort-tab" data-sort="upcoming" aria-pressed="false">Sắp khởi hành</button>
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
                <p class="lt-state__text" id="tour-empty-text">Thử bỏ bớt bộ lọc, chọn ngày khác hoặc đổi từ khóa nhé.</p>
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

        <aside class="col-12 lt-col-aside d-none d-lg-block" aria-label="So sánh tour">
            <div class="lt-aside-sticky">
                <section class="lt-panel lt-compare" id="compare-panel" aria-labelledby="compare-title">
                    <div class="lt-panel__head">
                        <h2 class="lt-panel__title" id="compare-title">Tour đang so sánh</h2>
                        <span class="lt-compare__count js-compare-count">0/3 tour</span>
                    </div>
                    <p class="lt-panel__text">Chọn tối đa 3 tour để xem giá, lịch trình và chính sách cạnh nhau.</p>
                    <ol class="lt-compare__slots js-compare-slots" aria-label="Các tour đã chọn">
<?php for ($slot = 1; $slot <= 3; $slot++): ?>
                        <li class="lt-compare__slot">
                            <span class="lt-compare__num"><?= $slot ?></span>
                            <span class="lt-compare__hint"><?= $slot === 1 ? 'Bấm “Thêm vào so sánh” trên thẻ tour' : 'Ô so sánh trống' ?></span>
                        </li>
<?php endfor; ?>
                    </ol>
                    <a class="lt-btn lt-btn--primary lt-btn--block js-compare-go is-disabled" href="<?= e(url('/compare')) ?>" aria-disabled="true">
                        <span class="lt-icon lt-icon--columns" aria-hidden="true"></span>
                        So sánh tour
                    </a>
                    <p class="lt-panel__note js-compare-note">Chọn 2–3 tour để so sánh.</p>
                    <button type="button" class="lt-linklike js-compare-clear" hidden>Xóa danh sách</button>
                </section>
            </div>
        </aside>
    </div>
</div>

<div class="lt-compare-bar d-lg-none" id="compare-bar" hidden>
    <p class="lt-compare-bar__text js-compare-bar-text">0/3 tour đang so sánh</p>
    <a class="lt-btn lt-btn--primary js-compare-go is-disabled" href="<?= e(url('/compare')) ?>" aria-disabled="true">
        <span class="lt-icon lt-icon--columns" aria-hidden="true"></span>
        So sánh
    </a>
</div>
