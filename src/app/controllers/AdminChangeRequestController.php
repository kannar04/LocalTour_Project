<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminChangeRequestModel;
use App\Models\PaymentResultModel;

/**
 * Xử lý thủ công yêu cầu đổi ngày / hủy tour (US14-S5-03, FR-12 – Nguyễn Tuấn Khôi).
 * Danh sách theo trạng thái, chi tiết kèm chính sách đã chụp lúc khách gửi, đồng ý / từ chối kèm ghi chú.
 * Đồng ý hủy: đơn bị hủy, trả chỗ, ghi số tiền hoàn để LocalTour chuyển khoản lại thủ công (chưa hoàn tự động).
 * Đồng ý đổi ngày: chuyển đơn sang lịch mới, giữ nguyên số khách và tổng tiền.
 * Mỗi lần xử lý được ghi vào lịch sử đơn (admin_logs, NFR-09).
 */
final class AdminChangeRequestController extends AdminController
{
    private const MESSAGES = [
        'approved' => 'Đã đồng ý yêu cầu và cập nhật đơn.',
        'rejected' => 'Đã từ chối yêu cầu. Đơn giữ nguyên.',
    ];

    private const EMPTY_FORM = ['decision' => '', 'note' => '', 'refund' => ''];

    private AdminChangeRequestModel $requests;

    public function __construct()
    {
        parent::__construct();
        $this->requests = new AdminChangeRequestModel();
        PaymentResultModel::expireHoldsQuietly();
    }

