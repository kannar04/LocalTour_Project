-- =====================================================================
-- LocalTour v0.1 - 05_procedures_NTK.sql
-- Mục đích  : Stored procedures cho nội dung trang chi tiết tour
--             (đánh giá của khách, chính sách hủy, lịch trình theo từng chặng,
--             phụ thu / hoạt động tùy chọn).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - WBS 3.2.6
-- Procedures: NTK_sp_tour_review_list, NTK_sp_tour_cancellation_policy,
--             NTK_sp_tour_itinerary_list, NTK_sp_tour_extra_list
-- Quy tắc   : Chỉ trả dữ liệu của tour đang hiển thị: tours.approval_status = 'approved'
--             VÀ providers.approval_status = 'approved' VÀ users.status = 'active'
--             (tài khoản của nhà cung cấp). Tour khác hoặc không tồn tại -> 0 dòng.
--             p_tour_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- Procedure của thiết kế cũ: bộ ảnh nay đọc bằng NMT_sp_tour_image_list (file 04);
-- bảng tour_inclusions không còn trong ERD (nay là tours.included_summary).
DROP PROCEDURE IF EXISTS NTK_sp_tour_image_list;
DROP PROCEDURE IF EXISTS NTK_sp_tour_inclusion_list;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_review_list(p_tour_id, p_limit)
--   Chỉ đánh giá moderation_status = 'approved'.
--   Cột: review_id, reviewer_name (= bookings.contact_name của đơn được đánh giá;
--        khách không có tài khoản), rating, content,
--        tour_date (giờ khởi hành của lịch trong đơn được đánh giá).
--   Sắp xếp: tour_date mới nhất trước. p_limit NULL hoặc 0 = lấy 5 đánh giá.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_review_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_review_list(
    IN p_tour_id CHAR(36),
    IN p_limit   TINYINT UNSIGNED
)
READS SQL DATA
BEGIN
    DECLARE v_limit INT UNSIGNED DEFAULT 5;

    IF p_limit IS NOT NULL AND p_limit > 0 THEN
        SET v_limit = p_limit;
    END IF;

    SELECT
        r.id            AS review_id,
        b.contact_name  AS reviewer_name,
        r.rating,
        r.content,
        s.starts_at     AS tour_date
    FROM reviews r
    JOIN bookings  b  ON b.id  = r.booking_id       -- đơn được đánh giá (tên người đặt)
    JOIN schedules s  ON s.id  = b.schedule_id
    JOIN tours     t  ON t.id  = r.tour_id
    JOIN providers p  ON p.id  = t.provider_id
    JOIN users     u  ON u.id  = p.user_id          -- tài khoản của nhà cung cấp
    WHERE r.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND r.moderation_status = 'approved'
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY s.starts_at DESC, r.id DESC
    LIMIT v_limit;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_cancellation_policy(p_tour_id)
--   0 hoặc 1 dòng: phiên bản chính sách hủy mới nhất (version lớn nhất) của tour.
--   Cột: policy_id, free_before_hours (NULL = không có hủy miễn phí),
--        refund_percent, terms, version.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_cancellation_policy;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_cancellation_policy(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        cp.id           AS policy_id,
        cp.free_before_hours,
        cp.refund_percent,
        cp.terms,
        cp.version
    FROM cancellation_policies cp
    JOIN tours     t ON t.id = cp.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE cp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY cp.version DESC
    LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_itinerary_list(p_tour_id)
--   Các chặng trong lịch trình của tour, theo đúng thứ tự stop_order.
--   Cột: stop_id, stop_order, title, description (NULL = chưa có mô tả),
--        duration_minutes (NULL = chưa có thời lượng; giao diện chỉ hiện khi có).
--   Sắp xếp stop_order, rồi stop_id. Tour không hiển thị hoặc chưa có lịch trình -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_itinerary_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_itinerary_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        st.id           AS stop_id,
        st.stop_order,
        st.title,
        st.description,
        st.duration_minutes
    FROM itinerary_stops st
    JOIN tours     t ON t.id = st.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE st.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY st.stop_order ASC, st.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_extra_list(p_tour_id)
--   Phụ thu và hoạt động tùy chọn của tour (FR-04, FR-10). Giá tách riêng,
--   không cộng vào giá tour hay tổng đơn.
--   Cột: extra_id, kind ('surcharge' = phụ thu, 'optional' = hoạt động tùy chọn),
--        name, price_vnd (NULL = chưa cập nhật giá), price_unit (NULL = không ghi
--        đơn vị), conditions (NULL = không có điều kiện), sort_order.
--   Sắp xếp: phụ thu trước, rồi sort_order, rồi extra_id.
--   Tour không hiển thị hoặc chưa có dòng nào -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_extra_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_extra_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        te.id           AS extra_id,
        te.kind,
        te.name,
        te.price_vnd,
        te.price_unit,
        te.conditions,
        te.sort_order
    FROM tour_extras te
    JOIN tours     t ON t.id = te.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE te.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY te.kind = 'surcharge' DESC, te.sort_order ASC, te.id ASC;
END$$
DELIMITER ;
