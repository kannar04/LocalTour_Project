-- =====================================================================
-- LocalTour v0.2 - 13_procedures_NMT_catalog.sql
-- Mục đích  : CRUD nền tảng cho trang quản trị (Sprint 4 - WBS 4.3.1.1, 4.4.2.1, 4.4.2.2):
--             đơn vị tổ chức (FR-13), thêm / sửa thông tin tour và trạng thái xác minh
--             (FR-13, NFR-07), lịch khởi hành, sức chứa và giá vé theo lịch (FR-14).
-- Phụ trách : Nguyễn Minh Thức (NMT)
-- Procedures: NMT_sp_admin_provider_list, NMT_sp_admin_provider_detail,
--             NMT_sp_admin_provider_create, NMT_sp_admin_provider_update,
--             NMT_sp_admin_destination_list, NMT_sp_admin_category_list,
--             NMT_sp_admin_tour_form, NMT_sp_admin_tour_validate (dùng nội bộ),
--             NMT_sp_admin_tour_create, NMT_sp_admin_tour_update,
--             NMT_sp_admin_schedule_list, NMT_sp_admin_schedule_detail,
--             NMT_sp_admin_schedule_create, NMT_sp_admin_schedule_update,
--             NMT_sp_admin_schedule_log_list
-- Quy tắc   : Chỉ trang quản trị gọi các procedure này (ứng dụng kiểm tra tài khoản quản
--             trị viên và dữ liệu nhập trước). Procedure ghi dữ liệu kiểm tra lại người
--             thao tác là quản trị viên đang hoạt động và kiểm tra lại dữ liệu (lớp chặn
--             cuối), rồi ghi đúng một dòng admin_logs trong cùng transaction
--             (target_type 'provider' / 'tour' / 'schedule').
--             Đơn vị tổ chức: chưa có tài khoản đăng nhập riêng. Thêm đơn vị = thêm một
--             dòng users (role 'provider', password_hash NULL, status 'active', name = tên
--             đơn vị, email = email liên hệ viết thường) và một dòng providers.
--             approved_at = thời điểm chuyển sang 'approved' (giữ nguyên khi vẫn
--             'approved', NULL khi không còn 'approved').
--             Tour mới luôn ở approval_status 'pending' (chờ duyệt ở trang Duyệt tour);
--             sửa tour giữ nguyên trạng thái duyệt. verification_status 'verified' cần
--             source_url; verified_at = ngày chuyển sang 'verified', NULL khi 'unverified'
--             (NFR-07: thiếu nguồn hoặc ngày thì để unverified).
--             Lịch khởi hành: lịch mới 'open', remaining = capacity, vé 'adult' (từ 12 tuổi)
--             và vé 'child' (4 - 11 tuổi, không bắt buộc).
--             Số chỗ đang giữ (held) = capacity - remaining (đơn 'pending' chưa giữ chỗ).
--             Sửa lịch: chỉ đổi giờ khi lịch chưa khởi hành; capacity mới >= held;
--             remaining = capacity mới - held (0 <= remaining <= capacity); 'open' / 'full'
--             tính lại theo remaining. Hủy lịch bị chặn khi còn đơn pending /
--             awaiting_payment / confirmed. Đổi giá chỉ đổi ticket_types.price_vnd: đơn
--             đã đặt giữ giá đã chụp ở booking_lines.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; so sánh "có thay
--             đổi không" dùng BINARY để nhận cả đổi hoa thường và dấu. Không có DEFINER.
-- Chạy sau  : 01_schema.sql -> 11. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_list()
--   Mọi đơn vị tổ chức, xếp theo tên. Cột: provider_id, business_name, contact_phone,
--   email, approval_status, approved_at, user_status, tour_count (mọi trạng thái duyệt).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_list()
READS SQL DATA
BEGIN
    SELECT
        p.id              AS provider_id,
        p.business_name,
        p.contact_phone,
        u.email,
        p.approval_status,
        p.approved_at,
        u.status          AS user_status,
        (SELECT COUNT(*)
           FROM tours t
          WHERE t.provider_id = p.id) AS tour_count
    FROM providers p
    JOIN users u ON u.id = p.user_id
    ORDER BY p.business_name, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_detail(p_provider_id)
