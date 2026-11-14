-- =====================================================================
-- LocalTour v0.1 - 07_procedures_NTK_admin.sql
-- Mục đích  : Stored procedures cho trang quản trị yêu cầu đặt tour (FR-25) và lịch sử
--             xử lý (NFR-09) dùng chung cho trang tour và trang yêu cầu đặt tour.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Procedures: NTK_sp_admin_booking_list, NTK_sp_admin_booking_detail,
--             NTK_sp_admin_booking_line_list, NTK_sp_admin_booking_extra_list,
--             NTK_sp_admin_booking_passenger_list, NTK_sp_admin_booking_payment_list,
--             NTK_sp_admin_log_list, NTK_sp_admin_booking_set_status,
--             NTK_sp_admin_vnpay_queue, NTK_sp_admin_vnpay_decide
-- Quy tắc   : Chỉ trang quản trị gọi các procedure này (ứng dụng kiểm tra tài khoản
--             quản trị viên trước). Procedure ghi dữ liệu kiểm tra lại người thao tác là
--             quản trị viên đang hoạt động, vì quyền trong session có thể đã cũ.
--             Đặt ngay (file 10, 28): đơn mới được tạo thẳng ở 'awaiting_payment' và đã giữ chỗ,
--             không còn bước quản trị viên xác nhận chỗ. 'pending' chỉ còn ở đơn tạo trước
--             thay đổi này (database cũ); quản trị viên vẫn xử lý được các đơn đó như dưới đây.
--             Chuyển trạng thái yêu cầu đặt tour (quản trị viên):
--               pending          -> awaiting_payment (đơn cũ: xác nhận chỗ và chốt tổng giá; hạn
--                                   thanh toán 24 giờ vì khách không có mặt lúc quản trị viên
--                                   xác nhận, không muộn hơn giờ khởi hành; không dùng
--                                   settings.hold_minutes), rejected (bắt buộc lý do),
--                                   cancelled (bắt buộc lý do)
--               awaiting_payment -> confirmed (cần thanh toán 'paid' hoặc chuyển khoản
--                                   VietQR 'awaiting_reconciliation': khoản này được ghi
--                                   'paid' = quản trị viên đã đối chiếu), cancelled (bắt buộc lý
--                                   do; không hủy được khi còn khoản chuyển khoản
--                                   'awaiting_reconciliation': quyết định khoản đó trước ở trang
--                                   đối chiếu; khoản 'pending' của đơn chuyển 'failed')
--               confirmed        -> completed (chỉ sau giờ khởi hành), cancelled (bắt buộc lý do)
--               rejected, cancelled, completed: trạng thái cuối, không đổi được nữa.
--             Đổi ngày không thuộc FR-25 mà thuộc FR-12: khách gửi yêu cầu ở file 19, quản trị
--             viên xử lý ở file 20. Đổi số người chưa có.
--             Giữ chỗ (M4): đơn 'awaiting_payment' / 'confirmed' đang giữ chỗ của lịch (đơn mới
--             giữ ngay lúc đặt, file 10). Đơn 'pending' (đơn cũ) chưa giữ chỗ: xác nhận chỗ
--             (pending -> awaiting_payment) trừ schedules.remaining theo số khách của đơn, lịch
--             về 0 chỗ thì chuyển 'full'. Hủy đơn đang giữ chỗ (awaiting_payment / confirmed ->
--             cancelled) cộng lại số chỗ (không vượt capacity), lịch 'full' mở lại 'open'.
--             Từ chối / hủy đơn 'pending' và hoàn thành đơn không đổi số chỗ.
--             Chốt tổng giá (Sprint 4, 4.4.3.2; chỉ còn với đơn cũ 'pending'): khi xác nhận chỗ,
--             quản trị viên nhập lại tổng giá nếu cần (vd. phụ thu ngày lễ, đón ngoài khu trung tâm). Đổi giá phải ghi lý do;
--             admin_logs ghi "Tổng giá: A -> B". Khách thanh toán đúng tổng giá đã chốt.
--             Xác nhận đơn (-> confirmed) cấp voucher (LTP_sp_voucher_issue, file 15).
--             Hủy đơn đã thanh toán (confirmed -> cancelled) tạo yêu cầu hoàn toàn bộ số tiền khách
--             đã trả (refunds 'requested'); quản trị viên hoàn tiền thủ công rồi ghi nhận ở trang
--             "Chi trả đơn vị" (file 30).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01_schema.sql (Sprint 5: cột bookings.package_name ở 16_migration_sprint5_LTP.sql).
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
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
--   Sprint 5: package_name (gói khách chọn, NULL = tour không có gói).
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
        b.package_name,
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
--   p_total_vnd: tổng giá chốt khi xác nhận chỗ đơn cũ (pending -> awaiting_payment); NULL =
--   giữ tổng hiện tại. Bỏ qua với các chuyển trạng thái khác.
--   1 dòng: result, status.
--     result = 'ok'                 : đã đổi; status = trạng thái mới.
--              'forbidden'          : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'          : không có đơn này.
--              'invalid_transition' : không được chuyển từ trạng thái hiện tại sang p_new_status.
--              'note_required'      : từ chối / hủy mà không có lý do.
--              'needs_payment'      : xác nhận khi chưa có thanh toán thành công / chờ đối chiếu.
--              'payment_in_review'  : hủy đơn 'awaiting_payment' khi còn khoản chuyển khoản chờ
--                                     đối chiếu ('awaiting_reconciliation').
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
    DECLARE v_refund     BIGINT       DEFAULT 0;
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

    -- Đơn chờ thanh toán còn khoản chuyển khoản chờ đối chiếu: khách có thể đã chuyển tiền, quản
    -- trị viên phải quyết định khoản đó trước (trang đối chiếu, file 14).
    IF v_new = 'cancelled' AND v_old = 'awaiting_payment'
       AND EXISTS (SELECT 1 FROM payments p
                    WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
                      AND p.status = 'awaiting_reconciliation') THEN
        ROLLBACK;
        SELECT 'payment_in_review' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
      FROM booking_lines bl
     WHERE bl.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci);

    -- Xác nhận chỗ (đơn cũ 'pending'): tổng giá chốt hợp lệ, lịch phải còn nhận khách và còn đủ
    -- chỗ, rồi giữ chỗ.
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

    -- Hủy đơn chờ thanh toán: khoản thanh toán còn mở của đơn không dùng được nữa.
    IF v_new = 'cancelled' AND v_old = 'awaiting_payment' THEN
        UPDATE payments
           SET status = 'failed', note = 'Đơn đã bị quản trị viên hủy.'
         WHERE booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
           AND status = 'pending';
    END IF;

    -- Quản trị viên hủy đơn đã thanh toán: tạo yêu cầu hoàn toàn bộ số tiền khách đã trả mà chưa
    -- có yêu cầu hoàn (mỗi khoản 'paid' một dòng), để tiền này không bị tính vào khoản chi trả
    -- cho đơn vị tổ chức (file 30). Quản trị viên chuyển khoản rồi ghi "Đã hoàn tiền".
    IF v_new = 'cancelled' AND v_old = 'confirmed' THEN
        SELECT COALESCE(SUM(p.amount_vnd - COALESCE((SELECT SUM(r.amount_vnd) FROM refunds r
                                                      WHERE r.payment_id = p.id AND r.status <> 'rejected'), 0)), 0)
          INTO v_refund
          FROM payments p
         WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
           AND p.status = 'paid';

        IF v_refund > 0 THEN
            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            SELECT UUID(), p.id,
                   p.amount_vnd - COALESCE((SELECT SUM(r.amount_vnd) FROM refunds r
                                             WHERE r.payment_id = p.id AND r.status <> 'rejected'), 0),
                   LEFT(CONCAT('Quản trị viên hủy đơn đã thanh toán: ', v_note), 255), 'requested', NOW()
              FROM payments p
             WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
               AND p.status = 'paid'
               AND p.amount_vnd - COALESCE((SELECT SUM(r.amount_vnd) FROM refunds r
                                             WHERE r.payment_id = p.id AND r.status <> 'rejected'), 0) > 0;

            INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), p_actor_user_id, 'booking', p_booking_id, 'refund_requested', NULL, NULL,
                    LEFT(CONCAT('Hoàn ', REPLACE(FORMAT(v_refund, 0), ',', '.'),
                                ' VND cho khách vì quản trị viên hủy đơn, LocalTour hoàn tiền thủ công.'), 255), NOW());
        END IF;
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

    -- Đơn cũ vừa được xác nhận chỗ: giữ chỗ 24 giờ (khách không có mặt lúc này), không muộn hơn
    -- giờ khởi hành.
    UPDATE bookings
       SET status = v_new,
           hold_expires_at = IF(v_new = 'awaiting_payment',
                                LEAST(NOW() + INTERVAL 24 HOUR, v_starts_at), NULL)
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

