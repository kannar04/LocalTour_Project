<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Số liệu cho trang "Tổng quan" của quản trị viên (FR-19 → FR-23, Nguyễn Minh Thức).
 * Procedure: NMT_sp_admin_summary, NMT_sp_admin_booking_status_stats,
 * NMT_sp_admin_booking_time_stats, NMT_sp_admin_revenue_stats.
 */
final class AdminStatsModel
{
    /**
     * Tài khoản khách hàng (FR-19), tour theo trạng thái duyệt (FR-20) và số yêu cầu chờ xác nhận.
     *
     * @return array<string, mixed>
     */
    public function summary(): array
    {
        return Database::call('NMT_sp_admin_summary')[0] ?? [];
    }

    /**
     * Số yêu cầu đặt tour theo từng trạng thái (FR-21), luôn đủ 6 trạng thái.
     *
     * @return list<array<string, mixed>>
     */
    public function bookingsByStatus(): array
    {
        return Database::call('NMT_sp_admin_booking_status_stats');
    }

    /**
     * Số yêu cầu đặt tour theo ngày tạo (FR-22). $period: 'day' | 'month' | 'year'; ngày dạng 'Y-m-d', null = không giới hạn.
     *
     * @return list<array<string, mixed>>
     */
    public function bookingsByTime(string $period, ?string $from, ?string $to): array
    {
        return Database::call('NMT_sp_admin_booking_time_stats', [$period, $from, $to]);
    }

    /**
     * Doanh thu theo ngày thanh toán (FR-23): gross_vnd, refund_vnd, net_vnd cho từng kỳ.
     *
     * @return list<array<string, mixed>>
     */
    public function revenue(string $period, ?string $from, ?string $to): array
    {
        return Database::call('NMT_sp_admin_revenue_stats', [$period, $from, $to]);
    }
}