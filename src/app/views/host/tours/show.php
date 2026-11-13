<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: tổng quan một tour của đơn vị (Nguyễn Tuấn Khôi).
 * Biến: $tour (LTP_sp_admin_tour_detail), $access (NTK_sp_host_tour_access: tour gốc / bản sửa đang mở),
 *       $canEdit (sửa nội dung: chỉ tour "Nháp" hoặc "Bị từ chối"), $canSchedule (sửa lịch khởi hành, giá vé),
 *       $rejectNote (lý do từ chối gần nhất khi tour đang "Bị từ chối", không thì null),
 *       $history (các bước duyệt, cũ trước), $notice (['type', 'text'] hoặc null).
 * Đơn vị không tự duyệt: tour "Nháp" phải gửi duyệt; tour "Đã duyệt" sửa qua bản sửa (khách vẫn thấy nội dung
 * đã duyệt cho tới khi quản trị viên duyệt bản sửa).
 */
use App\Controllers\HostTourController;

$tourId = (string) $tour['tour_id'];
$tourStatus = (string) $tour['approval_status'];
$isRevision = $access['revision_of'] !== null;
$originalId = $isRevision ? (string) $access['revision_of'] : $tourId;
$originalOk = !$isRevision || $access['revision_of_status'] === 'approved';
$revisionId = $access['revision_id'] !== null ? (string) $access['revision_id'] : null;
$missing = [];
if (!$isRevision) {
    // Lịch khởi hành và giá vé nằm ở tour gốc, bản sửa không có.
    if ((int) $tour['schedule_count'] === 0) {
        $missing[] = 'lịch khởi hành';
    }
    if ((int) $tour['ticket_count'] === 0) {
        $missing[] = 'loại vé và giá vé';
    }
}
if ((int) $tour['policy_count'] === 0) {
    $missing[] = 'chính sách hủy';
}
if ((int) $tour['image_count'] === 0) {
    $missing[] = 'ảnh';
}
$missingText = $missing !== [] ? ' Tour còn thiếu: ' . implode(', ', $missing) . '.' : '';
$fields = [
    'Điểm đến' => $tour['destination_name'],
    'Loại hình' => or_missing($tour['category_name']),
    'Thời lượng' => format_duration($tour['duration_minutes']),
    'Số khách tối đa' => $tour['max_group_size'] . ' người',
    'Ngôn ngữ' => format_languages($tour['language_codes']),
    'Nơi khởi hành' => departure_text($tour['pickup_mode'], $tour['meeting_point']),
    'Điểm trả khách' => or_missing($tour['dropoff_point']),
    'Phương tiện' => or_missing($tour['transport']),
    'Hướng dẫn viên' => or_missing($tour['guide_info']),
];
$counts = [
    'Lịch khởi hành' => $tour['schedule_count'],
    'Loại vé đang bán' => $tour['ticket_count'],
    'Ảnh' => $tour['image_count'],
    'Mục lịch trình' => $tour['itinerary_count'],
    'Dịch vụ bao gồm / không bao gồm' => $tour['inclusion_count'],
    'Phiên bản chính sách hủy' => $tour['policy_count'],
];
if ($isRevision) {
    unset($counts['Lịch khởi hành'], $counts['Loại vé đang bán']);
}
$noticeIcons = ['success' => 'check', 'warning' => 'info', 'danger' => 'alert'];
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
<?php if ($isRevision): ?>
            <a class="lt-admin__back" href="<?= e(url('/host/tours/' . $originalId)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Tour đang hiển thị
            </a>
<?php else: ?>
            <a class="lt-admin__back" href="<?= e(url('/host/tours')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Tour của tôi
            </a>
<?php endif; ?>
            <header class="lt-admin__head lt-admin__head--row">
                <div>
                    <h1 class="lt-admin__title" id="admin-title"><?= e($tour['title']) ?></h1>
                    <p class="lt-admin__subtitle">
                        <span class="lt-badge lt-badge--<?= e($tourStatus) ?>"><?= e(tour_status_label($tourStatus)) ?></span>
<?php if ($isRevision): ?>
                        Bản sửa của tour "<?= e($access['revision_of_title']) ?>"
<?php else: ?>
                        <?= (int) $tour['is_public'] === 1 ? 'Đang hiển thị cho khách' : 'Chưa hiển thị cho khách' ?>
<?php endif; ?>
                    </p>
                </div>
                <div class="lt-admin__actions">