-- ---------------------------------------------------------------------
-- NTK_sp_admin_vnpay_queue(p_booking_id)
--   Giao dịch VNPay chưa rõ kết quả (ISS-03, Sprint 4): khoản VNPay tạo từ trang thanh toán
--   (có reference = vnp_TxnRef) mà VNPay chưa trả kết quả nào (không có payment_events,
--   response_code NULL), vì Return URL và IPN đều không về (khách đóng trình duyệt, chạy ở
--   localhost...). Gồm:
--     * khoản 'pending' đã quá 15 phút (hết hạn link thanh toán VNPay, VnpayGateway), và
--     * khoản bị hệ thống đóng 'failed' (đơn quá hạn / bị hủy) khi đơn không được thanh toán
--       bằng khoản khác.
--   Quản trị viên tra mã thanh toán trên cổng VNPay rồi ghi kết quả (NTK_sp_admin_vnpay_decide).
--   p_booking_id: NULL = mọi đơn (tối đa 200 dòng, tạo trước lên trước); ngược lại một đơn.
--   Cột: payment_id, reference, amount_vnd, status, created_at, booking_id, code,
--   booking_status, hold_expires_at, contact_name, contact_phone, tour_title, starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_vnpay_queue;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_vnpay_queue(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.reference,
        p.amount_vnd,
        p.status,
        p.created_at,
        b.id            AS booking_id,
        b.code,
        b.status        AS booking_status,
        b.hold_expires_at,
        b.contact_name,
        b.contact_phone,
        t.title         AS tour_title,
        s.starts_at
    FROM payments p
    JOIN bookings b  ON b.id = p.booking_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE p.method = 'vnpay'
      AND p.reference IS NOT NULL
      AND p.response_code IS NULL
      AND NOT EXISTS (SELECT 1 FROM payment_events e WHERE e.payment_id = p.id)
      AND ((p.status = 'pending' AND p.created_at <= NOW() - INTERVAL 15 MINUTE)
           OR (p.status = 'failed' AND b.status NOT IN ('confirmed', 'completed')))
      AND (p_booking_id IS NULL OR b.id = (p_booking_id COLLATE utf8mb4_unicode_ci))
    ORDER BY p.created_at, p.id
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_vnpay_decide(p_payment_id, p_decision, p_actor_user_id, p_txn_no, p_note)
--   Quản trị viên ghi kết quả đã tra trên cổng VNPay cho một khoản của NTK_sp_admin_vnpay_queue.
--   p_decision = 'confirm': VNPay có giao dịch thành công, bắt buộc p_txn_no (mã giao dịch tại
--                VNPay). Khoản -> 'paid'. Đơn còn 'awaiting_payment' -> 'confirmed', cấp voucher,
--                khoản 'pending' khác -> 'failed' (như VNPay báo thành công). Đơn đã hủy -> khoản
--                vẫn 'paid' và tạo yêu cầu hoàn tiền ('requested'), như tiền VNPay tới muộn.
--              'reject' : VNPay không có giao dịch thành công, bắt buộc lý do. Khoản -> 'failed';
--                đơn không đổi (đơn còn hạn thì khách thanh toán lại được).
--   Mỗi quyết định ghi một payment_events 'ADMIN-<reference>' (khoản rời hàng đợi) và
--   admin_logs của đơn. VNPay báo kết quả muộn sau 'reject' vẫn được ghi (file 15).
--   1 dòng: result, booking_id, confirmed (1 = chính lần này chuyển đơn sang 'confirmed', ứng
--   dụng gửi email "Đặt tour thành công"; 0 = không).
--     result = 'ok' | 'forbidden' | 'not_found' | 'invalid' (quyết định sai)
--              'txn_required' (đã nhận tiền mà không có mã giao dịch VNPay)
--              'note_required' (không có giao dịch mà không có lý do)
--              'not_payable' (khoản không còn trong hàng đợi chưa rõ kết quả)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_vnpay_decide;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_vnpay_decide(
    IN p_payment_id    CHAR(36),
    IN p_decision      VARCHAR(10),
    IN p_actor_user_id CHAR(36),
    IN p_txn_no        VARCHAR(100),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_code   VARCHAR(10) DEFAULT NULL;
    DECLARE v_created    DATETIME    DEFAULT NULL;
    DECLARE v_amount     BIGINT      DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE v_confirmed  TINYINT     DEFAULT 0;
    DECLARE v_txn_no     VARCHAR(100) DEFAULT NULLIF(TRIM(p_txn_no), '');
    DECLARE v_note       VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS booking_id, 0 AS confirmed;
        LEAVE proc;
    END IF;

    IF p_decision IS NULL OR p_decision NOT IN ('confirm', 'reject') THEN
        SELECT 'invalid' AS result, NULL AS booking_id, 0 AS confirmed;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT p.booking_id, p.status, p.response_code, p.created_at, p.amount_vnd, p.reference
      INTO v_booking_id, v_pay_status, v_pay_code, v_created, v_amount, v_reference
      FROM payments p
     WHERE p.id = (p_payment_id COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vnpay'
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS booking_id, 0 AS confirmed;
        LEAVE proc;
    END IF;

    -- Khóa đơn (cùng thứ tự khóa với các procedure khác: khoản rồi đơn).
    SELECT b.status INTO v_status FROM bookings b WHERE b.id = v_booking_id FOR UPDATE;

    -- Kiểm tra lại điều kiện của hàng đợi trong transaction (VNPay có thể vừa trả kết quả).
    IF v_reference IS NULL OR v_pay_code IS NOT NULL
       OR EXISTS (SELECT 1 FROM payment_events e WHERE e.payment_id = (p_payment_id COLLATE utf8mb4_unicode_ci))
       OR NOT ((v_pay_status = 'pending' AND v_created <= NOW() - INTERVAL 15 MINUTE)
               OR (v_pay_status = 'failed' AND v_status NOT IN ('confirmed', 'completed'))) THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, v_booking_id AS booking_id, 0 AS confirmed;
        LEAVE proc;
    END IF;

    IF p_decision = 'confirm' AND v_txn_no IS NULL THEN
        ROLLBACK;
        SELECT 'txn_required' AS result, v_booking_id AS booking_id, 0 AS confirmed;
        LEAVE proc;
    END IF;

    IF p_decision = 'reject' AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_booking_id AS booking_id, 0 AS confirmed;
        LEAVE proc;
    END IF;

    INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at)
    VALUES (UUID(), p_payment_id, CONCAT('ADMIN-', v_reference),
            IF(p_decision = 'confirm', 'ADMIN_PAID', 'ADMIN_NONE'), TRUE, NOW());

    IF p_decision = 'confirm' THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), provider_txn_id = v_txn_no,
               note = LEFT(CONCAT('Đối chiếu trên cổng VNPay', IF(v_note IS NULL, '.', CONCAT(': ', v_note))), 255)
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        IF v_status = 'awaiting_payment' THEN
            UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

            UPDATE payments
               SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
             WHERE booking_id = v_booking_id
               AND id <> (p_payment_id COLLATE utf8mb4_unicode_ci)
               AND status = 'pending';

            INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'vnpay_reconcile_paid', 'awaiting_payment', 'confirmed',
                    LEFT(CONCAT('Đã thấy giao dịch VNPay ', v_reference, ' thành công (mã GD ', v_txn_no, ')',
                                IF(v_note IS NULL, '', CONCAT(': ', v_note))), 255), NOW());

            CALL LTP_sp_voucher_issue(v_booking_id);
            SET v_confirmed = 1;
        ELSE
            -- Tiền đã trừ nhưng đơn không còn chờ thanh toán: tạo yêu cầu hoàn tiền (như file 15).
            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), p_payment_id, v_amount,
                    -- Lý do in nhãn trạng thái tiếng Việt (khách và quản trị viên đọc được).
                    CONCAT('Thanh toán VNPay ', v_reference, ' đối chiếu khi đơn đang "',
                           CASE v_status WHEN 'cancelled' THEN 'Đã hủy' WHEN 'confirmed' THEN 'Đã xác nhận'
                                          WHEN 'completed' THEN 'Đã hoàn thành' WHEN 'awaiting_payment' THEN 'Chờ thanh toán'
                                          WHEN 'pending' THEN 'Chờ xác nhận' WHEN 'rejected' THEN 'Đã từ chối'
                                          ELSE v_status END,
                           '"; cần hoàn tiền cho khách.'),
                    'requested', NOW());

            INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'vnpay_reconcile_paid', NULL, NULL,
                    LEFT(CONCAT('Đã thấy giao dịch VNPay ', v_reference, ' thành công (mã GD ', v_txn_no,
                                ') khi đơn không còn chờ thanh toán; đã tạo yêu cầu hoàn tiền.'), 255), NOW());
        END IF;
    ELSE
        UPDATE payments
           SET status = 'failed', note = v_note
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'vnpay_reconcile_none', NULL, NULL,
                LEFT(CONCAT('Không có giao dịch VNPay ', v_reference, ': ', v_note), 255), NOW());
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_booking_id AS booking_id, v_confirmed AS confirmed;
END$$
DELIMITER ;
