<?php

declare(strict_types=1);

namespace Core;

use RuntimeException;

/**
 * Lớp cha của mọi controller: render view trong layout, trả JSON và đọc tham số request an toàn.
 */
class Controller
{
    /** ID hợp lệ: số nguyên dương, tối đa 10 chữ số, trong miền INT UNSIGNED của MySQL. */
    private const MAX_ID = 4294967295;

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

    /** Trả về ID nếu chuỗi là số nguyên dương hợp lệ, ngược lại null (0, -1, abc, 1.5, quá lớn...). */
    protected static function parseId(string $value): ?int
    {
        if (!preg_match('/^[1-9][0-9]{0,9}$/', $value)) {
            return null;
        }

        $id = (int) $value;

        return $id <= self::MAX_ID ? $id : null;
    }
}
