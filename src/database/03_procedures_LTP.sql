-- =====================================================================
-- LocalTour v0.1 - 03_procedures_LTP.sql
-- Mục đích  : Stored procedures cho trang danh sách tour (Bảng tin du lịch) và trang
--             duyệt tour của quản trị viên (FR-24).
-- Phụ trách : Lê Trung Phong (LTP) - WBS 3.2.3
-- Procedures: LTP_sp_tour_list, LTP_sp_destination_list, LTP_sp_category_list,
--             LTP_sp_admin_tour_list, LTP_sp_admin_tour_detail,
--             LTP_sp_admin_tour_set_approval
-- Quy tắc   : Trang khách: tour được hiển thị khi tours.approval_status = 'approved' VÀ
--             providers.approval_status = 'approved' VÀ tài khoản của nhà cung cấp
--             (users.status) = 'active'. Tour khác -> không bao giờ trả về.
--             Lịch đặt được: status = 'open', starts_at > NOW(), remaining > 0 và có
--             ít nhất một loại vé active.
--             Điểm đánh giá chỉ tính đánh giá moderation_status = 'approved'.
--             Ảnh bìa: ảnh của chính tour có sort_order nhỏ nhất (rồi id nhỏ nhất).
--             Tên điểm đến = destinations.name; tour chưa gán destination_id thì dùng
--             tours.destination.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci để không lỗi
--             "Illegal mix of collations" khi database mặc định dùng collation khác.
--             Trang quản trị: xem mọi tour, quy tắc riêng ở phần "Trang quản trị" cuối file.
--             Không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_tour_list(p_keyword, p_destination_id, p_category_id, p_sort)
--   p_keyword        : NULL / '' / toàn khoảng trắng = không lọc; ngược lại tìm
--                      LIKE '%từ khóa%' trong tên tour, mô tả, điểm đến, loại hình,
--                      tên nhà cung cấp. Ký tự % và _ được tìm đúng nghĩa đen (ký tự
--                      thoát là !).
--   p_destination_id : NULL / '' = mọi điểm đến; ngược lại chỉ tour có
--                      tours.destination_id = p_destination_id.
--   p_category_id    : NULL / '' = mọi loại hình; ngược lại chỉ tour có
--                      tours.category_id = p_category_id.
--   p_sort           : 'recommended' (mặc định) | 'upcoming' | 'price_asc' | 'price_desc';
--                      giá trị khác = 'recommended'.
--     recommended: tour có đánh giá trước, rating_avg giảm dần, review_count giảm dần
--     upcoming   : next_starts_at tăng dần, tour chưa có lịch đặt được xếp cuối
--     price_asc / price_desc: from_price_vnd, tour chưa có giá (NULL) xếp cuối
--     Cùng thứ hạng thì xếp theo title, rồi id.
--   Cột trả về: tour_id, title, description, destination_id, destination_name,
--     category_id, category_name (NULL nếu chưa gán loại hình), provider_name,
--     duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point,
--     from_price_vnd, rating_avg (DECIMAL(2,1), NULL nếu chưa có đánh giá),
--     review_count, next_starts_at, cover_image_url, cover_alt_text
--   from_price_vnd: giá vé 'adult' active thấp nhất trong các lịch đặt được. Chỉ lấy vé
--     người lớn (giá hiển thị là "/ người lớn", FR-10); không lấy giá vé trẻ em thay thế.
--     NULL khi không có lịch đặt được hoặc không lịch nào còn vé người lớn đang bán
--     (giao diện xếp vào nhóm "chưa cập nhật giá").
--   next_starts_at: giờ khởi hành sớm nhất trong các lịch đặt được (NULL nếu không có).
--   cover_image_url / cover_alt_text: url và alt_text của ảnh bìa trong tour_images
--     (sort_order nhỏ nhất, cùng sort_order thì id nhỏ nhất); NULL nếu tour chưa có ảnh.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_tour_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_tour_list(
    IN p_keyword        VARCHAR(100),
    IN p_destination_id CHAR(36),
    IN p_category_id    CHAR(36),
    IN p_sort           VARCHAR(20)
)
READS SQL DATA
BEGIN
    DECLARE v_pattern        VARCHAR(310) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_destination_id CHAR(36) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_category_id    CHAR(36) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_sort           VARCHAR(20) DEFAULT 'recommended';

    -- Thoát ký tự đặc biệt của LIKE: '!' trước (vì là ký tự thoát), sau đó '%' và '_'.
    IF p_keyword IS NOT NULL AND TRIM(p_keyword) <> '' THEN
        SET v_pattern = CONCAT('%',
            REPLACE(REPLACE(REPLACE(TRIM(p_keyword), '!', '!!'), '%', '!%'), '_', '!_'),
            '%');
    END IF;

    IF p_destination_id IS NOT NULL AND p_destination_id <> '' THEN
        SET v_destination_id = p_destination_id;
    END IF;

    IF p_category_id IS NOT NULL AND p_category_id <> '' THEN
        SET v_category_id = p_category_id;
    END IF;

    IF p_sort IN ('upcoming', 'price_asc', 'price_desc') THEN
        SET v_sort = p_sort;
    END IF;

    SELECT
        t.id                            AS tour_id,
        t.title,
        t.description,
        t.destination_id,
        COALESCE(d.name, t.destination) AS destination_name,
        t.category_id,
        c.name                          AS category_name,
        p.business_name                 AS provider_name,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        bs.from_price_vnd,
        rs.rating_avg,
        COALESCE(rs.review_count, 0)    AS review_count,
        bs.next_starts_at,
        ci.url                          AS cover_image_url,
        ci.alt_text                     AS cover_alt_text
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    -- Lịch đặt được của từng tour: giá "Từ" và lịch khởi hành gần nhất
    LEFT JOIN (SELECT s.tour_id,
                      MIN(s.starts_at) AS next_starts_at,
                      MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS from_price_vnd
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                WHERE s.status = 'open'
                  AND s.starts_at > NOW()
                  AND s.remaining > 0
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
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
      AND (v_destination_id IS NULL
           OR t.destination_id = (v_destination_id COLLATE utf8mb4_unicode_ci))
      AND (v_category_id IS NULL
           OR t.category_id = (v_category_id COLLATE utf8mb4_unicode_ci))
      AND (v_pattern IS NULL
           OR t.title                         LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR t.description                   LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR COALESCE(d.name, t.destination) LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR c.name                          LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR p.business_name                 LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!')
    ORDER BY
        CASE WHEN v_sort = 'recommended' THEN (rs.rating_avg IS NULL) END ASC,
        CASE WHEN v_sort = 'recommended' THEN rs.rating_avg END DESC,
        CASE WHEN v_sort = 'recommended' THEN COALESCE(rs.review_count, 0) END DESC,
        CASE WHEN v_sort = 'upcoming'    THEN (bs.next_starts_at IS NULL) END ASC,
        CASE WHEN v_sort = 'upcoming'    THEN bs.next_starts_at END ASC,
        CASE WHEN v_sort IN ('price_asc', 'price_desc') THEN (bs.from_price_vnd IS NULL) END ASC,
        CASE WHEN v_sort = 'price_asc'   THEN bs.from_price_vnd END ASC,
        CASE WHEN v_sort = 'price_desc'  THEN bs.from_price_vnd END DESC,
        t.title ASC,
        t.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_destination_list()
--   Điểm đến cho bộ lọc và thanh bên, lấy từ bảng destinations. Chỉ trả điểm đến
--   đang có ít nhất một tour hiển thị, kèm số tour hiển thị.
--   Cột trả về: destination_id, name, slug, tour_count.
--   Sắp xếp theo destinations.sort_order, rồi name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_destination_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_destination_list()
READS SQL DATA
BEGIN
    SELECT
        d.id     AS destination_id,
        d.name,
        d.slug,
        COUNT(*) AS tour_count
    FROM destinations d
    JOIN tours     t ON t.destination_id = d.id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    GROUP BY d.id, d.name, d.slug, d.sort_order
    ORDER BY d.sort_order ASC, d.name ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_category_list()
--   Loại hình cho bộ lọc "Loại hình", lấy từ bảng categories. Chỉ trả loại hình
--   đang có ít nhất một tour hiển thị, kèm số tour hiển thị.
--   Cột trả về: category_id, name, slug, tour_count. Sắp xếp theo name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_category_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_category_list()
READS SQL DATA
BEGIN
    SELECT
        c.id     AS category_id,
        c.name,
        c.slug,
        COUNT(*) AS tour_count
    FROM categories c
    JOIN tours     t ON t.category_id = c.id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    GROUP BY c.id, c.name, c.slug
    ORDER BY c.name ASC;
END$$
DELIMITER ;

-- =====================================================================
-- Trang quản trị: duyệt tour (FR-24, NFR-09)
--   Các procedure dưới đây KHÔNG lọc tour công khai: quản trị viên xem mọi tour.
--   Chỉ trang quản trị gọi chúng (ứng dụng kiểm tra tài khoản quản trị viên trước).
--   Chuyển trạng thái duyệt: pending -> approved, pending -> rejected (bắt buộc lý do).
--   Tour bị từ chối không mở lại được; đơn vị tổ chức gửi lại thông tin thì quản trị
--   viên nhập thành tour mới ở trạng thái 'pending'.
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_admin_tour_list(p_approval_status)
--   p_approval_status: NULL / '' = mọi trạng thái; ngược lại 'draft' | 'pending' |
--                      'approved' | 'rejected'.
--   Cột trả về: tour_id, title, provider_name, provider_approval_status,
--     provider_user_status, destination_name, category_name, approval_status,
--     is_public (1 = đang hiển thị cho khách), schedule_count (mọi lịch của tour),
--     last_action_at (lần xử lý gần nhất trong admin_logs, NULL nếu chưa có).
--   Sắp xếp: tour chờ duyệt trước, rồi title, rồi id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_tour_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_tour_list(
    IN p_approval_status VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                AS tour_id,
        t.title,
        p.business_name     AS provider_name,
        p.approval_status   AS provider_approval_status,
        u.status            AS provider_user_status,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        t.approval_status,
        (t.approval_status = 'approved'
         AND p.approval_status = 'approved'
         AND u.status = 'active') AS is_public,
        (SELECT COUNT(*)
           FROM schedules s
          WHERE s.tour_id = t.id) AS schedule_count,
        (SELECT MAX(l.created_at)
           FROM admin_logs l
          WHERE l.target_type = 'tour'
            AND l.target_id = t.id) AS last_action_at
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    WHERE NULLIF(p_approval_status, '') IS NULL
       OR t.approval_status = (p_approval_status COLLATE utf8mb4_unicode_ci)
    ORDER BY (t.approval_status = 'pending') DESC, t.title ASC, t.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_tour_detail(p_tour_id)
--   0 hoặc 1 dòng, mọi trạng thái duyệt. Cột: tour_id, title, description,
--   destination_name, category_name, duration_minutes, max_group_size, language_codes,
--   pickup_mode, meeting_point, transport, guide_info, dropoff_point,
--   source_url, verified_at, verification_status (NFR-07),
--   provider_name, provider_phone, provider_approval_status, provider_user_status,
--   approval_status, is_public,
--   schedule_count, ticket_count (loại vé active), image_count, itinerary_count,
--   inclusion_count, policy_count (số phiên bản chính sách hủy).
--   Chỉ trả số lượng các phần con: trang quản trị dùng để xem tour đã đủ thông tin chưa.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_tour_detail;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_tour_detail(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                AS tour_id,
        t.title,
        t.description,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.transport,
        t.guide_info,
        t.dropoff_point,
        t.source_url,
        t.verified_at,
        t.verification_status,
        p.business_name     AS provider_name,
        p.contact_phone     AS provider_phone,
        p.approval_status   AS provider_approval_status,
        u.status            AS provider_user_status,
        t.approval_status,
        (t.approval_status = 'approved'
         AND p.approval_status = 'approved'
         AND u.status = 'active') AS is_public,
        (SELECT COUNT(*) FROM schedules s WHERE s.tour_id = t.id) AS schedule_count,
        (SELECT COUNT(*)
           FROM ticket_types tt
           JOIN schedules s ON s.id = tt.schedule_id
          WHERE s.tour_id = t.id
            AND tt.active = TRUE) AS ticket_count,
        (SELECT COUNT(*) FROM tour_images ti WHERE ti.tour_id = t.id) AS image_count,
        (SELECT COUNT(*) FROM tour_itinerary_items ii WHERE ii.tour_id = t.id) AS itinerary_count,
        (SELECT COUNT(*) FROM tour_inclusions tn WHERE tn.tour_id = t.id) AS inclusion_count,
        (SELECT COUNT(*) FROM cancellation_policies cp WHERE cp.tour_id = t.id) AS policy_count
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_tour_set_approval(p_tour_id, p_new_status, p_actor_user_id, p_note)
--   p_new_status: 'approved' (phê duyệt) | 'rejected' (từ chối, bắt buộc p_note).
--   Đổi trạng thái và ghi admin_logs ('tour_approve' / 'tour_reject') trong cùng một
--   transaction. p_note tối đa 255 ký tự (NULL / '' = không có).
--   1 dòng: result, approval_status.
--     result = 'ok'                 : đã đổi; approval_status = trạng thái mới.
--              'forbidden'          : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'          : không có tour này.
--              'invalid_transition' : tour không ở trạng thái 'pending', hoặc p_new_status sai.
--              'note_required'      : từ chối mà không có lý do.
--     Khi không 'ok', approval_status = trạng thái hiện tại, không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_tour_set_approval;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_tour_set_approval(
    IN p_tour_id       CHAR(36),
    IN p_new_status    VARCHAR(20),
    IN p_actor_user_id CHAR(36),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_old  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_new  VARCHAR(20)  DEFAULT COALESCE(p_new_status, '');
    DECLARE v_note VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS approval_status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT approval_status
      INTO v_old
      FROM tours
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS approval_status;
        LEAVE proc;
    END IF;

    IF v_old <> 'pending' OR v_new NOT IN ('approved', 'rejected') THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, v_old AS approval_status;
        LEAVE proc;
    END IF;

    IF v_new = 'rejected' AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_old AS approval_status;
        LEAVE proc;
    END IF;

    UPDATE tours
       SET approval_status = v_new
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id,
            IF(v_new = 'approved', 'tour_approve', 'tour_reject'), v_old, v_new, v_note, NOW());

    COMMIT;
    SELECT 'ok' AS result, v_new AS approval_status;
END$$
DELIMITER ;
