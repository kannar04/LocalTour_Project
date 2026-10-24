-- =====================================================================
-- LocalTour v0.1 - 06_procedures_NTK_account.sql
-- Mục đích  : Stored procedures cho tài khoản khách hàng (đăng ký, đăng nhập).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - WBS 3.2.8
-- Procedures: NTK_sp_customer_register, NTK_sp_user_find_by_email
-- Quy tắc   : Mật khẩu được băm bằng password_hash() của PHP trước khi gọi procedure;
--             database chỉ lưu chuỗi băm, không bao giờ nhận mật khẩu gốc.
--             Email lưu chữ thường, so sánh với COLLATE utf8mb4_unicode_ci.
--             Không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_customer_register(p_name, p_email, p_phone, p_password_hash)
--   Tạo tài khoản role = 'customer', status = 'active' với id UUID mới.
--   p_phone NULL / '' = không có số điện thoại.
--   1 dòng, cột user_id: id của tài khoản mới; NULL khi email đã được dùng
--   (khóa uq_users_email, kể cả email của tài khoản nhân viên / nhà cung cấp).
--   Kiểm tra định dạng dữ liệu (độ dài, email, mật khẩu) do ứng dụng làm trước khi gọi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_register;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_register(
    IN p_name          VARCHAR(100),
    IN p_email         VARCHAR(150),
    IN p_phone         VARCHAR(20),
    IN p_password_hash VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_user_id   CHAR(36) DEFAULT NULL;
    DECLARE v_duplicate BOOLEAN  DEFAULT FALSE;
    -- 1062 = trùng khóa UNIQUE (email đã có)
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    SET v_user_id = UUID();

    INSERT INTO users (id, email, password_hash, name, phone, role, status)
    VALUES (v_user_id,
            LOWER(TRIM(p_email)),
            p_password_hash,
            TRIM(p_name),
            NULLIF(TRIM(p_phone), ''),
            'customer',
            'active');

    IF v_duplicate THEN
        SET v_user_id = NULL;
    END IF;

    SELECT v_user_id AS user_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_user_find_by_email(p_email)
--   0 hoặc 1 dòng: tài khoản có email này (không phân biệt hoa thường).
--   Cột: user_id, name, email, password_hash (NULL = chưa đặt mật khẩu), role, status.
--   Ứng dụng tự kiểm tra role = 'customer', status = 'active' và mật khẩu
--   (password_verify) trước khi cho đăng nhập.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_user_find_by_email;

DELIMITER $$
CREATE PROCEDURE NTK_sp_user_find_by_email(
    IN p_email VARCHAR(150)
)
READS SQL DATA
BEGIN
    SELECT
        u.id            AS user_id,
        u.name,
        u.email,
        u.password_hash,
        u.role,
        u.status
    FROM users u
    WHERE u.email = (LOWER(TRIM(p_email)) COLLATE utf8mb4_unicode_ci)
    LIMIT 1;
END$$
DELIMITER ;
