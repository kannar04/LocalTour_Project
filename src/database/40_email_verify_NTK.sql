-- =====================================================================
-- LocalTour - 40_email_verify_NTK.sql
-- Mục đích  : Xác minh email của tài khoản khách hàng bằng mã 6 chữ số gửi qua email, và đổi
--             email đăng nhập (mã gửi tới email mới). Chức năng thêm, chỉ chạy khi đã cấu hình gửi
--             email (MAIL_HOST trong .env, như email "Đặt tour thành công" của 25_email_NTK.sql);
--             MAIL_HOST trống thì trang "Tài khoản" giữ nguyên ô email chỉ đọc, không có gì của
--             chức năng này. Thêm:
--   1. Cột users.email_verified_at: lúc email hiện tại được xác minh (NULL = chưa xác minh).
--   2. Bảng email_verifications: mỗi mã đã gửi một dòng; chỉ lưu chuỗi băm của mã.
--   3. Procedure: NTK_sp_email_verify_state, NTK_sp_email_verify_issue,
--      NTK_sp_email_verify_attempt, NTK_sp_email_verify_confirm, NTK_sp_email_verify_cancel
--      (và NTK_sp_email_verify_wait dùng bên trong).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Quy tắc   : purpose của email_verifications:
--               verify : xác minh email hiện tại (mã gửi tới email đang dùng).
--               change : đổi sang email mới (mã gửi tới email mới; đúng mã thì đổi email và coi
--                        như đã xác minh).
--             * Chỉ tài khoản khách hàng đang hoạt động.
--             * Mã hết hạn sau 15 phút; mỗi mã nhập tối đa 5 lần (lần thứ 5 sai thì mã bỏ); mã mới
--               thay mã cũ cùng mục đích; đổi email xong thì mọi mã đang chờ khác bỏ.
--             * Gửi mã: cách mã trước ít nhất 60 giây, tối đa 5 mã mỗi tài khoản trong 1 giờ (tính
--               cả hai mục đích, cả mã gửi lỗi).
--             * code_hash = password_hash() của PHP; ứng dụng so mã bằng password_verify() (so sánh
--               thời gian cố định). Database không bao giờ nhận mã gốc.
--             * Email lưu chữ thường; email đã thuộc tài khoản khác thì không đổi sang được.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MariaDB 11.
-- Chạy sau  : 01 -> 39. Chạy lại được: cột / bảng đã có thì giữ nguyên dữ liệu, procedure tạo lại.
-- =====================================================================

SET NAMES utf8mb4;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS email_verified_at DATETIME NULL;

