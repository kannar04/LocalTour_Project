<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;
use App\Models\BookingHistoryModel;
use App\Models\PaymentResultModel;

/**
 * Quản lý yêu cầu đặt tour (FR-25, Nguyễn Tuấn Khôi): danh sách lọc theo trạng thái / tìm theo mã hoặc khách,
 * chi tiết và cập nhật trạng thái kèm ghi chú. Mỗi lần đổi trạng thái được ghi lịch sử (NFR-09).
 * Sprint 4: chốt tổng giá khi xác nhận chỗ (4.4.3.2), xem phụ thu / tùy chọn khách chọn, các khoản thanh toán và
 * đối chiếu VietQR (4.5.3.2), lịch sử gồm cả thao tác của khách, hệ thống và VNPay (4.3.3.2).
 * Đổi ngày hoặc số người không thuộc FR-25 (FR-12, phát triển sau).
 */
final class AdminBookingController extends AdminController
{
    public const FILTERS = ['', 'pending', 'awaiting_payment', 'confirmed', 'completed', 'rejected', 'cancelled'];
    public const KEYWORD_MAX_LENGTH = 100;

    /** Lỗi đối chiếu VietQR (AdminPaymentController chuyển về với ?err=). */
    public const PAYMENT_ERRORS = [
        'csrf' => self::CSRF_FAILED,
        'invalid' => 'Thao tác đối chiếu không hợp lệ.',
        'note_too_long' => self::NOTE_TOO_LONG,
        'note_required' => '“Không khớp” cần nhập lý do để báo cho khách.',
        'not_payable' => 'Khoản này không còn chờ đối chiếu hoặc đơn không còn chờ thanh toán. Trang đã tải lại trạng thái mới.',
    ];

    private const MESSAGES = [
        'status' => 'Đã cập nhật trạng thái yêu cầu.',
        'payment_confirm' => 'Đã xác nhận nhận tiền: đơn chuyển “Đã xác nhận” và khách nhận được voucher.',
        'payment_reject' => 'Đã báo chuyển khoản không khớp. Đơn vẫn chờ thanh toán tới hết hạn giữ chỗ.',
    ];

    private const ERRORS = [
        'note_required' => 'Từ chối hoặc hủy yêu cầu cần nhập lý do.',
        'needs_payment' => 'Yêu cầu chưa có thanh toán thành công hoặc khoản chuyển khoản VietQR chờ đối chiếu, chưa xác nhận được.',
        'not_departed' => 'Tour chưa tới giờ khởi hành, chưa đánh dấu hoàn thành được.',
        'invalid_transition' => 'Không chuyển được sang trạng thái này từ trạng thái hiện tại.',
        'no_seats' => 'Lịch khởi hành không còn đủ chỗ cho yêu cầu này, chưa xác nhận được. Hãy từ chối kèm lý do (vd. đề nghị khách chọn ngày khác).',
        'schedule_closed' => 'Lịch khởi hành đã đóng hoặc đã tới giờ khởi hành, chưa xác nhận chỗ được.',
        'invalid_total' => 'Tổng giá phải là số tiền lớn hơn 0 và không quá 1.000.000.000đ.',
        'total_note_required' => 'Đổi tổng giá cần ghi lý do (vd. phụ thu đón khách sạn xa).',
    ];

    private AdminBookingModel $bookings;

    public function __construct()
    {
        parent::__construct();
        $this->bookings = new AdminBookingModel();
        PaymentResultModel::expireHoldsQuietly();
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
        $this->renderShow($this->findOrFail($id), $this->flash(self::MESSAGES), self::PAYMENT_ERRORS[$this->query('err')] ?? '');
    }

    /** POST /admin/bookings/{id}/status – status, note, total_vnd (chỉ khi xác nhận chỗ và giá), _csrf */
    public function updateStatus(string $id): void
    {
        $booking = $this->findOrFail($id);
        $newStatus = $this->input('status');
        $note = $this->input('note');
        $totalInput = $this->input('total_vnd');
        $form = ['newStatus' => $newStatus, 'note' => $note, 'total' => $totalInput];

        if (!$this->csrfValid()) {
            $this->renderShow($booking, '', self::CSRF_FAILED, 403, $form);
            return;
        }
        if ($newStatus === '') {
            $this->renderShow($booking, '', 'Vui lòng chọn trạng thái mới.', 422, $form);
            return;
        }
        if (mb_strlen($note) > AdminBookingModel::NOTE_MAX_LENGTH) {
            $this->renderShow($booking, '', self::NOTE_TOO_LONG, 422, $form);
            return;
        }

        // Tổng giá chỉ đọc khi xác nhận chỗ và giá; nhận "1.880.000", "1 880 000" hoặc "1880000".
        $totalVnd = null;
        if ($newStatus === 'awaiting_payment' && $totalInput !== '') {
            $digits = preg_replace('/[.\s]/u', '', $totalInput);
            if (!preg_match('/^\d{1,10}$/D', (string) $digits) || (int) $digits <= 0 || (int) $digits > AdminBookingModel::TOTAL_MAX) {
                $this->renderShow($booking, '', self::ERRORS['invalid_total'], 422, $form);
                return;
            }
            $totalVnd = (int) $digits;
        }

        $bookingId = (string) $booking['booking_id'];
        $result = $this->bookings->setStatus($bookingId, $newStatus, $this->actorId(), $note, $totalVnd);

        match ($result) {
            'ok' => $this->redirect('/admin/bookings/' . $bookingId . '?msg=status'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'note_required', 'invalid_total', 'total_note_required' => $this->renderShow($booking, '', self::ERRORS[$result], 422, $form),
            // Trạng thái có thể vừa bị người khác đổi: tải lại yêu cầu.
            default => $this->renderShow($this->findOrFail($id), '', self::ERRORS[$result] ?? self::ERRORS['invalid_transition'], 409, $form),
        };
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $id): array
    {
        $bookingId = self::parseUuid($id);
        $booking = $bookingId === null ? null : $this->bookings->find($bookingId);

        return $booking ?? self::notFound();
    }

    /**
     * @param array<string, mixed> $booking
     * @param array{newStatus?: string, note?: string, total?: string} $form Giá trị form giữ lại khi có lỗi.
     */
    private function renderShow(array $booking, string $success, string $error, int $status = 200, array $form = []): void
    {
        $bookingId = (string) $booking['booking_id'];

        $this->render('admin/bookings/show', [
            'title' => 'Yêu cầu ' . $booking['code'],
            'adminNav' => 'bookings',
            'booking' => $booking,
            'lines' => $this->bookings->lines($bookingId),
            'extras' => $this->bookings->extras($bookingId),
            'payments' => $this->bookings->payments($bookingId),
            'passengers' => $this->bookings->passengers($bookingId),
            'history' => (new BookingHistoryModel())->forAdmin($bookingId),
            'nextStatuses' => AdminBookingModel::NEXT_STATUSES[$booking['status']] ?? [],
            'success' => $success,
            'error' => $error,
            'newStatus' => $form['newStatus'] ?? '',
            'note' => $form['note'] ?? '',
            'totalInput' => $form['total'] ?? '',
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
