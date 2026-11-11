-- =====================================================================
-- LocalTour v0.5 - 26_procedures_NTK_setup.sql
-- Mục đích  : Procedure cho các script cài đặt trong src/scripts (Sprint 6, đóng gói demo):
--             tạo / đặt lại tài khoản quản trị (create_admin.php) và kiểm tra cài đặt
--             (check_install.php, install_database.php). Trang web không gọi các procedure này.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - Sprint 6
-- Procedures: NTK_sp_setup_admin_save, NTK_sp_setup_db_info, NTK_sp_setup_object_list,
--             NTK_sp_setup_demo_status, NTK_sp_setup_local_image_list
-- Quy tắc   : * NTK_sp_setup_admin_save chạy với quyền của người gọi (SQL SECURITY INVOKER):
--               tài khoản chỉ có quyền EXECUTE (tài khoản ứng dụng của database dùng chung)
--               không tạo được quản trị viên. Chỉ tạo tài khoản mới hoặc đặt lại mật khẩu của
--               tài khoản đang là quản trị viên; không nâng quyền tài khoản khách hàng / nhà
--               cung cấp. Mật khẩu được băm bằng password_hash() của PHP trước khi gọi.
--             * Các procedure còn lại chỉ đọc (tên bảng / procedure, bảng mã, số liệu demo).
--             * Không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_setup_admin_save(p_email, p_name, p_password_hash)
--   Email chưa có: tạo tài khoản role = 'admin', status = 'active' (p_name NULL / '' thì đặt
--   tên "Quản trị viên LocalTour"). Email là quản trị viên: đặt mật khẩu mới, mở khóa,
--   đổi tên khi có p_name. Email của tài khoản khác: không đổi gì.
--   Ghi admin_logs (target_type 'user', action 'admin_setup').
--   1 dòng: result ('created', 'reset', 'not_admin', 'invalid'), user_id, name, role, old_status.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setup_admin_save;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setup_admin_save(
    IN p_email         VARCHAR(150),
    IN p_name          VARCHAR(100),
    IN p_password_hash VARCHAR(255)
)
MODIFIES SQL DATA
SQL SECURITY INVOKER
proc: BEGIN
    DECLARE v_email   VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(p_email));
    DECLARE v_name    VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_name), '');
    DECLARE v_user_id CHAR(36)     DEFAULT NULL;
    DECLARE v_role    VARCHAR(20)  DEFAULT NULL;
    DECLARE v_status  VARCHAR(20)  DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_user_id = NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF COALESCE(v_email, '') = '' OR COALESCE(TRIM(p_password_hash), '') = '' THEN
        SELECT 'invalid' AS result, NULL AS user_id, NULL AS name, NULL AS role, NULL AS old_status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT id, role, status
      INTO v_user_id, v_role, v_status
      FROM users
     WHERE email = (v_email COLLATE utf8mb4_unicode_ci)
     LIMIT 1
       FOR UPDATE;

    IF v_user_id IS NULL THEN
        SET v_user_id = UUID();
        INSERT INTO users (id, email, password_hash, name, phone, role, status)
        VALUES (v_user_id, v_email, p_password_hash, COALESCE(v_name, 'Quản trị viên LocalTour'),
                NULL, 'admin', 'active');
        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note)
        VALUES (UUID(), v_user_id, 'user', v_user_id, 'admin_setup', NULL, 'active',
                'Tạo tài khoản quản trị bằng scripts/create_admin.php');
        COMMIT;
        SELECT 'created' AS result, v_user_id AS user_id, COALESCE(v_name, 'Quản trị viên LocalTour') AS name,
               'admin' AS role, NULL AS old_status;
        LEAVE proc;
    END IF;

    IF v_role <> 'admin' THEN
        ROLLBACK;
        SELECT 'not_admin' AS result, v_user_id AS user_id, NULL AS name, v_role AS role, v_status AS old_status;
        LEAVE proc;
    END IF;

    UPDATE users
       SET password_hash = p_password_hash,
           status        = 'active',
           name          = COALESCE(v_name, name)
     WHERE id = v_user_id;
    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note)
    VALUES (UUID(), v_user_id, 'user', v_user_id, 'admin_setup', v_status, 'active',
            'Đặt lại mật khẩu quản trị bằng scripts/create_admin.php');
    COMMIT;

    SELECT 'reset' AS result, u.id AS user_id, u.name, u.role, v_status AS old_status
      FROM users u
     WHERE u.id = v_user_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_setup_db_info()
--   1 dòng: database_name, server_version, db_charset, db_collation (bảng mã mặc định của
--   database; procedure nhận tham số tiếng Việt theo bảng mã này, phải là utf8mb4).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setup_db_info;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setup_db_info()
READS SQL DATA
BEGIN
    SELECT
        DATABASE()                AS database_name,
        VERSION()                 AS server_version,
        @@character_set_database  AS db_charset,
        @@collation_database      AS db_collation;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_setup_object_list()
--   Bảng và procedure đang có trong database: object_type ('table' / 'procedure'), object_name,
--   collation_name (collation của bảng / của database lúc tạo procedure), client_charset (bảng mã
--   của phiên import khi tạo procedure; NULL với bảng). check_install.php so tên với danh sách đọc
--   từ các file src/database/NN_*.sql và báo bảng / procedure không dùng utf8mb4.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setup_object_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setup_object_list()
READS SQL DATA
BEGIN
    SELECT 'table' AS object_type, t.TABLE_NAME AS object_name,
           t.TABLE_COLLATION AS collation_name, NULL AS client_charset
      FROM information_schema.TABLES t
     WHERE t.TABLE_SCHEMA = DATABASE()
       AND t.TABLE_TYPE = 'BASE TABLE'
    UNION ALL
    SELECT 'procedure', r.ROUTINE_NAME, r.DATABASE_COLLATION, r.CHARACTER_SET_CLIENT
      FROM information_schema.ROUTINES r
     WHERE r.ROUTINE_SCHEMA = DATABASE()
       AND r.ROUTINE_TYPE = 'PROCEDURE'
    ORDER BY 1, 2;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_setup_demo_status()
--   1 dòng: admin_ready (số quản trị viên đang hoạt động đã có mật khẩu, đăng nhập được),
--   open_schedules (số lịch còn nhận khách: open, chưa khởi hành, còn chỗ). Lịch mẫu tính theo
--   ngày import, nên open_schedules = 0 nghĩa là cần cài lại database trước buổi demo.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setup_demo_status;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setup_demo_status()
READS SQL DATA
BEGIN
    SELECT
        (SELECT COUNT(*) FROM users
          WHERE role = 'admin' AND status = 'active'
            AND password_hash IS NOT NULL AND password_hash <> '')              AS admin_ready,
        (SELECT COUNT(*) FROM schedules
          WHERE status = 'open' AND starts_at > NOW() AND remaining > 0)        AS open_schedules;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_setup_local_image_list()
--   Đường dẫn ảnh tour lưu trên máy (không phải link http/https), mỗi đường dẫn 1 dòng: url.
--   check_install.php kiểm tra file có trong public/assets không (thiếu thì trang hiện ảnh thay thế).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setup_local_image_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setup_local_image_list()
READS SQL DATA
BEGIN
    SELECT DISTINCT i.url
      FROM tour_images i
     WHERE i.url NOT LIKE 'http://%'
       AND i.url NOT LIKE 'https://%'
     ORDER BY i.url;
END$$
DELIMITER ;