-- ---------------------------------------------------------------------
-- 1. email_verifications
--   email     : địa chỉ nhận mã (verify: email hiện tại lúc gửi; change: email mới).
--   attempts  : số lần đã nhập mã (tối đa 5).
--   expires_at: hết hạn (15 phút sau khi gửi; mã bị thay / hủy thì đặt về lúc thay / hủy).
--   used_at   : lúc nhập đúng mã (NULL = chưa dùng).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS email_verifications (
    id         CHAR(36)         NOT NULL,
    user_id    CHAR(36)         NOT NULL,
    purpose    ENUM('verify','change') NOT NULL,
    email      VARCHAR(150)     NOT NULL,
    code_hash  VARCHAR(255)     NOT NULL,
    attempts   TINYINT UNSIGNED NOT NULL DEFAULT 0,
    expires_at DATETIME         NOT NULL,
    used_at    DATETIME         NULL,
    created_at DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_email_verifications_user_purpose (user_id, purpose, created_at),
    KEY idx_email_verifications_user_created (user_id, created_at),
    CONSTRAINT fk_email_verifications_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- NTK_sp_email_verify_wait(p_user_id, OUT p_cooldown, OUT p_limit)
--   Dùng bên trong (không gọi từ PHP). Số giây phải chờ trước khi gửi mã mới:
--   p_cooldown: còn trong 60 giây kể từ mã gần nhất; p_limit: đã có 5 mã trong 1 giờ (chờ tới
--   khi mã thứ 5 gần nhất ra khỏi khung 1 giờ). 0 = gửi được.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_verify_wait;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_verify_wait(
    IN  p_user_id  CHAR(36),
    OUT p_cooldown INT,
    OUT p_limit    INT
)
READS SQL DATA
BEGIN
    DECLARE v_last  DATETIME DEFAULT NULL;
    DECLARE v_fifth DATETIME DEFAULT NULL;

    SET v_last = (SELECT MAX(v.created_at)
                    FROM email_verifications v
                   WHERE v.user_id = (p_user_id COLLATE utf8mb4_unicode_ci));
    SET v_fifth = (SELECT v.created_at
                     FROM email_verifications v
                    WHERE v.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND v.created_at > NOW() - INTERVAL 1 HOUR
                    ORDER BY v.created_at DESC
                    LIMIT 1 OFFSET 4);

    SET p_cooldown = IF(v_last IS NULL, 0, GREATEST(0, 60 - TIMESTAMPDIFF(SECOND, v_last, NOW())));
    SET p_limit = IF(v_fifth IS NULL, 0, GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), v_fifth + INTERVAL 1 HOUR)));
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_verify_state(p_user_id)
--   Tình trạng cho trang "Tài khoản". 0 hoặc 1 dòng (tài khoản khách hàng đang hoạt động):
--   email, email_verified_at (NULL = chưa xác minh),
--   verify_expires_at (mã xác minh email hiện tại đang chờ nhập, NULL = không có),
--   change_email, change_expires_at (mã đổi email đang chờ nhập: email mới và hạn; NULL = không có),
--   wait_seconds (số giây phải chờ trước khi gửi mã mới; 0 = gửi được).
--   Mã "đang chờ" = mã mới nhất của mục đích đó, chưa dùng, chưa hết hạn, chưa nhập đủ 5 lần.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_verify_state;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_verify_state(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    DECLARE v_cooldown  INT      DEFAULT 0;
    DECLARE v_limit     INT      DEFAULT 0;
    DECLARE v_verify_id CHAR(36) DEFAULT NULL;
    DECLARE v_change_id CHAR(36) DEFAULT NULL;

    CALL NTK_sp_email_verify_wait(p_user_id, v_cooldown, v_limit);

    SET v_verify_id = (SELECT v.id FROM email_verifications v
                        WHERE v.user_id = (p_user_id COLLATE utf8mb4_unicode_ci) AND v.purpose = 'verify'
                        ORDER BY v.created_at DESC, v.id DESC LIMIT 1);
    SET v_change_id = (SELECT v.id FROM email_verifications v
                        WHERE v.user_id = (p_user_id COLLATE utf8mb4_unicode_ci) AND v.purpose = 'change'
                        ORDER BY v.created_at DESC, v.id DESC LIMIT 1);

    SELECT
        u.email,
        u.email_verified_at,
        IF(vv.id IS NOT NULL AND vv.used_at IS NULL AND vv.attempts < 5 AND vv.expires_at > NOW()
           AND vv.email = u.email, vv.expires_at, NULL) AS verify_expires_at,
        IF(vc.id IS NOT NULL AND vc.used_at IS NULL AND vc.attempts < 5 AND vc.expires_at > NOW(),
           vc.email, NULL) AS change_email,
        IF(vc.id IS NOT NULL AND vc.used_at IS NULL AND vc.attempts < 5 AND vc.expires_at > NOW(),
           vc.expires_at, NULL) AS change_expires_at,
        GREATEST(v_cooldown, v_limit) AS wait_seconds
    FROM users u
    LEFT JOIN email_verifications vv ON vv.id = v_verify_id
    LEFT JOIN email_verifications vc ON vc.id = v_change_id
    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'customer'
      AND u.status = 'active'
    LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_verify_issue(p_user_id, p_purpose, p_email, p_code_hash)
--   Ghi mã mới trước khi gửi email. p_purpose 'verify' (p_email bỏ qua, mã gửi tới email hiện
--   tại) hoặc 'change' (p_email = email mới, ứng dụng đã kiểm tra định dạng). p_code_hash =
--   password_hash() của mã. Khóa dòng tài khoản nên hai yêu cầu cùng lúc chạy lần lượt.
--   1 dòng: result, verification_id, email (địa chỉ nhận mã), name (họ tên để chào trong email),
--   wait_seconds, expires_at.
--     result = 'ok'        : đã ghi mã (verification_id, hết hạn expires_at); mã cũ cùng mục
--                            đích không còn dùng được. Ứng dụng gửi email; gửi lỗi thì gọi
--                            NTK_sp_email_verify_cancel.
--              'already'   : verify khi email đã được xác minh.
--              'same'      : change sang đúng email đang dùng.
--              'taken'     : change sang email của tài khoản khác.
--              'cooldown'  : chưa đủ 60 giây từ mã trước (wait_seconds = số giây còn lại).
--              'limit'     : đã gửi 5 mã trong 1 giờ (wait_seconds = số giây còn lại).
--              'not_found' : không phải tài khoản khách hàng đang hoạt động.
--              'invalid'   : p_purpose sai, thiếu chuỗi băm hoặc thiếu email mới.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_verify_issue;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_verify_issue(
    IN p_user_id   CHAR(36),
    IN p_purpose   VARCHAR(10),
    IN p_email     VARCHAR(150) CHARACTER SET utf8mb4,
    IN p_code_hash VARCHAR(255)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_user_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_current  VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_name     VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_verified DATETIME     DEFAULT NULL;
    DECLARE v_email    VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_cooldown INT          DEFAULT 0;
    DECLARE v_limit    INT          DEFAULT 0;
    DECLARE v_id       CHAR(36)     DEFAULT UUID();
    DECLARE v_expires  DATETIME     DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_purpose IS NULL OR p_purpose NOT IN ('verify', 'change')
       OR NULLIF(TRIM(p_code_hash), '') IS NULL
       OR (p_purpose = 'change' AND NULLIF(TRIM(p_email), '') IS NULL) THEN
        SELECT 'invalid' AS result, NULL AS verification_id, NULL AS email, NULL AS name,
               0 AS wait_seconds, NULL AS expires_at;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT u.id, u.email, u.name, u.email_verified_at
      INTO v_user_id, v_current, v_name, v_verified
      FROM users u
     WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND u.role = 'customer'
       AND u.status = 'active'
     LIMIT 1
       FOR UPDATE;

    IF v_user_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS verification_id, NULL AS email, NULL AS name,
               0 AS wait_seconds, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF p_purpose = 'verify' THEN
        IF v_verified IS NOT NULL THEN
            ROLLBACK;
            SELECT 'already' AS result, NULL AS verification_id, v_current AS email, v_name AS name,
                   0 AS wait_seconds, NULL AS expires_at;
            LEAVE proc;
        END IF;
        SET v_email = v_current;
    ELSE
        SET v_email = LOWER(TRIM(p_email));
        IF v_email = v_current THEN
            ROLLBACK;
            SELECT 'same' AS result, NULL AS verification_id, v_email AS email, v_name AS name,
                   0 AS wait_seconds, NULL AS expires_at;
            LEAVE proc;
        END IF;
        IF EXISTS (SELECT 1 FROM users x
                    WHERE x.email = (v_email COLLATE utf8mb4_unicode_ci)
                      AND x.id <> v_user_id) THEN
            ROLLBACK;
            SELECT 'taken' AS result, NULL AS verification_id, v_email AS email, v_name AS name,
                   0 AS wait_seconds, NULL AS expires_at;
            LEAVE proc;
        END IF;
    END IF;

    CALL NTK_sp_email_verify_wait(v_user_id, v_cooldown, v_limit);
    IF v_limit > 0 THEN
        ROLLBACK;
        SELECT 'limit' AS result, NULL AS verification_id, v_email AS email, v_name AS name,
               v_limit AS wait_seconds, NULL AS expires_at;
        LEAVE proc;
    END IF;
    IF v_cooldown > 0 THEN
        ROLLBACK;
        SELECT 'cooldown' AS result, NULL AS verification_id, v_email AS email, v_name AS name,
               v_cooldown AS wait_seconds, NULL AS expires_at;
        LEAVE proc;
    END IF;

    -- Mã mới thay mã cũ cùng mục đích.
    UPDATE email_verifications
       SET expires_at = NOW()
     WHERE user_id = v_user_id
       AND purpose = (p_purpose COLLATE utf8mb4_unicode_ci)
       AND used_at IS NULL
       AND expires_at > NOW();

    -- Dọn mã cũ hơn 1 ngày của tài khoản này (không còn dùng cho giới hạn 1 giờ).
    DELETE FROM email_verifications
     WHERE user_id = v_user_id
       AND created_at < NOW() - INTERVAL 1 DAY;

    SET v_expires = NOW() + INTERVAL 15 MINUTE;
    INSERT INTO email_verifications (id, user_id, purpose, email, code_hash, attempts, expires_at, used_at, created_at)
    VALUES (v_id, v_user_id, p_purpose, v_email, p_code_hash, 0, v_expires, NULL, NOW());

    COMMIT;
    SELECT 'ok' AS result, v_id AS verification_id, v_email AS email, v_name AS name,
           0 AS wait_seconds, v_expires AS expires_at;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_verify_attempt(p_user_id, p_purpose)
--   Giữ một lượt nhập cho mã đang chờ (mới nhất) của mục đích p_purpose, TRƯỚC khi ứng dụng so
--   mã: tăng attempts ngay, nên dù gửi nhiều yêu cầu cùng lúc mỗi mã cũng chỉ được so tối đa 5 lần.
--   1 dòng: result, verification_id, code_hash, email, attempts_left (số lần còn lại sau lượt này).
--     result = 'ok'        : ứng dụng so mã với code_hash (password_verify); đúng thì gọi
--                            NTK_sp_email_verify_confirm(verification_id, ...).
--              'none'      : không có mã đang chờ (chưa gửi, đã dùng, hoặc mã xác minh của email
--                            cũ trước khi đổi email).
--              'locked'    : mã đã nhập sai 5 lần.
--              'expired'   : mã đã hết hạn (hoặc gửi email lỗi).
--              'not_found' : không phải tài khoản khách hàng đang hoạt động.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_verify_attempt;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_verify_attempt(
    IN p_user_id CHAR(36),
    IN p_purpose VARCHAR(10)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_user_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_current  VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_id       CHAR(36)     DEFAULT NULL;
    DECLARE v_email    VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_hash     VARCHAR(255) DEFAULT NULL;
    DECLARE v_attempts INT          DEFAULT 0;
    DECLARE v_expires  DATETIME     DEFAULT NULL;
    DECLARE v_used     DATETIME     DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT u.id, u.email INTO v_user_id, v_current
      FROM users u
     WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND u.role = 'customer'
       AND u.status = 'active'
     LIMIT 1
       FOR UPDATE;

    IF v_user_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS verification_id, NULL AS code_hash, NULL AS email, 0 AS attempts_left;
        LEAVE proc;
    END IF;

    SELECT v.id, v.email, v.code_hash, v.attempts, v.expires_at, v.used_at
      INTO v_id, v_email, v_hash, v_attempts, v_expires, v_used
      FROM email_verifications v
     WHERE v.user_id = v_user_id
       AND v.purpose = (p_purpose COLLATE utf8mb4_unicode_ci)
     ORDER BY v.created_at DESC, v.id DESC
     LIMIT 1
       FOR UPDATE;

    IF v_id IS NULL OR v_used IS NOT NULL OR (p_purpose = 'verify' AND v_email <> v_current) THEN
        ROLLBACK;
        SELECT 'none' AS result, NULL AS verification_id, NULL AS code_hash, NULL AS email, 0 AS attempts_left;
        LEAVE proc;
    END IF;
    IF v_attempts >= 5 THEN
        ROLLBACK;
        SELECT 'locked' AS result, NULL AS verification_id, NULL AS code_hash, v_email AS email, 0 AS attempts_left;
        LEAVE proc;
    END IF;
    IF v_expires <= NOW() THEN
        ROLLBACK;
        SELECT 'expired' AS result, NULL AS verification_id, NULL AS code_hash, v_email AS email, 0 AS attempts_left;
        LEAVE proc;
    END IF;

    UPDATE email_verifications SET attempts = attempts + 1 WHERE id = v_id;

    COMMIT;
    SELECT 'ok' AS result, v_id AS verification_id, v_hash AS code_hash, v_email AS email,
           5 - (v_attempts + 1) AS attempts_left;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_verify_confirm(p_verification_id, p_user_id)
--   Gọi sau khi ứng dụng đã so đúng mã. Đánh dấu mã đã dùng và:
--     verify : users.email_verified_at = NOW() (nếu email chưa đổi từ lúc gửi mã);
--     change : users.email = email mới, email_verified_at = NOW(); các mã đang chờ khác bỏ.
--   1 dòng: result, purpose, email (email đăng nhập sau khi xử lý).
--     result = 'ok'
--              'taken'     : (change) email mới vừa thuộc về tài khoản khác; mã bỏ.
--              'not_found' : mã không còn dùng được (đã dùng, hết hạn, email đã đổi) hoặc không
--                            phải tài khoản khách hàng đang hoạt động.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_verify_confirm;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_verify_confirm(
    IN p_verification_id CHAR(36),
    IN p_user_id         CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_user_id   CHAR(36)     DEFAULT NULL;
    DECLARE v_current   VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_id        CHAR(36)     DEFAULT NULL;
    DECLARE v_purpose   VARCHAR(10)  DEFAULT NULL;
    DECLARE v_email     VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_duplicate BOOLEAN      DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- 1062 = trùng khóa uq_users_email (tài khoản khác vừa lấy email này).
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    START TRANSACTION;

    SELECT u.id, u.email INTO v_user_id, v_current
      FROM users u
     WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND u.role = 'customer'
       AND u.status = 'active'
     LIMIT 1
       FOR UPDATE;

    IF v_user_id IS NOT NULL THEN
        SELECT v.id, v.purpose, v.email INTO v_id, v_purpose, v_email
          FROM email_verifications v
         WHERE v.id = (p_verification_id COLLATE utf8mb4_unicode_ci)
           AND v.user_id = v_user_id
           AND v.used_at IS NULL
           AND v.expires_at > NOW()
         LIMIT 1
           FOR UPDATE;
    END IF;

    IF v_id IS NULL OR (v_purpose = 'verify' AND v_email <> v_current) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS purpose, v_current AS email;
        LEAVE proc;
    END IF;

    IF v_purpose = 'verify' THEN
        UPDATE users SET email_verified_at = NOW() WHERE id = v_user_id;
    ELSE
        IF EXISTS (SELECT 1 FROM users x
                    WHERE x.email = (v_email COLLATE utf8mb4_unicode_ci)
                      AND x.id <> v_user_id) THEN
            SET v_duplicate = TRUE;
        ELSE
            UPDATE users SET email = v_email, email_verified_at = NOW() WHERE id = v_user_id;
        END IF;

        IF v_duplicate THEN
            ROLLBACK;
            UPDATE email_verifications SET used_at = NOW() WHERE id = v_id AND used_at IS NULL;
            SELECT 'taken' AS result, v_purpose AS purpose, v_current AS email;
            LEAVE proc;
        END IF;

        -- Email đã đổi: mã khác đang chờ (vd. mã xác minh email cũ) không còn dùng được.
        UPDATE email_verifications
           SET expires_at = NOW()
         WHERE user_id = v_user_id
           AND id <> v_id
           AND used_at IS NULL
           AND expires_at > NOW();
        SET v_current = v_email;
    END IF;

    UPDATE email_verifications SET used_at = NOW() WHERE id = v_id;

    COMMIT;
    SELECT 'ok' AS result, v_purpose AS purpose, v_current AS email;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_verify_cancel(p_verification_id, p_user_id)
--   Bỏ mã vừa ghi khi gửi email lỗi (mã vẫn tính vào giới hạn 60 giây / 5 mã mỗi giờ).
--   1 dòng: result = 'ok' | 'not_found'.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_verify_cancel;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_verify_cancel(
    IN p_verification_id CHAR(36),
    IN p_user_id         CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    UPDATE email_verifications
       SET expires_at = LEAST(expires_at, NOW())
     WHERE id = (p_verification_id COLLATE utf8mb4_unicode_ci)
       AND user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND used_at IS NULL;

    SELECT IF(ROW_COUNT() > 0, 'ok', 'not_found') AS result;
END$$
DELIMITER ;
