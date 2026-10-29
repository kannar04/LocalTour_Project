<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Lưu yêu cầu đặt tour (M4 mục 6 – Lê Trung Phong): một đơn 'pending' kèm dòng vé, phụ thu / tùy chọn khách chọn
 * (Sprint 4, 4.3.3.1) và danh sách khách; ghi lịch sử "tạo đơn" (4.3.3.2).
 * Procedure: LTP_sp_booking_create.
 */
final class BookingModel
{
    public const PASSENGERS_MAX = 50;
    public const PASSENGER_NAME_MAX_LENGTH = 100;
    public const SPECIAL_REQUEST_MAX_LENGTH = 500;
    public const EXTRAS_MAX = 20;

    /**
     * Tạo yêu cầu đặt tour. Trả dòng kết quả của procedure: result (ok, duplicate, forbidden, invalid,
     * schedule_unavailable, group_limit, no_seats, tickets_changed, extras_changed, price_changed, retry),
     * booking_code, total_vnd, remaining, max_group_size.
     *
     * @param array{name: string, email: string, phone: string} $contact
     * @param list<array{ticket_type_id: string, full_name: string}> $passengers Theo thứ tự trên form.
     * @param list<string> $extraIds Mã các khoản phụ thu / tùy chọn khách chọn (không trùng).
     * @return array<string, mixed>
     */
    public function create(
        string $userId,
        string $scheduleId,
        string $requestToken,
        array $contact,
        array $passengers,
        string $specialRequest,
        int $expectedTotal,
        array $extraIds = []
    ): array {
        $rows = Database::call('LTP_sp_booking_create', [
            $userId,
            $scheduleId,
            $requestToken,
            $contact['name'],
            $contact['email'],
            $contact['phone'],
            json_encode($passengers, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
            $specialRequest === '' ? null : $specialRequest,
            $expectedTotal,
            json_encode(array_values($extraIds), JSON_THROW_ON_ERROR),
        ]);

        return $rows[0] ?? ['result' => 'retry'];
    }
}
