-- =====================================================================
-- LocalTour v0.1 - 03_procedures_LTP.sql
-- Mục đích  : Stored procedures cho trang danh sách tour (Bảng tin du lịch).
-- Phụ trách : Lê Trung Phong (LTP) - WBS 3.2.3
-- Procedures: LTP_sp_tour_list, LTP_sp_destination_list
-- Quy tắc   : Chỉ trả về tour status = 'published' của đơn vị is_active = 1.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_tour_list(p_keyword, p_destination_id, p_sort)
--   p_keyword        : NULL / '' / toàn khoảng trắng = không lọc; ngược lại tìm
--                      LIKE '%từ khóa%' trong tên tour, mô tả ngắn, tên điểm đến,
--                      tên đơn vị tổ chức. Ký tự % và _ được tìm đúng nghĩa đen.
--   p_destination_id : NULL hoặc 0 = mọi điểm đến.
--   p_sort           : 'recommended' (mặc định) | 'newest' | 'price_asc' | 'price_desc';
--                      giá trị khác = 'recommended'.
--     recommended: tour có đánh giá trước, rating_avg giảm dần, review_count giảm dần, tour_id tăng dần
--     newest     : created_at giảm dần, tour_id giảm dần
--     price_asc / price_desc: price_per_person, cùng giá thì tour_id tăng dần
--   Cột trả về: tour_id, title, summary, destination_id, destination_name, category_name,
--     provider_name, provider_verified, duration_hours, max_group_size, languages,
--     price_per_person, meeting_point, cover_image, cover_caption, rating_avg,
--     review_count, next_departure_date, created_at
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_tour_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_tour_list(
    IN p_keyword        VARCHAR(100),
    IN p_destination_id INT UNSIGNED,
    IN p_sort           VARCHAR(20)
)
READS SQL DATA
BEGIN
    DECLARE v_pattern VARCHAR(310) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_sort    VARCHAR(20) DEFAULT 'recommended';

    IF p_keyword IS NOT NULL AND TRIM(p_keyword) <> '' THEN
        SET v_pattern = CONCAT('%',
            REPLACE(REPLACE(REPLACE(TRIM(p_keyword), '!', '!!'), '%', '!%'), '_', '!_'),
            '%');
    END IF;

    IF p_sort IN ('newest', 'price_asc', 'price_desc') THEN
        SET v_sort = p_sort;
    END IF;

    SELECT
        t.tour_id,
        t.title,
        t.summary,
        t.destination_id,
        d.name                          AS destination_name,
        c.name                          AS category_name,
        p.name                          AS provider_name,
        p.is_verified                   AS provider_verified,
        t.duration_hours,
        t.max_group_size,
        t.languages,
        t.price_per_person,
        t.meeting_point,
        ci.image_path                   AS cover_image,
        ci.caption                      AS cover_caption,
        rs.rating_avg,
        COALESCE(rs.review_count, 0)    AS review_count,
        (SELECT MIN(s.departure_date)
           FROM tour_schedules s
          WHERE s.tour_id = t.tour_id
            AND s.status = 'open'
            AND s.departure_date >= CURDATE()
            AND s.seats_booked < s.seats_total) AS next_departure_date,
        t.created_at
    FROM tours t
    JOIN providers    p ON p.provider_id    = t.provider_id
    JOIN destinations d ON d.destination_id = t.destination_id
    JOIN categories   c ON c.category_id    = t.category_id
    LEFT JOIN tour_images ci
           ON ci.image_id = (SELECT i.image_id
                               FROM tour_images i
                              WHERE i.tour_id = t.tour_id
                              ORDER BY i.sort_order, i.image_id
                              LIMIT 1)
    LEFT JOIN (SELECT r.tour_id,
                      CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1)) AS rating_avg,
                      COUNT(*)                                      AS review_count
                 FROM reviews r
                GROUP BY r.tour_id) rs
           ON rs.tour_id = t.tour_id
    WHERE t.status = 'published'
      AND p.is_active = 1
      AND (p_destination_id IS NULL OR p_destination_id = 0 OR t.destination_id = p_destination_id)
      AND (v_pattern IS NULL
           OR t.title   LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR t.summary LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR d.name    LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR p.name    LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!')
    ORDER BY
        CASE WHEN v_sort = 'price_asc'   THEN t.price_per_person END ASC,
        CASE WHEN v_sort = 'price_desc'  THEN t.price_per_person END DESC,
        CASE WHEN v_sort = 'newest'      THEN t.created_at END DESC,
        CASE WHEN v_sort = 'newest'      THEN t.tour_id END DESC,
        CASE WHEN v_sort = 'recommended' THEN (rs.rating_avg IS NULL) END ASC,
        CASE WHEN v_sort = 'recommended' THEN rs.rating_avg END DESC,
        CASE WHEN v_sort = 'recommended' THEN COALESCE(rs.review_count, 0) END DESC,
        t.tour_id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_destination_list()
--   Điểm đến cho bộ lọc và thanh bên, kèm số tour đang hiển thị
--   (published + đơn vị đang hoạt động). Điểm đến chưa có tour vẫn được liệt kê.
--   Cột trả về: destination_id, name, slug, tour_count. Sắp xếp sort_order, name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_destination_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_destination_list()
READS SQL DATA
BEGIN
    SELECT
        d.destination_id,
        d.name,
        d.slug,
        (SELECT COUNT(*)
           FROM tours t
           JOIN providers p ON p.provider_id = t.provider_id
          WHERE t.destination_id = d.destination_id
            AND t.status = 'published'
            AND p.is_active = 1) AS tour_count
    FROM destinations d
    ORDER BY d.sort_order, d.name;
END$$
DELIMITER ;
