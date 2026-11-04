<?php declare(strict_types=1); ?>
<?php
/*
 * Voucher tham gia tour (Sprint 4, 4.5.4.2 – Lê Trung Phong): chỉ hiện khi đơn đã xác nhận nhờ thanh toán đã xác minh.
 * Khi in (Ctrl+P hoặc nút "In voucher") chỉ còn phần voucher.
 * Biến: $booking (NTK_sp_customer_booking_detail, có voucher_code), $lines, $extras, $passengers, $title.
 */
$code = (string) $booking['code'];
$meetingPoint = trim((string) ($booking['meeting_point'] ?? ''));
$meetingLines = [departure_text((string) $booking['pickup_mode'], $meetingPoint)];
if ($booking['pickup_mode'] === 'hotel_pickup' && $meetingPoint !== '') {
    $meetingLines[] = 'Khu vực đón: ' . $meetingPoint;
}
?>
<main id="main-content" class="lt-detail lt-book" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav class="lt-no-print" aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings')) ?>">Đơn của tôi</a></li>
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings/' . $code)) ?>"><?= e($code) ?></a></li>
                <li class="breadcrumb-item active" aria-current="page">Voucher</li>
            </ol>
        </nav>

        <div class="lt-book-actions lt-no-print">
            <a class="lt-btn lt-btn--outline" href="<?= e(url('/bookings/' . $code)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Về trang đơn
            </a>
            <button class="lt-btn lt-btn--primary js-print" type="button">In voucher</button>
        </div>

        <article class="lt-voucher" aria-labelledby="voucher-title">
            <header class="lt-voucher__head">
                <div>
                    <p class="lt-voucher__brand">LocalTour</p>
                    <h1 class="lt-voucher__title" id="voucher-title">Voucher tham gia tour</h1>
                </div>
                <div class="lt-voucher__code">
                    <span>Mã voucher</span>
                    <strong><?= e($booking['voucher_code']) ?></strong>
                </div>
            </header>

            <dl class="lt-book-summary">
                <div><dt>Tour</dt><dd><strong><?= e($booking['tour_title']) ?></strong></dd></div>
                <div><dt>Mã đơn</dt><dd><?= e($code) ?></dd></div>
                <div><dt>Ngày tham gia</dt><dd><?= e(format_date((string) $booking['starts_at'])) ?></dd></div>
                <div><dt>Giờ</dt><dd><?= e(schedule_time_text((string) $booking['starts_at'], (string) $booking['ends_at'])) ?></dd></div>
                <div>
                    <dt><?= $booking['pickup_mode'] === 'hotel_pickup' ? 'Điểm đón' : 'Điểm gặp' ?></dt>
                    <dd>
<?php foreach ($meetingLines as $meetingLine): ?>
                        <span class="d-block"><?= e($meetingLine) ?></span>
<?php endforeach; ?>
                    </dd>
                </div>
                <div><dt>Tổ chức bởi</dt><dd><?= e($booking['provider_name']) ?></dd></div>
                <div><dt>Người liên hệ</dt><dd><?= e($booking['contact_name']) ?> · <?= e($booking['contact_phone']) ?></dd></div>
            </dl>

            <h2 class="lt-voucher__section">Khách tham gia (<?= e((int) $booking['people']) ?>)</h2>
            <ol class="lt-book-guests">
<?php foreach ($passengers as $passenger): ?>
                <li>
                    <span class="lt-book-guests__name"><?= e($passenger['full_name']) ?></span>
                    <span class="lt-book-guests__type"><?= e(ticket_label((string) $passenger['age_group'])) ?></span>
                </li>
<?php endforeach; ?>
            </ol>

<?php if ($extras !== []): ?>
            <h2 class="lt-voucher__section">Phụ thu và hoạt động tùy chọn</h2>
            <ul class="lt-book-lines">
<?php foreach ($extras as $extra): ?>
                <li><span><?= (int) $extra['quantity'] > 1 ? e((int) $extra['quantity']) . ' × ' : '' ?><?= e($extra['name']) ?></span><span><?= e(format_vnd($extra['line_total_vnd'])) ?></span></li>
<?php endforeach; ?>
            </ul>
<?php endif; ?>

            <footer class="lt-voucher__foot">
                <p>Đã thanh toán <strong><?= e(format_vnd($booking['total_vnd'])) ?></strong> · voucher cấp lúc <?= e(format_datetime((string) $booking['voucher_issued_at'])) ?></p>
                <p>Đưa mã voucher cho hướng dẫn viên khi tới điểm hẹn. Có mặt trước giờ khởi hành 15 phút.</p>
            </footer>
        </article>
    </div>
</main>
