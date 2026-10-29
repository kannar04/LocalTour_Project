<?php declare(strict_types=1); ?>
<?php
/*
 * Chi tiết yêu cầu đặt tour và form cập nhật trạng thái (FR-25, Nguyễn Tuấn Khôi).
 * Biến: $booking (NTK_sp_admin_booking_detail, gồm số chỗ của lịch), $lines (dòng vé), $extras (phụ thu / tùy chọn
 *       khách chọn), $payments (các khoản thanh toán), $passengers (danh sách khách),
 *       $history (LTP_sp_booking_history: thao tác của khách, hệ thống, VNPay và quản trị viên, NFR-09),
 *       $nextStatuses (trạng thái được chọn tiếp, [] = trạng thái cuối), $success / $error ('' = không có),
 *       $newStatus, $note, $totalInput (giữ lại lựa chọn khi có lỗi).
 * Sprint 4: chốt tổng giá khi xác nhận chỗ (4.4.3.2), đối chiếu chuyển khoản VietQR ngay ở khoản thanh toán (4.5.3.2).
 * Đổi ngày hoặc số người không làm ở đây (FR-12, phát triển sau).
 */
$actionLabels = [
    'awaiting_payment' => 'Xác nhận chỗ và giá (giữ chỗ, chuyển “Chờ thanh toán”, hạn 24 giờ)',
    'confirmed' => 'Xác nhận đã thanh toán (chuyển “Đã xác nhận”)',
    'completed' => 'Tour đã diễn ra (chuyển “Đã hoàn thành”)',
    'rejected' => 'Từ chối yêu cầu',
    'cancelled' => 'Hủy yêu cầu',
];
$refund = (int) $booking['refund_completed_vnd'];
$scheduleLabels = ['open' => 'đang mở', 'full' => 'hết chỗ', 'cancelled' => 'đã hủy', 'completed' => 'đã diễn ra'];
$scheduleState = $scheduleLabels[(string) $booking['schedule_status']] ?? (string) $booking['schedule_status'];
// Đơn đang giữ chỗ của lịch: đã xác nhận chỗ, chưa hủy và chưa hoàn thành.
$holdsSeats = in_array($booking['status'], ['awaiting_payment', 'confirmed'], true);
$ticketsVnd = (int) $booking['tickets_vnd'];
$extrasVnd = (int) $booking['extras_vnd'];
$totalVnd = (int) $booking['total_vnd'];
$refundRequested = (int) $booking['refund_requested_vnd'];
$canSetTotal = in_array('awaiting_payment', $nextStatuses, true);
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
                            <dt>Chỗ của lịch</dt><dd>Còn <?= e((int) $booking['schedule_remaining']) ?>/<?= e((int) $booking['schedule_capacity']) ?> chỗ · lịch <?= e($scheduleState) ?><?= $holdsSeats ? ' · đơn này đang giữ ' . e((int) $booking['people']) . ' chỗ' : '' ?></dd>
                            <dt>Đơn vị tổ chức</dt><dd><?= e($booking['provider_name']) ?> · <?= e($booking['provider_phone']) ?></dd>
                            <dt>Chính sách hủy</dt><dd>Phiên bản <?= e($booking['policy_version']) ?></dd>
                        </dl>

                        <h3 class="lt-panel__subtitle">Vé và phụ thu (<?= e($booking['people']) ?> khách)</h3>
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
<?php foreach ($extras as $extra): ?>
                                    <tr>
                                        <td><?= e($extra['kind'] === 'surcharge' ? 'Phụ thu' : 'Tùy chọn') ?>: <?= e($extra['name']) ?><?php if (trim((string) $extra['price_unit']) !== ''): ?> <span class="lt-table__sub">/ <?= e($extra['price_unit']) ?></span><?php endif; ?></td>
                                        <td class="text-right"><?= e($extra['quantity']) ?></td>
                                        <td class="text-right"><?= e(format_vnd($extra['unit_price_vnd'])) ?></td>
                                        <td class="text-right"><?= e(format_vnd($extra['line_total_vnd'])) ?></td>
                                    </tr>
<?php endforeach; ?>
                                </tbody>
                                <tfoot>
