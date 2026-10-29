<?php declare(strict_types=1); ?>
<?php
/*
 * Chi tiết một đơn của khách hàng (M4 mục 8, Nguyễn Tuấn Khôi): trạng thái và bước tiếp theo, lý do từ chối / hủy,
 * chuyến đi, danh sách khách, tiền vé và chính sách hủy đúng phiên bản lúc đặt.
 * Biến: $booking (NTK_sp_customer_booking_detail), $lines (vé), $extras (phụ thu / tùy chọn), $passengers,
 *       $payments (NMT_sp_payment_list), $history (LTP_sp_customer_booking_history), $justCreated (vừa gửi yêu cầu),
 *       $payNotice (kết quả thanh toán: [loại, nội dung] hoặc null), $title.
 * Sprint 4: "Chờ thanh toán" có nút thanh toán VNPay / VietQR và hạn giữ chỗ; đơn đã xác nhận có voucher.
 */
$missing = or_missing(null);
$bookingStatus = (string) $booking['status'];
$statusKey = preg_replace('/[^a-z_]/', '', $bookingStatus);
$isPublic = (int) $booking['tour_public'] === 1;
$tourUrl = url('/tours/' . $booking['tour_id']);
$statusNote = trim((string) ($booking['status_note'] ?? ''));
$code = (string) $booking['code'];
$ticketsVnd = (int) $booking['tickets_vnd'];
$extrasVnd = (int) $booking['extras_vnd'];
$totalVnd = (int) $booking['total_vnd'];
// Đang chờ LocalTour đối chiếu chuyển khoản VietQR: không thanh toán thêm, đơn không bị tự hủy.
$awaitingReconciliation = in_array('awaiting_reconciliation', array_column($payments, 'status'), true);
$hasVoucher = $booking['voucher_code'] !== null && in_array($bookingStatus, ['confirmed', 'completed'], true);
$holdUntil = format_datetime($booking['hold_expires_at'] === null ? null : (string) $booking['hold_expires_at']);
$meetingPoint = trim((string) ($booking['meeting_point'] ?? ''));
$meetingLines = [departure_text((string) $booking['pickup_mode'], $meetingPoint)];
if ($booking['pickup_mode'] === 'hotel_pickup' && $meetingPoint !== '') {
    $meetingLines[] = 'Khu vực đón: ' . $meetingPoint;
}
$hasPolicy = $booking['policy_refund_percent'] !== null;
$policyLines = $hasPolicy ? cancellation_policy_lines($booking['policy_free_before_hours'], $booking['policy_refund_percent']) : [];
$specialRequests = array_values(array_filter(
    array_map(static fn (array $passenger): string => trim((string) ($passenger['special_request'] ?? '')), $passengers),
    static fn (string $request): bool => $request !== ''
));

// Bước tiếp theo theo trạng thái (giống luồng xử lý trong 07_procedures_NTK_admin.sql).
$nextStep = match ($bookingStatus) {
    'pending' => 'LocalTour đang kiểm tra chỗ cho yêu cầu của bạn. Đơn chưa giữ chỗ và chưa thu tiền.',
    'awaiting_payment' => $awaitingReconciliation
        ? 'Bạn đã báo chuyển khoản. LocalTour đang đối chiếu và sẽ xác nhận đơn; chỗ của bạn vẫn được giữ trong lúc chờ.'
        : ((int) $booking['hold_expired'] === 1
            ? 'Đơn đã quá hạn thanh toán và sẽ được hủy, chỗ được trả lại cho lịch.'
            : 'LocalTour đã giữ chỗ và chốt tổng giá. Vui lòng thanh toán bằng VNPay hoặc VietQR'
                . ($holdUntil !== '' ? ' trước ' . $holdUntil : '') . '; quá hạn đơn tự hủy.'),
    'confirmed' => 'Đơn đã được xác nhận. Mang theo voucher (bản in hoặc trên điện thoại) và có mặt ở điểm hẹn trước giờ khởi hành.',
    'completed' => 'Chuyến đi đã hoàn thành. Cảm ơn bạn đã đi tour cùng LocalTour.',
    'rejected' => 'LocalTour không nhận được yêu cầu này. Bạn có thể chọn ngày khác hoặc tour khác.',
    'cancelled' => 'Đơn đã bị hủy.',
    default => '',
};
$isClosed = in_array($bookingStatus, ['rejected', 'cancelled'], true);
// Bước 1 "Thông tin chuyến đi" luôn xong; bước 2 "Thanh toán" đang làm khi chờ thanh toán; bước 3 xong khi đã xác nhận.
$paymentDone = in_array($bookingStatus, ['confirmed', 'completed'], true);
$steps = [
    ['label' => 'Thông tin chuyến đi', 'state' => 'done'],
    ['label' => 'Thanh toán', 'state' => $paymentDone ? 'done' : ($bookingStatus === 'awaiting_payment' ? 'current' : '')],
    ['label' => 'Xác nhận', 'state' => $paymentDone ? 'done' : ''],
];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-book" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/tours')) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings')) ?>">Đơn của tôi</a></li>
                <li class="breadcrumb-item active" aria-current="page"><?= e($booking['code']) ?></li>
            </ol>
        </nav>

