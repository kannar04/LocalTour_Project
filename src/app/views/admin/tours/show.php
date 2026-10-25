<?php declare(strict_types=1); ?>
<?php
/*
 * Chi tiết tour cho quản trị viên duyệt (FR-24, Lê Trung Phong).
 * Biến: $tour (LTP_sp_admin_tour_detail), $history (lịch sử xử lý, NFR-09), $success / $error ('' = không có),
 *       $note (lý do từ chối giữ lại khi có lỗi).
 * Form "Phê duyệt" và "Từ chối" chỉ hiện khi tour đang "Chờ duyệt".
 */
$isPending = $tour['approval_status'] === 'pending';
$providerOk = $tour['provider_approval_status'] === 'approved' && $tour['provider_user_status'] === 'active';
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
    'Đơn vị tổ chức' => $tour['provider_name'] . ' · ' . $tour['provider_phone'],
    'Nguồn tham khảo' => or_missing($tour['source_url']),
    'Ngày xác minh' => $tour['verified_at'] !== null ? format_date($tour['verified_at']) : 'Chưa xác minh',
];
$counts = [
    'Lịch khởi hành' => $tour['schedule_count'],
    'Loại vé đang bán' => $tour['ticket_count'],
    'Ảnh' => $tour['image_count'],
    'Mục lịch trình' => $tour['itinerary_count'],
    'Dịch vụ bao gồm / không bao gồm' => $tour['inclusion_count'],
    'Phiên bản chính sách hủy' => $tour['policy_count'],
];
$actionLabels = ['tour_approve' => 'Phê duyệt', 'tour_reject' => 'Từ chối'];
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/admin/tours' . ($isPending ? '' : '?status=all'))) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Danh sách tour
            </a>
            <header class="lt-admin__head lt-admin__head--row">
                <div>
                    <h1 class="lt-admin__title" id="admin-title"><?= e($tour['title']) ?></h1>
                    <p class="lt-admin__subtitle">
                        <span class="lt-badge lt-badge--<?= e($tour['approval_status']) ?>"><?= e(tour_status_label($tour['approval_status'])) ?></span>
                        <?= (int) $tour['is_public'] === 1 ? 'Đang hiển thị cho khách' : 'Chưa hiển thị cho khách' ?>
                    </p>
                </div>
<?php if ((int) $tour['is_public'] === 1): ?>
                <a class="lt-btn lt-btn--outline" href="<?= e(url('/tours/' . $tour['tour_id'])) ?>">Xem trang tour</a>
<?php endif; ?>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if ($error !== ''): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($error) ?></span></div>
<?php endif; ?>
<?php if (!$providerOk): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Đơn vị tổ chức chưa được duyệt hoặc đang bị khóa: tour sẽ chưa hiển thị cho khách dù đã phê duyệt.</span></div>
<?php endif; ?>
<?php if ($isPending && $missing !== []): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tour còn thiếu: <?= e(implode(', ', $missing)) ?>.</span></div>
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

<?php if ($isPending): ?>
                    <section class="lt-panel" aria-labelledby="tour-decide-title">
                        <h2 class="lt-panel__title" id="tour-decide-title">Xử lý</h2>
                        <form action="<?= e(url('/admin/tours/' . $tour['tour_id'] . '/approve')) ?>" method="post" class="lt-admin-form">
                            <?= csrf_field() ?>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">
                                <span class="lt-icon lt-icon--check" aria-hidden="true"></span> Phê duyệt tour
                            </button>
                        </form>
                        <form action="<?= e(url('/admin/tours/' . $tour['tour_id'] . '/reject')) ?>" method="post" class="lt-admin-form lt-admin-form--split">
                            <?= csrf_field() ?>
                            <label class="lt-admin-label" for="reject-note">Lý do từ chối (bắt buộc)</label>
                            <textarea class="lt-admin-input" id="reject-note" name="note" rows="3" maxlength="255" required><?= e($note) ?></textarea>
                            <button class="lt-btn lt-btn--danger lt-btn--block" type="submit">
                                <span class="lt-icon lt-icon--x" aria-hidden="true"></span> Từ chối tour
                            </button>
                        </form>
                    </section>
<?php endif; ?>
                </div>
            </div>

            <section class="lt-panel" aria-labelledby="tour-history-title">
                <h2 class="lt-panel__title" id="tour-history-title">Lịch sử xử lý</h2>
<?php if ($history === []): ?>
                <p class="lt-empty">Chưa có lần xử lý nào.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr><th scope="col">Thời điểm</th><th scope="col">Người xử lý</th><th scope="col">Thao tác</th><th scope="col">Lý do / ghi chú</th></tr>
                        </thead>
                        <tbody>
<?php foreach ($history as $log): ?>
                            <tr>
                                <td><?= e(format_datetime($log['created_at'])) ?></td>
                                <td><?= e($log['actor_name']) ?></td>
                                <td><?= e($actionLabels[$log['action']] ?? $log['action']) ?>: <?= e(tour_status_label($log['from_status'])) ?> → <?= e(tour_status_label($log['to_status'])) ?></td>
                                <td><?= $log['note'] !== null ? e($log['note']) : '<span class="lt-muted">Không có</span>' ?></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
            </section>
        </main>
    </div>
</div>
