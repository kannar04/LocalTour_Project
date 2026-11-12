<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminPaymentModel;
use App\Models\MomoPaymentModel;
use App\Models\PaymentResultModel;
use App\Services\BookingMail;
use App\Services\MomoGateway;
use Throwable;

/**
 * Đối chiếu chuyển khoản VietQR (Sprint 4, 4.5.3.2 – Nguyễn Minh Thức, Nguyễn Tuấn Khôi): danh sách khoản khách đã
 * báo chuyển khoản, quản trị viên kiểm tra sao kê rồi bấm "Đã nhận tiền" (đơn được xác nhận, cấp voucher) hoặc
 * "Không khớp" kèm lý do. Nút đối chiếu nằm ở trang chi tiết yêu cầu, cạnh số tiền và nội dung chuyển khoản.
 * Giao dịch VNPay chưa rõ kết quả (Nguyễn Tuấn Khôi): quản trị viên tra mã thanh toán trên cổng VNPay rồi ghi
 * "Có giao dịch thành công" (kèm mã giao dịch VNPay) hoặc "Không có giao dịch" (kèm lý do).
 * Giao dịch MoMo chưa rõ kết quả (Nguyễn Tuấn Khôi): nút "Tra cứu MoMo" gọi API query có chữ ký rồi ghi đúng kết quả
 * MoMo trả lời (quản trị viên không tự nhập kết quả).
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
            'momoPayments' => (new MomoPaymentModel())->queue(),
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

    /** POST /admin/payments/{id}/momo – _csrf: tra cứu lại khoản MoMo chưa rõ kết quả và ghi theo MoMo trả lời. */
    public function momoCheck(string $id): void
    {
        $paymentId = self::parseUuid($id) ?? self::notFound();
        if (!$this->csrfValid()) {
            $this->redirect('/admin/payments?err=csrf');
        }

        $momo = new MomoPaymentModel();
        $payment = $momo->queue(null, $paymentId)[0] ?? null;
        if ($payment === null) {
            $this->redirect('/admin/payments?err=not_payable');
        }
        $back = '/admin/bookings/' . $payment['booking_id'];
        $config = require BASE_PATH . '/config/payment.php';
        if (!MomoGateway::enabled($config)) {
            $this->redirect($back . '?err=momo_unavailable#payments');
        }

        $status = MomoGateway::query($config, (string) $payment['order_id']);
        if ($status === null) {
            $this->redirect($back . '?err=momo_query#payments');
        }
        if ($status['outcome'] === 'pending') {
            $this->redirect($back . '?err=momo_pending#payments');
        }

        try {
            $row = $momo->result((string) $payment['order_id'], (int) $status['amount_vnd'], (string) $status['result_code'],
                (string) $status['trans_id'], (string) $status['pay_type'], 'admin');
        } catch (Throwable $exception) {
            error_log('LocalTour: không ghi được kết quả tra cứu MoMo: ' . $exception->getMessage());
            $this->redirect($back . '?err=momo_query#payments');
        }

        if ($row['result'] === 'ok' && $row['booking_status'] === 'confirmed') {
            BookingMail::sendConfirmedForBooking((string) $payment['booking_id']);
        }
        match ((string) $row['result']) {
            'ok' => $this->redirect($back . '?msg=momo_paid#payments'),
            'failed' => $this->redirect($back . '?msg=momo_failed#payments'),
            'invalid_amount' => $this->redirect($back . '?err=momo_amount#payments'),
            default => $this->redirect($back . '?err=not_payable#payments'),
        };
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

        // Email "Đặt tour thành công" chỉ khi chính lần ghi nhận tiền này chuyển đơn sang "Đã xác nhận" (confirmed = 1).
        // Tiền tới muộn cho đơn đã hủy hoặc đã được xác nhận từ trước: không gửi lại.
        if ($result === 'ok' && (int) ($row['confirmed'] ?? 0) === 1) {
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