    /** GET /admin/change-requests?status=pending|approved|rejected|all (mặc định pending) */
    public function index(): void
    {
        $filter = $this->query('status');
        if (!isset(AdminChangeRequestModel::FILTERS[$filter])) {
            $filter = 'pending';
        }

        $this->render('admin/change-requests/index', [
            'title' => 'Yêu cầu đổi ngày / hủy tour',
            'adminNav' => 'change-requests',
            'filter' => $filter,
            'requests' => $this->requests->list($filter === 'all' ? '' : $filter),
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /admin/change-requests/{id} */
    public function show(string $id): void
    {
        $this->renderShow($this->findOrFail($id), self::EMPTY_FORM, [], $this->flash(self::MESSAGES));
    }

    /** POST /admin/change-requests/{id}/decide – decision (approved | rejected), note, refund (khi đồng ý hủy), _csrf */
    public function decide(string $id): void
    {
        $request = $this->findOrFail($id);
        $old = [
            'decision' => $this->input('decision'),
            'note' => $this->input('note'),
            'refund' => $this->input('refund'),
        ];
        if (!$this->csrfValid()) {
            $this->renderShow($request, $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        [$refund, $errors] = self::validate($old, $request);
        if ($errors !== []) {
            $this->renderShow($request, $old, $errors, '', 422);
            return;
        }

        $requestId = (string) $request['request_id'];
        $row = $this->requests->decide($this->actorId(), $requestId, $old['decision'], $old['note'], $refund);
        $people = (int) $request['people'];

        match ((string) $row['result']) {
            'ok' => $this->redirect('/admin/change-requests/' . $requestId . '?msg=' . $old['decision']),
            'forbidden' => self::forbidden(),
            'not_found' => self::notFound(),
            'invalid' => $this->renderShow($request, $old, self::fieldError($row['field'] ?? null), '', 422),
            // Yêu cầu, đơn hoặc lịch vừa thay đổi: tải lại số liệu mới nhất rồi báo lỗi.
            'already_handled' => $this->renderFresh($requestId, $old, 'Yêu cầu này đã được xử lý trước đó.'),
            'booking_closed' => $this->renderFresh($requestId, $old, 'Đơn đã đóng (bị từ chối, đã hủy hoặc đã hoàn thành) nên chỉ có thể từ chối yêu cầu.'),
            'payment_in_review' => $this->renderFresh($requestId, $old, 'Đơn còn khoản chuyển khoản chờ đối chiếu. Hãy đối chiếu ở trang "Đối chiếu thanh toán" trước khi đồng ý hủy.'),
            'schedule_unavailable' => $this->renderFresh($requestId, $old, 'Lịch khách muốn đổi sang không còn nhận khách (đã hủy, đã đầy hoặc đã khởi hành). Hãy từ chối và báo khách chọn ngày khác.'),
            'no_seats' => $this->renderFresh($requestId, $old, 'Lịch khách muốn đổi sang không còn đủ chỗ cho ' . $people . ' khách.'),
            'tickets_missing' => $this->renderFresh($requestId, $old, 'Lịch khách muốn đổi sang không bán đủ các loại vé của đơn (ví dụ vé trẻ em). Hãy thêm giá vé cho lịch đó hoặc từ chối yêu cầu.'),
            default => $this->renderFresh($requestId, $old, 'Không xử lý được yêu cầu, vui lòng thử lại.'),
        };
    }

    /**
     * @param array<string, string> $old
     * @param array<string, mixed> $request
     * @return array{0: ?int, 1: array<string, string>} [số tiền hoàn (null = theo dự kiến), lỗi]
     */
    private static function validate(array $old, array $request): array
    {
        $errors = [];
        if (!in_array($old['decision'], ['approved', 'rejected'], true)) {
            $errors['decision'] = 'Vui lòng chọn đồng ý hoặc từ chối.';
        }
        if ($old['note'] === '') {
            $errors['note'] = 'Vui lòng nhập ghi chú gửi khách (lý do đồng ý / từ chối).';
        } elseif (mb_strlen($old['note']) > AdminChangeRequestModel::NOTE_MAX_LENGTH) {
            $errors['note'] = 'Ghi chú tối đa ' . AdminChangeRequestModel::NOTE_MAX_LENGTH . ' ký tự.';
        }

        $refund = null;
        $refunds = $request['type'] === 'cancel' && $old['decision'] === 'approved';
        if ($refunds && $old['refund'] !== '') {
            $digits = str_replace(['.', ',', ' '], '', $old['refund']);
            $paid = (int) $request['paid_now_vnd'];
            if (!ctype_digit($digits) || strlen($digits) > 12 || (int) $digits > $paid) {
                $errors['refund'] = 'Số tiền hoàn từ 0đ đến số khách đã thanh toán (' . format_vnd($paid) . ').';
            } else {
                $refund = (int) $digits;
            }
        }

        return [$refund, $errors];
    }

    /** @return array<string, string> */
    private static function fieldError(mixed $field): array
    {
        $field = $field === 'refund_vnd' ? 'refund' : (string) $field;

        return isset(self::EMPTY_FORM[$field])
            ? [$field => 'Giá trị không hợp lệ, vui lòng kiểm tra lại.']
            : ['form' => 'Không xử lý được yêu cầu, vui lòng kiểm tra lại thông tin.'];
    }

    /** @return array<string, mixed> */
    private function findOrFail(string $id): array
    {
        $requestId = self::parseUuid($id);
        $request = $requestId === null ? null : $this->requests->find($requestId);

        return $request ?? self::notFound();
    }

    /** @param array<string, string> $old */
    private function renderFresh(string $requestId, array $old, string $error): void
    {
        $this->renderShow($this->findOrFail($requestId), $old, ['form' => $error], '', 409);
    }

    /**
     * @param array<string, mixed> $request
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderShow(array $request, array $old, array $errors, string $success, int $status = 200): void
    {
        $others = array_values(array_filter(
            $this->requests->list('', (string) $request['booking_id']),
            static fn (array $row): bool => $row['request_id'] !== $request['request_id']
        ));

        $this->render('admin/change-requests/show', [
            'title' => change_request_type_label((string) $request['type']) . ' · ' . $request['booking_code'],
            'adminNav' => 'change-requests',
            'request' => $request,
            'others' => $others,
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
