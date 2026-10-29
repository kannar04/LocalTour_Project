-- =====================================================================
-- LocalTour v0.1 - 04_procedures_NMT.sql
-- Mục đích  : Stored procedures cho trang chi tiết tour (thông tin chính kèm điểm đến,
--             loại hình, phương tiện, điều kiện; lịch khởi hành đặt được, loại vé và
--             giá vé, bộ ảnh của tour) và trang thống kê của quản trị viên (FR-19 -> FR-23).
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.4
-- Procedures: NMT_sp_tour_detail, NMT_sp_tour_schedule_list, NMT_sp_tour_ticket_list,
--             NMT_sp_tour_image_list, NMT_sp_admin_summary,
--             NMT_sp_admin_booking_status_stats, NMT_sp_admin_booking_time_stats,
--             NMT_sp_admin_revenue_stats
-- Quy tắc   : Trang chi tiết tour chỉ trả dữ liệu của tour đang hiển thị: tours.approval_status = 'approved'
--             VÀ providers.approval_status = 'approved' VÀ users.status = 'active'
--             (tài khoản của nhà cung cấp). Tour khác hoặc không tồn tại -> 0 dòng.
--             Lịch đặt được: status = 'open', starts_at > NOW(), remaining > 0 và có
--             ít nhất một loại vé active.
--             p_tour_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Thống kê: tính trên toàn hệ thống, quy tắc ở phần "Trang quản trị" cuối file.
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

-- =====================================================================
-- Trang quản trị: thống kê (FR-19 -> FR-23)
--   Các procedure dưới đây KHÔNG lọc tour công khai: số liệu tính trên toàn hệ thống.
--   Chỉ trang quản trị gọi chúng (ứng dụng kiểm tra tài khoản quản trị viên trước).
--   p_period: 'day' | 'month' | 'year'; giá trị khác = 'month'.
--   p_from / p_to: khoảng ngày (tính cả hai đầu). NULL = không giới hạn đầu đó.
--   Chỉ trả các kỳ có dữ liệu; kỳ trống do giao diện tự bỏ qua.
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_summary()
--   1 dòng. Cột: customer_total, customer_active, customer_locked (FR-19, tài khoản
--   role = 'customer'), tour_total, tour_draft, tour_pending, tour_approved,
--   tour_rejected (FR-20), tour_public (đang hiển thị cho khách), booking_total,
--   booking_pending (yêu cầu chờ xác nhận, cần quản trị viên xử lý).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_summary;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_summary()
READS SQL DATA
BEGIN
    SELECT
        cu.customer_total,
        cu.customer_active,
        cu.customer_locked,
        tr.tour_total,
        tr.tour_draft,
        tr.tour_pending,
        tr.tour_approved,
        tr.tour_rejected,
        tr.tour_public,
        bk.booking_total,
        bk.booking_pending
    FROM (SELECT COUNT(*)                      AS customer_total,
                 COALESCE(SUM(status = 'active'), 0) AS customer_active,
                 COALESCE(SUM(status = 'locked'), 0) AS customer_locked
            FROM users
           WHERE role = 'customer') cu
    CROSS JOIN
         (SELECT COUNT(*)                                     AS tour_total,
                 COALESCE(SUM(t.approval_status = 'draft'), 0)    AS tour_draft,
                 COALESCE(SUM(t.approval_status = 'pending'), 0)  AS tour_pending,
                 COALESCE(SUM(t.approval_status = 'approved'), 0) AS tour_approved,
                 COALESCE(SUM(t.approval_status = 'rejected'), 0) AS tour_rejected,
                 COALESCE(SUM(t.approval_status = 'approved'
                              AND p.approval_status = 'approved'
                              AND u.status = 'active'), 0)        AS tour_public
            FROM tours t
            JOIN providers p ON p.id = t.provider_id
            JOIN users     u ON u.id = p.user_id) tr
    CROSS JOIN
         (SELECT COUNT(*)                            AS booking_total,
                 COALESCE(SUM(status = 'pending'), 0) AS booking_pending
            FROM bookings) bk;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_booking_status_stats()
