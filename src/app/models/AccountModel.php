<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;
use Throwable;

/**
 * Trang "Tài khoản" của khách hàng (CR2 – Lê Trung Phong): họ tên, số điện thoại, số CCCD, ngày sinh, giới tính,
 * địa chỉ, ảnh đại diện và mật khẩu.
 * Procedure: LTP_sp_account_get, LTP_sp_account_update_profile, LTP_sp_account_set_avatar,
 *            LTP_sp_account_get_password_hash, LTP_sp_account_set_password (37_procedures_LTP_account.sql;
 *            cột thông tin cá nhân ở 39_migration_profile_LTP.sql).
 * Chỉ tài khoản khách hàng đang hoạt động; tài khoản khác / đã khóa: procedure trả 'not_found'.
 * Số CCCD là thông tin nhạy cảm: chỉ trả cho trang "Tài khoản" của chủ tài khoản, không ghi vào nhật ký.
 */
final class AccountModel
{
    /**
     * Tài khoản khách hàng đang hoạt động; null nếu không có (sai id, không phải khách hàng, đã khóa).
     * citizen_id, date_of_birth (Y-m-d), gender ('male' / 'female' / 'other'), address: null = chưa cập nhật.
     *
     * @return array{user_id: string, email: string, name: string, phone: ?string, citizen_id: ?string,
     *               date_of_birth: ?string, gender: ?string, address: ?string, role: string,
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
            'citizen_id' => self::textOrNull($row['citizen_id'] ?? null),
            'date_of_birth' => self::textOrNull($row['date_of_birth'] ?? null),
            'gender' => self::textOrNull($row['gender'] ?? null),
            'address' => self::textOrNull($row['address'] ?? null),
            'role' => (string) $row['role'],
            'avatar_url' => $row['avatar_url'] === null || $row['avatar_url'] === '' ? null : (string) $row['avatar_url'],
            'has_password' => (int) $row['has_password'] === 1,
        ];
    }

    /**
     * Lưu thông tin cá nhân (đã kiểm tra ở controller). Ô không bắt buộc '' = xóa giá trị. true khi đã lưu.
     * Lỗi database: trả false, nhật ký chỉ có thông báo lỗi của database (không có tham số).
     *
     * @param array{name: string, phone: string, citizen_id: string, date_of_birth: string, gender: string,
     *              address: string} $profile date_of_birth dạng Y-m-d
     */
    public function updateProfile(string $userId, array $profile): bool
    {
        $optional = static fn (string $value): ?string => $value === '' ? null : $value;
        try {
            $row = Database::call('LTP_sp_account_update_profile', [
                $userId,
                $profile['name'],
                $optional($profile['phone']),
                $optional($profile['citizen_id']),
                $optional($profile['date_of_birth']),
                $optional($profile['gender']),
                $optional($profile['address']),
            ])[0] ?? null;
        } catch (Throwable $exception) {
            // Chỉ thông báo lỗi, không ghi cả exception: dấu vết ngăn xếp có thể chứa tham số (số CCCD).
            error_log('LTP_sp_account_update_profile: ' . $exception->getMessage());

            return false;
        }

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

    private static function textOrNull(mixed $value): ?string
    {
        return $value === null || $value === '' ? null : (string) $value;
    }
}