<?php if ($canEdit): ?>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/tours/' . $tourId . '/edit')) ?>">Sửa thông tin</a>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/tours/' . $tourId . '/content')) ?>">Ảnh, lịch trình, dịch vụ, chính sách</a>
<?php endif; ?>
<?php if ($canSchedule): ?>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/tours/' . $tourId . '/schedules')) ?>">Lịch khởi hành và giá vé</a>
<?php endif; ?>
<?php if (!$isRevision): ?>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/bookings?tour=' . $tourId)) ?>">Đơn đặt tour</a>
<?php endif; ?>
<?php if (!$isRevision && (int) $tour['is_public'] === 1): ?>
                    <a class="lt-btn lt-btn--outline" href="<?= e(url('/tours/' . $tourId)) ?>">Xem trang tour</a>
<?php endif; ?>
                </div>
            </header>

<?php if ($notice !== null): ?>
            <div class="lt-alert lt-alert--<?= e($notice['type']) ?>" role="status"><span class="lt-icon lt-icon--<?= e($noticeIcons[$notice['type']]) ?>" aria-hidden="true"></span><span><?= e($notice['text']) ?></span></div>
<?php endif; ?>
<?php if ($isRevision && !$originalOk): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tour gốc không còn ở trạng thái "Đã duyệt" nên bản sửa này không gửi duyệt được. Hãy hủy bản sửa.</span></div>
<?php elseif ($isRevision && $tourStatus === 'pending'): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Bản sửa đang chờ quản trị viên LocalTour duyệt nên bị khóa. Khách vẫn thấy nội dung đã duyệt của tour.</span></div>
<?php elseif ($isRevision && $tourStatus === 'rejected'): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Bản sửa bị từ chối<?= $rejectNote !== null ? ': ' . e($rejectNote) : '.' ?> Sửa theo góp ý rồi gửi duyệt lại, hoặc hủy bản sửa. Tour đang hiển thị giữ nguyên.</span></div>
<?php elseif ($isRevision): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Đây là bản sửa, chưa gửi duyệt. Khách vẫn thấy nội dung đã duyệt của tour cho tới khi quản trị viên LocalTour duyệt bản sửa này.<?= e($missingText) ?></span></div>
<?php elseif ($tourStatus === 'draft'): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tour đang là bản nháp, chưa gửi duyệt nên chưa hiển thị cho khách.<?= e($missingText) ?></span></div>
<?php elseif ($tourStatus === 'pending'): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tour đang chờ quản trị viên LocalTour duyệt nên chưa hiển thị cho khách và không sửa được nội dung.<?= e($missingText) ?></span></div>
<?php elseif ($tourStatus === 'rejected'): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Tour bị từ chối<?= $rejectNote !== null ? ': ' . e($rejectNote) : '.' ?> Sửa tour theo góp ý rồi chọn "Gửi duyệt" để gửi lại.</span></div>
<?php elseif ($tourStatus === 'approved' && $revisionId !== null): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tour có một bản sửa đang "<?= e(tour_status_label($access['revision_status'])) ?>". Khách vẫn thấy nội dung hiện tại cho tới khi bản sửa được duyệt.
                <a href="<?= e(url('/host/tours/' . $revisionId)) ?>">Mở bản sửa</a></span></div>
<?php elseif ($tourStatus === 'archived' && $notice === null): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tour đang ngừng hiển thị: khách không tìm thấy và không đặt được tour. Liên hệ quản trị viên LocalTour để hiển thị lại.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="tour-info-title">
                        <h2 class="lt-panel__title" id="tour-info-title">Thông tin tour</h2>
<?php foreach (text_paragraphs($tour['description']) as $paragraph): ?>
                        <p class="lt-admin__text"><?= nl2br(e($paragraph)) ?></p>
<?php endforeach; ?>
                        <dl class="lt-fields">
<?php foreach ($fields as $label => $value): ?>
                            <dt><?= e($label) ?></dt>
                            <dd><?= e($value) ?></dd>
<?php endforeach; ?>
                        </dl>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="tour-counts-title">
                        <h2 class="lt-panel__title" id="tour-counts-title">Nội dung đã nhập</h2>
                        <dl class="lt-fields lt-fields--compact">
<?php foreach ($counts as $label => $value): ?>
                            <dt><?= e($label) ?></dt>
                            <dd><?= e($value) ?></dd>
<?php endforeach; ?>
                        </dl>
                    </section>

<?php if ($canEdit): ?>
                    <section class="lt-panel" aria-labelledby="tour-submit-title">
                        <h2 class="lt-panel__title" id="tour-submit-title">Gửi duyệt</h2>
