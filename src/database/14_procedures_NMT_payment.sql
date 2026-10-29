-- =====================================================================
-- LocalTour v0.3 - 14_procedures_NMT_payment.sql
-- Mục đích  : Thanh toán của khách hàng (VNPay, VietQR) và đối chiếu chuyển khoản VietQR
--             của quản trị viên.
-- Phụ trách : Nguyễn Minh Thức (NMT) - Sprint 4: 4.5.1.2, 4.5.3.1, 4.5.3.2
-- Procedures: NMT_sp_payment_list, NMT_sp_payment_start, NMT_sp_payment_get,
--             NMT_sp_payment_transfer_submit, NMT_sp_admin_payment_queue,
--             NMT_sp_admin_payment_decide
-- Quy tắc   : * Chỉ đơn 'awaiting_payment' (đã xác nhận chỗ và giá) còn trong hạn giữ chỗ
--               mới thanh toán được. Số tiền = bookings.total_vnd (giá quản trị viên đã chốt).
--             * Mỗi lần bắt đầu thanh toán VNPay là một khoản 'pending' mới với mã riêng
--               (reference = mã đơn + P + số thứ tự, vd. LT518204P2) gửi làm vnp_TxnRef.
--             * VietQR dùng lại khoản VietQR 'pending' đang có của đơn (cùng nội dung chuyển
--               khoản); khách bấm "Tôi đã chuyển khoản" -> 'awaiting_reconciliation'.
--             * Đơn đang có khoản chờ đối chiếu thì không bắt đầu khoản mới (tránh thu hai lần);
--               đơn này cũng không bị tự hủy khi quá hạn (15_procedures_LTP_payment.sql).
--             * Quản trị viên đối chiếu: "Đã nhận tiền" -> khoản 'paid', đơn 'confirmed', cấp
--               voucher; "Không khớp" (bắt buộc lý do) -> khoản 'failed', đơn vẫn chờ thanh toán
--               tới hết hạn. Mỗi lần đối chiếu ghi admin_logs của đơn (NFR-09).
--             * Nhiều khoản tạo trong cùng một giây được xếp theo số thứ tự trong reference.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 12. NMT_sp_admin_payment_decide gọi LTP_sp_voucher_issue (file 15).
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_payment_list(p_user_id, p_code)
--   Các khoản thanh toán của đơn (chỉ đơn của tài khoản này), mới trước.
--   Cột: payment_id, method, reference, amount_vnd, status, created_at, submitted_at,
--   paid_at, response_code, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.method,
        COALESCE(p.reference, p.provider_txn_id) AS reference,
        p.amount_vnd,
        p.status,
        p.created_at,
        p.submitted_at,
        p.paid_at,
        p.response_code,
        p.note
    FROM payments p
    JOIN bookings b ON b.id = p.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY p.created_at DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_payment_start(p_user_id, p_code, p_method)
--   Bắt đầu thanh toán đơn p_code bằng p_method ('vnpay' / 'vietqr').
--   1 dòng: result, payment_id, reference, amount_vnd, expires_at.
--     result = 'ok'                      : khoản sẵn sàng (VNPay: khoản mới; VietQR: khoản
--                                          'pending' đang có hoặc khoản mới).
--              'not_found'               : không có đơn này trong tài khoản.
--              'not_payable'             : đơn không ở 'awaiting_payment' hoặc đã thanh toán.
--              'expired'                 : đã quá hạn giữ chỗ (đơn sẽ bị tự hủy).
--              'awaiting_reconciliation' : đã báo chuyển khoản, đang chờ đối chiếu.
--              'invalid'                 : phương thức không hợp lệ.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_start;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_start(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20),
    IN p_method  VARCHAR(10)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_code       VARCHAR(20) DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_total      BIGINT      DEFAULT NULL;
    DECLARE v_hold       DATETIME    DEFAULT NULL;
    DECLARE v_payment_id CHAR(36)    DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE v_count      INT         DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_method IS NULL OR p_method NOT IN ('vnpay', 'vietqr') THEN
        SELECT 'invalid' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT b.id, b.code, b.status, b.total_vnd, b.hold_expires_at
      INTO v_booking_id, v_code, v_status, v_total, v_hold
      FROM bookings b
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_status <> 'awaiting_payment'
       OR EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'paid') THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'awaiting_reconciliation') THEN
        ROLLBACK;
        SELECT 'awaiting_reconciliation' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_hold IS NULL OR v_hold <= NOW() THEN
        ROLLBACK;
        SELECT 'expired' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    -- VietQR: dùng lại khoản đang chờ chuyển khoản nếu đúng số tiền hiện tại.
    IF p_method = 'vietqr' THEN
        SELECT p.id, p.reference INTO v_payment_id, v_reference
          FROM payments p
         WHERE p.booking_id = v_booking_id
           AND p.method = 'vietqr'
           AND p.status = 'pending'
           AND p.amount_vnd = v_total
           AND p.reference IS NOT NULL
         ORDER BY p.created_at DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id
         LIMIT 1;
    END IF;

    IF v_payment_id IS NULL THEN
        SELECT COUNT(*) INTO v_count FROM payments p WHERE p.booking_id = v_booking_id;
        SET v_payment_id = UUID();
        SET v_reference = CONCAT(v_code, 'P', v_count + 1);

        INSERT INTO payments (id, booking_id, method, reference, provider_txn_id, amount_vnd, status,
                              expires_at, paid_at, created_at)
        VALUES (v_payment_id, v_booking_id, p_method, v_reference, NULL, v_total, 'pending',
                v_hold, NULL, NOW());
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_payment_id AS payment_id, v_reference AS reference, v_total AS amount_vnd, v_hold AS expires_at;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_payment_get(p_user_id, p_code, p_method)
--   Khoản mới nhất của đơn theo phương thức (trang chuyển khoản VietQR), 0 hoặc 1 dòng.
--   Cột: payment_id, method, reference, amount_vnd, status, created_at, submitted_at, note,
--   booking_status, hold_expires_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_get;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_get(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20),
    IN p_method  VARCHAR(10)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.method,
        p.reference,
        p.amount_vnd,
        p.status,
        p.created_at,
        p.submitted_at,
        p.note,
        b.status        AS booking_status,
        b.hold_expires_at
    FROM payments p
    JOIN bookings b ON b.id = p.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
      AND p.method = (p_method COLLATE utf8mb4_unicode_ci)
      AND p.reference IS NOT NULL
    ORDER BY p.created_at DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id
    LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_payment_transfer_submit(p_user_id, p_code, p_payment_id)
