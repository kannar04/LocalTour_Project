-- =====================================================================
-- LocalTour v0.1 - 07_procedures_NTK_admin.sql
-- Mục đích  : Stored procedures cho trang quản trị yêu cầu đặt tour (FR-25) và lịch sử
--             xử lý (NFR-09) dùng chung cho trang tour và trang yêu cầu đặt tour.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Procedures: NTK_sp_admin_booking_list, NTK_sp_admin_booking_detail,
--             NTK_sp_admin_booking_line_list, NTK_sp_admin_booking_extra_list,
--             NTK_sp_admin_booking_passenger_list, NTK_sp_admin_booking_payment_list,
--             NTK_sp_admin_log_list, NTK_sp_admin_booking_set_status
-- Quy tắc   : Chỉ trang quản trị gọi các procedure này (ứng dụng kiểm tra tài khoản
--             quản trị viên trước). Procedure ghi dữ liệu kiểm tra lại người thao tác là
--             quản trị viên đang hoạt động, vì quyền trong session có thể đã cũ.
--             Chuyển trạng thái yêu cầu đặt tour (quản trị viên):
--               pending          -> awaiting_payment (xác nhận chỗ và chốt tổng giá; hạn thanh
--                                   toán 24 giờ), rejected (bắt buộc lý do), cancelled (bắt buộc lý do)
--               awaiting_payment -> confirmed (cần thanh toán 'paid' hoặc chuyển khoản
--                                   VietQR 'awaiting_reconciliation': khoản này được ghi
--                                   'paid' = quản trị viên đã đối chiếu), cancelled (bắt buộc lý do)
--               confirmed        -> completed (chỉ sau giờ khởi hành), cancelled (bắt buộc lý do)
--               rejected, cancelled, completed: trạng thái cuối, không đổi được nữa.
--             Đổi ngày hoặc số người không thuộc FR-25 (thuộc FR-12, phát triển sau).
--             Giữ chỗ (M4): đơn 'pending' chưa giữ chỗ. Xác nhận chỗ (pending ->
--             awaiting_payment) trừ schedules.remaining theo số khách của đơn, lịch về 0 chỗ
--             thì chuyển 'full'. Hủy đơn đang giữ chỗ (awaiting_payment / confirmed ->
--             cancelled) cộng lại số chỗ (không vượt capacity), lịch 'full' mở lại 'open'.
--             Từ chối / hủy đơn 'pending' và hoàn thành đơn không đổi số chỗ.
--             Chốt tổng giá (Sprint 4, 4.4.3.2): khi xác nhận chỗ, quản trị viên nhập lại tổng
--             giá nếu cần (vd. phụ thu ngày lễ, đón ngoài khu trung tâm). Đổi giá phải ghi lý do;
--             admin_logs ghi "Tổng giá: A -> B". Khách thanh toán đúng tổng giá đã chốt.
--             Xác nhận đơn (-> confirmed) cấp voucher (LTP_sp_voucher_issue, file 15).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
--             Các procedure đọc cột / bảng của file 08 và 12 và gọi LTP_sp_voucher_issue
--             (file 15), nên cần import đủ 01 -> 15 trước khi mở trang quản trị.
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_list(p_status, p_keyword)
--   p_status : NULL / '' = mọi trạng thái; ngược lại một giá trị của bookings.status.
--   p_keyword: NULL / '' = không lọc; ngược lại tìm trong mã đơn, tên, email, số điện
--              thoại liên hệ (không phân biệt hoa thường).
--   Tối đa 200 dòng, đơn mới tạo trước. Cột: booking_id, code, status, created_at,
--   contact_name, contact_email, contact_phone, tour_title, starts_at, people (tổng số vé),
--   total_vnd, payment_status (khoản thanh toán tiêu biểu, NULL = chưa có), hold_expires_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_list(
    IN p_status  VARCHAR(30),
    IN p_keyword VARCHAR(100) CHARACTER SET utf8mb4
)
READS SQL DATA
BEGIN
    DECLARE v_keyword VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_keyword), '');

    SELECT
        b.id              AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        t.title           AS tour_title,
        s.starts_at,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        b.total_vnd,
        (SELECT p.status
           FROM payments p
          WHERE p.booking_id = b.id
          ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
          LIMIT 1)        AS payment_status,
        b.hold_expires_at
    FROM bookings b
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE (NULLIF(p_status, '') IS NULL OR b.status = (p_status COLLATE utf8mb4_unicode_ci))
      AND (v_keyword IS NULL
           OR LOCATE(v_keyword COLLATE utf8mb4_unicode_ci,
                     CONCAT_WS(' ', b.code, b.contact_name, b.contact_email, b.contact_phone)) > 0)
    ORDER BY b.created_at DESC, b.code
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_detail(p_booking_id)
--   0 hoặc 1 dòng: thông tin đơn, tài khoản đặt, tour, đơn vị tổ chức, lịch khởi hành
--   (kèm schedule_capacity, schedule_remaining, schedule_status), số khách, khoản thanh toán tiêu biểu (ưu tiên 'paid', rồi 'awaiting_reconciliation',
--   'processing', 'pending', 'failed'), tổng tiền đã hoàn ('completed'), số tiền đang chờ
--   hoàn ('requested'), tiền vé (tickets_vnd), phụ thu / tùy chọn khách chọn (extras_vnd)
--   và voucher (voucher_code, voucher_issued_at; NULL = chưa cấp).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_detail;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_detail(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id                AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.hold_expires_at,
        b.total_vnd,
        (SELECT COALESCE(SUM(bl.line_total_vnd), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS tickets_vnd,
        (SELECT COALESCE(SUM(bx.line_total_vnd), 0)
           FROM booking_extras bx
          WHERE bx.booking_id = b.id) AS extras_vnd,
        b.voucher_code,
        b.voucher_issued_at,
        b.policy_version,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        u.name              AS account_name,
        u.email             AS account_email,
        u.status            AS account_status,
        t.id                AS tour_id,
        t.title             AS tour_title,
        pr.business_name    AS provider_name,
        pr.contact_phone    AS provider_phone,
        s.starts_at,
        s.ends_at,
        s.capacity          AS schedule_capacity,
        s.remaining         AS schedule_remaining,
        s.status            AS schedule_status,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        pay.method          AS payment_method,
        pay.status          AS payment_status,
        pay.amount_vnd      AS payment_amount_vnd,
        pay.paid_at,
        pay.provider_txn_id,
        (SELECT COALESCE(SUM(r.amount_vnd), 0)
           FROM refunds r
           JOIN payments p2 ON p2.id = r.payment_id
          WHERE p2.booking_id = b.id
            AND r.status = 'completed') AS refund_completed_vnd,
        (SELECT COALESCE(SUM(r.amount_vnd), 0)
           FROM refunds r
           JOIN payments p2 ON p2.id = r.payment_id
          WHERE p2.booking_id = b.id
            AND r.status = 'requested') AS refund_requested_vnd
    FROM bookings b
    JOIN users u      ON u.id = b.user_id
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    LEFT JOIN payments pay ON pay.id = (
        SELECT p.id
          FROM payments p
         WHERE p.booking_id = b.id
         ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
         LIMIT 1)
    WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_line_list(p_booking_id)
--   Các dòng vé của đơn. Cột: ticket_name, quantity, unit_price_vnd, line_total_vnd.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_line_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_line_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tt.name           AS ticket_name,
        bl.quantity,
        bl.unit_price_vnd,
        bl.line_total_vnd
    FROM booking_lines bl
    JOIN ticket_types tt ON tt.id = bl.ticket_type_id
    WHERE bl.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY bl.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_extra_list(p_booking_id)
--   Phụ thu / hoạt động tùy chọn khách chọn khi đặt (bảng booking_extras, file 12).
--   Cột: kind, name, price_unit, quantity, unit_price_vnd, line_total_vnd.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_extra_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_extra_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        bx.kind,
        bx.name,
        bx.price_unit,
        bx.quantity,
        bx.unit_price_vnd,
        bx.line_total_vnd
    FROM booking_extras bx
    WHERE bx.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY bx.kind = 'surcharge' DESC, bx.sort_order, bx.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_payment_list(p_booking_id)
--   Mọi khoản thanh toán của đơn, mới trước (Sprint 4: VNPay, VietQR, đối chiếu).
--   Cột: payment_id, method, reference (mã gửi cổng / nội dung chuyển khoản; khoản cũ dùng
--   provider_txn_id), provider_txn_id, amount_vnd, status, created_at, submitted_at, paid_at,
--   response_code, bank_code, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_payment_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_payment_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id              AS payment_id,
        p.method,
        COALESCE(p.reference, p.provider_txn_id) AS reference,
        p.provider_txn_id,
        p.amount_vnd,
        p.status,
        p.created_at,
        p.submitted_at,
        p.paid_at,
        p.response_code,
        p.bank_code,
        p.note
    FROM payments p
    WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY COALESCE(p.created_at, p.paid_at) DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_passenger_list(p_booking_id)
--   Danh sách khách của đơn theo thứ tự nhập trên form (passengers.sort_order, cột của
--   file 08). Cột: full_name, age_group (adult / child / infant),
--   special_request (NULL = không có).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_passenger_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_passenger_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.full_name,
        p.age_group,
        p.special_request
    FROM passengers p
    WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY p.sort_order, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_log_list(p_target_type, p_target_id)
--   Lịch sử xử lý của một đối tượng ('tour' hoặc 'booking' + UUID), cũ trước.
--   Cột: created_at, actor_name, action, from_status, to_status, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_log_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_log_list(
    IN p_target_type VARCHAR(50),
    IN p_target_id   CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        l.created_at,
        u.name            AS actor_name,
        l.action,
        l.from_status,
        l.to_status,
        l.note
    FROM admin_logs l
    JOIN users u ON u.id = l.actor_user_id
    WHERE l.target_type = (p_target_type COLLATE utf8mb4_unicode_ci)
      AND l.target_id = (p_target_id COLLATE utf8mb4_unicode_ci)
    ORDER BY l.created_at, l.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_set_status(p_booking_id, p_new_status, p_actor_user_id, p_note, p_total_vnd)
--   Đổi trạng thái theo bảng chuyển trạng thái ở đầu file và ghi admin_logs trong cùng
--   một transaction. p_note: lý do / ghi chú (NULL / '' = không có), tối đa 255 ký tự.
--   p_total_vnd: tổng giá chốt khi xác nhận chỗ (pending -> awaiting_payment); NULL = giữ
--   tổng hiện tại. Bỏ qua với các chuyển trạng thái khác.
--   1 dòng: result, status.
--     result = 'ok'                 : đã đổi; status = trạng thái mới.
--              'forbidden'          : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'          : không có đơn này.
--              'invalid_transition' : không được chuyển từ trạng thái hiện tại sang p_new_status.
--              'note_required'      : từ chối / hủy mà không có lý do.
--              'needs_payment'      : xác nhận khi chưa có thanh toán thành công / chờ đối chiếu.
--              'not_departed'       : hoàn thành khi chưa tới giờ khởi hành.
--              'schedule_closed'    : xác nhận chỗ khi lịch đã hủy, đã hoàn thành hoặc đã khởi hành.
--              'no_seats'           : xác nhận chỗ khi lịch không còn đủ chỗ cho số khách của đơn.
--              'invalid_total'      : tổng giá chốt <= 0.
--              'total_note_required': đổi tổng giá mà không ghi lý do.
--     Khi không 'ok', status = trạng thái hiện tại (NULL nếu không có đơn), không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_set_status;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_set_status(
    IN p_booking_id    CHAR(36),
    IN p_new_status    VARCHAR(30),
    IN p_actor_user_id CHAR(36),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4,
    IN p_total_vnd     BIGINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_old        VARCHAR(30)  DEFAULT NULL;
    DECLARE v_total      BIGINT       DEFAULT NULL;
    DECLARE v_starts_at  DATETIME     DEFAULT NULL;
    DECLARE v_schedule   CHAR(36)     DEFAULT NULL;
    DECLARE v_sched_st   VARCHAR(30)  DEFAULT NULL;
    DECLARE v_remaining  INT          DEFAULT NULL;
    DECLARE v_people     INT          DEFAULT 0;
    DECLARE v_payment_id CHAR(36)     DEFAULT NULL;
    DECLARE v_payment_st VARCHAR(30)  DEFAULT NULL;
    DECLARE v_new        VARCHAR(30)  DEFAULT COALESCE(p_new_status, '');
    DECLARE v_note       VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa cả đơn và lịch: số chỗ chỉ đổi trong transaction này.
    SELECT b.status, b.total_vnd, b.schedule_id, s.starts_at, s.status, s.remaining
      INTO v_old, v_total, v_schedule, v_starts_at, v_sched_st, v_remaining
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS status;
        LEAVE proc;
    END IF;

    IF NOT ((v_old = 'pending'          AND v_new IN ('awaiting_payment', 'rejected', 'cancelled'))
         OR (v_old = 'awaiting_payment' AND v_new IN ('confirmed', 'cancelled'))
         OR (v_old = 'confirmed'        AND v_new IN ('completed', 'cancelled'))) THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    IF v_new IN ('rejected', 'cancelled') AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    IF v_new = 'completed' AND v_starts_at > NOW() THEN
        ROLLBACK;
        SELECT 'not_departed' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
      FROM booking_lines bl
     WHERE bl.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci);

    -- Xác nhận chỗ: tổng giá chốt hợp lệ, lịch phải còn nhận khách và còn đủ chỗ, rồi giữ chỗ.
    IF v_new = 'awaiting_payment' AND p_total_vnd IS NOT NULL AND NOT (p_total_vnd <=> v_total) THEN
        IF p_total_vnd <= 0 THEN
            ROLLBACK;
            SELECT 'invalid_total' AS result, v_old AS status;
            LEAVE proc;
        END IF;
        IF v_note IS NULL THEN
            ROLLBACK;
            SELECT 'total_note_required' AS result, v_old AS status;
            LEAVE proc;
        END IF;
    END IF;

    IF v_new = 'awaiting_payment' THEN
        IF v_sched_st NOT IN ('open', 'full') OR v_starts_at <= NOW() THEN
            ROLLBACK;
            SELECT 'schedule_closed' AS result, v_old AS status;
            LEAVE proc;
        END IF;

        IF v_remaining < v_people THEN
            ROLLBACK;
            SELECT 'no_seats' AS result, v_old AS status;
            LEAVE proc;
        END IF;

        -- SET chạy từ trái sang phải: status so với remaining đã trừ.
        UPDATE schedules
           SET remaining = remaining - v_people,
               status = IF(remaining = 0 AND status = 'open', 'full', status)
         WHERE id = (v_schedule COLLATE utf8mb4_unicode_ci);
    END IF;

    -- Hủy đơn đang giữ chỗ: trả lại chỗ.
    IF v_new = 'cancelled' AND v_old IN ('awaiting_payment', 'confirmed') THEN
        UPDATE schedules
           SET remaining = LEAST(capacity, remaining + v_people),
               status = IF(status = 'full' AND remaining > 0, 'open', status)
         WHERE id = (v_schedule COLLATE utf8mb4_unicode_ci);
    END IF;

    IF v_new = 'confirmed' THEN
        SELECT p.id, p.status
          INTO v_payment_id, v_payment_st
          FROM payments p
         WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
           AND p.status IN ('paid', 'awaiting_reconciliation')
         ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation'), p.id
         LIMIT 1
           FOR UPDATE;

        IF v_payment_id IS NULL THEN
            ROLLBACK;
            SELECT 'needs_payment' AS result, v_old AS status;
            LEAVE proc;
        END IF;

        -- Quản trị viên xác nhận = đã đối chiếu khoản chuyển khoản VietQR.
        IF v_payment_st = 'awaiting_reconciliation' THEN
            UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = v_payment_id;
        END IF;
    END IF;

    -- Chốt tổng giá trước khi chuyển "Chờ thanh toán": ghi lịch sử riêng cho lần đổi giá.
    IF v_new = 'awaiting_payment' AND p_total_vnd IS NOT NULL AND NOT (p_total_vnd <=> v_total) THEN
        UPDATE bookings SET total_vnd = p_total_vnd WHERE id = (p_booking_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', p_booking_id, 'booking_total', NULL, NULL,
                LEFT(CONCAT('Tổng giá: ', REPLACE(FORMAT(v_total, 0), ',', '.'), ' → ',
                            REPLACE(FORMAT(p_total_vnd, 0), ',', '.'), ' VND'), 255), NOW());
    END IF;

    UPDATE bookings
       SET status = v_new,
           hold_expires_at = IF(v_new = 'awaiting_payment', NOW() + INTERVAL 24 HOUR, NULL)
     WHERE id = (p_booking_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'booking', p_booking_id, 'booking_status', v_old, v_new, v_note, NOW());

    IF v_new = 'confirmed' THEN
        -- Khoản khác còn chờ của đơn không dùng nữa; cấp voucher (file 15).
        UPDATE payments
           SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
         WHERE booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
           AND id <> v_payment_id
           AND status = 'pending';

        CALL LTP_sp_voucher_issue(p_booking_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_new AS status;
END$$
DELIMITER ;
