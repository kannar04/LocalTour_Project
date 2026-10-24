<?php
/*
 * Trang 404 cho đường dẫn không có route. Độc lập với layout để luôn hiển thị được.
 */
?><!doctype html>
<html lang="vi">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Không tìm thấy trang · LocalTour</title>
    <style>
        body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #f3f3f3; color: #1f2328; font-family: "Be Vietnam Pro", "Segoe UI", Arial, sans-serif; }
        .error-card { max-width: 440px; margin: 16px; padding: 40px 32px; background: #fff; border: 1px solid #e3e3e3; border-radius: 8px; text-align: center; }
        .error-code { margin: 0 0 8px; color: #176b5f; font-size: 48px; font-weight: 700; line-height: 1; }
        h1 { margin: 0 0 12px; font-size: 22px; }
        p { margin: 0 0 24px; color: #6b7280; line-height: 1.5; }
        a { display: inline-block; padding: 10px 20px; border-radius: 6px; background: #176b5f; color: #fff; font-weight: 600; text-decoration: none; }
        a:hover, a:focus { background: #125449; }
    </style>
</head>
<body>
    <main class="error-card">
        <p class="error-code">404</p>
        <h1>Không tìm thấy trang</h1>
        <p>Đường dẫn bạn mở không tồn tại trên LocalTour.</p>
        <a href="<?= e(url('/tours')) ?>">Về bảng tin du lịch</a>
    </main>
</body>
</html>
