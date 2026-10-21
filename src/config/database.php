<?php

declare(strict_types=1);

use Core\Env;

// Giá trị thật nằm trong src/.env (không commit). Xem src/.env.example.
return [
    'host' => Env::get('DB_HOST', '127.0.0.1'),
    'port' => (int) Env::get('DB_PORT', '3306'),
    'database' => Env::get('DB_DATABASE', 'db_localtour'),
    'username' => Env::get('DB_USERNAME', 'root'),
    'password' => Env::get('DB_PASSWORD'),
    'charset' => 'utf8mb4',
    // Giây chờ kết nối; máy host qua VPN không phản hồi thì báo lỗi nhanh thay vì treo trang.
    'timeout' => 5,
];
