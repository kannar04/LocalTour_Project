<?php declare(strict_types=1); ?>
<?php
/*
 * Ô email của trang "Tài khoản" khi bật xác minh email (Nguyễn Tuấn Khôi – NTK). Chức năng thêm: chỉ hiện khi đã cấu
 * hình gửi email (MAIL_HOST) và database đã chạy 40_email_verify_NTK.sql.
 * settings.php gọi file này ở chỗ ô email chỉ đọc: trả true khi đã hiện ô email mới; trả false khi chức năng tắt
 * (settings.php hiện ô email cũ, trang giữ nguyên như khi không có file này).
 * Hiện: nhãn "Đã xác minh" / "Chưa xác minh", nút "Gửi mã xác minh" và ô nhập mã, mục "Đổi email" (email mới + mật
 * khẩu hiện tại → mã gửi tới email mới → nhập mã). Các form nằm ngoài form "Thông tin cá nhân" (không lồng form).
 * Dùng biến của settings.php: $account (LTP_sp_account_get), $pageStyles, $pageScripts (thêm account_email.css / .js).
 * Biến riêng đặt tên $ev… để không ghi đè biến của settings.php. Không bao giờ in mã hay mật khẩu.
 */
$evData = \App\Controllers\AccountEmailController::viewData($account);
if ($evData === null) {
    return false;
}
$pageStyles[] = 'css/account_email.css';
$pageScripts[] = 'js/account_email.js';

$evState = $evData['state'];
$evVerified = $evState['verified_at'] !== null;
$evPanel = $evData['panel'];
$evVerifyErrors = $evPanel === 'verify' ? $evData['errors'] : [];
$evChangeErrors = $evPanel === 'change' ? $evData['errors'] : [];
$evVerifyPending = !$evVerified && $evState['verify_expires_at'] !== null;
$evChangePending = $evState['change_email'] !== null;
$evChangeOpen = $evChangePending || $evChangeErrors !== [];
$evWait = (int) $evState['wait_seconds'];
$evTime = static fn (?string $at): string => $at === null ? '' : date('H:i', (int) strtotime($at));
// Đưa con trỏ vào ô cần nhập tiếp: ô lỗi, hoặc ô mã ngay sau khi gửi mã.
$evFocus = array_key_first(array_diff_key($evData['errors'], ['form' => true]));
if ($evFocus === null && $evData['success'] !== '') {
    $evFocus = match (true) {
        $evPanel === 'verify' && $evVerifyPending => 'code',
        $evPanel === 'change' && $evChangePending => 'code',
        default => null,
    };
}
$evNewEmail = $evData['new_email'] !== '' ? $evData['new_email'] : (string) ($evState['change_email'] ?? '');
$evSuccess = $evData['success'];
// Email đã xác minh mà còn gửi form xác minh (trang mở từ trước): không còn gì để làm, chỉ báo đã xác minh.
if ($evVerified && $evVerifyErrors !== [] && $evSuccess === '') {
    $evSuccess = 'Email đã được xác minh.';
}
?>
                    <div class="lt-field lt-email" id="email" tabindex="-1">
                        <div class="lt-email__label-row">
                            <label class="lt-field__label" for="account-email">Email</label>
<?php if ($evVerified): ?>
                            <span class="lt-status lt-status--confirmed lt-email__badge">
                                <span class="lt-icon lt-icon--check" aria-hidden="true"></span>Đã xác minh
                            </span>
<?php else: ?>
                            <span class="lt-status lt-status--pending lt-email__badge">Chưa xác minh</span>
<?php endif; ?>
                        </div>
                        <input class="lt-input" type="email" id="account-email" value="<?= e($account['email']) ?>" readonly aria-describedby="account-email-hint">
                        <p class="lt-field__hint" id="account-email-hint">Email dùng để đăng nhập. Muốn đổi email, mở "Đổi email" bên dưới.</p>

<?php if ($evSuccess !== ''): ?>
                        <div class="lt-book-alert lt-account-alert--success lt-email__alert" role="status">
                            <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
                            <span><?= e($evSuccess) ?></span>
                        </div>
