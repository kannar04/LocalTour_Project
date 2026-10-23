-- =====================================================================
-- LocalTour v0.1 - 04_procedures_NMT.sql
-- Mục đích  : Stored procedures cho trang chi tiết tour (thông tin chính kèm điểm đến,
--             loại hình, phương tiện, điều kiện; lịch khởi hành đặt được, loại vé và
--             giá vé, bộ ảnh của tour).
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.4
-- Procedures: NMT_sp_tour_detail, NMT_sp_tour_schedule_list, NMT_sp_tour_ticket_list,
--             NMT_sp_tour_image_list
-- Quy tắc   : Chỉ trả dữ liệu của tour đang hiển thị: tours.approval_status = 'approved'
--             VÀ providers.approval_status = 'approved' VÀ users.status = 'active'
--             (tài khoản của nhà cung cấp). Tour khác hoặc không tồn tại -> 0 dòng.
--             Lịch đặt được: status = 'open', starts_at > NOW(), remaining > 0 và có
--             ít nhất một loại vé active.
--             p_tour_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- Procedure của thiết kế cũ: lịch trình nay đọc bằng NTK_sp_tour_itinerary_list (file 05).
DROP PROCEDURE IF EXISTS NMT_sp_tour_itinerary_list;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_detail(p_tour_id)
--   0 hoặc 1 dòng. Cột: tour_id, provider_id, title, description, destination_id,
--   destination_name (destinations.name; tour chưa gán destination_id thì dùng
--   tours.destination), category_id, category_name (NULL nếu chưa gán loại hình),
--   duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point,
--   provider_name, provider_approved_at,
--   rating_avg (DECIMAL(2,1), NULL nếu chưa có đánh giá đã duyệt), review_count,
--   from_price_vnd (vé 'adult' active rẻ nhất trong các lịch đặt được; NULL nếu không
--   có lịch đặt được hoặc không lịch nào còn vé người lớn đang bán), next_starts_at,
--   transport, guide_info, dropoff_point (FR-02),
--   document_terms, meal_terms, voucher_terms, reschedule_terms (FR-05).
--   7 cột cuối NULL = chưa cập nhật (giao diện hiện "Chưa cập nhật").
--   Dịch vụ bao gồm / không bao gồm (FR-04) đọc bằng NTK_sp_tour_inclusion_list (file 05).
--   Không trả các cột NFR-07 (source_url, verified_at, verification_status):
--   chúng dành cho trang quản trị sau này.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_detail;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_detail(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                AS tour_id,
        t.provider_id,
        t.title,
        t.description,
        t.destination_id,
        COALESCE(d.name, t.destination) AS destination_name,
        t.category_id,
        c.name              AS category_name,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        p.business_name     AS provider_name,
        p.approved_at       AS provider_approved_at,
        (SELECT CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1))
           FROM reviews r
          WHERE r.tour_id = t.id
            AND r.moderation_status = 'approved') AS rating_avg,
        (SELECT COUNT(*)
           FROM reviews r
          WHERE r.tour_id = t.id
            AND r.moderation_status = 'approved') AS review_count,
        bs.from_price_vnd,
        bs.next_starts_at,
        t.transport,                -- FR-02 phương tiện
        t.guide_info,               -- FR-02 hướng dẫn viên
        t.dropoff_point,            -- FR-02 điểm trả
        t.document_terms,           -- FR-05 giấy tờ
        t.meal_terms,               -- FR-05 ăn uống
        t.voucher_terms,            -- FR-05 voucher
        t.reschedule_terms          -- FR-05 đổi lịch
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    -- Lịch đặt được của tour: giá "Từ" và lịch khởi hành gần nhất
    LEFT JOIN (SELECT s.tour_id,
                      MIN(s.starts_at) AS next_starts_at,
                      MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS from_price_vnd
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                  AND s.status = 'open'
                  AND s.starts_at > NOW()
                  AND s.remaining > 0
                GROUP BY s.tour_id) bs
           ON bs.tour_id = t.id
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_schedule_list(p_tour_id)
--   Các lịch đặt được của tour.
--   Cột: schedule_id, starts_at, ends_at, capacity, remaining,
--        from_price_vnd (vé 'adult' active rẻ nhất của lịch; lịch chỉ còn vé trẻ em
--        đang bán vẫn được trả về nhưng from_price_vnd = NULL, không lấy giá trẻ em
--        thay thế, FR-10). Sắp xếp starts_at, schedule_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_schedule_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_schedule_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id            AS schedule_id,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS from_price_vnd
    FROM schedules s
    JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
      AND s.status = 'open'
      AND s.starts_at > NOW()
      AND s.remaining > 0
    GROUP BY s.id, s.starts_at, s.ends_at, s.capacity, s.remaining
    ORDER BY s.starts_at, s.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_ticket_list(p_tour_id)
--   Các loại vé active của mọi lịch đặt được (giao diện lọc theo schedule_id
--   khi khách chọn lịch).
--   Cột: ticket_type_id, schedule_id, name ('adult', 'child', ...), min_age, max_age
--        (NULL = không giới hạn), price_vnd.
--   Sắp xếp: lịch sớm trước; trong một lịch vé đắt trước (người lớn trước trẻ em), rồi name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_ticket_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_ticket_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tt.id           AS ticket_type_id,
        tt.schedule_id,
        tt.name,
        tt.min_age,
        tt.max_age,
        tt.price_vnd
    FROM ticket_types tt
    JOIN schedules s ON s.id = tt.schedule_id
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
      AND s.status = 'open'
      AND s.starts_at > NOW()
      AND s.remaining > 0
      AND tt.active = TRUE
    ORDER BY s.starts_at, s.id, tt.price_vnd DESC, tt.name, tt.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_image_list(p_tour_id)
--   Bộ ảnh (gallery) của chính tour đó, không lấy ảnh của tour khác.
--   Cột: image_id, url (tương đối từ src/public/assets/ hoặc http(s)://...),
--        alt_text (NULL nếu chưa có mô tả ảnh), sort_order.
--   Sắp xếp sort_order, rồi image_id. Ảnh đầu tiên = ảnh bìa ở trang danh sách.
--   Tour không hiển thị hoặc chưa có ảnh -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_image_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_image_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        ti.id           AS image_id,
        ti.url,
        ti.alt_text,
        ti.sort_order
    FROM tour_images ti
    JOIN tours     t ON t.id = ti.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE ti.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY ti.sort_order ASC, ti.id ASC;
END$$
DELIMITER ;
