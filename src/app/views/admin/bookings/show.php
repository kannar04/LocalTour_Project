<?php declare(strict_types=1); ?>
<?php
/*
 * Chi tiết yêu cầu đặt tour và form cập nhật trạng thái (FR-25, Nguyễn Tuấn Khôi).
 * Biến: $booking (NTK_sp_admin_booking_detail), $lines (dòng vé), $history (lịch sử, NFR-09),
 *       $nextStatuses (trạng thái được chọn tiếp, [] = trạng thái cuối), $success / $error ('' = không có),
 *       $newStatus, $note (giữ lại lựa chọn khi có lỗi).
 * Đổi ngày hoặc số người không làm ở đây (FR-12, phát triển sau).
 */
$actionLabels = [
    'awaiting_payment' => 'Xác nhận chỗ và giá (chuyển “Chờ thanh toán”, hạn 24 giờ)',
    'confirmed' => 'Xác nhận đã thanh toán (chuyển “Đã xác nhận”)',
    'completed' => 'Tour đã diễn ra (chuyển “Đã hoàn thành”)',
    'rejected' => 'Từ chối yêu cầu',
    'cancelled' => 'Hủy yêu cầu',
];
$refund = (int) $booking['refund_completed_vnd'];
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/admin/bookings')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Danh sách yêu cầu
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Yêu cầu <?= e($booking['code']) ?></h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($booking['status']) ?>"><?= e(booking_status_label($booking['status'])) ?></span>
                    Tạo lúc <?= e(format_datetime($booking['created_at'])) ?>
<?php if ($booking['hold_expires_at'] !== null): ?>
                    · Hạn thanh toán <?= e(format_datetime($booking['hold_expires_at'])) ?>
<?php endif; ?>
                </p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if ($error !== ''): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($error) ?></span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="booking-tour-title">
                        <h2 class="lt-panel__title" id="booking-tour-title">Tour và lịch khởi hành</h2>
                        <dl class="lt-fields">
                            <dt>Tour</dt><dd><?= e($booking['tour_title']) ?></dd>
                            <dt>Khởi hành</dt><dd><?= e(format_datetime($booking['starts_at'])) ?> – <?= e(format_time($booking['ends_at'])) ?> <?= format_date($booking['ends_at']) !== format_date($booking['starts_at']) ? e(format_date($booking['ends_at'])) : '' ?></dd>
                            <dt>Đơn vị tổ chức</dt><dd><?= e($booking['provider_name']) ?> · <?= e($booking['provider_phone']) ?></dd>
                            <dt>Chính sách hủy</dt><dd>Phiên bản <?= e($booking['policy_version']) ?></dd>
                        </dl>

                        <h3 class="lt-panel__subtitle">Vé (<?= e($booking['people']) ?> khách)</h3>
                        <div class="table-responsive">
                            <table class="table lt-table mb-0">
                                <thead>
                                    <tr><th scope="col">Loại vé</th><th scope="col" class="text-right">Số lượng</th><th scope="col" class="text-right">Đơn giá</th><th scope="col" class="text-right">Thành tiền</th></tr>
                                </thead>
                                <tbody>
<?php foreach ($lines as $line): ?>
                                    <tr>
                                        <td><?= e(ticket_label((string) $line['ticket_name'])) ?></td>
                                        <td class="text-right"><?= e($line['quantity']) ?></td>
                                        <td class="text-right"><?= e(format_vnd($line['unit_price_vnd'])) ?></td>
                                        <td class="text-right"><?= e(format_vnd($line['line_total_vnd'])) ?></td>
                                    </tr>
