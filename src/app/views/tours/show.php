<?php declare(strict_types=1); ?>
<?php
/*
 * Chi tiết tour (UIEx2, Nguyễn Tuấn Khôi) – render phía server, tour-detail.js chỉ xử lý thẻ giá và tab neo.
 * Biến: $tour (NMT_sp_tour_detail), $schedules, $itinerary, $images, $inclusions, $reviews, $title.
 */
$listUrl = url('/tours');
$ratingText = format_rating($tour['rating_avg'] === null ? null : (string) $tour['rating_avg']);
$reviewCount = (int) $tour['review_count'];
$priceText = format_vnd((int) $tour['price_per_person']);
$maxGroup = (int) $tour['max_group_size'];
$hasSchedules = !empty($schedules);
$providerName = (string) $tour['provider_name'];
$providerInitial = mb_strtoupper(mb_substr($providerName, 0, 1));
$isVerified = !empty($tour['provider_verified']);

$galleryFallbacks = ['Ảnh chính của tour', 'Ảnh trải nghiệm', 'Ảnh hành trình'];

$includedItems = [];
$excludedItems = [];
foreach ($inclusions as $inclusion) {
    if ((int) $inclusion['is_included'] === 1) {
        $includedItems[] = (string) $inclusion['item_text'];
    } else {
        $excludedItems[] = (string) $inclusion['item_text'];
    }
}

$sections = [
    'tong-quan' => 'Tổng quan',
    'lich-trinh' => 'Lịch trình',
    'bao-gom' => 'Bao gồm',
    'diem-don' => 'Điểm đón',
    'danh-gia' => 'Đánh giá',
];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e($listUrl) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item"><a href="<?= e(url('/tours?destination=' . (int) $tour['destination_id'])) ?>"><?= e($tour['destination_name']) ?></a></li>
                <li class="breadcrumb-item active"><?= e($tour['category_name']) ?></li>
            </ol>
        </nav>

        <div class="lt-detail-head">
            <div class="lt-detail-head__main">
                <h1 class="lt-detail-head__title"><?= e($tour['title']) ?></h1>
                <ul class="lt-detail-meta">
                    <li class="lt-detail-meta__item lt-detail-meta__item--rating">
                        <span class="lt-icon lt-icon--star" aria-hidden="true"></span>
<?php if ($ratingText !== null): ?>
                        <span><strong><?= e($ratingText) ?>/5</strong> (<?= e($reviewCount) ?> đánh giá)</span>
<?php else: ?>
                        <span>Chưa có đánh giá</span>
<?php endif; ?>
                    </li>
                    <li class="lt-detail-meta__item">
                        <span class="lt-icon lt-icon--pin" aria-hidden="true"></span>
                        <span><?= e($tour['destination_name']) ?></span>
                    </li>
                    <li class="lt-detail-meta__item">
                        <span>Tổ chức bởi <strong><?= e($providerName) ?></strong></span>
<?php if ($isVerified): ?>
                        <span class="lt-verified" title="Nhà tổ chức đã xác minh">
                            <span class="lt-icon lt-icon--verified" aria-hidden="true"></span>
                            <span class="sr-only">Đã xác minh</span>
                        </span>
<?php endif; ?>
                    </li>
                </ul>
            </div>
            <div class="lt-detail-head__actions">
                <button type="button" class="lt-btn lt-btn--soft" disabled title="Sắp có">
                    <span class="lt-icon lt-icon--bookmark" aria-hidden="true"></span>
                    Lưu tour
                </button>
                <button type="button" class="lt-btn lt-btn--light" disabled title="Sắp có">
                    <span class="lt-icon lt-icon--share" aria-hidden="true"></span>
                    Chia sẻ
                </button>
                <span class="lt-soon">Sắp có</span>
            </div>
        </div>

        <div class="lt-gallery">
