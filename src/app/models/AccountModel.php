<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Trang "Tài khoản" của khách hàng (CR3 – Lê Trung Phong): họ tên, số điện thoại, ảnh đại diện và mật khẩu.
 * Procedure: LTP_sp_account_get, LTP_sp_account_update_profile, LTP_sp_account_set_avatar,
 *            LTP_sp_account_get_password_hash, LTP_sp_account_set_password (37_procedures_LTP_account.sql).
 * Chỉ tài khoản khách hàng đang hoạt động; tài khoản khác / đã khóa: procedure trả 'not_found'.
 */
final class AccountModel
{
    /**
     * Tài khoản khách hàng đang hoạt động; null nếu không có (sai id, không phải khách hàng, đã khóa).
     *
     * @return array{user_id: string, email: string, name: string, phone: ?string, role: string,
     *               avatar_url: ?string, has_password: bool}|null
     */
    public function find(string $userId): ?array
    {
        $row = Database::call('LTP_sp_account_get', [$userId])[0] ?? null;
        if ($row === null) {
            return null;
        }

        return [
            'user_id' => (string) $row['user_id'],
            'email' => (string) $row['email'],
            'name' => (string) $row['name'],
            'phone' => $row['phone'] === null ? null : (string) $row['phone'],
            'role' => (string) $row['role'],
            'avatar_url' => $row['avatar_url'] === null || $row['avatar_url'] === '' ? null : (string) $row['avatar_url'],
            'has_password' => (int) $row['has_password'] === 1,
        ];
    }

    /** Lưu họ tên và số điện thoại ('' = xóa số). true khi đã lưu. */
    public function updateProfile(string $userId, string $name, string $phone): bool
    {
        $row = Database::call('LTP_sp_account_update_profile', [$userId, $name, $phone === '' ? null : $phone])[0] ?? null;

        return ($row['result'] ?? '') === 'ok';
    }

    /**
     * Đặt ảnh đại diện mới (null = xóa ảnh).
     *
     * @return array{ok: bool, old_avatar_url: ?string} old_avatar_url = ảnh trước đó để xóa file cũ.
     */
    public function setAvatar(string $userId, ?string $avatarUrl): array
    {
        $row = Database::call('LTP_sp_account_set_avatar', [$userId, $avatarUrl])[0] ?? null;
        $old = $row['old_avatar_url'] ?? null;

        return [
            'ok' => ($row['result'] ?? '') === 'ok',
            'old_avatar_url' => is_string($old) && $old !== '' ? $old : null,
        ];
    }

    /** Chuỗi băm mật khẩu hiện tại; null = chưa đặt mật khẩu hoặc không tìm thấy tài khoản. */
    public function passwordHash(string $userId): ?string
    {
        $hash = Database::call('LTP_sp_account_get_password_hash', [$userId])[0]['password_hash'] ?? null;

        return is_string($hash) && $hash !== '' ? $hash : null;
    }

    /** Lưu mật khẩu mới đã băm bằng password_hash(). true khi đã lưu. */
    public function setPassword(string $userId, string $passwordHash): bool
    {
        $row = Database::call('LTP_sp_account_set_password', [$userId, $passwordHash])[0] ?? null;

        return ($row['result'] ?? '') === 'ok';
    }
}
