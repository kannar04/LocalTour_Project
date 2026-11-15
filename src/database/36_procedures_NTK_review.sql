-- =====================================================================
-- LocalTour v0.7 - 36_procedures_NTK_review.sql
-- Mục đích  : Đánh giá sao (FR-16, CR3): khách hàng chấm 1–5 sao và viết nhận xét cho đơn đã
--             hoàn thành; quản trị viên duyệt trước khi đánh giá hiện trên trang tour.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Procedures: NTK_sp_review_get, NTK_sp_review_save, NTK_sp_review_state_list,
--             NTK_sp_admin_review_list, NTK_sp_admin_review_summary, NTK_sp_admin_review_decide
-- Quy tắc   : * Chỉ đơn của chính tài khoản khách hàng, ở trạng thái 'completed' (Đã hoàn thành),
--               mới đánh giá được; mỗi đơn một đánh giá (reviews.uq_reviews_booking).
--             * rating là số nguyên 1–5; content 10–1000 ký tự sau khi bỏ khoảng trắng hai đầu.
--             * Đánh giá mới hoặc vừa sửa ở 'pending' (Chờ duyệt); chỉ 'approved' (Đã duyệt) hiện
--               trên trang tour và được tính vào điểm trung bình (LTP_sp_tour_list,
--               NMT_sp_tour_detail, NTK_sp_tour_review_list đều tính trực tiếp từ đánh giá đã
--               duyệt, không lưu điểm riêng nên không cần cập nhật thêm).
--             * Khách sửa được khi đánh giá còn 'pending' hoặc 'rejected' (Không được duyệt); sửa
--               xong quay lại 'pending', xóa ghi chú kiểm duyệt cũ. Đánh giá đã duyệt bị khóa.
--             * reviews.created_at = lần khách gửi gần nhất (gửi lại sau khi sửa thì cập nhật).
--             * Quản trị viên: 'pending' -> 'approved' (ghi chú không bắt buộc) hoặc 'rejected'
--               (bắt buộc lý do); 'approved' -> 'rejected' (gỡ đánh giá đã đăng, bắt buộc lý do).
--               Mỗi lần xử lý ghi admin_logs (target_type 'review', NFR-09) trong cùng transaction.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 33 (33_migration_cr3_NTK.sql thêm reviews.created_at, moderated_by,
--             moderated_at, moderation_note). Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- NTK_sp_review_get(p_user_id, p_code)
--   0 dòng: không có đơn mã p_code của tài khoản p_user_id.
--   1 dòng: booking_id, code, booking_status, tour_id,
--     can_review (1 = đơn 'completed' và đánh giá chưa duyệt / chưa có: khách gửi hoặc sửa được),
--     review_id, rating, content, moderation_status, moderation_note, created_at, moderated_at
--     (các cột đánh giá NULL khi đơn chưa có đánh giá).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_review_get;

