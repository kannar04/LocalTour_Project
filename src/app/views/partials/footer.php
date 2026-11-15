<?php declare(strict_types=1); ?>
<?php /* Footer chung. CR3 (Nguyễn Tuấn Khôi): link Trợ giúp và Điều khoản sử dụng. */ ?>
<footer class="lt-footer">
    <div class="container-xl lt-container lt-footer__inner">
        <p>© 2026 LocalTour · Dữ liệu tour, giá và đánh giá là minh họa phục vụ đồ án.</p>
        <nav class="lt-footer__links" aria-label="Thông tin">
            <a href="<?= e(url('/tro-giup')) ?>">Trợ giúp</a>
            <span aria-hidden="true">·</span>
            <a href="<?= e(url('/dieu-khoan')) ?>">Điều khoản sử dụng</a>
        </nav>
        <p><span class="lt-footer__brand">localtour</span> · Khám phá cùng người địa phương</p>
    </div>
</footer>
