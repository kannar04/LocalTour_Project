<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\PaymentResultModel;
use App\Models\PayoutModel;

/**
 * Khu đơn vị tổ chức (Nguyễn Tuấn Khôi): "Doanh thu & chi trả" – đơn vị xem các khoản chi trả của mình (tiền thực thu,
 * phí dịch vụ LocalTour, thực nhận, trạng thái, mã giao dịch chuyển khoản) và các đơn trong từng khoản; "Tài khoản nhận
 * tiền" – đơn vị tự khai tài khoản ngân hàng để LocalTour chuyển khoản. Khoản chi trả do hệ thống lập sau khi lịch khởi
 * hành kết thúc, quản trị viên chuyển khoản rồi ghi nhận đã chi trả: đơn vị chỉ xem. Khoản của đơn vị khác: 404 như khoản
 * không tồn tại (procedure cũng không trả, file 30).
 */
final class HostPayoutController extends AdminController
{
    protected const PORTAL = 'host';

    private const MESSAGES = [
        'saved' => 'Đã lưu tài khoản nhận tiền.',
        'unchanged' => 'Không có thay đổi nào.',
    ];

    private const FIELD_ERRORS = [
        'bank_name' => 'Tên ngân hàng từ 2 đến 100 ký tự.',
        'bank_account_no' => 'Số tài khoản chỉ gồm chữ số, từ 6 đến 20 chữ số.',
        'bank_account_name' => 'Tên chủ tài khoản từ 2 đến 100 ký tự.',
    ];

    private PayoutModel $payouts;

    public function __construct()
    {
        parent::__construct();
        $this->payouts = new PayoutModel();
        // Đơn của lịch đã kết thúc tự hoàn thành và khoản chi trả được lập trước khi hiện trang.
        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /host/payouts */
    public function index(): void
    {
        $this->render('host/payouts/index', [
            'title' => 'Doanh thu & chi trả',
            'adminNav' => 'payouts',
            'summary' => $this->payouts->hostSummary($this->actorId()) ?? [],
            'payouts' => $this->payouts->hostList($this->actorId()),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /host/payouts/{id} */
    public function show(string $id): void
    {
        $payoutId = self::parseUuid($id) ?? self::notFound();
        $payout = $this->payouts->hostFind($this->actorId(), $payoutId) ?? self::notFound();

        $this->render('host/payouts/show', [
            'title' => 'Chi trả · ' . $payout['tour_title'],
            'adminNav' => 'payouts',
            'payout' => $payout,
            'items' => $this->payouts->hostItems($this->actorId(), $payoutId),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /host/bank */
    public function bank(): void
    {
        $bank = $this->payouts->hostBank($this->actorId()) ?? [];
        $this->renderBank([
            'bank_name' => (string) ($bank['bank_name'] ?? ''),
            'bank_account_no' => (string) ($bank['bank_account_no'] ?? ''),
            'bank_account_name' => (string) ($bank['bank_account_name'] ?? ''),
        ], [], $this->flash(self::MESSAGES));
    }

    /** POST /host/bank – bank_name, bank_account_no, bank_account_name, _csrf */
    public function saveBank(): void
    {
        $old = [
            'bank_name' => $this->input('bank_name'),
            // Số tài khoản hay được gõ kèm khoảng trắng / dấu chấm ngăn nhóm: bỏ trước khi kiểm tra.
            'bank_account_no' => str_replace([' ', '.', '-'], '', $this->input('bank_account_no')),
            'bank_account_name' => $this->input('bank_account_name'),
        ];
        if (!$this->csrfValid()) {
            $this->renderBank($old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        $errors = self::validate($old);
        if ($errors !== []) {
            $this->renderBank($old, $errors, '', 422);
            return;
        }

        $row = $this->payouts->saveHostBank($this->actorId(), $old['bank_name'], $old['bank_account_no'], $old['bank_account_name']);
        match ($row['result']) {
            'ok' => $this->redirect('/host/bank?msg=saved'),
            'unchanged' => $this->redirect('/host/bank?msg=unchanged'),
            'forbidden' => self::forbidden(),
            default => $this->renderBank($old, isset(self::FIELD_ERRORS[(string) $row['field']])
                ? [(string) $row['field'] => self::FIELD_ERRORS[(string) $row['field']]]
                : ['form' => 'Không lưu được, vui lòng kiểm tra lại thông tin.'], '', 422),
        };
    }

    /**
     * Lỗi theo từng ô; [] khi hợp lệ.
     *
     * @param array<string, string> $old
     * @return array<string, string>
     */
    private static function validate(array $old): array
    {
        $errors = [];
        if (mb_strlen($old['bank_name']) < 2 || mb_strlen($old['bank_name']) > PayoutModel::BANK_NAME_MAX_LENGTH) {
            $errors['bank_name'] = $old['bank_name'] === '' ? 'Vui lòng nhập tên ngân hàng.' : self::FIELD_ERRORS['bank_name'];
        }
        if (!ctype_digit($old['bank_account_no'])
            || strlen($old['bank_account_no']) < PayoutModel::BANK_NO_MIN_LENGTH
            || strlen($old['bank_account_no']) > PayoutModel::BANK_NO_MAX_LENGTH) {
            $errors['bank_account_no'] = $old['bank_account_no'] === '' ? 'Vui lòng nhập số tài khoản.' : self::FIELD_ERRORS['bank_account_no'];
        }
        if (mb_strlen($old['bank_account_name']) < 2 || mb_strlen($old['bank_account_name']) > PayoutModel::BANK_NAME_MAX_LENGTH) {
            $errors['bank_account_name'] = $old['bank_account_name'] === '' ? 'Vui lòng nhập tên chủ tài khoản.' : self::FIELD_ERRORS['bank_account_name'];
        }

        return $errors;
    }

    /**
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderBank(array $old, array $errors, string $success, int $status = 200): void
    {
        $this->render('host/payouts/bank', [
            'title' => 'Tài khoản nhận tiền',
            'adminNav' => 'bank',
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