DELIMITER $$
CREATE PROCEDURE NTK_sp_review_get(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        b.id                  AS booking_id,
        b.code,
        b.status              AS booking_status,
        s.tour_id,
        (b.status = 'completed' AND COALESCE(r.moderation_status, 'pending') <> 'approved') AS can_review,
        r.id                  AS review_id,
        r.rating,
        r.content,
        r.moderation_status,
        r.moderation_note,
        r.created_at,
        r.moderated_at
    FROM bookings b
    JOIN schedules s     ON s.id = b.schedule_id
    LEFT JOIN reviews r  ON r.booking_id = b.id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_review_save(p_user_id, p_code, p_rating, p_content)
--   Gửi đánh giá mới hoặc sửa đánh giá đang chờ duyệt / không được duyệt của đơn p_code.
--   1 dòng: result, field, review_id, moderation_status.
--     result = 'created'       : đã thêm đánh giá (moderation_status = 'pending').
--              'updated'       : đã sửa, đánh giá quay lại 'pending'.
--              'forbidden'     : tài khoản không phải khách hàng đang hoạt động.
--              'not_found'     : không có đơn mã p_code của tài khoản này.
--              'not_completed' : đơn chưa ở trạng thái 'completed'.
--              'locked'        : đánh giá đã được duyệt, không sửa được nữa.
--              'invalid'       : field = 'rating' (không phải 1–5) | 'content' (dưới 10 hoặc trên
--                                1000 ký tự sau khi bỏ khoảng trắng hai đầu).
--   Khóa dòng đơn (FOR UPDATE) để hai lần gửi cùng lúc không tạo hai đánh giá.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_review_save;

DELIMITER $$
CREATE PROCEDURE NTK_sp_review_save(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20),
    IN p_rating  INT,
    IN p_content TEXT CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_content    TEXT        CHARACTER SET utf8mb4;
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_tour_id    CHAR(36)    DEFAULT NULL;
    DECLARE v_review_id  CHAR(36)    DEFAULT NULL;
    DECLARE v_moderation VARCHAR(20) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_content = TRIM(COALESCE(p_content, ''));

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'customer' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS review_id, NULL AS moderation_status;
        LEAVE proc;
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        SELECT 'invalid' AS result, 'rating' AS field, NULL AS review_id, NULL AS moderation_status;
        LEAVE proc;
    END IF;
    IF CHAR_LENGTH(v_content) < 10 OR CHAR_LENGTH(v_content) > 1000 THEN
        SELECT 'invalid' AS result, 'content' AS field, NULL AS review_id, NULL AS moderation_status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT b.id, b.status, s.tour_id
      INTO v_booking_id, v_status, v_tour_id
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS review_id, NULL AS moderation_status;
        LEAVE proc;
    END IF;

    IF v_status <> 'completed' THEN
        ROLLBACK;
        SELECT 'not_completed' AS result, NULL AS field, NULL AS review_id, NULL AS moderation_status;
        LEAVE proc;
    END IF;

    SELECT id, moderation_status
      INTO v_review_id, v_moderation
      FROM reviews
     WHERE booking_id = v_booking_id
       FOR UPDATE;

    IF v_review_id IS NULL THEN
        SET v_review_id = UUID();
        INSERT INTO reviews (id, booking_id, tour_id, rating, content, moderation_status, created_at)
        VALUES (v_review_id, v_booking_id, v_tour_id, p_rating, v_content, 'pending', NOW());
        COMMIT;
        SELECT 'created' AS result, NULL AS field, v_review_id AS review_id, 'pending' AS moderation_status;
        LEAVE proc;
    END IF;

    IF v_moderation = 'approved' THEN
        ROLLBACK;
        SELECT 'locked' AS result, NULL AS field, v_review_id AS review_id, v_moderation AS moderation_status;
        LEAVE proc;
    END IF;

    UPDATE reviews
       SET rating            = p_rating,
           content           = v_content,
           moderation_status = 'pending',
           created_at        = NOW(),
           moderated_by      = NULL,
           moderated_at      = NULL,
           moderation_note   = NULL
     WHERE id = v_review_id;

    COMMIT;
    SELECT 'updated' AS result, NULL AS field, v_review_id AS review_id, 'pending' AS moderation_status;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_review_state_list(p_user_id)
--   Trạng thái đánh giá của các đơn thuộc tài khoản p_user_id (chỉ đơn đã có đánh giá), dùng cho
--   nhắc "Viết đánh giá" ở trang "Đơn của tôi".
--   Cột: booking_id, moderation_status.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_review_state_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_review_state_list(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        r.booking_id,
        r.moderation_status
    FROM reviews r
    JOIN bookings b ON b.id = r.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_review_list(p_status, p_keyword, p_limit, p_offset)
--   p_status : 'pending' | 'approved' | 'rejected'; NULL / '' = mọi trạng thái.
--   p_keyword: NULL / '' = không lọc; ngược lại tìm trong mã đơn, tên tour, tên và email khách.
--   p_limit 1–50 (ngoài khoảng = 20), p_offset >= 0 (NULL = 0).
--   Cột: review_id, booking_id, booking_code, tour_id, tour_title, customer_name, customer_email,
--        starts_at (giờ khởi hành của lịch trong đơn), rating, content, moderation_status,
--        created_at (lần gửi gần nhất), moderated_at, moderation_note, moderator_name
--        (NULL = chưa xử lý).
--   Sắp xếp: đánh giá chờ duyệt trước (gửi sớm trước), rồi các đánh giá khác mới gửi trước.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_review_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_review_list(
    IN p_status  VARCHAR(20),
    IN p_keyword VARCHAR(100) CHARACTER SET utf8mb4,
    IN p_limit   INT,
    IN p_offset  INT
)
READS SQL DATA
BEGIN
    DECLARE v_keyword VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_keyword), '');
    DECLARE v_limit   INT DEFAULT 20;
    DECLARE v_offset  INT DEFAULT 0;

    IF p_limit IS NOT NULL AND p_limit BETWEEN 1 AND 50 THEN
        SET v_limit = p_limit;
    END IF;
    IF p_offset IS NOT NULL AND p_offset > 0 THEN
        SET v_offset = p_offset;
    END IF;

    SELECT
        r.id                AS review_id,
        b.id                AS booking_id,
        b.code              AS booking_code,
        t.id                AS tour_id,
        t.title             AS tour_title,
        c.name              AS customer_name,
        c.email             AS customer_email,
        s.starts_at,
        r.rating,
        r.content,
        r.moderation_status,
        r.created_at,
        r.moderated_at,
        r.moderation_note,
        m.name              AS moderator_name
    FROM reviews r
    JOIN bookings  b ON b.id = r.booking_id
    JOIN users     c ON c.id = b.user_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours     t ON t.id = r.tour_id
    LEFT JOIN users m ON m.id = r.moderated_by
    WHERE (NULLIF(p_status, '') IS NULL OR r.moderation_status = (p_status COLLATE utf8mb4_unicode_ci))
      AND (v_keyword IS NULL
           OR LOCATE(v_keyword COLLATE utf8mb4_unicode_ci,
                     CONCAT_WS(' ', b.code, t.title, c.name, c.email)) > 0)
    ORDER BY (r.moderation_status = 'pending') DESC,
             CASE WHEN r.moderation_status = 'pending' THEN r.created_at END ASC,
             r.created_at DESC,
             r.id
    LIMIT v_limit OFFSET v_offset;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_review_summary(p_status, p_keyword)
