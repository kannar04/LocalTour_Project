-- =====================================================================
-- LocalTour v0.7 - 34_procedures_NMT_social.sql
-- Mục đích  : Thích, Lưu tour và số tương tác trên thẻ tour / trang chi tiết tour (CR2):
--   1. Số lượt thích, số bình luận đang hiển thị, tài khoản đang xem đã thích / đã lưu chưa
--      (một lần gọi cho cả trang danh sách).
--   2. Thích / bỏ thích (bảng tour_likes, file 33).
--   3. Lưu / bỏ lưu (bảng favorite_tours, file 01) và danh sách "Tour đã lưu".
-- Phụ trách : Nguyễn Minh Thức (NMT) - CR2
-- Procedures: NMT_sp_tour_social_state, NMT_sp_tour_like_toggle, NMT_sp_tour_save_toggle,
--             NMT_sp_saved_tour_list
-- Quy tắc   : Tour đang hiển thị = tour 'approved' của đơn vị 'approved' có tài khoản 'active'
--             (giống LTP_sp_tour_list, file 03). Chỉ tài khoản khách hàng đang hoạt động được
--             Thích / Lưu. Tour đã ngừng hiển thị vẫn bỏ thích / bỏ lưu được (để khách dọn
--             "Tour đã lưu"), nhưng không thích / lưu mới được.
--             Số bình luận = tour_comments có status 'visible' (file 33).
-- Chạy sau  : 33_migration_cr2_NTK.sql (bảng tour_likes, tour_comments). Khi gọi
--             NMT_sp_saved_tour_list cần bảng settings (28_migration_economy_NTK.sql) và
--             tour_packages (16_migration_sprint5_LTP.sql). Chạy lại được.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_social_state(p_user_id, p_tour_ids)
--   p_user_id : tài khoản đang xem; NULL hoặc '' = khách chưa đăng nhập (liked, saved = 0).
--   p_tour_ids: mã tour cách nhau bởi dấu phẩy, vd. 'c000...0001,c000...0005'. Tối đa 60 mã
--               (ứng dụng chặn trước); mã không có hoặc tour đang ẩn bị bỏ qua.
--   Mỗi tour đang hiển thị một dòng, theo thứ tự trong p_tour_ids. Cột:
--     tour_id, like_count, comment_count (bình luận 'visible'),
--     liked (1 = tài khoản đã thích), saved (1 = tài khoản đã lưu).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_social_state;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_social_state(
    IN p_user_id  CHAR(36),
    IN p_tour_ids TEXT
)
READS SQL DATA
BEGIN
    DECLARE v_ids  TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT REPLACE(COALESCE(p_tour_ids, ''), ' ', '');
    DECLARE v_user CHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULLIF(TRIM(COALESCE(p_user_id, '')), '');

    SELECT
        t.id AS tour_id,
        (SELECT COUNT(*) FROM tour_likes l WHERE l.tour_id = t.id)                              AS like_count,
        (SELECT COUNT(*) FROM tour_comments c WHERE c.tour_id = t.id AND c.status = 'visible')  AS comment_count,
        IF(v_user IS NULL, 0,
           EXISTS (SELECT 1 FROM tour_likes l
                    WHERE l.tour_id = t.id AND l.user_id = v_user))                             AS liked,
        IF(v_user IS NULL, 0,
           EXISTS (SELECT 1 FROM favorite_tours f
                    WHERE f.tour_id = t.id AND f.user_id = v_user))                             AS saved
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id          -- tài khoản của đơn vị tổ chức
    WHERE FIND_IN_SET(t.id, v_ids) > 0
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY FIND_IN_SET(t.id, v_ids);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_like_toggle(p_user_id, p_tour_id, p_want)
--   p_want: 1 = thích, 0 = bỏ thích, NULL = đảo trạng thái hiện tại. Gọi lại với cùng p_want
--           không đổi gì (bấm hai lần, hai tab cùng mở).
--   1 dòng: result, liked, like_count.
--     result = 'ok'        : liked = trạng thái sau khi gọi (1/0), like_count = tổng lượt thích.
--              'forbidden' : p_user_id không phải tài khoản khách hàng đang hoạt động.
--              'not_found' : không có tour này, hoặc tour đang ẩn mà tài khoản chưa thích
--                            (tour đang ẩn chỉ bỏ thích được).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_like_toggle;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_like_toggle(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36),
    IN p_want    TINYINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_visible   BOOLEAN DEFAULT FALSE;
    DECLARE v_has       BOOLEAN DEFAULT FALSE;
    DECLARE v_want      BOOLEAN DEFAULT FALSE;
    DECLARE v_duplicate BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- 1062 = trùng khóa UNIQUE (user_id, tour_id): lần bấm khác vừa thêm cùng dòng.
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'customer' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS liked, NULL AS like_count;
        LEAVE proc;
    END IF;

    SET v_visible = EXISTS (SELECT 1
                              FROM tours t
                              JOIN providers p ON p.id = t.provider_id
                              JOIN users     u ON u.id = p.user_id
                             WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                               AND t.approval_status = 'approved'
                               AND p.approval_status = 'approved'
                               AND u.status = 'active');
    SET v_has = EXISTS (SELECT 1 FROM tour_likes
                         WHERE user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
                           AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci));
    SET v_want = IF(p_want IS NULL, NOT v_has, p_want <> 0);

    IF NOT v_visible AND NOT v_has THEN
        SELECT 'not_found' AS result, NULL AS liked, NULL AS like_count;
        LEAVE proc;
    END IF;

    -- Tới đây: tour đang hiển thị, hoặc đang ẩn nhưng tài khoản đã thích (chỉ bỏ thích được).
    IF v_want AND NOT v_has THEN
        INSERT INTO tour_likes (id, user_id, tour_id, created_at)
        VALUES (UUID(), p_user_id, p_tour_id, NOW());
    ELSEIF NOT v_want AND v_has THEN
        DELETE FROM tour_likes
         WHERE user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    END IF;

    SELECT 'ok' AS result,
           IF(v_want, 1, 0) AS liked,
           (SELECT COUNT(*) FROM tour_likes WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)) AS like_count;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_save_toggle(p_user_id, p_tour_id, p_want)
