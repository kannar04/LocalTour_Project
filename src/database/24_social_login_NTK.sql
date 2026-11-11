-- =====================================================================
-- LocalTour v0.5 - 24_social_login_NTK.sql
-- Mục đích  : Đăng nhập bằng Google / Facebook cho tài khoản khách hàng (OAuth 2.0).
--   1. Bảng user_social_accounts: liên kết một tài khoản Google / Facebook (mã người dùng
--      do nhà cung cấp cấp) với một tài khoản LocalTour. Mỗi tài khoản Google / Facebook
--      chỉ gắn với một tài khoản LocalTour (UNIQUE provider + provider_user_id); một tài
--      khoản LocalTour có thể gắn cả Google lẫn Facebook. Xóa tài khoản thì xóa liên kết.
--   2. Procedure NTK_sp_social_login: tìm / liên kết / tạo tài khoản trong một transaction.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - Sprint 6
-- Procedures: NTK_sp_social_login
-- Quy tắc   : Ứng dụng đã đổi mã xác thực lấy thông tin tài khoản với Google / Facebook và
--             kiểm tra email (Google: email đã xác minh) trước khi gọi procedure.
--             Tài khoản tạo bằng Google / Facebook có password_hash NULL: chỉ đăng nhập lại
--             bằng Google / Facebook, không đăng nhập bằng mật khẩu được.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01_schema.sql. Chạy lại được (CREATE TABLE IF NOT EXISTS, DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. user_social_accounts
--   provider_user_id: mã người dùng của nhà cung cấp (Google "sub", Facebook "id").
--   email: email nhà cung cấp trả về ở lần đăng nhập gần nhất (chỉ để tra cứu).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_social_accounts (
    id               CHAR(36)      NOT NULL,
    user_id          CHAR(36)      NOT NULL,
    provider         ENUM('google','facebook') NOT NULL,
    provider_user_id VARCHAR(255)  NOT NULL,
    email            VARCHAR(150)  NULL,
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_social_accounts_provider_user (provider, provider_user_id),
    KEY idx_social_accounts_user (user_id),
    CONSTRAINT fk_social_accounts_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. NTK_sp_social_login(p_provider, p_provider_user_id, p_email, p_name)
--   p_provider: 'google' / 'facebook'. p_email: email đã kiểm tra định dạng. p_name: tên
--   hiển thị (NULL / '' = lấy phần trước @ của email).
--   Thứ tự xử lý (một transaction, khóa dòng FOR UPDATE):
--     a. Đã có liên kết (provider, provider_user_id) -> tài khoản đã liên kết.
--     b. Chưa có liên kết, đã có tài khoản cùng email -> liên kết vào tài khoản đó.
--     c. Chưa có tài khoản -> tạo tài khoản khách hàng (password_hash NULL) và liên kết.
--     Tài khoản ở a / b không phải 'customer' -> 'not_customer' (không liên kết, không
--     đăng nhập); đang bị khóa -> 'locked'.
--   1 dòng, cột: result, user_id, name, email, role.
--     result 'existing' / 'linked' / 'created': đăng nhập được, các cột còn lại là tài khoản.
--     result 'not_customer' / 'locked' / 'invalid' (thiếu dữ liệu) / 'retry' (hai lần đăng
--     nhập cùng lúc tạo trùng, thử lại): các cột còn lại NULL.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_social_login;

DELIMITER $$
CREATE PROCEDURE NTK_sp_social_login(
    IN p_provider         VARCHAR(20),
    IN p_provider_user_id VARCHAR(255),
    IN p_email            VARCHAR(150),
    IN p_name             VARCHAR(100) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_provider VARCHAR(20)  CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(COALESCE(p_provider, '')));
    DECLARE v_subject  VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_provider_user_id, ''));
    DECLARE v_email    VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(COALESCE(p_email, '')));
    DECLARE v_name     VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_name), '');
    DECLARE v_user_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_role     VARCHAR(20)  DEFAULT NULL;
    DECLARE v_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_result   VARCHAR(20)  DEFAULT NULL;
    -- 1062 = trùng khóa UNIQUE: lần đăng nhập khác vừa tạo cùng tài khoản / liên kết.
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SELECT 'retry' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
    END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF v_provider NOT IN ('google', 'facebook') OR v_subject = '' OR v_email = '' THEN
        SELECT 'invalid' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- a. Đã liên kết.
    SELECT u.id, u.role, u.status
      INTO v_user_id, v_role, v_status
      FROM user_social_accounts s
      JOIN users u ON u.id = s.user_id
     WHERE s.provider = (v_provider COLLATE utf8mb4_unicode_ci)
       AND s.provider_user_id = (v_subject COLLATE utf8mb4_unicode_ci)
     LIMIT 1
       FOR UPDATE;

    IF v_user_id IS NOT NULL THEN
        SET v_result = 'existing';
    ELSE
        -- b. Tài khoản cùng email.
        SELECT u.id, u.role, u.status
          INTO v_user_id, v_role, v_status
          FROM users u
         WHERE u.email = (v_email COLLATE utf8mb4_unicode_ci)
         LIMIT 1
           FOR UPDATE;

        IF v_user_id IS NOT NULL THEN
            SET v_result = 'linked';
        ELSE
            -- c. Tài khoản khách hàng mới, chưa có mật khẩu.
            SET v_user_id = UUID();
            SET v_role = 'customer';
            SET v_status = 'active';
            SET v_result = 'created';
            INSERT INTO users (id, email, password_hash, name, phone, role, status)
            VALUES (v_user_id, v_email, NULL, COALESCE(v_name, SUBSTRING_INDEX(v_email, '@', 1)),
                    NULL, 'customer', 'active');
        END IF;
    END IF;

    IF v_role <> 'customer' THEN
        ROLLBACK;
        SELECT 'not_customer' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
        LEAVE proc;
    END IF;

    IF v_status <> 'active' THEN
        ROLLBACK;
        SELECT 'locked' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
        LEAVE proc;
    END IF;

    IF v_result = 'existing' THEN
        UPDATE user_social_accounts
           SET email = v_email
         WHERE provider = (v_provider COLLATE utf8mb4_unicode_ci)
           AND provider_user_id = (v_subject COLLATE utf8mb4_unicode_ci);
    ELSE
        INSERT INTO user_social_accounts (id, user_id, provider, provider_user_id, email)
        VALUES (UUID(), v_user_id, v_provider, v_subject, v_email);
    END IF;

    COMMIT;

    SELECT v_result AS result, u.id AS user_id, u.name, u.email, u.role
      FROM users u
     WHERE u.id = v_user_id;
END$$
DELIMITER ;
