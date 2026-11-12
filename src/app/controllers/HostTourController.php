<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;
use App\Models\AdminTourModel;
use App\Models\HostModel;

/**
 * Khu đơn vị tổ chức (Nguyễn Tuấn Khôi): "Tour của tôi" và trang tổng quan của một tour của đơn vị
 * (trạng thái duyệt, lý do bị từ chối, phần còn thiếu, lối vào các trang sửa).
 * Đơn vị không tự duyệt tour: tour mới và tour vừa sửa ở trạng thái "Chờ duyệt" cho tới khi quản trị viên duyệt.
 */
final class HostTourController extends AdminController
{
    protected const PORTAL = 'host';

    private const MESSAGES = [
        'created' => 'Đã thêm tour. Tour đang "Chờ duyệt": thêm lịch khởi hành, giá vé, ảnh và chính sách hủy để quản trị viên duyệt.',
        'updated' => 'Đã lưu thông tin tour.',
        'unchanged' => 'Không có thay đổi nào.',
        'locked' => 'Tour đang "Ngừng hiển thị" nên không sửa được. Liên hệ quản trị viên LocalTour để hiển thị lại.',
    ];

    /** Các bước duyệt hiện ở "Lịch sử duyệt" (bỏ các lần sửa ảnh, lịch trình... cho gọn). */
    public const HISTORY_ACTIONS = [
        'tour_create' => 'Thêm tour',
        'tour_approve' => 'Quản trị viên phê duyệt',
        'tour_reject' => 'Quản trị viên từ chối',
        'tour_resubmit' => 'Sửa tour, chờ duyệt lại',
        'tour_archive' => 'Ngừng hiển thị',
        'tour_restore' => 'Hiển thị lại, chờ duyệt',
    ];

    private HostModel $hosts;

    public function __construct()
    {
        parent::__construct();
        $this->hosts = new HostModel();
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
            'canEdit' => (int) $access['can_edit'] === 1,
            'rejectNote' => $access['reject_note'],
            'history' => $history,
            'success' => $this->flash(self::MESSAGES),
            'pageStyles' => ['css/admin.css'],
        ]);
    }
}
