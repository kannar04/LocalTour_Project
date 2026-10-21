-- =====================================================================
-- LocalTour v0.1 - 04_procedures_NMT.sql
-- Mục đích  : Stored procedures cho trang chi tiết tour (thông tin chính,
--             lịch khởi hành, lịch trình).
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.4
-- Procedures: NMT_sp_tour_detail, NMT_sp_tour_schedule_list, NMT_sp_tour_itinerary_list
-- Quy tắc   : Chỉ trả dữ liệu của tour status = 'published' thuộc đơn vị is_active = 1;
--             tour ẩn hoặc không tồn tại -> 0 dòng. Chỉ đọc, không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_tour_detail(p_tour_id)
--   0 hoặc 1 dòng. Cột: mọi cột của tours trừ status, cộng thêm
--   destination_name, category_name, provider_name, provider_description,
--   provider_verified, rating_avg (DECIMAL(2,1), NULL nếu chưa có đánh giá),
--   review_count (0 nếu chưa có).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_detail;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_detail(
    IN p_tour_id INT UNSIGNED
)
READS SQL DATA
BEGIN
    SELECT
        t.tour_id,
        t.provider_id,
        t.destination_id,
        t.category_id,
        t.title,
        t.summary,
        t.description,
        t.duration_hours,
        t.max_group_size,
        t.languages,
        t.price_per_person,
        t.price_note,
        t.meeting_point,
        t.meeting_note,
        t.transport_note,
        t.cancellation_policy,
        t.created_at,
        t.updated_at,
        d.name          AS destination_name,
        c.name          AS category_name,
        p.name          AS provider_name,
        p.description   AS provider_description,
        p.is_verified   AS provider_verified,
        (SELECT CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1))
           FROM reviews r
          WHERE r.tour_id = t.tour_id) AS rating_avg,
        (SELECT COUNT(*)
           FROM reviews r
          WHERE r.tour_id = t.tour_id) AS review_count
    FROM tours t
    JOIN providers    p ON p.provider_id    = t.provider_id
    JOIN destinations d ON d.destination_id = t.destination_id
    JOIN categories   c ON c.category_id    = t.category_id
    WHERE t.tour_id = p_tour_id
      AND t.status = 'published'
      AND p.is_active = 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_schedule_list(p_tour_id)
--   Lịch khởi hành sắp tới còn đặt được: departure_date >= hôm nay,
--   status = 'open', còn chỗ (seats_booked < seats_total).
--   Cột: schedule_id, departure_date, start_time, seats_left. Sắp xếp ngày, giờ.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_schedule_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_schedule_list(
    IN p_tour_id INT UNSIGNED
)
READS SQL DATA
BEGIN
    SELECT
        s.schedule_id,
        s.departure_date,
        s.start_time,
        CAST(s.seats_total AS SIGNED) - CAST(s.seats_booked AS SIGNED) AS seats_left
    FROM tour_schedules s
    JOIN tours     t ON t.tour_id     = s.tour_id
    JOIN providers p ON p.provider_id = t.provider_id
    WHERE s.tour_id = p_tour_id
      AND t.status = 'published'
      AND p.is_active = 1
      AND s.status = 'open'
      AND s.departure_date >= CURDATE()
      AND s.seats_booked < s.seats_total
    ORDER BY s.departure_date, s.start_time, s.schedule_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_itinerary_list(p_tour_id)
--   Cột: start_time (NULL = giờ linh hoạt), description. Sắp xếp sort_order, item_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_itinerary_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_itinerary_list(
    IN p_tour_id INT UNSIGNED
)
READS SQL DATA
BEGIN
    SELECT
        it.start_time,
        it.description
    FROM tour_itinerary_items it
    JOIN tours     t ON t.tour_id     = it.tour_id
    JOIN providers p ON p.provider_id = t.provider_id
    WHERE it.tour_id = p_tour_id
      AND t.status = 'published'
      AND p.is_active = 1
    ORDER BY it.sort_order, it.item_id;
END$$
DELIMITER ;
