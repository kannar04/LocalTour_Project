<?php declare(strict_types=1); ?>
<?php
/*
 * "Tour đã lưu" (CR2 – Nguyễn Minh Thức): các tour tài khoản khách hàng đã bấm "Lưu", lưu gần nhất trước.
 * Biến: $tours (TourSocialController::presentSaved()), $title.
 * Nút "Bỏ lưu" (.js-saved-remove) do tour-social.js gửi POST /api/tours/{id}/save (saved=0) rồi gỡ thẻ.
 * Tour đã ngừng hiển thị vẫn nằm trong danh sách (mờ, không có link) để khách bỏ lưu.
 */
$total = count($tours);
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-saved" tabindex="-1" aria-labelledby="saved-title">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/tours')) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item active" aria-current="page">Tour đã lưu</li>
            </ol>
        </nav>

        <header class="lt-saved-head">
            <div>
                <h1 class="lt-saved-head__title" id="saved-title">Tour đã lưu</h1>
                <p class="lt-saved-head__lead">Các tour bạn bấm "Lưu" trên bảng tin hoặc trang chi tiết tour.</p>
            </div>
            <p class="lt-saved-head__count" id="saved-count" aria-live="polite"<?= $total === 0 ? ' hidden' : '' ?>><?= e($total) ?> tour</p>
        </header>

        <div class="lt-empty-card lt-saved-empty" id="saved-empty"<?= $total > 0 ? ' hidden' : '' ?>>
            <span class="lt-empty-card__icon" aria-hidden="true"><span class="lt-icon lt-icon--bookmark"></span></span>
            <div>
                <p class="lt-empty-card__title">Chưa có tour nào được lưu</p>
                <p class="lt-empty-card__text">Bấm "Lưu" trên một tour để xem lại sau ở đây.</p>
                <a class="lt-btn lt-btn--primary lt-saved-empty__cta" href="<?= e(url('/tours')) ?>">Khám phá tour</a>
            </div>
        </div>

<?php if ($total > 0): ?>
        <ul class="lt-saved-grid" id="saved-list">
<?php foreach ($tours as $index => $tour): ?>
<?php $titleId = 'saved-title-' . $index; ?>
            <li class="lt-saved-card js-saved-card<?= $tour['is_visible'] ? '' : ' lt-saved-card--hidden' ?>" data-tour-id="<?= e($tour['tour_id']) ?>">
                <div class="lt-saved-card__media">
<?php if ($tour['cover_url'] !== null): ?>
                    <img src="<?= e($tour['cover_url']) ?>" alt="<?= e($tour['cover_alt']) ?>" width="640" height="360" loading="lazy" decoding="async">
<?php else: ?>
                    <div class="lt-media-placeholder lt-saved-card__placeholder">
                        <span class="lt-icon lt-icon--image" aria-hidden="true"></span>
                        <span>Chưa cập nhật ảnh</span>
                    </div>
<?php endif; ?>
                </div>
                <div class="lt-saved-card__body">
<?php if ($tour['place_text'] !== ''): ?>
                    <p class="lt-saved-card__place"><?= e($tour['place_text']) ?></p>
<?php endif; ?>
                    <h2 class="lt-saved-card__title" id="<?= e($titleId) ?>">
<?php if ($tour['is_visible']): ?>
                        <a class="lt-saved-card__link" href="<?= e($tour['url']) ?>"><?= e($tour['title']) ?></a>
<?php else: ?>
                        <?= e($tour['title']) ?>
<?php endif; ?>
                    </h2>
                    <p class="lt-saved-card__provider">Tổ chức bởi <?= e($tour['provider_name']) ?></p>
<?php if ($tour['is_visible']): ?>
                    <ul class="lt-saved-card__meta">
                        <li>
                            <span class="lt-icon lt-icon--star lt-saved-card__star" aria-hidden="true"></span>
<?php if ($tour['rating_text'] !== null): ?>
                            <span><strong><?= e($tour['rating_text']) ?>/5</strong> (<?= e($tour['review_count']) ?> đánh giá)</span>
<?php else: ?>
                            <span>Chưa có đánh giá</span>
<?php endif; ?>
                        </li>
                        <li>
                            <span class="lt-icon lt-icon--clock" aria-hidden="true"></span>
                            <span><?= e($tour['duration_text']) ?></span>
                        </li>
                        <li>
                            <span class="lt-icon lt-icon--calendar" aria-hidden="true"></span>
                            <span><?= e($tour['next_departure_text'] !== null ? 'Khởi hành ' . $tour['next_departure_text'] : 'Chưa có lịch khởi hành sắp tới') ?></span>
                        </li>
                    </ul>
<?php else: ?>
                    <p class="lt-saved-card__notice">
                        <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                        <span>Tour này hiện không còn hiển thị trên LocalTour.</span>
                    </p>
<?php endif; ?>
                    <p class="lt-saved-card__saved">Đã lưu ngày <?= e($tour['saved_text']) ?></p>
                </div>
                <div class="lt-saved-card__foot">
<?php if ($tour['is_visible'] && $tour['price_text'] !== null): ?>
                    <p class="lt-saved-card__price">Từ <strong class="lt-saved-card__amount"><?= e($tour['price_text']) ?></strong> / người lớn</p>
<?php elseif ($tour['is_visible']): ?>
                    <p class="lt-saved-card__price lt-saved-card__price--none">Giá: Chưa cập nhật</p>
<?php else: ?>
                    <span></span>
<?php endif; ?>
                    <div class="lt-saved-card__actions">
                        <button type="button" class="lt-btn lt-btn--outline lt-saved-card__remove js-saved-remove"
                                data-tour-id="<?= e($tour['tour_id']) ?>" aria-describedby="<?= e($titleId) ?>">
                            <span class="lt-icon lt-icon--bookmark" aria-hidden="true"></span>
                            <span>Bỏ lưu</span>
                        </button>
<?php if ($tour['is_visible']): ?>
                        <a class="lt-btn lt-btn--primary" href="<?= e($tour['url']) ?>" aria-describedby="<?= e($titleId) ?>">Xem chi tiết</a>
<?php endif; ?>
                    </div>
                </div>
            </li>
<?php endforeach; ?>
        </ul>
<?php endif; ?>
    </div>
</main>