--   Lưu tour vào "Tour đã lưu" (bảng favorite_tours).
--   p_want: 1 = lưu, 0 = bỏ lưu, NULL = đảo trạng thái hiện tại. Gọi lại với cùng p_want
--           không đổi gì.
--   1 dòng: result, saved.
--     result = 'ok'        : saved = trạng thái sau khi gọi (1/0).
--              'forbidden' : p_user_id không phải tài khoản khách hàng đang hoạt động.
--              'not_found' : không có tour này, hoặc tour đang ẩn mà tài khoản chưa lưu
--                            (tour đang ẩn chỉ bỏ lưu được).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_save_toggle;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_save_toggle(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36),
    IN p_want    TINYINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_visible   BOOLEAN DEFAULT FALSE;
    DECLARE v_has       BOOLEAN DEFAULT FALSE;
    DECLARE v_want      BOOLEAN DEFAULT FALSE;
    DECLARE v_duplicate BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- 1062 = trùng khóa UNIQUE (user_id, tour_id): lần bấm khác vừa thêm cùng dòng.
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'customer' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS saved;
        LEAVE proc;
    END IF;

    SET v_visible = EXISTS (SELECT 1
                              FROM tours t
                              JOIN providers p ON p.id = t.provider_id
                              JOIN users     u ON u.id = p.user_id
                             WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                               AND t.approval_status = 'approved'
                               AND p.approval_status = 'approved'
                               AND u.status = 'active');
    SET v_has = EXISTS (SELECT 1 FROM favorite_tours
                         WHERE user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
                           AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci));
    SET v_want = IF(p_want IS NULL, NOT v_has, p_want <> 0);

    IF NOT v_visible AND NOT v_has THEN
        SELECT 'not_found' AS result, NULL AS saved;
        LEAVE proc;
    END IF;

    -- Tới đây: tour đang hiển thị, hoặc đang ẩn nhưng tài khoản đã lưu (chỉ bỏ lưu được).
    IF v_want AND NOT v_has THEN
        INSERT INTO favorite_tours (id, user_id, tour_id, created_at)
        VALUES (UUID(), p_user_id, p_tour_id, NOW());
    ELSEIF NOT v_want AND v_has THEN
        DELETE FROM favorite_tours
         WHERE user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    END IF;

    SELECT 'ok' AS result, IF(v_want, 1, 0) AS saved;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_saved_tour_list(p_user_id)
