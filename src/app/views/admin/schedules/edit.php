<?php declare(strict_types=1); ?>
<?php
/*
 * Sửa một lịch khởi hành: giờ, sức chứa, giá vé, mở bán / hủy lịch (FR-14, Nguyễn Minh Thức).
 * Biến: $schedule (NMT_sp_admin_schedule_detail), $old (giá trị đang nhập: starts_at, ends_at, capacity, adult_price,
 *       child_price, status), $errors (lỗi theo ô; 'form' = lỗi chung).
 */
$backHref = '/admin/tours/' . $schedule['tour_id'] . '/schedules';
$isCompleted = $schedule['status'] === 'completed';
$isDeparted = (int) $schedule['departed'] === 1;
$held = (int) $schedule['held'];
$activeBookings = (int) $schedule['active_booking_count'];
$statusError = $errors['status'] ?? '';
$statusOptions = [
    'open' => ['label' => 'Mở bán', 'hint' => 'Tự chuyển "Hết chỗ" khi không còn chỗ.'],
    'cancelled' => ['label' => 'Hủy lịch', 'hint' => 'Chỉ hủy được khi không còn yêu cầu đặt tour đang xử lý.'],
];
$seatFacts = [
    'Sức chứa' => $schedule['capacity'] . ' chỗ',
    'Đang giữ' => $held . ' chỗ',
    'Còn nhận' => $schedule['remaining'] . ' chỗ',
    'Yêu cầu đang xử lý' => $activeBookings > 0 ? $activeBookings . ' yêu cầu' : 'Không có',
    'Chờ xác nhận (chưa giữ chỗ)' => (int) $schedule['pending_booking_count'] > 0
        ? $schedule['pending_booking_count'] . ' yêu cầu · ' . $schedule['pending_people'] . ' khách'
        : 'Không có',
];
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url($backHref)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Lịch khởi hành của tour
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Sửa lịch khởi hành</h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($schedule['status']) ?>"><?= e(schedule_status_label($schedule['status'])) ?></span>
                    <?= e($schedule['tour_title']) ?> · <?= e(format_datetime($schedule['starts_at'])) ?>
                </p>
            </header>

<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Chưa lưu được: vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="schedule-edit-title">
                        <h2 class="lt-panel__title" id="schedule-edit-title">Thông tin lịch</h2>
<?php if ($isCompleted): ?>
                        <p class="lt-empty">Lịch đã hoàn thành nên không sửa được nữa.</p>
<?php else: ?>
                        <form class="lt-admin-form" action="<?= e(url('/admin/schedules/' . $schedule['schedule_id'] . '/edit')) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
<?php
$prefix = 'schedule-edit';
$lockTimes = $isDeparted;
$heldSeats = $held;
require __DIR__ . '/fields.php';
?>
<?php if ($isDeparted): ?>
                            <input type="hidden" name="status" value="<?= e($old['status']) ?>">
                            <p class="lt-admin-hint">Lịch đã khởi hành nên không mở bán lại hay hủy được.</p>
<?php if ($statusError !== ''): ?>
                            <p class="lt-admin-error" id="schedule-status-error" role="alert"><?= e($statusError) ?></p>
<?php endif; ?>
<?php else: ?>
                            <fieldset class="lt-choices<?= $statusError !== '' ? ' is-invalid' : '' ?>"<?= $statusError !== '' ? ' aria-describedby="schedule-status-error"' : '' ?>>
                                <legend class="lt-admin-label">Trạng thái</legend>
<?php foreach ($statusOptions as $value => $option): ?>
                                <label class="lt-choice">
                                    <input type="radio" name="status" value="<?= e($value) ?>" required<?= $old['status'] === $value ? ' checked' : '' ?>>
                                    <span><strong><?= e($option['label']) ?></strong><br><span class="lt-muted"><?= e($option['hint']) ?></span></span>
                                </label>
<?php endforeach; ?>
<?php if ($statusError !== ''): ?>
                                <p class="lt-admin-error" id="schedule-status-error"><?= e($statusError) ?></p>
<?php endif; ?>
                            </fieldset>
<?php endif; ?>
                            <p class="lt-admin-hint">Giá mới chỉ áp dụng cho yêu cầu đặt tour gửi sau khi lưu; yêu cầu đã gửi giữ giá lúc đặt.</p>
                            <div class="lt-admin__actions">
                                <button class="lt-btn lt-btn--primary" type="submit">Lưu thay đổi</button>
                                <a class="lt-btn lt-btn--outline" href="<?= e(url($backHref)) ?>">Hủy</a>
                            </div>
                        </form>
<?php endif; ?>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="schedule-seats-title">
                        <h2 class="lt-panel__title" id="schedule-seats-title">Tình trạng chỗ</h2>
                        <dl class="lt-fields lt-fields--compact">
<?php foreach ($seatFacts as $label => $value): ?>
                            <dt><?= e($label) ?></dt>
                            <dd><?= e($value) ?></dd>
<?php endforeach; ?>
                        </dl>
                        <p class="lt-admin-hint">Đang giữ = sức chứa - còn nhận. Còn nhận sau khi lưu = sức chứa mới - đang giữ.</p>
                    </section>
                </div>
            </div>
        </main>
    </div>
</div>
