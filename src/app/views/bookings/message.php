<?php declare(strict_types=1); ?>
<?php
/*
 * Thông báo của phần đặt tour (M4, Nguyễn Tuấn Khôi): không tìm thấy đơn (404) hoặc tài khoản không phải khách hàng (403).
 * Biến: $errorCode ("Lỗi 404"), $heading, $text, $title.
 */
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <section class="lt-notfound" aria-labelledby="message-title">
            <span class="lt-booking-message__icon" aria-hidden="true">
                <span class="lt-icon lt-icon--clipboard"></span>
            </span>
            <p class="lt-notfound__code"><?= e($errorCode) ?></p>
            <h1 class="lt-notfound__title" id="message-title"><?= e($heading) ?></h1>
            <p class="lt-notfound__text"><?= e($text) ?></p>
            <div class="lt-booking-message__actions">
<?php if ((current_user()['role'] ?? '') === 'customer'): ?>
                <a class="lt-btn lt-btn--soft" href="<?= e(url('/bookings')) ?>">Đơn của tôi</a>
<?php endif; ?>
                <a class="lt-btn lt-btn--primary" href="<?= e(url('/tours')) ?>">
                    <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                    Quay lại danh sách tour
                </a>
            </div>
        </section>
    </div>
</main>
