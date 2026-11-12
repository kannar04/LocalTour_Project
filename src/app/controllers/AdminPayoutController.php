<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\PaymentResultModel;
use App\Models\PayoutModel;
use App\Models\SettingModel;

/**
 * Chi trả cho đơn vị tổ chức (Nguyễn Tuấn Khôi). Sau khi lịch khởi hành kết thúc và không còn gì dang dở, hệ thống tự
 * lập một khoản chi trả cho mỗi lịch: tiền thực thu, phí dịch vụ LocalTour, thực nhận. Quản trị viên chuyển khoản cho
 * đơn vị ngoài hệ thống rồi ghi nhận đã chi trả kèm mã giao dịch. Trang danh sách còn có các lịch chưa lập được khoản chi
 * trả (kèm lý do) và các khoản hoàn tiền còn phải chuyển lại cho khách: ghi "Đã hoàn tiền" xong thì lịch mới được chi trả.
 * Mọi thao tác ghi đều qua procedure (file 30), procedure kiểm tra lại quyền quản trị và ghi admin_logs.
 */
final class AdminPayoutController extends AdminController
{
    private const MESSAGES = [
        'paid' => 'Đã ghi nhận chuyển khoản. Khoản chi trả chuyển sang “Đã chi trả”.',
        'refunded' => 'Đã ghi nhận hoàn tiền cho khách.',
    ];

    private const EMPTY_FORM = ['reference' => '', 'note' => ''];

    private PayoutModel $payouts;