<?php foreach ([0, 1, 2] as $slot): ?>
<?php
    $image = $images[$slot] ?? null;
    $imageUrl = $image === null ? null : tour_image_url($image['image_path'] === null ? null : (string) $image['image_path']);
    $caption = $image === null ? $galleryFallbacks[$slot] : (string) $image['caption'];
?>
            <figure class="lt-gallery__item<?= $slot === 0 ? ' lt-gallery__item--main' : '' ?>">
<?php if ($imageUrl !== null): ?>
                <img src="<?= e($imageUrl) ?>" alt="<?= e($caption) ?>" width="1280" height="720"<?= $slot === 0 ? '' : ' loading="lazy"' ?> decoding="async">
<?php else: ?>
                <div class="lt-media-placeholder" role="img" aria-label="<?= e($caption) ?>">
                    <span class="lt-icon lt-icon--image" aria-hidden="true"></span>
                </div>
<?php endif; ?>
                <figcaption class="lt-gallery__caption" aria-hidden="true"><?= e($caption) ?></figcaption>
            </figure>
<?php endforeach; ?>
        </div>

        <div class="row lt-detail-body">
            <div class="col-12 col-lg-7 col-xl-8 lt-detail-content">
                <div class="lt-detail-card">
                <nav class="lt-anchor-tabs js-detail-tabs" aria-label="Mục trong trang">
                    <ul class="lt-anchor-tabs__list">
<?php foreach ($sections as $sectionId => $sectionLabel): ?>
                        <li><a class="lt-anchor-tab<?= $sectionId === 'tong-quan' ? ' is-active' : '' ?>" href="#<?= e($sectionId) ?>"<?= $sectionId === 'tong-quan' ? ' aria-current="true"' : '' ?>><?= e($sectionLabel) ?></a></li>
<?php endforeach; ?>
                    </ul>
                </nav>

                <section class="lt-section" id="tong-quan" tabindex="-1" aria-labelledby="tong-quan-title">
                    <h2 class="lt-section__title" id="tong-quan-title">Tổng quan</h2>
                    <p class="lt-section__lead"><?= e($tour['summary']) ?></p>
                    <div class="lt-prose"><?= nl2br(e($tour['description']), false) ?></div>
                    <ul class="lt-facts">
                        <li class="lt-chip"><span class="lt-icon lt-icon--clock" aria-hidden="true"></span><?= e(format_duration((string) $tour['duration_hours'])) ?></li>
                        <li class="lt-chip"><span class="lt-icon lt-icon--users" aria-hidden="true"></span>Nhóm tối đa <?= e($maxGroup) ?> khách</li>
                        <li class="lt-chip"><span class="lt-icon lt-icon--globe" aria-hidden="true"></span><?= e($tour['languages']) ?></li>
                        <li class="lt-chip"><span class="lt-icon lt-icon--tag" aria-hidden="true"></span><?= e($tour['category_name']) ?></li>
                    </ul>
                </section>

                <section class="lt-section" id="lich-trinh" tabindex="-1" aria-labelledby="lich-trinh-title">
                    <h2 class="lt-section__title" id="lich-trinh-title">Lịch trình</h2>
<?php if (empty($itinerary)): ?>
                    <p class="lt-empty-note">Lịch trình chi tiết đang được cập nhật.</p>
<?php else: ?>
                    <ol class="lt-timeline">
<?php foreach ($itinerary as $step): ?>
                        <li class="lt-timeline__item">
                            <span class="lt-timeline__time"><?= $step['start_time'] === null ? '—' : e(format_time((string) $step['start_time'])) ?></span>
                            <span class="lt-timeline__text"><?= e($step['description']) ?></span>
                        </li>
<?php endforeach; ?>
                    </ol>
<?php endif; ?>
                </section>

                <section class="lt-section" id="bao-gom" tabindex="-1" aria-labelledby="bao-gom-title">
                    <h2 class="lt-section__title" id="bao-gom-title">Chi phí bao gồm</h2>
                    <div class="row lt-inclusions">
                        <div class="col-12 col-sm-6">
                            <h3 class="lt-subheading">Đã bao gồm</h3>
