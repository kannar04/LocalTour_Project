<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminPaymentModel;
use App\Models\PaymentResultModel;
use App\Services\BookingMail;

/**
 * Đối chiếu chuyển khoản VietQR (Sprint 4, 4.5.3.2 – Nguyễn Minh Thức, Nguyễn Tuấn Khôi): danh sách khoản khách đã
 * báo chuyển khoản, quản trị viên kiểm tra sao kê rồi bấm "Đã nhận tiền" (đơn được xác nhận, cấp voucher) hoặc
 * "Không khớp" kèm lý do. Nút đối chiếu nằm ở trang chi tiết yêu cầu, cạnh số tiền và nội dung chuyển khoản.
 * Giao dịch VNPay chưa rõ kết quả (Nguyễn Tuấn Khôi): quản trị viên tra mã thanh toán trên cổng VNPay rồi ghi
 * "Có giao dịch thành công" (kèm mã giao dịch VNPay) hoặc "Không có giao dịch" (kèm lý do).
 */
final class AdminPaymentController extends AdminController
{
    private AdminPaymentModel $payments;

    public function __construct()
    {
        parent::__construct();
        $this->payments = new AdminPaymentModel();
        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /admin/payments */
    public function index(): void
    {
        $this->render('admin/payments/index', [
            'title' => 'Đối chiếu thanh toán',
            'adminNav' => 'payments',
            'payments' => $this->payments->queue(),
            'vnpayPayments' => $this->payments->vnpayQueue(),
            'error' => AdminBookingController::PAYMENT_ERRORS[$this->query('err')] ?? '',
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** POST /admin/payments/{id}/decide – decision (confirm / reject), note, _csrf */
    public function decide(string $id): void
    {
        $paymentId = self::parseUuid($id) ?? self::notFound();
        $decision = $this->input('decision');
        $note = $this->input('note');

        if (!$this->csrfValid()) {
            $this->redirect('/admin/payments?err=csrf');
        }
        if (!in_array($decision, AdminPaymentModel::DECISIONS, true)) {
            $this->redirect('/admin/payments?err=invalid');
        }
        if (mb_strlen($note) > AdminPaymentModel::NOTE_MAX_LENGTH) {
            $this->redirect('/admin/payments?err=note_too_long');
        }

        $row = $this->payments->decide($paymentId, $decision, $this->actorId(), $note);
        $this->finish($row, 'payment_' . $decision);
    }

    /** POST /admin/payments/{id}/vnpay – decision (confirm / reject), txn_no, note, _csrf */
    public function vnpayDecide(string $id): void
    {
        $paymentId = self::parseUuid($id) ?? self::notFound();
        $decision = $this->input('decision');
        $txnNo = $this->input('txn_no');
        $note = $this->input('note');

        if (!$this->csrfValid()) {
            $this->redirect('/admin/payments?err=csrf');
        }
        if (!in_array($decision, AdminPaymentModel::DECISIONS, true)) {
            $this->redirect('/admin/payments?err=invalid');
        }
        if (mb_strlen($note) > AdminPaymentModel::NOTE_MAX_LENGTH) {
            $this->redirect('/admin/payments?err=note_too_long');
        }
        if ($decision === 'reject') {
            $txnNo = '';
        } elseif ($txnNo !== '' && preg_match(AdminPaymentModel::TXN_PATTERN, $txnNo) !== 1) {
            $this->redirect('/admin/payments?err=txn_invalid');
        }

        $row = $this->payments->vnpayDecide($paymentId, $decision, $this->actorId(), $txnNo, $note);
        $this->finish($row, 'vnpay_' . $decision);
    }

    /**
     * Về trang chi tiết yêu cầu sau khi đối chiếu: thành công → thông báo $message, lỗi → ?err=.
     *
     * @param array<string, mixed> $row
     */
    private function finish(array $row, string $message): never
    {
        $result = (string) $row['result'];
        $bookingId = (string) ($row['booking_id'] ?? '');

        // Email "Đặt tour thành công" khi vừa ghi nhận tiền; BookingMail bỏ qua đơn không "Đã xác nhận" (tiền tới muộn).
        if ($result === 'ok' && in_array($message, ['payment_confirm', 'vnpay_confirm'], true)) {
            BookingMail::sendConfirmedForBooking($bookingId);
        }

        match ($result) {
            'ok' => $this->redirect('/admin/bookings/' . $bookingId . '?msg=' . $message . '#payments'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->redirect($bookingId !== ''
                ? '/admin/bookings/' . $bookingId . '?err=' . $result . '#payments'
                : '/admin/payments?err=' . $result),
        };
    }
}
