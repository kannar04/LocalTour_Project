<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminBookingModel;
use App\Models\AdminChangeRequestModel;
use App\Models\AdminPaymentModel;
use App\Models\BookingHistoryModel;
use App\Models\MomoPaymentModel;
use App\Models\PaymentResultModel;
use App\Services\BookingMail;
use App\Services\MomoGateway;

/**
 * Quản lý đơn đặt tour (FR-25, Nguyễn Tuấn Khôi): danh sách lọc theo trạng thái / tìm theo mã hoặc khách,
 * chi tiết và cập nhật trạng thái kèm ghi chú. Mỗi lần đổi trạng thái được ghi lịch sử (NFR-09).
 * Sprint 4: chốt tổng giá khi xác nhận chỗ (4.4.3.2), xem phụ thu / tùy chọn khách chọn, các khoản thanh toán và
 * đối chiếu VietQR (4.5.3.2), lịch sử gồm cả thao tác của khách, hệ thống và VNPay (4.3.3.2).
 * Đặt ngay: đơn mới đã giữ chỗ và bắt đầu ở "Chờ thanh toán", quản trị viên không còn xác nhận chỗ; việc duyệt tay còn lại
 * là đối chiếu chuyển khoản VietQR. Xác nhận chỗ / từ chối chỉ còn dùng cho đơn "Chờ xác nhận" tạo theo quy trình cũ.
 * Đổi ngày hoặc số người không thuộc FR-25 (FR-12, phát triển sau).
 */
final class AdminBookingController extends AdminController
{
    public const FILTERS = ['', 'pending', 'awaiting_payment', 'confirmed', 'completed', 'rejected', 'cancelled'];
    public const KEYWORD_MAX_LENGTH = 100;

    /** Lỗi đối chiếu VietQR / VNPay / MoMo (AdminPaymentController chuyển về với ?err=). */
    public const PAYMENT_ERRORS = [
        'csrf' => self::CSRF_FAILED,
        'invalid' => 'Thao tác đối chiếu không hợp lệ.',
        'note_too_long' => self::NOTE_TOO_LONG,
        'note_required' => '“Không khớp” / “Không có giao dịch” cần nhập lý do.',
        'not_payable' => 'Khoản này không còn chờ đối chiếu (đã được xử lý hoặc đã có kết quả). Trang đã tải lại trạng thái mới.',
        'txn_required' => '“Có giao dịch thành công” cần nhập mã giao dịch VNPay của giao dịch đó.',
        'txn_invalid' => 'Mã giao dịch VNPay chỉ gồm chữ số (tối đa 20 số).',
        'momo_unavailable' => 'MoMo đang tạm ngưng (thiếu khóa MoMo trong .env), chưa tra cứu được.',
        'momo_query' => 'Chưa tra cứu được giao dịch với MoMo, vui lòng thử lại sau ít phút.',
        'momo_pending' => 'MoMo chưa có kết quả cuối cho giao dịch này, vui lòng tra cứu lại sau.',
        'momo_amount' => 'Số tiền MoMo trả lời không khớp với khoản thanh toán nên chưa được ghi nhận.',
    ];

    private const MESSAGES = [
        'status' => 'Đã cập nhật trạng thái đơn.',
        'payment_confirm' => 'Đã xác nhận nhận tiền. Đơn còn chờ thanh toán thì chuyển “Đã xác nhận” và khách nhận được voucher; đơn đã hủy hoặc đã thanh toán bằng khoản khác thì tạo yêu cầu hoàn tiền.',
        'payment_reject' => 'Đã báo chuyển khoản không khớp. Đơn còn hạn giữ chỗ thì khách thanh toán lại được; đã quá hạn thì đơn tự hủy và trả lại chỗ.',
        'vnpay_confirm' => 'Đã ghi giao dịch VNPay thành công. Đơn còn chờ thanh toán thì chuyển “Đã xác nhận” và khách nhận được voucher; đơn đã hủy thì tạo yêu cầu hoàn tiền.',
        'vnpay_reject' => 'Đã ghi “Không có giao dịch VNPay”. Đơn còn hạn giữ chỗ thì khách thanh toán lại được.',
        'momo_paid' => 'MoMo báo giao dịch thành công. Đơn còn chờ thanh toán thì chuyển “Đã xác nhận” và khách nhận được voucher; đơn đã hủy thì tạo yêu cầu hoàn tiền.',
        'momo_failed' => 'MoMo báo giao dịch không thành công, đã ghi nhận. Đơn còn hạn giữ chỗ thì khách thanh toán lại được.',
    ];