<?php endforeach; ?>
                                </tbody>
                                <tfoot>
                                    <tr><th scope="row" colspan="3">Tổng tiền</th><td class="text-right"><strong><?= e(format_vnd($booking['total_vnd'])) ?></strong></td></tr>
                                </tfoot>
                            </table>
                        </div>
                    </section>

                    <section class="lt-panel" aria-labelledby="booking-contact-title">
                        <h2 class="lt-panel__title" id="booking-contact-title">Khách hàng</h2>
                        <dl class="lt-fields">
                            <dt>Người liên hệ</dt><dd><?= e($booking['contact_name']) ?></dd>
                            <dt>Email</dt><dd><?= e($booking['contact_email']) ?></dd>
                            <dt>Số điện thoại</dt><dd><?= e($booking['contact_phone']) ?></dd>
                            <dt>Tài khoản đặt</dt><dd><?= e($booking['account_name']) ?> · <?= e($booking['account_email']) ?><?= $booking['account_status'] === 'locked' ? ' (đang bị khóa)' : '' ?></dd>
                        </dl>
                    </section>

                    <section class="lt-panel" aria-labelledby="booking-payment-title">
                        <h2 class="lt-panel__title" id="booking-payment-title">Thanh toán</h2>
<?php if ($booking['payment_status'] === null): ?>
                        <p class="lt-empty">Chưa có khoản thanh toán nào.</p>
<?php else: ?>
                        <dl class="lt-fields">
                            <dt>Trạng thái</dt><dd><span class="lt-badge lt-badge--<?= e($booking['payment_status']) ?>"><?= e(payment_status_label($booking['payment_status'])) ?></span></dd>
                            <dt>Phương thức</dt><dd><?= e(payment_method_label($booking['payment_method'])) ?></dd>
                            <dt>Số tiền</dt><dd><?= e(format_vnd($booking['payment_amount_vnd'])) ?></dd>
                            <dt>Mã giao dịch</dt><dd><?= e(or_missing($booking['provider_txn_id'])) ?></dd>
                            <dt>Thời điểm thanh toán</dt><dd><?= $booking['paid_at'] !== null ? e(format_datetime($booking['paid_at'])) : 'Chưa có' ?></dd>
<?php if ($refund > 0): ?>
                            <dt>Đã hoàn tiền</dt><dd><?= e(format_vnd($refund)) ?></dd>
<?php endif; ?>
                        </dl>
<?php endif; ?>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="booking-action-title">
                        <h2 class="lt-panel__title" id="booking-action-title">Cập nhật trạng thái</h2>
<?php if ($nextStatuses === []): ?>
                        <p class="lt-empty">Yêu cầu đã ở trạng thái cuối (“<?= e(booking_status_label($booking['status'])) ?>”), không cập nhật được nữa.</p>
<?php else: ?>
                        <form action="<?= e(url('/admin/bookings/' . $booking['booking_id'] . '/status')) ?>" method="post" class="lt-admin-form">
                            <?= csrf_field() ?>
                            <fieldset class="lt-choices">
                                <legend class="lt-admin-label">Trạng thái mới</legend>
<?php foreach ($nextStatuses as $value): ?>
                                <label class="lt-choice">
                                    <input type="radio" name="status" value="<?= e($value) ?>" required<?= $value === $newStatus ? ' checked' : '' ?>>
                                    <span><?= e($actionLabels[$value] ?? booking_status_label($value)) ?></span>
                                </label>
<?php endforeach; ?>
                            </fieldset>
                            <label class="lt-admin-label" for="status-note">Lý do / ghi chú</label>
                            <textarea class="lt-admin-input" id="status-note" name="note" rows="3" maxlength="255"><?= e($note) ?></textarea>
                            <p class="lt-admin-hint">Bắt buộc khi từ chối hoặc hủy. Xác nhận đã thanh toán cần khoản VNPay thành công hoặc khoản chuyển khoản VietQR đang chờ đối chiếu (thao tác này ghi nhận khoản VietQR là đã thanh toán).</p>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Cập nhật trạng thái</button>
                        </form>
<?php endif; ?>
                    </section>

                    <section class="lt-panel" aria-labelledby="booking-history-title">
                        <h2 class="lt-panel__title" id="booking-history-title">Lịch sử xử lý</h2>
<?php if ($history === []): ?>
                        <p class="lt-empty">Chưa có lần xử lý nào.</p>
<?php else: ?>
                        <ol class="lt-history">
<?php foreach ($history as $log): ?>
                            <li class="lt-history__item">
                                <p class="lt-history__head"><?= e(booking_status_label($log['from_status'])) ?> → <strong><?= e(booking_status_label($log['to_status'])) ?></strong></p>
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
