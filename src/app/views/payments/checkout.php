<?php declare(strict_types=1); ?>
<?php
/*
 * Chọn phương thức thanh toán (Sprint 4, 4.5.1.1 – Nguyễn Minh Thức): VNPay (sandbox) hoặc chuyển khoản VietQR
 * cho đơn "Chờ thanh toán". Số tiền là tổng giá LocalTour đã chốt.
 * Biến: $booking (NTK_sp_customer_booking_detail), $lines, $extras, $vnpayEnabled, $vietqrEnabled,
 *       $error ('' = không có), $title.
 */
$code = (string) $booking['code'];
$holdUntil = format_datetime($booking['hold_expires_at'] === null ? null : (string) $booking['hold_expires_at']);
$totalVnd = (int) $booking['total_vnd'];
$adjustment = $totalVnd - (int) $booking['tickets_vnd'] - (int) $booking['extras_vnd'];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-book" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings')) ?>">Đơn của tôi</a></li>
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings/' . $code)) ?>"><?= e($code) ?></a></li>
                <li class="breadcrumb-item active" aria-current="page">Thanh toán</li>
            </ol>
        </nav>

        <div class="lt-book-head">
            <a class="lt-book-back" href="<?= e(url('/bookings/' . $code)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Đơn <?= e($code) ?>
            </a>
            <h1 class="lt-book-head__title">Thanh toán đơn <?= e($code) ?></h1>
<?php if ($holdUntil !== ''): ?>
            <p class="lt-book-head__lead">LocalTour giữ chỗ tới <strong><?= e($holdUntil) ?></strong>. Quá hạn chưa thanh toán, đơn tự hủy và chỗ được trả lại cho lịch.</p>
<?php endif; ?>
            <ol class="lt-steps" aria-label="Tiến trình đơn">
                <li class="lt-steps__item is-done"><span class="lt-steps__num"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span class="sr-only">Xong: </span></span>Thông tin chuyến đi</li>
                <li class="lt-steps__item is-current" aria-current="step"><span class="lt-steps__num">2</span>Thanh toán</li>
                <li class="lt-steps__item"><span class="lt-steps__num">3</span>Xác nhận</li>
            </ol>
        </div>

<?php if ($error !== ''): ?>
        <div class="lt-book-alert" role="alert">
            <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
            <span><?= e($error) ?></span>
        </div>
<?php endif; ?>

        <div class="row">
            <div class="col-12 col-lg-7 col-xl-8">
                <section class="lt-book-card" aria-labelledby="pay-method-title">
                    <h2 class="lt-book-card__title" id="pay-method-title">Chọn phương thức thanh toán</h2>
                    <p class="lt-field__hint">Môi trường thử nghiệm của đồ án: VNPay chạy sandbox, vui lòng không chuyển tiền thật.</p>

                    <div class="lt-pay-methods">
                        <form class="lt-pay-method" action="<?= e(url('/bookings/' . $code . '/pay/vnpay')) ?>" method="post">
                            <?= csrf_field() ?>
                            <h3 class="lt-pay-method__title">VNPay</h3>
                            <p class="lt-pay-method__text">Thẻ ATM nội địa, thẻ quốc tế hoặc QR ngân hàng qua cổng VNPay. Đơn được xác nhận ngay khi thanh toán thành công.</p>
<?php if ($vnpayEnabled): ?>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Thanh toán qua VNPay</button>
<?php else: ?>
                            <button class="lt-btn lt-btn--outline lt-btn--block" type="button" disabled>VNPay đang tạm ngưng</button>
<?php endif; ?>
                        </form>

                        <form class="lt-pay-method" action="<?= e(url('/bookings/' . $code . '/pay/vietqr')) ?>" method="post">
                            <?= csrf_field() ?>
                            <h3 class="lt-pay-method__title">Chuyển khoản VietQR</h3>
                            <p class="lt-pay-method__text">Quét mã bằng ứng dụng ngân hàng, MoMo hoặc ZaloPay. LocalTour đối chiếu chuyển khoản rồi xác nhận đơn; chỗ được giữ trong lúc chờ đối chiếu.</p>
<?php if ($vietqrEnabled): ?>
                            <button class="lt-btn lt-btn--outline lt-btn--block" type="submit">Lấy mã VietQR</button>
<?php else: ?>
                            <button class="lt-btn lt-btn--outline lt-btn--block" type="button" disabled>VietQR đang tạm ngưng</button>
<?php endif; ?>
                        </form>
                    </div>
                </section>
            </div>

            <div class="col-12 col-lg-5 col-xl-4 lt-detail-aside">
                <aside class="lt-booking lt-book-aside" aria-labelledby="pay-summary-title">
                    <h2 class="lt-book-aside__title" id="pay-summary-title"><?= e($booking['tour_title']) ?></h2>
                    <dl class="lt-book-summary">
                        <div><dt>Ngày</dt><dd><?= e(format_date((string) $booking['starts_at'])) ?> · <?= e(schedule_time_text((string) $booking['starts_at'], (string) $booking['ends_at'])) ?></dd></div>
                        <div><dt>Số khách</dt><dd><?= e((int) $booking['people']) ?> khách</dd></div>
                    </dl>
                    <ul class="lt-book-lines">
<?php foreach ($lines as $line): ?>
                        <li>
                            <span><?= e((int) $line['quantity']) ?> × <?= e(ticket_label((string) $line['ticket_name'])) ?></span>
                            <span><?= e(format_vnd($line['line_total_vnd'])) ?></span>
                        </li>
<?php endforeach; ?>
<?php foreach ($extras as $extra): ?>
                        <li>
                            <span><?= (int) $extra['quantity'] > 1 ? e((int) $extra['quantity']) . ' × ' : '' ?><?= e($extra['name']) ?></span>
                            <span><?= e(format_vnd($extra['line_total_vnd'])) ?></span>
                        </li>
<?php endforeach; ?>
<?php if ($adjustment !== 0): ?>
                        <li>
                            <span>Điều chỉnh khi LocalTour chốt giá</span>
                            <span><?= e(($adjustment > 0 ? '+' : '−') . format_vnd(abs($adjustment))) ?></span>
                        </li>
<?php endif; ?>
                    </ul>
                    <div class="lt-booking__total">
                        <div class="lt-booking__total-main">
                            <span class="lt-booking__total-label">Cần thanh toán</span>
                            <span class="lt-booking__total-formula">Giá LocalTour đã chốt · VND</span>
                        </div>
                        <strong class="lt-booking__total-value"><?= e(format_vnd($totalVnd)) ?></strong>
                    </div>
                </aside>
            </div>
        </div>
    </div>
</main>
