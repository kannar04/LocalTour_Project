<?php

declare(strict_types=1);

namespace App\Controllers;

use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * Lớp cha của các trang quản trị (/admin/...).
 * Chưa đăng nhập → chuyển tới "Đăng nhập quản trị"; đã đăng nhập nhưng không phải quản trị viên → trang 403.
 * Procedure ghi dữ liệu kiểm tra lại người thao tác là quản trị viên đang hoạt động (quyền trong session có thể đã cũ).
 */
abstract class AdminController extends Controller
{
    protected const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';
    protected const NOTE_TOO_LONG = 'Lý do tối đa 255 ký tự.';

    /** @var array{user_id: string, name: string, email: string, role: string} */
    protected array $admin;

    public function __construct()
    {
        // Trang quản trị có thông tin khách hàng: trình duyệt không được lưu cache.
        header('Cache-Control: no-store');

        $user = Auth::user();
        if ($user === null) {
            $this->redirect('/admin/login' . self::nextQuery());
        }
        if ($user['role'] !== 'admin') {
            self::forbidden();
        }

        $this->admin = $user;
    }

    protected function actorId(): string
    {
        return $this->admin['user_id'];
    }

    protected function csrfValid(): bool
    {
        return Auth::verifyCsrf($_POST['_csrf'] ?? null);
    }

    /** Thông báo sau khi thao tác thành công (?msg=), chỉ nhận mã có trong $messages. */
    protected function flash(array $messages): string
    {
        return $messages[$this->query('msg')] ?? '';
    }

    protected static function forbidden(): never
    {
        http_response_code(403);
        header('Content-Type: text/html; charset=utf-8');
        require BASE_PATH . '/app/views/errors/403.php';
        exit;
    }

    protected static function notFound(): never
    {
        http_response_code(404);
        header('Content-Type: text/html; charset=utf-8');
        require BASE_PATH . '/app/views/errors/404.php';
        exit;
    }

    /** "?next=..." để quay lại đúng trang đang mở (chỉ với GET; POST quay về /admin). */
    private static function nextQuery(): string
    {
        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
            return '';
        }

        $uri = $_SERVER['REQUEST_URI'] ?? '/admin';
        $query = (string) parse_url($uri, PHP_URL_QUERY);
        $next = Router::pathFromUri($uri) . ($query !== '' ? '?' . $query : '');

        return $next === '/admin' ? '' : '?next=' . rawurlencode($next);
    }
}