<?php endif; ?>

<?php if (!$evVerified): ?>
                        <div class="lt-email__box">
<?php if (is_string($evVerifyErrors['form'] ?? null)): ?>
                            <div class="lt-book-alert lt-email__alert" role="alert">
                                <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                                <span><?= e($evVerifyErrors['form']) ?></span>
                            </div>
<?php endif; ?>
<?php if ($evVerifyPending): ?>
<?php $evError = (string) ($evVerifyErrors['code'] ?? ''); ?>
                            <form class="lt-email__code" action="<?= e(url('/tai-khoan/email/verify')) ?>" method="post" novalidate>
                                <?= csrf_field() ?>
                                <label class="lt-field__label" for="email-verify-code">Mã xác minh</label>
                                <div class="lt-email__code-row">
                                    <input class="lt-input lt-email__code-input js-email-code<?= $evError !== '' ? ' is-invalid' : '' ?>" type="text" id="email-verify-code"
                                           name="code" inputmode="numeric" autocomplete="one-time-code" maxlength="6" required
                                           aria-describedby="email-verify-code-hint<?= $evError !== '' ? ' email-verify-code-error' : '' ?>"
                                           <?= $evError !== '' ? 'aria-invalid="true"' : '' ?> <?= $evPanel === 'verify' && $evFocus === 'code' ? 'autofocus' : '' ?>>
                                    <button class="lt-btn lt-btn--primary" type="submit">Xác minh</button>
                                </div>
                                <p class="lt-field__hint" id="email-verify-code-hint">Nhập mã 6 chữ số đã gửi tới email trên. Mã hết hạn lúc <?= e($evTime($evState['verify_expires_at'])) ?>.</p>
<?php if ($evError !== ''): ?>
                                <p class="lt-field__error" id="email-verify-code-error"><?= e($evError) ?></p>
<?php endif; ?>
                            </form>
<?php elseif (is_string($evVerifyErrors['code'] ?? null)): ?>
                            <p class="lt-field__error lt-email__note" role="alert"><?= e($evVerifyErrors['code']) ?></p>
<?php endif; ?>
                            <form class="lt-email__send" action="<?= e(url('/tai-khoan/email/code')) ?>" method="post">
                                <?= csrf_field() ?>
                                <button class="lt-btn lt-btn--outline js-email-wait" type="submit" data-wait="<?= e($evWait) ?>">
                                    <?= $evVerifyPending ? 'Gửi lại mã' : 'Gửi mã xác minh' ?>
                                </button>
<?php if (!$evVerifyPending): ?>
                                <span class="lt-field__hint">LocalTour gửi mã 6 chữ số tới email trên để xác minh.</span>
<?php endif; ?>
                            </form>
                        </div>
<?php endif; ?>

                        <details class="lt-email__change"<?= $evChangeOpen ? ' open' : '' ?>>
                            <summary class="lt-btn lt-btn--soft lt-email__summary">Đổi email</summary>
                            <div class="lt-email__change-body">
<?php if (is_string($evChangeErrors['form'] ?? null)): ?>
                                <div class="lt-book-alert lt-email__alert" role="alert">
                                    <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                                    <span><?= e($evChangeErrors['form']) ?></span>
                                </div>
<?php endif; ?>
                                <form action="<?= e(url('/tai-khoan/email/change')) ?>" method="post" novalidate>
                                    <?= csrf_field() ?>
                                    <input class="sr-only" type="email" name="username" value="<?= e($account['email']) ?>" autocomplete="username" tabindex="-1" aria-hidden="true" readonly>
<?php $evError = (string) ($evChangeErrors['new_email'] ?? ''); ?>
                                    <div class="lt-field">
                                        <label class="lt-field__label" for="email-new">Email mới</label>
                                        <input class="lt-input<?= $evError !== '' ? ' is-invalid' : '' ?>" type="email" id="email-new" name="new_email"
                                               value="<?= e($evNewEmail) ?>" maxlength="150" autocomplete="email" required
                                               aria-describedby="email-new-hint<?= $evError !== '' ? ' email-new-error' : '' ?>"
                                               <?= $evError !== '' ? 'aria-invalid="true"' : '' ?> <?= $evPanel === 'change' && $evFocus === 'new_email' ? 'autofocus' : '' ?>>
                                        <p class="lt-field__hint" id="email-new-hint">Mã xác minh được gửi tới email mới. Email chỉ đổi sau khi bạn nhập đúng mã.</p>
