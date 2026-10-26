<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Quản lý yêu cầu đặt tour (FR-25) và lịch sử xử lý (NFR-09) của quản trị viên (Nguyễn Tuấn Khôi).
 * Procedure: NTK_sp_admin_booking_list, NTK_sp_admin_booking_detail, NTK_sp_admin_booking_line_list,
 * NTK_sp_admin_booking_passenger_list, NTK_sp_admin_booking_set_status, NTK_sp_admin_log_list.
 * Xác nhận chỗ (pending → awaiting_payment) giữ chỗ của lịch; hủy đơn đang giữ chỗ trả lại chỗ.
 */
final class AdminBookingModel
{
    /** Trạng thái mới quản trị viên được chọn, theo trạng thái hiện tại (giống bảng trong 07_procedures_NTK_admin.sql). */
    public const NEXT_STATUSES = [
        'pending' => ['awaiting_payment', 'rejected', 'cancelled'],
        'awaiting_payment' => ['confirmed', 'cancelled'],
        'confirmed' => ['completed', 'cancelled'],
    ];

    /** Trạng thái phải kèm lý do. */
    public const NOTE_REQUIRED = ['rejected', 'cancelled'];

    public const NOTE_MAX_LENGTH = 255;

    /**
     * Yêu cầu đặt tour theo trạng thái ('' = tất cả) và từ khóa (mã, tên, email, số điện thoại), mới nhất trước.
     *
     * @return list<array<string, mixed>>
     */
    public function list(string $status, string $keyword): array
    {
        return Database::call('NTK_sp_admin_booking_list', [
            $status === '' ? null : $status,
            $keyword === '' ? null : $keyword,
        ]);
    }

    /**
     * Một yêu cầu đặt tour; null nếu không có.
     *
     * @return array<string, mixed>|null
     */
    public function find(string $bookingId): ?array
    {
        return Database::call('NTK_sp_admin_booking_detail', [$bookingId])[0] ?? null;
    }

    /**
     * Các dòng vé của yêu cầu.
     *
     * @return list<array<string, mixed>>
     */
    public function lines(string $bookingId): array
    {
        return Database::call('NTK_sp_admin_booking_line_list', [$bookingId]);
    }

    /**
     * Danh sách khách của yêu cầu theo thứ tự nhập (full_name, age_group, special_request).
     *
     * @return list<array<string, mixed>>
     */
    public function passengers(string $bookingId): array
    {
        return Database::call('NTK_sp_admin_booking_passenger_list', [$bookingId]);
    }

    /**
     * Đổi trạng thái và ghi lịch sử. Trả về result của procedure: ok, forbidden, not_found,
     * invalid_transition, note_required, needs_payment, not_departed, no_seats, schedule_closed.
     */
    public function setStatus(string $bookingId, string $newStatus, string $actorUserId, string $note): string
    {
        $rows = Database::call('NTK_sp_admin_booking_set_status', [$bookingId, $newStatus, $actorUserId, $note === '' ? null : $note]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /**
     * Lịch sử xử lý của một tour ('tour') hoặc yêu cầu đặt tour ('booking'), cũ trước.
     *
     * @return list<array<string, mixed>>
     */
    public function history(string $targetType, string $targetId): array
    {
        return Database::call('NTK_sp_admin_log_list', [$targetType, $targetId]);
    }
}
