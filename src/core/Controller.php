<?php

declare(strict_types=1);

namespace Core;

use RuntimeException;

/**
 * Lớp cha của mọi controller: render view trong layout, trả JSON, chuyển hướng và đọc tham số request an toàn.
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

        // Mở session trước khi in HTML: header cần biết khách đã đăng nhập chưa và cần mã CSRF.
        Auth::start();

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

    /** Chuyển hướng (303) tới đường dẫn trong ứng dụng, vd. redirect('/tours'). */
    public function redirect(string $path): never
    {
        header('Location: ' . url($path), true, 303);
        exit;
    }

    /** Tham số query string dạng chuỗi; mảng (?q[]=...), chuỗi không phải UTF-8 hoặc thiếu đều coi là rỗng. */
    protected function query(string $key): string
    {
        $value = $_GET[$key] ?? '';

        return is_string($value) && mb_check_encoding($value, 'UTF-8') ? trim($value) : '';
    }

    /**
     * Trường form POST dạng chuỗi; mảng, chuỗi không phải UTF-8 hoặc thiếu đều coi là rỗng.
     * Mật khẩu đọc với $trim = false.
     */
    protected function input(string $key, bool $trim = true): string
    {
        $value = $_POST[$key] ?? '';
        if (!is_string($value) || !mb_check_encoding($value, 'UTF-8')) {
            return '';
        }

        return $trim ? trim($value) : $value;
    }

    /**
     * Trường form POST dạng mảng (vd. passengers[0][full_name]); thiếu hoặc không phải mảng → [].
     * Giá trị bên trong chưa được kiểm tra: controller tự kiểm tra từng phần tử.
     *
     * @return array<int|string, mixed>
     */
    protected function inputArray(string $key): array
    {
        $value = $_POST[$key] ?? [];

        return is_array($value) ? $value : [];
    }

    /**
     * Tham số query string dạng mảng (vd. ?tickets[<mã vé>]=2); thiếu hoặc không phải mảng → [].
     *
     * @return array<int|string, mixed>
     */
    protected function queryArray(string $key): array
    {
        $value = $_GET[$key] ?? [];

        return is_array($value) ? $value : [];
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
