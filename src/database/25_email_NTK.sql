-- =====================================================================
-- LocalTour - 25_email_NTK.sql
-- Mục đích  : Email "Đặt tour thành công" gửi cho khách khi đơn chuyển sang "Đã xác nhận"
--             (VNPay, đối chiếu VietQR, quản trị viên xác nhận, ...). Thêm:
--   1. Bảng email_logs: nhật ký mỗi lượt gửi email của đơn (người nhận, kết quả, lỗi).
--      Mỗi đơn có tối đa một email loại 'booking_confirmed' gửi thành công ('sent'):
--      Return URL và IPN của VNPay, hay quản trị viên bấm lại, không làm khách nhận hai email.
--   2. Procedure: NTK_sp_email_booking_get, NTK_sp_email_log_start,
--      NTK_sp_email_log_finish, NTK_sp_email_log_latest.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Quy tắc   : status của email_logs:
--               sending : đang gửi (giữ lượt trước khi kết nối SMTP, chống hai yêu cầu cùng
--                         gửi một lúc); quá 2 phút vẫn 'sending' = lượt bị ngắt, coi như lỗi.
--               sent    : máy chủ SMTP đã nhận email.
--               failed  : gửi lỗi (error ghi lỗi SMTP / mạng); lần xác nhận sau gửi lại được.
--               skipped : không gửi (chưa cấu hình MAIL_HOST, đơn không còn "Đã xác nhận"...).
--             Dữ liệu trong email đọc bằng procedure có sẵn của trang "Đơn của tôi"
--             (NTK_sp_customer_booking_detail, NTK_sp_customer_booking_line_list,
--             NMT_sp_payment_list); NTK_sp_email_booking_get chỉ tìm tài khoản của đơn.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01 -> 21. Chạy lại được: bảng đã có thì giữ nguyên dữ liệu, procedure tạo lại.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. email_logs
--   kind       : loại email, hiện có 'booking_confirmed' (Đặt tour thành công).
--   to_email   : địa chỉ nhận (bookings.contact_email lúc gửi).
--   error      : lỗi khi 'failed' / lý do khi 'skipped' (NULL khi 'sent').
--   message_id : Message-ID của email đã gửi.
--   finished_at: lúc có kết quả (NULL khi còn 'sending').
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS email_logs (
    id          CHAR(36)      NOT NULL,
    booking_id  CHAR(36)      NOT NULL,
    kind        VARCHAR(30)   NOT NULL,
    to_email    VARCHAR(150)  NOT NULL,
    status      ENUM('sending','sent','failed','skipped') NOT NULL DEFAULT 'sending',
    error       VARCHAR(1000) NULL,
    message_id  VARCHAR(200)  NULL,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME      NULL,
    PRIMARY KEY (id),
    KEY idx_email_logs_booking (booking_id, kind, status),
    KEY idx_email_logs_created (created_at),
    CONSTRAINT fk_email_logs_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Import lại 01_schema.sql tạo lại bảng bookings nhưng không xóa email_logs: bỏ nhật ký của
-- đơn không còn tồn tại.
DELETE FROM email_logs
 WHERE NOT EXISTS (SELECT 1 FROM bookings b WHERE b.id = email_logs.booking_id);

-- ---------------------------------------------------------------------
-- NTK_sp_email_booking_get(p_booking_id, p_code)
--   Tìm đơn cần gửi email theo booking_id (trang quản trị) hoặc theo mã đơn (VNPay, MoMo);
--   truyền một trong hai, giá trị còn lại NULL.
--   0 hoặc 1 dòng: booking_id, code, user_id, status, contact_name, contact_email.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_booking_get;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_booking_get(
    IN p_booking_id CHAR(36),
    IN p_code       VARCHAR(20)
)
READS SQL DATA
BEGIN
    IF NULLIF(TRIM(p_booking_id), '') IS NOT NULL THEN
        SELECT b.id AS booking_id, b.code, b.user_id, b.status, b.contact_name, b.contact_email
          FROM bookings b
         WHERE b.id = (TRIM(p_booking_id) COLLATE utf8mb4_unicode_ci);
    ELSE
        SELECT b.id AS booking_id, b.code, b.user_id, b.status, b.contact_name, b.contact_email
          FROM bookings b
         WHERE b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci);
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_log_start(p_booking_id, p_kind, p_to_email)
--   Giữ lượt gửi email loại p_kind của đơn trước khi kết nối SMTP. Khóa dòng của đơn nên hai
--   yêu cầu tới cùng lúc (vd. Return URL và IPN) chạy lần lượt.
--   1 dòng: result, email_log_id.
--     result = 'ok'        : đã thêm dòng 'sending' (email_log_id); ứng dụng gửi rồi gọi
--                            NTK_sp_email_log_finish.
--              'duplicate' : đơn đã có email loại này gửi thành công; không gửi lại.
--              'busy'      : đang có lượt gửi khác của đơn (dòng 'sending' chưa quá 2 phút).
--              'not_found' : không có đơn.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_log_start;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_log_start(
    IN p_booking_id CHAR(36),
    IN p_kind       VARCHAR(30),
    IN p_to_email   VARCHAR(150) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36) DEFAULT NULL;
    DECLARE v_log_id     CHAR(36) DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT b.id INTO v_booking_id
      FROM bookings b
     WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS email_log_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM email_logs l
                WHERE l.booking_id = v_booking_id
                  AND l.kind = (p_kind COLLATE utf8mb4_unicode_ci)
                  AND l.status = 'sent') THEN
        ROLLBACK;
        SELECT 'duplicate' AS result, NULL AS email_log_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM email_logs l
                WHERE l.booking_id = v_booking_id
                  AND l.kind = (p_kind COLLATE utf8mb4_unicode_ci)
                  AND l.status = 'sending'
                  AND l.created_at > NOW() - INTERVAL 2 MINUTE) THEN
        ROLLBACK;
        SELECT 'busy' AS result, NULL AS email_log_id;
        LEAVE proc;
    END IF;

    -- Lượt cũ quá 2 phút chưa có kết quả (tiến trình PHP bị ngắt): ghi lỗi rồi cho gửi lại.
    UPDATE email_logs
       SET status = 'failed', error = 'Lượt gửi bị ngắt giữa chừng (quá 2 phút chưa có kết quả).', finished_at = NOW()
     WHERE booking_id = v_booking_id
       AND kind = (p_kind COLLATE utf8mb4_unicode_ci)
       AND status = 'sending';

    INSERT INTO email_logs (id, booking_id, kind, to_email, status, created_at)
    VALUES (v_log_id, v_booking_id, p_kind, LEFT(COALESCE(p_to_email, ''), 150), 'sending', NOW());

    COMMIT;
    SELECT 'ok' AS result, v_log_id AS email_log_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_log_finish(p_email_log_id, p_status, p_error, p_message_id)
