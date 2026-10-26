-- =====================================================================
-- LocalTour v0.2 - 11_procedures_NTK_booking.sql
-- Mục đích  : Trang "Đơn của tôi" của khách hàng (M4): danh sách đơn, chi tiết một đơn
--             (trạng thái, lý do từ chối / hủy), dòng vé và danh sách khách.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - M4 mục 7, 8
-- Procedures: NTK_sp_customer_booking_list, NTK_sp_customer_booking_detail,
--             NTK_sp_customer_booking_line_list, NTK_sp_customer_booking_passenger_list
-- Quy tắc   : Mọi procedure nhận p_user_id (lấy từ session) và chỉ trả đơn của chính tài
--             khoản đó: đơn của người khác hoặc mã không có -> 0 dòng (trang hiện "Không
--             tìm thấy đơn", không lộ đơn của người khác).
--             Đơn vẫn hiện khi tour đã bị ẩn sau lúc đặt; cột tour_public cho biết còn mở
--             được trang chi tiết tour hay không.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01_schema.sql, 08_migration_booking_NMT.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_list(p_user_id)
--   Tối đa 100 đơn, mới đặt trước. Cột: booking_id, code, status, created_at,
--   hold_expires_at, total_vnd, tour_id, tour_title, tour_public (1/0), destination_name,
--   starts_at, ends_at, people (tổng số vé), cover_url (ảnh bìa của tour, NULL = chưa có ảnh).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_list(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id              AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.hold_expires_at,
        b.total_vnd,
        t.id              AS tour_id,
        t.title           AS tour_title,
        (t.approval_status = 'approved' AND pr.approval_status = 'approved' AND pu.status = 'active') AS tour_public,
        COALESCE(d.name, t.destination) AS destination_name,
        s.starts_at,
        s.ends_at,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        (SELECT ti.url
           FROM tour_images ti
          WHERE ti.tour_id = t.id
          ORDER BY ti.sort_order, ti.id
          LIMIT 1)        AS cover_url
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    JOIN users pu     ON pu.id = pr.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
    ORDER BY b.created_at DESC, b.code
    LIMIT 100;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_detail(p_user_id, p_code)
--   0 hoặc 1 dòng: đơn có mã p_code của tài khoản p_user_id.
--   Cột: booking_id, code, status, created_at, hold_expires_at, total_vnd, policy_version,
--   contact_name, contact_email, contact_phone, tour_id, tour_title, tour_public,
--   destination_name, duration_minutes, language_codes, pickup_mode, meeting_point,
--   provider_name, starts_at, ends_at, people, cover_url,
--   policy_free_before_hours, policy_refund_percent (chính sách hủy đúng phiên bản lúc đặt;
--   NULL = tour chưa có chính sách),
--   payment_status (khoản thanh toán tiêu biểu, NULL = chưa có),
--   status_note, status_changed_at (ghi chú và thời điểm của lần quản trị viên chuyển đơn
--   sang trạng thái hiện tại; NULL khi đơn còn 'pending' hoặc không có ghi chú).
--   Trang chỉ hiện status_note cho đơn bị từ chối / bị hủy (lý do).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_detail;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_detail(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        b.id                AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.hold_expires_at,
        b.total_vnd,
        b.policy_version,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        t.id                AS tour_id,
        t.title             AS tour_title,
        (t.approval_status = 'approved' AND pr.approval_status = 'approved' AND pu.status = 'active') AS tour_public,
        COALESCE(d.name, t.destination) AS destination_name,
        t.duration_minutes,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        pr.business_name    AS provider_name,
        s.starts_at,
        s.ends_at,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        (SELECT ti.url
           FROM tour_images ti
          WHERE ti.tour_id = t.id
          ORDER BY ti.sort_order, ti.id
          LIMIT 1)          AS cover_url,
        cp.free_before_hours AS policy_free_before_hours,
        cp.refund_percent   AS policy_refund_percent,
        (SELECT p.status
           FROM payments p
          WHERE p.booking_id = b.id
          ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
          LIMIT 1)          AS payment_status,
        lg.note             AS status_note,
        lg.created_at       AS status_changed_at
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    JOIN users pu     ON pu.id = pr.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN cancellation_policies cp ON cp.tour_id = t.id AND cp.version = b.policy_version
    LEFT JOIN admin_logs lg ON lg.id = (
        SELECT l.id
          FROM admin_logs l
         WHERE l.target_type = 'booking'
           AND l.target_id = b.id
           AND l.to_status = b.status
         ORDER BY l.created_at DESC, l.id DESC
         LIMIT 1)
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_line_list(p_user_id, p_code)
--   Các dòng vé của đơn (chỉ đơn của tài khoản này).
--   Cột: ticket_name, quantity, unit_price_vnd, line_total_vnd. Vé đắt trước.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_line_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_line_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        tt.name           AS ticket_name,
        bl.quantity,
        bl.unit_price_vnd,
        bl.line_total_vnd
    FROM booking_lines bl
    JOIN bookings b      ON b.id = bl.booking_id
    JOIN ticket_types tt ON tt.id = bl.ticket_type_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY bl.unit_price_vnd DESC, tt.name, bl.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_passenger_list(p_user_id, p_code)
--   Danh sách khách của đơn (chỉ đơn của tài khoản này).
--   Cột: full_name, age_group (adult / child / infant), special_request (NULL = không có).
--   Thứ tự = thứ tự nhập trên form (passengers.sort_order, cột của file 08).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_passenger_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_passenger_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        p.full_name,
        p.age_group,
        p.special_request
    FROM passengers p
    JOIN bookings b ON b.id = p.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY p.sort_order, p.id;
END$$
DELIMITER ;
