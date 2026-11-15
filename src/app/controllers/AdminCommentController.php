<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourCommentModel;

/**
 * Trang "Bình luận" của quản trị viên (CR3 – Nguyễn Minh Thức): xem bình luận của khách trên các tour, lọc theo
 * trạng thái, tìm theo nội dung / người viết / tên tour; ẩn bình luận (bắt buộc lý do) hoặc hiện lại.
 * Bình luận bị ẩn không còn hiện trên trang tour. Mỗi lần ẩn / hiện được ghi vào admin_logs (file 35).
 */
final class AdminCommentController extends AdminController
{
    public const KEYWORD_MAX_LENGTH = 100;

    private const MESSAGES = [
        'hidden' => 'Đã ẩn bình luận. Bình luận không còn hiện trên trang tour.',
        'shown' => 'Đã hiện lại bình luận trên trang tour.',
    ];

    private const ERRORS = [
        'csrf' => self::CSRF_FAILED,
        'reason_required' => 'Vui lòng nhập lý do ẩn bình luận.',
        'reason_too_long' => 'Lý do tối đa 255 ký tự.',
        'not_found' => 'Không tìm thấy bình luận (có thể người viết đã xóa).',
        'unchanged' => 'Bình luận đã ở trạng thái này.',
        'failed' => 'Không cập nhật được bình luận, vui lòng thử lại.',
    ];

    private TourCommentModel $comments;

    public function __construct()
    {
        parent::__construct();
        $this->comments = new TourCommentModel();
    }

    /** GET /admin/comments?status=visible|hidden|all&q=&page= (mặc định: đang hiển thị, trang 1) */
    public function index(): void
    {
        $filter = $this->query('status');
        if (!isset(TourCommentModel::ADMIN_FILTERS[$filter])) {
            $filter = 'visible';
        }
        $keyword = mb_substr($this->query('q'), 0, self::KEYWORD_MAX_LENGTH);
        $pageText = $this->query('page');
        $page = ctype_digit($pageText) && (int) $pageText >= 1 && (int) $pageText <= 10000 ? (int) $pageText : 1;

        $rows = $this->comments->adminList($filter === 'all' ? '' : $filter, $keyword, $page);
        $total = $rows === [] ? 0 : (int) $rows[0]['total_count'];

        $this->render('admin/comments/index', [
            'title' => 'Bình luận',
            'adminNav' => 'comments',
            'filter' => $filter,
            'keyword' => $keyword,
            'page' => $page,
            'pageSize' => TourCommentModel::ADMIN_PAGE_SIZE,
            'total' => $total,
            'comments' => $rows,
            'success' => $this->flash(self::MESSAGES),
            'error' => self::ERRORS[$this->query('err')] ?? '',
            'pageStyles' => ['css/admin.css', 'css/tour-comments.css'],
        ]);
    }

    /** POST /admin/comments/{id}/hide – reason (bắt buộc, tối đa 255 ký tự), back, _csrf */
    public function hide(string $id): void
    {
        $this->changeStatus($id, 'hidden');
    }

    /** POST /admin/comments/{id}/show – back, _csrf */
    public function show(string $id): void
    {
        $this->changeStatus($id, 'visible');
    }

    private function changeStatus(string $id, string $status): void
    {
        $back = self::backPath($this->input('back'));
        if (!$this->csrfValid()) {
            $this->redirect(self::withQuery($back, 'err', 'csrf'));
        }

        $commentId = self::parseUuid($id);
        if ($commentId === null) {
            $this->redirect(self::withQuery($back, 'err', 'not_found'));
        }

        $reason = null;
        if ($status === 'hidden') {
            $reason = $this->input('reason');
            if ($reason === '') {
                $this->redirect(self::withQuery($back, 'err', 'reason_required'));
            }
            if (mb_strlen($reason) > TourCommentModel::REASON_MAX_LENGTH) {
                $this->redirect(self::withQuery($back, 'err', 'reason_too_long'));
            }
        }

        $result = $this->comments->setStatus($commentId, $this->actorId(), $status, $reason);

        match ($result) {
            'ok' => $this->redirect(self::withQuery($back, 'msg', $status === 'hidden' ? 'hidden' : 'shown')),
            'forbidden' => self::forbidden(),
            'not_found' => $this->redirect(self::withQuery($back, 'err', 'not_found')),
            'reason_required' => $this->redirect(self::withQuery($back, 'err', 'reason_required')),
            'unchanged' => $this->redirect(self::withQuery($back, 'err', 'unchanged')),
            default => $this->redirect(self::withQuery($back, 'err', 'failed')),
        };
    }

    /**
     * Trang danh sách để quay lại sau khi ẩn / hiện (giữ bộ lọc, từ khóa, số trang).
     * Chỉ nhận "/admin/comments" kèm query; giá trị khác → "/admin/comments".
     */
    private static function backPath(string $back): string
    {
        $path = (string) parse_url($back, PHP_URL_PATH);
        if ($path !== '/admin/comments' || str_contains($back, '#') || preg_match('/[\x00-\x1F\x7F\\\\]/', $back)) {
            return '/admin/comments';
        }

        parse_str((string) parse_url($back, PHP_URL_QUERY), $query);
        $kept = array_filter([
            'status' => is_string($query['status'] ?? null) ? $query['status'] : '',
            'q' => is_string($query['q'] ?? null) ? mb_substr($query['q'], 0, self::KEYWORD_MAX_LENGTH) : '',
            'page' => is_string($query['page'] ?? null) && ctype_digit($query['page']) ? $query['page'] : '',
        ], static fn (string $value): bool => $value !== '');

        return '/admin/comments' . ($kept !== [] ? '?' . http_build_query($kept) : '');
    }

    private static function withQuery(string $path, string $key, string $value): string
    {
        return $path . (str_contains($path, '?') ? '&' : '?') . $key . '=' . rawurlencode($value);
    }
}
