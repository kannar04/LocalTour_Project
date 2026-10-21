<?php declare(strict_types=1); ?>
<?php
/*
 * Layout chung của LocalTour (Nguyễn Tuấn Khôi).
 * Biến: $title, $content (HTML của view), $pageStyles, $pageScripts (đường dẫn trong public/assets/), $activeNav.
 * Mỗi view tự đặt landmark <main id="main-content"> để link "Bỏ qua đến nội dung chính" nhảy đúng chỗ.
 */
$pageTitle = ($title ?? '') === '' || $title === 'LocalTour' ? 'LocalTour' : $title . ' · LocalTour';
?>
<!doctype html>
<html lang="vi">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <meta name="app-base-url" content="<?= e(url('/')) ?>">
    <meta name="description" content="LocalTour – khám phá tour địa phương do người bản địa dẫn. Dữ liệu minh họa phục vụ Sprint 3.">
    <meta name="theme-color" content="#176b5f">
    <title><?= e($pageTitle) ?></title>
    <link rel="icon" type="image/svg+xml" href="<?= e(asset('img/logo-mark.svg')) ?>">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700&amp;display=swap">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/css/bootstrap.min.css" integrity="sha384-xOolHFLEh07PJGoPkLv1IbcEPTNtaed2xpHsD9ESMhqIYd0nLMwNLD69Npy4HI+N" crossorigin="anonymous">
    <link rel="stylesheet" href="<?= e(asset('css/base.css')) ?>">
<?php foreach ($pageStyles ?? [] as $pageStyle): ?>
    <link rel="stylesheet" href="<?= e(asset((string) $pageStyle)) ?>">
<?php endforeach; ?>
</head>
<body>
    <a class="lt-skip-link" href="#main-content">Bỏ qua đến nội dung chính</a>

<?php require __DIR__ . '/../partials/header.php'; ?>

<?= $content ?? '' ?>

<?php require __DIR__ . '/../partials/footer.php'; ?>

    <script src="https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js" integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo=" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.6.2/dist/js/bootstrap.bundle.min.js" integrity="sha384-Fy6S3B9q64WdZWQUiU+q4/2Lc9npb8tCaSX9FK7E8HnRr0Jz8D6OP9dO5Vg3Q9ct" crossorigin="anonymous"></script>
    <script src="<?= e(asset('js/app.js')) ?>"></script>
<?php foreach ($pageScripts ?? [] as $pageScript): ?>
    <script src="<?= e(asset((string) $pageScript)) ?>"></script>
<?php endforeach; ?>
</body>
</html>
