<?php declare(strict_types=1); ?>
<?php
/*
 * Nút "Tiếp tục với Google / Facebook" ở trang đăng nhập và đăng ký (Nguyễn Tuấn Khôi).
 * Biến: $socialButtons (SocialLogin::buttons(): chỉ nhà cung cấp đã cấu hình trong .env). Rỗng thì không in gì.
 */
$socialButtons = $socialButtons ?? [];
?>
<?php if ($socialButtons !== []): ?>
            <div class="lt-auth__social">
<?php foreach ($socialButtons as $socialButton): ?>
                <a class="lt-btn lt-btn--block lt-auth__social-btn" href="<?= e($socialButton['href']) ?>">
                    <img class="lt-auth__social-logo" src="<?= e(asset('img/social-' . $socialButton['provider'] . '.svg')) ?>" alt="" width="18" height="18">
                    <span><?= e($socialButton['label']) ?></span>
                </a>
<?php endforeach; ?>
            </div>
            <p class="lt-auth__divider"><span>hoặc dùng email</span></p>
<?php endif; ?>
