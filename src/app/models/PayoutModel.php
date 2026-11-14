<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Dòng tiền sau tour (Nguyễn Tuấn Khôi): đơn tự hoàn thành khi lịch kết thúc, phí dịch vụ LocalTour, khoản chi trả cho
 * đơn vị tổ chức (quản trị viên chuyển khoản ngoài hệ thống rồi ghi nhận đã chi trả), khoản hoàn tiền còn phải chuyển cho
 * khách và tài khoản nhận tiền của đơn vị. Procedure: 30_procedures_NTK_payout.sql.
 */
final class PayoutModel
{
    public const STATUS_LABELS = ['pending' => 'Chờ chi trả', 'paid' => 'Đã chi trả'];
    public const FILTERS = ['pending' => 'Chờ chi trả', 'paid' => 'Đã chi trả', 'all' => 'Tất cả'];
    public const REFERENCE_MAX_LENGTH = 100;
    public const NOTE_MAX_LENGTH = 255;
    public const BANK_NAME_MAX_LENGTH = 100;
    public const BANK_NO_MIN_LENGTH = 6;
    public const BANK_NO_MAX_LENGTH = 20;

    /** Trạng thái khoản chi trả (host_payouts.status) → nhãn tiếng Việt. */
    public static function statusLabel(?string $status): string
    {
        return self::STATUS_LABELS[(string) $status] ?? (string) $status;
    }

    /** "10.00" → "10%", "12.50" → "12,5%". */
    public static function percentText(int|float|string|null $rate): string
    {
        $text = number_format((float) $rate, 2, ',', '');

        return rtrim(rtrim($text, '0'), ',') . '%';
    }

    /**
     * Việc định kỳ sau tour: đơn của lịch đã kết thúc tự "Đã hoàn thành", lịch đã kết thúc "Đã hoàn thành", lập khoản
     * chi trả cho lịch không còn gì dang dở. Gọi nhiều lần / cùng lúc vẫn an toàn.
     *
     * @return array{completed: int, schedules_completed: int, payouts: int}
     */
    public function sweep(): array
    {
        $row = Database::call('NTK_sp_payout_sweep')[0] ?? [];

        return [
            'completed' => (int) ($row['completed'] ?? 0),
            'schedules_completed' => (int) ($row['schedules_completed'] ?? 0),
            'payouts' => (int) ($row['payouts'] ?? 0),
        ];
    }

    /** @return list<array<string, mixed>> Khoản chi trả cho trang quản trị; $status '' = tất cả. */
    public function adminList(string $status = ''): array
    {
        return Database::call('NTK_sp_admin_payout_list', [$status === '' ? null : $status]);
    }

    /** @return array<string, mixed> Tổng: gross_vnd, commission_vnd, net_pending_vnd, net_paid_vnd, pending_count, paid_count. */
    public function adminSummary(): array
    {
        return Database::call('NTK_sp_admin_payout_summary')[0] ?? [];
    }

    /** @return array<string, mixed>|null */
    public function adminFind(string $payoutId): ?array
    {
        return Database::call('NTK_sp_admin_payout_detail', [$payoutId])[0] ?? null;
    }

    /** @return list<array<string, mixed>> Các đơn trong khoản chi trả. */
    public function adminItems(string $payoutId): array
    {
        return Database::call('NTK_sp_admin_payout_item_list', [$payoutId]);
    }