--   0 hoặc 1 dòng, cùng các cột với NMT_sp_admin_provider_list.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_detail;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_detail(
    IN p_provider_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id              AS provider_id,
        p.business_name,
        p.contact_phone,
        u.email,
        p.approval_status,
        p.approved_at,
        u.status          AS user_status,
        (SELECT COUNT(*)
           FROM tours t
          WHERE t.provider_id = p.id) AS tour_count
    FROM providers p
    JOIN users u ON u.id = p.user_id
    WHERE p.id = (p_provider_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_create(p_actor_user_id, p_business_name, p_contact_phone,
--                              p_email, p_approval_status)
--   Thêm tài khoản users (role 'provider') và dòng providers, ghi admin_logs
--   'provider_create'.
--   1 dòng: result, field, provider_id.
--     result = 'ok'          : đã thêm; provider_id = mã đơn vị mới.
--              'forbidden'   : người thao tác không phải quản trị viên đang hoạt động.
--              'invalid'     : dữ liệu sai; field = ô sai đầu tiên (business_name,
--                              contact_phone, email, approval_status).
--              'email_taken' : email đã thuộc một tài khoản khác.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_create;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_create(
    IN p_actor_user_id   CHAR(36),
    IN p_business_name   VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_contact_phone   VARCHAR(50),
    IN p_email           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_approval_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_name        VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT TRIM(p_business_name);
    DECLARE v_phone       VARCHAR(50)  DEFAULT TRIM(p_contact_phone);
    DECLARE v_email       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(p_email));
    DECLARE v_status      VARCHAR(20)  DEFAULT COALESCE(p_approval_status, '');
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_user_id     CHAR(36)     DEFAULT UUID();
    DECLARE v_provider_id CHAR(36)     DEFAULT UUID();
    DECLARE v_duplicate   BOOLEAN      DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- 1062 = trùng khóa UNIQUE (email vừa được tài khoản khác dùng)
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF v_name IS NULL OR v_name = '' OR CHAR_LENGTH(v_name) > 150 THEN
        SET v_field = 'business_name';
    ELSEIF v_phone IS NULL OR CHAR_LENGTH(v_phone) NOT BETWEEN 8 AND 20
        OR v_phone NOT REGEXP '^[+]?[0-9 ]+$' THEN
        SET v_field = 'contact_phone';
    ELSEIF v_email IS NULL OR CHAR_LENGTH(v_email) > 150
        OR v_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SET v_field = 'email';
    ELSEIF v_status NOT IN ('pending', 'approved', 'rejected') THEN
        SET v_field = 'approval_status';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE email = (v_email COLLATE utf8mb4_unicode_ci)) THEN
        SELECT 'email_taken' AS result, 'email' AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- users.name tối đa 100 ký tự; tên đầy đủ nằm ở providers.business_name.
    INSERT INTO users (id, email, password_hash, name, phone, role, status)
    VALUES (v_user_id, v_email, NULL, LEFT(v_name, 100), NULL, 'provider', 'active');

    IF v_duplicate THEN
        ROLLBACK;
        SELECT 'email_taken' AS result, 'email' AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    INSERT INTO providers (id, user_id, business_name, contact_phone, approval_status, approved_at)
    VALUES (v_provider_id, v_user_id, v_name, v_phone, v_status,
            IF(v_status = 'approved', NOW(), NULL));

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'provider', v_provider_id, 'provider_create', NULL, v_status, NULL, NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_provider_id AS provider_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_update(p_actor_user_id, p_provider_id, p_business_name,
--                              p_contact_phone, p_email, p_approval_status)
--   Sửa thông tin đơn vị (và name / email của tài khoản users đi kèm), ghi admin_logs
--   'provider_update' (from / to = trạng thái hợp tác, note = các ô đã sửa).
--   1 dòng: result, field, provider_id.
--     result = 'ok'          : đã lưu.
--              'unchanged'   : dữ liệu giống hệt hiện tại, không ghi gì.
--              'forbidden'   : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'   : không có đơn vị này.
--              'invalid'     : dữ liệu sai; field như NMT_sp_admin_provider_create.
--              'email_taken' : email đã thuộc một tài khoản khác.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_update;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_update(
    IN p_actor_user_id   CHAR(36),
    IN p_provider_id     CHAR(36),
    IN p_business_name   VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_contact_phone   VARCHAR(50),
    IN p_email           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_approval_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_name       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT TRIM(p_business_name);
    DECLARE v_phone      VARCHAR(50)  DEFAULT TRIM(p_contact_phone);
    DECLARE v_email      VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(p_email));
    DECLARE v_status     VARCHAR(20)  DEFAULT COALESCE(p_approval_status, '');
    DECLARE v_field      VARCHAR(30)  DEFAULT NULL;
    DECLARE v_user_id    CHAR(36)     DEFAULT NULL;
    DECLARE v_old_name   VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_phone  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_old_email  VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_status VARCHAR(20)  DEFAULT NULL;
    DECLARE v_changes    VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT '';
    DECLARE v_duplicate  BOOLEAN      DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF v_name IS NULL OR v_name = '' OR CHAR_LENGTH(v_name) > 150 THEN
        SET v_field = 'business_name';
    ELSEIF v_phone IS NULL OR CHAR_LENGTH(v_phone) NOT BETWEEN 8 AND 20
        OR v_phone NOT REGEXP '^[+]?[0-9 ]+$' THEN
        SET v_field = 'contact_phone';
    ELSEIF v_email IS NULL OR CHAR_LENGTH(v_email) > 150
        OR v_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SET v_field = 'email';
    ELSEIF v_status NOT IN ('pending', 'approved', 'rejected') THEN
        SET v_field = 'approval_status';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT p.user_id, p.business_name, p.contact_phone, u.email, p.approval_status
      INTO v_user_id, v_old_name, v_old_phone, v_old_email, v_old_status
      FROM providers p
      JOIN users u ON u.id = p.user_id
     WHERE p.id = (p_provider_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_user_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM users
                WHERE email = (v_email COLLATE utf8mb4_unicode_ci)
                  AND id <> v_user_id) THEN
        ROLLBACK;
        SELECT 'email_taken' AS result, 'email' AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    SET v_changes = CONCAT_WS(', ',
        IF(BINARY v_old_name  <> BINARY v_name,  'tên đơn vị', NULL),
        IF(BINARY v_old_phone <> BINARY v_phone, 'số điện thoại', NULL),
        IF(BINARY v_old_email <> BINARY v_email, 'email', NULL));

    IF v_changes = '' AND v_old_status = v_status THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    UPDATE users
       SET email = v_email,
           name = LEFT(v_name, 100)
     WHERE id = v_user_id;

    IF v_duplicate THEN
        ROLLBACK;
        SELECT 'email_taken' AS result, 'email' AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    UPDATE providers
       SET business_name = v_name,
           contact_phone = v_phone,
           approved_at = CASE
                             WHEN v_status <> 'approved' THEN NULL
                             WHEN approval_status = 'approved' THEN approved_at
                             ELSE NOW()
                         END,
           approval_status = v_status
     WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'provider', p_provider_id, 'provider_update',
            v_old_status, v_status, NULLIF(CONCAT('Sửa: ', v_changes), 'Sửa: '), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, p_provider_id AS provider_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_destination_list() / NMT_sp_admin_category_list()
--   Mọi điểm đến / loại hình (kể cả chưa có tour hiển thị), dùng cho ô chọn trong
--   form tour. Cột: destination_id, name / category_id, name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_destination_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_destination_list()
READS SQL DATA
BEGIN
    SELECT d.id AS destination_id, d.name
      FROM destinations d
     ORDER BY d.sort_order, d.name, d.id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS NMT_sp_admin_category_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_category_list()
READS SQL DATA
BEGIN
    SELECT c.id AS category_id, c.name
      FROM categories c
     ORDER BY c.name, c.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_form(p_tour_id)
--   0 hoặc 1 dòng: giá trị gốc của các cột trong form sửa tour, mọi trạng thái duyệt.
--   Cột: tour_id, provider_id, destination_id, category_id, title, description,
--   destination, duration_minutes, max_group_size, language_codes, pickup_mode,
--   meeting_point, transport, guide_info, dropoff_point, document_terms, meal_terms,
--   voucher_terms, reschedule_terms, source_url, verification_status, verified_at,
--   approval_status.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_form;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_form(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id AS tour_id,
        t.provider_id,
        t.destination_id,
        t.category_id,
        t.title,
        t.description,
        t.destination,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.transport,
        t.guide_info,
        t.dropoff_point,
        t.document_terms,
        t.meal_terms,
        t.voucher_terms,
        t.reschedule_terms,
        t.source_url,
        t.verification_status,
        t.verified_at,
        t.approval_status
    FROM tours t
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_validate(...)
--   Dùng nội bộ cho NMT_sp_admin_tour_create / NMT_sp_admin_tour_update (ứng dụng không
--   gọi). Nhận giá trị đã TRIM (ô không bắt buộc để trống = NULL).
--   OUT p_field: NULL = hợp lệ; ngược lại tên ô sai đầu tiên (provider_id, destination_id,
--     category_id, title, description, duration_minutes, max_group_size, language_codes,
--     pickup_mode, meeting_point, transport, guide_info, dropoff_point, source_url,
--     verification_status).
--   OUT p_destination_name: destinations.name của điểm đến đã chọn (ghi vào
--     tours.destination).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_validate;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_validate(
    IN  p_provider_id         CHAR(36),
    IN  p_destination_id      CHAR(36),
    IN  p_category_id         CHAR(36),
    IN  p_title               VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_description         TEXT CHARACTER SET utf8mb4,
    IN  p_duration_minutes    INT,
    IN  p_max_group_size      INT,
    IN  p_language_codes      VARCHAR(100),
    IN  p_pickup_mode         VARCHAR(20),
    IN  p_meeting_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_transport           VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_guide_info          VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_dropoff_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_source_url          VARCHAR(600),
    IN  p_verification_status VARCHAR(20),
    OUT p_field               VARCHAR(30),
    OUT p_destination_name    VARCHAR(100) CHARACTER SET utf8mb4
)
READS SQL DATA
BEGIN
    SET p_field = NULL;
    SET p_destination_name = NULL;

    SELECT d.name INTO p_destination_name
      FROM destinations d
     WHERE d.id = (p_destination_id COLLATE utf8mb4_unicode_ci);

    IF p_provider_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM providers WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci)) THEN
        SET p_field = 'provider_id';
    ELSEIF p_destination_name IS NULL THEN
        SET p_field = 'destination_id';
    ELSEIF p_category_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM categories WHERE id = (p_category_id COLLATE utf8mb4_unicode_ci)) THEN
        SET p_field = 'category_id';
    ELSEIF p_title IS NULL OR p_title = '' OR CHAR_LENGTH(p_title) > 200 THEN
        SET p_field = 'title';
    ELSEIF p_description IS NULL OR p_description = '' THEN
        SET p_field = 'description';
    ELSEIF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 15 AND 10080 THEN
        SET p_field = 'duration_minutes';
    ELSEIF p_max_group_size IS NULL OR p_max_group_size NOT BETWEEN 1 AND 500 THEN
        SET p_field = 'max_group_size';
    ELSEIF p_language_codes IS NULL OR CHAR_LENGTH(p_language_codes) > 50
        OR BINARY p_language_codes NOT REGEXP '^[a-z]{2}(,[a-z]{2})*$' THEN
        -- BINARY: REGEXP theo collation _ci không phân biệt hoa thường.
        SET p_field = 'language_codes';
    ELSEIF COALESCE(p_pickup_mode, '') NOT IN ('meeting_point', 'hotel_pickup') THEN
        SET p_field = 'pickup_mode';
    ELSEIF (p_pickup_mode = 'meeting_point' AND p_meeting_point IS NULL)
        OR CHAR_LENGTH(p_meeting_point) > 255 THEN
        SET p_field = 'meeting_point';
    ELSEIF CHAR_LENGTH(p_transport) > 255 THEN
        SET p_field = 'transport';
    ELSEIF CHAR_LENGTH(p_guide_info) > 255 THEN
        SET p_field = 'guide_info';
    ELSEIF CHAR_LENGTH(p_dropoff_point) > 255 THEN
        SET p_field = 'dropoff_point';
    ELSEIF CHAR_LENGTH(p_source_url) > 500
        OR (p_source_url IS NOT NULL AND p_source_url NOT REGEXP '^https?://[^ ]+$') THEN
        SET p_field = 'source_url';
    ELSEIF COALESCE(p_verification_status, '') NOT IN ('unverified', 'verified') THEN
        SET p_field = 'verification_status';
    ELSEIF p_verification_status = 'verified' AND p_source_url IS NULL THEN
        -- NFR-07: thiếu nguồn thì không được đánh dấu đã xác minh.
        SET p_field = 'source_url';
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_create(p_actor_user_id, p_provider_id, p_destination_id,
--   p_category_id, p_title, p_description, p_duration_minutes, p_max_group_size,
--   p_language_codes, p_pickup_mode, p_meeting_point, p_transport, p_guide_info,
--   p_dropoff_point, p_document_terms, p_meal_terms, p_voucher_terms,
--   p_reschedule_terms, p_source_url, p_verification_status)
--   Thêm tour ở trạng thái 'pending' (chờ duyệt), ghi admin_logs 'tour_create'
--   (from NULL, to 'pending'). Ô không bắt buộc để trống = NULL.
--   1 dòng: result, field, tour_id.
--     result = 'ok'        : đã thêm; tour_id = mã tour mới.
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'invalid'   : dữ liệu sai; field = ô sai đầu tiên (xem
--                            NMT_sp_admin_tour_validate).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_create;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_create(
    IN p_actor_user_id       CHAR(36),
    IN p_provider_id         CHAR(36),
    IN p_destination_id      CHAR(36),
    IN p_category_id         CHAR(36),
    IN p_title               VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_description         TEXT CHARACTER SET utf8mb4,
    IN p_duration_minutes    INT,
    IN p_max_group_size      INT,
    IN p_language_codes      VARCHAR(100),
    IN p_pickup_mode         VARCHAR(20),
    IN p_meeting_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_transport           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_guide_info          VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_dropoff_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_document_terms      TEXT CHARACTER SET utf8mb4,
    IN p_meal_terms          TEXT CHARACTER SET utf8mb4,
    IN p_voucher_terms       TEXT CHARACTER SET utf8mb4,
    IN p_reschedule_terms    TEXT CHARACTER SET utf8mb4,
    IN p_source_url          VARCHAR(600),
    IN p_verification_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_title       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_title), '');
    DECLARE v_description TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_description), '');
    DECLARE v_languages   VARCHAR(100) DEFAULT NULLIF(TRIM(p_language_codes), '');
    DECLARE v_meeting     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_meeting_point), '');
    DECLARE v_transport   VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_transport), '');
    DECLARE v_guide       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_guide_info), '');
    DECLARE v_dropoff     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_dropoff_point), '');
    DECLARE v_source      VARCHAR(600) DEFAULT NULLIF(TRIM(p_source_url), '');
    DECLARE v_category    CHAR(36)     DEFAULT NULLIF(p_category_id, '');
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_destination VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_tour_id     CHAR(36)     DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    CALL NMT_sp_admin_tour_validate(p_provider_id, p_destination_id, v_category, v_title,
        v_description, p_duration_minutes, p_max_group_size, v_languages, p_pickup_mode,
        v_meeting, v_transport, v_guide, v_dropoff, v_source, p_verification_status,
        v_field, v_destination);

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    INSERT INTO tours (id, provider_id, destination_id, category_id, title, description,
                       destination, duration_minutes, max_group_size, language_codes,
                       pickup_mode, meeting_point, included_summary, transport, guide_info,
                       dropoff_point, excluded_summary, document_terms, meal_terms,
                       voucher_terms, reschedule_terms, source_url, verified_at,
                       verification_status, approval_status)
    VALUES (v_tour_id, p_provider_id, p_destination_id, v_category, v_title, v_description,
            v_destination, p_duration_minutes, p_max_group_size, v_languages,
            p_pickup_mode, v_meeting, NULL, v_transport, v_guide,
            v_dropoff, NULL, NULLIF(TRIM(p_document_terms), ''), NULLIF(TRIM(p_meal_terms), ''),
            NULLIF(TRIM(p_voucher_terms), ''), NULLIF(TRIM(p_reschedule_terms), ''), v_source,
            IF(p_verification_status = 'verified', CURDATE(), NULL),
            p_verification_status, 'pending');

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', v_tour_id, 'tour_create', NULL, 'pending', NULL, NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_tour_id AS tour_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_update(p_actor_user_id, p_tour_id, ... cùng tham số với
--   NMT_sp_admin_tour_create)
--   Sửa thông tin tour, giữ nguyên approval_status. Ghi admin_logs 'tour_update':
--   from / to = trạng thái xác minh trước / sau, note = các ô đã sửa.
--   1 dòng: result, field, tour_id.
--     result = 'ok'        : đã lưu.
--              'unchanged' : dữ liệu giống hệt hiện tại, không ghi gì.
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found' : không có tour này.
--              'invalid'   : dữ liệu sai; field như NMT_sp_admin_tour_create.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_update;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_update(
    IN p_actor_user_id       CHAR(36),
    IN p_tour_id             CHAR(36),
    IN p_provider_id         CHAR(36),
    IN p_destination_id      CHAR(36),
    IN p_category_id         CHAR(36),
    IN p_title               VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_description         TEXT CHARACTER SET utf8mb4,
    IN p_duration_minutes    INT,
    IN p_max_group_size      INT,
    IN p_language_codes      VARCHAR(100),
    IN p_pickup_mode         VARCHAR(20),
    IN p_meeting_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_transport           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_guide_info          VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_dropoff_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_document_terms      TEXT CHARACTER SET utf8mb4,
    IN p_meal_terms          TEXT CHARACTER SET utf8mb4,
    IN p_voucher_terms       TEXT CHARACTER SET utf8mb4,
    IN p_reschedule_terms    TEXT CHARACTER SET utf8mb4,
    IN p_source_url          VARCHAR(600),
    IN p_verification_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_title       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_title), '');
    DECLARE v_description TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_description), '');
    DECLARE v_languages   VARCHAR(100) DEFAULT NULLIF(TRIM(p_language_codes), '');
    DECLARE v_meeting     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_meeting_point), '');
    DECLARE v_transport   VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_transport), '');
    DECLARE v_guide       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_guide_info), '');
    DECLARE v_dropoff     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_dropoff_point), '');
    DECLARE v_documents   TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_document_terms), '');
    DECLARE v_meals       TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_meal_terms), '');
    DECLARE v_vouchers    TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_voucher_terms), '');
    DECLARE v_reschedule  TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_reschedule_terms), '');
    DECLARE v_source      VARCHAR(600) DEFAULT NULLIF(TRIM(p_source_url), '');
    DECLARE v_category    CHAR(36)     DEFAULT NULLIF(p_category_id, '');
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_destination VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_changes     VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT '';
    -- Giá trị hiện tại (o_ = old)
    DECLARE o_provider    CHAR(36)     DEFAULT NULL;
    DECLARE o_destination CHAR(36)     DEFAULT NULL;
    DECLARE o_category    CHAR(36)     DEFAULT NULL;
    DECLARE o_title       VARCHAR(200) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_description TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_duration    INT          DEFAULT NULL;
    DECLARE o_group       INT          DEFAULT NULL;
    DECLARE o_languages   VARCHAR(50)  DEFAULT NULL;
    DECLARE o_pickup      VARCHAR(20)  DEFAULT NULL;
    DECLARE o_meeting     VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_transport   VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_guide       VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_dropoff     VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_documents   TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_meals       TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_vouchers    TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_reschedule  TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_source      VARCHAR(500) DEFAULT NULL;
    DECLARE o_verified    VARCHAR(20)  DEFAULT NULL;
    DECLARE o_verified_at DATE         DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    CALL NMT_sp_admin_tour_validate(p_provider_id, p_destination_id, v_category, v_title,
        v_description, p_duration_minutes, p_max_group_size, v_languages, p_pickup_mode,
        v_meeting, v_transport, v_guide, v_dropoff, v_source, p_verification_status,
        v_field, v_destination);

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, p_tour_id AS tour_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT t.provider_id, t.destination_id, t.category_id, t.title, t.description,
           t.duration_minutes, t.max_group_size, t.language_codes, t.pickup_mode,
           t.meeting_point, t.transport, t.guide_info, t.dropoff_point, t.document_terms,
           t.meal_terms, t.voucher_terms, t.reschedule_terms, t.source_url,
           t.verification_status, t.verified_at
      INTO o_provider, o_destination, o_category, o_title, o_description,
           o_duration, o_group, o_languages, o_pickup,
           o_meeting, o_transport, o_guide, o_dropoff, o_documents,
           o_meals, o_vouchers, o_reschedule, o_source,
           o_verified, o_verified_at
      FROM tours t
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF o_title IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    SET v_changes = CONCAT_WS(', ',
        IF(NOT (BINARY o_title       <=> BINARY v_title),          'tên tour', NULL),
        IF(NOT (BINARY o_provider    <=> BINARY p_provider_id),    'đơn vị tổ chức', NULL),
        IF(NOT (BINARY o_destination <=> BINARY p_destination_id), 'điểm đến', NULL),
        IF(NOT (BINARY o_category    <=> BINARY v_category),       'loại hình', NULL),
        IF(NOT (BINARY o_description <=> BINARY v_description),    'mô tả', NULL),
        IF(NOT (o_duration <=> p_duration_minutes),                'thời lượng', NULL),
        IF(NOT (o_group    <=> p_max_group_size),                  'số khách tối đa', NULL),
        IF(NOT (BINARY o_languages   <=> BINARY v_languages),      'ngôn ngữ', NULL),
        IF(NOT (BINARY o_pickup      <=> BINARY p_pickup_mode),    'hình thức đón', NULL),
        IF(NOT (BINARY o_meeting     <=> BINARY v_meeting),        'điểm hẹn', NULL),
        IF(NOT (BINARY o_transport   <=> BINARY v_transport),      'phương tiện', NULL),
        IF(NOT (BINARY o_guide       <=> BINARY v_guide),          'hướng dẫn viên', NULL),
        IF(NOT (BINARY o_dropoff     <=> BINARY v_dropoff),        'điểm trả khách', NULL),
        IF(NOT (BINARY o_documents   <=> BINARY v_documents),      'giấy tờ', NULL),
        IF(NOT (BINARY o_meals       <=> BINARY v_meals),          'ăn uống', NULL),
        IF(NOT (BINARY o_vouchers    <=> BINARY v_vouchers),       'voucher', NULL),
        IF(NOT (BINARY o_reschedule  <=> BINARY v_reschedule),     'đổi lịch', NULL),
        IF(NOT (BINARY o_source      <=> BINARY v_source),         'nguồn tham khảo', NULL));

    IF v_changes = '' AND o_verified = p_verification_status THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, p_tour_id AS tour_id;
        LEAVE proc;
    END IF;

    UPDATE tours
       SET provider_id = p_provider_id,
           destination_id = p_destination_id,
           category_id = v_category,
           title = v_title,
           description = v_description,
           destination = v_destination,
           duration_minutes = p_duration_minutes,
           max_group_size = p_max_group_size,
           language_codes = v_languages,
           pickup_mode = p_pickup_mode,
           meeting_point = v_meeting,
           transport = v_transport,
           guide_info = v_guide,
           dropoff_point = v_dropoff,
           document_terms = v_documents,
           meal_terms = v_meals,
           voucher_terms = v_vouchers,
           reschedule_terms = v_reschedule,
           source_url = v_source,
           verified_at = CASE
                             WHEN p_verification_status = 'unverified' THEN NULL
                             WHEN o_verified = 'verified' AND o_verified_at IS NOT NULL THEN o_verified_at
                             ELSE CURDATE()
                         END,
           verification_status = p_verification_status
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_update', o_verified, p_verification_status,
            IF(v_changes = '', NULL, LEFT(CONCAT('Sửa: ', v_changes), 255)), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, p_tour_id AS tour_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_list(p_tour_id)