--   FR-21. Luôn 6 dòng, kể cả trạng thái chưa có yêu cầu nào.
--   Cột: status, booking_count. Thứ tự theo luồng xử lý.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_booking_status_stats;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_booking_status_stats()
READS SQL DATA
BEGIN
    SELECT
        st.status,
        COUNT(b.id) AS booking_count
    FROM (SELECT 1 AS sort_order, 'pending' AS status
          UNION ALL SELECT 2, 'awaiting_payment'
          UNION ALL SELECT 3, 'confirmed'
          UNION ALL SELECT 4, 'completed'
          UNION ALL SELECT 5, 'rejected'
          UNION ALL SELECT 6, 'cancelled') st
    LEFT JOIN bookings b ON b.status = (st.status COLLATE utf8mb4_unicode_ci)
    GROUP BY st.sort_order, st.status
    ORDER BY st.sort_order;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_booking_time_stats(p_period, p_from, p_to)
--   FR-22. Số yêu cầu đặt tour theo ngày tạo (bookings.created_at), mọi trạng thái.
--   Cột: period_key ('YYYY-MM-DD' | 'YYYY-MM' | 'YYYY'), booking_count.
--   Sắp xếp period_key tăng dần.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_booking_time_stats;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_booking_time_stats(
    IN p_period VARCHAR(10),
    IN p_from   DATE,
    IN p_to     DATE
)
READS SQL DATA
BEGIN
    DECLARE v_format VARCHAR(10) DEFAULT '%Y-%m';

    IF p_period = 'day' THEN
        SET v_format = '%Y-%m-%d';
    ELSEIF p_period = 'year' THEN
        SET v_format = '%Y';
    END IF;

    SELECT
        DATE_FORMAT(b.created_at, v_format) AS period_key,
        COUNT(*)                            AS booking_count
    FROM bookings b
    WHERE (p_from IS NULL OR b.created_at >= p_from)
      AND (p_to IS NULL OR b.created_at < p_to + INTERVAL 1 DAY)
    GROUP BY period_key
    ORDER BY period_key;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_revenue_stats(p_period, p_from, p_to)
--   FR-23. Doanh thu theo ngày thanh toán (payments.paid_at) của khoản 'paid'.
--   Cột: period_key, paid_count, gross_vnd (tổng tiền đã thanh toán), refund_vnd (tiền
--   đã hoàn, refunds.status = 'completed', tính vào kỳ của khoản thanh toán gốc),
--   net_vnd = gross_vnd - refund_vnd. Sắp xếp period_key tăng dần.
--   Tiền hoàn được cộng trước theo từng khoản thanh toán để không bị nhân dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_revenue_stats;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_revenue_stats(
    IN p_period VARCHAR(10),
    IN p_from   DATE,
    IN p_to     DATE
)
READS SQL DATA
BEGIN
    DECLARE v_format VARCHAR(10) DEFAULT '%Y-%m';

    IF p_period = 'day' THEN
        SET v_format = '%Y-%m-%d';
    ELSEIF p_period = 'year' THEN
        SET v_format = '%Y';
    END IF;

    SELECT
        DATE_FORMAT(p.paid_at, v_format)                AS period_key,
        COUNT(*)                                        AS paid_count,
        SUM(p.amount_vnd)                               AS gross_vnd,
        COALESCE(SUM(r.refund_vnd), 0)                  AS refund_vnd,
        SUM(p.amount_vnd) - COALESCE(SUM(r.refund_vnd), 0) AS net_vnd
    FROM payments p
    LEFT JOIN (SELECT payment_id, SUM(amount_vnd) AS refund_vnd
                 FROM refunds
                WHERE status = 'completed'
                GROUP BY payment_id) r
           ON r.payment_id = p.id
    WHERE p.status = 'paid'
      AND p.paid_at IS NOT NULL
      AND (p_from IS NULL OR p.paid_at >= p_from)
      AND (p_to IS NULL OR p.paid_at < p_to + INTERVAL 1 DAY)
    GROUP BY period_key
    ORDER BY period_key;
END$$
DELIMITER ;
