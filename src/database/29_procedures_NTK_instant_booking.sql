-- =====================================================================
-- LocalTour v0.6 - 29_procedures_NTK_instant_booking.sql
-- Mục đích  : Procedure đọc cho luồng đặt ngay (không chờ quản trị viên xác nhận chỗ): trang đặt
--             tour và trang thanh toán hỏi các thông số vận hành đang áp dụng và hỏi đơn có
--             được chuyển khoản VietQR nữa không, để giao diện nói đúng với những gì
--             LTP_sp_booking_create (file 10) và NMT_sp_payment_start (file 14) sẽ làm.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Procedures: NTK_sp_booking_rules, NTK_sp_booking_payment_options
-- Quy tắc   : * Luồng đặt ngay: khách gửi đơn -> LTP_sp_booking_create giữ chỗ và tạo đơn
--               'awaiting_payment' (file 10) -> khách thanh toán trong hạn giữ chỗ (file 14, 15,
--               22) -> quá hạn chưa thanh toán thì LTP_sp_booking_expire_holds hủy đơn, trả chỗ.
--               Việc duyệt tay duy nhất còn lại là quản trị viên đối chiếu chuyển khoản VietQR.
--             * Thông số đọc từ bảng settings (file 28). Dòng thiếu hoặc giá trị không phải số
--               hợp lệ thì dùng mặc định, giống hệt cách đọc trong các procedure ghi dữ liệu.
--               Có hai lớp giới hạn: trang "Thông số vận hành" (NTK_sp_admin_setting_save, file
--               30) chỉ cho lưu trong khoảng hẹp; lúc đọc, procedure chấp nhận khoảng rộng hơn để
--               giá trị sửa tay trong database vẫn dùng được nếu là số hợp lệ:
--                 hold_minutes           (lưu 5 - 1440; đọc 1 - 99999; mặc định 30) : số phút giữ
--                                         chỗ.
--                 booking_cutoff_minutes (lưu 0 - 1440; đọc 0 - 99999; mặc định 60) : ngừng nhận
--                                         đặt trước giờ khởi hành bấy nhiêu phút.
--                 vietqr_cutoff_hours    (lưu 0 - 168; đọc 0 - 9999; mặc định 24) : còn dưới bấy
--                                         nhiêu giờ tới giờ khởi hành thì không nhận VietQR.
--             * Chỉ đọc dữ liệu (READS SQL DATA). Tham số chuỗi được so sánh với
--               COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01_schema.sql -> 28_migration_economy_NTK.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_booking_rules()
--   Thông số đặt tour đang áp dụng (trang đặt tour dùng để ghi điều kiện đặt tour).
--   1 dòng: hold_minutes, booking_cutoff_minutes, vietqr_cutoff_hours.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_booking_rules;

DELIMITER $$
CREATE PROCEDURE NTK_sp_booking_rules()
READS SQL DATA
BEGIN
    SELECT
        COALESCE((SELECT IF(st.value REGEXP '^[1-9][0-9]{0,4}$', CAST(st.value AS UNSIGNED), NULL)
                    FROM settings st WHERE st.name = 'hold_minutes'), 30)           AS hold_minutes,
        COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,5}$', CAST(st.value AS UNSIGNED), NULL)
                    FROM settings st WHERE st.name = 'booking_cutoff_minutes'), 60) AS booking_cutoff_minutes,
        COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,4}$', CAST(st.value AS UNSIGNED), NULL)
                    FROM settings st WHERE st.name = 'vietqr_cutoff_hours'), 24)    AS vietqr_cutoff_hours;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_booking_payment_options(p_user_id, p_code)
--   Phương thức thanh toán còn dùng được cho đơn p_code (chỉ đơn của tài khoản p_user_id).
--   0 hoặc 1 dòng: starts_at, hold_expires_at, vietqr_cutoff_hours,
--     vietqr_open (1 = còn nhận chuyển khoản VietQR; 0 = còn dưới vietqr_cutoff_hours giờ tới
--                  giờ khởi hành, NMT_sp_payment_start sẽ trả 'vietqr_closed').
--   VNPay và MoMo tự xác nhận nên không bị giới hạn ở đây (chỉ cần đơn còn hạn giữ chỗ).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_booking_payment_options;

DELIMITER $$
CREATE PROCEDURE NTK_sp_booking_payment_options(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    DECLARE v_qr_hours INT DEFAULT 24;
    SET v_qr_hours = COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,4}$', CAST(st.value AS UNSIGNED), NULL)
                                 FROM settings st WHERE st.name = 'vietqr_cutoff_hours'), 24);

    SELECT
        s.starts_at,
        b.hold_expires_at,
        v_qr_hours AS vietqr_cutoff_hours,
        (s.starts_at >= NOW() + INTERVAL v_qr_hours HOUR) AS vietqr_open
    FROM bookings b
    JOIN schedules s ON s.id = b.schedule_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;
