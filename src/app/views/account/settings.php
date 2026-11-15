<?php declare(strict_types=1); ?>
<?php
/*
 * Trang "Tài khoản" của khách hàng (CR3 – Lê Trung Phong): ảnh đại diện, thông tin cá nhân, mật khẩu và lối tắt.
 * Biến: $account (LTP_sp_account_get: user_id, email, name, phone, citizen_id, date_of_birth, gender, address,
 *       avatar_url, has_password), $old (name, phone, citizen_id, date_of_birth, gender, address đang hiện trong form
 *       thông tin cá nhân), $success (thông báo sau khi lưu, '' = không có),
 *       $errors ('form' = lỗi chung như hết phiên; 'avatar' = lỗi ảnh; 'profile' / 'password' = lỗi theo ô,
 *       khóa 'form' bên trong = lỗi chung của form đó), $genders (giá trị → nhãn giới tính), $birthMin / $birthMax
 *       (khoảng ngày sinh chọn được, Y-m-d), $minAge, $addressMaxLength, $avatarMaxBytes, $avatarMinSide,
 *       $avatarMaxSide, $title.
 * Không bao giờ in lại mật khẩu. Số CCCD chỉ hiện trong ô của chính chủ tài khoản (không đưa vào thông báo lỗi).
 * account.js: xem trước ảnh, kiểm tra loại / dung lượng / kích thước trước khi gửi, hỏi lại trước khi xóa ảnh,
 * nút hiện / ẩn mật khẩu.
 */
$avatarUrl = $account['avatar_url'];
// File không có trên máy đang chạy (database chép từ máy khác): hiện chữ cái đầu tên, không hiện ảnh vỡ.
$hasAvatar = $avatarUrl !== null && is_file(BASE_PATH . '/public/assets/' . ltrim((string) $avatarUrl, '/'));
$initial = mb_strtoupper(mb_substr(trim((string) $account['name']), 0, 1));
$hasPassword = (bool) $account['has_password'];
$profileErrors = is_array($errors['profile'] ?? null) ? $errors['profile'] : [];
$passwordErrors = is_array($errors['password'] ?? null) ? $errors['password'] : [];
$avatarError = is_string($errors['avatar'] ?? null) ? $errors['avatar'] : '';
$maxMb = $avatarMaxBytes / 1024 / 1024;

// 'row': 'start' / 'end' = mở / đóng một hàng hai cột (.lt-book-grid: hai cột từ 768 px, một cột trên điện thoại).
$profileFields = [
    ['name' => 'name', 'label' => 'Họ tên', 'type' => 'text', 'maxlength' => 100, 'autocomplete' => 'name', 'required' => true, 'optional' => false, 'hint' => ''],
    ['name' => 'phone', 'label' => 'Số điện thoại', 'type' => 'tel', 'maxlength' => 20, 'autocomplete' => 'tel', 'required' => false, 'optional' => true, 'hint' => 'Dùng khi đơn vị tổ chức cần liên hệ về tour.'],
    ['name' => 'citizen_id', 'label' => 'Số CCCD', 'type' => 'text', 'maxlength' => 12, 'autocomplete' => 'off', 'inputmode' => 'numeric', 'required' => false, 'optional' => true, 'hint' => '12 chữ số trên thẻ căn cước. Chỉ bạn xem được số này.'],
    ['name' => 'date_of_birth', 'label' => 'Ngày sinh', 'type' => 'date', 'autocomplete' => 'bday', 'min' => $birthMin, 'max' => $birthMax, 'required' => false, 'optional' => true, 'hint' => 'Bạn cần đủ ' . $minAge . ' tuổi.', 'row' => 'start'],
    ['name' => 'gender', 'label' => 'Giới tính', 'type' => 'select', 'options' => ['' => 'Không nêu'] + $genders, 'autocomplete' => 'sex', 'required' => false, 'optional' => true, 'hint' => '', 'row' => 'end'],
    ['name' => 'address', 'label' => 'Địa chỉ', 'type' => 'text', 'maxlength' => $addressMaxLength, 'autocomplete' => 'street-address', 'required' => false, 'optional' => true, 'hint' => ''],
];
$passwordFields = array_values(array_filter([
    $hasPassword ? ['name' => 'current_password', 'label' => 'Mật khẩu hiện tại', 'autocomplete' => 'current-password', 'hint' => ''] : null,
    ['name' => 'password', 'label' => $hasPassword ? 'Mật khẩu mới' : 'Mật khẩu', 'autocomplete' => 'new-password', 'hint' => 'Tối thiểu 8 ký tự.'],
    ['name' => 'password_confirm', 'label' => 'Nhập lại mật khẩu', 'autocomplete' => 'new-password', 'hint' => ''],
]));
// Đưa con trỏ vào ô lỗi đầu tiên.
$focusField = array_key_first(array_diff_key($profileErrors, ['form' => true]))
    ?? array_key_first(array_diff_key($passwordErrors, ['form' => true]));
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-book lt-account" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/tours')) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item active" aria-current="page">Tài khoản</li>
            </ol>
        </nav>

        <div class="lt-book-head">
            <h1 class="lt-book-head__title">Tài khoản</h1>
            <p class="lt-book-head__lead">Ảnh đại diện, thông tin cá nhân và mật khẩu của bạn.</p>
        </div>