    public function __construct()
    {
        parent::__construct();
        $this->payouts = new PayoutModel();
        // Tự hủy đơn quá hạn, tự hoàn thành đơn của lịch đã kết thúc và lập khoản chi trả trước khi hiện trang.
        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /admin/payouts?status=pending|paid|all (mặc định pending) */
    public function index(): void
    {
        $this->renderIndex([], '', $this->flash(self::MESSAGES));
    }

    /** GET /admin/payouts/{id} */
    public function show(string $id): void
    {
        $this->renderShow($this->findOrFail($id), self::EMPTY_FORM, [], $this->flash(self::MESSAGES));
    }

    /** POST /admin/payouts/{id}/pay – reference (mã giao dịch chuyển khoản, bắt buộc), note, account_no (ô ẩn: số tài khoản đang hiện trên trang), _csrf */
    public function pay(string $id): void
    {
        $payout = $this->findOrFail($id);
        $old = ['reference' => $this->input('reference'), 'note' => $this->input('note')];
        if (!$this->csrfValid()) {
            $this->renderShow($payout, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $errors = [];
        if ($old['reference'] === '') {
            $errors['reference'] = 'Vui lòng nhập mã giao dịch chuyển khoản.';
        } elseif (mb_strlen($old['reference']) > PayoutModel::REFERENCE_MAX_LENGTH) {
            $errors['reference'] = 'Mã giao dịch tối đa ' . PayoutModel::REFERENCE_MAX_LENGTH . ' ký tự.';
        }
        if (mb_strlen($old['note']) > PayoutModel::NOTE_MAX_LENGTH) {
            $errors['note'] = 'Ghi chú tối đa ' . PayoutModel::NOTE_MAX_LENGTH . ' ký tự.';
        }
        if ($errors !== []) {
            $this->renderShow($payout, $old, $errors, '', 422);
            return;
        }

        $payoutId = (string) $payout['payout_id'];
        match ($this->payouts->pay($this->actorId(), $payoutId, $old['reference'], $old['note'], $this->input('account_no'))) {
            'ok' => $this->redirect('/admin/payouts/' . $payoutId . '?msg=paid'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'reference_required' => $this->renderShow($payout, $old, ['reference' => 'Vui lòng nhập mã giao dịch chuyển khoản.'], '', 422),
            'invalid' => $this->renderShow($payout, $old, ['form' => 'Mã giao dịch hoặc ghi chú quá dài, vui lòng kiểm tra lại.'], '', 422),
            // Khoản hoặc tài khoản của đơn vị vừa thay đổi: tải lại số liệu mới nhất rồi báo lỗi.
            'already_paid' => $this->renderShow($this->findOrFail($payoutId), $old, ['form' => 'Khoản chi trả này đã được ghi “Đã chi trả” trước đó.'], '', 409),
            'bank_missing' => $this->renderShow($this->findOrFail($payoutId), $old, ['form' => 'Đơn vị chưa khai đủ tài khoản nhận tiền nên chưa ghi nhận đã chi trả được. Hãy nhắc đơn vị khai ở mục “Tài khoản nhận tiền” của khu đơn vị tổ chức.'], '', 409),
            'bank_changed' => $this->renderShow($this->findOrFail($payoutId), $old, ['form' => 'Đơn vị vừa đổi tài khoản nhận tiền. Trang đã tải lại tài khoản mới: hãy kiểm tra bạn đã chuyển khoản tới đúng tài khoản này rồi mới ghi nhận đã chi trả.'], '', 409),
            default => $this->renderShow($payout, $old, ['form' => 'Không ghi nhận được, vui lòng thử lại.'], '', 409),
        };
    }

    /** POST /admin/refunds/{id}/complete – reference (mã giao dịch hoàn tiền, bắt buộc), _csrf */
    public function completeRefund(string $id): void
    {
        $refundId = self::parseUuid($id) ?? self::notFound();
        $reference = $this->input('reference');
        if (!$this->csrfValid()) {
            $this->renderIndex([$refundId => self::CSRF_FAILED], $reference, '', 403);
            return;
        }

        if ($reference === '') {
            $this->renderIndex([$refundId => 'Vui lòng nhập mã giao dịch hoàn tiền.'], $reference, '', 422);
            return;
        }
        if (mb_strlen($reference) > PayoutModel::REFERENCE_MAX_LENGTH) {
            $this->renderIndex([$refundId => 'Mã giao dịch tối đa ' . PayoutModel::REFERENCE_MAX_LENGTH . ' ký tự.'], $reference, '', 422);
            return;
        }

        match ($this->payouts->completeRefund($this->actorId(), $refundId, $reference)) {
            'ok' => $this->redirect('/admin/payouts?msg=refunded'),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'not_open' => $this->renderIndex(['form' => 'Khoản hoàn tiền này đã được xử lý trước đó.'], '', '', 409),
            default => $this->renderIndex([$refundId => 'Mã giao dịch hoàn tiền không hợp lệ.'], $reference, '', 422),
        };
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $id): array
    {
        $payoutId = self::parseUuid($id);
        $payout = $payoutId === null ? null : $this->payouts->adminFind($payoutId);

        return $payout ?? self::notFound();
    }

    /**
     * @param array<string, string> $refundErrors lỗi theo mã khoản hoàn; 'form' = lỗi chung
     */
    private function renderIndex(array $refundErrors, string $oldReference, string $success, int $status = 200): void
    {
        $filter = $this->query('status');
        if (!isset(PayoutModel::FILTERS[$filter])) {
            $filter = 'pending';
        }

        // Lỗi của khoản hoàn không còn trong danh sách chờ (vừa được xử lý ở tab khác): không có dòng nào để hiện lỗi,
        // nên báo ở đầu trang.
        $refunds = $this->payouts->openRefunds();
        $openIds = array_column($refunds, 'refund_id');
        foreach (array_keys($refundErrors) as $key) {
            if ($key !== 'form' && !in_array($key, $openIds, true)) {
                unset($refundErrors[$key]);
                $refundErrors['form'] = 'Khoản hoàn tiền này không còn trong danh sách chờ (đã được xử lý trước đó).';
            }
        }

        $this->render('admin/payouts/index', [
            'title' => 'Chi trả đơn vị tổ chức',
            'adminNav' => 'payouts',
            'filter' => $filter,
            'summary' => $this->payouts->adminSummary(),
            'payouts' => $this->payouts->adminList($filter === 'all' ? '' : $filter),
            'waiting' => $this->payouts->waiting(),
            'refunds' => $refunds,
            'payoutsFrom' => (new SettingModel())->payoutsFrom(),
            'refundErrors' => $refundErrors,
            'oldReference' => $oldReference,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }

    /**
     * @param array<string, mixed> $payout
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderShow(array $payout, array $old, array $errors, string $success, int $status = 200): void
    {
        $this->render('admin/payouts/show', [
            'title' => 'Chi trả · ' . $payout['tour_title'],
            'adminNav' => 'payouts',
            'payout' => $payout,
            'items' => $this->payouts->adminItems((string) $payout['payout_id']),
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
