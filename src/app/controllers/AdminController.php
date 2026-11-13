<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\HostModel;
use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * Lớp cha của các trang quản trị (/admin/...).
 * Chưa đăng nhập → chuyển tới "Đăng nhập quản trị"; đã đăng nhập nhưng không phải quản trị viên → trang 403.
 * Procedure ghi dữ liệu kiểm tra lại người thao tác là quản trị viên đang hoạt động (quyền trong session có thể đã cũ).
 *
 * Khu đơn vị tổ chức (/host/..., Sprint 6): các lớp Host...Controller kế thừa trang thêm / sửa tour, lịch khởi hành
 * và nội dung tour của quản trị, đặt PORTAL = 'host'. Khi đó chỉ tài khoản đơn vị tổ chức đang hợp tác vào được,
 * và chỉ thao tác trên tour của chính đơn vị (authorizeTour(); procedure kiểm tra lại, file 27).
 * Đơn vị chỉ sửa nội dung tour đang "Nháp" hoặc "Bị từ chối" (tour đã duyệt sửa qua bản sửa, file 32).
 */
abstract class AdminController extends Controller
{
    /** Khu của controller: 'admin' (quản trị viên) hoặc 'host' (đơn vị tổ chức). */
    protected const PORTAL = 'admin';

    protected const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng thử lại.';
    protected const NOTE_TOO_LONG = 'Lý do tối đa 255 ký tự.';

    /**
     * Tài khoản đang đăng nhập: quản trị viên, hoặc tài khoản đơn vị tổ chức ở khu /host.
     *
     * @var array{user_id: string, name: string, email: string, role: string}
     */
    protected array $admin;

    /** Đường dẫn gốc của khu đang mở ('/admin' hoặc '/host'): dùng cho liên kết và chuyển hướng. */
    protected string $base = '/admin';

    /**
     * Đơn vị tổ chức đang đăng nhập (NTK_sp_host_profile); null ở trang quản trị.
     *
     * @var array<string, mixed>|null
     */
    protected ?array $host = null;

    public function __construct()
    {
        // Trang quản trị có thông tin khách hàng: trình duyệt không được lưu cache.
        header('Cache-Control: no-store');

        $isHost = static::PORTAL === 'host';
        $this->base = $isHost ? '/host' : '/admin';

        $user = Auth::user();
        if ($user === null) {
            $this->redirect($this->base . '/login' . self::nextQuery($this->base));
        }
        if ($user['role'] !== ($isHost ? 'provider' : 'admin')) {
            self::forbidden();
        }

        $this->admin = $user;

        if ($isHost) {
            // Đơn vị bị ngừng hợp tác hoặc tài khoản bị khóa sau khi đăng nhập: kết thúc phiên.
            $profile = (new HostModel())->profile($user['user_id']);
            if (!HostModel::isActive($profile)) {
                Auth::logout();
                $this->redirect('/host/login?stopped=1');
            }
            $this->host = $profile;
        }
    }

    /** View của khu quản trị và khu /host dùng chung: $portal = đường dẫn gốc, $host = đơn vị đang đăng nhập (null ở quản trị). */
    public function render(string $view, array $data = [], int $status = 200): void
    {
        parent::render($view, $data + ['portal' => $this->base, 'host' => $this->host], $status);
    }

    /**
     * Khu /host: tour phải thuộc đơn vị đang đăng nhập (không thì 404 như tour không tồn tại).
     * $scope 'content' (thông tin, ảnh, lịch trình, dịch vụ, chính sách): chỉ tour "Nháp" hoặc "Bị từ chối";
     * $scope 'schedule' (lịch khởi hành, giá vé): mọi tour chưa "Ngừng hiển thị", trừ bản sửa.
     * Không được phép thì quay về trang tour của đơn vị. Trang quản trị: không giới hạn.
     */
    protected function authorizeTour(string $tourId, string $scope = 'content'): void
    {
        if ($this->host === null) {
            return;
        }

        $access = (new HostModel())->tourAccess($this->actorId(), $tourId);
        if ($access === null) {
            self::notFound();
        }
        if ((int) $access[$scope === 'schedule' ? 'can_schedule' : 'can_edit'] !== 1) {
            $this->redirect('/host/tours/' . $tourId . '?msg=' . ($scope === 'schedule' ? 'schedule_locked' : 'locked'));
        }
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

    /** "?next=..." để quay lại đúng trang đang mở (chỉ với GET; POST quay về trang đầu của khu, $base). */
    private static function nextQuery(string $base): string
    {
        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
            return '';
        }

        $uri = $_SERVER['REQUEST_URI'] ?? $base;
        $query = (string) parse_url($uri, PHP_URL_QUERY);
        $next = Router::pathFromUri($uri) . ($query !== '' ? '?' . $query : '');

        return $next === $base ? '' : '?next=' . rawurlencode($next);
    }
}
