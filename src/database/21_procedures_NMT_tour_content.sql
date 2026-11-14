-- =====================================================================
-- LocalTour v0.4 - 21_procedures_NMT_tour_content.sql
-- Mục đích  : Hoàn thiện quản trị tour (US07-S5-01, FR-13): các phần trước đây chỉ thêm được
--             bằng SQL nay quản lý ở trang quản trị: ảnh, lịch trình, dịch vụ bao gồm / không
--             bao gồm, chính sách hủy (phiên bản mới); xóa tour và xóa đơn vị tổ chức chưa có tour.
-- Phụ trách : Nguyễn Minh Thức (NMT) - Sprint 5
-- Procedures: NMT_sp_admin_image_list, NMT_sp_admin_image_add, NMT_sp_admin_image_delete,
--             NMT_sp_admin_image_set_cover,
--             NMT_sp_admin_itinerary_list, NMT_sp_admin_itinerary_save, NMT_sp_admin_itinerary_delete,
--             NMT_sp_admin_inclusion_list, NMT_sp_admin_inclusion_add, NMT_sp_admin_inclusion_delete,
--             NMT_sp_admin_policy_list, NMT_sp_admin_policy_add,
--             NMT_sp_admin_tour_delete, NMT_sp_admin_tour_restore,
--             NMT_sp_admin_provider_delete
-- Quy tắc   : * Mọi thao tác ghi kiểm tra người thao tác là quản trị viên đang hoạt động và ghi
--               admin_logs (target_type 'tour', target_id = mã tour).
--             * Sprint 6: ảnh, lịch trình, dịch vụ và chính sách hủy còn nhận người thao tác là
--               đơn vị tổ chức đang hợp tác, chỉ trên tour của chính đơn vị
--               (NTK_sp_host_can_edit_tour, file 27) và chỉ khi tour đang 'draft' / 'rejected'.
--               Đơn vị sửa nội dung tour bị từ chối thì tour quay về 'draft'
--               (NTK_sp_host_tour_resubmit); tour đã duyệt sửa qua "bản sửa" (file 32). Xóa / khôi
--               phục tour và xóa đơn vị vẫn chỉ dành cho quản trị viên.
--             * Chỉ sửa dữ liệu của đúng tour (mã mục phải thuộc tour đó): không ảnh hưởng tour khác.
--             * Ảnh: tối đa 12 ảnh / tour; ảnh bìa = ảnh có sort_order nhỏ nhất. File ảnh do ứng
--               dụng lưu (public/assets/uploads/tours); xóa ảnh trả url để ứng dụng xóa file.
--             * Chính sách hủy không sửa phiên bản cũ (đơn đã đặt giữ phiên bản lúc đặt): lưu
--               chính sách mới = thêm phiên bản mới (version + 1).
--             * Xóa tour: tour chưa có đơn nào thì xóa hẳn cùng mọi dữ liệu con; tour đã có
--               đơn thì chuyển 'archived' (ngừng hiển thị, đơn cũ giữ nguyên). Không xóa / ngừng
--               hiển thị khi còn đơn đang xử lý (pending / awaiting_payment / confirmed).
--               Khôi phục tour ngừng hiển thị: về 'pending' để duyệt lại.
--             * Xóa đơn vị tổ chức: chỉ khi đơn vị chưa có tour nào; còn tour thì chuyển
--               "Ngừng hợp tác" để ẩn tour (admin_logs target_type 'provider').
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 16_migration_sprint5_LTP.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- =====================================================================
-- Ảnh tour
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_list(p_tour_id)
--   Cột: image_id, url, alt_text, sort_order, is_cover (1 = ảnh bìa). Sắp xếp sort_order.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        ti.id          AS image_id,
        ti.url,
        ti.alt_text,
        ti.sort_order,
        (ti.id = (SELECT c.id FROM tour_images c
                   WHERE c.tour_id = ti.tour_id
                   ORDER BY c.sort_order, c.id LIMIT 1)) AS is_cover
    FROM tour_images ti
    WHERE ti.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY ti.sort_order, ti.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_add(p_actor_user_id, p_tour_id, p_url, p_alt_text)
