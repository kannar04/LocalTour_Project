-- =====================================================================
-- LocalTour v0.1 - 05_procedures_NTK.sql
-- Mục đích  : Stored procedures cho nội dung trang chi tiết tour
--             (bộ ảnh, chi phí bao gồm / không gồm, đánh giá của khách).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - WBS 3.2.6
-- Procedures: NTK_sp_tour_image_list, NTK_sp_tour_inclusion_list, NTK_sp_tour_review_list
-- Quy tắc   : Chỉ trả dữ liệu của tour status = 'published' thuộc đơn vị is_active = 1;
--             tour ẩn hoặc không tồn tại -> 0 dòng. Chỉ đọc, không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_tour_image_list(p_tour_id)
--   Cột: image_id, image_path (NULL = chưa có ảnh), caption. Sắp xếp sort_order, image_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_image_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_image_list(
    IN p_tour_id INT UNSIGNED
)
READS SQL DATA
BEGIN
    SELECT
        i.image_id,
        i.image_path,
        i.caption
    FROM tour_images i
    JOIN tours     t ON t.tour_id     = i.tour_id
    JOIN providers p ON p.provider_id = t.provider_id
    WHERE i.tour_id = p_tour_id
      AND t.status = 'published'
      AND p.is_active = 1
    ORDER BY i.sort_order, i.image_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_inclusion_list(p_tour_id)
--   Cột: item_text, is_included (1 = bao gồm, 0 = không gồm).
--   Mục "bao gồm" đứng trước, sau đó theo sort_order.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_inclusion_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_inclusion_list(
    IN p_tour_id INT UNSIGNED
)
READS SQL DATA
BEGIN
    SELECT
        inc.item_text,
        inc.is_included
    FROM tour_inclusions inc
    JOIN tours     t ON t.tour_id     = inc.tour_id
    JOIN providers p ON p.provider_id = t.provider_id
    WHERE inc.tour_id = p_tour_id
      AND t.status = 'published'
      AND p.is_active = 1
    ORDER BY inc.is_included DESC, inc.sort_order, inc.inclusion_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_review_list(p_tour_id, p_limit)
--   Cột: reviewer_name, rating, comment, created_at. Mới nhất trước.
--   p_limit NULL hoặc 0 = lấy 5 đánh giá.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_review_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_review_list(
    IN p_tour_id INT UNSIGNED,
    IN p_limit   TINYINT UNSIGNED
)
READS SQL DATA
BEGIN
    DECLARE v_limit INT UNSIGNED DEFAULT 5;

    IF p_limit IS NOT NULL AND p_limit > 0 THEN
        SET v_limit = p_limit;
    END IF;

    SELECT
        r.reviewer_name,
        r.rating,
        r.comment,
        r.created_at
    FROM reviews r
    JOIN tours     t ON t.tour_id     = r.tour_id
    JOIN providers p ON p.provider_id = t.provider_id
    WHERE r.tour_id = p_tour_id
      AND t.status = 'published'
      AND p.is_active = 1
    ORDER BY r.created_at DESC, r.review_id DESC
    LIMIT v_limit;
END$$
DELIMITER ;
