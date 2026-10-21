<?php
/*
 * Trang lỗi máy chủ (500) hoặc mất kết nối database (503), do public/index.php gọi.
 * Biến: $statusCode, $message, $debugDetail (chỉ có khi APP_DEBUG=true).
 * Không dùng layout/DB để vẫn hiển thị được khi các phần đó lỗi.
 */
$statusCode = $statusCode ?? 500;
$heading = $statusCode === 503 ? 'Tạm thời không tải được dữ liệu' : 'Đã có lỗi xảy ra';
?><!doctype html>
<html lang="vi">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($heading) ?> · LocalTour</title>
    <style>
        body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #f3f3f3; color: #1f2328; font-family: "Be Vietnam Pro", "Segoe UI", Arial, sans-serif; }
        .error-card { max-width: 480px; margin: 16px; padding: 40px 32px; background: #fff; border: 1px solid #e3e3e3; border-radius: 8px; text-align: center; }
        .error-code { margin: 0 0 8px; color: #b45309; font-size: 48px; font-weight: 700; line-height: 1; }
        h1 { margin: 0 0 12px; font-size: 22px; }
        p { margin: 0 0 24px; color: #6b7280; line-height: 1.5; }
        .actions a { display: inline-block; margin: 4px; padding: 10px 20px; border-radius: 6px; font-weight: 600; text-decoration: none; }
        .primary { background: #176b5f; color: #fff; }
        .primary:hover, .primary:focus { background: #125449; }
        .secondary { background: #e3f1ee; color: #176b5f; }
        pre { margin: 24px 0 0; padding: 12px; max-height: 300px; overflow: auto; background: #1f2328; color: #f3f3f3; font-size: 12px; text-align: left; white-space: pre-wrap; }
    </style>
</head>
<body>
    <main class="error-card">
        <p class="error-code"><?= e($statusCode) ?></p>
        <h1><?= e($heading) ?></h1>
        <p><?= e($message ?? 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.') ?></p>
        <div class="actions">
            <a class="primary" href="">Thử lại</a>
            <a class="secondary" href="<?= e(url('/tours')) ?>">Về bảng tin du lịch</a>
        </div>
        <?php if (!empty($debugDetail)): ?>
            <pre><?= e($debugDetail) ?></pre>
        <?php endif; ?>
    </main>
</body>
</html>
