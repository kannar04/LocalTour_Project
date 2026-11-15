-- =====================================================================
-- LocalTour v0.7 - 37_procedures_LTP_account.sql
-- Mục đích  : Trang "Tài khoản" của khách hàng (CR3): xem và sửa họ tên, số điện thoại, số CCCD,
--             ngày sinh, giới tính, địa chỉ (cột mới ở 39_migration_profile_LTP.sql), ảnh đại diện
--             (users.avatar_url, cột mới ở 33_migration_cr3_NTK.sql) và đổi / đặt mật khẩu.
-- Phụ trách : Lê Trung Phong (LTP) - CR3
-- Procedures: LTP_sp_account_get, LTP_sp_account_update_profile, LTP_sp_account_set_avatar,
--             LTP_sp_account_get_password_hash, LTP_sp_account_set_password
-- Quy tắc   : * Chỉ tài khoản khách hàng (role 'customer') đang hoạt động ('active') được đọc /
--               sửa ở đây; tài khoản khác hoặc đã khóa: result = 'not_found'.
--             * Email không đổi được (dùng để đăng nhập).
--             * Kiểm tra định dạng (độ dài họ tên, số điện thoại, CCCD, ngày sinh, giới tính, độ dài
--               địa chỉ, loại / dung lượng ảnh, độ dài mật khẩu) do ứng dụng làm trước khi gọi;
--               LTP_sp_account_update_profile kiểm tra lại CCCD / ngày sinh / giới tính ('invalid').
--               Mật khẩu được băm bằng password_hash() của PHP; database chỉ nhận chuỗi băm.
--             * Số CCCD là thông tin nhạy cảm: chỉ LTP_sp_account_get (chủ tài khoản) trả về.
--             * avatar_url = đường dẫn tương đối từ public/assets/ (vd. 'uploads/avatars/<32 ký tự
--               hex>.jpg'); NULL = chưa có ảnh. File ảnh do ứng dụng lưu / xóa.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 33 (cần cột users.avatar_url); trang chỉ dùng được sau khi đã chạy file 39
--             (cột thông tin cá nhân; procedure tạo trước file 39 vẫn được). Chạy lại được
--             (DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- LTP_sp_account_get(p_user_id)
--   0 hoặc 1 dòng: tài khoản khách hàng đang hoạt động.
--   Cột: user_id, email, name, phone (NULL = chưa có), citizen_id, date_of_birth, gender ('male' /
--        'female' / 'other'), address (NULL = chưa cập nhật), role, avatar_url (NULL = chưa có
--        ảnh), has_password (1 = đã đặt mật khẩu, 0 = chưa có mật khẩu).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_account_get;

DELIMITER $$
CREATE PROCEDURE LTP_sp_account_get(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        u.id         AS user_id,
        u.email,
        u.name,
        u.phone,
        u.citizen_id,
        u.date_of_birth,
        u.gender,
        u.address,
        u.role,
        u.avatar_url,
        (u.password_hash IS NOT NULL AND u.password_hash <> '') AS has_password
    FROM users u
    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'customer'
      AND u.status = 'active'
    LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_account_update_profile(p_user_id, p_name, p_phone, p_citizen_id, p_date_of_birth,
--                               p_gender, p_address)
--   Sửa thông tin cá nhân. Các tham số không bắt buộc nhận NULL / '' = xóa giá trị:
--     p_phone, p_citizen_id (đúng 12 chữ số), p_date_of_birth (DATE, 1900-01-01 → hôm nay),
--     p_gender ('male' / 'female' / 'other'), p_address (tối đa 255 ký tự).
--   1 dòng: result ('ok' / 'not_found' / 'invalid' khi CCCD, ngày sinh hoặc giới tính sai dạng),
--   name (họ tên đã lưu, để cập nhật session).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_account_update_profile;

DELIMITER $$
CREATE PROCEDURE LTP_sp_account_update_profile(
    IN p_user_id       CHAR(36),
    IN p_name          VARCHAR(100) CHARACTER SET utf8mb4,
    IN p_phone         VARCHAR(20)  CHARACTER SET utf8mb4,
    IN p_citizen_id    VARCHAR(12),
    IN p_date_of_birth DATE,
    IN p_gender        VARCHAR(10),
    IN p_address       VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_citizen_id VARCHAR(12) DEFAULT NULL;
    DECLARE v_gender     VARCHAR(10) DEFAULT NULL;

    SET v_citizen_id = NULLIF(TRIM(p_citizen_id), '');
    SET v_gender = NULLIF(TRIM(p_gender), '');

    IF (v_citizen_id IS NOT NULL AND v_citizen_id NOT REGEXP '^[0-9]{12}$')
       OR (v_gender IS NOT NULL AND v_gender NOT IN ('male', 'female', 'other'))
       OR (p_date_of_birth IS NOT NULL AND (p_date_of_birth < '1900-01-01' OR p_date_of_birth > CURDATE())) THEN
        SELECT 'invalid' AS result, NULL AS name;
    ELSEIF NOT EXISTS (SELECT 1 FROM users
                        WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                          AND role = 'customer' AND status = 'active') THEN
        SELECT 'not_found' AS result, NULL AS name;
    ELSE
        UPDATE users
           SET name          = TRIM(p_name),
               phone         = NULLIF(TRIM(p_phone), ''),
               citizen_id    = v_citizen_id,
               date_of_birth = p_date_of_birth,
               gender        = v_gender,
               address       = NULLIF(TRIM(p_address), '')
         WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci);

        SELECT 'ok' AS result, TRIM(p_name) AS name;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_account_set_avatar(p_user_id, p_avatar_url)
--   Đặt ảnh đại diện mới; p_avatar_url NULL = xóa ảnh.
--   1 dòng: result ('ok' / 'not_found'), old_avatar_url (ảnh trước đó, NULL = chưa có) để ứng
--   dụng xóa file cũ. Khóa dòng tài khoản (FOR UPDATE) khi đọc ảnh cũ: hai lần tải lên cùng lúc
--   không làm mất dấu file nào.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_account_set_avatar;

DELIMITER $$
CREATE PROCEDURE LTP_sp_account_set_avatar(
    IN p_user_id    CHAR(36),
    IN p_avatar_url VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_found BOOLEAN      DEFAULT FALSE;
    DECLARE v_old   VARCHAR(255) DEFAULT NULL;

    -- Không có dòng nào (sai id, không phải khách hàng, đã khóa): v_found giữ FALSE.
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT TRUE, u.avatar_url
      INTO v_found, v_old
      FROM users u
     WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND u.role = 'customer'
       AND u.status = 'active'
     LIMIT 1
       FOR UPDATE;

    IF NOT v_found THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS old_avatar_url;
    ELSE
        UPDATE users
           SET avatar_url = NULLIF(TRIM(p_avatar_url), '')
         WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci);
        COMMIT;

        SELECT 'ok' AS result, v_old AS old_avatar_url;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_account_get_password_hash(p_user_id)
--   0 hoặc 1 dòng: cột password_hash (NULL = chưa đặt mật khẩu) của tài khoản khách hàng đang
--   hoạt động. Chỉ dùng để kiểm tra mật khẩu hiện tại trước khi đổi (password_verify trong PHP).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_account_get_password_hash;

DELIMITER $$
CREATE PROCEDURE LTP_sp_account_get_password_hash(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT u.password_hash
      FROM users u
     WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND u.role = 'customer'
       AND u.status = 'active'
     LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_account_set_password(p_user_id, p_password_hash)
--   Lưu mật khẩu mới (đã băm). 1 dòng: result ('ok' / 'not_found' / 'invalid' khi chuỗi băm rỗng).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_account_set_password;

DELIMITER $$
CREATE PROCEDURE LTP_sp_account_set_password(
    IN p_user_id       CHAR(36),
    IN p_password_hash VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    IF p_password_hash IS NULL OR TRIM(p_password_hash) = '' THEN
        SELECT 'invalid' AS result;
    ELSEIF NOT EXISTS (SELECT 1 FROM users
                        WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                          AND role = 'customer' AND status = 'active') THEN
        SELECT 'not_found' AS result;
    ELSE
        UPDATE users
           SET password_hash = p_password_hash
         WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci);

        SELECT 'ok' AS result;
    END IF;
END$$
DELIMITER ;
