<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;

/**
 * Quản lý yêu cầu đặt tour (FR-25, Nguyễn Tuấn Khôi): danh sách lọc theo trạng thái / tìm theo mã hoặc khách,
 * chi tiết và cập nhật trạng thái kèm ghi chú. Mỗi lần đổi trạng thái được ghi lịch sử (NFR-09).
 * Đổi ngày hoặc số người không thuộc FR-25 (FR-12, phát triển sau).
 */
final class AdminBookingController extends AdminController
{
    public const FILTERS = ['', 'pending', 'awaiting_payment', 'confirmed', 'completed', 'rejected', 'cancelled'];
    public const KEYWORD_MAX_LENGTH = 100;

    private const MESSAGES = ['status' => 'Đã cập nhật trạng thái yêu cầu.'];

    private const ERRORS = [
        'note_required' => 'Từ chối hoặc hủy yêu cầu cần nhập lý do.',
        'needs_payment' => 'Yêu cầu chưa có thanh toán thành công hoặc khoản chuyển khoản VietQR chờ đối chiếu, chưa xác nhận được.',
        'not_departed' => 'Tour chưa tới giờ khởi hành, chưa đánh dấu hoàn thành được.',
        'invalid_transition' => 'Không chuyển được sang trạng thái này từ trạng thái hiện tại.',
        'no_seats' => 'Lịch khởi hành không còn đủ chỗ cho yêu cầu này, chưa xác nhận được. Hãy từ chối kèm lý do (vd. đề nghị khách chọn ngày khác).',
        'schedule_closed' => 'Lịch khởi hành đã đóng hoặc đã tới giờ khởi hành, chưa xác nhận chỗ được.',
    ];

    private AdminBookingModel $bookings;

    public function __construct()
    {
        parent::__construct();
        $this->bookings = new AdminBookingModel();
    }

    /** GET /admin/bookings?status=&q= */
    public function index(): void
    {
        $status = $this->query('status');
        if (!in_array($status, self::FILTERS, true)) {
            $status = '';
        }
        $keyword = mb_substr($this->query('q'), 0, self::KEYWORD_MAX_LENGTH);

        $this->render('admin/bookings/index', [
            'title' => 'Yêu cầu đặt tour',
            'adminNav' => 'bookings',
            'filter' => $status,
            'keyword' => $keyword,
            'bookings' => $this->bookings->list($status, $keyword),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /admin/bookings/{id} */
    public function show(string $id): void
    {
        $this->renderShow($this->findOrFail($id), $this->flash(self::MESSAGES), '');
    }

    /** POST /admin/bookings/{id}/status – status, note, _csrf */
    public function updateStatus(string $id): void
    {
        $booking = $this->findOrFail($id);
        $newStatus = $this->input('status');
        $note = $this->input('note');

        if (!$this->csrfValid()) {
            $this->renderShow($booking, '', self::CSRF_FAILED, 403, $newStatus, $note);
            return;
        }
        if ($newStatus === '') {
            $this->renderShow($booking, '', 'Vui lòng chọn trạng thái mới.', 422, $newStatus, $note);
            return;
        }
        if (mb_strlen($note) > AdminBookingModel::NOTE_MAX_LENGTH) {
            $this->renderShow($booking, '', self::NOTE_TOO_LONG, 422, $newStatus, $note);
            return;
        }

        $bookingId = (string) $booking['booking_id'];
        $result = $this->bookings->setStatus($bookingId, $newStatus, $this->actorId(), $note);

        match ($result) {
            'ok' => $this->redirect('/admin/bookings/' . $bookingId . '?msg=status'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'note_required' => $this->renderShow($booking, '', self::ERRORS['note_required'], 422, $newStatus, $note),
            // Trạng thái có thể vừa bị người khác đổi: tải lại yêu cầu.
            default => $this->renderShow($this->findOrFail($id), '', self::ERRORS[$result] ?? self::ERRORS['invalid_transition'], 409, $newStatus, $note),
        };
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $id): array
    {
        $bookingId = self::parseUuid($id);
        $booking = $bookingId === null ? null : $this->bookings->find($bookingId);

        return $booking ?? self::notFound();
    }

    /** @param array<string, mixed> $booking */
    private function renderShow(array $booking, string $success, string $error, int $status = 200, string $newStatus = '', string $note = ''): void
    {
        $bookingId = (string) $booking['booking_id'];

        $this->render('admin/bookings/show', [
            'title' => 'Yêu cầu ' . $booking['code'],
            'adminNav' => 'bookings',
            'booking' => $booking,
            'lines' => $this->bookings->lines($bookingId),
            'passengers' => $this->bookings->passengers($bookingId),
            'history' => $this->bookings->history('booking', $bookingId),
            'nextStatuses' => AdminBookingModel::NEXT_STATUSES[$booking['status']] ?? [],
            'success' => $success,
            'error' => $error,
            'newStatus' => $newStatus,
            'note' => $note,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
