<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;
use App\Models\HostModel;
use App\Models\PaymentResultModel;

/**
 * Khu đơn vị tổ chức (Nguyễn Tuấn Khôi): "Đơn đặt tour" – đơn vị XEM đơn đặt trên tour của mình để chuẩn bị đón khách
 * (ai đi, bao nhiêu khách, số điện thoại liên hệ, đơn đã xác nhận / đã thanh toán chưa, khách có xin đổi ngày / hủy không).
 * Chỉ có 2 trang GET, không có thao tác ghi: xác nhận, từ chối, hủy đơn, xử lý đổi ngày / hủy và đối chiếu thanh toán
 * vẫn do quản trị viên làm ở /admin. Đơn của tour thuộc đơn vị khác: 404 như đơn không tồn tại (procedure cũng không trả).
 */
final class HostBookingController extends AdminController
{
    protected const PORTAL = 'host';

    private HostModel $hosts;

    public function __construct()
    {
        parent::__construct();
        $this->hosts = new HostModel();
        // Đơn quá hạn thanh toán tự hủy trước khi hiện danh sách (giống các trang đơn khác).
        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /host/bookings?status=&tour= */
    public function index(): void
    {
        $status = $this->query('status');
        if (!in_array($status, AdminBookingController::FILTERS, true)) {
            $status = '';
        }

        // Lọc theo tour: chỉ nhận tour của chính đơn vị, mã khác coi như không lọc.
        $tours = $this->hosts->tours($this->actorId());
        $tourId = self::parseUuid($this->query('tour')) ?? '';
        if (!in_array($tourId, array_column($tours, 'tour_id'), true)) {
            $tourId = '';
        }

        $this->render('host/bookings/index', [
            'title' => 'Đơn đặt tour',
            'adminNav' => 'bookings',
            'filter' => $status,
            'tourId' => $tourId,
            'tours' => $tours,
            'bookings' => $this->hosts->bookings($this->actorId(), $status, $tourId),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /host/bookings/{id} */
    public function show(string $id): void
    {
        $bookingId = self::parseUuid($id) ?? self::notFound();
        $booking = $this->hosts->booking($this->actorId(), $bookingId) ?? self::notFound();
        $parts = new AdminBookingModel();

        $this->render('host/bookings/show', [
            'title' => 'Đơn ' . $booking['code'],
            'adminNav' => 'bookings',
            'booking' => $booking,
            'lines' => $parts->lines($bookingId),
            'extras' => $parts->extras($bookingId),
            'passengers' => $parts->passengers($bookingId),
            'changeRequests' => $this->hosts->bookingChanges($this->actorId(), $bookingId),
            'pageStyles' => ['css/admin.css'],
        ]);
    }
}