<?php if ($payNotice !== null): ?>
<?php if ($payNotice[0] === 'success'): ?>
        <div class="lt-book-success" role="status">
            <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
            <div><p><?= e($payNotice[1]) ?></p></div>
        </div>
<?php else: ?>
        <div class="lt-book-alert" role="alert">
            <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
            <span><?= e($payNotice[1]) ?></span>
        </div>
<?php endif; ?>
<?php endif; ?>

<?php if ($justCreated): ?>
        <div class="lt-book-success" role="status">
            <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
            <div>
                <p class="lt-book-success__title">Đã gửi yêu cầu đặt tour</p>
                <p>Mã đơn của bạn là <strong><?= e($booking['code']) ?></strong>. LocalTour sẽ kiểm tra chỗ và báo kết quả qua email <?= e($booking['contact_email']) ?>.</p>
            </div>
        </div>
<?php endif; ?>

        <div class="lt-book-head">
            <a class="lt-book-back" href="<?= e(url('/bookings')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Đơn của tôi
            </a>
            <div class="lt-book-head__row">
                <h1 class="lt-book-head__title">Đơn <?= e($booking['code']) ?></h1>
                <span class="lt-status lt-status--<?= e($statusKey) ?>"><?= e(booking_status_label($bookingStatus)) ?></span>
            </div>
            <p class="lt-book-head__lead">Gửi lúc <?= e(format_datetime((string) $booking['created_at'])) ?></p>
<?php if (!$isClosed): ?>
            <ol class="lt-steps" aria-label="Tiến trình đơn">
<?php foreach ($steps as $index => $step): ?>
                <li class="lt-steps__item<?= $step['state'] === 'done' ? ' is-done' : ($step['state'] === 'current' ? ' is-current' : '') ?>"<?= $step['state'] === 'current' ? ' aria-current="step"' : '' ?>>
                    <span class="lt-steps__num"><?= $step['state'] === 'done' ? '<span class="lt-icon lt-icon--check" aria-hidden="true"></span><span class="sr-only">Xong: </span>' : e($index + 1) ?></span><?= e($step['label']) ?>
                </li>
<?php endforeach; ?>
            </ol>
<?php endif; ?>
        </div>

        <div class="row">
            <div class="col-12 col-lg-7 col-xl-8">
                <section class="lt-book-card lt-book-state lt-book-state--<?= e($statusKey) ?>" aria-labelledby="order-state-title">
                    <h2 class="lt-book-card__title" id="order-state-title">Trạng thái: <?= e(booking_status_label($bookingStatus)) ?></h2>
                    <p><?= e($nextStep) ?></p>
<?php if ($isClosed): ?>
                    <p class="lt-book-state__reason"><strong>Lý do:</strong> <?= e($statusNote !== '' ? $statusNote : 'LocalTour chưa ghi lý do.') ?></p>
<?php if ($booking['status_changed_at'] !== null): ?>
                    <p class="lt-field__hint">Cập nhật lúc <?= e(format_datetime((string) $booking['status_changed_at'])) ?></p>
<?php endif; ?>
<?php elseif ($bookingStatus === 'awaiting_payment'): ?>
                    <p class="lt-book-state__pay">
                        Số tiền cần thanh toán: <strong><?= e(format_vnd($totalVnd)) ?></strong>
                        · <?= e(payment_status_label($booking['payment_status'] === null ? null : (string) $booking['payment_status'])) ?>
                    </p>
<?php if ($awaitingReconciliation): ?>
                    <a class="lt-btn lt-btn--outline lt-book-state__action" href="<?= e(url('/bookings/' . $code . '/pay/vietqr')) ?>">Xem thông tin chuyển khoản</a>
<?php elseif ((int) $booking['hold_expired'] === 0): ?>
                    <a class="lt-btn lt-btn--primary lt-book-state__action" href="<?= e(url('/bookings/' . $code . '/pay')) ?>">Thanh toán ngay</a>