--   Khách báo đã chuyển khoản VietQR: khoản 'pending' -> 'awaiting_reconciliation'.
--   1 dòng: result = 'ok' | 'already' (đã báo rồi) | 'not_found' | 'not_payable' | 'expired'.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_transfer_submit;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_transfer_submit(
    IN p_user_id    CHAR(36),
    IN p_code       VARCHAR(20),
    IN p_payment_id CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_hold       DATETIME    DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT p.status, p.reference, b.id, b.status, b.hold_expires_at
      INTO v_pay_status, v_reference, v_booking_id, v_status, v_hold
      FROM payments p
      JOIN bookings b ON b.id = p.booking_id
     WHERE p.id = (p_payment_id COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vietqr'
       AND b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    IF v_pay_status = 'awaiting_reconciliation' THEN
        ROLLBACK;
        SELECT 'already' AS result;
        LEAVE proc;
    END IF;

    IF v_status <> 'awaiting_payment' OR v_pay_status <> 'pending' THEN
        ROLLBACK;
        SELECT 'not_payable' AS result;
        LEAVE proc;
    END IF;

    IF v_hold IS NULL OR v_hold <= NOW() THEN
        ROLLBACK;
        SELECT 'expired' AS result;
        LEAVE proc;
    END IF;

    UPDATE payments
       SET status = 'awaiting_reconciliation', submitted_at = NOW()
     WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'customer', p_user_id, 'transfer_submitted', NULL, NULL,
            CONCAT('Khách báo đã chuyển khoản VietQR, nội dung ', v_reference), NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_payment_queue()
--   Khoản VietQR khách đã báo chuyển khoản, đang chờ quản trị viên đối chiếu (báo trước
--   lên trước). Cột: payment_id, reference, amount_vnd, submitted_at, created_at, booking_id,
--   code, booking_status, total_vnd, hold_expires_at, contact_name, contact_phone,
--   tour_title, starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_payment_queue;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_payment_queue()
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        COALESCE(p.reference, p.provider_txn_id) AS reference,
        p.amount_vnd,
        p.submitted_at,
        p.created_at,
        b.id            AS booking_id,
        b.code,
        b.status        AS booking_status,
        b.total_vnd,
        b.hold_expires_at,
        b.contact_name,
        b.contact_phone,
        t.title         AS tour_title,
        s.starts_at
    FROM payments p
    JOIN bookings b  ON b.id = p.booking_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE p.method = 'vietqr'
      AND p.status = 'awaiting_reconciliation'
    ORDER BY COALESCE(p.submitted_at, p.created_at), p.id
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_payment_decide(p_payment_id, p_decision, p_actor_user_id, p_note)
--   Đối chiếu một khoản VietQR đang 'awaiting_reconciliation'.
--   p_decision = 'confirm' (đã nhận đúng số tiền) hoặc 'reject' (không thấy / không khớp).
--   1 dòng: result, booking_id.
--     result = 'ok' | 'forbidden' | 'not_found' | 'invalid' (quyết định sai)
--              'note_required' (từ chối mà không có lý do)
--              'not_payable' (khoản không còn chờ đối chiếu hoặc đơn không còn chờ thanh toán)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_payment_decide;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_payment_decide(
    IN p_payment_id    CHAR(36),
    IN p_decision      VARCHAR(10),
    IN p_actor_user_id CHAR(36),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_reference  VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_note       VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision IS NULL OR p_decision NOT IN ('confirm', 'reject') THEN
        SELECT 'invalid' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT p.booking_id, p.status, COALESCE(p.reference, p.provider_txn_id)
      INTO v_booking_id, v_pay_status, v_reference
      FROM payments p
     WHERE p.id = (p_payment_id COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vietqr'
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    SELECT b.status INTO v_status FROM bookings b WHERE b.id = v_booking_id FOR UPDATE;

    IF v_pay_status <> 'awaiting_reconciliation' OR v_status <> 'awaiting_payment' THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision = 'reject' AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision = 'confirm' THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), note = v_note
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

        -- Khoản khác còn chờ của đơn không dùng nữa.
        UPDATE payments
           SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
         WHERE booking_id = v_booking_id
           AND id <> (p_payment_id COLLATE utf8mb4_unicode_ci)
           AND status = 'pending';

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'payment_confirm', 'awaiting_payment', 'confirmed',
                LEFT(CONCAT('Đã nhận chuyển khoản VietQR ', v_reference, IF(v_note IS NULL, '', CONCAT(': ', v_note))), 255), NOW());

        CALL LTP_sp_voucher_issue(v_booking_id);
    ELSE
        UPDATE payments
           SET status = 'failed', note = v_note
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'payment_reject', NULL, NULL,
                LEFT(CONCAT('Không khớp chuyển khoản VietQR ', v_reference, ': ', v_note), 255), NOW());
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_booking_id AS booking_id;
END$$
DELIMITER ;