<?php if ($evError !== ''): ?>
                                        <p class="lt-field__error" id="email-new-error"><?= e($evError) ?></p>
<?php endif; ?>
                                    </div>
<?php if ($evData['has_password']): ?>
<?php $evError = (string) ($evChangeErrors['current_password'] ?? ''); ?>
                                    <div class="lt-field">
                                        <label class="lt-field__label" for="email-current-password">Mật khẩu hiện tại</label>
                                        <div class="lt-account-password">
                                            <input class="lt-input<?= $evError !== '' ? ' is-invalid' : '' ?>" type="password" id="email-current-password" name="current_password"
                                                   maxlength="72" autocomplete="current-password" required
                                                   <?= $evError !== '' ? 'aria-invalid="true" aria-describedby="email-current-password-error"' : '' ?>
                                                   <?= $evPanel === 'change' && $evFocus === 'current_password' ? 'autofocus' : '' ?>>
                                            <button class="lt-account-password__toggle js-password-toggle" type="button" aria-controls="email-current-password"
                                                    aria-pressed="false" aria-label="Hiện mật khẩu" hidden>
                                                <span class="lt-icon lt-icon--eye" aria-hidden="true"></span>
                                            </button>
                                        </div>
<?php if ($evError !== ''): ?>
                                        <p class="lt-field__error" id="email-current-password-error"><?= e($evError) ?></p>
<?php endif; ?>
                                    </div>
<?php endif; ?>
                                    <div class="lt-email__actions">
                                        <button class="lt-btn lt-btn--primary js-email-wait" type="submit" data-wait="<?= e($evWait) ?>">
                                            <?= $evChangePending ? 'Gửi lại mã tới email mới' : 'Gửi mã tới email mới' ?>
                                        </button>
                                    </div>
                                </form>
<?php if ($evChangePending): ?>
<?php $evError = (string) ($evChangeErrors['code'] ?? ''); ?>
                                <form class="lt-email__code lt-email__code--change" action="<?= e(url('/tai-khoan/email/change/confirm')) ?>" method="post" novalidate>
                                    <?= csrf_field() ?>
                                    <label class="lt-field__label" for="email-change-code">Mã gửi tới <?= e($evState['change_email']) ?></label>
                                    <div class="lt-email__code-row">
                                        <input class="lt-input lt-email__code-input js-email-code<?= $evError !== '' ? ' is-invalid' : '' ?>" type="text" id="email-change-code"
                                               name="code" inputmode="numeric" autocomplete="one-time-code" maxlength="6" required
                                               aria-describedby="email-change-code-hint<?= $evError !== '' ? ' email-change-code-error' : '' ?>"
                                               <?= $evError !== '' ? 'aria-invalid="true"' : '' ?> <?= $evPanel === 'change' && $evFocus === 'code' ? 'autofocus' : '' ?>>
                                        <button class="lt-btn lt-btn--primary" type="submit">Đổi email</button>
                                    </div>
                                    <p class="lt-field__hint" id="email-change-code-hint">Mã hết hạn lúc <?= e($evTime($evState['change_expires_at'])) ?>. Đúng mã thì email đăng nhập đổi ngay.</p>
<?php if ($evError !== ''): ?>
                                    <p class="lt-field__error" id="email-change-code-error"><?= e($evError) ?></p>
<?php endif; ?>
                                </form>
<?php elseif (is_string($evChangeErrors['code'] ?? null)): ?>
                                <p class="lt-field__error lt-email__note" role="alert"><?= e($evChangeErrors['code']) ?></p>
<?php endif; ?>
                            </div>
                        </details>
                    </div>
<?php return true; ?>
