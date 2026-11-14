-- =====================================================================
-- LocalTour v0.4 - 19_procedures_LTP_change.sql
-- Mục đích  : Khách gửi yêu cầu đổi ngày / hủy tour (US14-S5-01, US14-S5-02, FR-12): xem chính
--             sách áp dụng cho đơn và số tiền dự kiến hoàn, chọn lịch mới, lưu yêu cầu và lịch
--             sử. Quản trị viên xử lý thủ công ở 20_procedures_LTP_change_admin.sql.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 5
-- Procedures: LTP_sp_change_quote, LTP_sp_change_schedule_options, LTP_sp_change_request_create,
--             LTP_sp_change_request_list
-- Quy tắc   : * Chỉ chủ đơn (tài khoản khách hàng đang hoạt động) gửi được.
--             * Đơn đang 'pending', 'awaiting_payment' hoặc 'confirmed' và chưa tới giờ khởi
--               hành. Mỗi đơn chỉ một yêu cầu 'pending' (khóa dòng đơn FOR UPDATE khi kiểm tra).
--             * Chính sách áp dụng = phiên bản đã lưu cùng đơn (bookings.policy_version):
--               hủy trước (giờ khởi hành - free_before_hours) được hoàn 100% tiền đã trả;
--               sau mốc đó hoàn refund_percent %. free_before_hours NULL = không có mốc hủy
--               miễn phí, luôn hoàn refund_percent %. Đơn không có chính sách (version 0): dự
--               kiến hoàn 0đ, LocalTour xem xét từng trường hợp.
--             * Tiền đã trả = tổng payments 'paid' của đơn. Đơn chưa thanh toán: hoàn 0đ.
--             * Đổi ngày: lịch mới cùng tour, đang mở bán ('open'), còn nhận đặt (giờ khởi hành
--               sau NOW() + settings.booking_cutoff_minutes phút, mặc định 60, như trang đặt tour
--               ở file 10), khác lịch hiện tại và còn đủ chỗ cho số khách của đơn. Giá đơn không
--               đổi.
--             * Lý do bắt buộc, tối đa 500 ký tự.
--             * Chưa tự động hoàn tiền, chưa đổi đơn ở bước này: chỉ lưu yêu cầu, chụp lại chính
--               sách và ghi booking_events 'cancel_requested' / 'change_requested'.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 16_migration_sprint5_LTP.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
--             Đọc bảng settings (28_migration_economy_NTK.sql) lúc chạy.
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_change_quote(p_user_id, p_code)
--   0 hoặc 1 dòng (đơn của tài khoản p_user_id):
--   booking_id, booking_code, booking_status, tour_id, tour_title, schedule_id, starts_at,
--   ends_at, people, total_vnd, policy_version, free_before_hours, refund_percent,
--   policy_terms, free_until (NULL khi không có mốc hủy miễn phí), in_free_window (1/0),
--   paid_vnd, estimated_refund_vnd (nếu hủy ngay bây giờ),
--   can_request (1 = gửi được yêu cầu), block_reason (NULL, 'status', 'departed',
--   'pending_request'), pending_request_id, pending_request_type.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_quote;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_quote(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        q.*,
        (q.block_reason IS NULL) AS can_request
    FROM (
        SELECT
            x.*,
            CASE
                WHEN x.booking_status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN 'status'
                WHEN x.starts_at <= NOW() THEN 'departed'
                WHEN x.pending_request_id IS NOT NULL THEN 'pending_request'
            END AS block_reason,
            FLOOR(x.paid_vnd * IF(x.in_free_window, 100, COALESCE(x.refund_percent, 0)) / 100) AS estimated_refund_vnd
        FROM (
            SELECT
                b.id                AS booking_id,
                b.code              AS booking_code,
                b.status            AS booking_status,
                t.id                AS tour_id,
                t.title             AS tour_title,
                s.id                AS schedule_id,
                s.starts_at,
                s.ends_at,
                (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id) AS people,
                b.total_vnd,
                b.policy_version,
                cp.free_before_hours,
                cp.refund_percent,
                cp.terms            AS policy_terms,
                IF(cp.free_before_hours IS NULL, NULL,
                   s.starts_at - INTERVAL cp.free_before_hours HOUR) AS free_until,
                (cp.free_before_hours IS NOT NULL
                 AND NOW() < s.starts_at - INTERVAL cp.free_before_hours HOUR) AS in_free_window,
                (SELECT COALESCE(SUM(p.amount_vnd), 0) FROM payments p
                  WHERE p.booking_id = b.id AND p.status = 'paid') AS paid_vnd,
                (SELECT r.id FROM booking_change_requests r
                  WHERE r.booking_id = b.id AND r.status = 'pending'
                  ORDER BY r.created_at DESC, r.id LIMIT 1) AS pending_request_id,
                (SELECT r.type FROM booking_change_requests r
                  WHERE r.booking_id = b.id AND r.status = 'pending'
                  ORDER BY r.created_at DESC, r.id LIMIT 1) AS pending_request_type
            FROM bookings b
            JOIN schedules s ON s.id = b.schedule_id
            JOIN tours     t ON t.id = s.tour_id
            LEFT JOIN cancellation_policies cp
                   ON cp.tour_id = t.id AND cp.version = b.policy_version
            WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
              AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
        ) x
    ) q;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_change_schedule_options(p_user_id, p_code)
--   Các lịch khách có thể đổi sang: cùng tour với đơn, 'open', còn nhận đặt (giờ khởi hành sau
--   NOW() + booking_cutoff_minutes phút), khác lịch
--   hiện tại, còn đủ chỗ cho số khách của đơn (đơn chưa giữ chỗ cũng tính như vậy) và có
--   loại vé đang bán cùng tên với mọi dòng vé của đơn (người lớn / trẻ em).
--   Rỗng nếu không phải đơn của tài khoản này.
--   Cột: schedule_id, starts_at, ends_at, remaining. Sắp xếp starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_schedule_options;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_schedule_options(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    DECLARE v_cutoff_min INT DEFAULT 60;

    -- Ngừng nhận đặt trước giờ khởi hành (file 28); thiếu dòng hoặc giá trị không hợp lệ thì dùng 60.
    SET v_cutoff_min = COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,5}$', CAST(st.value AS UNSIGNED), NULL)
                                   FROM settings st WHERE st.name = 'booking_cutoff_minutes'), 60);

    SELECT
        s2.id          AS schedule_id,
        s2.starts_at,
        s2.ends_at,
        s2.remaining
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN schedules s2 ON s2.tour_id = s.tour_id AND s2.id <> s.id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
      AND s2.status = 'open'
      AND s2.starts_at > NOW() + INTERVAL v_cutoff_min MINUTE
      AND s2.remaining >= (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id)
      AND NOT EXISTS (SELECT 1
                        FROM booking_lines bl
                        JOIN ticket_types ot ON ot.id = bl.ticket_type_id
                       WHERE bl.booking_id = b.id
                         AND NOT EXISTS (SELECT 1 FROM ticket_types nt
                                          WHERE nt.schedule_id = s2.id AND nt.name = ot.name
                                            AND nt.active = TRUE))
    ORDER BY s2.starts_at, s2.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_change_request_create(p_user_id, p_code, p_type, p_schedule_id, p_reason)
