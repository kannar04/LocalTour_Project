<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * "Đơn của tôi" của khách hàng (M4 – Nguyễn Tuấn Khôi): danh sách đơn, chi tiết, dòng vé và danh sách khách.
 * Mọi procedure nhận user_id từ session và chỉ trả đơn của chính tài khoản đó.
 * Procedure: NTK_sp_customer_booking_list, NTK_sp_customer_booking_detail, NTK_sp_customer_booking_line_list,
 * NTK_sp_customer_booking_passenger_list.
 */
final class CustomerBookingModel
{
    /** Mã đơn do LTP_sp_booking_create sinh: LT + 6 chữ số. */
    public const CODE_PATTERN = '/^LT\d{6}$/';

    /**
     * Tối đa 100 đơn của tài khoản, mới đặt trước.
     *
     * @return list<array<string, mixed>>
     */
    public function list(string $userId): array
    {
        return Database::call('NTK_sp_customer_booking_list', [$userId]);
    }

    /**
     * Một đơn theo mã (chỉ đơn của tài khoản này); null nếu không có.
     *
     * @return array<string, mixed>|null
     */
    public function find(string $userId, string $code): ?array
    {
        return Database::call('NTK_sp_customer_booking_detail', [$userId, $code])[0] ?? null;
    }

    /**
     * Các dòng vé của đơn, vé đắt trước.
     *
     * @return list<array<string, mixed>>
     */
    public function lines(string $userId, string $code): array
    {
        return Database::call('NTK_sp_customer_booking_line_list', [$userId, $code]);
    }

    /**
     * Danh sách khách theo thứ tự nhập trên form.
     *
     * @return list<array<string, mixed>>
     */
    public function passengers(string $userId, string $code): array
    {
        return Database::call('NTK_sp_customer_booking_passenger_list', [$userId, $code]);
    }
}