<?php if (empty($includedItems)): ?>
                            <p class="lt-empty-note">Chưa có thông tin.</p>
<?php else: ?>
                            <ul class="lt-checklist">
<?php foreach ($includedItems as $itemText): ?>
                                <li class="lt-checklist__item"><span class="lt-checklist__mark" aria-hidden="true"><span class="lt-icon lt-icon--check"></span></span><?= e($itemText) ?></li>
<?php endforeach; ?>
                            </ul>
<?php endif; ?>
                        </div>
                        <div class="col-12 col-sm-6">
                            <h3 class="lt-subheading">Không gồm</h3>
<?php if (empty($excludedItems)): ?>
                            <p class="lt-empty-note">Không có khoản phát sinh được ghi nhận.</p>
<?php else: ?>
                            <ul class="lt-checklist lt-checklist--excluded">
<?php foreach ($excludedItems as $itemText): ?>
                                <li class="lt-checklist__item"><span class="lt-checklist__mark" aria-hidden="true"><span class="lt-icon lt-icon--x"></span></span><?= e($itemText) ?></li>
<?php endforeach; ?>
                            </ul>
<?php endif; ?>
                        </div>
                    </div>
                </section>

                <section class="lt-section" id="diem-don" tabindex="-1" aria-labelledby="diem-don-title">
                    <h2 class="lt-section__title" id="diem-don-title">Điểm đón</h2>
                    <div class="lt-meeting">
                        <div class="lt-meeting__row">
                            <span class="lt-meeting__icon" aria-hidden="true"><span class="lt-icon lt-icon--pin"></span></span>
                            <div>
                                <p class="lt-meeting__label">Điểm hẹn</p>
                                <p class="lt-meeting__value"><?= e($tour['meeting_point']) ?></p>
<?php if (!empty($tour['meeting_note'])): ?>
                                <p class="lt-meeting__note"><?= e($tour['meeting_note']) ?></p>
<?php endif; ?>
                            </div>
                        </div>
<?php if (!empty($tour['transport_note'])): ?>
                        <div class="lt-meeting__row">
                            <span class="lt-meeting__icon" aria-hidden="true"><span class="lt-icon lt-icon--navigation"></span></span>
                            <div>
                                <p class="lt-meeting__label">Di chuyển</p>
                                <p class="lt-meeting__value"><?= e($tour['transport_note']) ?></p>
                            </div>
                        </div>
<?php endif; ?>
                    </div>
                </section>

                <section class="lt-section" id="danh-gia" tabindex="-1" aria-labelledby="danh-gia-title">
                    <h2 class="lt-section__title" id="danh-gia-title">Đánh giá của khách</h2>
<?php if ($ratingText !== null && $reviewCount > 0): ?>
                    <div class="lt-review-summary">
                        <span class="lt-review-summary__score"><?= e($ratingText) ?></span>
                        <div>
                            <span class="lt-stars" style="--lt-rating: <?= e((float) $tour['rating_avg']) ?>" role="img" aria-label="<?= e($ratingText) ?> trên 5 sao"></span>
                            <p class="lt-review-summary__meta"><?= e($reviewCount) ?> đánh giá · Sắp xếp: Mới nhất</p>
                        </div>
                    </div>
<?php endif; ?>
<?php if (empty($reviews)): ?>
                    <div class="lt-empty-card">
                        <span class="lt-empty-card__icon" aria-hidden="true"><span class="lt-icon lt-icon--message"></span></span>
                        <div>
                            <p class="lt-empty-card__title">Chưa có đánh giá</p>
                            <p class="lt-empty-card__text">Tour này chưa có đánh giá nào. Đánh giá sẽ hiển thị sau khi khách tham gia tour.</p>
                        </div>
                    </div>
<?php else: ?>
                    <ul class="lt-reviews">
