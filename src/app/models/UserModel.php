<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;
use Core\DatabaseException;
use PDOException;

/**
 * Tài khoản khách hàng: đăng ký và tìm theo email (WBS 3.2.8 – Nguyễn Tuấn Khôi).
 * Procedure: NTK_sp_customer_register, NTK_sp_user_find_by_email, NTK_sp_social_login (đăng nhập Google / Facebook).
 */
final class UserModel
{
    public const NAME_MAX_LENGTH = 100;
    public const EMAIL_MAX_LENGTH = 150;
    public const PHONE_MAX_LENGTH = 20;
    public const PASSWORD_MIN_LENGTH = 8;
    /** password_hash() (bcrypt) chỉ dùng 72 byte đầu của mật khẩu. */
    public const PASSWORD_MAX_LENGTH = 72;

    /**
     * Tài khoản theo email (không phân biệt hoa thường); null nếu chưa có.
     *
     * @return array<string, mixed>|null
     */
    public function findByEmail(string $email): ?array
    {
        $rows = Database::call('NTK_sp_user_find_by_email', [mb_strtolower($email)]);

        return $rows[0] ?? null;
    }

    /**
     * Tạo tài khoản khách hàng với mật khẩu đã băm. Trả về user_id mới, hoặc null khi email đã được dùng.
     */
    public function registerCustomer(string $name, string $email, string $phone, string $passwordHash): ?string
    {
        $rows = Database::call('NTK_sp_customer_register', [
            $name,
            mb_strtolower($email),
            $phone === '' ? null : $phone,
            $passwordHash,
        ]);
        $userId = $rows[0]['user_id'] ?? null;

        return $userId === null ? null : (string) $userId;
    }

    /**
     * Đăng nhập bằng Google / Facebook: tài khoản đã liên kết, hoặc liên kết vào tài khoản khách hàng cùng email,
     * hoặc tạo tài khoản khách hàng mới (chưa có mật khẩu). Một dòng: result ('existing' / 'linked' / 'created' =
     * đăng nhập được; 'not_customer', 'locked', 'invalid', 'retry'), user_id, name, email, role.
     * null khi chưa chạy file 24_social_login_NTK.sql hoặc lỗi database (đã ghi log).
     *
     * @return array<string, mixed>|null
     */
    public function socialLogin(string $provider, string $providerUserId, string $email, string $name): ?array
    {
        try {
            $rows = Database::call('NTK_sp_social_login', [$provider, $providerUserId, mb_strtolower($email), $name]);
        } catch (PDOException | DatabaseException $exception) {
            error_log('NTK_sp_social_login: ' . $exception->getMessage());

            return null;
        }

        return $rows[0] ?? null;
    }
}