--   1 dòng (cùng bộ lọc từ khóa như NTK_sp_admin_review_list):
--   total (số đánh giá khớp p_status và p_keyword, để chia trang),
--   pending_count, approved_count, rejected_count, all_count (theo từ khóa, mọi trạng thái).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_review_summary;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_review_summary(
    IN p_status  VARCHAR(20),
    IN p_keyword VARCHAR(100) CHARACTER SET utf8mb4
)
READS SQL DATA
BEGIN
    DECLARE v_keyword VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_keyword), '');

    SELECT
        COALESCE(SUM(NULLIF(p_status, '') IS NULL
                     OR r.moderation_status = (p_status COLLATE utf8mb4_unicode_ci)), 0) AS total,
        COALESCE(SUM(r.moderation_status = 'pending'), 0)  AS pending_count,
        COALESCE(SUM(r.moderation_status = 'approved'), 0) AS approved_count,
        COALESCE(SUM(r.moderation_status = 'rejected'), 0) AS rejected_count,
        COUNT(r.id)                                        AS all_count
    FROM reviews r
    JOIN bookings  b ON b.id = r.booking_id
    JOIN users     c ON c.id = b.user_id
    JOIN tours     t ON t.id = r.tour_id
    WHERE v_keyword IS NULL
       OR LOCATE(v_keyword COLLATE utf8mb4_unicode_ci,
                 CONCAT_WS(' ', b.code, t.title, c.name, c.email)) > 0;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_review_decide(p_actor_user_id, p_review_id, p_decision, p_note)
--   p_decision: 'approved' (duyệt, chỉ từ 'pending') | 'rejected' (từ chối đánh giá chờ duyệt
--   hoặc gỡ đánh giá đã duyệt; bắt buộc p_note). p_note tối đa 255 ký tự.
--   Đổi trạng thái, ghi người duyệt / thời điểm / ghi chú và admin_logs ('review_approve' /
--   'review_reject') trong cùng một transaction.
--   1 dòng: result, moderation_status.
--     result = 'ok'                 : đã đổi; moderation_status = trạng thái mới.
--              'forbidden'          : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'          : không có đánh giá này.
--              'invalid'            : p_decision sai hoặc p_note quá 255 ký tự.
--              'note_required'      : từ chối mà không có lý do.
--              'invalid_transition' : trạng thái hiện tại không cho phép (vd. duyệt đánh giá đã
--                                     duyệt, từ chối đánh giá đã từ chối).
--     Khi không 'ok', moderation_status = trạng thái hiện tại (NULL nếu không có), không đổi gì.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_review_decide;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_review_decide(
    IN p_actor_user_id CHAR(36),
    IN p_review_id     CHAR(36),
    IN p_decision      VARCHAR(20),
    IN p_note          TEXT CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_decision VARCHAR(20)  DEFAULT COALESCE(p_decision, '');
    DECLARE v_note     TEXT         CHARACTER SET utf8mb4;
    DECLARE v_old      VARCHAR(20)  DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_note = NULLIF(TRIM(p_note), '');

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS moderation_status;
        LEAVE proc;
    END IF;

    IF v_decision NOT IN ('approved', 'rejected') OR CHAR_LENGTH(COALESCE(v_note, '')) > 255 THEN
        SELECT 'invalid' AS result, NULL AS moderation_status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT moderation_status
      INTO v_old
      FROM reviews
     WHERE id = (p_review_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS moderation_status;
        LEAVE proc;
    END IF;

    IF (v_decision = 'approved' AND v_old <> 'pending')
       OR (v_decision = 'rejected' AND v_old = 'rejected') THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, v_old AS moderation_status;
        LEAVE proc;
    END IF;

    IF v_decision = 'rejected' AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_old AS moderation_status;
        LEAVE proc;
    END IF;

    UPDATE reviews
       SET moderation_status = v_decision,
           moderated_by      = p_actor_user_id,
           moderated_at      = NOW(),
           moderation_note   = v_note
     WHERE id = (p_review_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'review', p_review_id,
            IF(v_decision = 'approved', 'review_approve', 'review_reject'), v_old, v_decision, v_note, NOW());

    COMMIT;
    SELECT 'ok' AS result, v_decision AS moderation_status;
END$$
DELIMITER ;