<?php if ($success !== ''): ?>
        <div class="lt-book-alert lt-account-alert--success" role="status">
            <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
            <span><?= e($success) ?></span>
        </div>
<?php endif; ?>
<?php if (is_string($errors['form'] ?? null)): ?>
        <div class="lt-book-alert" role="alert">
            <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
            <span><?= e($errors['form']) ?></span>
        </div>
<?php endif; ?>

        <div class="lt-account-layout">
            <div class="lt-account-main">
                <section class="lt-book-card lt-account-card" id="anh-dai-dien" tabindex="-1" aria-labelledby="avatar-title">
                    <h2 class="lt-book-card__title" id="avatar-title">Ảnh đại diện</h2>
                    <p class="lt-book-card__lead">Ảnh hiện ở đầu trang khi bạn đăng nhập và cạnh bình luận của bạn.</p>

                    <div class="lt-account-avatar-row">
                        <span class="lt-account-avatar js-avatar-preview" data-initial="<?= e($initial) ?>">
<?php if ($hasAvatar): ?>
                            <img src="<?= e(asset((string) $avatarUrl)) ?>" alt="Ảnh đại diện hiện tại" width="96" height="96">
<?php else: ?>
                            <span class="lt-account-avatar__initial" aria-hidden="true"><?= e($initial) ?></span>
<?php endif; ?>
                        </span>

                        <div class="lt-account-avatar-forms">
                            <form class="lt-account-upload js-avatar-form" action="<?= e(url('/tai-khoan/avatar')) ?>" method="post"
                                  enctype="multipart/form-data" novalidate
                                  data-max-bytes="<?= e($avatarMaxBytes) ?>" data-min-side="<?= e($avatarMinSide) ?>" data-max-side="<?= e($avatarMaxSide) ?>">
                                <?= csrf_field() ?>
                                <input type="hidden" name="MAX_FILE_SIZE" value="<?= e($avatarMaxBytes) ?>">
                                <input class="lt-account-file sr-only js-avatar-input" type="file" id="avatar-file" name="avatar"
                                       accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp"
                                       aria-describedby="avatar-hint<?= $avatarError !== '' ? ' avatar-error' : '' ?>"
                                       <?= $avatarError !== '' ? 'aria-invalid="true"' : '' ?>>
                                <label class="lt-btn lt-btn--outline lt-account-file__btn" for="avatar-file">
                                    <span class="lt-icon lt-icon--camera" aria-hidden="true"></span>
                                    Chọn ảnh
                                </label>
                                <button class="lt-btn lt-btn--primary js-avatar-submit" type="submit">Lưu ảnh</button>
                                <p class="lt-field__hint lt-account-upload__hint" id="avatar-hint">
                                    JPG, PNG hoặc WebP, tối đa <?= e($maxMb) ?> MB. Ảnh được cắt vuông ở giữa.
                                    <span class="lt-account-upload__name js-avatar-name" aria-live="polite"></span>
                                </p>
                                <p class="lt-field__error js-avatar-error" id="avatar-error" role="alert"<?= $avatarError === '' ? ' hidden' : '' ?>><?= e($avatarError) ?></p>
                            </form>

