<?php declare(strict_types=1); ?>
<?php
/*
 * Chuyển khoản VietQR (Sprint 4, 4.5.3.1, 4.5.3.2 – Nguyễn Minh Thức, Nguyễn Tuấn Khôi): mã QR đúng số tiền và nội dung
 * chuyển khoản (mã thanh toán của đơn), rồi khách bấm "Tôi đã chuyển khoản" để LocalTour đối chiếu.
 * Biến: $booking, $payment (NMT_sp_payment_get), $waiting (đã báo chuyển khoản), $bank (config/payment.php),
 *       $qrUrl ('' = VietQR đang tạm ngưng), $error, $title.
 */
$code = (string) $booking['code'];
$amount = (int) $payment['amount_vnd'];
$reference = (string) $payment['reference'];
$holdUntil = format_datetime($booking['hold_expires_at'] === null ? null : (string) $booking['hold_expires_at']);
$bankName = $bank['bank_name'] !== '' ? $bank['bank_name'] : $bank['bank_id'];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-book" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings')) ?>">Đơn của tôi</a></li>
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings/' . $code)) ?>"><?= e($code) ?></a></li>
                <li class="breadcrumb-item active" aria-current="page">Chuyển khoản VietQR</li>
            </ol>
        </nav>

        <div class="lt-book-head">
            <a class="lt-book-back" href="<?= e(url('/bookings/' . $code)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Đơn <?= e($code) ?>
            </a>
            <h1 class="lt-book-head__title">Chuyển khoản VietQR</h1>
<?php if ($waiting): ?>
            <p class="lt-book-head__lead">Bạn đã báo chuyển khoản<?= $payment['submitted_at'] !== null ? ' lúc ' . e(format_datetime((string) $payment['submitted_at'])) : '' ?>. LocalTour đang đối chiếu; chỗ của bạn vẫn được giữ.</p>
<?php elseif ($holdUntil !== ''): ?>
            <p class="lt-book-head__lead">Chuyển khoản trước <strong><?= e($holdUntil) ?></strong> rồi bấm "Tôi đã chuyển khoản".</p>
<?php endif; ?>
        </div>

<?php if ($error !== ''): ?>
        <div class="lt-book-alert" role="alert">
            <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
            <span><?= e($error) ?></span>
        </div>
<?php endif; ?>

        <div class="row">
            <div class="col-12 col-lg-7 col-xl-8">
                <section class="lt-book-card lt-transfer" aria-labelledby="transfer-title">
                    <h2 class="lt-book-card__title" id="transfer-title">Thông tin chuyển khoản</h2>
<?php if ($qrUrl !== ''): ?>
                    <div class="lt-transfer__qr">
                        <img src="<?= e($qrUrl) ?>" width="280" height="280" alt="Mã VietQR chuyển <?= e(format_vnd($amount)) ?> với nội dung <?= e($reference) ?>">
                    </div>
<?php else: ?>
                    <p class="lt-field__hint">Mã VietQR đang tạm ngưng. Vui lòng chọn phương thức khác hoặc liên hệ LocalTour.</p>
<?php endif; ?>
                    <dl class="lt-book-summary">
<?php if ($bankName !== ''): ?>
                        <div><dt>Ngân hàng</dt><dd><?= e($bankName) ?></dd></div>
<?php endif; ?>
<?php if ($bank['account_no'] !== ''): ?>
                        <div><dt>Số tài khoản</dt><dd><?= e($bank['account_no']) ?></dd></div>
<?php endif; ?>
<?php if ($bank['account_name'] !== ''): ?>
                        <div><dt>Chủ tài khoản</dt><dd><?= e($bank['account_name']) ?></dd></div>
<?php endif; ?>
                        <div><dt>Số tiền</dt><dd><strong><?= e(format_vnd($amount)) ?></strong></dd></div>
                        <div><dt>Nội dung chuyển khoản</dt><dd><strong class="lt-transfer__ref"><?= e($reference) ?></strong></dd></div>
                    </dl>
                    <ol class="lt-transfer__steps">
                        <li>Mở ứng dụng ngân hàng và quét mã (hoặc nhập thông tin ở trên).</li>
                        <li>Giữ đúng số tiền và nội dung <strong><?= e($reference) ?></strong> để LocalTour đối chiếu được.</li>
                        <li>Chuyển xong, bấm "Tôi đã chuyển khoản".</li>
                    </ol>
                    <p class="lt-field__hint">Môi trường thử nghiệm của đồ án: vui lòng không chuyển tiền thật.</p>

<?php if ($waiting): ?>
                    <div class="lt-book-actions">
                        <a class="lt-btn lt-btn--primary" href="<?= e(url('/bookings/' . $code)) ?>">Về trang đơn</a>
                    </div>
<?php else: ?>
                    <form class="lt-book-actions" action="<?= e(url('/bookings/' . $code . '/pay/vietqr/submit')) ?>" method="post">
                        <?= csrf_field() ?>
                        <input type="hidden" name="payment_id" value="<?= e($payment['payment_id']) ?>">
                        <a class="lt-btn lt-btn--outline" href="<?= e(url('/bookings/' . $code . '/pay')) ?>">Chọn phương thức khác</a>
                        <button class="lt-btn lt-btn--primary" type="submit">Tôi đã chuyển khoản</button>
                    </form>
<?php endif; ?>
                </section>
            </div>

            <div class="col-12 col-lg-5 col-xl-4 lt-detail-aside">
                <aside class="lt-booking lt-book-aside" aria-labelledby="transfer-summary-title">
                    <h2 class="lt-book-aside__title" id="transfer-summary-title"><?= e($booking['tour_title']) ?></h2>
                    <dl class="lt-book-summary">
                        <div><dt>Đơn</dt><dd><?= e($code) ?></dd></div>
                        <div><dt>Ngày</dt><dd><?= e(format_date((string) $booking['starts_at'])) ?> · <?= e(schedule_time_text((string) $booking['starts_at'], (string) $booking['ends_at'])) ?></dd></div>
                        <div><dt>Số khách</dt><dd><?= e((int) $booking['people']) ?> khách</dd></div>
                        <div><dt>Trạng thái</dt><dd><?= e(payment_status_label((string) $payment['status'])) ?></dd></div>
                    </dl>
                    <div class="lt-booking__total">
                        <div class="lt-booking__total-main">
                            <span class="lt-booking__total-label">Cần chuyển</span>
                            <span class="lt-booking__total-formula">Giá LocalTour đã chốt · VND</span>
                        </div>
                        <strong class="lt-booking__total-value"><?= e(format_vnd($amount)) ?></strong>
                    </div>
                </aside>
            </div>
        </div>
    </div>
</main>