--   Mọi lịch của tour: lịch chưa khởi hành trước (sớm nhất trước), rồi lịch đã qua
--   (gần nhất trước). Cột: schedule_id, starts_at, ends_at, capacity, remaining,
--   held (= capacity - remaining, số chỗ đang giữ), status, departed (1 = đã tới giờ
--   khởi hành), adult_ticket_id, adult_price_vnd, adult_active, child_ticket_id,
--   child_price_vnd, child_active (NULL khi lịch không có loại vé đó),
--   active_booking_count (đơn pending / awaiting_payment / confirmed).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id                                   AS schedule_id,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        GREATEST(0, s.capacity - s.remaining)  AS held,
        s.status,
        (s.starts_at <= NOW())                 AS departed,
        ad.id                                  AS adult_ticket_id,
        ad.price_vnd                           AS adult_price_vnd,
        ad.active                              AS adult_active,
        ch.id                                  AS child_ticket_id,
        ch.price_vnd                           AS child_price_vnd,
        ch.active                              AS child_active,
        (SELECT COUNT(*)
           FROM bookings b
          WHERE b.schedule_id = s.id
            AND b.status IN ('pending', 'awaiting_payment', 'confirmed')) AS active_booking_count
    FROM schedules s
    LEFT JOIN ticket_types ad ON ad.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'adult'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    LEFT JOIN ticket_types ch ON ch.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'child'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY (s.starts_at <= NOW()),
             IF(s.starts_at <= NOW(), NULL, s.starts_at),
             s.starts_at DESC,
             s.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_detail(p_schedule_id)
