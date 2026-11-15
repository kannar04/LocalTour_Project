<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Mã xác minh email của tài khoản khách hàng (Nguyễn Tuấn Khôi – NTK): xác minh email hiện tại và đổi email.
 * Procedure: NTK_sp_email_verify_state, NTK_sp_email_verify_issue, NTK_sp_email_verify_attempt,
 *            NTK_sp_email_verify_confirm, NTK_sp_email_verify_cancel (40_email_verify_NTK.sql).
 * Database chỉ nhận chuỗi băm của mã (password_hash); so mã bằng password_verify ở AccountEmailController.
 * Lỗi database được ném ra để controller bắt và chỉ ghi thông báo lỗi (không ghi tham số).
 */
final class EmailVerificationModel
{
    public const PURPOSE_VERIFY = 'verify';
    public const PURPOSE_CHANGE = 'change';

    /**
     * Tình trạng xác minh email; null khi không phải tài khoản khách hàng đang hoạt động.
     *
     * @return array{email: string, verified_at: ?string, verify_expires_at: ?string, change_email: ?string,
     *               change_expires_at: ?string, wait_seconds: int}|null
     */
    public function state(string $userId): ?array
    {
        $row = Database::call('NTK_sp_email_verify_state', [$userId])[0] ?? null;
        if ($row === null) {
            return null;
        }

        return [
            'email' => (string) $row['email'],
            'verified_at' => self::textOrNull($row['email_verified_at']),
            'verify_expires_at' => self::textOrNull($row['verify_expires_at']),
            'change_email' => self::textOrNull($row['change_email']),
            'change_expires_at' => self::textOrNull($row['change_expires_at']),
            'wait_seconds' => max(0, (int) $row['wait_seconds']),
        ];
    }

    /**
     * Ghi mã mới (chuỗi băm) trước khi gửi email. $email chỉ dùng khi đổi email (email mới).
     * result: ok, already, same, taken, cooldown, limit, not_found, invalid (xem file 40).
     *
     * @return array{result: string, verification_id: ?string, email: ?string, name: string, wait_seconds: int,
     *               expires_at: ?string}
     */
    public function issue(string $userId, string $purpose, ?string $email, string $codeHash): array
    {
        $row = Database::call('NTK_sp_email_verify_issue', [$userId, $purpose, $email, $codeHash])[0] ?? [];

        return [
            'result' => (string) ($row['result'] ?? 'invalid'),
            'verification_id' => self::textOrNull($row['verification_id'] ?? null),
            'email' => self::textOrNull($row['email'] ?? null),
            'name' => (string) ($row['name'] ?? ''),
            'wait_seconds' => max(0, (int) ($row['wait_seconds'] ?? 0)),
            'expires_at' => self::textOrNull($row['expires_at'] ?? null),
        ];
    }

    /**
     * Giữ một lượt nhập của mã đang chờ (tăng số lần nhập trước khi so mã).
     * result: ok (kèm code_hash), none, locked, expired, not_found.
     *
     * @return array{result: string, verification_id: ?string, code_hash: ?string, email: ?string, attempts_left: int}
     */
    public function attempt(string $userId, string $purpose): array
    {
        $row = Database::call('NTK_sp_email_verify_attempt', [$userId, $purpose])[0] ?? [];

        return [
            'result' => (string) ($row['result'] ?? 'none'),
            'verification_id' => self::textOrNull($row['verification_id'] ?? null),
            'code_hash' => self::textOrNull($row['code_hash'] ?? null),
            'email' => self::textOrNull($row['email'] ?? null),
            'attempts_left' => max(0, (int) ($row['attempts_left'] ?? 0)),
        ];
    }

    /**
     * Mã đã đúng: đánh dấu đã xác minh / đổi email. result: ok, taken, not_found; email = email đăng nhập sau đó.
     *
     * @return array{result: string, purpose: ?string, email: ?string}
     */
    public function confirm(string $verificationId, string $userId): array
    {
        $row = Database::call('NTK_sp_email_verify_confirm', [$verificationId, $userId])[0] ?? [];

        return [
            'result' => (string) ($row['result'] ?? 'not_found'),
            'purpose' => self::textOrNull($row['purpose'] ?? null),
            'email' => self::textOrNull($row['email'] ?? null),
        ];
    }

    /** Bỏ mã vừa ghi khi gửi email lỗi. */
    public function cancel(string $verificationId, string $userId): void
    {
        Database::call('NTK_sp_email_verify_cancel', [$verificationId, $userId]);
    }

    private static function textOrNull(mixed $value): ?string
    {
        return $value === null || $value === '' ? null : (string) $value;
    }
}