<?php foreach ($reviews as $review): ?>
                        <li class="lt-review">
                            <div class="lt-review__head">
                                <span class="lt-avatar lt-avatar--sm" aria-hidden="true"><?= e(mb_strtoupper(mb_substr((string) $review['reviewer_name'], 0, 1))) ?></span>
                                <div class="lt-review__who">
                                    <p class="lt-review__name"><?= e($review['reviewer_name']) ?></p>
                                    <p class="lt-review__meta">
                                        <span class="lt-stars lt-stars--sm" style="--lt-rating: <?= e((int) $review['rating']) ?>" role="img" aria-label="<?= e((int) $review['rating']) ?> trên 5 sao"></span>
                                        <span><?= e((int) $review['rating']) ?>/5 · <?= e(format_date(substr((string) $review['created_at'], 0, 10))) ?> · Đã tham gia tour (minh họa)</span>
                                    </p>
                                </div>
                            </div>
                            <p class="lt-review__text">“<?= e($review['comment']) ?>”</p>
                        </li>
<?php endforeach; ?>
                    </ul>
<?php if ($reviewCount > count($reviews)): ?>
                    <p class="lt-empty-note">Đang hiển thị <?= e(count($reviews)) ?> đánh giá mới nhất trên tổng số <?= e($reviewCount) ?>.</p>
<?php endif; ?>
<?php endif; ?>
                </section>
                </div>

                <section class="lt-provider" aria-labelledby="provider-title">
                    <span class="lt-avatar lt-avatar--lg" aria-hidden="true"><?= e($providerInitial) ?></span>
                    <div class="lt-provider__body">
                        <p class="lt-provider__eyebrow">Tổ chức bởi</p>
                        <h2 class="lt-provider__name" id="provider-title">
                            <?= e($providerName) ?>
<?php if ($isVerified): ?>
                            <span class="lt-provider__badge"><span class="lt-icon lt-icon--verified" aria-hidden="true"></span>Đã xác minh</span>
<?php endif; ?>
                        </h2>
<?php if (!empty($tour['provider_description'])): ?>
                        <p class="lt-provider__desc"><?= e($tour['provider_description']) ?></p>
<?php endif; ?>
                    </div>
                    <button type="button" class="lt-btn lt-btn--light lt-provider__action" disabled title="Sắp có">
                        <span class="lt-icon lt-icon--message" aria-hidden="true"></span>
                        Nhắn tin
                        <span class="lt-soon">Sắp có</span>
                    </button>
                </section>
            </div>

            <div class="col-12 col-lg-5 col-xl-4 lt-detail-aside">
                <aside class="lt-booking" id="booking-card" aria-labelledby="booking-title"
                       data-price="<?= e((int) $tour['price_per_person']) ?>"
                       data-max-group="<?= e($maxGroup) ?>">
                    <h2 class="sr-only" id="booking-title">Chọn lịch và giá</h2>
                    <p class="lt-booking__price">
                        <span class="lt-booking__amount"><?= e($priceText) ?></span>
                        <span class="lt-booking__unit">/ người</span>
                    </p>
                    <p class="lt-booking__note"><?= e(!empty($tour['price_note']) ? $tour['price_note'] : 'Giá minh họa · VND') ?></p>

                    <form class="lt-booking__form" id="booking-form" action="#" novalidate>
                        <div class="lt-field">
                            <label class="lt-field__label" for="booking-schedule">Ngày tham gia</label>
<?php if ($hasSchedules): ?>
                            <select class="lt-input lt-select" id="booking-schedule" name="schedule_id">
<?php foreach ($schedules as $schedule): ?>
                                <option value="<?= e((int) $schedule['schedule_id']) ?>"
                                        data-start-time="<?= e(format_time((string) $schedule['start_time'])) ?>"
                                        data-seats-left="<?= e((int) $schedule['seats_left']) ?>"><?= e(format_date((string) $schedule['departure_date'])) ?> · còn <?= e((int) $schedule['seats_left']) ?> chỗ</option>
<?php endforeach; ?>
                            </select>