--   Ghi kết quả của lượt gửi do NTK_sp_email_log_start tạo (chỉ đổi dòng còn 'sending').
--   p_status = 'sent' | 'failed' | 'skipped'; p_error: lỗi / lý do (bỏ qua khi 'sent').
--   1 dòng: result = 'ok' | 'invalid' (p_status sai) | 'not_found' (không có dòng 'sending').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_log_finish;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_log_finish(
    IN p_email_log_id CHAR(36),
    IN p_status       VARCHAR(10),
    IN p_error        VARCHAR(1000) CHARACTER SET utf8mb4,
    IN p_message_id   VARCHAR(200)
)
MODIFIES SQL DATA
proc: BEGIN
    IF p_status IS NULL OR p_status NOT IN ('sent', 'failed', 'skipped') THEN
        SELECT 'invalid' AS result;
        LEAVE proc;
    END IF;

    UPDATE email_logs
       SET status = p_status,
           error = IF(p_status = 'sent', NULL, LEFT(NULLIF(TRIM(p_error), ''), 1000)),
           message_id = IF(p_status = 'sent', LEFT(NULLIF(TRIM(p_message_id), ''), 200), NULL),
           finished_at = NOW()
     WHERE id = (p_email_log_id COLLATE utf8mb4_unicode_ci)
       AND status = 'sending';

    SELECT IF(ROW_COUNT() > 0, 'ok', 'not_found') AS result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_log_latest(p_booking_id, p_kind)
--   Tình trạng email loại p_kind của đơn cho trang quản trị: lượt gửi thành công nếu có,
--   ngược lại lượt mới nhất.
--   0 hoặc 1 dòng: email_log_id, to_email, status, error, created_at, finished_at,
--   attempts (số lượt đã ghi của loại email này).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_log_latest;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_log_latest(
    IN p_booking_id CHAR(36),
    IN p_kind       VARCHAR(30)
)
READS SQL DATA
BEGIN
    SELECT
        l.id          AS email_log_id,
        l.to_email,
        l.status,
        l.error,
        l.created_at,
        l.finished_at,
        (SELECT COUNT(*)
           FROM email_logs x
          WHERE x.booking_id = l.booking_id
            AND x.kind = l.kind) AS attempts
    FROM email_logs l
    WHERE l.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
      AND l.kind = (p_kind COLLATE utf8mb4_unicode_ci)
    ORDER BY l.status = 'sent' DESC, l.created_at DESC, l.id DESC
    LIMIT 1;
END$$
DELIMITER ;