--   p_type: 'cancel' | 'change_date' (p_schedule_id = lịch mới, bỏ qua với 'cancel').
--   1 dòng: result, field, request_id, estimated_refund_vnd.
--     result = 'ok'                   : đã lưu yêu cầu 'pending'.
--              'forbidden'            : không phải tài khoản khách hàng đang hoạt động.
--              'not_found'            : không có đơn này của tài khoản.
--              'invalid'              : field = type, schedule_id hoặc reason (trống / quá 500 ký tự).
--              'not_allowed'          : đơn không còn ở trạng thái đổi / hủy được.
--              'departed'             : đã tới giờ khởi hành.
--              'pending_exists'       : đơn đang có một yêu cầu chờ xử lý.
--              'schedule_unavailable' : lịch mới không đổi sang được (khác tour, đã đóng, đã
--                                       khởi hành hoặc đã ngừng nhận đặt, trùng lịch hiện tại,
--                                       thiếu loại vé của đơn).
--              'no_seats'             : lịch mới không còn đủ chỗ.
--     Khi không 'ok', không có gì được ghi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_request_create;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_request_create(
    IN p_user_id     CHAR(36),
    IN p_code        VARCHAR(20),
    IN p_type        VARCHAR(20),
    IN p_schedule_id CHAR(36),
    IN p_reason      TEXT CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_type        VARCHAR(20)  DEFAULT COALESCE(p_type, '');
    DECLARE v_reason      TEXT         CHARACTER SET utf8mb4;
    DECLARE v_booking_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_status      VARCHAR(30)  DEFAULT NULL;
    DECLARE v_schedule_id CHAR(36)     DEFAULT NULL;
    DECLARE v_tour_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_starts_at   DATETIME     DEFAULT NULL;
    DECLARE v_policy      INT          DEFAULT 0;
    DECLARE v_free_hours  INT          DEFAULT NULL;
    DECLARE v_percent     INT          DEFAULT NULL;
    DECLARE v_in_free     BOOLEAN      DEFAULT FALSE;
    DECLARE v_paid        BIGINT       DEFAULT 0;
    DECLARE v_refund      BIGINT       DEFAULT 0;
    DECLARE v_people      INT          DEFAULT 0;
    DECLARE v_new_id      CHAR(36)     DEFAULT NULL;
    DECLARE v_new_tour    CHAR(36)     DEFAULT NULL;
    DECLARE v_new_starts  DATETIME     DEFAULT NULL;
    DECLARE v_new_status  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_new_left    INT          DEFAULT 0;
    DECLARE v_request_id  CHAR(36)     DEFAULT UUID();
    DECLARE v_cutoff_min  INT          DEFAULT 60;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_reason = NULLIF(TRIM(p_reason), '');

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'customer' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    IF v_type NOT IN ('cancel', 'change_date') THEN
        SELECT 'invalid' AS result, 'type' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;
    IF v_type = 'change_date' AND NULLIF(TRIM(p_schedule_id), '') IS NULL THEN
        SELECT 'invalid' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;
    IF v_reason IS NULL OR CHAR_LENGTH(v_reason) > 500 THEN
        SELECT 'invalid' AS result, 'reason' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    -- Ngừng nhận đặt trước giờ khởi hành (file 28); thiếu dòng hoặc giá trị không hợp lệ thì dùng 60.
    SET v_cutoff_min = COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,5}$', CAST(st.value AS UNSIGNED), NULL)
                                   FROM settings st WHERE st.name = 'booking_cutoff_minutes'), 60);

    START TRANSACTION;

    -- Khóa dòng đơn: hai yêu cầu gửi cùng lúc chỉ một yêu cầu được lưu.
    SELECT b.id, b.status, b.schedule_id, b.policy_version
      INTO v_booking_id, v_status, v_schedule_id, v_policy
      FROM bookings b
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    SELECT s.tour_id, s.starts_at INTO v_tour_id, v_starts_at
      FROM schedules s
     WHERE s.id = v_schedule_id;

    IF v_status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN
        ROLLBACK;
        SELECT 'not_allowed' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    IF v_starts_at <= NOW() THEN
        ROLLBACK;
        SELECT 'departed' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM booking_change_requests r
                WHERE r.booking_id = v_booking_id AND r.status = 'pending') THEN
        ROLLBACK;
        SELECT 'pending_exists' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
      FROM booking_lines bl
     WHERE bl.booking_id = v_booking_id;

    IF v_type = 'change_date' THEN
        SELECT s.id, s.tour_id, s.starts_at, s.status, s.remaining
          INTO v_new_id, v_new_tour, v_new_starts, v_new_status, v_new_left
          FROM schedules s
         WHERE s.id = (TRIM(p_schedule_id) COLLATE utf8mb4_unicode_ci);

        IF v_new_id IS NULL OR v_new_tour <> v_tour_id OR v_new_id = v_schedule_id
           OR v_new_status <> 'open' OR v_new_starts <= NOW() + INTERVAL v_cutoff_min MINUTE THEN
            ROLLBACK;
            SELECT 'schedule_unavailable' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
            LEAVE proc;
        END IF;

        IF v_new_left < v_people THEN
            ROLLBACK;
            SELECT 'no_seats' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
            LEAVE proc;
        END IF;

        -- Lịch mới phải có loại vé đang bán cùng tên với mọi dòng vé của đơn.
        IF EXISTS (SELECT 1
                     FROM booking_lines bl
                     JOIN ticket_types ot ON ot.id = bl.ticket_type_id
                    WHERE bl.booking_id = v_booking_id
                      AND NOT EXISTS (SELECT 1 FROM ticket_types nt
                                       WHERE nt.schedule_id = v_new_id AND nt.name = ot.name
                                         AND nt.active = TRUE)) THEN
            ROLLBACK;
            SELECT 'schedule_unavailable' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
            LEAVE proc;
        END IF;
    END IF;

    -- Chính sách đã lưu cùng đơn và tiền đã trả: chụp lại vào yêu cầu.
    SELECT cp.free_before_hours, cp.refund_percent
      INTO v_free_hours, v_percent
      FROM cancellation_policies cp
     WHERE cp.tour_id = v_tour_id AND cp.version = v_policy;

    SET v_in_free = (v_free_hours IS NOT NULL AND NOW() < v_starts_at - INTERVAL v_free_hours HOUR);

    SELECT COALESCE(SUM(p.amount_vnd), 0) INTO v_paid
      FROM payments p
     WHERE p.booking_id = v_booking_id AND p.status = 'paid';

    SET v_refund = IF(v_type = 'cancel',
                      FLOOR(v_paid * IF(v_in_free, 100, COALESCE(v_percent, 0)) / 100), 0);

    INSERT INTO booking_change_requests (id, booking_id, user_id, type, requested_schedule_id, reason, status,
                                         booking_status, policy_version, free_before_hours, refund_percent,
                                         in_free_window, paid_vnd, estimated_refund_vnd, created_at)
    VALUES (v_request_id, v_booking_id, p_user_id, v_type, v_new_id, v_reason, 'pending',
            v_status, v_policy, v_free_hours, v_percent,
            v_in_free, v_paid, v_refund, NOW());

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'customer', p_user_id,
            IF(v_type = 'cancel', 'cancel_requested', 'change_requested'), v_status, v_status,
            LEFT(CONCAT(IF(v_type = 'cancel', '',
                           CONCAT('Đổi sang ', DATE_FORMAT(v_new_starts, '%d/%m/%Y %H:%i'), '. ')),
                        'Lý do: ', v_reason), 255),
            NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_request_id AS request_id, v_refund AS estimated_refund_vnd;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_change_request_list(p_user_id, p_code)
--   Các yêu cầu đổi / hủy của một đơn (của tài khoản p_user_id), mới nhất trước.
--   Cột: request_id, type, status, requested_starts_at, reason, in_free_window, paid_vnd,
--        estimated_refund_vnd, refund_vnd, result_note, created_at, handled_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_request_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_request_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        r.id               AS request_id,
        r.type,
        r.status,
        ns.starts_at       AS requested_starts_at,
        r.reason,
        r.in_free_window,
        r.paid_vnd,
        r.estimated_refund_vnd,
        r.refund_vnd,
        r.result_note,
        r.created_at,
        r.handled_at
    FROM booking_change_requests r
    JOIN bookings b ON b.id = r.booking_id
    LEFT JOIN schedules ns ON ns.id = r.requested_schedule_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY r.created_at DESC, r.id;
END$$
DELIMITER ;