--   0 hoặc 1 dòng: các cột của NMT_sp_admin_schedule_list cho một lịch, thêm tour_id,
--   tour_title, pending_booking_count và pending_people (đơn 'pending' chưa giữ chỗ:
--   số đơn và tổng số khách).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_detail;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_detail(
    IN p_schedule_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id                                   AS schedule_id,
        t.id                                   AS tour_id,
        t.title                                AS tour_title,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        GREATEST(0, s.capacity - s.remaining)  AS held,
        s.status,
        (s.starts_at <= NOW())                 AS departed,
        ad.id                                  AS adult_ticket_id,
        ad.price_vnd                           AS adult_price_vnd,
        ad.active                              AS adult_active,
        ch.id                                  AS child_ticket_id,
        ch.price_vnd                           AS child_price_vnd,
        ch.active                              AS child_active,
        (SELECT COUNT(*)
           FROM bookings b
          WHERE b.schedule_id = s.id
            AND b.status IN ('pending', 'awaiting_payment', 'confirmed')) AS active_booking_count,
        (SELECT COUNT(*)
           FROM bookings b
          WHERE b.schedule_id = s.id AND b.status = 'pending') AS pending_booking_count,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM bookings b
           JOIN booking_lines bl ON bl.booking_id = b.id
          WHERE b.schedule_id = s.id AND b.status = 'pending') AS pending_people
    FROM schedules s
    JOIN tours t ON t.id = s.tour_id
    LEFT JOIN ticket_types ad ON ad.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'adult'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    LEFT JOIN ticket_types ch ON ch.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'child'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_create(p_actor_user_id, p_tour_id, p_starts_at, p_ends_at,
--                              p_capacity, p_adult_price_vnd, p_child_price_vnd)
--   Thêm lịch 'open' (remaining = capacity), vé 'adult' (từ 12 tuổi) và vé 'child'
--   (4 - 11 tuổi) khi p_child_price_vnd khác NULL. Ghi admin_logs 'schedule_create'.
--   Giới hạn: starts_at sau hiện tại, ends_at sau starts_at, capacity 1 - 500, giá vé
--   1 - 100.000.000 đ.
--   1 dòng: result, field, schedule_id.
--     result = 'ok'        : đã thêm; schedule_id = mã lịch mới.
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found' : không có tour này.
--              'invalid'   : dữ liệu sai; field = starts_at, ends_at, capacity,
--                            adult_price hoặc child_price.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_create;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_create(
    IN p_actor_user_id   CHAR(36),
    IN p_tour_id         CHAR(36),
    IN p_starts_at       DATETIME,
    IN p_ends_at         DATETIME,
    IN p_capacity        INT,
    IN p_adult_price_vnd BIGINT,
    IN p_child_price_vnd BIGINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_field       VARCHAR(30) DEFAULT NULL;
    DECLARE v_schedule_id CHAR(36)    DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS schedule_id;
        LEAVE proc;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)) THEN
        SELECT 'not_found' AS result, NULL AS field, NULL AS schedule_id;
        LEAVE proc;
    END IF;

    IF p_starts_at IS NULL OR p_starts_at <= NOW() THEN
        SET v_field = 'starts_at';
    ELSEIF p_ends_at IS NULL OR p_ends_at <= p_starts_at THEN
        SET v_field = 'ends_at';
    ELSEIF p_capacity IS NULL OR p_capacity NOT BETWEEN 1 AND 500 THEN
        SET v_field = 'capacity';
    ELSEIF p_adult_price_vnd IS NULL OR p_adult_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'adult_price';
    ELSEIF p_child_price_vnd IS NOT NULL AND p_child_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'child_price';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, NULL AS schedule_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    INSERT INTO schedules (id, tour_id, starts_at, ends_at, capacity, remaining, status)
    VALUES (v_schedule_id, p_tour_id, p_starts_at, p_ends_at, p_capacity, p_capacity, 'open');

    INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
    VALUES (UUID(), v_schedule_id, 'adult', 12, NULL, p_adult_price_vnd, TRUE);

    IF p_child_price_vnd IS NOT NULL THEN
        INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
        VALUES (UUID(), v_schedule_id, 'child', 4, 11, p_child_price_vnd, TRUE);
    END IF;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'schedule', v_schedule_id, 'schedule_create', NULL, 'open',
            CONCAT('Khởi hành ', DATE_FORMAT(p_starts_at, '%d/%m/%Y %H:%i'),
                   ', ', p_capacity, ' chỗ, người lớn ',
                   REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ',
                   IF(p_child_price_vnd IS NULL, '',
                      CONCAT(', trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ'))),
            NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_schedule_id AS schedule_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_update(p_actor_user_id, p_schedule_id, p_starts_at, p_ends_at,
--                              p_capacity, p_adult_price_vnd, p_child_price_vnd, p_status)
--   Sửa lịch trong một transaction (khóa dòng lịch FOR UPDATE):
--     - giờ khởi hành / kết thúc chỉ đổi khi lịch chưa khởi hành; giờ mới phải sau hiện
--       tại và ends_at sau starts_at;
--     - capacity mới >= held; remaining = capacity mới - held;
--     - p_status 'open' (đang mở bán) hoặc 'cancelled' (hủy lịch). Lịch không hủy thì
--       status = 'full' khi remaining = 0, ngược lại 'open';
--     - giá vé: cập nhật price_vnd của vé 'adult' / 'child' (thêm vé nếu chưa có);
--       p_child_price_vnd NULL = ngừng bán vé trẻ em (active = FALSE).
--   Ghi admin_logs 'schedule_update' (from / to = trạng thái lịch, note = nội dung sửa).
--   1 dòng: result, field, status, held, active_bookings.
--     result = 'ok'                  : đã lưu; status = trạng thái mới.
--              'unchanged'           : không có gì thay đổi.
--              'forbidden'           : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'           : không có lịch này.
--              'invalid'             : dữ liệu sai; field = starts_at, ends_at, capacity,
--                                      adult_price, child_price hoặc status.
--              'completed'           : lịch đã hoàn thành, không sửa được.
--              'departed'            : đổi giờ hoặc đổi trạng thái khi lịch đã khởi hành.
--              'capacity_below_held' : capacity mới nhỏ hơn số chỗ đang giữ (held).
--              'has_bookings'        : hủy lịch khi còn đơn pending / awaiting_payment /
--                                      confirmed (active_bookings = số đơn đó).
--     Khi không 'ok', status / held là giá trị hiện tại, không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_update;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_update(
    IN p_actor_user_id   CHAR(36),
    IN p_schedule_id     CHAR(36),
    IN p_starts_at       DATETIME,
    IN p_ends_at         DATETIME,
    IN p_capacity        INT,
    IN p_adult_price_vnd BIGINT,
    IN p_child_price_vnd BIGINT,
    IN p_status          VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_field        VARCHAR(30)  DEFAULT NULL;
    DECLARE v_old_starts   DATETIME     DEFAULT NULL;
    DECLARE v_old_ends     DATETIME     DEFAULT NULL;
    DECLARE v_old_capacity INT          DEFAULT NULL;
    DECLARE v_old_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_held         INT          DEFAULT 0;
    DECLARE v_remaining    INT          DEFAULT 0;
    DECLARE v_new_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_departed     BOOLEAN      DEFAULT FALSE;
    DECLARE v_time_changed BOOLEAN      DEFAULT FALSE;
    DECLARE v_active       INT          DEFAULT 0;
    DECLARE v_adult_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_adult_price  BIGINT       DEFAULT NULL;
    DECLARE v_adult_active BOOLEAN      DEFAULT NULL;
    DECLARE v_child_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_child_price  BIGINT       DEFAULT NULL;
    DECLARE v_child_active BOOLEAN      DEFAULT NULL;
    DECLARE v_old_child    BIGINT       DEFAULT NULL;
    DECLARE v_changes      VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS status, NULL AS held, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa dòng lịch: số chỗ và trạng thái chỉ đổi trong transaction này (đặt tour và
    -- xác nhận chỗ cũng khóa dòng này).
    SELECT s.starts_at, s.ends_at, s.capacity, s.status, GREATEST(0, s.capacity - s.remaining)
      INTO v_old_starts, v_old_ends, v_old_capacity, v_old_status, v_held
      FROM schedules s
     WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS status, NULL AS held, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_active
      FROM bookings b
     WHERE b.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
       AND b.status IN ('pending', 'awaiting_payment', 'confirmed');

    IF v_old_status = 'completed' THEN
        ROLLBACK;
        SELECT 'completed' AS result, NULL AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    SET v_departed = (v_old_starts <= NOW());
    SET v_time_changed = NOT (p_starts_at <=> v_old_starts) OR NOT (p_ends_at <=> v_old_ends);

    IF COALESCE(p_status, '') NOT IN ('open', 'cancelled') THEN
        SET v_field = 'status';
    ELSEIF p_starts_at IS NULL OR (v_time_changed AND NOT v_departed AND p_starts_at <= NOW()) THEN
        SET v_field = 'starts_at';
    ELSEIF p_ends_at IS NULL OR p_ends_at <= p_starts_at THEN
        SET v_field = 'ends_at';
    ELSEIF p_capacity IS NULL OR p_capacity NOT BETWEEN 1 AND 500 THEN
        SET v_field = 'capacity';
    ELSEIF p_adult_price_vnd IS NULL OR p_adult_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'adult_price';
    ELSEIF p_child_price_vnd IS NOT NULL AND p_child_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'child_price';
    END IF;

    IF v_field IS NOT NULL THEN
        ROLLBACK;
        SELECT 'invalid' AS result, v_field AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    -- Lịch đã khởi hành: không đổi giờ, không hủy / mở lại.
    IF v_departed AND (v_time_changed
                       OR (p_status = 'cancelled') <> (v_old_status = 'cancelled')) THEN
        ROLLBACK;
        SELECT 'departed' AS result, NULL AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    IF p_capacity < v_held THEN
        ROLLBACK;
        SELECT 'capacity_below_held' AS result, 'capacity' AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    IF p_status = 'cancelled' AND v_old_status <> 'cancelled' AND v_active > 0 THEN
        ROLLBACK;
        SELECT 'has_bookings' AS result, 'status' AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    SET v_remaining = p_capacity - v_held;
    SET v_new_status = IF(p_status = 'cancelled', 'cancelled', IF(v_remaining = 0, 'full', 'open'));

    -- Vé hiện tại (ưu tiên vé đang bán)
    SELECT tt.id, tt.price_vnd, tt.active INTO v_adult_id, v_adult_price, v_adult_active
      FROM ticket_types tt
     WHERE tt.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci) AND tt.name = 'adult'
     ORDER BY tt.active DESC, tt.id
     LIMIT 1
       FOR UPDATE;

    SELECT tt.id, tt.price_vnd, tt.active INTO v_child_id, v_child_price, v_child_active
      FROM ticket_types tt
     WHERE tt.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci) AND tt.name = 'child'
     ORDER BY tt.active DESC, tt.id
     LIMIT 1
       FOR UPDATE;

    -- Giá trẻ em đang bán (NULL = không bán vé trẻ em)
    SET v_old_child = IF(v_child_active, v_child_price, NULL);

    SET v_changes = CONCAT_WS(', ',
        IF(v_time_changed,
           CONCAT('giờ ', DATE_FORMAT(p_starts_at, '%d/%m/%Y %H:%i'), ' - ', DATE_FORMAT(p_ends_at, '%d/%m/%Y %H:%i')),
           NULL),
        IF(p_capacity <> v_old_capacity, CONCAT('sức chứa ', v_old_capacity, ' → ', p_capacity), NULL),
        IF(v_adult_id IS NULL OR NOT v_adult_active OR v_adult_price <> p_adult_price_vnd,
           CONCAT('giá người lớn ', REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ'), NULL),
        IF(NOT (v_old_child <=> p_child_price_vnd),
           IF(p_child_price_vnd IS NULL, 'ngừng bán vé trẻ em',
              CONCAT('giá trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ')),
           NULL));

    IF v_changes = '' AND v_new_status = v_old_status THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    UPDATE schedules
       SET starts_at = p_starts_at,
           ends_at = p_ends_at,
           capacity = p_capacity,
           remaining = v_remaining,
           status = v_new_status
     WHERE id = (p_schedule_id COLLATE utf8mb4_unicode_ci);

    IF v_adult_id IS NULL THEN
        INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
        VALUES (UUID(), p_schedule_id, 'adult', 12, NULL, p_adult_price_vnd, TRUE);
    ELSEIF NOT v_adult_active OR v_adult_price <> p_adult_price_vnd THEN
        UPDATE ticket_types SET price_vnd = p_adult_price_vnd, active = TRUE WHERE id = v_adult_id;
    END IF;

    IF p_child_price_vnd IS NULL THEN
        IF v_child_active THEN
            UPDATE ticket_types SET active = FALSE WHERE id = v_child_id;
        END IF;
    ELSEIF v_child_id IS NULL THEN
        INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
        VALUES (UUID(), p_schedule_id, 'child', 4, 11, p_child_price_vnd, TRUE);
    ELSEIF NOT v_child_active OR v_child_price <> p_child_price_vnd THEN
        UPDATE ticket_types SET price_vnd = p_child_price_vnd, active = TRUE WHERE id = v_child_id;
    END IF;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'schedule', p_schedule_id, 'schedule_update', v_old_status, v_new_status,
            IF(v_changes = '', NULL, LEFT(CONCAT('Sửa: ', v_changes), 255)), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_new_status AS status, v_held AS held, v_active AS active_bookings;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_log_list(p_tour_id)
--   Lịch sử thêm / sửa các lịch khởi hành của một tour, mới nhất trước, tối đa 100 dòng.
--   Cột: created_at, actor_name, action, from_status, to_status, note, schedule_id,
--   starts_at (giờ khởi hành hiện tại của lịch).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_log_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_log_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        l.created_at,
        u.name            AS actor_name,
        l.action,
        l.from_status,
        l.to_status,
        l.note,
        s.id              AS schedule_id,
        s.starts_at
    FROM admin_logs l
    JOIN schedules s ON s.id = l.target_id
    JOIN users u     ON u.id = l.actor_user_id
    WHERE l.target_type = 'schedule'
      AND s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY l.created_at DESC, l.id
    LIMIT 100;
END$$
DELIMITER ;