<?php endif; ?>
<?php elseif ($hasVoucher): ?>
                    <p class="lt-book-state__pay">Mã voucher: <strong><?= e($booking['voucher_code']) ?></strong></p>
                    <a class="lt-btn lt-btn--primary lt-book-state__action" href="<?= e(url('/bookings/' . $code . '/voucher')) ?>">Xem và in voucher</a>
<?php endif; ?>
                </section>

                <section class="lt-book-card" aria-labelledby="order-trip-title">
                    <h2 class="lt-book-card__title" id="order-trip-title">Chuyến đi</h2>
                    <dl class="lt-book-summary">
                        <div>
                            <dt>Tour</dt>
                            <dd>
<?php if ($isPublic): ?>
                                <a href="<?= e($tourUrl) ?>"><?= e($booking['tour_title']) ?></a>
<?php else: ?>
                                <?= e($booking['tour_title']) ?> <span class="lt-field__hint">(tour hiện không hiển thị)</span>
<?php endif; ?>
                            </dd>
                        </div>
                        <div><dt>Điểm đến</dt><dd><?= e(or_missing((string) $booking['destination_name'])) ?></dd></div>
                        <div><dt>Ngày tham gia</dt><dd><?= e(format_date((string) $booking['starts_at'])) ?></dd></div>
                        <div><dt>Giờ</dt><dd><?= e(schedule_time_text((string) $booking['starts_at'], (string) $booking['ends_at'])) ?></dd></div>
                        <div><dt>Thời lượng</dt><dd><?= e(format_duration($booking['duration_minutes'])) ?></dd></div>
                        <div><dt>Ngôn ngữ hướng dẫn</dt><dd><?= e(or_missing(format_languages($booking['language_codes'] === null ? null : (string) $booking['language_codes']))) ?></dd></div>
                        <div>
                            <dt><?= $booking['pickup_mode'] === 'hotel_pickup' ? 'Điểm đón' : 'Điểm gặp' ?></dt>
                            <dd>
<?php foreach ($meetingLines as $meetingLine): ?>
                                <span class="d-block"><?= e($meetingLine) ?></span>
<?php endforeach; ?>
                            </dd>
                        </div>
                        <div><dt>Tổ chức bởi</dt><dd><?= e($booking['provider_name']) ?></dd></div>
                    </dl>
                </section>

                <section class="lt-book-card" aria-labelledby="order-guests-title">
                    <h2 class="lt-book-card__title" id="order-guests-title">Danh sách khách (<?= e((int) $booking['people']) ?>)</h2>
                    <ol class="lt-book-guests">
<?php foreach ($passengers as $passenger): ?>
                        <li>
                            <span class="lt-book-guests__name"><?= e($passenger['full_name']) ?></span>
                            <span class="lt-book-guests__type"><?= e(ticket_label((string) $passenger['age_group'])) ?></span>
                        </li>
<?php endforeach; ?>
                    </ol>
                    <p class="lt-book-request-text"><strong>Yêu cầu đặc biệt:</strong> <?= e($specialRequests !== [] ? implode(' · ', $specialRequests) : 'Không có') ?></p>
                </section>

                <section class="lt-book-card" aria-labelledby="order-contact-title">
                    <h2 class="lt-book-card__title" id="order-contact-title">Người liên hệ</h2>
                    <dl class="lt-book-summary">
                        <div><dt>Họ tên</dt><dd><?= e($booking['contact_name']) ?></dd></div>
                        <div><dt>Email</dt><dd><?= e($booking['contact_email']) ?></dd></div>
                        <div><dt>Số điện thoại</dt><dd><?= e($booking['contact_phone']) ?></dd></div>
                    </dl>
                </section>

<?php if ($payments !== []): ?>
                <section class="lt-book-card" aria-labelledby="order-payments-title">
                    <h2 class="lt-book-card__title" id="order-payments-title">Các lần thanh toán</h2>
                    <ul class="lt-book-payments">
<?php foreach ($payments as $payment): ?>
                        <li>
                            <span>
                                <strong><?= e(payment_method_label((string) $payment['method'])) ?></strong> · <?= e(format_vnd($payment['amount_vnd'])) ?>
                                <span class="lt-field__hint d-block"><?= e(format_datetime((string) $payment['created_at'])) ?><?= $payment['reference'] !== null ? ' · ' . e($payment['reference']) : '' ?></span>