    private const ERRORS = [
        'note_required' => 'Từ chối hoặc hủy đơn cần nhập lý do.',
        'needs_payment' => 'Đơn chưa có thanh toán thành công hoặc khoản chuyển khoản VietQR chờ đối chiếu, chưa xác nhận được.',
        'not_departed' => 'Tour chưa tới giờ khởi hành, chưa đánh dấu hoàn thành được.',
        'invalid_transition' => 'Không chuyển được sang trạng thái này từ trạng thái hiện tại.',
        'no_seats' => 'Lịch khởi hành không còn đủ chỗ cho đơn này, chưa xác nhận được. Hãy từ chối kèm lý do (vd. đề nghị khách chọn ngày khác).',
        'schedule_closed' => 'Lịch khởi hành đã đóng hoặc đã tới giờ khởi hành, chưa xác nhận chỗ được.',
        'invalid_total' => 'Tổng giá phải là số tiền lớn hơn 0 và không quá 1.000.000.000đ.',
        'total_note_required' => 'Đổi tổng giá cần ghi lý do (vd. phụ thu đón khách sạn xa).',
        'payment_in_review' => 'Đơn còn khoản chuyển khoản VietQR chờ đối chiếu nên chưa hủy được. Hãy quyết định khoản đó trước (“Đã nhận tiền” hoặc “Không khớp”) ở mục “Thanh toán” của đơn hoặc trang “Đối chiếu thanh toán”, rồi mới hủy đơn.',
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
            'title' => 'Đơn đặt tour',
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

        // Email "Đặt tour thành công" khi quản trị viên vừa chuyển "Chờ thanh toán" → "Đã xác nhận".
        if ($result === 'ok' && $newStatus === 'confirmed') {
            BookingMail::sendConfirmedForBooking($bookingId);
        }

        match ($result) {
            'ok' => $this->redirect('/admin/bookings/' . $bookingId . '?msg=status'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'note_required', 'invalid_total', 'total_note_required' => $this->renderShow($booking, '', self::ERRORS[$result], 422, $form),
            // Trạng thái có thể vừa bị người khác đổi: tải lại đơn.
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
            'title' => 'Đơn ' . $booking['code'],
            'adminNav' => 'bookings',
            'booking' => $booking,
            'lines' => $this->bookings->lines($bookingId),
            'extras' => $this->bookings->extras($bookingId),
            'payments' => $this->bookings->payments($bookingId),
            'vnpayUnclear' => array_column((new AdminPaymentModel())->vnpayQueue($bookingId), 'payment_id'),
            'momoUnclear' => MomoGateway::enabled(require BASE_PATH . '/config/payment.php')
                ? array_column((new MomoPaymentModel())->queue($bookingId), 'order_id', 'payment_id') : [],
            'passengers' => $this->bookings->passengers($bookingId),
            'history' => (new BookingHistoryModel())->forAdmin($bookingId),
            'changeRequests' => (new AdminChangeRequestModel())->list('', $bookingId),
            'nextStatuses' => AdminBookingModel::NEXT_STATUSES[$booking['status']] ?? [],
            'confirmMail' => BookingMail::adminStatusLine($bookingId, (string) $booking['status']),
            'success' => $success,
            'error' => $error,
            'newStatus' => $form['newStatus'] ?? '',
            'note' => $form['note'] ?? '',
            'totalInput' => $form['total'] ?? '',
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
