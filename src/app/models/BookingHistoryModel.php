<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Lịch sử của đơn đặt tour (Sprint 4, 4.3.3.2, FR-11, NFR-09 – Lê Trung Phong): thao tác của khách, hệ thống,
 * VNPay (booking_events) và của quản trị viên (admin_logs), cũ trước.
 * Procedure: LTP_sp_customer_booking_history, LTP_sp_booking_history.
 */
final class BookingHistoryModel
{
    /**
     * Lịch sử cho trang "Đơn của tôi" (chỉ đơn của tài khoản này, không có tên quản trị viên).
     *
     * @return list<array<string, mixed>>
     */
    public function forCustomer(string $userId, string $code): array
    {
        return Database::call('LTP_sp_customer_booking_history', [$userId, $code]);
    }

    /**
     * Lịch sử đầy đủ cho trang quản trị (có tên người thao tác).
     *
     * @return list<array<string, mixed>>
     */
    public function forAdmin(string $bookingId): array
    {
        return Database::call('LTP_sp_booking_history', [$bookingId]);
    }
}
