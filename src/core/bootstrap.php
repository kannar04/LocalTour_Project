<?php

declare(strict_types=1);

/*
 * Khởi động ứng dụng: hằng BASE_PATH, autoload theo namespace, đọc .env, cấu hình báo lỗi.
 */

use Core\Env;

define('BASE_PATH', dirname(__DIR__));

spl_autoload_register(static function (string $class): void {
    $namespaces = [
        'Core\\' => 'core/',
        'App\\Controllers\\' => 'app/controllers/',
        'App\\Models\\' => 'app/models/',
    ];

    foreach ($namespaces as $prefix => $directory) {
        if (!str_starts_with($class, $prefix)) {
            continue;
        }

        $file = BASE_PATH . '/' . $directory . str_replace('\\', '/', substr($class, strlen($prefix))) . '.php';
        if (is_file($file)) {
            require $file;
        }
        return;
    }
});

require BASE_PATH . '/core/helpers.php';

Env::load(BASE_PATH . '/.env');
date_default_timezone_set('Asia/Ho_Chi_Minh');
mb_internal_encoding('UTF-8');

// Không bao giờ hiển thị lỗi PHP cho người dùng (trừ khi APP_DEBUG=true); lỗi được ghi vào storage/logs/app.log.
$appConfig = require BASE_PATH . '/config/app.php';
error_reporting(E_ALL);
ini_set('display_errors', $appConfig['debug'] ? '1' : '0');
ini_set('log_errors', '1');
ini_set('error_log', BASE_PATH . '/storage/logs/app.log');

// Cảnh báo/notice cũng được coi là lỗi để không lọt dữ liệu sai ra giao diện.
set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
    if (!(error_reporting() & $severity)) {
        return false;
    }
    throw new ErrorException($message, 0, $severity, $file, $line);
});
