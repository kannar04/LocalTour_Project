-- =====================================================================
-- LocalTour v0.2 - 09_procedures_NMT_booking.sql
-- Mục đích  : Kiểm tra lịch khởi hành và số chỗ trước khi tạo yêu cầu đặt tour (M4 mục 5):
--             trang đặt tour gọi trước bước "Xem lại & xác nhận" để biết lịch còn nhận khách,
--             còn đủ chỗ và giá vé hiện tại có đổi không.
-- Phụ trách : Nguyễn Minh Thức (NMT) - M4 mục 5
-- Procedures: NMT_sp_schedule_availability, NMT_sp_schedule_ticket_list
-- Quy tắc   : Chỉ trả lịch của tour đang hiển thị: tours.approval_status = 'approved' VÀ
--             providers.approval_status = 'approved' VÀ users.status = 'active' (tài khoản
--             của nhà cung cấp). Lịch của tour khác hoặc không tồn tại -> 0 dòng.
--             Lịch đặt được (bookable): status = 'open', starts_at > NOW(), remaining > 0 và
--             có ít nhất một loại vé active (giống NMT_sp_tour_schedule_list, file 04).
--             Đây chỉ là kiểm tra trước; LTP_sp_booking_create (file 10) kiểm tra lại trong
--             transaction khi tạo đơn.
--             p_schedule_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_schedule_availability(p_schedule_id)
--   0 hoặc 1 dòng. Cột: schedule_id, tour_id, starts_at, ends_at, capacity, remaining,
--   status (open / full / cancelled / completed), max_group_size (của tour),
--   active_ticket_count (số loại vé đang bán),
--   bookable (1 = lịch còn nhận đặt, 0 = không: đã hủy, đã qua, hết chỗ hoặc không có vé).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_schedule_availability;

DELIMITER $$
CREATE PROCEDURE NMT_sp_schedule_availability(
    IN p_schedule_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id            AS schedule_id,
        s.tour_id,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        s.status,
        t.max_group_size,
        (SELECT COUNT(*)
           FROM ticket_types tt
          WHERE tt.schedule_id = s.id
            AND tt.active = TRUE) AS active_ticket_count,
        (s.status = 'open'
         AND s.starts_at > NOW()
         AND s.remaining > 0
         AND EXISTS (SELECT 1
                       FROM ticket_types tt
                      WHERE tt.schedule_id = s.id
                        AND tt.active = TRUE)) AS bookable
    FROM schedules s
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_schedule_ticket_list(p_schedule_id)
--   Các loại vé active của một lịch (tour đang hiển thị), giá hiện tại.
--   Cột: ticket_type_id, name ('adult', 'child', ...), min_age, max_age (NULL = không
--   giới hạn), price_vnd. Sắp xếp: vé đắt trước (người lớn trước trẻ em), rồi name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_schedule_ticket_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_schedule_ticket_list(
    IN p_schedule_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tt.id           AS ticket_type_id,
        tt.name,
        tt.min_age,
        tt.max_age,
        tt.price_vnd
    FROM ticket_types tt
    JOIN schedules s ON s.id = tt.schedule_id
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE tt.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
      AND tt.active = TRUE
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY tt.price_vnd DESC, tt.name, tt.id;
END$$
DELIMITER ;