-- =====================================================================
-- LocalTour v0.7 - 35_procedures_NMT_comment.sql
-- Mục đích  : Bình luận trên trang tour (CR3): khách xem bình luận, tài khoản khách hàng viết và
--             tự xóa bình luận của mình; quản trị viên ẩn / hiện lại bình luận (trang "Bình luận").
-- Phụ trách : Nguyễn Minh Thức (NMT)
-- Procedures: NMT_sp_tour_comment_list, NMT_sp_tour_comment_count, NMT_sp_tour_comment_create,
--             NMT_sp_tour_comment_delete_own, NMT_sp_admin_comment_list,
--             NMT_sp_admin_comment_set_status
-- Quy tắc   : Bảng tour_comments (33_migration_cr3_NTK.sql).
--             Tour đang hiển thị = tours.approval_status = 'approved' VÀ providers.approval_status =
--             'approved' VÀ users.status = 'active' (tài khoản của nhà cung cấp), như trang chi tiết
--             tour (file 04). Tour khác hoặc không tồn tại: không đọc / viết bình luận được.
--             Công khai chỉ hiện bình luận status = 'visible'; 'hidden' = quản trị viên đã ẩn.
--             Chỉ tài khoản khách hàng (role = 'customer') đang hoạt động mới viết bình luận.
--             Nội dung 1–1000 ký tự (sau khi bỏ khoảng trắng đầu / cuối; controller đã bỏ ký tự
--             điều khiển, trừ xuống dòng). Mỗi tài khoản tối đa 5 bình luận trong 10 phút.
--             Người viết tự xóa bình luận của mình = xóa hẳn dòng.
--             Ẩn / hiện lại ghi admin_logs (target_type 'tour_comment', action 'comment_hide' /
--             'comment_show'), lý do ẩn bắt buộc, tối đa 255 ký tự.
--             UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
-- Chạy sau  : 01 -> 33. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_comment_list(p_tour_id, p_viewer_id, p_limit, p_offset)
--   Bình luận đang hiển thị của tour đang hiển thị, mới nhất trước (created_at, rồi id).
--   p_viewer_id: tài khoản đang xem (NULL = khách chưa đăng nhập) để đánh dấu is_mine.
--   p_limit NULL hoặc 0 = 10, tối đa 50. p_offset NULL = 0.
--   Cột: comment_id, user_name, avatar_url (users.avatar_url, NULL = chưa có ảnh), content,
--        created_at, is_mine (1 = bình luận của p_viewer_id).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_comment_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_comment_list(
    IN p_tour_id   CHAR(36),
    IN p_viewer_id CHAR(36),
    IN p_limit     TINYINT UNSIGNED,
    IN p_offset    INT UNSIGNED
)
READS SQL DATA
BEGIN
    DECLARE v_limit  INT UNSIGNED DEFAULT 10;
    DECLARE v_offset INT UNSIGNED DEFAULT COALESCE(p_offset, 0);

    IF p_limit IS NOT NULL AND p_limit > 0 THEN
        SET v_limit = LEAST(p_limit, 50);
    END IF;

    SELECT
        c.id          AS comment_id,
        cu.name       AS user_name,
        cu.avatar_url,
        c.content,
        c.created_at,
        IF(p_viewer_id IS NOT NULL AND c.user_id = (p_viewer_id COLLATE utf8mb4_unicode_ci), 1, 0) AS is_mine
    FROM tour_comments c
    JOIN users     cu ON cu.id = c.user_id         -- người viết
    JOIN tours     t  ON t.id  = c.tour_id
    JOIN providers p  ON p.id  = t.provider_id
    JOIN users     u  ON u.id  = p.user_id         -- tài khoản của nhà cung cấp
    WHERE c.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND c.status = 'visible'
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY c.created_at DESC, c.id DESC
    LIMIT v_limit OFFSET v_offset;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_comment_count(p_tour_id)
