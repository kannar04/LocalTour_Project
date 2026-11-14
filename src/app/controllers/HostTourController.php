<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;
use App\Models\AdminTourContentModel;
use App\Models\AdminTourModel;
use App\Models\HostModel;
use App\Models\TourRevisionModel;

/**
 * Khu đơn vị tổ chức (Nguyễn Tuấn Khôi): "Tour của tôi" và trang tổng quan của một tour của đơn vị
 * (trạng thái duyệt, lý do bị từ chối, phần còn thiếu, lối vào các trang sửa).
 * Đơn vị không tự duyệt tour (Sprint 6):
 *   - tour mới ở trạng thái "Nháp"; đơn vị chọn "Gửi duyệt" thì tour sang "Chờ duyệt" và bị khóa;
 *   - tour "Bị từ chối" sửa được (tour về "Nháp") rồi gửi duyệt lại;
 *   - tour "Đã duyệt" không sửa trực tiếp: đơn vị tạo một bản sửa, sửa trên đó rồi gửi duyệt; khách vẫn thấy nội dung
 *     đã duyệt cho tới khi quản trị viên duyệt bản sửa (mỗi tour tối đa một bản sửa đang mở);
 *   - đơn vị tự "Ngừng hiển thị" tour đã duyệt khi tour không còn đơn đang xử lý; hiển thị lại do quản trị viên.
 * Lịch khởi hành và giá vé không cần duyệt (trang lịch khởi hành).
 */
final class HostTourController extends AdminController
{
    protected const PORTAL = 'host';

    /** Thông báo theo mã ?msg= : [kiểu alert, nội dung]. */
    private const MESSAGES = [
        'created' => ['success', 'Đã thêm tour ở trạng thái "Nháp". Thêm lịch khởi hành, giá vé, ảnh và chính sách hủy rồi chọn "Gửi duyệt".'],
        'updated' => ['success', 'Đã lưu thông tin tour.'],
        'unchanged' => ['success', 'Không có thay đổi nào.'],
        'submitted' => ['success', 'Đã gửi duyệt. Tour bị khóa cho tới khi quản trị viên LocalTour xử lý.'],
        'archived' => ['success', 'Đã ngừng hiển thị tour. Khách không còn tìm thấy và không đặt được tour.'],
        'revision_started' => ['success', 'Đã tạo bản sửa. Sửa nội dung rồi chọn "Gửi duyệt"; khách vẫn thấy nội dung đã duyệt cho tới khi bản sửa được duyệt.'],
        'revision_exists' => ['warning', 'Tour đã có một bản sửa đang mở. Mỗi tour chỉ có một bản sửa cùng lúc.'],
        'revision_discarded' => ['success', 'Đã hủy bản sửa. Tour đang hiển thị giữ nguyên.'],
        'not_submittable' => ['warning', 'Chỉ tour đang "Nháp" hoặc "Bị từ chối" mới gửi duyệt được.'],
        'original_not_approved' => ['warning', 'Tour gốc không còn ở trạng thái "Đã duyệt" nên bản sửa không gửi duyệt được. Hãy hủy bản sửa.'],
        'not_archivable' => ['warning', 'Chỉ tour đang "Đã duyệt" mới ngừng hiển thị được.'],
        'has_bookings' => ['warning', 'Tour còn đơn đang chờ xác nhận, chờ thanh toán hoặc đã xác nhận nên chưa ngừng hiển thị được.'],
        'not_discardable' => ['warning', 'Bản sửa đang chờ duyệt nên không hủy được.'],
        'schedule_locked' => ['warning', 'Lịch khởi hành và giá vé sửa ở tour gốc, không sửa trên bản sửa hoặc tour đã ngừng hiển thị.'],
        'expired' => ['danger', self::CSRF_FAILED],
    ];

    /** Thông báo "không sửa được" theo trạng thái của tour (?msg=locked). */
    private const LOCKED = [
        'pending' => 'Tour đang "Chờ duyệt" nên không sửa được cho tới khi quản trị viên LocalTour xử lý.',
        'approved' => 'Tour "Đã duyệt" không sửa trực tiếp. Chọn "Tạo bản sửa" để sửa; khách vẫn thấy nội dung hiện tại cho tới khi bản sửa được duyệt.',
        'archived' => 'Tour đang "Ngừng hiển thị" nên không sửa được. Liên hệ quản trị viên LocalTour để hiển thị lại.',
    ];

    /** Các bước duyệt hiện ở "Lịch sử duyệt" (bỏ các lần sửa ảnh, lịch trình... cho gọn). */
    public const HISTORY_ACTIONS = [
        'tour_create' => 'Thêm tour',
        'tour_submit' => 'Gửi duyệt',
        'tour_approve' => 'Quản trị viên phê duyệt',
        'tour_reject' => 'Quản trị viên từ chối',
        'tour_redraft' => 'Sửa tour bị từ chối, tour về "Nháp"',
        'tour_resubmit' => 'Sửa tour, chờ duyệt lại',
        'tour_revision_start' => 'Tạo bản sửa',
        'tour_revision_approve' => 'Quản trị viên duyệt bản sửa',
        'tour_revision_discard' => 'Hủy bản sửa',
        'tour_archive' => 'Ngừng hiển thị',
        'tour_restore' => 'Hiển thị lại, chờ duyệt',
    ];

