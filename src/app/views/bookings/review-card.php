<?php declare(strict_types=1); ?>
<?php
/*
 * Thẻ "Đánh giá tour" trên trang chi tiết đơn (FR-16, CR2 – Nguyễn Tuấn Khôi), require từ bookings/show.php.
 * Biến: $review (NTK_sp_review_get: đơn + đánh giá, cột đánh giá NULL khi chưa có), $reviewFlash
 *       (ReviewController::pullFlash: type, message, errors, old; null = không có), $code, $isPublic, $tourUrl.
 * Đơn đã xác nhận (chuyến đi sắp tới): một dòng nhắc. Đơn chờ xác nhận / chờ thanh toán / bị từ chối / đã hủy: không hiện.
 * Đơn đã hoàn thành: chưa đánh giá → form; chờ duyệt → nội dung + "Sửa đánh giá"; đã đăng → nội dung + link trang tour;
 * không được duyệt → lý do + form gửi lại. booking-review.js tô sao đã chọn và đếm ký tự (không có JS form vẫn gửi được).
 */
use App\Models\ReviewModel;

$reviewBookingStatus = (string) ($review['booking_status'] ?? '');
if (($review ?? null) === null || !in_array($reviewBookingStatus, ['confirmed', 'completed'], true)) {
    return;
}

$reviewStatus = $review['review_id'] !== null ? (string) $review['moderation_status'] : null;
$reviewErrors = $reviewFlash['errors'] ?? [];
$reviewOld = $reviewFlash['old'] ?? [];
$oldRating = (string) ($reviewOld['rating'] ?? ($review['rating'] ?? ''));
$oldContent = (string) ($reviewOld['content'] ?? ($review['content'] ?? ''));
$ratingError = (string) ($reviewErrors['rating'] ?? '');
$contentError = (string) ($reviewErrors['content'] ?? '');
$reviewRating = (int) ($review['rating'] ?? 0);
$reviewContent = (string) ($review['content'] ?? '');
$reviewNote = trim((string) ($review['moderation_note'] ?? ''));
$formOpen = $reviewErrors !== [] || ($reviewFlash !== null && $reviewFlash['type'] === 'error' && $reviewOld !== []);
$showForm = (int) ($review['can_review'] ?? 0) === 1;
$submitLabel = match ($reviewStatus) {
    'pending' => 'Lưu thay đổi',
    'rejected' => 'Gửi lại đánh giá',
    default => 'Gửi đánh giá',
};
$statusClass = match ($reviewStatus) {
    'approved' => 'completed',
    'rejected' => 'rejected',
    default => 'pending',
};
?>
                <section class="lt-book-card lt-review-card" id="danh-gia-tour" tabindex="-1" aria-labelledby="order-review-title">
                    <h2 class="lt-book-card__title" id="order-review-title">Đánh giá tour</h2>

<?php if ($reviewFlash !== null && $reviewFlash['message'] !== ''): ?>
<?php if ($reviewFlash['type'] === 'success'): ?>
                    <div class="lt-book-success lt-review-card__notice" role="status">
                        <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
                        <div><p><?= e($reviewFlash['message']) ?></p></div>
                    </div>
<?php else: ?>
                    <div class="lt-book-alert lt-review-card__notice" role="alert">
                        <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                        <span><?= e($reviewFlash['message']) ?></span>
                    </div>
<?php endif; ?>
<?php endif; ?>

<?php if ($reviewBookingStatus !== 'completed'): ?>
                    <p class="lt-field__hint mb-0">Bạn có thể chấm điểm và nhận xét tour sau khi chuyến đi hoàn thành.</p>
<?php else: ?>
<?php if ($reviewStatus === null): ?>
                    <p class="lt-book-card__lead">Chuyến đi thế nào? Chấm điểm và viết vài dòng để giúp khách khác chọn tour.</p>
<?php else: ?>
                    <div class="lt-review-mine">
                        <div class="lt-review-mine__head">
                            <span class="lt-review-stars" style="--lt-rating: <?= e($reviewRating) ?>" role="img" aria-label="<?= e($reviewRating) ?> trên 5 sao"></span>
                            <span class="lt-review-mine__score"><?= e($reviewRating) ?>/5</span>
                            <span class="lt-status lt-status--<?= e($statusClass) ?>"><?= e(ReviewModel::STATUS_LABELS[$reviewStatus] ?? $reviewStatus) ?></span>
                        </div>
                        <p class="lt-review-mine__text"><?= nl2br(e($reviewContent), false) ?></p>
                        <p class="lt-field__hint mb-0">Gửi lúc <?= e(format_datetime($review['created_at'] === null ? null : (string) $review['created_at'])) ?></p>
                    </div>
<?php if ($reviewStatus === 'pending'): ?>
                    <p class="lt-review-card__state">Đánh giá đang chờ LocalTour duyệt. Bạn vẫn sửa được trước khi đánh giá được đăng.</p>
