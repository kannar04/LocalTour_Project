-- =====================================================================
-- LocalTour v0.3 - 15_procedures_LTP_payment.sql
-- Mục đích  : Kết quả thanh toán VNPay (Return URL và IPN), tự hủy đơn quá hạn giữ chỗ,
--             cấp voucher sau khi thanh toán được xác minh và lịch sử của đơn.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 4: 4.3.3.2, 4.5.2.1, 4.5.2.2, 4.5.4.1, 4.5.4.2
-- Procedures: LTP_sp_voucher_issue (dùng nội bộ, không trả dòng),
--             LTP_sp_payment_vnpay_result, LTP_sp_booking_expire_holds,
--             LTP_sp_booking_history, LTP_sp_customer_booking_history
-- Quy tắc   : * Ứng dụng kiểm tra chữ ký VNPay (HMAC-SHA512) TRƯỚC khi gọi
--               LTP_sp_payment_vnpay_result; procedure chỉ nhận kết quả đã xác minh.
--             * Idempotent: Return URL và IPN cùng báo một giao dịch -> lần đầu ghi kết quả,
--               các lần sau trả 'already', không đổi gì. Khoản bị hệ thống đóng ('failed' khi
--               đơn quá hạn, chưa có kết quả VNPay: response_code NULL) vẫn nhận kết quả VNPay
--               tới muộn, để khách đã bị trừ tiền được hoàn tiền.
--             * VNPay thành công khi đơn còn 'awaiting_payment' -> đơn 'confirmed', cấp voucher,
--               các khoản khác còn 'pending' của đơn -> 'failed'. Đơn đã hết hạn / đã hủy /
--               đã thanh toán bằng khoản khác -> khoản vẫn ghi 'paid' và tạo yêu cầu hoàn tiền
--               ('requested') để quản trị viên xử lý.
--             * Tự hủy (4.5.4.1): đơn 'awaiting_payment' quá hold_expires_at (24 giờ từ lúc
--               xác nhận chỗ) và KHÔNG có khoản VietQR đang chờ đối chiếu hay khoản đã thanh
--               toán -> 'cancelled', trả lại chỗ, khoản 'pending' -> 'failed'.
--             * Voucher (4.5.4.2): chỉ cấp cho đơn 'confirmed' / 'completed', mỗi đơn một mã
--               LTV + 6 số của mã đơn + 4 số ngẫu nhiên (vd. LTV5182040427), không cấp lại.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 12 (bảng booking_events, cột voucher_code, payments.reference).
--             07 và 14 gọi LTP_sp_voucher_issue: import đủ 01 -> 15 trước khi chạy ứng dụng.
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_voucher_issue(p_booking_id)
--   Dùng nội bộ (CALL từ procedure khác, trong transaction của procedure gọi).
--   Không SELECT gì để không chen result set vào kết quả của procedure gọi.
--   Đơn chưa 'confirmed' / 'completed' hoặc đã có voucher -> không làm gì.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_voucher_issue;

DELIMITER $$
CREATE PROCEDURE LTP_sp_voucher_issue(
    IN p_booking_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    UPDATE bookings
       SET voucher_code = CONCAT('LTV', SUBSTRING(code, 3), LPAD(FLOOR(RAND() * 10000), 4, '0')),
           voucher_issued_at = NOW()
     WHERE id = (p_booking_id COLLATE utf8mb4_unicode_ci)
       AND status IN ('confirmed', 'completed')
       AND voucher_code IS NULL;

    IF ROW_COUNT() > 0 THEN
        INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
        SELECT UUID(), b.id, 'system', NULL, 'voucher_issued', NULL, NULL, CONCAT('Mã voucher ', b.voucher_code), NOW()
          FROM bookings b
         WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci);
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_payment_vnpay_result(p_reference, p_amount_vnd, p_response_code, p_txn_status,
--                             p_txn_no, p_bank_code)
--   p_reference    : vnp_TxnRef (payments.reference).
--   p_amount_vnd   : vnp_Amount / 100 (ứng dụng đã đổi); -1 = sai dạng.
--   p_response_code: vnp_ResponseCode; p_txn_status: vnp_TransactionStatus ('00' = thành công).
--   p_txn_no       : vnp_TransactionNo (mã giao dịch tại VNPay); p_bank_code: vnp_BankCode.
--   1 dòng: result, booking_code, payment_status, booking_status.
--     result = 'ok'             : đã ghi kết quả lần đầu.
--              'already'        : giao dịch này đã có kết quả (Return URL và IPN cùng báo).
--              'not_found'      : không có khoản VNPay với mã này.
--              'invalid_amount' : số tiền VNPay báo khác số tiền của khoản; không đổi gì.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_payment_vnpay_result;

