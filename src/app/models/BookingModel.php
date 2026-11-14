<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Lưu đơn đặt tour (M4 mục 6 – Lê Trung Phong): một đơn 'awaiting_payment' (Chờ thanh toán) đã giữ chỗ, kèm dòng vé,
 * phụ thu / tùy chọn khách chọn (Sprint 4, 4.3.3.1), gói tour khách chọn (Sprint 5, US06-S5-01) và danh sách khách;
 * ghi lịch sử "tạo đơn" (4.3.3.2). Đặt ngay, không chờ quản trị viên xác nhận chỗ (Nguyễn Tuấn Khôi).
 * Procedure: LTP_sp_booking_create, NTK_sp_booking_rules.
 */
final class BookingModel
{
    public const PASSENGERS_MAX = 50;
    public const PASSENGER_NAME_MAX_LENGTH = 100;
    public const SPECIAL_REQUEST_MAX_LENGTH = 500;
    public const EXTRAS_MAX = 20;

    /**
     * Tạo đơn đặt tour và giữ chỗ. Trả dòng kết quả của procedure: result (ok, duplicate, forbidden, invalid,
     * schedule_unavailable, group_limit, no_seats, tickets_changed, extras_changed, package_changed, price_changed,
     * retry), booking_code, total_vnd, remaining, max_group_size.
     *
     * @param array{name: string, email: string, phone: string} $contact
     * @param list<array{ticket_type_id: string, full_name: string}> $passengers Theo thứ tự trên form.
     * @param list<string> $extraIds Mã các khoản phụ thu / tùy chọn khách chọn (không trùng).
     * @param string|null $packageId Gói khách chọn; null khi tour không chia gói.
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
        array $extraIds = [],
        ?string $packageId = null
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
            $packageId,
        ]);

        return $rows[0] ?? ['result' => 'retry'];
    }

    /**
     * Thông số đặt tour đang áp dụng (bảng settings): số phút giữ chỗ, ngừng nhận đặt trước giờ khởi hành bao nhiêu
     * phút, còn dưới bao nhiêu giờ tới giờ khởi hành thì không nhận chuyển khoản VietQR.
     *
     * @return array{hold_minutes: int, booking_cutoff_minutes: int, vietqr_cutoff_hours: int}
     */
    public function rules(): array
    {
        $row = Database::call('NTK_sp_booking_rules')[0] ?? [];

        return [
            'hold_minutes' => (int) ($row['hold_minutes'] ?? 30),
            'booking_cutoff_minutes' => (int) ($row['booking_cutoff_minutes'] ?? 60),
            'vietqr_cutoff_hours' => (int) ($row['vietqr_cutoff_hours'] ?? 24),
        ];
    }
}
