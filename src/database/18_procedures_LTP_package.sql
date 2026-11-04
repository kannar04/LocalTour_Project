-- =====================================================================
-- LocalTour v0.4 - 18_procedures_LTP_package.sql
-- Mục đích  : Gói của tour (US06-S5-01, FR-07): khách xem và chọn gói khi đặt tour, quản trị
--             viên thêm / sửa / ngừng bán gói.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 5
-- Procedures: LTP_sp_tour_package_list, LTP_sp_admin_package_list, LTP_sp_admin_package_save
-- Quy tắc   : * Gói phân theo phương tiện hoặc tuyến điểm; lịch khởi hành, lịch trình chính và
--               phụ thu dùng chung với tour. Giá vé của gói áp dụng cho mọi lịch của tour.
--             * Tour có ít nhất một gói đang bán thì khách phải chọn gói khi đặt; giá vé lấy
--               theo gói (vé trẻ em chỉ bán khi gói có giá trẻ em và lịch có vé trẻ em).
--               Tour không có gói đang bán: giá vé theo lịch như trước.
--             * Gói không xóa được (đơn cũ giữ mã gói); ngừng bán = active FALSE.
--             * Đổi giá gói không đổi giá các đơn đã đặt (giá chụp lại ở booking_lines).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 16_migration_sprint5_LTP.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_tour_package_list(p_tour_id)
--   Các gói đang bán của một tour đang hiển thị (cùng điều kiện với trang chi tiết tour).
--   Cột: package_id, name, description, adult_price_vnd, child_price_vnd (NULL = không bán
--        vé trẻ em). Sắp xếp sort_order, giá người lớn, tên.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_tour_package_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_tour_package_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tp.id               AS package_id,
        tp.name,
        tp.description,
        tp.adult_price_vnd,
        tp.child_price_vnd
    FROM tour_packages tp
    JOIN tours     t ON t.id = tp.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND tp.active = TRUE
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY tp.sort_order, tp.adult_price_vnd, tp.name, tp.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_package_list(p_tour_id)
--   Mọi gói của tour (cả gói ngừng bán) cho trang quản trị.
--   Cột: package_id, name, description, adult_price_vnd, child_price_vnd, active,
--        sort_order, created_at, updated_at, booking_count (mọi đơn đã chọn gói),
--        active_booking_count (đơn pending / awaiting_payment / confirmed).
--   Sắp xếp: gói đang bán trước, rồi sort_order, tên.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_package_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_package_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tp.id               AS package_id,
        tp.name,
        tp.description,
        tp.adult_price_vnd,
        tp.child_price_vnd,
        tp.active,
        tp.sort_order,
        tp.created_at,
        tp.updated_at,
        (SELECT COUNT(*) FROM bookings b WHERE b.package_id = tp.id) AS booking_count,
        (SELECT COUNT(*) FROM bookings b
          WHERE b.package_id = tp.id
            AND b.status IN ('pending', 'awaiting_payment', 'confirmed')) AS active_booking_count
    FROM tour_packages tp
    WHERE tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY tp.active DESC, tp.sort_order, tp.name, tp.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_package_save(p_actor_user_id, p_tour_id, p_package_id, p_name,
--                           p_description, p_adult_price_vnd, p_child_price_vnd,
--                           p_active, p_sort_order)
--   p_package_id NULL / '' = thêm gói mới; ngược lại sửa gói đó (phải thuộc p_tour_id).
--   Giới hạn: tên 1 - 100 ký tự, không trùng tên gói khác của tour; mô tả tối đa 500 ký
--   tự (NULL / '' = không có); giá người lớn 1 - 100.000.000 đ; giá trẻ em NULL hoặc
--   1 - 100.000.000 đ; thứ tự 0 - 999.
--   Ghi admin_logs (target_type 'tour', target_id = mã tour, action 'package_create' /
--   'package_update', note = tên gói và nội dung thay đổi).
--   1 dòng: result, field, package_id.
--     result = 'ok'          : đã lưu.
--              'unchanged'   : sửa nhưng không có gì thay đổi.
--              'forbidden'   : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'   : không có tour, hoặc gói không thuộc tour này.
--              'invalid'     : dữ liệu sai; field = name, description, adult_price,
--                              child_price hoặc sort_order.
--              'duplicate'   : tour đã có gói khác cùng tên (field = name).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_package_save;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_package_save(
    IN p_actor_user_id   CHAR(36),
    IN p_tour_id         CHAR(36),
    IN p_package_id      CHAR(36),
    IN p_name            VARCHAR(255) CHARACTER SET utf8mb4,
    IN p_description     TEXT         CHARACTER SET utf8mb4,
    IN p_adult_price_vnd BIGINT,
    IN p_child_price_vnd BIGINT,
    IN p_active          BOOLEAN,
    IN p_sort_order      INT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_package_id  CHAR(36)     DEFAULT NULLIF(TRIM(p_package_id), '');
    DECLARE v_name        VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_name, ''));
    DECLARE v_description TEXT         CHARACTER SET utf8mb4;
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_found       INT          DEFAULT 0;
    DECLARE v_old_name    VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_desc    VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_adult   BIGINT       DEFAULT NULL;
    DECLARE v_old_child   BIGINT       DEFAULT NULL;
    DECLARE v_old_active  BOOLEAN      DEFAULT NULL;
    DECLARE v_old_sort    INT          DEFAULT NULL;
    DECLARE v_changes     VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_description = NULLIF(TRIM(p_description), '');

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS package_id;
        LEAVE proc;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)) THEN
        SELECT 'not_found' AS result, NULL AS field, NULL AS package_id;
        LEAVE proc;
    END IF;

    IF v_name = '' OR CHAR_LENGTH(v_name) > 100 THEN
        SET v_field = 'name';
    ELSEIF v_description IS NOT NULL AND CHAR_LENGTH(v_description) > 500 THEN
        SET v_field = 'description';
    ELSEIF p_adult_price_vnd IS NULL OR p_adult_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'adult_price';
    ELSEIF p_child_price_vnd IS NOT NULL AND p_child_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'child_price';
    ELSEIF p_sort_order IS NULL OR p_sort_order NOT BETWEEN 0 AND 999 THEN
        SET v_field = 'sort_order';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF v_package_id IS NOT NULL THEN
        SELECT COUNT(*), MAX(tp.name), MAX(tp.description), MAX(tp.adult_price_vnd), MAX(tp.child_price_vnd),
               MAX(tp.active), MAX(tp.sort_order)
          INTO v_found, v_old_name, v_old_desc, v_old_adult, v_old_child, v_old_active, v_old_sort
          FROM tour_packages tp
         WHERE tp.id = (v_package_id COLLATE utf8mb4_unicode_ci)
           AND tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
           FOR UPDATE;
        IF v_found = 0 THEN
            ROLLBACK;
            SELECT 'not_found' AS result, NULL AS field, v_package_id AS package_id;
            LEAVE proc;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM tour_packages tp
                WHERE tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                  AND tp.name = (v_name COLLATE utf8mb4_unicode_ci)
                  AND NOT (tp.id <=> (v_package_id COLLATE utf8mb4_unicode_ci))) THEN
        ROLLBACK;
        SELECT 'duplicate' AS result, 'name' AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    IF v_package_id IS NULL THEN
        SET v_package_id = UUID();
        INSERT INTO tour_packages (id, tour_id, name, description, adult_price_vnd, child_price_vnd,
                                   active, sort_order, created_at)
        VALUES (v_package_id, p_tour_id, v_name, v_description, p_adult_price_vnd, p_child_price_vnd,
                COALESCE(p_active, TRUE), p_sort_order, NOW());

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'package_create', NULL,
                IF(COALESCE(p_active, TRUE), 'active', 'inactive'),
                LEFT(CONCAT('Thêm gói "', v_name, '", người lớn ',
                            REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ',
                            IF(p_child_price_vnd IS NULL, '',
                               CONCAT(', trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ'))), 255),
                NOW());

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    SET v_changes = CONCAT_WS(', ',
        IF(BINARY v_old_name <> BINARY v_name,
           CONCAT('tên "', v_old_name, '" → "', v_name, '"'), NULL),
        IF(NOT (v_old_desc <=> v_description), 'mô tả', NULL),
        IF(v_old_adult <> p_adult_price_vnd,
           CONCAT('người lớn ', REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ'), NULL),
        IF(NOT (v_old_child <=> p_child_price_vnd),
           IF(p_child_price_vnd IS NULL, 'ngừng bán vé trẻ em',
              CONCAT('trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ')), NULL),
        IF(v_old_sort <> p_sort_order, CONCAT('thứ tự ', p_sort_order), NULL),
        IF(v_old_active <> COALESCE(p_active, TRUE),
           IF(COALESCE(p_active, TRUE), 'mở bán lại', 'ngừng bán'), NULL));

    IF v_changes = '' THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    UPDATE tour_packages
       SET name = v_name,
           description = v_description,
           adult_price_vnd = p_adult_price_vnd,
           child_price_vnd = p_child_price_vnd,
           active = COALESCE(p_active, TRUE),
           sort_order = p_sort_order,
           updated_at = NOW()
     WHERE id = (v_package_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'package_update',
            IF(v_old_active, 'active', 'inactive'), IF(COALESCE(p_active, TRUE), 'active', 'inactive'),
            LEFT(CONCAT('Gói "', v_name, '": ', v_changes), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_package_id AS package_id;
END$$
DELIMITER ;
