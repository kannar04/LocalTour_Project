<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Nhật ký email gửi cho khách (email "Đặt tour thành công" – Nguyễn Tuấn Khôi): tìm đơn cần gửi, giữ lượt gửi (chống
 * gửi trùng), ghi kết quả và đọc tình trạng cho trang quản trị.
 * Procedure (25_email_NTK.sql): NTK_sp_email_booking_get, NTK_sp_email_log_start, NTK_sp_email_log_finish,
 * NTK_sp_email_log_latest.
 */
final class EmailLogModel
{
    /**
     * Đơn theo booking_id hoặc mã đơn (truyền một trong hai): booking_id, code, user_id, status, contact_name,
     * contact_email; null nếu không có.
     *
     * @return array<string, mixed>|null
     */
    public function booking(?string $bookingId, ?string $code): ?array
    {
        return Database::call('NTK_sp_email_booking_get', [$bookingId, $code])[0] ?? null;
    }

    /**
     * Giữ lượt gửi email loại $kind của đơn. Trả result (ok, duplicate, busy, not_found) và email_log_id (khi ok).
     *
     * @return array{result: string, email_log_id: ?string}
     */
    public function start(string $bookingId, string $kind, string $toEmail): array
    {
        $row = Database::call('NTK_sp_email_log_start', [$bookingId, $kind, $toEmail])[0] ?? [];

        return [
            'result' => (string) ($row['result'] ?? 'not_found'),
            'email_log_id' => isset($row['email_log_id']) ? (string) $row['email_log_id'] : null,
        ];
    }

    /** Kết quả của lượt gửi: $status = sent, failed hoặc skipped. Trả result (ok, invalid, not_found). */
    public function finish(string $emailLogId, string $status, ?string $error, ?string $messageId): string
    {
        $rows = Database::call('NTK_sp_email_log_finish', [$emailLogId, $status, $error, $messageId]);

        return (string) ($rows[0]['result'] ?? 'not_found');
    }

    /**
     * Lượt gửi thành công của đơn nếu có, ngược lại lượt mới nhất; null khi chưa gửi lần nào.
     * Cột: email_log_id, to_email, status, error, created_at, finished_at, attempts.
     *
     * @return array<string, mixed>|null
     */
    public function latest(string $bookingId, string $kind): ?array
    {
        return Database::call('NTK_sp_email_log_latest', [$bookingId, $kind])[0] ?? null;
    }
}