<?php if ($ticketsVnd + $extrasVnd !== $totalVnd): ?>
                                    <tr><th scope="row" colspan="3">Theo giá lúc đặt</th><td class="text-right"><?= e(format_vnd($ticketsVnd + $extrasVnd)) ?></td></tr>
                                    <tr><th scope="row" colspan="3">Tổng giá đã chốt</th><td class="text-right"><strong><?= e(format_vnd($totalVnd)) ?></strong></td></tr>
<?php else: ?>
                                    <tr><th scope="row" colspan="3">Tổng tiền</th><td class="text-right"><strong><?= e(format_vnd($totalVnd)) ?></strong></td></tr>
<?php endif; ?>
                                </tfoot>
                            </table>
                        </div>

                        <h3 class="lt-panel__subtitle">Danh sách khách</h3>
<?php if ($passengers === []): ?>
                        <p class="lt-empty">Yêu cầu chưa có danh sách khách.</p>
<?php else: ?>
                        <ol class="lt-guest-list">
<?php foreach ($passengers as $passenger): ?>
                            <li>
                                <?= e($passenger['full_name']) ?> <span class="lt-guest-list__type">· <?= e(ticket_label((string) $passenger['age_group'])) ?></span>
<?php if ($passenger['special_request'] !== null && trim((string) $passenger['special_request']) !== ''): ?>
                                <p class="lt-guest-list__note">Yêu cầu đặc biệt: <?= e($passenger['special_request']) ?></p>
<?php endif; ?>
                            </li>
<?php endforeach; ?>
                        </ol>
<?php endif; ?>
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

                    <section class="lt-panel" id="payments" aria-labelledby="booking-payment-title">
                        <h2 class="lt-panel__title" id="booking-payment-title">Thanh toán</h2>
<?php if ($booking['voucher_code'] !== null): ?>
                        <p class="lt-admin-hint">Voucher <strong><?= e($booking['voucher_code']) ?></strong> · cấp lúc <?= e(format_datetime($booking['voucher_issued_at'])) ?></p>
<?php endif; ?>
<?php if ($refund > 0): ?>
                        <p class="lt-admin-hint">Đã hoàn tiền <?= e(format_vnd($refund)) ?>.</p>
<?php endif; ?>
<?php if ($refundRequested > 0): ?>
                        <div class="lt-alert lt-alert--warning" role="note"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Có khoản <?= e(format_vnd($refundRequested)) ?> khách đã trả sau khi đơn không còn chờ thanh toán: cần hoàn tiền cho khách.</span></div>
<?php endif; ?>
<?php if ($payments === []): ?>
                        <p class="lt-empty">Chưa có khoản thanh toán nào.</p>
<?php else: ?>
                        <ul class="lt-pay-list">
<?php foreach ($payments as $payment): ?>
<?php $reconcile = $payment['method'] === 'vietqr' && $payment['status'] === 'awaiting_reconciliation'; ?>
                            <li class="lt-pay-item<?= $reconcile ? ' is-waiting' : '' ?>">
                                <div class="lt-pay-item__head">
                                    <span><strong><?= e(payment_method_label($payment['method'])) ?></strong> · <?= e(format_vnd($payment['amount_vnd'])) ?></span>
                                    <span class="lt-badge lt-badge--<?= e($payment['status']) ?>"><?= e(payment_status_label($payment['status'])) ?></span>
                                </div>
                                <dl class="lt-fields lt-fields--compact">
                                    <dt><?= $payment['method'] === 'vietqr' ? 'Nội dung CK' : 'Mã thanh toán' ?></dt><dd><code><?= e(or_missing($payment['reference'])) ?></code></dd>
<?php if ($payment['method'] === 'vnpay' && $payment['provider_txn_id'] !== null): ?>
                                    <dt>Mã GD VNPay</dt><dd><?= e($payment['provider_txn_id']) ?><?= $payment['bank_code'] !== null ? ' · ' . e($payment['bank_code']) : '' ?></dd>
<?php endif; ?>
                                    <dt>Tạo lúc</dt><dd><?= e(format_datetime($payment['created_at'])) ?></dd>
