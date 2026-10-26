<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Kiểm tra lịch khởi hành trước khi đặt tour (M4 mục 5 – Nguyễn Minh Thức): lịch còn nhận khách không,
 * còn bao nhiêu chỗ và giá vé hiện tại. Đây chỉ là kiểm tra trước, LTP_sp_booking_create kiểm tra lại khi tạo đơn.
 * Procedure: NMT_sp_schedule_availability, NMT_sp_schedule_ticket_list.
 */
final class BookingAvailabilityModel
{
    /**
     * Lịch của tour đang hiển thị: số chỗ còn lại, nhóm tối đa, cờ bookable; null nếu không có.
     *
     * @return array<string, mixed>|null
     */
    public function find(string $scheduleId): ?array
    {
        return Database::call('NMT_sp_schedule_availability', [$scheduleId])[0] ?? null;
    }

    /**
     * Loại vé đang bán của lịch với giá hiện tại, vé đắt trước.
     *
     * @return list<array<string, mixed>>
     */
    public function tickets(string $scheduleId): array
    {
        return Database::call('NMT_sp_schedule_ticket_list', [$scheduleId]);
    }
}
