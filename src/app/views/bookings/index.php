<?php declare(strict_types=1); ?>
<?php
/*
 * Đơn của tôi (M4, Nguyễn Tuấn Khôi): các yêu cầu đặt tour của tài khoản đang đăng nhập, mới đặt trước.
 * Biến: $bookings (NTK_sp_customer_booking_list), $notice (kết quả thanh toán không gắn được với đơn, '' = không có), $title.
 */
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-book" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/tours')) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item active" aria-current="page">Đơn của tôi</li>
            </ol>
        </nav>

        <div class="lt-book-head">
            <h1 class="lt-book-head__title">Đơn của tôi</h1>
            <p class="lt-book-head__lead">Các yêu cầu đặt tour bạn đã gửi và trạng thái xử lý, mới nhất trước.</p>
        </div>

<?php if ($notice !== ''): ?>
        <div class="lt-book-alert" role="alert">
            <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
            <span><?= e($notice) ?></span>
        </div>
<?php endif; ?>

<?php if ($bookings === []): ?>
        <section class="lt-book-card lt-book-empty" aria-labelledby="orders-empty-title">
            <span class="lt-booking-message__icon" aria-hidden="true">
                <span class="lt-icon lt-icon--clipboard"></span>
            </span>
            <h2 class="lt-book-card__title" id="orders-empty-title">Bạn chưa có đơn đặt tour nào</h2>
            <p class="lt-book-card__lead">Chọn một tour, chọn ngày và số khách rồi bấm "Đặt tour" để gửi yêu cầu.</p>
            <a class="lt-btn lt-btn--primary" href="<?= e(url('/tours')) ?>">
                <span class="lt-icon lt-icon--compass" aria-hidden="true"></span>
                Khám phá tour
            </a>
        </section>
<?php else: ?>
        <ul class="lt-orders">
<?php foreach ($bookings as $booking): ?>
<?php
    $coverUrl = $booking['cover_url'] === null ? null : image_src((string) $booking['cover_url']);
    $statusKey = preg_replace('/[^a-z_]/', '', (string) $booking['status']);
?>
            <li>
                <a class="lt-order" href="<?= e(url('/bookings/' . $booking['code'])) ?>">
                    <span class="lt-order__media">
<?php if ($coverUrl !== null): ?>
                        <img src="<?= e($coverUrl) ?>" alt="" loading="lazy">
<?php else: ?>
                        <span class="lt-media-placeholder"><span class="lt-icon lt-icon--image" aria-hidden="true"></span></span>
<?php endif; ?>
                    </span>
                    <span class="lt-order__body">
                        <span class="lt-order__top">
                            <span class="lt-order__code">Đơn <?= e($booking['code']) ?></span>
                            <span class="lt-status lt-status--<?= e($statusKey) ?>"><?= e(booking_status_label((string) $booking['status'])) ?></span>
                        </span>
                        <span class="lt-order__title"><?= e($booking['tour_title']) ?></span>
                        <span class="lt-order__meta">
                            <span><span class="lt-icon lt-icon--calendar" aria-hidden="true"></span><?= e(format_date((string) $booking['starts_at'])) ?> · <?= e(schedule_time_text((string) $booking['starts_at'], (string) $booking['ends_at'])) ?></span>
                            <span><span class="lt-icon lt-icon--user" aria-hidden="true"></span><?= e((int) $booking['people']) ?> khách</span>
                            <span><span class="lt-icon lt-icon--pin" aria-hidden="true"></span><?= e(or_missing((string) $booking['destination_name'])) ?></span>
                        </span>
                        <span class="lt-order__foot">
<?php if ($booking['status'] === 'awaiting_payment' && $booking['hold_expires_at'] !== null): ?>
                            <span class="lt-order__due">Thanh toán trước <?= e(format_datetime((string) $booking['hold_expires_at'])) ?></span>
<?php else: ?>
                            <span>Đặt lúc <?= e(format_datetime((string) $booking['created_at'])) ?></span>
<?php endif; ?>
                            <strong class="lt-order__total"><?= e(format_vnd($booking['total_vnd'])) ?></strong>
                        </span>
                    </span>
                </a>
            </li>
<?php endforeach; ?>
        </ul>
<?php endif; ?>
    </div>
</main>