--   Thêm ảnh cuối danh sách (sort_order = lớn nhất + 1). p_url: đường dẫn ứng dụng đã lưu
--   (vd. 'uploads/tours/<tên file>'), tối đa 255 ký tự; p_alt_text tối đa 255 ký tự.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid', 'limit'), field, image_id.
--     'limit' = tour đã có 12 ảnh.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_add;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_add(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_url           VARCHAR(500) CHARACTER SET utf8mb4,
    IN p_alt_text      VARCHAR(500) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_url      VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_url), '');
    DECLARE v_alt      VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_alt_text), '');
    DECLARE v_count    INT      DEFAULT 0;
    DECLARE v_sort     INT      DEFAULT 0;
    DECLARE v_image_id CHAR(36) DEFAULT UUID();
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result, NULL AS field, NULL AS image_id;
            LEAVE proc;
        END IF;
    END IF;

    IF v_url IS NULL OR CHAR_LENGTH(v_url) > 255 THEN
        SELECT 'invalid' AS result, 'image' AS field, NULL AS image_id;
        LEAVE proc;
    END IF;
    IF v_alt IS NOT NULL AND CHAR_LENGTH(v_alt) > 255 THEN
        SELECT 'invalid' AS result, 'alt_text' AS field, NULL AS image_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa dòng tour: hai lần thêm ảnh cùng lúc không vượt giới hạn.
    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS image_id;
        LEAVE proc;
    END IF;

    SELECT COUNT(*), COALESCE(MAX(sort_order), 0) INTO v_count, v_sort
      FROM tour_images
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    IF v_count >= 12 THEN
        ROLLBACK;
        SELECT 'limit' AS result, 'image' AS field, NULL AS image_id;
        LEAVE proc;
    END IF;

    INSERT INTO tour_images (id, tour_id, url, alt_text, sort_order)
    VALUES (v_image_id, p_tour_id, v_url, v_alt, v_sort + 1);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'image_add', NULL, NULL,
            LEFT(CONCAT('Thêm ảnh', IF(v_alt IS NULL, '', CONCAT(' "', v_alt, '"'))), 255), NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_image_id AS image_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_delete(p_actor_user_id, p_tour_id, p_image_id)
--   1 dòng: result ('ok', 'forbidden', 'not_found'), url (đường dẫn ảnh vừa xóa).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_image_id      CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_url VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_alt VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result, NULL AS url;
            LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;

    SELECT url, alt_text INTO v_url, v_alt
      FROM tour_images
     WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_url IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS url;
        LEAVE proc;
    END IF;

    DELETE FROM tour_images WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'image_delete', NULL, NULL,
            LEFT(CONCAT('Xóa ảnh', IF(v_alt IS NULL, '', CONCAT(' "', v_alt, '"'))), 255), NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_url AS url;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_set_cover(p_actor_user_id, p_tour_id, p_image_id)
