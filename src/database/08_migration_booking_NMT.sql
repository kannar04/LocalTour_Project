-- =====================================================================
-- LocalTour v0.2 - 08_migration_booking_NMT.sql
-- Mục đích  : Bổ sung cấu trúc dữ liệu Booking cho luồng đặt tour MVP (M4) và dữ liệu
--             kiểm thử đặt tour. Không xóa bảng, không mất dữ liệu đang có.
--   1. bookings.request_token: mã của một lần mở form đặt tour (trang đặt tour sinh ra,
--      32 ký tự hex). Khách bấm "Gửi yêu cầu" hai lần hoặc mạng lỗi rồi gửi lại cùng mã
--      -> không tạo đơn thứ hai: UNIQUE (user_id, request_token). Đơn cũ để NULL.
--   2. booking_lines: mỗi loại vé chỉ một dòng trong một đơn: UNIQUE (booking_id, ticket_type_id).
--   3. passengers.sort_order: thứ tự khách trên form đặt tour (1, 2, ...), để danh sách khách
--      luôn hiện đúng thứ tự đã nhập. Khách của đơn cũ để 0 (sắp tiếp theo id).
--   4. Dữ liệu kiểm thử: lịch 40 của tour 6 (Hội An) chỉ còn 1 chỗ, để thử "không đủ chỗ"
--      (đặt 2 khách) và "đặt vừa đủ" (đặt 1 khách).
-- Quy tắc giữ chỗ (M4, theo User Flow đặt tour và BPMN đặt tour):
--   * Đơn mới = 'pending' (Chờ xác nhận): CHƯA trừ schedules.remaining, chỉ kiểm tra
--     remaining >= số khách lúc tạo đơn.
--   * Quản trị viên xác nhận chỗ (pending -> awaiting_payment): trừ remaining (giữ chỗ 24 giờ);
--     không đủ chỗ thì báo lỗi, không đổi gì. remaining về 0 -> lịch chuyển 'full'.
--   * Hủy đơn đang giữ chỗ (awaiting_payment / confirmed -> cancelled): cộng lại remaining
--     (không vượt capacity), lịch 'full' mở lại 'open'.
--   * Tự hủy khi quá hạn giữ chỗ 24 giờ thuộc M5 (thanh toán).
-- Phụ trách : Nguyễn Minh Thức (NMT) - M4 mục 3
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01_schema.sql, 02_seed.sql. Chạy lại được: cột / khóa đã có thì bỏ qua,
--             dữ liệu kiểm thử đã có thì không chèn lại.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1 + 2 + 3. Cột và khóa mới. ALTER TABLE chạy trong procedure tạm để bỏ qua lỗi
--        "đã có" (1060 cột trùng tên, 1061 khóa trùng tên) khi chạy lại file.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_migrate_booking_m4;

DELIMITER $$
CREATE PROCEDURE NMT_sp_migrate_booking_m4()
MODIFIES SQL DATA
BEGIN
    DECLARE v_skipped INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR 1060, 1061 SET v_skipped = v_skipped + 1;

    ALTER TABLE bookings
        ADD COLUMN request_token VARCHAR(64) NULL AFTER code;
    ALTER TABLE bookings
        ADD UNIQUE KEY uq_bookings_user_request (user_id, request_token);
    ALTER TABLE booking_lines
        ADD UNIQUE KEY uq_booking_lines_ticket (booking_id, ticket_type_id);
    ALTER TABLE passengers
        ADD COLUMN sort_order INT NOT NULL DEFAULT 0 AFTER special_request;
END$$
DELIMITER ;

CALL NMT_sp_migrate_booking_m4();
DROP PROCEDURE IF EXISTS NMT_sp_migrate_booking_m4;

-- ---------------------------------------------------------------------
-- 4. Dữ liệu kiểm thử đặt tour
--   Lịch 40: tour 6 (Hội An, 180 phút), 5 ngày nữa lúc 16:30, sức chứa 10, còn 1 chỗ.
--   Vé 401 người lớn 590.000đ, 402 trẻ em (4-11 tuổi) 410.000đ, cùng giá lịch 22-24.
--   Chỉ chèn khi tour 6 có trong database và lịch 40 chưa có.
-- ---------------------------------------------------------------------
INSERT INTO schedules (id, tour_id, starts_at, ends_at, capacity, remaining, status)
SELECT 'd0000000-0000-4000-8000-000000000040', t.id,
       TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '16:30:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '19:30:00'),
       10, 1, 'open'
  FROM tours t
 WHERE t.id = 'c0000000-0000-4000-8000-000000000006'
   AND NOT EXISTS (SELECT 1 FROM schedules s WHERE s.id = 'd0000000-0000-4000-8000-000000000040');

INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
SELECT v.id, s.id, v.name, v.min_age, v.max_age, v.price_vnd, TRUE
  FROM schedules s
  JOIN (SELECT 'e0000000-0000-4000-8000-000000000401' AS id, 'adult' AS name, 12 AS min_age, NULL AS max_age, 590000 AS price_vnd
        UNION ALL
        SELECT 'e0000000-0000-4000-8000-000000000402', 'child', 4, 11, 410000) v
 WHERE s.id = 'd0000000-0000-4000-8000-000000000040'
   AND NOT EXISTS (SELECT 1 FROM ticket_types tt WHERE tt.id = v.id);
