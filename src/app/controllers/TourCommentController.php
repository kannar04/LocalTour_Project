<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourCommentModel;
use Core\Auth;
use Core\Controller;

/**
 * Bình luận trên trang tour (CR3 – Nguyễn Minh Thức). Endpoint JSON cho tour-comments.js:
 * mọi người xem bình luận đang hiển thị; tài khoản khách hàng viết bình luận (1–1000 ký tự, tối đa 5 bình luận
 * trong 10 phút) và tự xóa bình luận của mình. Quản trị viên ẩn / hiện lại ở AdminCommentController.
 */
final class TourCommentController extends Controller
{
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng tải lại trang rồi thử lại.';
    private const MAX_PAGE = 1000;

    private TourCommentModel $comments;

    public function __construct()
    {
        $this->comments = new TourCommentModel();
    }

    /** GET /api/tours/{id}/comments?page=N (mặc định trang 1, mỗi trang 10 bình luận) */
    public function index(string $id): void
    {
        $tourId = self::parseUuid($id);
        if ($tourId === null) {
            $this->json(false, 'Mã tour không hợp lệ.', null, 400);
        }

        $pageText = $this->query('page');
        $page = $pageText === '' ? 1 : (ctype_digit($pageText) ? (int) $pageText : 0);
        if ($page < 1 || $page > self::MAX_PAGE) {
            $this->json(false, 'Số trang không hợp lệ.', null, 400);
        }

        $count = $this->comments->count($tourId);
        if ($count['tour_visible'] !== 1) {
            $this->json(false, 'Không tìm thấy tour.', null, 404);
        }

        $user = Auth::user();
        $rows = $this->comments->list($tourId, $user['user_id'] ?? null, $page);
        $total = $count['total_count'];

        $this->json(true, '', [
            'comments' => array_map([self::class, 'present'], $rows),
            'total' => $total,
            'page' => $page,
            'page_size' => TourCommentModel::PAGE_SIZE,
            'has_more' => $page * TourCommentModel::PAGE_SIZE < $total,
        ]);
    }

    /** POST /api/tours/{id}/comments – content, _csrf */
    public function store(string $id): void
    {
        $this->requireCustomer();

        $tourId = self::parseUuid($id);
        if ($tourId === null) {
            $this->json(false, 'Mã tour không hợp lệ.', null, 400);
        }

        $content = self::cleanContent($this->input('content', false));
        $length = mb_strlen($content);
        if ($length === 0) {
            $this->json(false, 'Vui lòng nhập nội dung bình luận.', ['field' => 'content'], 422);
        }
        if ($length > TourCommentModel::CONTENT_MAX_LENGTH) {
            $this->json(false, 'Bình luận tối đa ' . TourCommentModel::CONTENT_MAX_LENGTH . ' ký tự.', ['field' => 'content'], 422);
        }

        $row = $this->comments->create(Auth::user()['user_id'], $tourId, $content);

        match ((string) $row['result']) {
            'ok' => $this->json(true, 'Đã đăng bình luận.', [
                'comment' => self::present($row),
                'total' => (int) $row['total_count'],
            ], 201),
            'forbidden' => $this->json(false, 'Tài khoản của bạn hiện không bình luận được.', null, 403),
            'not_found' => $this->json(false, 'Không tìm thấy tour.', null, 404),
            'rate_limited' => $this->json(false, 'Bạn đã gửi 5 bình luận trong 10 phút. Vui lòng đợi một lúc rồi gửi tiếp.', null, 429),
            default => $this->json(false, 'Nội dung bình luận từ 1 đến ' . TourCommentModel::CONTENT_MAX_LENGTH . ' ký tự.', ['field' => 'content'], 422),
        };
    }

    /** POST /api/comments/{id}/delete – _csrf. Chỉ xóa được bình luận của chính mình. */
    public function destroy(string $id): void
    {
        $user = Auth::user();
        if ($user === null) {
            $this->json(false, 'Vui lòng đăng nhập.', ['login_url' => url('/login')], 401);
        }
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->json(false, self::CSRF_FAILED, null, 403);
        }

        $commentId = self::parseUuid($id);
        if ($commentId === null) {
            $this->json(false, 'Mã bình luận không hợp lệ.', null, 400);
        }

        $result = $this->comments->deleteOwn($commentId, $user['user_id']);
        if ($result['affected_count'] < 1) {
            $this->json(false, 'Không tìm thấy bình luận của bạn (có thể đã được xóa).', null, 404);
        }

        $this->json(true, 'Đã xóa bình luận.', [
            'tour_id' => $result['tour_id'],
            'total' => (int) $result['total_count'],
        ]);
    }

    /** Chưa đăng nhập → 401; không phải tài khoản khách hàng → 403; sai mã CSRF → 403. */
    private function requireCustomer(): void
    {
        $user = Auth::user();
        if ($user === null) {
            $this->json(false, 'Vui lòng đăng nhập để bình luận.', ['login_url' => url('/login')], 401);
        }
        if ($user['role'] !== 'customer') {
            $this->json(false, 'Chỉ tài khoản khách hàng mới bình luận được.', null, 403);
        }
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->json(false, self::CSRF_FAILED, null, 403);
        }
    }

    /**
     * Gộp CRLF thành LF, tab thành khoảng trắng, bỏ ký tự điều khiển (giữ xuống dòng) và ký tự đảo chiều chữ,
     * rồi bỏ khoảng trắng đầu / cuối.
     */
    private static function cleanContent(string $content): string
    {
        $content = str_replace(["\r\n", "\r", "\t"], ["\n", "\n", ' '], $content);
        $content = (string) preg_replace('/[\x{0000}-\x{0009}\x{000B}-\x{001F}\x{007F}-\x{009F}\x{202A}-\x{202E}\x{2066}-\x{2069}]/u', '', $content);
        // Nhiều dòng trống liền nhau → một dòng trống.
        $content = (string) preg_replace("/\n[ \n]*\n/", "\n\n", $content);

        return trim($content);
    }

    /**
     * Dòng từ procedure → dữ liệu cho tour-comments.js. avatar_src = URL ảnh đại diện (null = hiện chữ cái đầu).
     *
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private static function present(array $row): array
    {
        $name = trim((string) $row['user_name']);
        $createdAt = (string) $row['created_at'];

        return [
            'comment_id' => (string) $row['comment_id'],
            'user_name' => $name,
            'initial' => mb_strtoupper(mb_substr($name, 0, 1)),
            'avatar_src' => self::avatarSrc($row['avatar_url'] ?? null),
            'content' => (string) $row['content'],
            'created_at' => $createdAt,
            'created_text' => format_datetime($createdAt),
            'is_mine' => (int) $row['is_mine'] === 1,
        ];
    }

    /** Ảnh đại diện nằm trong public/assets/uploads/avatars và có trên máy đang chạy → URL; ngược lại null. */
    private static function avatarSrc(mixed $path): ?string
    {
        $path = ltrim(trim((string) $path), '/');
        if ($path === '' || !preg_match('#^uploads/avatars/[A-Za-z0-9_-]+\.(jpe?g|png|webp)$#', $path)
            || !is_file(BASE_PATH . '/public/assets/' . $path)) {
            return null;
        }

        return asset($path);
    }
}