DELIMITER $$
CREATE PROCEDURE LTP_sp_payment_vnpay_result(
    IN p_reference     VARCHAR(32),
    IN p_amount_vnd    BIGINT,
    IN p_response_code VARCHAR(10),
    IN p_txn_status    VARCHAR(10),
    IN p_txn_no        VARCHAR(100),
    IN p_bank_code     VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_payment_id CHAR(36)    DEFAULT NULL;
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_amount     BIGINT      DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_code   VARCHAR(10) DEFAULT NULL;
    DECLARE v_code       VARCHAR(20) DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_success    BOOLEAN     DEFAULT FALSE;
    DECLARE v_txn_no     VARCHAR(100) DEFAULT NULLIF(TRIM(p_txn_no), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT p.id, p.booking_id, p.amount_vnd, p.status, p.response_code
      INTO v_payment_id, v_booking_id, v_amount, v_pay_status, v_pay_code
      FROM payments p
     WHERE p.reference = (TRIM(p_reference) COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vnpay'
       FOR UPDATE;

    IF v_payment_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS booking_code, NULL AS payment_status, NULL AS booking_status;
        LEAVE proc;
    END IF;

    -- Khóa đơn (cùng thứ tự khóa với các procedure khác: khoản rồi đơn).
    SELECT b.code, b.status INTO v_code, v_status
      FROM bookings b
     WHERE b.id = v_booking_id
       FOR UPDATE;

    IF NOT (p_amount_vnd <=> v_amount) THEN
        ROLLBACK;
        SELECT 'invalid_amount' AS result, v_code AS booking_code, v_pay_status AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    IF v_pay_status <> 'pending' AND NOT (v_pay_status = 'failed' AND v_pay_code IS NULL) THEN
        ROLLBACK;
        SELECT 'already' AS result, v_code AS booking_code, v_pay_status AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    SET v_success = (p_response_code = '00' AND p_txn_status = '00');

    -- Một sự kiện cho mỗi khoản: khoản đã có kết quả thì không tới được đây lần thứ hai.
    INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at)
    VALUES (UUID(), v_payment_id, CONCAT('VNPAY-', p_reference), COALESCE(NULLIF(p_response_code, ''), '??'), TRUE, NOW());

    IF v_success THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), provider_txn_id = v_txn_no,
               response_code = p_response_code, bank_code = NULLIF(p_bank_code, '')
         WHERE id = v_payment_id;

        IF v_status = 'awaiting_payment' THEN
            UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'vnpay', NULL, 'vnpay_paid', 'awaiting_payment', 'confirmed',
                    CONCAT('Thanh toán VNPay thành công, mã giao dịch ', COALESCE(v_txn_no, p_reference)), NOW());

            -- Các lần thanh toán khác chưa xong của đơn không dùng nữa.
            UPDATE payments
               SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
             WHERE booking_id = v_booking_id
               AND id <> v_payment_id
               AND status = 'pending';

            CALL LTP_sp_voucher_issue(v_booking_id);
            SET v_status = 'confirmed';
        ELSE
            -- Tiền đã trừ ở ngân hàng nhưng đơn không còn chờ thanh toán: tạo yêu cầu hoàn tiền.
            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), v_payment_id, v_amount,
                    CONCAT('Thanh toán VNPay ', p_reference, ' tới khi đơn đang "', v_status, '"; cần hoàn tiền cho khách.'),
                    'requested', NOW());

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'vnpay', NULL, 'refund_requested', NULL, NULL,
                    CONCAT('Khoản VNPay ', p_reference, ' tới sau khi đơn không còn chờ thanh toán; đã tạo yêu cầu hoàn tiền.'), NOW());
        END IF;

        COMMIT;
        SELECT 'ok' AS result, v_code AS booking_code, 'paid' AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    UPDATE payments
       SET status = 'failed', provider_txn_id = NULLIF(v_txn_no, '0'),
           response_code = NULLIF(p_response_code, ''), bank_code = NULLIF(p_bank_code, '')
     WHERE id = v_payment_id;

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'vnpay', NULL, 'vnpay_failed', NULL, NULL,
            CONCAT('Thanh toán VNPay không thành công (mã ', COALESCE(NULLIF(p_response_code, ''), '??'), ')'), NOW());

    COMMIT;
    SELECT 'ok' AS result, v_code AS booking_code, 'failed' AS payment_status, v_status AS booking_status;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_booking_expire_holds()
--   Hủy các đơn 'awaiting_payment' đã quá hạn giữ chỗ (hold_expires_at <= NOW()) mà không
--   có khoản 'awaiting_reconciliation' (VietQR chờ đối chiếu) hay 'paid'. Mỗi đơn một
--   transaction: trả lại chỗ, khoản 'pending' -> 'failed', ghi booking_events (system).
--   Gọi từ ứng dụng mỗi khi mở trang đơn / trang quản trị, và từ scripts/expire_holds.php
--   (Task Scheduler). Chạy nhiều lần cùng lúc vẫn an toàn (khóa dòng, kiểm tra lại).
--   1 dòng: expired (số đơn đã hủy lần này).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_booking_expire_holds;

