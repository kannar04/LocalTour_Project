<?php declare(strict_types=1); ?>
<?php
/*
 * Lịch khởi hành và giá vé của một tour (FR-14, Nguyễn Minh Thức).
 * Biến: $tour (LTP_sp_admin_tour_detail), $schedules (NMT_sp_admin_schedule_list), $logs (lịch sử thêm / sửa lịch,
 *       mới nhất trước), $old / $errors (form thêm lịch; 'form' = lỗi chung), $success ('' = không có).
 * Đang giữ = sức chứa - còn nhận: chỗ của các yêu cầu đã xác nhận chỗ (yêu cầu "Chờ xác nhận" chưa giữ chỗ).
 */
$tourId = (string) $tour['tour_id'];
$logLabels = ['schedule_create' => 'Thêm lịch', 'schedule_update' => 'Sửa lịch'];
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/admin/tours/' . $tourId)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Chi tiết tour
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Lịch khởi hành và giá vé</h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($tour['approval_status']) ?>"><?= e(tour_status_label($tour['approval_status'])) ?></span>
                    <?= e($tour['title']) ?>
                </p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Chưa thêm được lịch: vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <section class="lt-panel" aria-labelledby="schedule-list-title">
                <h2 class="lt-panel__title" id="schedule-list-title">Các lịch khởi hành</h2>
<?php if ($schedules === []): ?>
                <p class="lt-empty">Tour chưa có lịch khởi hành nào.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Khởi hành</th>
                                <th scope="col" class="text-right">Sức chứa</th>
                                <th scope="col" class="text-right">Đang giữ</th>
                                <th scope="col" class="text-right">Còn nhận</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col">Giá vé</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($schedules as $schedule): ?>
<?php $activeBookings = (int) $schedule['active_booking_count']; ?>
                            <tr>
                                <td>
                                    <strong><?= e(format_date($schedule['starts_at'])) ?></strong>
                                    <span class="lt-table__sub"><?= e(schedule_time_text($schedule['starts_at'], $schedule['ends_at'])) ?><?= (int) $schedule['departed'] === 1 ? ' · đã khởi hành' : '' ?></span>
                                </td>
                                <td class="text-right"><?= e($schedule['capacity']) ?></td>
                                <td class="text-right"><?= e($schedule['held']) ?></td>
                                <td class="text-right"><?= e($schedule['remaining']) ?></td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($schedule['status']) ?>"><?= e(schedule_status_label($schedule['status'])) ?></span>
<?php if ($activeBookings > 0): ?>
                                    <span class="lt-table__sub"><?= e($activeBookings) ?> yêu cầu đang xử lý</span>
<?php endif; ?>
                                </td>
                                <td>
<?php if ($schedule['adult_price_vnd'] !== null && (int) $schedule['adult_active'] === 1): ?>
                                    Người lớn <?= e(format_vnd($schedule['adult_price_vnd'])) ?>
<?php else: ?>
                                    <span class="lt-muted">Chưa bán vé người lớn</span>
<?php endif; ?>
                                    <span class="lt-table__sub"><?= $schedule['child_price_vnd'] !== null && (int) $schedule['child_active'] === 1 ? 'Trẻ em ' . e(format_vnd($schedule['child_price_vnd'])) : 'Không bán vé trẻ em' ?></span>
                                </td>
                                <td class="text-right">
<?php if ($schedule['status'] !== 'completed'): ?>
                                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/admin/schedules/' . $schedule['schedule_id'] . '/edit')) ?>">Sửa<span class="sr-only"> lịch <?= e(format_datetime($schedule['starts_at'])) ?></span></a>
<?php endif; ?>
                                </td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
            </section>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="schedule-new-title">
                        <h2 class="lt-panel__title" id="schedule-new-title">Thêm lịch khởi hành</h2>
                        <form class="lt-admin-form" action="<?= e(url('/admin/tours/' . $tourId . '/schedules')) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
<?php
$prefix = 'schedule-new';
$lockTimes = false;
$heldSeats = 0;
require __DIR__ . '/fields.php';
?>
                            <button class="lt-btn lt-btn--primary" type="submit">
                                <span class="lt-icon lt-icon--plus" aria-hidden="true"></span> Thêm lịch
                            </button>
                        </form>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="schedule-history-title">
                        <h2 class="lt-panel__title" id="schedule-history-title">Lịch sử thay đổi (mới nhất trước)</h2>
<?php if ($logs === []): ?>
                        <p class="lt-empty">Chưa có thay đổi nào được ghi lại.</p>
<?php else: ?>
                        <ol class="lt-history">
<?php foreach ($logs as $log): ?>
                            <li class="lt-history__item">
                                <p class="lt-history__head">
                                    <?= e($logLabels[$log['action']] ?? $log['action']) ?> <?= e(format_datetime($log['starts_at'])) ?>
<?php if ($log['from_status'] !== null && $log['from_status'] !== $log['to_status']): ?>
                                    · <?= e(schedule_status_label($log['from_status'])) ?> → <strong><?= e(schedule_status_label($log['to_status'])) ?></strong>
<?php endif; ?>
                                </p>
                                <p class="lt-history__meta"><?= e(format_datetime($log['created_at'])) ?> · <?= e($log['actor_name']) ?></p>
<?php if ($log['note'] !== null): ?>
                                <p class="lt-history__note"><?= e($log['note']) ?></p>
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