<?php if ($originalOk): ?>
                        <p class="lt-admin__text"><?= $isRevision
                            ? 'Gửi bản sửa cho quản trị viên LocalTour. Khi bản sửa được duyệt, nội dung mới thay cho nội dung đang hiển thị.'
                            : 'Gửi tour cho quản trị viên LocalTour. Trong lúc chờ duyệt tour bị khóa, không sửa được nội dung.' ?></p>
                        <form action="<?= e(url('/host/tours/' . $tourId . '/submit')) ?>" method="post" class="lt-admin-form">
                            <?= csrf_field() ?>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">
                                <span class="lt-icon lt-icon--check" aria-hidden="true"></span> <?= $isRevision ? 'Gửi duyệt bản sửa' : 'Gửi duyệt' ?>
                            </button>
                        </form>
<?php endif; ?>
<?php if ($isRevision): ?>
                        <form action="<?= e(url('/host/tours/' . $tourId . '/revision/discard')) ?>" method="post" class="lt-admin-form<?= $originalOk ? ' lt-admin-form--split' : '' ?>">
                            <?= csrf_field() ?>
                            <p class="lt-admin__text">Hủy bản sửa sẽ bỏ mọi thay đổi trong bản sửa này. Tour đang hiển thị giữ nguyên.</p>
                            <button class="lt-btn lt-btn--danger lt-btn--block" type="submit">
                                <span class="lt-icon lt-icon--x" aria-hidden="true"></span> Hủy bản sửa
                            </button>
                        </form>
<?php endif; ?>
                    </section>
<?php endif; ?>

<?php if (!$isRevision && $tourStatus === 'approved'): ?>
                    <section class="lt-panel" aria-labelledby="tour-revise-title">
                        <h2 class="lt-panel__title" id="tour-revise-title">Sửa tour đã duyệt</h2>
<?php if ($revisionId !== null): ?>
                        <p class="lt-admin__text">Tour đang có một bản sửa (<?= e(tour_status_label($access['revision_status'])) ?>). Mỗi tour chỉ có một bản sửa cùng lúc.</p>
                        <a class="lt-btn lt-btn--primary lt-btn--block" href="<?= e(url('/host/tours/' . $revisionId)) ?>">Mở bản sửa</a>
<?php else: ?>
                        <p class="lt-admin__text">Thông tin, ảnh, lịch trình, dịch vụ và chính sách hủy của tour đã duyệt sửa qua một bản sửa. Khách vẫn thấy nội dung hiện tại cho tới khi quản trị viên LocalTour duyệt bản sửa. Lịch khởi hành và giá vé sửa trực tiếp, không cần duyệt.</p>
                        <form action="<?= e(url('/host/tours/' . $tourId . '/revision')) ?>" method="post" class="lt-admin-form">
                            <?= csrf_field() ?>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">
                                <span class="lt-icon lt-icon--plus" aria-hidden="true"></span> Tạo bản sửa
                            </button>
                        </form>
<?php endif; ?>
                        <form action="<?= e(url('/host/tours/' . $tourId . '/archive')) ?>" method="post" class="lt-admin-form lt-admin-form--split">
                            <?= csrf_field() ?>
                            <p class="lt-admin__text">Ngừng hiển thị: khách không còn tìm thấy và không đặt được tour, các đơn cũ giữ nguyên. Chỉ làm được khi tour không còn đơn đang xử lý; muốn hiển thị lại thì liên hệ quản trị viên LocalTour.</p>
                            <button class="lt-btn lt-btn--danger lt-btn--block" type="submit">
                                <span class="lt-icon lt-icon--x" aria-hidden="true"></span> Ngừng hiển thị tour
                            </button>
                        </form>
                    </section>
<?php endif; ?>

                    <section class="lt-panel" aria-labelledby="tour-history-title">
                        <h2 class="lt-panel__title" id="tour-history-title">Lịch sử duyệt</h2>
<?php if ($history === []): ?>
                        <p class="lt-empty">Chưa có lần xử lý nào.</p>
<?php else: ?>
                        <ol class="lt-history">
<?php foreach ($history as $log): ?>
                            <li class="lt-history__item">
                                <p class="lt-history__head"><?= e(HostTourController::HISTORY_ACTIONS[$log['action']]) ?></p>
                                <p class="lt-history__meta"><?= e(format_datetime($log['created_at'])) ?></p>
<?php if ($log['action'] === 'tour_reject' && $log['note'] !== null): ?>
                                <p class="lt-history__note">Lý do: <?= e($log['note']) ?></p>
<?php endif; ?>
                            </li>
<?php endforeach; ?>
                        </ol>
<?php endif; ?>
                    </section>
                </div>
            </div>
        </main>
    </div>
</div>