<?php if ($account['avatar_url'] !== null): ?>
                            <form class="js-confirm-form" action="<?= e(url('/tai-khoan/avatar/delete')) ?>" method="post"
                                  data-confirm="Xóa ảnh đại diện? Giao diện sẽ hiện chữ cái đầu tên của bạn.">
                                <?= csrf_field() ?>
                                <button class="lt-btn lt-btn--soft lt-account-remove" type="submit">
                                    <span class="lt-icon lt-icon--trash" aria-hidden="true"></span>
                                    Xóa ảnh
                                </button>
                            </form>
<?php endif; ?>
                        </div>
                    </div>
                </section>

                <section class="lt-book-card lt-account-card" id="thong-tin" tabindex="-1" aria-labelledby="profile-title">
                    <h2 class="lt-book-card__title" id="profile-title">Thông tin cá nhân</h2>
                    <p class="lt-book-card__lead">Họ tên và số điện thoại được điền sẵn khi bạn đặt tour. Các thông tin còn lại chỉ bạn xem được.</p>

<?php if (is_string($profileErrors['form'] ?? null)): ?>
                    <div class="lt-book-alert" role="alert">
                        <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                        <span><?= e($profileErrors['form']) ?></span>
                    </div>
<?php endif; ?>

                    <div class="lt-field">
                        <label class="lt-field__label" for="account-email">Email</label>
                        <input class="lt-input" type="email" id="account-email" value="<?= e($account['email']) ?>" readonly aria-describedby="account-email-hint">
                        <p class="lt-field__hint" id="account-email-hint">Email dùng để đăng nhập nên không đổi được.</p>
                    </div>

                    <form action="<?= e(url('/tai-khoan/profile')) ?>" method="post" novalidate>
                        <?= csrf_field() ?>
