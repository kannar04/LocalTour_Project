<?php

declare(strict_types=1);

namespace Core;

use RuntimeException;

/**
 * Lớp cha của mọi controller: render view trong layout, trả JSON và đọc tham số request an toàn.
 */
class Controller
{
    public function render(string $view, array $data = [], int $status = 200): void
    {
        $viewFile = BASE_PATH . '/app/views/' . $view . '.php';
        $layoutFile = BASE_PATH . '/app/views/layouts/main.php';
        if (!is_file($viewFile) || !is_file($layoutFile)) {
            throw new RuntimeException('View không tồn tại: ' . $view);
        }

        $data += ['title' => 'LocalTour', 'pageStyles' => [], 'pageScripts' => [], 'activeNav' => 'feed'];
        extract($data, EXTR_SKIP);

        ob_start();
        require $viewFile;
        $content = (string) ob_get_clean();

        http_response_code($status);
        header('Content-Type: text/html; charset=utf-8');
        require $layoutFile;
    }

    /**
     * Mọi endpoint JSON trả cùng một cấu trúc: { success, message, data }.
     */
    public function json(bool $success, string $message, mixed $data = null, int $status = 200): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode(
            ['success' => $success, 'message' => $message, 'data' => $data],
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        );
        exit;
    }

    /** Tham số query string dạng chuỗi; mảng (?q[]=...) hoặc thiếu đều coi là rỗng. */
    protected function query(string $key): string
    {
        $value = $_GET[$key] ?? '';

        return is_string($value) ? trim($value) : '';
    }

    /** Trả về UUID (chữ thường) nếu chuỗi đúng dạng 8-4-4-4-12 ký tự hex, ngược lại null (1, abc, UUID thiếu ký tự...). */
    protected static function parseUuid(string $value): ?string
    {
        if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $value)) {
            return null;
        }

        return strtolower($value);
    }
}