    /**
     * Ghi nhận đã chi trả cho khoản chi trả. $seenAccountNo = số tài khoản quản trị viên thấy trên trang lúc chuyển khoản;
     * đơn vị vừa đổi số tài khoản thì trả bank_changed, không ghi. Tài khoản đơn vị đang khai chưa được quản trị viên xác
     * minh (verifyBank) thì trả bank_unverified, không ghi.
     *
     * @return string ok, forbidden, reference_required, invalid, not_found, already_paid, bank_missing, bank_changed,
     *                bank_unverified
     */
    public function pay(string $actorUserId, string $payoutId, string $reference, string $note, string $seenAccountNo): string
    {
        $rows = Database::call('NTK_sp_admin_payout_pay', [$actorUserId, $payoutId, $reference, $note, $seenAccountNo]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /**
     * Quản trị viên xác minh tài khoản nhận tiền đơn vị đang khai (đã kiểm tra với đơn vị ngoài hệ thống). $seen* = đúng
     * thông tin quản trị viên thấy trên trang; đơn vị vừa đổi tài khoản thì trả bank_changed, không ghi. Đơn vị sửa tài
     * khoản thì dấu xác minh bị xóa, phải xác minh lại.
     *
     * @return string ok, unchanged (đã xác minh trước đó), forbidden, not_found, bank_missing, bank_changed
     */
    public function verifyBank(string $actorUserId, string $providerId, string $seenBankName, string $seenAccountNo, string $seenAccountName): string
    {
        $rows = Database::call('NTK_sp_admin_provider_bank_verify', [$actorUserId, $providerId, $seenBankName, $seenAccountNo, $seenAccountName]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /** @return list<array<string, mixed>> Lịch đã kết thúc chưa lập được khoản chi trả và lý do. */
    public function waiting(): array
    {
        return Database::call('NTK_sp_admin_payout_waiting_list');
    }

    /** @return list<array<string, mixed>> Khoản hoàn tiền LocalTour còn phải chuyển lại cho khách. */
    public function openRefunds(): array
    {
        return Database::call('NTK_sp_admin_refund_open_list');
    }

    /**
     * Ghi "Đã hoàn tiền" cho một khoản hoàn.
     *
     * @return string ok, forbidden, not_found, reference_required, invalid, not_open
     */
    public function completeRefund(string $actorUserId, string $refundId, string $reference): string
    {
        $rows = Database::call('NTK_sp_admin_refund_complete', [$actorUserId, $refundId, $reference]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /**
     * @return array<string, mixed>|null commission_percent, has_bank, bank_verified (1 = LocalTour đã xác minh tài khoản
     *         đang khai), payout_count, gross_vnd, commission_vnd, net_pending_vnd, net_paid_vnd
     */
    public function hostSummary(string $userId): ?array
    {
        return Database::call('NTK_sp_host_payout_summary', [$userId])[0] ?? null;
    }

    /** @return list<array<string, mixed>> Khoản chi trả của đơn vị đang đăng nhập. */
    public function hostList(string $userId): array
    {
        return Database::call('NTK_sp_host_payout_list', [$userId]);
    }

    /** @return array<string, mixed>|null null = không có hoặc khoản của đơn vị khác. */
    public function hostFind(string $userId, string $payoutId): ?array
    {
        return Database::call('NTK_sp_host_payout_detail', [$userId, $payoutId])[0] ?? null;
    }

    /** @return list<array<string, mixed>> */
    public function hostItems(string $userId, string $payoutId): array
    {
        return Database::call('NTK_sp_host_payout_item_list', [$userId, $payoutId]);
    }

    /**
     * @return array<string, mixed>|null bank_name, bank_account_no, bank_account_name (null = chưa khai),
     *         bank_verified_at (null = LocalTour chưa xác minh tài khoản đang khai)
     */
    public function hostBank(string $userId): ?array
    {
        return Database::call('NTK_sp_host_bank', [$userId])[0] ?? null;
    }

    /**
     * Đơn vị khai / sửa tài khoản nhận tiền. Tài khoản đổi thì dấu xác minh của LocalTour bị xóa.
     *
     * @return array{result: string, field: ?string} result: ok, unchanged, forbidden, invalid (field = ô sai)
     */
    public function saveHostBank(string $userId, string $bankName, string $accountNo, string $accountName): array
    {
        $row = Database::call('NTK_sp_host_bank_save', [$userId, $bankName, $accountNo, $accountName])[0] ?? [];

        return ['result' => (string) ($row['result'] ?? 'invalid'), 'field' => isset($row['field']) ? (string) $row['field'] : null];
    }
}