<?php foreach ($profileFields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'account-' . str_replace('_', '-', $name);
    $error = (string) ($profileErrors[$name] ?? '');
    $describedBy = trim(($field['hint'] !== '' ? $id . '-hint ' : '') . ($error !== '' ? $id . '-error' : ''));
    $value = (string) ($old[$name] ?? '');
    $attributes = 'id="' . e($id) . '" name="' . e($name) . '" autocomplete="' . e($field['autocomplete']) . '"'
        . ($field['required'] ? ' required' : '')
        . ($error !== '' ? ' aria-invalid="true"' : '')
        . ($describedBy !== '' ? ' aria-describedby="' . e($describedBy) . '"' : '')
        . ($name === $focusField ? ' autofocus' : '');
?>
<?php if (($field['row'] ?? '') === 'start'): ?>
                        <div class="lt-book-grid">
<?php endif; ?>
                        <div class="lt-field">
                            <label class="lt-field__label" for="<?= e($id) ?>">
                                <?= e($field['label']) ?><?php if ($field['optional']): ?> <span class="lt-field__optional">(không bắt buộc)</span><?php endif; ?>
                            </label>
<?php if ($field['type'] === 'select'): ?>
                            <select class="lt-input lt-select<?= $error !== '' ? ' is-invalid' : '' ?>" <?= $attributes ?>>
<?php foreach ($field['options'] as $optionValue => $optionLabel): ?>
                                <option value="<?= e($optionValue) ?>"<?= (string) $optionValue === $value ? ' selected' : '' ?>><?= e($optionLabel) ?></option>
<?php endforeach; ?>
                            </select>
<?php elseif ($field['type'] === 'date'): ?>
                            <input class="lt-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="date" <?= $attributes ?>
                                   value="<?= e($value) ?>" min="<?= e($field['min']) ?>" max="<?= e($field['max']) ?>">
<?php else: ?>
                            <input class="lt-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="<?= e($field['type']) ?>" <?= $attributes ?>
                                   value="<?= e($value) ?>" maxlength="<?= e($field['maxlength']) ?>"<?= isset($field['inputmode']) ? ' inputmode="' . e($field['inputmode']) . '"' : '' ?>>
<?php endif; ?>
<?php if ($field['hint'] !== ''): ?>
                            <p class="lt-field__hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php endif; ?>
<?php if ($error !== ''): ?>
                            <p class="lt-field__error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                        </div>
<?php if (($field['row'] ?? '') === 'end'): ?>
                        </div>
<?php endif; ?>
<?php endforeach; ?>
                        <div class="lt-account-actions">
                            <button class="lt-btn lt-btn--primary" type="submit">Lưu thông tin</button>
                        </div>
                    </form>
                </section>

                <section class="lt-book-card lt-account-card" id="mat-khau" tabindex="-1" aria-labelledby="password-title">
                    <h2 class="lt-book-card__title" id="password-title"><?= $hasPassword ? 'Đổi mật khẩu' : 'Đặt mật khẩu' ?></h2>
                    <p class="lt-book-card__lead">
                        <?= $hasPassword
                            ? 'Nhập mật khẩu hiện tại rồi chọn mật khẩu mới. Bạn vẫn đăng nhập sau khi đổi.'
                            : 'Tài khoản của bạn chưa có mật khẩu. Đặt mật khẩu để đăng nhập bằng email.' ?>
                    </p>

<?php if (is_string($passwordErrors['form'] ?? null)): ?>
                    <div class="lt-book-alert" role="alert">
                        <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                        <span><?= e($passwordErrors['form']) ?></span>
                    </div>
<?php endif; ?>

                    <form action="<?= e(url('/tai-khoan/password')) ?>" method="post" novalidate>
                        <?= csrf_field() ?>
                        <input class="sr-only" type="email" name="username" value="<?= e($account['email']) ?>" autocomplete="username" tabindex="-1" aria-hidden="true" readonly>
<?php foreach ($passwordFields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'account-' . str_replace('_', '-', $name);
    $error = (string) ($passwordErrors[$name] ?? '');
    $describedBy = trim(($field['hint'] !== '' ? $id . '-hint ' : '') . ($error !== '' ? $id . '-error' : ''));
?>
                        <div class="lt-field">
                            <label class="lt-field__label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
                            <div class="lt-account-password">
                                <input class="lt-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="password" id="<?= e($id) ?>" name="<?= e($name) ?>"
                                       maxlength="72" autocomplete="<?= e($field['autocomplete']) ?>" required
                                       <?= $error !== '' ? 'aria-invalid="true"' : '' ?> <?= $describedBy !== '' ? 'aria-describedby="' . e($describedBy) . '"' : '' ?>
                                       <?= $name === $focusField ? 'autofocus' : '' ?>>
                                <button class="lt-account-password__toggle js-password-toggle" type="button" aria-controls="<?= e($id) ?>"
                                        aria-pressed="false" aria-label="Hiện mật khẩu" hidden>
                                    <span class="lt-icon lt-icon--eye" aria-hidden="true"></span>
                                </button>
                            </div>
<?php if ($field['hint'] !== ''): ?>
                            <p class="lt-field__hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php endif; ?>
<?php if ($error !== ''): ?>
                            <p class="lt-field__error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                        </div>
<?php endforeach; ?>
                        <div class="lt-account-actions">
                            <button class="lt-btn lt-btn--primary" type="submit"><?= $hasPassword ? 'Đổi mật khẩu' : 'Đặt mật khẩu' ?></button>
                        </div>
                    </form>
                </section>
            </div>

            <aside class="lt-account-aside" aria-labelledby="shortcuts-title">
                <section class="lt-book-card lt-account-card">
                    <h2 class="lt-book-card__title" id="shortcuts-title">Lối tắt</h2>
                    <ul class="lt-account-links">
                        <li>
                            <a class="lt-account-link" href="<?= e(url('/bookings')) ?>">
                                <span class="lt-icon lt-icon--clipboard" aria-hidden="true"></span>
                                <span>Đơn của tôi</span>
                            </a>
                        </li>
                        <li>
                            <a class="lt-account-link" href="<?= e(url('/tour-da-luu')) ?>">
                                <span class="lt-icon lt-icon--bookmark" aria-hidden="true"></span>
                                <span>Tour đã lưu</span>
                            </a>
                        </li>
                    </ul>
                </section>
            </aside>
        </div>
    </div>
</main>
