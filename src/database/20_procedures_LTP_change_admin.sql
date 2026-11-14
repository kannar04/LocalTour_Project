-- =====================================================================
-- LocalTour v0.4 - 20_procedures_LTP_change_admin.sql
-- Mục đích  : Quản trị viên xem và xử lý thủ công yêu cầu đổi ngày / hủy tour của khách
--             (US14-S5-03, FR-12): đồng ý hoặc từ chối, ghi kết quả, trạng thái và lịch sử.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 5
-- Procedures: LTP_sp_admin_change_request_list, LTP_sp_admin_change_request_detail,
--             LTP_sp_admin_change_request_decide
-- Quy tắc   : * Chỉ quản trị viên đang hoạt động xử lý được; yêu cầu chỉ xử lý một lần.
--             * Bắt buộc ghi kết quả xử lý (tối đa 500 ký tự), cả khi đồng ý lẫn từ chối.
--             * Đồng ý hủy: đơn chuyển 'cancelled'; đơn đang giữ chỗ được trả lại chỗ; khoản
--               thanh toán chưa xong ('pending', 'processing') chuyển 'failed'. Không đồng ý
--               được khi còn khoản chuyển khoản chờ đối chiếu (xử lý ở trang Thanh toán trước).
--               Có tiền đã trả: ghi một dòng refunds 'requested' với số tiền quản trị viên chốt
--               (0 - tiền đã trả; mặc định = số dự kiến hoàn) để hoàn tay. Chưa tự động hoàn tiền.
--             * Đồng ý đổi ngày: lịch mới phải còn mở bán, chưa khởi hành, cùng tour và còn đủ
--               chỗ; đơn chuyển sang lịch mới (dòng vé đổi sang loại vé cùng tên của lịch mới,
--               giá đơn giữ nguyên). Đơn đang giữ chỗ: trả chỗ lịch cũ, giữ chỗ lịch mới.
--             * Lịch sử: admin_logs của đơn ('cancel_approved', 'cancel_rejected',
--               'change_approved', 'change_rejected', 'refund_requested'); trang đơn của khách
--               và của quản trị viên đọc qua LTP_sp_*booking_history (file 15).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 19_procedures_LTP_change.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_admin_change_request_list(p_status, p_booking_id)
--   p_status    : NULL / '' = mọi trạng thái; 'pending' | 'approved' | 'rejected'.
--   p_booking_id: NULL / '' = mọi đơn; ngược lại chỉ yêu cầu của đơn đó.
--   Cột: request_id, type, status, created_at, handled_at, booking_id, booking_code,
--        booking_status, customer_name, customer_email, tour_title, starts_at (lịch hiện tại
--        của đơn), requested_starts_at, people, paid_vnd, estimated_refund_vnd, refund_vnd,
--        result_note, handler_name.
--   Sắp xếp: chờ xử lý trước (gửi sớm trước), rồi đã xử lý (mới nhất trước). Tối đa 200 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_change_request_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_change_request_list(
    IN p_status     VARCHAR(20),
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        r.id                 AS request_id,
        r.type,
        r.status,
        r.created_at,
        r.handled_at,
        b.id                 AS booking_id,
        b.code               AS booking_code,
        b.status             AS booking_status,
        cu.name              AS customer_name,
        cu.email             AS customer_email,
        t.title              AS tour_title,
        s.starts_at,
        ns.starts_at         AS requested_starts_at,
        (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id) AS people,
        r.paid_vnd,
        r.estimated_refund_vnd,
        r.refund_vnd,
        r.result_note,
        hu.name              AS handler_name
    FROM booking_change_requests r
    JOIN bookings  b  ON b.id = r.booking_id
    JOIN users     cu ON cu.id = r.user_id
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours     t  ON t.id = s.tour_id
    LEFT JOIN schedules ns ON ns.id = r.requested_schedule_id
    LEFT JOIN users     hu ON hu.id = r.handled_by
    WHERE (NULLIF(p_status, '') IS NULL OR r.status = (p_status COLLATE utf8mb4_unicode_ci))
      AND (NULLIF(p_booking_id, '') IS NULL OR r.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci))
    ORDER BY (r.status = 'pending') DESC,
             IF(r.status = 'pending', r.created_at, NULL) ASC,
             COALESCE(r.handled_at, r.created_at) DESC,
             r.id
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_change_request_detail(p_request_id)
--   0 hoặc 1 dòng: mọi cột của yêu cầu và thông tin để quản trị viên quyết định.
--   Cột: request_id, type, status, reason, created_at, handled_at, result_note, refund_vnd,
--        handler_name, booking_status_at_request (booking_status lúc gửi), policy_version,
--        free_before_hours, refund_percent, in_free_window, paid_vnd (lúc gửi),
--        estimated_refund_vnd, policy_terms,
--        booking_id, booking_code, booking_status, total_vnd, package_name, contact_name,
--        contact_email, contact_phone, customer_name, customer_email, tour_id, tour_title,
--        schedule_id, starts_at, ends_at, people, paid_now_vnd (tiền đã trả hiện tại),
--        review_payment_count (khoản chuyển khoản chờ đối chiếu: phải xử lý trước khi hủy),
--        requested_schedule_id, requested_starts_at, requested_ends_at,
--        requested_status, requested_remaining.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_change_request_detail;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_change_request_detail(
    IN p_request_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        r.id                 AS request_id,
        r.type,
        r.status,
        r.reason,
        r.created_at,
        r.handled_at,
        r.result_note,
        r.refund_vnd,
        hu.name              AS handler_name,
        r.booking_status     AS booking_status_at_request,
        r.policy_version,
        r.free_before_hours,
        r.refund_percent,
        r.in_free_window,
        r.paid_vnd,
        r.estimated_refund_vnd,
        cp.terms             AS policy_terms,
        b.id                 AS booking_id,
        b.code               AS booking_code,
        b.status             AS booking_status,
        b.total_vnd,
        b.package_name,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        cu.name              AS customer_name,
        cu.email             AS customer_email,
        t.id                 AS tour_id,
        t.title              AS tour_title,
        s.id                 AS schedule_id,
        s.starts_at,
        s.ends_at,
        (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id) AS people,
        (SELECT COALESCE(SUM(p.amount_vnd), 0) FROM payments p
          WHERE p.booking_id = b.id AND p.status = 'paid') AS paid_now_vnd,
        (SELECT COUNT(*) FROM payments p
          WHERE p.booking_id = b.id AND p.status = 'awaiting_reconciliation') AS review_payment_count,
        ns.id                AS requested_schedule_id,
        ns.starts_at         AS requested_starts_at,
        ns.ends_at           AS requested_ends_at,
        ns.status            AS requested_status,
        ns.remaining         AS requested_remaining
    FROM booking_change_requests r
    JOIN bookings  b  ON b.id = r.booking_id
    JOIN users     cu ON cu.id = r.user_id
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours     t  ON t.id = s.tour_id
    LEFT JOIN schedules ns ON ns.id = r.requested_schedule_id
    LEFT JOIN users     hu ON hu.id = r.handled_by
    LEFT JOIN cancellation_policies cp ON cp.tour_id = t.id AND cp.version = r.policy_version
    WHERE r.id = (p_request_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_change_request_decide(p_actor_user_id, p_request_id, p_decision, p_note,
--                                    p_refund_vnd)
--   p_decision : 'approved' (đồng ý) | 'rejected' (từ chối).
--   p_note     : kết quả xử lý, bắt buộc, tối đa 500 ký tự.
--   p_refund_vnd: chỉ dùng khi đồng ý hủy: số tiền sẽ hoàn (0 - tiền còn hoàn được). NULL = số
--                 dự kiến hoàn lúc khách gửi (không vượt tiền còn hoàn được).
--                 Tiền còn hoàn được = tổng khoản 'paid' của đơn - tổng khoản hoàn chưa bị từ
--                 chối ('requested', 'approved', 'completed') của các khoản đó, không âm.
--   1 dòng: result, field, booking_status.
--     result = 'ok'                   : đã xử lý; booking_status = trạng thái đơn sau xử lý.
--              'forbidden'            : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'            : không có yêu cầu này.
--              'invalid'              : field = decision, note hoặc refund_vnd.
--              'already_handled'      : yêu cầu đã được xử lý trước đó.
--              'booking_closed'       : đồng ý khi đơn đã hủy / bị từ chối / hoàn thành.
--              'payment_in_review'    : đồng ý hủy khi còn khoản chuyển khoản chờ đối chiếu.
--              'schedule_unavailable' : đồng ý đổi ngày khi lịch mới đã đóng / đã khởi hành.
--              'no_seats'             : đồng ý đổi ngày khi lịch mới không còn đủ chỗ.
--              'tickets_missing'      : lịch mới không có loại vé đang bán tương ứng với vé của đơn.
--     Khi không 'ok', không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_change_request_decide;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_change_request_decide(
    IN p_actor_user_id CHAR(36),
    IN p_request_id    CHAR(36),
    IN p_decision      VARCHAR(20),
    IN p_note          TEXT CHARACTER SET utf8mb4,
    IN p_refund_vnd    BIGINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_decision    VARCHAR(20)  DEFAULT COALESCE(p_decision, '');
    DECLARE v_note        TEXT         CHARACTER SET utf8mb4;
    DECLARE v_req_status  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_type        VARCHAR(20)  DEFAULT NULL;
    DECLARE v_booking_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_new_sched   CHAR(36)     DEFAULT NULL;
    DECLARE v_estimate    BIGINT       DEFAULT 0;
    DECLARE v_status      VARCHAR(30)  DEFAULT NULL;
    DECLARE v_schedule    CHAR(36)     DEFAULT NULL;
    DECLARE v_tour_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_old_starts  DATETIME     DEFAULT NULL;
    DECLARE v_new_tour    CHAR(36)     DEFAULT NULL;
    DECLARE v_new_starts  DATETIME     DEFAULT NULL;
    DECLARE v_new_status  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_new_left    INT          DEFAULT 0;
    DECLARE v_people      INT          DEFAULT 0;
    DECLARE v_paid        BIGINT       DEFAULT 0;
    DECLARE v_refund      BIGINT       DEFAULT NULL;
    DECLARE v_payment_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_reference   VARCHAR(32)  DEFAULT NULL;
    DECLARE v_holds       BOOLEAN      DEFAULT FALSE;
    DECLARE v_missing     INT          DEFAULT 0;
    DECLARE v_log_note    VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_note = NULLIF(TRIM(p_note), '');

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;

    IF v_decision NOT IN ('approved', 'rejected') THEN
        SELECT 'invalid' AS result, 'decision' AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;
    IF v_note IS NULL OR CHAR_LENGTH(v_note) > 500 THEN
        SELECT 'invalid' AS result, 'note' AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;
    IF p_refund_vnd IS NOT NULL AND p_refund_vnd < 0 THEN
        SELECT 'invalid' AS result, 'refund_vnd' AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT r.status, r.type, r.booking_id, r.requested_schedule_id, r.estimated_refund_vnd
      INTO v_req_status, v_type, v_booking_id, v_new_sched, v_estimate
      FROM booking_change_requests r
     WHERE r.id = (p_request_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_req_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;

    -- Khóa đơn và lịch hiện tại: số chỗ và trạng thái đơn chỉ đổi trong transaction này.
    SELECT b.status, b.schedule_id, s.tour_id, s.starts_at
      INTO v_status, v_schedule, v_tour_id, v_old_starts
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE b.id = v_booking_id
       FOR UPDATE;

    IF v_req_status <> 'pending' THEN
        ROLLBACK;
        SELECT 'already_handled' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    -- Từ chối: chỉ ghi kết quả.
    IF v_decision = 'rejected' THEN
        UPDATE booking_change_requests
           SET status = 'rejected', result_note = v_note,
               handled_by = p_actor_user_id, handled_at = NOW()
         WHERE id = (p_request_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id,
                IF(v_type = 'cancel', 'cancel_rejected', 'change_rejected'), v_status, v_status,
                LEFT(v_note, 255), NOW());

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    IF v_status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN
        ROLLBACK;
        SELECT 'booking_closed' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    SET v_holds = v_status IN ('awaiting_payment', 'confirmed');
    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
      FROM booking_lines bl
     WHERE bl.booking_id = v_booking_id;

    -- ----------------------------- Đồng ý hủy -----------------------------
    IF v_type = 'cancel' THEN
        IF EXISTS (SELECT 1 FROM payments p
                    WHERE p.booking_id = v_booking_id AND p.status = 'awaiting_reconciliation') THEN
            ROLLBACK;
            SELECT 'payment_in_review' AS result, NULL AS field, v_status AS booking_status;
            LEAVE proc;
        END IF;

        -- Tiền còn hoàn được: đã trả trừ các khoản hoàn chưa bị từ chối của đơn, không âm.
        SELECT GREATEST(0, COALESCE(SUM(p.amount_vnd), 0)
                           - COALESCE((SELECT SUM(r.amount_vnd)
                                         FROM refunds r
                                         JOIN payments rp ON rp.id = r.payment_id
                                        WHERE rp.booking_id = v_booking_id AND r.status <> 'rejected'), 0))
          INTO v_paid
          FROM payments p
         WHERE p.booking_id = v_booking_id AND p.status = 'paid';

        SET v_refund = COALESCE(p_refund_vnd, LEAST(v_estimate, v_paid));
        IF v_refund > v_paid THEN
            ROLLBACK;
            SELECT 'invalid' AS result, 'refund_vnd' AS field, v_status AS booking_status;
            LEAVE proc;
        END IF;

        IF v_holds THEN
            UPDATE schedules
               SET remaining = LEAST(capacity, remaining + v_people),
                   status = IF(status = 'full' AND remaining > 0, 'open', status)
             WHERE id = v_schedule;
        END IF;

        UPDATE bookings SET status = 'cancelled', hold_expires_at = NULL WHERE id = v_booking_id;

        UPDATE payments
           SET status = 'failed', note = 'Đơn đã hủy theo yêu cầu của khách.'
         WHERE booking_id = v_booking_id
           AND status IN ('pending', 'processing');

        UPDATE booking_change_requests
           SET status = 'approved', result_note = v_note, refund_vnd = v_refund,
               handled_by = p_actor_user_id, handled_at = NOW()
         WHERE id = (p_request_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'cancel_approved', v_status, 'cancelled',
                LEFT(v_note, 255), NOW());

        IF v_refund > 0 THEN
            SELECT p.id, p.reference INTO v_payment_id, v_reference
              FROM payments p
             WHERE p.booking_id = v_booking_id AND p.status = 'paid'
             ORDER BY p.amount_vnd DESC, p.paid_at DESC, p.id
             LIMIT 1;

            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), v_payment_id, v_refund,
                    LEFT(CONCAT('Hủy tour theo yêu cầu của khách: ', v_note), 255), 'requested', NOW());

            INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'refund_requested', NULL, NULL,
                    LEFT(CONCAT('Hoàn ', REPLACE(FORMAT(v_refund, 0), ',', '.'), ' VND',
                                IF(v_reference IS NULL, '', CONCAT(' cho khoản ', v_reference)),
                                ', LocalTour hoàn tiền thủ công.'), 255), NOW());
        END IF;

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, 'cancelled' AS booking_status;
        LEAVE proc;
    END IF;

    -- --------------------------- Đồng ý đổi ngày ---------------------------
    SELECT s.tour_id, s.starts_at, s.status, s.remaining
      INTO v_new_tour, v_new_starts, v_new_status, v_new_left
      FROM schedules s
     WHERE s.id = v_new_sched
       FOR UPDATE;

    IF v_new_tour IS NULL OR v_new_tour <> v_tour_id OR v_new_sched = v_schedule
       OR v_new_status <> 'open' OR v_new_starts <= NOW() THEN
        ROLLBACK;
        SELECT 'schedule_unavailable' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    IF v_new_left < v_people THEN
        ROLLBACK;
        SELECT 'no_seats' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    -- Mỗi dòng vé của đơn phải có loại vé đang bán cùng tên ở lịch mới.
    SELECT COUNT(*) INTO v_missing
      FROM booking_lines bl
      JOIN ticket_types ot ON ot.id = bl.ticket_type_id
     WHERE bl.booking_id = v_booking_id
       AND NOT EXISTS (SELECT 1 FROM ticket_types nt
                        WHERE nt.schedule_id = v_new_sched AND nt.name = ot.name
                          AND nt.active = TRUE);

    IF v_missing > 0 THEN
        ROLLBACK;
        SELECT 'tickets_missing' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    UPDATE booking_lines bl
      JOIN ticket_types ot ON ot.id = bl.ticket_type_id
       SET bl.ticket_type_id = (SELECT nt.id FROM ticket_types nt
                                 WHERE nt.schedule_id = v_new_sched AND nt.name = ot.name
                                   AND nt.active = TRUE
                                 ORDER BY nt.id
                                 LIMIT 1)
     WHERE bl.booking_id = v_booking_id;

    IF v_holds THEN
        UPDATE schedules
           SET remaining = LEAST(capacity, remaining + v_people),
               status = IF(status = 'full' AND remaining > 0, 'open', status)
         WHERE id = v_schedule;

        -- SET chạy từ trái sang phải: status so với remaining đã trừ.
        UPDATE schedules
           SET remaining = remaining - v_people,
               status = IF(remaining = 0 AND status = 'open', 'full', status)
         WHERE id = v_new_sched;
    END IF;

    UPDATE bookings SET schedule_id = v_new_sched WHERE id = v_booking_id;

    UPDATE booking_change_requests
       SET status = 'approved', result_note = v_note,
           handled_by = p_actor_user_id, handled_at = NOW()
     WHERE id = (p_request_id COLLATE utf8mb4_unicode_ci);

    SET v_log_note = LEFT(CONCAT('Đổi lịch ', DATE_FORMAT(v_old_starts, '%d/%m/%Y %H:%i'), ' → ',
                                 DATE_FORMAT(v_new_starts, '%d/%m/%Y %H:%i'), '. ', v_note), 255);
    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'change_approved', v_status, v_status, v_log_note, NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_status AS booking_status;
END$$
DELIMITER ;
