<?php declare(strict_types=1); ?>
<?php
/*
 * Duyệt đánh giá sao (FR-16, CR2 – Nguyễn Tuấn Khôi).
 * Biến: $filter ('pending' | 'approved' | 'rejected' | 'all'), $keyword (mã đơn, tour, tên hoặc email khách),
 *       $page / $pages (trang đang xem / số trang), $summary (total, pending, approved, rejected, all – theo từ khóa),
 *       $reviews (NTK_sp_admin_review_list), $success / $error ('' = không có).
 * Chờ duyệt: "Duyệt" hoặc "Từ chối" (bắt buộc lý do). Đã duyệt: "Gỡ đánh giá" (bắt buộc lý do).
 * Không được duyệt: chỉ xem; khách sửa và gửi lại từ trang đơn.
 */
use App\Controllers\AdminReviewController;
use App\Models\ReviewModel;

$counts = ['pending' => $summary['pending'], 'approved' => $summary['approved'], 'rejected' => $summary['rejected'], 'all' => $summary['all']];
$hiddenState = static function () use ($filter, $keyword, $page): string {
    return '<input type="hidden" name="status" value="' . e($filter) . '">'
        . '<input type="hidden" name="q" value="' . e($keyword) . '">'
        . '<input type="hidden" name="page" value="' . e($page) . '">';
};
$firstShown = ($page - 1) * ReviewModel::PAGE_SIZE + 1;
$lastShown = $firstShown + count($reviews) - 1;
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Duyệt đánh giá</h1>
                <p class="lt-admin__subtitle">Khách gửi đánh giá từ đơn đã hoàn thành. Chỉ đánh giá đã duyệt mới hiện trên trang tour và được tính vào điểm trung bình.</p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if ($error !== ''): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($error) ?></span></div>
<?php endif; ?>

            <form class="lt-admin-search" action="<?= e(url('/admin/reviews')) ?>" method="get" role="search">
<?php if ($filter !== 'pending'): ?>
                <input type="hidden" name="status" value="<?= e($filter) ?>">
<?php endif; ?>
                <label class="sr-only" for="review-search">Tìm theo mã đơn, tên tour, tên hoặc email khách</label>
                <input class="lt-admin-input" type="search" id="review-search" name="q" value="<?= e($keyword) ?>"
                       maxlength="<?= e(ReviewModel::KEYWORD_MAX_LENGTH) ?>" placeholder="Mã đơn, tên tour, tên hoặc email khách">
                <button class="lt-btn lt-btn--primary" type="submit">Tìm</button>
<?php if ($keyword !== ''): ?>
                <a class="lt-btn lt-btn--soft" href="<?= e(url(AdminReviewController::listUrl($filter, '', 1))) ?>">Xóa tìm kiếm</a>
<?php endif; ?>
            </form>

            <nav class="lt-tabs" aria-label="Lọc theo trạng thái duyệt">
<?php foreach (ReviewModel::FILTERS as $value => $label): ?>
                <a class="lt-tabs__link<?= $value === $filter ? ' is-active' : '' ?>" href="<?= e(url(AdminReviewController::listUrl($value, $keyword, 1))) ?>"<?= $value === $filter ? ' aria-current="page"' : '' ?>><?= e($label) ?> (<?= e($counts[$value]) ?>)</a>
<?php endforeach; ?>
            </nav>

            <section class="lt-panel" aria-label="Danh sách đánh giá">
<?php if ($reviews === []): ?>
                <p class="lt-empty"><?= $keyword !== '' ? 'Không tìm thấy đánh giá nào khớp với “' . e($keyword) . '”.' : ($filter === 'pending' ? 'Không có đánh giá nào đang chờ duyệt.' : 'Không có đánh giá nào ở trạng thái này.') ?></p>
<?php else: ?>
                <p class="lt-panel__lead">Đánh giá <?= e($firstShown) ?>–<?= e($lastShown) ?> trên tổng số <?= e($summary['total']) ?><?= $filter === 'pending' ? ', gửi sớm trước' : ($filter === 'all' ? ', chờ duyệt trước' : ', mới gửi trước') ?></p>
                <ul class="lt-review-queue">
<?php foreach ($reviews as $review): ?>
<?php
    $reviewId = (string) $review['review_id'];
    $reviewStatus = (string) $review['moderation_status'];
    $rating = (int) $review['rating'];
    $note = trim((string) ($review['moderation_note'] ?? ''));
