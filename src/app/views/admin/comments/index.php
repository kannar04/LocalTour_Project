<?php declare(strict_types=1); ?>
<?php
/*
 * Trang "Bình luận" của quản trị viên (CR2 – Nguyễn Minh Thức).
 * Biến: $filter ('visible' | 'hidden' | 'all'), $keyword, $page, $pageSize, $total (số dòng khớp bộ lọc),
 *       $comments (NMT_sp_admin_comment_list, mới nhất trước), $success, $error (thông báo sau khi ẩn / hiện).
 * Ẩn: bắt buộc lý do (tối đa 255 ký tự). Hiện lại: bình luận về trang tour, xóa thông tin ẩn.
 */
use App\Controllers\AdminCommentController;
use App\Models\TourCommentModel;

$listHref = static function (array $changes) use ($filter, $keyword, $page): string {
    $query = array_merge(['status' => $filter, 'q' => $keyword, 'page' => (string) $page], $changes);
    if ($query['status'] === 'visible') {
        $query['status'] = '';
    }
    if ($query['page'] === '1') {
        $query['page'] = '';
    }
    $query = array_filter($query, static fn (string $part): bool => $part !== '');

    return '/admin/comments' . ($query !== [] ? '?' . http_build_query($query) : '');
};
$currentPath = $listHref([]);
$lastPage = max(1, (int) ceil($total / $pageSize));
$firstShown = ($page - 1) * $pageSize + 1;
$lastShown = $firstShown + count($comments) - 1;
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Bình luận</h1>
                <p class="lt-admin__subtitle">Bình luận của khách trên trang tour. Ẩn bình luận vi phạm điều khoản (kèm lý do); bình luận bị ẩn không còn hiện trên trang tour.</p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if ($error !== ''): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($error) ?></span></div>
<?php endif; ?>

            <form class="lt-admin-search" action="<?= e(url('/admin/comments')) ?>" method="get" role="search">
<?php if ($filter !== 'visible'): ?>
                <input type="hidden" name="status" value="<?= e($filter) ?>">
<?php endif; ?>
                <label class="sr-only" for="comment-search">Tìm theo nội dung, người viết hoặc tên tour</label>
                <input class="lt-admin-input" type="search" id="comment-search" name="q" value="<?= e($keyword) ?>"
                       maxlength="<?= AdminCommentController::KEYWORD_MAX_LENGTH ?>" placeholder="Nội dung, tên hoặc email người viết, tên tour">
                <button class="lt-btn lt-btn--primary" type="submit">Tìm</button>
<?php if ($keyword !== ''): ?>
                <a class="lt-btn lt-btn--soft" href="<?= e(url($listHref(['q' => '', 'page' => '1']))) ?>">Xóa tìm kiếm</a>
<?php endif; ?>
            </form>

            <nav class="lt-tabs" aria-label="Lọc theo trạng thái">
<?php foreach (TourCommentModel::ADMIN_FILTERS as $value => $label): ?>
                <a class="lt-tabs__link<?= $value === $filter ? ' is-active' : '' ?>" href="<?= e(url($listHref(['status' => $value, 'page' => '1']))) ?>"<?= $value === $filter ? ' aria-current="page"' : '' ?>><?= e($label) ?></a>
<?php endforeach; ?>
            </nav>

            <section class="lt-panel" aria-label="Danh sách bình luận">
<?php if ($comments === []): ?>
                <p class="lt-empty"><?php if ($keyword !== ''): ?>Không tìm thấy bình luận nào khớp với “<?= e($keyword) ?>”.<?php elseif ($page > 1): ?>Trang này không còn bình luận. <a href="<?= e(url($listHref(['page' => '1']))) ?>">Về trang đầu</a><?php else: ?><?= $filter === 'hidden' ? 'Chưa có bình luận nào bị ẩn.' : 'Chưa có bình luận nào.' ?><?php endif; ?></p>
<?php else: ?>
                <p class="lt-panel__lead"><?= $total > $pageSize ? e($firstShown) . '–' . e($lastShown) . ' trên ' : '' ?><?= e($total) ?> bình luận, mới nhất trước</p>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Thời gian</th>
                                <th scope="col">Người viết</th>
                                <th scope="col" class="lt-table__grow">Bình luận</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($comments as $comment): ?>
