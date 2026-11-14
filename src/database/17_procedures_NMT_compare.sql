-- =====================================================================
-- LocalTour v0.4 - 17_procedures_NMT_compare.sql
-- Mục đích  : Dữ liệu so sánh 2 - 3 tour (US04-S5-02, FR-15): một dòng cho mỗi tour đang hiển
--             thị, cùng đơn vị để đặt cạnh nhau (giá theo người lớn / người, thời lượng theo
--             phút, quy mô nhóm theo khách, chính sách hủy theo giờ và phần trăm).
--             Ô thiếu dữ liệu trả NULL; trang so sánh hiện "Chưa cập nhật" (CompareModel).
-- Phụ trách : Nguyễn Minh Thức (NMT) - Sprint 5
-- Procedures: NMT_sp_tour_compare
-- Quy tắc   : Lịch đặt được: 'open', còn chỗ, có vé đang bán và còn hơn
--             settings.booking_cutoff_minutes phút (mặc định 60) mới tới giờ khởi hành, giống
--             trang chi tiết tour (file 04) và LTP_sp_booking_create (file 10).
-- Chạy sau  : 16_migration_sprint5_LTP.sql (bảng tour_packages). Khi gọi cần bảng settings
--             (28_migration_economy_NTK.sql). Chạy lại được.
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_tour_compare(p_tour_ids)
--   p_tour_ids: mã tour cách nhau bởi dấu phẩy, không khoảng trắng, theo thứ tự khách chọn,
--               vd. 'c000...0001,c000...0005'. Tối đa 3 tour (ứng dụng chặn trước); tour không
--               có hoặc đang ẩn bị bỏ qua.
--   Mỗi tour một dòng, theo thứ tự trong p_tour_ids. Cột:
--     tour_id, title, provider_name, destination_name, category_name, cover_image_url,
--     cover_alt_text, duration_minutes, max_group_size, language_codes, pickup_mode,
--     meeting_point, dropoff_point, transport, guide_info, meal_terms, reschedule_terms,
--     from_price_vnd (giá người lớn thấp nhất / người: gói đang bán thấp nhất nếu tour có gói,
--                     ngược lại vé 'adult' active thấp nhất của các lịch đặt được),
--     child_from_price_vnd (giá trẻ em thấp nhất / người, cùng cách tính; NULL = không bán),
--     package_count, package_names (tên các gói, ngăn bởi ' · '),
--     next_starts_at, schedule_count (số lịch đặt được),
--     policy_version, free_before_hours, refund_percent (chính sách hủy mới nhất),
--     rating_avg, review_count,
--     included_items, excluded_items (ngăn bởi xuống dòng, theo sort_order),
--     itinerary_items ("HH:MM mô tả" hoặc "mô tả", ngăn bởi xuống dòng),
--     extras_items ("Tên: giá đ / đơn vị" hoặc "Tên: giá cập nhật sau", ngăn bởi xuống dòng).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_compare;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_compare(
    IN p_tour_ids VARCHAR(200)
)
READS SQL DATA
BEGIN
    DECLARE v_ids VARCHAR(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT REPLACE(COALESCE(p_tour_ids, ''), ' ', '');
    -- Ngừng nhận đặt trước giờ khởi hành bao nhiêu phút (file 28).
    DECLARE v_cutoff_min INT DEFAULT 60;

    SET v_cutoff_min = COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,5}$', CAST(st.value AS UNSIGNED), NULL)
                                   FROM settings st WHERE st.name = 'booking_cutoff_minutes'), 60);

    -- Danh sách bao gồm / lịch trình có thể dài hơn giới hạn mặc định 1024 ký tự.
    SET SESSION group_concat_max_len = 16384;

    SELECT
        t.id                AS tour_id,
        t.title,
        p.business_name     AS provider_name,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        ci.url              AS cover_image_url,
        ci.alt_text         AS cover_alt_text,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.dropoff_point,
        t.transport,
        t.guide_info,
        t.meal_terms,
        t.reschedule_terms,
        IF(bs.tour_id IS NULL, NULL, COALESCE(pk.adult_from, bs.adult_from)) AS from_price_vnd,
        IF(bs.tour_id IS NULL, NULL,
           IF(pk.tour_id IS NULL, bs.child_from, IF(bs.has_child, pk.child_from, NULL))) AS child_from_price_vnd,
        COALESCE(pk.package_count, 0) AS package_count,
        pk.package_names,
        bs.next_starts_at,
        COALESCE(bs.schedule_count, 0) AS schedule_count,
        cp.version          AS policy_version,
        cp.free_before_hours,
        cp.refund_percent,
        rs.rating_avg,
        COALESCE(rs.review_count, 0) AS review_count,
        (SELECT GROUP_CONCAT(i.item_text ORDER BY i.sort_order, i.id SEPARATOR '\n')
           FROM tour_inclusions i WHERE i.tour_id = t.id AND i.is_included = TRUE) AS included_items,
        (SELECT GROUP_CONCAT(i.item_text ORDER BY i.sort_order, i.id SEPARATOR '\n')
           FROM tour_inclusions i WHERE i.tour_id = t.id AND i.is_included = FALSE) AS excluded_items,
        (SELECT GROUP_CONCAT(CONCAT(IF(it.start_time IS NULL, '', CONCAT(TIME_FORMAT(it.start_time, '%H:%i'), ' ')),
                                    it.description)
                             ORDER BY it.sort_order, it.start_time, it.id SEPARATOR '\n')
           FROM tour_itinerary_items it WHERE it.tour_id = t.id) AS itinerary_items,
        (SELECT GROUP_CONCAT(CONCAT(te.name, ': ',
                                    IF(te.price_vnd IS NULL, 'giá cập nhật sau',
                                       CONCAT(REPLACE(FORMAT(te.price_vnd, 0), ',', '.'), 'đ',
                                              IF(NULLIF(TRIM(te.price_unit), '') IS NULL, ' / nhóm',
                                                 CONCAT(' / ', TRIM(te.price_unit))))))
                             ORDER BY te.kind, te.sort_order, te.id SEPARATOR '\n')
           FROM tour_extras te WHERE te.tour_id = t.id) AS extras_items
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    -- Lịch đặt được: giá vé thấp nhất theo loại, lịch gần nhất, số lịch
    LEFT JOIN (SELECT s.tour_id,
                      MIN(s.starts_at) AS next_starts_at,
                      COUNT(DISTINCT s.id) AS schedule_count,
                      MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS adult_from,
                      MIN(CASE WHEN tt.name = 'child' THEN tt.price_vnd END) AS child_from,
                      MAX(tt.name = 'child') AS has_child
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                WHERE FIND_IN_SET(s.tour_id, v_ids) > 0
                  AND s.status = 'open'
                  AND s.starts_at > NOW() + INTERVAL v_cutoff_min MINUTE
                  AND s.remaining > 0
                GROUP BY s.tour_id) bs
           ON bs.tour_id = t.id
    -- Gói đang bán
    LEFT JOIN (SELECT tp.tour_id,
                      COUNT(*) AS package_count,
                      MIN(tp.adult_price_vnd) AS adult_from,
                      MIN(tp.child_price_vnd) AS child_from,
                      GROUP_CONCAT(tp.name ORDER BY tp.sort_order, tp.adult_price_vnd, tp.name SEPARATOR ' · ') AS package_names
                 FROM tour_packages tp
                WHERE tp.active = TRUE
                  AND FIND_IN_SET(tp.tour_id, v_ids) > 0
                GROUP BY tp.tour_id) pk
           ON pk.tour_id = t.id
    -- Chính sách hủy mới nhất
    LEFT JOIN cancellation_policies cp
           ON cp.tour_id = t.id
          AND cp.version = (SELECT MAX(cp2.version) FROM cancellation_policies cp2 WHERE cp2.tour_id = t.id)
    -- Đánh giá đã duyệt
    LEFT JOIN (SELECT r.tour_id,
                      CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1)) AS rating_avg,
                      COUNT(*) AS review_count
                 FROM reviews r
                WHERE r.moderation_status = 'approved'
                  AND FIND_IN_SET(r.tour_id, v_ids) > 0
                GROUP BY r.tour_id) rs
           ON rs.tour_id = t.id
    -- Ảnh bìa: ảnh có sort_order nhỏ nhất
    LEFT JOIN tour_images ci
           ON ci.id = (SELECT ti.id FROM tour_images ti
                        WHERE ti.tour_id = t.id
                        ORDER BY ti.sort_order, ti.id LIMIT 1)
    WHERE FIND_IN_SET(t.id, v_ids) > 0
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY FIND_IN_SET(t.id, v_ids)
    LIMIT 3;
END$$
DELIMITER ;