<?php else: ?>
                            <select class="lt-input lt-select" id="booking-schedule" name="schedule_id" disabled aria-describedby="booking-no-schedule">
                                <option value="">Chưa có lịch khởi hành sắp tới</option>
                            </select>
                            <p class="lt-booking__alert" id="booking-no-schedule">
                                <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                                Chưa có lịch khởi hành sắp tới. Vui lòng quay lại sau.
                            </p>
<?php endif; ?>
                        </div>

                        <div class="lt-field">
                            <label class="lt-field__label" for="booking-guests">Số khách</label>
                            <div class="lt-stepper">
                                <button type="button" class="lt-stepper__btn" id="booking-guests-dec" aria-controls="booking-guests" aria-label="Bớt 1 khách"<?= $hasSchedules ? '' : ' disabled' ?>>
                                    <span class="lt-icon lt-icon--minus" aria-hidden="true"></span>
                                </button>
                                <input class="lt-input lt-stepper__input" type="number" id="booking-guests" name="guests"
                                       value="1" min="1" max="<?= e($maxGroup) ?>" step="1" inputmode="numeric"
                                       aria-describedby="booking-guests-hint"<?= $hasSchedules ? '' : ' disabled' ?>>
                                <button type="button" class="lt-stepper__btn" id="booking-guests-inc" aria-controls="booking-guests" aria-label="Thêm 1 khách"<?= $hasSchedules ? '' : ' disabled' ?>>
                                    <span class="lt-icon lt-icon--plus" aria-hidden="true"></span>
                                </button>
                            </div>
                            <p class="lt-field__hint" id="booking-guests-hint">Nhóm tối đa <?= e($maxGroup) ?> khách</p>
                        </div>

                        <div class="lt-field">
                            <label class="lt-field__label" for="booking-start-time">Giờ bắt đầu</label>
                            <input class="lt-input" type="text" id="booking-start-time" readonly
                                   value="<?= $hasSchedules ? e(format_time((string) $schedules[0]['start_time'])) : '—' ?>"<?= $hasSchedules ? '' : ' disabled' ?>>
                        </div>

                        <div class="lt-booking__total">
                            <span class="lt-booking__total-label">Tạm tính</span>
                            <output class="lt-booking__total-value" id="booking-total" for="booking-schedule booking-guests" aria-live="polite">
<?php if ($hasSchedules): ?>
                                <span class="js-total-formula">1 khách × <?= e($priceText) ?></span> = <strong class="js-total-amount"><?= e($priceText) ?></strong>
<?php else: ?>
                                <span class="js-total-formula">Chưa thể tính</span>
<?php endif; ?>
                            </output>
                        </div>

                        <div class="lt-booking__actions">
                            <button type="button" class="lt-btn lt-btn--primary lt-btn--block" disabled title="Sắp có">
                                Đặt tour <span class="lt-soon">Sắp có</span>
                            </button>
                            <button type="button" class="lt-btn lt-btn--soft lt-btn--block" disabled title="Sắp có">
                                <span class="lt-icon lt-icon--columns" aria-hidden="true"></span>
                                Thêm vào so sánh <span class="lt-soon">Sắp có</span>
                            </button>
                        </div>
                    </form>

                    <div class="lt-booking__policy">
                        <span class="lt-icon lt-icon--shield" aria-hidden="true"></span>
                        <div>
                            <p><?= e($tour['cancellation_policy']) ?></p>
                            <p class="lt-booking__policy-note">Chính sách minh họa · Kiểm tra trước khi đặt</p>
                        </div>
                    </div>

                    <a class="lt-btn lt-btn--outline lt-btn--block" href="<?= e($listUrl) ?>">
                        <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                        Quay lại danh sách
                    </a>
                </aside>
            </div>
        </div>
    </div>

    <div class="lt-mobile-cta d-lg-none">
        <p class="lt-mobile-cta__price"><strong><?= e($priceText) ?></strong> / người</p>
        <a class="lt-btn lt-btn--primary js-scroll-link" href="#booking-card">Chọn lịch</a>
    </div>
</main>