--   Luôn 1 dòng. Cột: tour_visible (1 = tour đang hiển thị), total_count (số bình luận đang
--   hiển thị; 0 khi tour không hiển thị).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_comment_count;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_comment_count(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    DECLARE v_visible TINYINT DEFAULT 0;

    SELECT COUNT(*) INTO v_visible
      FROM tours t
      JOIN providers p ON p.id = t.provider_id
      JOIN users     u ON u.id = p.user_id
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       AND t.approval_status = 'approved'
       AND p.approval_status = 'approved'
       AND u.status = 'active';

    SELECT
        v_visible AS tour_visible,
        IF(v_visible = 1,
           (SELECT COUNT(*) FROM tour_comments c
             WHERE c.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
               AND c.status = 'visible'),
           0) AS total_count;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_comment_create(p_user_id, p_tour_id, p_content)
--   Tài khoản khách hàng viết bình luận. 1 dòng: result, rồi các cột của bình luận mới
--   (chỉ có giá trị khi result = 'ok'): comment_id, user_name, avatar_url, content, created_at,
--   is_mine (= 1), total_count (số bình luận đang hiển thị của tour sau khi thêm).
--     result = 'ok'           : đã thêm.
--              'forbidden'    : không phải tài khoản khách hàng đang hoạt động.
--              'not_found'    : tour không tồn tại hoặc không hiển thị.
--              'invalid'      : nội dung rỗng hoặc quá 1000 ký tự.
--              'rate_limited' : đã viết 5 bình luận trong 10 phút gần nhất.
--   Khóa dòng users của người viết (FOR UPDATE) để hai lần gửi cùng lúc không vượt giới hạn.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_comment_create;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_comment_create(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36),
    IN p_content TEXT CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_content TEXT CHARACTER SET utf8mb4 DEFAULT TRIM(p_content);
    DECLARE v_role    VARCHAR(20) DEFAULT NULL;
    DECLARE v_recent  INT DEFAULT 0;
    DECLARE v_id      CHAR(36) DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF v_content IS NULL OR CHAR_LENGTH(v_content) = 0 OR CHAR_LENGTH(v_content) > 1000
       OR v_content REGEXP '^[[:space:]]*$' THEN
        SELECT 'invalid' AS result, NULL AS comment_id, NULL AS user_name, NULL AS avatar_url,
               NULL AS content, NULL AS created_at, 0 AS is_mine, NULL AS total_count;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT role INTO v_role
      FROM users
     WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND status = 'active'
       FOR UPDATE;

    IF v_role IS NULL OR v_role <> 'customer' THEN
        ROLLBACK;
        SELECT 'forbidden' AS result, NULL AS comment_id, NULL AS user_name, NULL AS avatar_url,
               NULL AS content, NULL AS created_at, 0 AS is_mine, NULL AS total_count;
        LEAVE proc;
    END IF;

    IF NOT EXISTS (SELECT 1
                     FROM tours t
                     JOIN providers p ON p.id = t.provider_id
                     JOIN users     u ON u.id = p.user_id
                    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                      AND t.approval_status = 'approved'
                      AND p.approval_status = 'approved'
                      AND u.status = 'active') THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS comment_id, NULL AS user_name, NULL AS avatar_url,
               NULL AS content, NULL AS created_at, 0 AS is_mine, NULL AS total_count;
        LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_recent
      FROM tour_comments
     WHERE user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND created_at > NOW() - INTERVAL 10 MINUTE;

    IF v_recent >= 5 THEN
        ROLLBACK;
        SELECT 'rate_limited' AS result, NULL AS comment_id, NULL AS user_name, NULL AS avatar_url,
               NULL AS content, NULL AS created_at, 0 AS is_mine, NULL AS total_count;
        LEAVE proc;
    END IF;

    INSERT INTO tour_comments (id, tour_id, user_id, content, status, created_at)
    VALUES (v_id, p_tour_id, p_user_id, v_content, 'visible', NOW());

    COMMIT;

    SELECT
        'ok'         AS result,
        c.id         AS comment_id,
        cu.name      AS user_name,
        cu.avatar_url,
        c.content,
        c.created_at,
        1            AS is_mine,
        (SELECT COUNT(*) FROM tour_comments x
          WHERE x.tour_id = c.tour_id AND x.status = 'visible') AS total_count
    FROM tour_comments c
    JOIN users cu ON cu.id = c.user_id
    WHERE c.id = v_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_comment_delete_own(p_comment_id, p_user_id)
--   Người viết xóa bình luận của mình (xóa hẳn dòng; bình luận đã bị ẩn cũng xóa được).
--   1 dòng: affected_count (1 = đã xóa; 0 = không có bình luận này hoặc không phải của
--   p_user_id), tour_id (NULL khi không xóa), total_count (số bình luận đang hiển thị của tour
--   sau khi xóa; NULL khi không xóa).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_comment_delete_own;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_comment_delete_own(
    IN p_comment_id CHAR(36),
    IN p_user_id    CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_tour_id  CHAR(36) DEFAULT NULL;
    DECLARE v_affected INT DEFAULT 0;

    SELECT tour_id INTO v_tour_id
      FROM tour_comments
     WHERE id = (p_comment_id COLLATE utf8mb4_unicode_ci)
       AND user_id = (p_user_id COLLATE utf8mb4_unicode_ci);

    IF v_tour_id IS NOT NULL THEN
        DELETE FROM tour_comments
         WHERE id = (p_comment_id COLLATE utf8mb4_unicode_ci)
           AND user_id = (p_user_id COLLATE utf8mb4_unicode_ci);
        SET v_affected = ROW_COUNT();
    END IF;

    SELECT
        v_affected AS affected_count,
        IF(v_affected > 0, v_tour_id, NULL) AS tour_id,
        IF(v_affected > 0,
           (SELECT COUNT(*) FROM tour_comments c WHERE c.tour_id = v_tour_id AND c.status = 'visible'),
           NULL) AS total_count;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_comment_list(p_status, p_keyword, p_limit, p_offset)
--   Trang "Bình luận" của quản trị viên. p_status: 'visible' | 'hidden' | NULL / '' (tất cả).
--   p_keyword: tìm trong nội dung, tên / email người viết và tên tour (NULL / '' = không lọc).
--   p_limit NULL hoặc 0 = 20, tối đa 100. Mới nhất trước.
--   Cột: comment_id, tour_id, tour_title, user_name, user_email, content, status, created_at,
--        hidden_by_name, hidden_reason, hidden_at, total_count (tổng số dòng khớp bộ lọc).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_comment_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_comment_list(
    IN p_status  VARCHAR(20),
    IN p_keyword VARCHAR(100) CHARACTER SET utf8mb4,
    IN p_limit   TINYINT UNSIGNED,
    IN p_offset  INT UNSIGNED
)
READS SQL DATA
BEGIN
    DECLARE v_keyword VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_keyword), '');
    DECLARE v_limit   INT UNSIGNED DEFAULT 20;
    DECLARE v_offset  INT UNSIGNED DEFAULT COALESCE(p_offset, 0);

    IF p_limit IS NOT NULL AND p_limit > 0 THEN
        SET v_limit = LEAST(p_limit, 100);
    END IF;

    SELECT
        c.id          AS comment_id,
        t.id          AS tour_id,
        t.title       AS tour_title,
        cu.name       AS user_name,
        cu.email      AS user_email,
        c.content,
        c.status,
        c.created_at,
        hu.name       AS hidden_by_name,
        c.hidden_reason,
        c.hidden_at,
        COUNT(*) OVER () AS total_count
    FROM tour_comments c
    JOIN tours t       ON t.id  = c.tour_id
    JOIN users cu      ON cu.id = c.user_id
    LEFT JOIN users hu ON hu.id = c.hidden_by
    WHERE (NULLIF(p_status, '') IS NULL OR c.status = (p_status COLLATE utf8mb4_unicode_ci))
      AND (v_keyword IS NULL
           OR LOCATE(v_keyword COLLATE utf8mb4_unicode_ci,
                     CONCAT_WS(' ', c.content, cu.name, cu.email, t.title)) > 0)
    ORDER BY c.created_at DESC, c.id DESC
    LIMIT v_limit OFFSET v_offset;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_comment_set_status(p_comment_id, p_admin_id, p_status, p_reason)