<?php
    $commentId = (string) $comment['comment_id'];
    $isHidden = $comment['status'] === 'hidden';
    $reasonId = 'comment-reason-' . $commentId;
?>
                            <tr>
                                <td class="lt-nowrap"><?= e(format_datetime((string) $comment['created_at'])) ?></td>
                                <td>
                                    <?= e($comment['user_name']) ?>
                                    <span class="lt-table__sub"><?= e($comment['user_email']) ?></span>
                                </td>
                                <td>
                                    <p class="lt-admin-comment__text"><?= nl2br(e($comment['content']), false) ?></p>
<?php if (mb_strlen((string) $comment['content']) > 240 || substr_count((string) $comment['content'], "\n") > 3): ?>
                                    <details class="lt-admin-comment__full">
                                        <summary>Xem đầy đủ</summary>
                                        <p><?= nl2br(e($comment['content']), false) ?></p>
                                    </details>
<?php endif; ?>
                                    <span class="lt-table__sub">Tour: <a href="<?= e(url('/tours/' . $comment['tour_id'])) ?>" target="_blank" rel="noopener"><?= e($comment['tour_title']) ?><span class="sr-only"> (mở tab mới)</span></a></span>
                                </td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= $isHidden ? 'rejected' : 'approved' ?>"><?= $isHidden ? 'Đã ẩn' : 'Đang hiển thị' ?></span>
<?php if ($isHidden): ?>
                                    <span class="lt-table__sub"><?= e($comment['hidden_by_name'] ?? '') ?><?= $comment['hidden_at'] !== null ? ' · ' . e(format_datetime((string) $comment['hidden_at'])) : '' ?></span>
<?php if ($comment['hidden_reason'] !== null): ?>
                                    <span class="lt-table__sub">Lý do: <?= e($comment['hidden_reason']) ?></span>
<?php endif; ?>
<?php endif; ?>
                                </td>
                                <td class="lt-admin-comment__actions">
<?php if ($isHidden): ?>
                                    <form action="<?= e(url('/admin/comments/' . $commentId . '/show')) ?>" method="post">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="back" value="<?= e($currentPath) ?>">
                                        <button class="lt-btn lt-btn--soft lt-btn--sm" type="submit">Hiện lại<span class="sr-only"> bình luận của <?= e($comment['user_name']) ?></span></button>
                                    </form>
<?php else: ?>
                                    <form class="lt-admin-comment__hide" action="<?= e(url('/admin/comments/' . $commentId . '/hide')) ?>" method="post">
                                        <?= csrf_field() ?>
                                        <input type="hidden" name="back" value="<?= e($currentPath) ?>">
                                        <label class="sr-only" for="<?= e($reasonId) ?>">Lý do ẩn bình luận của <?= e($comment['user_name']) ?></label>
                                        <input class="lt-admin-input" type="text" id="<?= e($reasonId) ?>" name="reason" required
                                               maxlength="<?= TourCommentModel::REASON_MAX_LENGTH ?>" placeholder="Lý do ẩn">
                                        <button class="lt-btn lt-btn--danger lt-btn--sm" type="submit">Ẩn<span class="sr-only"> bình luận của <?= e($comment['user_name']) ?></span></button>
                                    </form>
<?php endif; ?>
                                </td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
<?php if ($lastPage > 1): ?>
                <nav class="lt-admin-pager" aria-label="Phân trang bình luận">
<?php if ($page > 1): ?>
                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url($listHref(['page' => (string) min($page - 1, $lastPage)]))) ?>">Trang trước</a>
<?php endif; ?>
                    <span class="lt-admin-pager__info">Trang <?= e(min($page, $lastPage)) ?> / <?= e($lastPage) ?></span>
<?php if ($page < $lastPage): ?>
                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url($listHref(['page' => (string) ($page + 1)]))) ?>">Trang sau</a>
<?php endif; ?>
                </nav>
<?php endif; ?>
            </section>
        </main>
    </div>
</div>
