<?php declare(strict_types=1); ?>
<?php
/*
 * Trạng thái "Không tìm thấy tour" (HTTP 404, Nguyễn Tuấn Khôi): ID sai định dạng, không tồn tại hoặc tour đã ẩn.
 * Biến: $title.
 */
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <section class="lt-notfound" aria-labelledby="notfound-title">
            <svg class="lt-notfound__art" viewBox="0 0 240 160" width="240" height="160" aria-hidden="true" focusable="false">
                <defs>
                    <linearGradient id="nf-sky" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0" stop-color="#e3f1ee"/>
                        <stop offset="1" stop-color="#f6ead6"/>
                    </linearGradient>
                </defs>
                <rect x="8" y="8" width="224" height="144" rx="18" fill="url(#nf-sky)"/>
                <path d="M8 118c40-18 70-6 104-16s58-30 120-12v44a18 18 0 0 1-18 18H26a18 18 0 0 1-18-18z" fill="#cde6e0"/>
                <path d="M52 52l40-14 40 14 40-14v70l-40 14-40-14-40 14z" fill="#fff" stroke="#176b5f" stroke-width="3" stroke-linejoin="round"/>
                <path d="M92 38v70M132 52v70" stroke="#176b5f" stroke-width="3" opacity=".35"/>
                <path d="M66 92c10-12 22 6 34-6s20-8 28 2 22 4 30-8" fill="none" stroke="#e9a100" stroke-width="3" stroke-dasharray="5 6" stroke-linecap="round"/>
                <circle cx="174" cy="58" r="20" fill="#176b5f"/>
                <path d="M168 52a6 6 0 1 1 9 5c-2 1-3 2-3 4v2" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>
                <circle cx="174" cy="69" r="2" fill="#fff"/>
            </svg>
            <p class="lt-notfound__code">Lỗi 404</p>
            <h1 class="lt-notfound__title" id="notfound-title">Không tìm thấy tour</h1>
            <p class="lt-notfound__text">Tour bạn tìm không tồn tại hoặc đã ngừng hiển thị.</p>
            <a class="lt-btn lt-btn--primary" href="<?= e(url('/tours')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Quay lại danh sách tour
            </a>
        </section>
    </div>
</main>