<?php if ($payment['submitted_at'] !== null): ?>
                                    <dt>Khách báo CK</dt><dd><?= e(format_datetime($payment['submitted_at'])) ?></dd>
<?php endif; ?>
<?php if ($payment['paid_at'] !== null): ?>
                                    <dt>Thanh toán lúc</dt><dd><?= e(format_datetime($payment['paid_at'])) ?></dd>
<?php endif; ?>
<?php if ($payment['note'] !== null): ?>
                                    <dt>Ghi chú</dt><dd><?= e($payment['note']) ?></dd>
<?php endif; ?>
                                </dl>
<?php if ($reconcile): ?>
                                <form action="<?= e(url('/admin/payments/' . $payment['payment_id'] . '/decide')) ?>" method="post" class="lt-admin-form lt-pay-item__form">
                                    <?= csrf_field() ?>
                                    <p class="lt-admin-hint">Kiểm tra sao kê tài khoản nhận tiền: đúng số tiền <?= e(format_vnd($payment['amount_vnd'])) ?> và nội dung <strong><?= e($payment['reference']) ?></strong>.</p>
                                    <label class="lt-admin-label" for="pay-note-<?= e($payment['payment_id']) ?>">Lý do (bắt buộc khi không khớp)</label>
                                    <textarea class="lt-admin-input" id="pay-note-<?= e($payment['payment_id']) ?>" name="note" rows="2" maxlength="255"></textarea>
                                    <div class="lt-pay-item__actions">
                                        <button class="lt-btn lt-btn--primary" type="submit" name="decision" value="confirm">Đã nhận tiền</button>
                                        <button class="lt-btn lt-btn--danger" type="submit" name="decision" value="reject">Không khớp</button>
                                    </div>
                                </form>
<?php endif; ?>
                            </li>
<?php endforeach; ?>
                        </ul>
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
<?php if ($canSetTotal): ?>
                            <label class="lt-admin-label" for="status-total">Tổng giá chốt (VND)</label>
                            <input class="lt-admin-input" id="status-total" name="total_vnd" type="text" inputmode="numeric" maxlength="13"
                                   value="<?= e($totalInput !== '' ? $totalInput : (string) $totalVnd) ?>" aria-describedby="status-total-hint">
                            <p class="lt-admin-hint" id="status-total-hint">Chỉ dùng khi xác nhận chỗ và giá. Giá lúc đặt: vé <?= e(format_vnd($ticketsVnd)) ?><?= $extrasVnd > 0 ? ' + phụ thu / tùy chọn ' . e(format_vnd($extrasVnd)) : '' ?>. Đổi tổng giá (vd. phụ thu chưa có giá) cần ghi lý do; khách thanh toán đúng số này.</p>
<?php endif; ?>
                            <label class="lt-admin-label" for="status-note">Lý do / ghi chú</label>
                            <textarea class="lt-admin-input" id="status-note" name="note" rows="3" maxlength="255"><?= e($note) ?></textarea>
<?php if ($booking['status'] === 'pending'): ?>
                            <p class="lt-admin-hint">Xác nhận chỗ sẽ giữ <?= e((int) $booking['people']) ?> chỗ của lịch (lịch còn <?= e((int) $booking['schedule_remaining']) ?> chỗ). Từ chối hoặc hủy yêu cầu chờ xác nhận không đổi số chỗ.</p>
<?php elseif ($holdsSeats): ?>
                            <p class="lt-admin-hint">Hủy đơn này sẽ trả lại <?= e((int) $booking['people']) ?> chỗ cho lịch.</p>
<?php endif; ?>
                            <p class="lt-admin-hint">Bắt buộc khi từ chối, hủy hoặc đổi tổng giá. VNPay thành công tự xác nhận đơn; chuyển khoản VietQR nên đối chiếu ở mục “Thanh toán” bên trái.</p>
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
                                <p class="lt-history__head"><strong><?= e(booking_history_title($log)) ?></strong></p>
                                <p class="lt-history__meta"><?= e(format_datetime($log['created_at'])) ?> · <?= e($log['actor_name'] ?? booking_history_actor($log['actor'])) ?><?= $log['actor'] === 'customer' ? ' (khách)' : '' ?></p>
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
