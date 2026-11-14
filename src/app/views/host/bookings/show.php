<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: chi tiết một đơn đặt tour của tour thuộc đơn vị, chỉ xem (Nguyễn Tuấn Khôi).
 * Biến: $booking (NTK_sp_host_booking_detail), $lines (dòng vé), $extras (phụ thu / tùy chọn khách chọn),
 *       $passengers (danh sách khách), $changeRequests (NTK_sp_host_booking_change_list: yêu cầu đổi ngày / hủy tour).
 * Trang không có form: đơn vị không đổi được trạng thái đơn, không xử lý đổi ngày / hủy, không thấy email của khách,
 * mã giao dịch thanh toán hay số tiền hoàn. Mọi việc đó do quản trị viên LocalTour làm.
 */
$bookingStatus = (string) $booking['status'];
$scheduleLabels = ['open' => 'đang mở bán', 'full' => 'hết chỗ', 'cancelled' => 'đã hủy', 'completed' => 'đã diễn ra'];
$scheduleState = $scheduleLabels[(string) $booking['schedule_status']] ?? (string) $booking['schedule_status'];
// Đơn đang giữ chỗ của lịch: chờ thanh toán (giữ chỗ ngay lúc khách đặt) hoặc đã xác nhận, chưa hủy và chưa hoàn thành.
$holdsSeats = in_array($bookingStatus, ['awaiting_payment', 'confirmed'], true);
$ticketsVnd = (int) $booking['tickets_vnd'];
$extrasVnd = (int) $booking['extras_vnd'];
$totalVnd = (int) $booking['total_vnd'];
$statusNotes = [
    'pending' => 'Đơn tạo theo quy trình cũ, đang chờ quản trị viên LocalTour xác nhận chỗ và giá; đơn chưa giữ chỗ của lịch.',
    'awaiting_payment' => 'Khách đã đặt và đang chờ thanh toán. Đơn giữ chỗ của lịch tới hạn thanh toán; quá hạn chưa thanh toán thì đơn tự hủy và chỗ được trả lại.',
    'confirmed' => 'Khách đã thanh toán và nhận voucher. Hãy chuẩn bị đón khách theo danh sách bên dưới.',
    'completed' => 'Tour đã diễn ra.',
    'rejected' => 'LocalTour đã từ chối yêu cầu này, khách không tham gia.',
    'cancelled' => 'Đơn đã hủy, khách không tham gia.',
];
$showVoucher = $booking['voucher_code'] !== null && in_array($bookingStatus, ['confirmed', 'completed'], true);
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/host/bookings')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Đơn đặt tour
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Đơn <?= e($booking['code']) ?></h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($bookingStatus) ?>"><?= e(booking_status_label($bookingStatus)) ?></span>
                    Khách đặt lúc <?= e(format_datetime($booking['created_at'])) ?>
<?php if ($booking['hold_expires_at'] !== null): ?>
                    · Hạn thanh toán <?= e(format_datetime($booking['hold_expires_at'])) ?>
<?php endif; ?>
                </p>
            </header>

            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span><?= e($statusNotes[$bookingStatus] ?? '') ?> Trang này chỉ để xem: cần đổi gì ở đơn, liên hệ quản trị viên LocalTour.</span></div>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="booking-tour-title">
                        <h2 class="lt-panel__title" id="booking-tour-title">Tour và lịch khởi hành</h2>
                        <dl class="lt-fields">
                            <dt>Tour</dt><dd><a href="<?= e(url('/host/tours/' . $booking['tour_id'])) ?>"><?= e($booking['tour_title']) ?></a></dd>
<?php if ($booking['package_name'] !== null): ?>
                            <dt>Gói tour</dt><dd><?= e($booking['package_name']) ?></dd>
<?php endif; ?>
                            <dt>Khởi hành</dt><dd><?= e(format_datetime($booking['starts_at'])) ?> – <?= e(format_time($booking['ends_at'])) ?> <?= format_date($booking['ends_at']) !== format_date($booking['starts_at']) ? e(format_date($booking['ends_at'])) : '' ?></dd>
                            <dt>Chỗ của lịch</dt><dd>Còn <?= e((int) $booking['schedule_remaining']) ?>/<?= e((int) $booking['schedule_capacity']) ?> chỗ · lịch <?= e($scheduleState) ?><?= $holdsSeats ? ' · đơn này đang giữ ' . e((int) $booking['people']) . ' chỗ' : '' ?></dd>
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
                                    <tr><th scope="row" colspan="3">Tổng giá LocalTour đã chốt với khách</th><td class="text-right"><strong><?= e(format_vnd($totalVnd)) ?></strong></td></tr>