?>
                    <li class="lt-review-item">
                        <article aria-labelledby="review-<?= e($reviewId) ?>-title">
                            <div class="lt-review-item__head">
                                <h2 class="lt-review-item__title" id="review-<?= e($reviewId) ?>-title">
                                    <span class="lt-review-stars" style="--lt-rating: <?= e($rating) ?>" role="img" aria-label="<?= e($rating) ?> trên 5 sao"></span>
                                    <span><?= e($rating) ?>/5 · <?= e($review['tour_title']) ?></span>
                                </h2>
                                <span class="lt-badge lt-badge--<?= e(preg_replace('/[^a-z_]/', '', $reviewStatus)) ?>"><?= e(ReviewModel::FILTERS[$reviewStatus] ?? $reviewStatus) ?></span>
                            </div>
                            <p class="lt-review-item__meta">
                                Đơn <strong><?= e($review['booking_code']) ?></strong>
                                · <?= e($review['customer_name']) ?> (<?= e($review['customer_email']) ?>)
                                · Tham gia ngày <?= e(format_date((string) $review['starts_at'])) ?>
                                · Gửi lúc <?= e(format_datetime((string) $review['created_at'])) ?>
                            </p>
                            <p class="lt-review-item__text"><?= nl2br(e($review['content']), false) ?></p>
<?php if ($review['moderated_at'] !== null): ?>
                            <p class="lt-review-item__moderation">
                                <?= $reviewStatus === 'approved' ? 'Duyệt' : 'Từ chối' ?> bởi <?= e($review['moderator_name'] ?? 'quản trị viên') ?> lúc <?= e(format_datetime((string) $review['moderated_at'])) ?><?= $note !== '' ? ' · ' . ($reviewStatus === 'rejected' ? 'Lý do: ' : 'Ghi chú: ') . e($note) : '' ?>
                            </p>
<?php endif; ?>
<?php if ($reviewStatus !== 'rejected'): ?>
                            <div class="lt-review-item__actions">
<?php if ($reviewStatus === 'pending'): ?>
                                <form action="<?= e(url('/admin/reviews/' . $reviewId . '/approve')) ?>" method="post">
                                    <?= csrf_field() ?>
                                    <?= $hiddenState() ?>
                                    <button class="lt-btn lt-btn--primary lt-btn--sm" type="submit">Duyệt<span class="sr-only"> đánh giá của đơn <?= e($review['booking_code']) ?></span></button>
                                </form>
<?php endif; ?>
                                <details class="lt-review-item__reject">
                                    <summary class="lt-btn lt-btn--soft lt-btn--sm"><?= $reviewStatus === 'pending' ? 'Từ chối' : 'Gỡ đánh giá' ?><span class="sr-only"> của đơn <?= e($review['booking_code']) ?></span></summary>
                                    <form action="<?= e(url('/admin/reviews/' . $reviewId . '/reject')) ?>" method="post">
                                        <?= csrf_field() ?>
                                        <?= $hiddenState() ?>
                                        <label class="lt-admin-label" for="reject-note-<?= e($reviewId) ?>"><?= $reviewStatus === 'pending' ? 'Lý do từ chối' : 'Lý do gỡ đánh giá' ?> (bắt buộc, khách thấy ở trang đơn)</label>
                                        <textarea class="lt-admin-input" id="reject-note-<?= e($reviewId) ?>" name="note" rows="2" maxlength="<?= e(ReviewModel::NOTE_MAX_LENGTH) ?>" required></textarea>
                                        <button class="lt-btn lt-btn--danger lt-btn--sm" type="submit"><?= $reviewStatus === 'pending' ? 'Từ chối đánh giá' : 'Gỡ đánh giá' ?></button>
                                    </form>
                                </details>
                            </div>
<?php endif; ?>
                        </article>
                    </li>
<?php endforeach; ?>
                </ul>
<?php endif; ?>
<?php if ($pages > 1): ?>
                <nav class="lt-pager" aria-label="Phân trang">
<?php if ($page > 1): ?>
                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url(AdminReviewController::listUrl($filter, $keyword, $page - 1))) ?>" rel="prev">Trang trước</a>
<?php endif; ?>
                    <span class="lt-pager__info">Trang <?= e($page) ?> / <?= e($pages) ?></span>
<?php if ($page < $pages): ?>
                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url(AdminReviewController::listUrl($filter, $keyword, $page + 1))) ?>" rel="next">Trang sau</a>
<?php endif; ?>
                </nav>
<?php endif; ?>
            </section>
        </main>
    </div>
</div>