    private HostModel $hosts;
    private TourRevisionModel $revisions;

    public function __construct()
    {
        parent::__construct();
        $this->hosts = new HostModel();
        $this->revisions = new TourRevisionModel();
    }

    /** GET /host, GET /host/tours */
    public function index(): void
    {
        $this->render('host/tours/index', [
            'title' => 'Tour của tôi',
            'adminNav' => 'tours',
            'tours' => $this->hosts->tours($this->actorId()),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /host/tours/{id} */
    public function show(string $id): void
    {
        $tourId = self::parseUuid($id) ?? self::notFound();
        // Tour của đơn vị khác: 404 như tour không tồn tại.
        $access = $this->hosts->tourAccess($this->actorId(), $tourId) ?? self::notFound();
        $tour = (new AdminTourModel())->find($tourId) ?? self::notFound();

        $history = array_values(array_filter(
            (new AdminBookingModel())->history('tour', $tourId),
            static fn (array $log): bool => isset(self::HISTORY_ACTIONS[$log['action']])
        ));

        $this->render('host/tours/show', [
            'title' => $tour['title'],
            'adminNav' => 'tours',
            'tour' => $tour,
            'access' => $access,
            'canEdit' => (int) $access['can_edit'] === 1,
            'canSchedule' => (int) $access['can_schedule'] === 1,
            'rejectNote' => $access['reject_note'],
            'history' => $history,
            'notice' => $this->notice((string) $access['approval_status']),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** POST /host/tours/{id}/submit – _csrf ("Nháp" / "Bị từ chối" → "Chờ duyệt"; dùng cho cả bản sửa) */
    public function submit(string $id): void
    {
        $tourId = $this->ownTourOrFail($id);

        $this->back($tourId, match ($this->revisions->submit($this->actorId(), $tourId)) {
            'ok' => 'submitted',
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'original_not_approved' => 'original_not_approved',
            default => 'not_submittable',
        });
    }

    /** POST /host/tours/{id}/archive – _csrf (tour "Đã duyệt" → "Ngừng hiển thị") */
    public function archive(string $id): void
    {
        $tourId = $this->ownTourOrFail($id);

        $this->back($tourId, match ($this->revisions->archive($this->actorId(), $tourId)) {
            'ok' => 'archived',
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'has_bookings' => 'has_bookings',
            default => 'not_archivable',
        });
    }

    /** POST /host/tours/{id}/revision – _csrf (tạo bản sửa của tour "Đã duyệt", rồi mở bản sửa) */
    public function startRevision(string $id): void
    {
        $tourId = $this->ownTourOrFail($id);
        $row = $this->revisions->start($this->actorId(), $tourId);

        match ((string) $row['result']) {
            'ok' => $this->back((string) $row['revision_id'], 'revision_started'),
            'exists' => $this->back((string) $row['revision_id'], 'revision_exists'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->back($tourId, 'locked'),
        };
    }

    /** POST /host/tours/{id}/revision/discard – _csrf ({id} = mã bản sửa; bản sửa đang chờ duyệt thì không hủy được) */
    public function discardRevision(string $id): void
    {
        $revisionId = $this->ownTourOrFail($id);
        // Ảnh của bản sửa mất theo bản sửa: lấy danh sách trước để xóa file không còn dòng ảnh nào dùng.
        $images = (new AdminTourContentModel())->images($revisionId);
        $row = $this->revisions->discard($this->actorId(), $revisionId);

        $result = (string) $row['result'];
        if ($result === 'ok') {
            foreach ($images as $image) {
                AdminTourContentController::removeUpload((string) $image['url']);
            }
            $this->back((string) $row['original_id'], 'revision_discarded');
        }

        match ($result) {
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->back($revisionId, 'not_discardable'),
        };
    }

    /** Mã tour hợp lệ, tour thuộc đơn vị đang đăng nhập và phiên còn hạn; không thì 404 / quay về trang tour. */
    private function ownTourOrFail(string $id): string
    {
        $tourId = self::parseUuid($id) ?? self::notFound();
        if ($this->hosts->tourAccess($this->actorId(), $tourId) === null) {
            self::notFound();
        }
        if (!$this->csrfValid()) {
            $this->back($tourId, 'expired');
        }

        return $tourId;
    }

    private function back(string $tourId, string $message): never
    {
        $this->redirect('/host/tours/' . $tourId . '?msg=' . $message);
    }

    /**
     * Thông báo đầu trang theo ?msg= ; "locked" tùy trạng thái hiện tại của tour.
     *
     * @return array{type: string, text: string}|null
     */
    private function notice(string $status): ?array
    {
        $code = $this->query('msg');
        if ($code === 'locked') {
            return isset(self::LOCKED[$status]) ? ['type' => 'warning', 'text' => self::LOCKED[$status]] : null;
        }
        if (!isset(self::MESSAGES[$code])) {
            return null;
        }

        return ['type' => self::MESSAGES[$code][0], 'text' => self::MESSAGES[$code][1]];
    }
}