<?php elseif ($reviewStatus === 'approved'): ?>
                    <p class="lt-review-card__state">Đánh giá đã hiện trên trang tour. Đánh giá đã đăng không sửa được nữa.</p>
<?php if ($isPublic): ?>
                    <a class="lt-btn lt-btn--outline lt-book-state__action" href="<?= e($tourUrl . '#danh-gia') ?>">Xem trên trang tour</a>
<?php endif; ?>
<?php else: ?>
                    <p class="lt-review-card__state lt-review-card__state--rejected"><strong>LocalTour chưa đăng đánh giá này.</strong> Lý do: <?= e($reviewNote !== '' ? $reviewNote : 'LocalTour chưa ghi lý do.') ?></p>
                    <p class="lt-field__hint">Sửa nội dung rồi gửi lại, đánh giá sẽ được duyệt lại.</p>
<?php endif; ?>
<?php endif; ?>

<?php if ($showForm): ?>
<?php if ($reviewStatus === 'pending'): ?>
                    <details class="lt-review-edit"<?= $formOpen ? ' open' : '' ?>>
                        <summary class="lt-btn lt-btn--outline lt-btn--sm">Sửa đánh giá</summary>
<?php endif; ?>
                    <form class="lt-book-form lt-review-form" action="<?= e(url('/bookings/' . $code . '/review')) ?>" method="post">
                        <?= csrf_field() ?>
                        <fieldset class="lt-field lt-star-picker" aria-describedby="review-rating-word<?= $ratingError !== '' ? ' review-rating-error' : '' ?>">
                            <legend class="lt-field__label">Chấm điểm</legend>
                            <div class="lt-star-picker__options js-star-picker">
<?php for ($star = ReviewModel::RATING_MIN; $star <= ReviewModel::RATING_MAX; $star++): ?>
                                <input class="lt-star-picker__input" type="radio" id="review-rating-<?= e($star) ?>" name="rating" value="<?= e($star) ?>"
                                       <?= $oldRating === (string) $star ? 'checked ' : '' ?>required<?= $ratingError !== '' ? ' aria-invalid="true"' : '' ?>>
                                <label class="lt-star-picker__label<?= $oldRating !== '' && $star <= (int) $oldRating ? ' is-lit' : '' ?>" for="review-rating-<?= e($star) ?>" data-word="<?= e(ReviewModel::RATING_WORDS[$star]) ?>">
                                    <span class="lt-star-picker__star" aria-hidden="true"></span>
                                    <span class="lt-star-picker__text"><?= e($star) ?> sao</span>
                                </label>
<?php endfor; ?>
                            </div>
                            <p class="lt-field__hint js-star-word" id="review-rating-word"><?= e(isset(ReviewModel::RATING_WORDS[(int) $oldRating]) ? (int) $oldRating . ' sao · ' . ReviewModel::RATING_WORDS[(int) $oldRating] : 'Chọn từ 1 đến 5 sao.') ?></p>
<?php if ($ratingError !== ''): ?>
                            <p class="lt-field__error" id="review-rating-error"><?= e($ratingError) ?></p>
<?php endif; ?>
                        </fieldset>

                        <div class="lt-field">
                            <label class="lt-field__label" for="review-content">Nhận xét</label>
                            <textarea class="lt-input lt-textarea js-review-content<?= $contentError !== '' ? ' is-invalid' : '' ?>" id="review-content" name="content" rows="5"
                                      minlength="<?= e(ReviewModel::CONTENT_MIN_LENGTH) ?>" maxlength="<?= e(ReviewModel::CONTENT_MAX_LENGTH) ?>" required
                                      aria-describedby="review-content-hint review-content-count<?= $contentError !== '' ? ' review-content-error' : '' ?>"<?= $contentError !== '' ? ' aria-invalid="true"' : '' ?>><?= e($oldContent) ?></textarea>
                            <p class="lt-field__hint" id="review-content-hint">Từ <?= e(ReviewModel::CONTENT_MIN_LENGTH) ?> đến <?= e(ReviewModel::CONTENT_MAX_LENGTH) ?> ký tự. Kể trải nghiệm thật của bạn, không ghi số điện thoại hay thông tin cá nhân.</p>
                            <p class="lt-field__hint lt-field__count js-review-count" id="review-content-count"><?= e(mb_strlen($oldContent)) ?>/<?= e(ReviewModel::CONTENT_MAX_LENGTH) ?> ký tự</p>
<?php if ($contentError !== ''): ?>
                            <p class="lt-field__error" id="review-content-error"><?= e($contentError) ?></p>
<?php endif; ?>
                        </div>

                        <div class="lt-book-actions">
                            <button type="submit" class="lt-btn lt-btn--primary"><?= e($submitLabel) ?></button>
                        </div>
                        <p class="lt-field__hint mb-0">Đánh giá hiện trên trang tour sau khi LocalTour duyệt.</p>
                    </form>
<?php if ($reviewStatus === 'pending'): ?>
                    </details>
<?php endif; ?>
<?php endif; ?>
<?php endif; ?>
                </section>
