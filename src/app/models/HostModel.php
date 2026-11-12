<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Tài khoản đơn vị tổ chức (khu /host, Nguyễn Tuấn Khôi): đơn vị của tài khoản đang đăng nhập, tour của đơn vị,
 * đơn đặt tour trên tour của đơn vị (chỉ xem), đơn vị tự đăng ký (chờ duyệt) và mật khẩu đăng nhập do quản trị viên cấp.
 * Procedure: 27_procedures_NTK_host.sql.
 */
final class HostModel
{
    /**
     * Đơn vị tổ chức của tài khoản; null khi tài khoản không phải đơn vị tổ chức.
     *
     * @return array<string, mixed>|null provider_id, business_name, contact_phone, email, approval_status, user_status, tour_count
     */
    public function profile(string $userId): ?array
    {
        return Database::call('NTK_sp_host_profile', [$userId])[0] ?? null;
    }

    /** Đơn vị đang hợp tác và tài khoản đang hoạt động thì mới dùng được khu /host. */
    public static function isActive(?array $profile): bool
    {
        return $profile !== null && $profile['approval_status'] === 'approved' && $profile['user_status'] === 'active';
    }

    /** @return list<array<string, mixed>> Mọi tour của đơn vị (NTK_sp_host_tour_list). */
    public function tours(string $userId): array
    {
        return Database::call('NTK_sp_host_tour_list', [$userId]);
    }

    /**
     * Tour có thuộc đơn vị của tài khoản không; null = không phải tour của đơn vị.
     *
     * @return array<string, mixed>|null tour_id, approval_status, can_edit, reject_note
     */
    public function tourAccess(string $userId, string $tourId): ?array
    {
        return Database::call('NTK_sp_host_tour_access', [$userId, $tourId])[0] ?? null;
    }

    /**
     * Đơn đặt tour trên các tour của đơn vị (chỉ đọc), mới nhất trước. $status '' = mọi trạng thái, $tourId '' = mọi tour.
     *
     * @return list<array<string, mixed>>
     */
    public function bookings(string $userId, string $status = '', string $tourId = ''): array
    {
        return Database::call('NTK_sp_host_booking_list', [
            $userId,
            $status === '' ? null : $status,
            $tourId === '' ? null : $tourId,
        ]);
    }

    /**
     * Một đơn đặt tour của tour thuộc đơn vị; null = không có hoặc đơn của đơn vị khác.
     *
     * @return array<string, mixed>|null
     */
    public function booking(string $userId, string $bookingId): ?array
    {
        return Database::call('NTK_sp_host_booking_detail', [$userId, $bookingId])[0] ?? null;
    }

    /**
     * Yêu cầu đổi ngày / hủy tour của đơn (chỉ đọc), mới trước.
     *
     * @return list<array<string, mixed>>
     */
    public function bookingChanges(string $userId, string $bookingId): array
    {
        return Database::call('NTK_sp_host_booking_change_list', [$userId, $bookingId]);
    }

    /**
     * Tài khoản đăng nhập của đơn vị (cho form "Sửa đơn vị tổ chức").
     *
     * @return array<string, mixed>|null has_password, user_status
     */
    public function account(string $providerId): ?array
    {
        return Database::call('NTK_sp_admin_provider_account', [$providerId])[0] ?? null;
    }

    /**
     * Đơn vị tự đăng ký ở /host/register: tạo tài khoản và đơn vị ở trạng thái "Chờ duyệt". $passwordHash = password_hash().
     *
     * @return array{result: string, field: ?string} result: ok, invalid (field = ô sai), email_taken
     */
    public function register(string $businessName, string $contactPhone, string $email, string $passwordHash): array
    {
        $row = Database::call('NTK_sp_host_register', [$businessName, $contactPhone, mb_strtolower($email), $passwordHash])[0] ?? [];

        return ['result' => (string) ($row['result'] ?? 'invalid'), 'field' => isset($row['field']) ? (string) $row['field'] : null];
    }

    /**
     * Quản trị viên cấp / đổi mật khẩu đăng nhập của đơn vị. $passwordHash = password_hash().
     *
     * @return string ok, forbidden, not_found, invalid
     */
    public function setPassword(string $actorUserId, string $providerId, string $passwordHash): string
    {
        $rows = Database::call('NTK_sp_admin_provider_set_password', [$actorUserId, $providerId, $passwordHash]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }
}