<?php if ($payment['note'] !== null && $payment['status'] === 'failed'): ?>
                                <span class="lt-field__hint d-block"><?= e($payment['note']) ?></span>
<?php endif; ?>
                            </span>
                            <span class="lt-pay-status lt-pay-status--<?= e(preg_replace('/[^a-z_]/', '', (string) $payment['status'])) ?>"><?= e(payment_status_label((string) $payment['status'])) ?></span>
                        </li>
<?php endforeach; ?>
                    </ul>
                </section>
<?php endif; ?>

                <section class="lt-book-card" aria-labelledby="order-history-title">
                    <h2 class="lt-book-card__title" id="order-history-title">Lịch sử đơn</h2>
<?php if ($history === []): ?>
                    <p class="lt-field__hint">Chưa có cập nhật nào.</p>
<?php else: ?>
                    <ol class="lt-book-history">
<?php foreach ($history as $event): ?>
                        <li>
                            <p class="lt-book-history__title"><?= e(booking_history_title($event)) ?></p>
                            <p class="lt-book-history__meta"><?= e(format_datetime((string) $event['created_at'])) ?> · <?= e(booking_history_actor((string) $event['actor'])) ?></p>
<?php if ($event['note'] !== null && trim((string) $event['note']) !== ''): ?>
                            <p class="lt-book-history__note"><?= e($event['note']) ?></p>
<?php endif; ?>
                        </li>
<?php endforeach; ?>
                    </ol>
<?php endif; ?>
                </section>
            </div>

            <div class="col-12 col-lg-5 col-xl-4 lt-detail-aside">
                <aside class="lt-booking lt-book-aside" aria-labelledby="order-price-title">
                    <h2 class="lt-book-aside__title" id="order-price-title">Chi tiết giá</h2>
                    <ul class="lt-book-lines">
<?php foreach ($lines as $line): ?>
                        <li>
                            <span><?= e((int) $line['quantity']) ?> × <?= e(ticket_label((string) $line['ticket_name'])) ?> <span class="lt-book-lines__unit">(<?= e(format_vnd($line['unit_price_vnd'])) ?>)</span></span>
                            <span><?= e(format_vnd($line['line_total_vnd'])) ?></span>
                        </li>
<?php endforeach; ?>
<?php foreach ($extras as $extra): ?>
                        <li>
                            <span><?= (int) $extra['quantity'] > 1 ? e((int) $extra['quantity']) . ' × ' : '' ?><?= e($extra['name']) ?> <span class="lt-book-lines__unit">(<?= e($extra['kind'] === 'surcharge' ? 'phụ thu' : 'tùy chọn') ?>)</span></span>
                            <span><?= e(format_vnd($extra['line_total_vnd'])) ?></span>
                        </li>
<?php endforeach; ?>
<?php if ($ticketsVnd + $extrasVnd !== $totalVnd): ?>
                        <li>
                            <span>Điều chỉnh khi LocalTour chốt giá</span>
                            <span><?= e(($totalVnd > $ticketsVnd + $extrasVnd ? '+' : '−') . format_vnd(abs($totalVnd - $ticketsVnd - $extrasVnd))) ?></span>
                        </li>
<?php endif; ?>
                    </ul>
                    <div class="lt-booking__total">
                        <div class="lt-booking__total-main">
                            <span class="lt-booking__total-label">Tổng tiền</span>
                            <span class="lt-booking__total-formula"><?= $bookingStatus === 'pending' ? 'Giá lúc đặt, LocalTour sẽ chốt · VND' : 'Giá LocalTour đã chốt · VND' ?></span>
                        </div>
                        <strong class="lt-booking__total-value"><?= e(format_vnd($totalVnd)) ?></strong>
                    </div>

                    <div class="lt-booking__policy">
                        <span class="lt-icon lt-icon--shield" aria-hidden="true"></span>
                        <div>
<?php if ($hasPolicy): ?>
<?php foreach ($policyLines as $policyLine): ?>
                            <p><?= e($policyLine) ?></p>
<?php endforeach; ?>
                            <p class="lt-booking__policy-note">Chính sách hủy phiên bản <?= e((int) $booking['policy_version']) ?>, áp dụng từ lúc đặt.</p>
<?php else: ?>
                            <p>Chính sách hủy: <?= e($missing) ?></p>
<?php endif; ?>
                        </div>
                    </div>

                    <a class="lt-btn lt-btn--outline lt-btn--block" href="<?= e(url('/bookings')) ?>">
                        <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                        Đơn của tôi
                    </a>
                </aside>
            </div>
        </div>
    </div>
</main>
