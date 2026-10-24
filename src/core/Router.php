<?php

declare(strict_types=1);

namespace Core;

use RuntimeException;

/**
 * Router tối giản: khai báo route GET/POST với tham số {ten}, tự bỏ phần thư mục gốc
 * khi ứng dụng chạy trong thư mục con của htdocs (vd. /LocalTour_Project/src/public).
 */
final class Router
{
    /** @var array<string, list<array{pattern: string, handler: array{0: class-string, 1: string}}>> */
    private array $routes = [];

    public function get(string $path, array $handler): void
    {
        $this->add('GET', $path, $handler);
    }

    public function post(string $path, array $handler): void
    {
        $this->add('POST', $path, $handler);
    }

    private function add(string $method, string $path, array $handler): void
    {
        $pattern = preg_replace('#\{([a-zA-Z_][a-zA-Z0-9_]*)\}#', '(?P<$1>[^/]+)', $path);
        $this->routes[$method][] = ['pattern' => '#^' . $pattern . '/?$#', 'handler' => $handler];
    }

    public function dispatch(string $method, string $uri): void
    {
        $path = self::pathFromUri($uri);
        $method = $method === 'HEAD' ? 'GET' : $method;

        foreach ($this->routes[$method] ?? [] as $route) {
            if (!preg_match($route['pattern'], $path, $matches)) {
                continue;
            }

            [$class, $action] = $route['handler'];
            if (!class_exists($class) || !method_exists($class, $action)) {
                throw new RuntimeException('Route handler không hợp lệ: ' . $class . '@' . $action);
            }

            $arguments = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
            (new $class())->{$action}(...array_values($arguments));
            return;
        }

        $this->notFound($path);
    }

    /** Đường dẫn trong ứng dụng, đã bỏ thư mục gốc: "/tours/5". */
    public static function pathFromUri(string $uri): string
    {
        $path = rawurldecode(parse_url($uri, PHP_URL_PATH) ?: '/');
        $basePath = base_path_prefix();
        if ($basePath !== '' && str_starts_with($path, $basePath)) {
            $path = substr($path, strlen($basePath));
        }

        return '/' . ltrim($path, '/');
    }

    public static function isApiPath(string $path): bool
    {
        return $path === '/api' || str_starts_with($path, '/api/');
    }

    private function notFound(string $path): void
    {
        if (self::isApiPath($path)) {
            (new Controller())->json(false, 'Không tìm thấy đường dẫn API.', null, 404);
        }

        http_response_code(404);
        require BASE_PATH . '/app/views/errors/404.php';
    }
}
