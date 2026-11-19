<?php declare(strict_types=1); ?>
<?php
/*
 * Mục "Bình luận" trên trang chi tiết tour (CR2 – Nguyễn Minh Thức). show.php require file này ngay sau mục "Đánh giá".
 * Biến dùng từ show.php: $tour (tour_id), $tourPath ('/tours/<uuid>').
 * Danh sách bình luận do tour-comments.js tải qua GET /api/tours/{id}/comments (mỗi lần 10 bình luận, mới nhất trước).
 * Tài khoản khách hàng: ô viết bình luận (1–1000 ký tự). Khách chưa đăng nhập: nút đăng nhập, quay lại đúng mục này.
 * Tài khoản đơn vị tổ chức / quản trị viên: chỉ xem.
 */
use App\Models\TourCommentModel;

$commentUser = current_user();
$commentRole = (string) ($commentUser['role'] ?? '');
$commentLoginUrl = url('/login') . '?next=' . rawurlencode($tourPath . '#binh-luan');
$commentName = trim((string) ($commentUser['name'] ?? ''));
$commentAvatarPath = ltrim(trim((string) ($commentUser['avatar_url'] ?? '')), '/');
$commentAvatar = $commentAvatarPath !== ''
    && preg_match('#^uploads/avatars/[A-Za-z0-9_-]+\.(jpe?g|png|webp)$#', $commentAvatarPath)
    && is_file(BASE_PATH . '/public/assets/' . $commentAvatarPath)
    ? asset($commentAvatarPath) : null;
?>
                <section class="lt-section lt-comments" id="binh-luan" tabindex="-1" aria-labelledby="binh-luan-title">
                    <h2 class="lt-section__title" id="binh-luan-title">Bình luận <span class="lt-comments__count js-comments-count" hidden></span></h2>

                    <div class="js-tour-comments" data-tour-id="<?= e($tour['tour_id']) ?>" data-max-length="<?= TourCommentModel::CONTENT_MAX_LENGTH ?>"
                         data-login-url="<?= e($commentLoginUrl) ?>">
<?php if ($commentRole === 'customer'): ?>
                        <form class="lt-comment-form js-comment-form" action="<?= e(url('/api/tours/' . $tour['tour_id'] . '/comments')) ?>" method="post" novalidate>
<?php if ($commentAvatar !== null): ?>
                            <img class="lt-avatar lt-avatar--sm lt-avatar--img" src="<?= e($commentAvatar) ?>" alt="" width="34" height="34">
<?php else: ?>
                            <span class="lt-avatar lt-avatar--sm" aria-hidden="true"><?= e(mb_strtoupper(mb_substr($commentName, 0, 1))) ?></span>
<?php endif; ?>
                            <div class="lt-comment-form__body">
                                <label class="lt-comment-form__label" for="comment-content">Viết bình luận <span class="lt-comment-form__as">với tên <?= e($commentName) ?></span></label>
                                <textarea class="lt-comment-form__input js-comment-input" id="comment-content" name="content" rows="3"
                                          placeholder="Đặt câu hỏi hoặc chia sẻ cảm nhận của bạn về tour…"
                                          aria-describedby="comment-counter comment-rules"></textarea>
                                <p class="lt-comment-form__error js-comment-error" id="comment-error" role="alert" hidden></p>
                                <div class="lt-comment-form__foot">
                                    <span class="lt-comment-form__counter js-comment-counter" id="comment-counter">0/<?= TourCommentModel::CONTENT_MAX_LENGTH ?> ký tự</span>
                                    <button class="lt-btn lt-btn--primary lt-btn--sm js-comment-submit" type="submit">Gửi bình luận</button>
                                </div>
                            </div>
                        </form>
<?php elseif ($commentUser === null): ?>
                        <div class="lt-comment-cta">
                            <span class="lt-empty-card__icon" aria-hidden="true"><span class="lt-icon lt-icon--message"></span></span>
                            <p class="lt-comment-cta__text">Đăng nhập tài khoản khách hàng để đặt câu hỏi hoặc chia sẻ cảm nhận về tour.</p>
                            <a class="lt-btn lt-btn--outline lt-btn--sm" href="<?= e($commentLoginUrl) ?>">Đăng nhập để bình luận</a>
                        </div>
<?php else: ?>
                        <p class="lt-empty-note lt-comment-note">Chỉ tài khoản khách hàng mới viết được bình luận. Bạn đang xem với tài khoản <?= $commentRole === 'admin' ? 'quản trị viên' : 'đơn vị tổ chức' ?>.</p>
<?php endif; ?>
                        <p class="lt-comments__rules" id="comment-rules">Bình luận hiển thị công khai. Hãy lịch sự và đúng chủ đề; bình luận vi phạm <a href="<?= e(url('/dieu-khoan')) ?>">Điều khoản sử dụng</a> có thể bị quản trị viên ẩn.</p>

                        <p class="lt-comments__status js-comments-status" role="status">Đang tải bình luận…</p>
                        <noscript><p class="lt-empty-note">Bật JavaScript để xem bình luận.</p></noscript>
                        <ul class="lt-comments__list js-comments-list" aria-label="Danh sách bình luận"></ul>
                        <div class="lt-comments__more">
                            <button class="lt-btn lt-btn--soft lt-btn--sm js-comments-more" type="button" hidden>Xem thêm bình luận</button>
                        </div>
                    </div>
                </section>