<?php else: ?>
                                    <tr><th scope="row" colspan="3">Tổng tiền</th><td class="text-right"><strong><?= e(format_vnd($totalVnd)) ?></strong></td></tr>
<?php endif; ?>
                                </tfoot>
                            </table>
                        </div>

                        <h3 class="lt-panel__subtitle">Danh sách khách</h3>
<?php if ($passengers === []): ?>
                        <p class="lt-empty">Đơn chưa có danh sách khách.</p>
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
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="booking-contact-title">
                        <h2 class="lt-panel__title" id="booking-contact-title">Khách liên hệ và thanh toán</h2>
                        <dl class="lt-fields">
                            <dt>Người liên hệ</dt><dd><?= e($booking['contact_name']) ?></dd>
                            <dt>Số điện thoại</dt><dd><?= e($booking['contact_phone']) ?></dd>
                            <dt>Email</dt><dd><?= e(or_missing($booking['contact_email'] ?? null)) ?></dd>
                            <dt>Thanh toán</dt><dd><span class="lt-badge lt-badge--<?= e($booking['payment_status'] ?? 'none') ?>"><?= e(payment_status_label($booking['payment_status'])) ?></span></dd>
<?php if ($showVoucher): ?>
                            <dt>Mã voucher</dt><dd><strong><?= e($booking['voucher_code']) ?></strong></dd>
<?php endif; ?>
                        </dl>
<?php if ($showVoucher): ?>
                        <p class="lt-admin-hint">Khách đưa voucher có mã này khi tới điểm hẹn.</p>
<?php endif; ?>
                        <p class="lt-admin-hint">Khách thanh toán cho LocalTour. Việc đối chiếu và hoàn tiền do quản trị viên LocalTour xử lý.</p>
                    </section>

                    <section class="lt-panel" aria-labelledby="booking-change-title">
                        <h2 class="lt-panel__title" id="booking-change-title">Yêu cầu đổi ngày / hủy tour</h2>
<?php if ($changeRequests === []): ?>
                        <p class="lt-empty">Khách chưa gửi yêu cầu đổi ngày hay hủy tour nào cho đơn này.</p>
<?php else: ?>
                        <ol class="lt-history">
<?php foreach ($changeRequests as $changeRequest): ?>
                            <li class="lt-history__item">
                                <p class="lt-history__head">
                                    <strong><?= e(change_request_type_label((string) $changeRequest['type'])) ?></strong>
                                    · <span class="lt-badge lt-badge--<?= e($changeRequest['status']) ?>"><?= e(change_request_status_label((string) $changeRequest['status'])) ?></span>
                                </p>
                                <p class="lt-history__meta">Khách gửi lúc <?= e(format_datetime((string) $changeRequest['created_at'])) ?><?= $changeRequest['requested_starts_at'] !== null ? ' · xin đổi sang lịch ' . e(format_datetime((string) $changeRequest['requested_starts_at'])) : '' ?></p>
                                <p class="lt-history__note">Lý do của khách: <?= e($changeRequest['reason']) ?></p>
<?php if ($changeRequest['result_note'] !== null): ?>
                                <p class="lt-history__note">LocalTour trả lời (<?= e(format_datetime((string) $changeRequest['handled_at'])) ?>): <?= e($changeRequest['result_note']) ?></p>
<?php endif; ?>
                            </li>
<?php endforeach; ?>
                        </ol>
<?php if (in_array('pending', array_column($changeRequests, 'status'), true)): ?>
                        <p class="lt-admin-hint">Yêu cầu đang chờ quản trị viên LocalTour xử lý. Đơn vị sẽ thấy kết quả ở đây.</p>
<?php endif; ?>
<?php endif; ?>
                    </section>
                </div>
            </div>
        </main>
    </div>
</div>
