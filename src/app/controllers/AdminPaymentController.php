<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminPaymentModel;
use App\Models\PaymentResultModel;

/**
 * Đối chiếu chuyển khoản VietQR (Sprint 4, 4.5.3.2 – Nguyễn Minh Thức, Nguyễn Tuấn Khôi): danh sách khoản khách đã
 * báo chuyển khoản, quản trị viên kiểm tra sao kê rồi bấm "Đã nhận tiền" (đơn được xác nhận, cấp voucher) hoặc
 * "Không khớp" kèm lý do. Nút đối chiếu nằm ở trang chi tiết yêu cầu, cạnh số tiền và nội dung chuyển khoản.
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
        $result = (string) $row['result'];
        $bookingId = (string) ($row['booking_id'] ?? '');

        match ($result) {
            'ok' => $this->redirect('/admin/bookings/' . $bookingId . '?msg=payment_' . $decision . '#payments'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            default => $this->redirect($bookingId !== ''
                ? '/admin/bookings/' . $bookingId . '?err=' . $result . '#payments'
                : '/admin/payments?err=' . $result),
        };
    }
}
