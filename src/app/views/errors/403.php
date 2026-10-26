<?php
/*
 * Trang 403: đã đăng nhập nhưng không phải quản trị viên (hoặc quyền đã bị thu hồi) mà mở trang quản trị.
 * Độc lập với layout, giống trang 404.
 */
?><!doctype html>
<html lang="vi">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Không có quyền truy cập · LocalTour</title>
    <style>
        body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #f3f3f3; color: #1f2328; font-family: "Be Vietnam Pro", "Segoe UI", Arial, sans-serif; }
        .error-card { max-width: 480px; margin: 16px; padding: 40px 32px; background: #fff; border: 1px solid #e3e3e3; border-radius: 8px; text-align: center; }
        .error-code { margin: 0 0 8px; color: #b42318; font-size: 48px; font-weight: 700; line-height: 1; }
        h1 { margin: 0 0 12px; font-size: 22px; }
        p { margin: 0 0 24px; color: #6b7280; line-height: 1.5; }
        .actions a { display: inline-block; margin: 4px; padding: 10px 20px; border-radius: 6px; font-weight: 600; text-decoration: none; }
        .primary { background: #176b5f; color: #fff; }
        .primary:hover, .primary:focus { background: #125449; }
        .secondary { background: #e3f1ee; color: #176b5f; }
    </style>
</head>
<body>
    <main class="error-card">
        <p class="error-code">403</p>
        <h1>Bạn không có quyền truy cập trang này.</h1>
        <p>Trang quản trị chỉ dành cho tài khoản quản trị viên LocalTour.</p>
        <div class="actions">
            <a class="primary" href="<?= e(url('/tours')) ?>">Về bảng tin du lịch</a>
            <a class="secondary" href="<?= e(url('/admin/login')) ?>">Đăng nhập quản trị</a>
        </div>
    </main>
</body>
</html>