--   Đưa ảnh lên đầu danh sách (sort_order = nhỏ nhất - 1) để làm ảnh bìa.
--   1 dòng: result ('ok', 'unchanged', 'forbidden', 'not_found').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_set_cover;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_set_cover(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_image_id      CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_found INT      DEFAULT 0;
    DECLARE v_cover CHAR(36) DEFAULT NULL;
    DECLARE v_min   INT      DEFAULT 0;
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result;
            LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_found
      FROM tour_images
     WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_found = 0 THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    SELECT id, sort_order INTO v_cover, v_min
      FROM tour_images
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY sort_order, id
     LIMIT 1;

    IF v_cover = (p_image_id COLLATE utf8mb4_unicode_ci) THEN
        ROLLBACK;
        SELECT 'unchanged' AS result;
        LEAVE proc;
    END IF;

    UPDATE tour_images SET sort_order = v_min - 1 WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'image_cover', NULL, NULL, 'Đổi ảnh bìa', NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- =====================================================================
-- Lịch trình
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_itinerary_list(p_tour_id)
--   Cột: item_id, start_time, description, sort_order. Sắp xếp như trang chi tiết tour.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_itinerary_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_itinerary_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT it.id AS item_id, it.start_time, it.description, it.sort_order
      FROM tour_itinerary_items it
     WHERE it.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY it.sort_order, it.start_time, it.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_itinerary_save(p_actor_user_id, p_tour_id, p_item_id, p_start_time,
--                             p_description, p_sort_order)
--   p_item_id NULL / '' = thêm mục mới; ngược lại sửa mục đó (phải thuộc tour).
--   p_start_time NULL = mục không ghi giờ. Mô tả 1 - 255 ký tự; thứ tự 0 - 999.
--   Tối đa 30 mục / tour.
--   1 dòng: result ('ok', 'unchanged', 'forbidden', 'not_found', 'invalid', 'limit'),
--           field (description, sort_order), item_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_itinerary_save;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_itinerary_save(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_item_id       CHAR(36),
    IN p_start_time    TIME,
    IN p_description   VARCHAR(500) CHARACTER SET utf8mb4,
    IN p_sort_order    INT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_item_id  CHAR(36)     DEFAULT NULLIF(TRIM(p_item_id), '');
    DECLARE v_desc     VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_description, ''));
    DECLARE v_found    INT          DEFAULT 0;
    DECLARE v_count    INT          DEFAULT 0;
    DECLARE v_old_time TIME         DEFAULT NULL;
    DECLARE v_old_desc VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_sort INT          DEFAULT NULL;
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result, NULL AS field, NULL AS item_id;
            LEAVE proc;
        END IF;
    END IF;

    IF v_desc = '' OR CHAR_LENGTH(v_desc) > 255 THEN
        SELECT 'invalid' AS result, 'description' AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;
    IF p_sort_order IS NULL OR p_sort_order NOT BETWEEN 0 AND 999 THEN
        SELECT 'invalid' AS result, 'sort_order' AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS item_id;
        LEAVE proc;
    END IF;

    IF v_item_id IS NULL THEN
        SELECT COUNT(*) INTO v_count
          FROM tour_itinerary_items
         WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
        IF v_count >= 30 THEN
            ROLLBACK;
            SELECT 'limit' AS result, NULL AS field, NULL AS item_id;
            LEAVE proc;
        END IF;

        SET v_item_id = UUID();
        INSERT INTO tour_itinerary_items (id, tour_id, start_time, description, sort_order)
        VALUES (v_item_id, p_tour_id, p_start_time, v_desc, p_sort_order);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'itinerary_add', NULL, NULL,
                LEFT(CONCAT('Thêm lịch trình: ', IF(p_start_time IS NULL, '', CONCAT(TIME_FORMAT(p_start_time, '%H:%i'), ' ')), v_desc), 255),
                NOW());

        -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
        IF v_host THEN
            CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
        END IF;

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    SELECT COUNT(*), MAX(start_time), MAX(description), MAX(sort_order)
      INTO v_found, v_old_time, v_old_desc, v_old_sort
      FROM tour_itinerary_items
     WHERE id = (v_item_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_found = 0 THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    IF (v_old_time <=> p_start_time) AND BINARY v_old_desc = BINARY v_desc AND v_old_sort = p_sort_order THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    UPDATE tour_itinerary_items
       SET start_time = p_start_time, description = v_desc, sort_order = p_sort_order
     WHERE id = (v_item_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'itinerary_update', NULL, NULL,
            LEFT(CONCAT('Sửa lịch trình: ', IF(p_start_time IS NULL, '', CONCAT(TIME_FORMAT(p_start_time, '%H:%i'), ' ')), v_desc), 255),
            NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_item_id AS item_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_itinerary_delete(p_actor_user_id, p_tour_id, p_item_id)
--   1 dòng: result ('ok', 'forbidden', 'not_found').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_itinerary_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_itinerary_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_item_id       CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_desc VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result;
            LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;

    SELECT description INTO v_desc
      FROM tour_itinerary_items
     WHERE id = (p_item_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_desc IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    DELETE FROM tour_itinerary_items WHERE id = (p_item_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'itinerary_delete', NULL, NULL,
            LEFT(CONCAT('Xóa lịch trình: ', v_desc), 255), NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- =====================================================================
-- Dịch vụ bao gồm / không bao gồm
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_inclusion_list(p_tour_id)
--   Cột: inclusion_id, item_text, is_included, sort_order. Bao gồm trước, rồi sort_order.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_inclusion_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_inclusion_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT i.id AS inclusion_id, i.item_text, i.is_included, i.sort_order
      FROM tour_inclusions i
     WHERE i.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY i.is_included DESC, i.sort_order, i.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_inclusion_add(p_actor_user_id, p_tour_id, p_item_text, p_is_included)
--   Thêm cuối nhóm (bao gồm / không bao gồm). Nội dung 1 - 150 ký tự, tối đa 40 mục / tour.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid', 'limit'), field, inclusion_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_inclusion_add;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_inclusion_add(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_item_text     VARCHAR(500) CHARACTER SET utf8mb4,
    IN p_is_included   BOOLEAN
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_text  VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_item_text, ''));
    DECLARE v_inc   BOOLEAN  DEFAULT COALESCE(p_is_included, TRUE);
    DECLARE v_count INT      DEFAULT 0;
    DECLARE v_sort  INT      DEFAULT 0;
    DECLARE v_id    CHAR(36) DEFAULT UUID();
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result, NULL AS field, NULL AS inclusion_id;
            LEAVE proc;
        END IF;
    END IF;

    IF v_text = '' OR CHAR_LENGTH(v_text) > 150 THEN
        SELECT 'invalid' AS result, 'item_text' AS field, NULL AS inclusion_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS inclusion_id;
        LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM tour_inclusions
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    IF v_count >= 40 THEN
        ROLLBACK;
        SELECT 'limit' AS result, NULL AS field, NULL AS inclusion_id;
        LEAVE proc;
    END IF;

    SELECT COALESCE(MAX(sort_order), 0) INTO v_sort
      FROM tour_inclusions
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci) AND is_included = v_inc;

    INSERT INTO tour_inclusions (id, tour_id, item_text, is_included, sort_order)
    VALUES (v_id, p_tour_id, v_text, v_inc, v_sort + 1);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'inclusion_add', NULL, NULL,
            LEFT(CONCAT(IF(v_inc, 'Thêm mục bao gồm: ', 'Thêm mục không bao gồm: '), v_text), 255), NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_id AS inclusion_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_inclusion_delete(p_actor_user_id, p_tour_id, p_inclusion_id)
--   1 dòng: result ('ok', 'forbidden', 'not_found').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_inclusion_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_inclusion_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_inclusion_id  CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_text VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result;
            LEAVE proc;
        END IF;
    END IF;

    START TRANSACTION;

    SELECT item_text INTO v_text
      FROM tour_inclusions
     WHERE id = (p_inclusion_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_text IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    DELETE FROM tour_inclusions WHERE id = (p_inclusion_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'inclusion_delete', NULL, NULL,
            LEFT(CONCAT('Xóa mục: ', v_text), 255), NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- =====================================================================
-- Chính sách hủy
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_policy_list(p_tour_id)
--   Mọi phiên bản chính sách hủy, mới nhất trước.
--   Cột: policy_id, version, free_before_hours, refund_percent, terms, booking_count (số đơn
--        đặt theo phiên bản này).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_policy_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_policy_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        cp.id                AS policy_id,
        cp.version,
        cp.free_before_hours,
        cp.refund_percent,
        cp.terms,
        (SELECT COUNT(*) FROM bookings b
           JOIN schedules s ON s.id = b.schedule_id
          WHERE s.tour_id = cp.tour_id AND b.policy_version = cp.version) AS booking_count
    FROM cancellation_policies cp
    WHERE cp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY cp.version DESC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_policy_add(p_actor_user_id, p_tour_id, p_free_before_hours, p_refund_percent,
--                         p_terms)
--   Thêm phiên bản mới (version = lớn nhất + 1). Đơn đặt sau đó dùng phiên bản mới; đơn cũ
--   giữ phiên bản lúc đặt.
--   p_free_before_hours: NULL = không có mốc hủy miễn phí; 0 - 720 giờ.
--   p_refund_percent   : 0 - 100 (% hoàn khi hủy sau mốc miễn phí, hoặc luôn áp dụng khi không
--                        có mốc). p_terms: 1 - 2000 ký tự.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid', 'unchanged'), field, version.
--     'unchanged' = giống hệt phiên bản mới nhất.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_policy_add;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_policy_add(
    IN p_actor_user_id     CHAR(36),
    IN p_tour_id           CHAR(36),
    IN p_free_before_hours INT,
    IN p_refund_percent    INT,
    IN p_terms             TEXT CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_terms     TEXT     CHARACTER SET utf8mb4;
    DECLARE v_version   INT      DEFAULT 0;
    DECLARE v_old_hours INT      DEFAULT NULL;
    DECLARE v_old_pct   INT      DEFAULT NULL;
    DECLARE v_old_terms TEXT     CHARACTER SET utf8mb4;
    DECLARE v_host BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_terms = TRIM(COALESCE(p_terms, ''));

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        -- Không phải quản trị viên: chỉ nhận đơn vị tổ chức đang hợp tác thao tác trên tour của mình (file 27).
        CALL NTK_sp_host_can_edit_tour(p_actor_user_id, p_tour_id, v_host);
        IF NOT COALESCE(v_host, FALSE) THEN
            SELECT 'forbidden' AS result, NULL AS field, NULL AS version;
            LEAVE proc;
        END IF;
    END IF;

    IF p_free_before_hours IS NOT NULL AND p_free_before_hours NOT BETWEEN 0 AND 720 THEN
        SELECT 'invalid' AS result, 'free_before_hours' AS field, NULL AS version;
        LEAVE proc;
    END IF;
    IF p_refund_percent IS NULL OR p_refund_percent NOT BETWEEN 0 AND 100 THEN
        SELECT 'invalid' AS result, 'refund_percent' AS field, NULL AS version;
        LEAVE proc;
    END IF;
    IF v_terms = '' OR CHAR_LENGTH(v_terms) > 2000 THEN
        SELECT 'invalid' AS result, 'terms' AS field, NULL AS version;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS version;
        LEAVE proc;
    END IF;

    SELECT cp.version, cp.free_before_hours, cp.refund_percent, cp.terms
      INTO v_version, v_old_hours, v_old_pct, v_old_terms
      FROM cancellation_policies cp
     WHERE cp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY cp.version DESC
     LIMIT 1;

    IF v_version > 0 AND (v_old_hours <=> p_free_before_hours) AND v_old_pct = p_refund_percent
       AND BINARY v_old_terms = BINARY v_terms THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_version AS version;
        LEAVE proc;
    END IF;

    SET v_version = COALESCE(v_version, 0) + 1;
    INSERT INTO cancellation_policies (id, tour_id, free_before_hours, refund_percent, terms, version)
    VALUES (UUID(), p_tour_id, p_free_before_hours, p_refund_percent, v_terms, v_version);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'policy_add', NULL, NULL,
            LEFT(CONCAT('Chính sách hủy phiên bản ', v_version, ': ',
                        IF(p_free_before_hours IS NULL, 'không có mốc hủy miễn phí',
                           CONCAT('hủy miễn phí trước ', p_free_before_hours, ' giờ')),
                        ', hoàn ', p_refund_percent, '%'), 255), NOW());

    -- Đơn vị tổ chức sửa tour bị từ chối: tour quay về "Bản nháp" (file 27).
    IF v_host THEN
        CALL NTK_sp_host_tour_resubmit(p_actor_user_id, p_tour_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_version AS version;
END$$
DELIMITER ;

-- =====================================================================
-- Xóa / ngừng hiển thị / khôi phục tour
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_delete(p_actor_user_id, p_tour_id)
--   Tour chưa có đơn: xóa hẳn tour và dữ liệu con (ảnh, lịch trình, bao gồm, phụ thu, chính
--   sách hủy, gói, lịch khởi hành và giá vé, bài viết, yêu thích, so sánh). admin_logs giữ lại
--   (action 'tour_delete', note = tên tour).
--   Tour đã có đơn: chuyển 'archived' (action 'tour_archive').
--   1 dòng: result, title, active_bookings.
--     result = 'deleted' | 'archived'
--              'forbidden'       : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'       : không có tour này.
--              'already_archived': tour đã ngừng hiển thị.
--              'has_bookings'    : còn đơn pending / awaiting_payment / confirmed
--                                  (active_bookings = số đơn đó).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_title    VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_bookings INT          DEFAULT 0;
    DECLARE v_active   INT          DEFAULT 0;
    DECLARE v_locked   INT          DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS title, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT title, approval_status INTO v_title, v_status
      FROM tours
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_title IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS title, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    IF v_status = 'archived' THEN
        ROLLBACK;
        SELECT 'already_archived' AS result, v_title AS title, 0 AS active_bookings;
        LEAVE proc;
    END IF;

    -- Khóa các lịch của tour: không có đơn mới được tạo trong lúc kiểm tra.
    SELECT COUNT(*) INTO v_locked
      FROM schedules s
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    SELECT COUNT(*), COALESCE(SUM(b.status IN ('pending', 'awaiting_payment', 'confirmed')), 0)
      INTO v_bookings, v_active
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    IF v_active > 0 THEN
        ROLLBACK;
        SELECT 'has_bookings' AS result, v_title AS title, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    IF v_bookings > 0 THEN
        UPDATE tours SET approval_status = 'archived' WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_archive', v_status, 'archived',
                LEFT(CONCAT('Ngừng hiển thị (tour đã có ', v_bookings, ' đơn)'), 255), NOW());

        COMMIT;
        SELECT 'archived' AS result, v_title AS title, 0 AS active_bookings;
        LEAVE proc;
    END IF;

    DELETE tt FROM ticket_types tt
      JOIN schedules s ON s.id = tt.schedule_id
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM schedules            WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_schedules       WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_images          WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM itinerary_stops      WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_itinerary_items WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_inclusions      WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_extras          WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM cancellation_policies WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_packages        WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_posts           WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM favorite_tours       WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM comparison_tours     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    -- Sprint 6 (NTK, file 32): tour còn "bản sửa" đang mở thì xóa bản sửa trước (khóa ngoại tours.revision_of).
    CALL NTK_sp_tour_revision_purge_of(p_tour_id);
    DELETE FROM tours                WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_delete', v_status, NULL,
            LEFT(CONCAT('Xóa tour "', v_title, '"'), 255), NOW());

    COMMIT;
    SELECT 'deleted' AS result, v_title AS title, 0 AS active_bookings;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_restore(p_actor_user_id, p_tour_id)
--   Tour 'archived' -> 'pending' (chờ duyệt lại ở trang Duyệt tour). Ghi 'tour_restore'.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid_transition').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_restore;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_restore(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT approval_status INTO v_status
      FROM tours
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    IF v_status <> 'archived' THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result;
        LEAVE proc;
    END IF;

    UPDATE tours SET approval_status = 'pending' WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_restore', 'archived', 'pending',
            'Hiển thị lại: chờ duyệt', NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;


-- =====================================================================
-- Xóa đơn vị tổ chức
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_delete(p_actor_user_id, p_provider_id)
--   Chỉ xóa được đơn vị chưa có tour nào (kể cả tour chờ duyệt / ngừng hiển thị): xóa dòng
--   providers và tài khoản 'provider' không đăng nhập đi kèm. Tài khoản còn được bảng khác dùng
--   thì giữ lại ở trạng thái 'locked'. admin_logs giữ lại (action 'provider_delete').
--   Đơn vị còn tour: không xóa; muốn ẩn tour của đơn vị thì chuyển "Ngừng hợp tác" ('rejected').
--   1 dòng: result, business_name, tour_count.
--     result = 'deleted'
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found' : không có đơn vị này.
--              'has_tours' : đơn vị còn tour (tour_count = số tour).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_delete(
    IN p_actor_user_id CHAR(36),
    IN p_provider_id   CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_name      VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_status    VARCHAR(20)  DEFAULT NULL;
    DECLARE v_user_id   CHAR(36)     DEFAULT NULL;
    DECLARE v_tours     INT          DEFAULT 0;
    DECLARE v_user_used BOOLEAN      DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- Tài khoản đi kèm còn được bảng khác tham chiếu (khóa ngoại RESTRICT): giữ lại, khóa tài khoản.
    DECLARE CONTINUE HANDLER FOR 1451 SET v_user_used = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS business_name, NULL AS tour_count;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT business_name, approval_status, user_id INTO v_name, v_status, v_user_id
      FROM providers
     WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_name IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS business_name, NULL AS tour_count;
        LEAVE proc;
    END IF;

    -- Khóa các tour của đơn vị: không có tour mới được thêm trong lúc kiểm tra.
    SELECT COUNT(*) INTO v_tours
      FROM tours
     WHERE provider_id = (p_provider_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_tours > 0 THEN
        ROLLBACK;
        SELECT 'has_tours' AS result, v_name AS business_name, v_tours AS tour_count;
        LEAVE proc;
    END IF;

    DELETE FROM providers WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM users WHERE id = v_user_id AND role = 'provider';
    IF v_user_used THEN
        UPDATE users SET status = 'locked' WHERE id = v_user_id AND role = 'provider';
    END IF;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'provider', p_provider_id, 'provider_delete', v_status, NULL,
            LEFT(CONCAT('Xóa đơn vị "', v_name, '"'), 255), NOW());

    COMMIT;
    SELECT 'deleted' AS result, v_name AS business_name, 0 AS tour_count;
END$$
DELIMITER ;
