-- =====================================================================
-- LocalTour v0.1 - 03_procedures_LTP.sql
-- Mục đích  : Stored procedures cho trang danh sách tour (Bảng tin du lịch).
-- Phụ trách : Lê Trung Phong (LTP) - WBS 3.2.3
-- Procedures: LTP_sp_tour_list, LTP_sp_destination_list, LTP_sp_category_list
-- Quy tắc   : Tour được hiển thị khi tours.approval_status = 'approved' VÀ
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
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
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
