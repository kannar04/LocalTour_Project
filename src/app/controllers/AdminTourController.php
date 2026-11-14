<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;
use App\Models\AdminTourContentModel;
use App\Models\AdminTourModel;
use App\Models\TourRevisionModel;

/**
 * Duyệt tour (FR-24, Lê Trung Phong): danh sách theo trạng thái, chi tiết, phê duyệt, từ chối kèm lý do.
 * Chỉ tour "Chờ duyệt" mới xử lý được; mỗi lần xử lý được ghi lịch sử (NFR-09).
 * Sprint 6 (Nguyễn Tuấn Khôi): "bản sửa" của tour đã duyệt cũng duyệt ở đây. Trang chi tiết bản sửa so sánh nội dung
 * đang hiển thị với nội dung đề xuất; phê duyệt thì nội dung bản sửa được áp dụng cho tour gốc, từ chối thì tour gốc
 * giữ nguyên (file 32).
 */
final class AdminTourController extends AdminController
{
    public const FILTERS = ['pending' => 'Chờ duyệt', 'approved' => 'Đã duyệt', 'rejected' => 'Bị từ chối', 'archived' => 'Ngừng hiển thị', 'all' => 'Tất cả'];

    private const MESSAGES = [
        'approved' => 'Đã phê duyệt tour.',
        'rejected' => 'Đã từ chối tour và lưu lý do.',
        'revision_applied' => 'Đã duyệt bản sửa: nội dung mới đã được áp dụng cho tour.',
        // Thêm / sửa thông tin tour (AdminTourFormController, FR-13)
        'created' => 'Đã thêm tour. Tour đang ở trạng thái Chờ duyệt: thêm lịch khởi hành và giá vé trước khi phê duyệt.',
        'updated' => 'Đã lưu thông tin tour.',
        'unchanged' => 'Không có thay đổi nào.',
        // Xóa tour (AdminTourContentController, US07-S5-01): tour chưa có đơn bị xóa hẳn
        'deleted' => 'Đã xóa tour.',
    ];

    private AdminTourModel $tours;
    private AdminBookingModel $logs;

    public function __construct()
    {
        parent::__construct();
        $this->tours = new AdminTourModel();
        $this->logs = new AdminBookingModel();
    }

    /** GET /admin/tours?status=pending|approved|rejected|archived|all (mặc định pending) */
    public function index(): void
    {
        $status = $this->query('status');
        if (!isset(self::FILTERS[$status])) {
            $status = 'pending';
        }

        $this->render('admin/tours/index', [
            'title' => 'Duyệt tour',
            'adminNav' => 'tours',
            'filter' => $status,
            'tours' => $this->tours->list($status === 'all' ? '' : $status),
            'success' => $this->flash(self::MESSAGES),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /admin/tours/{id} */
    public function show(string $id): void
    {
        $this->renderShow($this->findOrFail($id), $this->flash(self::MESSAGES), '');
    }

    /** POST /admin/tours/{id}/approve – _csrf */
    public function approve(string $id): void
    {
        $this->decide($id, 'approved');
    }

    /** POST /admin/tours/{id}/reject – note (bắt buộc), _csrf */
    public function reject(string $id): void
    {
        $this->decide($id, 'rejected');
    }

    private function decide(string $id, string $newStatus): void
    {
        $tour = $this->findOrFail($id);
        $note = $this->input('note');

        if (!$this->csrfValid()) {
            $this->renderShow($tour, '', self::CSRF_FAILED, 403, $note);
            return;
        }
        if (mb_strlen($note) > AdminBookingModel::NOTE_MAX_LENGTH) {
            $this->renderShow($tour, '', self::NOTE_TOO_LONG, 422, $note);
            return;
        }

        $tourId = (string) $tour['tour_id'];
        // Duyệt bản sửa: ảnh của tour gốc được thay bằng ảnh của bản sửa, nên lấy danh sách ảnh cũ trước
        // để xóa file không còn dòng ảnh nào dùng.
        $originalId = $newStatus === 'approved' && $tour['revision_of'] !== null ? (string) $tour['revision_of'] : null;
        $oldImages = $originalId !== null ? (new AdminTourContentModel())->images($originalId) : [];
        $result = $this->tours->setApproval($tourId, $newStatus, $this->actorId(), $note);

        if ($result === 'ok' && $originalId !== null) {
            foreach ($oldImages as $image) {
                AdminTourContentController::removeUpload((string) $image['url']);
            }
            $this->redirect('/admin/tours/' . $originalId . '?msg=revision_applied');
        }

        match ($result) {
            'ok' => $this->redirect('/admin/tours/' . $tourId . '?msg=' . $newStatus),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'note_required' => $this->renderShow($tour, '', 'Vui lòng nhập lý do từ chối.', 422, $note),
            'original_not_approved' => $this->renderShow($tour, '', 'Tour gốc không còn ở trạng thái Đã duyệt nên không áp dụng được bản sửa. Hãy từ chối bản sửa.', 409, $note),
            // Tour đã được người khác xử lý: tải lại trạng thái mới nhất.
            default => $this->renderShow($this->findOrFail($id), '', 'Tour không còn ở trạng thái Chờ duyệt nên không xử lý được nữa.', 409),
        };
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $id): array
    {
        $tourId = self::parseUuid($id);
        $tour = $tourId === null ? null : $this->tours->find($tourId);

        return $tour ?? self::notFound();
    }

    /**
     * Bản sửa của tour đã duyệt: thông tin và nội dung của hai bên (đang hiển thị / đề xuất) để so sánh.
     *
     * @param array<string, mixed> $tour
     * @return array<string, mixed>|null null = tour thường
     */
    private function revisionCompare(array $tour): ?array
    {
        if ($tour['revision_of'] === null) {
            return null;
        }
        $info = (new TourRevisionModel())->compare((string) $tour['tour_id']);
        if ($info === null) {
            return null;
        }

        $content = new AdminTourContentModel();
        $sides = [];
        foreach (['current' => (string) $tour['revision_of'], 'proposed' => (string) $tour['tour_id']] as $side => $tourId) {
            $sides[$side] = [
                'info' => $info[$side],
                'images' => $content->images($tourId),
                'itinerary' => $content->itinerary($tourId),
                'inclusions' => $content->inclusions($tourId),
                'policy' => $content->policies($tourId)[0] ?? null, // phiên bản mới nhất
            ];
        }

        return $sides;
    }

    /** @param array<string, mixed> $tour */
    private function renderShow(array $tour, string $success, string $error, int $status = 200, string $note = ''): void
    {
        $this->render('admin/tours/show', [
            'title' => $tour['title'],
            'adminNav' => 'tours',
            'tour' => $tour,
            'history' => $this->logs->history('tour', (string) $tour['tour_id']),
            'revision' => $this->revisionCompare($tour),
            'success' => $success,
            'error' => $error,
            'note' => $note,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