--   "Tour đã lưu" của một tài khoản, lưu gần nhất trước. Gồm cả tour đã ngừng hiển thị
--   (is_visible = 0) để khách thấy và bỏ lưu; tour đó không có giá / lịch.
--   Cột: tour_id, title, destination_name, category_name, provider_name, duration_minutes,
--        language_codes, pickup_mode, meeting_point,
--        from_price_vnd (giá người lớn thấp nhất / người của các lịch đặt được; tour có gói
--                        đang bán: giá người lớn thấp nhất của các gói – như LTP_sp_tour_list),
--        next_starts_at (lịch đặt được gần nhất), rating_avg, review_count (đánh giá đã duyệt),
--        like_count, cover_image_url, cover_alt_text,
--        is_visible (1 = tour đang hiển thị), bookable (1 = đang hiển thị và có lịch đặt được),
--        saved_at.
--   Lịch đặt được: 'open', còn chỗ, có vé 'adult' đang bán và còn hơn
--   settings.booking_cutoff_minutes phút (mặc định 60) mới tới giờ khởi hành.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_saved_tour_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_saved_tour_list(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    -- Ngừng nhận đặt trước giờ khởi hành bao nhiêu phút (file 28).
    DECLARE v_cutoff_min INT DEFAULT 60;

    SET v_cutoff_min = COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,5}$', CAST(st.value AS UNSIGNED), NULL)
                                   FROM settings st WHERE st.name = 'booking_cutoff_minutes'), 60);

    SELECT
        t.id                            AS tour_id,
        t.title,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name                          AS category_name,
        p.business_name                 AS provider_name,
        t.duration_minutes,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        IF((t.approval_status = 'approved' AND p.approval_status = 'approved' AND u.status = 'active'),
           bs.from_price_vnd, NULL)    AS from_price_vnd,
        IF((t.approval_status = 'approved' AND p.approval_status = 'approved' AND u.status = 'active'),
           bs.next_starts_at, NULL)    AS next_starts_at,
        rs.rating_avg,
        COALESCE(rs.review_count, 0)    AS review_count,
        (SELECT COUNT(*) FROM tour_likes l WHERE l.tour_id = t.id) AS like_count,
        ci.url                          AS cover_image_url,
        ci.alt_text                     AS cover_alt_text,
        IF((t.approval_status = 'approved' AND p.approval_status = 'approved' AND u.status = 'active'), 1, 0) AS is_visible,
        IF((t.approval_status = 'approved' AND p.approval_status = 'approved' AND u.status = 'active')
           AND bs.next_starts_at IS NOT NULL, 1, 0) AS bookable,
        f.created_at                    AS saved_at
    FROM favorite_tours f
    JOIN tours     t ON t.id = f.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id          -- tài khoản của đơn vị tổ chức
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    -- Lịch đặt được của các tour đã lưu: giá "Từ" và lịch khởi hành gần nhất
    LEFT JOIN (SELECT s.tour_id,
                      MIN(s.starts_at) AS next_starts_at,
                      MIN(CASE WHEN tt.name = 'adult' THEN COALESCE(pk.adult_from, tt.price_vnd) END) AS from_price_vnd
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                 -- Tour có gói đang bán: giá người lớn thấp nhất của các gói
                 LEFT JOIN (SELECT tp.tour_id, MIN(tp.adult_price_vnd) AS adult_from
                              FROM tour_packages tp
                             WHERE tp.active = TRUE
                             GROUP BY tp.tour_id) pk
                        ON pk.tour_id = s.tour_id
                WHERE s.status = 'open'
                  AND s.starts_at > NOW() + INTERVAL v_cutoff_min MINUTE
                  AND s.remaining > 0
                  AND s.tour_id IN (SELECT f3.tour_id FROM favorite_tours f3
                                     WHERE f3.user_id = (p_user_id COLLATE utf8mb4_unicode_ci))
                GROUP BY s.tour_id) bs
           ON bs.tour_id = t.id
    -- Điểm trung bình và số đánh giá đã duyệt
    LEFT JOIN (SELECT r.tour_id,
                      CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1)) AS rating_avg,
                      COUNT(*)                                      AS review_count
                 FROM reviews r
                WHERE r.moderation_status = 'approved'
                GROUP BY r.tour_id) rs
           ON rs.tour_id = t.id
    -- Ảnh bìa: đúng 1 ảnh của tour (hoặc không có)
    LEFT JOIN tour_images ci
           ON ci.id = (SELECT ti.id
                         FROM tour_images ti
                        WHERE ti.tour_id = t.id
                        ORDER BY ti.sort_order ASC, ti.id ASC
                        LIMIT 1)
    WHERE f.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
    ORDER BY f.created_at DESC, f.id DESC;
END$$
DELIMITER ;
