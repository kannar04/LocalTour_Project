<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\ReviewModel;

/**
 * Duyệt đánh giá sao (FR-16, CR2 – Nguyễn Tuấn Khôi): danh sách theo trạng thái kiểm duyệt, tìm theo mã đơn / tour /
 * khách, chia trang. Duyệt đánh giá chờ duyệt; từ chối (bắt buộc lý do) hoặc gỡ đánh giá đã đăng.
 * Chỉ đánh giá "Đã duyệt" hiện trên trang tour và được tính vào điểm trung bình. Mỗi lần xử lý ghi admin_logs (NFR-09).
 * Thao tác ngay trên trang danh sách; xử lý xong quay về đúng bộ lọc, từ khóa và trang đang xem.
 */
final class AdminReviewController extends AdminController
{
    private const MESSAGES = [
        'approved' => 'Đã duyệt đánh giá. Đánh giá đã hiện trên trang tour.',
        'rejected' => 'Đã từ chối đánh giá và lưu lý do. Khách thấy lý do ở trang đơn và có thể sửa rồi gửi lại.',
    ];

    private const ERRORS = [
        'csrf' => self::CSRF_FAILED,
        'note_required' => 'Vui lòng nhập lý do từ chối.',
        'note_long' => 'Lý do tối đa 255 ký tự.',
        'handled' => 'Đánh giá này đã được xử lý trước đó. Danh sách đã được tải lại.',
        'not_found' => 'Không tìm thấy đánh giá này.',
        'failed' => 'Không xử lý được đánh giá, vui lòng thử lại.',
    ];

    private ReviewModel $reviews;

    public function __construct()
    {
        parent::__construct();
        $this->reviews = new ReviewModel();
    }

    /** GET /admin/reviews?status=pending|approved|rejected|all (mặc định pending)&q=&page= */
    public function index(): void
    {
        [$filter, $keyword, $page] = $this->listState($_GET);
        $status = $filter === 'all' ? '' : $filter;
        $summary = $this->reviews->adminSummary($status, $keyword);
        $pages = max(1, (int) ceil($summary['total'] / ReviewModel::PAGE_SIZE));
        $page = min($page, $pages);

        $this->render('admin/reviews/index', [
            'title' => 'Duyệt đánh giá',
            'adminNav' => 'reviews',
            'filter' => $filter,
            'keyword' => $keyword,
            'page' => $page,
            'pages' => $pages,
            'summary' => $summary,
            'reviews' => $this->reviews->adminList($status, $keyword, $page),
            'success' => $this->flash(self::MESSAGES),
            'error' => self::ERRORS[$this->query('err')] ?? '',
            'pageStyles' => ['css/admin.css', 'css/review.css'],
        ]);
    }

    /** POST /admin/reviews/{id}/approve – note (không bắt buộc), status, q, page (để quay lại đúng trang), _csrf */
    public function approve(string $id): void
    {
        $this->decide($id, 'approved');
    }

    /** POST /admin/reviews/{id}/reject – note (bắt buộc), status, q, page, _csrf */
    public function reject(string $id): void
    {
        $this->decide($id, 'rejected');
    }

    private function decide(string $id, string $decision): void
    {
        $back = $this->listState($_POST);
        $reviewId = self::parseUuid($id);
        if ($reviewId === null) {
            self::notFound();
        }
        if (!$this->csrfValid()) {
            $this->back($back, 'err', 'csrf');
        }

        $note = $this->input('note');
        if (mb_strlen($note) > ReviewModel::NOTE_MAX_LENGTH) {
            $this->back($back, 'err', 'note_long');
        }
        if ($decision === 'rejected' && $note === '') {
            $this->back($back, 'err', 'note_required');
        }

        match ($this->reviews->decide($this->actorId(), $reviewId, $decision, $note)) {
            'ok' => $this->back($back, 'msg', $decision),
            'forbidden' => self::forbidden(),
            'not_found' => $this->back($back, 'err', 'not_found'),
            'note_required' => $this->back($back, 'err', 'note_required'),
            'invalid' => $this->back($back, 'err', 'note_long'),
            'invalid_transition' => $this->back($back, 'err', 'handled'),
            default => $this->back($back, 'err', 'failed'),
        };
    }

    /**
     * Bộ lọc, từ khóa và trang từ query string (GET) hoặc ô ẩn của form (POST); giá trị lạ → mặc định.
     *
     * @param array<string, mixed> $source
     * @return array{0: string, 1: string, 2: int}
     */
    private function listState(array $source): array
    {
        $filter = is_string($source['status'] ?? null) ? $source['status'] : '';
        if (!isset(ReviewModel::FILTERS[$filter])) {
            $filter = 'pending';
        }

        $keyword = is_string($source['q'] ?? null) && mb_check_encoding($source['q'], 'UTF-8') ? trim($source['q']) : '';
        $keyword = mb_substr($keyword, 0, ReviewModel::KEYWORD_MAX_LENGTH);

        $pageText = is_string($source['page'] ?? null) ? $source['page'] : '';
        $page = preg_match('/^[1-9]\d{0,4}$/D', $pageText) ? (int) $pageText : 1;

        return [$filter, $keyword, $page];
    }

    /** @param array{0: string, 1: string, 2: int} $state */
    private function back(array $state, string $key, string $code): never
    {
        $this->redirect(self::listUrl($state[0], $state[1], $state[2], [$key => $code]));
    }

    /**
     * Đường dẫn danh sách giữ bộ lọc / từ khóa / trang (bỏ giá trị mặc định cho gọn).
     *
     * @param array<string, string> $extra
     */
    public static function listUrl(string $filter, string $keyword, int $page, array $extra = []): string
    {
        $query = array_filter([
            'status' => $filter === 'pending' ? '' : $filter,
            'q' => $keyword,
            'page' => $page > 1 ? (string) $page : '',
        ] + $extra, static fn (string $part): bool => $part !== '');

        return '/admin/reviews' . ($query !== [] ? '?' . http_build_query($query) : '');
    }
}
