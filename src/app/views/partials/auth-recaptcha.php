<?php declare(strict_types=1); ?>
<?php
/*
 * Ô reCAPTCHA v2 "Tôi không phải người máy" trong form đăng nhập / đăng ký (Nguyễn Tuấn Khôi).
 * Biến: $recaptchaSiteKey (Recaptcha::siteKey(); '' = reCAPTCHA đang tắt, không in gì và không tải script của Google).
 * Script api.js của Google thay đổi theo thời gian nên không gắn được mã SRI.
 */
$recaptchaSiteKey = $recaptchaSiteKey ?? '';
?>
<?php if ($recaptchaSiteKey !== ''): ?>
                <div class="lt-auth__captcha">
                    <div class="g-recaptcha" data-sitekey="<?= e($recaptchaSiteKey) ?>"></div>
                </div>
                <script src="https://www.google.com/recaptcha/api.js?hl=vi" async defer></script>
<?php endif; ?>
