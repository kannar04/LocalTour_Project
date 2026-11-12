<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: tổng quan một tour của đơn vị (Nguyễn Tuấn Khôi).
 * Biến: $tour (LTP_sp_admin_tour_detail), $canEdit (false khi tour đang "Ngừng hiển thị"),
 *       $rejectNote (lý do từ chối gần nhất khi tour đang "Bị từ chối", không thì null),
 *       $history (các bước duyệt, cũ trước), $success ('' = không có).
 * Đơn vị không tự duyệt: tour hiển thị cho khách sau khi quản trị viên phê duyệt.
 */
use App\Controllers\HostTourController;

$tourId = (string) $tour['tour_id'];
$tourStatus = (string) $tour['approval_status'];
$missing = [];
if ((int) $tour['schedule_count'] === 0) {
    $missing[] = 'lịch khởi hành';
}
if ((int) $tour['ticket_count'] === 0) {
    $missing[] = 'loại vé và giá vé';
}
if ((int) $tour['policy_count'] === 0) {
    $missing[] = 'chính sách hủy';
}
if ((int) $tour['image_count'] === 0) {
    $missing[] = 'ảnh';
}
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
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/host/tours')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Tour của tôi
            </a>
            <header class="lt-admin__head lt-admin__head--row">
                <div>
                    <h1 class="lt-admin__title" id="admin-title"><?= e($tour['title']) ?></h1>
                    <p class="lt-admin__subtitle">
                        <span class="lt-badge lt-badge--<?= e($tourStatus) ?>"><?= e(tour_status_label($tourStatus)) ?></span>
                        <?= (int) $tour['is_public'] === 1 ? 'Đang hiển thị cho khách' : 'Chưa hiển thị cho khách' ?>
                    </p>
                </div>
                <div class="lt-admin__actions">
<?php if ($canEdit): ?>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/tours/' . $tourId . '/edit')) ?>">Sửa thông tin</a>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/tours/' . $tourId . '/schedules')) ?>">Lịch khởi hành và giá vé</a>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/tours/' . $tourId . '/content')) ?>">Ảnh, lịch trình, dịch vụ, chính sách</a>
<?php endif; ?>
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/host/bookings?tour=' . $tourId)) ?>">Đơn đặt tour</a>
<?php if ($canEdit && (int) $tour['is_public'] === 1): ?>
                    <a class="lt-btn lt-btn--outline" href="<?= e(url('/tours/' . $tourId)) ?>">Xem trang tour</a>
<?php endif; ?>
                </div>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--<?= $canEdit ? 'success' : 'warning' ?>" role="status"><span class="lt-icon lt-icon--<?= $canEdit ? 'check' : 'info' ?>" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if ($tourStatus === 'pending'): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tour đang chờ quản trị viên LocalTour duyệt nên chưa hiển thị cho khách.<?= $missing !== [] ? ' Tour còn thiếu: ' . e(implode(', ', $missing)) . '.' : '' ?></span></div>
<?php elseif ($tourStatus === 'rejected'): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Tour bị từ chối<?= $rejectNote !== null ? ': ' . e($rejectNote) : '.' ?> Sửa tour theo góp ý để tour quay về "Chờ duyệt".</span></div>
<?php elseif ($tourStatus === 'approved'): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Sửa thông tin, ảnh, lịch trình, dịch vụ hoặc chính sách hủy sẽ đưa tour về "Chờ duyệt" (tạm ẩn với khách) cho tới khi được duyệt lại. Thêm, sửa lịch khởi hành và giá vé không cần duyệt lại.</span></div>
<?php elseif ($tourStatus === 'archived' && $success === ''): ?>
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
