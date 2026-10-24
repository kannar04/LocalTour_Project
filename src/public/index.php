<?php

declare(strict_types=1);

use Core\Controller;
use Core\DatabaseException;
use Core\Router;

require dirname(__DIR__) . '/core/bootstrap.php';

$router = require BASE_PATH . '/routes/web.php';
$requestUri = $_SERVER['REQUEST_URI'] ?? '/';

try {
    $router->dispatch($_SERVER['REQUEST_METHOD'] ?? 'GET', $requestUri);
} catch (Throwable $exception) {
    error_log((string) $exception);

    $isDatabaseDown = $exception instanceof DatabaseException;
    $statusCode = $isDatabaseDown ? 503 : 500;
    $message = $isDatabaseDown
        ? 'Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau.'
        : 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.';

    if (Router::isApiPath(Router::pathFromUri($requestUri))) {
        (new Controller())->json(false, $message, null, $statusCode);
    }

    // Trang lỗi độc lập với layout để vẫn hiển thị được khi view hoặc database hỏng.
    if (ob_get_level() > 0) {
        ob_end_clean();
    }
    http_response_code($statusCode);
    $appConfig = require BASE_PATH . '/config/app.php';
    $debugDetail = $appConfig['debug'] ? (string) $exception : null;
    require BASE_PATH . '/app/views/errors/500.php';
}