--   p_status: 'hidden' (ẩn, bắt buộc p_reason, tối đa 255 ký tự) | 'visible' (hiện lại, xóa
--   thông tin ẩn). Đổi trạng thái và ghi admin_logs trong cùng một transaction.
--   1 dòng: result, status.
--     result = 'ok'              : đã đổi; status = trạng thái mới.
--              'forbidden'       : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'       : không có bình luận này.
--              'invalid'         : p_status sai.
--              'reason_required' : ẩn mà không có lý do.
--              'unchanged'       : bình luận đã ở trạng thái p_status.
--     Khi không 'ok', status = trạng thái hiện tại (NULL nếu không có), không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_comment_set_status;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_comment_set_status(
    IN p_comment_id CHAR(36),
    IN p_admin_id   CHAR(36),
    IN p_status     VARCHAR(20),
    IN p_reason     VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_old    VARCHAR(20) DEFAULT NULL;
    DECLARE v_new    VARCHAR(20) DEFAULT COALESCE(p_status, '');
    DECLARE v_reason VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_reason), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_admin_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT status INTO v_old
      FROM tour_comments
     WHERE id = (p_comment_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS status;
        LEAVE proc;
    END IF;

    IF v_new NOT IN ('hidden', 'visible') THEN
        ROLLBACK;
        SELECT 'invalid' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    IF v_new = 'hidden' AND v_reason IS NULL THEN
        ROLLBACK;
        SELECT 'reason_required' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    IF v_old = v_new THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    IF v_new = 'hidden' THEN
        UPDATE tour_comments
           SET status = 'hidden', hidden_by = p_admin_id, hidden_at = NOW(), hidden_reason = v_reason
         WHERE id = (p_comment_id COLLATE utf8mb4_unicode_ci);
    ELSE
        UPDATE tour_comments
           SET status = 'visible', hidden_by = NULL, hidden_at = NULL, hidden_reason = NULL
         WHERE id = (p_comment_id COLLATE utf8mb4_unicode_ci);
    END IF;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_admin_id, 'tour_comment', p_comment_id,
            IF(v_new = 'hidden', 'comment_hide', 'comment_show'), v_old, v_new,
            IF(v_new = 'hidden', v_reason, NULL), NOW());

    COMMIT;
    SELECT 'ok' AS result, v_new AS status;
END$$
DELIMITER ;