DELIMITER $$
CREATE PROCEDURE LTP_sp_booking_expire_holds()
MODIFIES SQL DATA
BEGIN
    DECLARE v_booking_id CHAR(36) DEFAULT NULL;
    DECLARE v_schedule   CHAR(36) DEFAULT NULL;
    DECLARE v_people     INT      DEFAULT 0;
    DECLARE v_expired    INT      DEFAULT 0;
    DECLARE v_done       BOOLEAN  DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    WHILE NOT v_done DO
        SET v_booking_id = NULL;
        START TRANSACTION;

        SELECT b.id, b.schedule_id INTO v_booking_id, v_schedule
          FROM bookings b
         WHERE b.status = 'awaiting_payment'
           AND b.hold_expires_at <= NOW()
           AND NOT EXISTS (SELECT 1 FROM payments p
                            WHERE p.booking_id = b.id
                              AND p.status IN ('awaiting_reconciliation', 'paid'))
         ORDER BY b.hold_expires_at, b.id
         LIMIT 1
           FOR UPDATE;

        IF v_booking_id IS NULL THEN
            COMMIT;
            SET v_done = TRUE;
        ELSE
            SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
              FROM booking_lines bl
             WHERE bl.booking_id = v_booking_id;

            -- Trả lại chỗ như khi hủy đơn đang giữ chỗ (07): không vượt capacity, 'full' mở lại.
            UPDATE schedules
               SET remaining = LEAST(capacity, remaining + v_people),
                   status = IF(status = 'full' AND remaining > 0, 'open', status)
             WHERE id = v_schedule;

            UPDATE bookings SET status = 'cancelled', hold_expires_at = NULL WHERE id = v_booking_id;

            UPDATE payments
               SET status = 'failed', note = 'Đơn đã quá hạn thanh toán.'
             WHERE booking_id = v_booking_id
               AND status IN ('pending', 'processing');

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'system', NULL, 'hold_expired', 'awaiting_payment', 'cancelled',
                    'Quá hạn thanh toán 24 giờ: hệ thống tự hủy đơn và trả lại chỗ.', NOW());

            COMMIT;
            SET v_expired = v_expired + 1;
        END IF;
    END WHILE;

    SELECT v_expired AS expired;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_booking_history(p_booking_id)
--   Lịch sử đầy đủ của một đơn cho trang quản trị (NFR-09): booking_events (khách, hệ thống,
--   VNPay) và admin_logs của đơn (quản trị viên), cũ trước.
--   Cột: created_at, actor ('customer' / 'system' / 'vnpay' / 'admin'), actor_name (NULL với
--   hệ thống, VNPay), action, from_status, to_status, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_booking_history;

DELIMITER $$
CREATE PROCEDURE LTP_sp_booking_history(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT h.created_at, h.actor, h.actor_name, h.action, h.from_status, h.to_status, h.note
      FROM (
        SELECT e.created_at, e.actor, u.name AS actor_name, e.action, e.from_status, e.to_status, e.note, e.id
          FROM booking_events e
          LEFT JOIN users u ON u.id = e.actor_user_id
         WHERE e.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
        UNION ALL
        SELECT l.created_at, 'admin', u.name, l.action, l.from_status, l.to_status, l.note, l.id
          FROM admin_logs l
          JOIN users u ON u.id = l.actor_user_id
         WHERE l.target_type = 'booking'
           AND l.target_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
      ) h
     ORDER BY h.created_at,
              -- Các dòng ghi trong cùng một giao dịch: tạo đơn, chốt giá, đổi trạng thái, rồi voucher / hoàn tiền.
              CASE h.action WHEN 'created' THEN 0 WHEN 'booking_total' THEN 1
                            WHEN 'voucher_issued' THEN 3 WHEN 'refund_requested' THEN 3 ELSE 2 END,
              h.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_customer_booking_history(p_user_id, p_code)
--   Lịch sử của đơn cho trang "Đơn của tôi" (FR-11): như LTP_sp_booking_history nhưng chỉ
--   đơn của tài khoản p_user_id và không trả tên quản trị viên (trang hiện "LocalTour").
--   Cột: created_at, actor, action, from_status, to_status, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_customer_booking_history;

DELIMITER $$
CREATE PROCEDURE LTP_sp_customer_booking_history(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT h.created_at, h.actor, h.action, h.from_status, h.to_status, h.note
      FROM (
        SELECT e.created_at, e.actor, e.action, e.from_status, e.to_status, e.note, e.id
          FROM booking_events e
          JOIN bookings b ON b.id = e.booking_id
         WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
        UNION ALL
        SELECT l.created_at, 'admin', l.action, l.from_status, l.to_status, l.note, l.id
          FROM admin_logs l
          JOIN bookings b ON b.id = l.target_id
         WHERE l.target_type = 'booking'
           AND b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
      ) h
     ORDER BY h.created_at,
              -- Các dòng ghi trong cùng một giao dịch: tạo đơn, chốt giá, đổi trạng thái, rồi voucher / hoàn tiền.
              CASE h.action WHEN 'created' THEN 0 WHEN 'booking_total' THEN 1
                            WHEN 'voucher_issued' THEN 3 WHEN 'refund_requested' THEN 3 ELSE 2 END,
              h.id;
END$$
DELIMITER ;
