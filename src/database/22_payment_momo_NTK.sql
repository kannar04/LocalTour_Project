-- =====================================================================
-- LocalTour v0.5 - 22_payment_momo_NTK.sql
-- Mục đích  : Thêm MoMo (API v2, môi trường thử) làm phương thức thanh toán thứ ba bên cạnh
--             VNPay và VietQR cho đơn "Chờ thanh toán".
--   1. payments.method thêm 'momo'; booking_events.actor thêm 'momo' (kết quả MoMo).
--      Giữ nguyên các giá trị đang có của hai ENUM (kể cả giá trị file khác thêm vào).
--   2. NTK_sp_payment_momo_start : tạo khoản MoMo 'pending' mới cho đơn (như VNPay), trả
--      orderId gửi MoMo = reference + '-' + 10 ký tự đầu MD5(payment_id), vd.
--      LT518204P2-3f9a1c2b7d (orderId không trùng giữa các lần import lại database).
--   3. NTK_sp_payment_momo_result: ghi kết quả MoMo đã xác minh (trang trả về sau khi tra
--      cứu bằng API query có chữ ký, IPN, hoặc quản trị viên tra cứu). Idempotent như
--      LTP_sp_payment_vnpay_result: lần đầu ghi, các lần sau trả 'already'.
--   4. NTK_sp_admin_momo_queue   : khoản MoMo chưa rõ kết quả cho trang quản trị.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Quy tắc   : * Ứng dụng kiểm tra chữ ký MoMo (HMAC-SHA256) và tra cứu lại giao dịch TRƯỚC
--               khi gọi NTK_sp_payment_momo_result; procedure chỉ nhận kết quả đã xác minh.
--             * Số tiền MoMo báo phải bằng payments.amount_vnd, ngược lại không đổi gì.
--             * MoMo thành công khi đơn còn 'awaiting_payment' -> đơn 'confirmed', cấp voucher,
--               các khoản 'pending' khác -> 'failed'. Đơn đã hết hạn / đã hủy / đã thanh toán
--               bằng khoản khác -> khoản vẫn 'paid' và tạo yêu cầu hoàn tiền ('requested').
--             * Khoản bị hệ thống đóng ('failed', chưa có kết quả MoMo: response_code NULL)
--               vẫn nhận kết quả MoMo tới muộn.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 21 (gọi LTP_sp_voucher_issue của file 15).
--             Chạy lại được (ENUM đã có 'momo' thì bỏ qua, DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. Thêm 'momo' vào payments.method và booking_events.actor.
--    Đọc ENUM hiện tại rồi nối thêm 'momo' (không ghi đè giá trị file khác đã thêm).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_migrate_momo;

DELIMITER $$
CREATE PROCEDURE NTK_sp_migrate_momo()
MODIFIES SQL DATA
BEGIN
    DECLARE v_type TEXT DEFAULT NULL;

    SELECT c.COLUMN_TYPE INTO v_type
      FROM information_schema.COLUMNS c
     WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = 'payments' AND c.COLUMN_NAME = 'method';
    IF v_type IS NOT NULL AND v_type NOT LIKE '%''momo''%' THEN
        SET @ntk_momo_sql = CONCAT('ALTER TABLE payments MODIFY COLUMN method ',
                                   LEFT(v_type, CHAR_LENGTH(v_type) - 1), ',''momo'') NOT NULL');
        PREPARE ntk_momo_stmt FROM @ntk_momo_sql;
        EXECUTE ntk_momo_stmt;
        DEALLOCATE PREPARE ntk_momo_stmt;
    END IF;

    SET v_type = NULL;
    SELECT c.COLUMN_TYPE INTO v_type
      FROM information_schema.COLUMNS c
     WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = 'booking_events' AND c.COLUMN_NAME = 'actor';
    IF v_type IS NOT NULL AND v_type NOT LIKE '%''momo''%' THEN
        SET @ntk_momo_sql = CONCAT('ALTER TABLE booking_events MODIFY COLUMN actor ',
                                   LEFT(v_type, CHAR_LENGTH(v_type) - 1), ',''momo'') NOT NULL');
        PREPARE ntk_momo_stmt FROM @ntk_momo_sql;
        EXECUTE ntk_momo_stmt;
        DEALLOCATE PREPARE ntk_momo_stmt;
    END IF;
END$$
DELIMITER ;

CALL NTK_sp_migrate_momo();
DROP PROCEDURE IF EXISTS NTK_sp_migrate_momo;

-- ---------------------------------------------------------------------
-- NTK_sp_payment_momo_start(p_user_id, p_code, p_min_vnd, p_max_vnd)
--   Bắt đầu thanh toán MoMo cho đơn p_code của tài khoản p_user_id: mỗi lần là một khoản
--   'pending' mới (orderId MoMo chỉ dùng được một lần). p_min_vnd / p_max_vnd: giới hạn số
--   tiền MoMo nhận (MomoGateway).
--   1 dòng: result, payment_id, reference, order_id, amount_vnd, expires_at.
--     result = 'ok'                      : khoản mới sẵn sàng gửi MoMo.
--              'not_found'               : không có đơn này trong tài khoản.
--              'not_payable'             : đơn không ở 'awaiting_payment' hoặc đã thanh toán.
--              'expired'                 : đã quá hạn giữ chỗ (đơn sẽ bị tự hủy).
--              'awaiting_reconciliation' : đã báo chuyển khoản VietQR, đang chờ đối chiếu.
--              'invalid_amount'          : tổng tiền ngoài giới hạn của MoMo.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_payment_momo_start;

DELIMITER $$
CREATE PROCEDURE NTK_sp_payment_momo_start(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20),
    IN p_min_vnd BIGINT,
    IN p_max_vnd BIGINT
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

    START TRANSACTION;

    SELECT b.id, b.code, b.status, b.total_vnd, b.hold_expires_at
      INTO v_booking_id, v_code, v_status, v_total, v_hold
      FROM bookings b
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_status <> 'awaiting_payment'
       OR EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'paid') THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'awaiting_reconciliation') THEN
        ROLLBACK;
        SELECT 'awaiting_reconciliation' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_hold IS NULL OR v_hold <= NOW() THEN
        ROLLBACK;
        SELECT 'expired' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_total IS NULL OR v_total < p_min_vnd OR v_total > p_max_vnd THEN
        ROLLBACK;
        SELECT 'invalid_amount' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, v_total AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_count FROM payments p WHERE p.booking_id = v_booking_id;
    SET v_payment_id = UUID();
    SET v_reference = CONCAT(v_code, 'P', v_count + 1);

    INSERT INTO payments (id, booking_id, method, reference, provider_txn_id, amount_vnd, status,
                          expires_at, paid_at, created_at)
    VALUES (v_payment_id, v_booking_id, 'momo', v_reference, NULL, v_total, 'pending',
            v_hold, NULL, NOW());

    COMMIT;
    SELECT 'ok' AS result, v_payment_id AS payment_id, v_reference AS reference,
           CONCAT(v_reference, '-', LEFT(MD5(v_payment_id), 10)) AS order_id,
           v_total AS amount_vnd, v_hold AS expires_at;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_payment_momo_result(p_order_id, p_amount_vnd, p_result_code, p_trans_id,
--                            p_pay_type, p_source)
--   p_order_id   : orderId gửi MoMo (NTK_sp_payment_momo_start.order_id).
--   p_amount_vnd : số tiền MoMo báo; -1 = sai dạng.
--   p_result_code: resultCode của MoMo ('0' = thành công); p_trans_id: transId tại MoMo;
--   p_pay_type   : payType (napas, credit, qr, webApp...).
--   p_source     : 'return' (trang trả về), 'ipn', 'admin' (quản trị viên tra cứu),
--                  'create' (MoMo từ chối tạo giao dịch). Chỉ ghi vào lịch sử đơn.
--   1 dòng: result, booking_code, payment_status, booking_status.
--     result = 'ok'             : lần đầu khoản này thành 'paid' (đơn 'confirmed', hoặc đơn đã
--                                 hủy / hết hạn: tạo yêu cầu hoàn tiền).
--              'failed'         : lần đầu ghi kết quả không thành công.
--              'already'        : khoản đã có kết quả (trang trả về và IPN cùng báo).
--              'not_found'      : không có khoản MoMo với orderId này.
--              'invalid_amount' : số tiền MoMo báo khác số tiền của khoản; không đổi gì.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_payment_momo_result;

DELIMITER $$
CREATE PROCEDURE NTK_sp_payment_momo_result(
    IN p_order_id    VARCHAR(64),
    IN p_amount_vnd  BIGINT,
    IN p_result_code VARCHAR(10),
    IN p_trans_id    VARCHAR(100),
    IN p_pay_type    VARCHAR(20),
    IN p_source      VARCHAR(10)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_payment_id CHAR(36)    DEFAULT NULL;
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE v_amount     BIGINT      DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_code   VARCHAR(10) DEFAULT NULL;
    DECLARE v_code       VARCHAR(20) DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_order_id   VARCHAR(64) DEFAULT TRIM(p_order_id);
    DECLARE v_result     VARCHAR(10) DEFAULT COALESCE(NULLIF(TRIM(p_result_code), ''), '??');
    DECLARE v_trans_id   VARCHAR(100) DEFAULT NULLIF(NULLIF(TRIM(p_trans_id), ''), '0');
    DECLARE v_source     VARCHAR(40) CHARACTER SET utf8mb4 DEFAULT
        CASE p_source WHEN 'ipn' THEN 'qua IPN' WHEN 'admin' THEN 'quản trị viên tra cứu'
                      WHEN 'create' THEN 'lúc tạo giao dịch' ELSE 'qua trang trả về' END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT p.id, p.booking_id, p.reference, p.amount_vnd, p.status, p.response_code
      INTO v_payment_id, v_booking_id, v_reference, v_amount, v_pay_status, v_pay_code
      FROM payments p
     WHERE p.reference = (SUBSTRING_INDEX(v_order_id, '-', 1) COLLATE utf8mb4_unicode_ci)
       AND p.method = 'momo'
       FOR UPDATE;

    -- orderId phải đúng khoản này (không nhận orderId của lần import database trước).
    IF v_payment_id IS NULL
       OR BINARY CONCAT(v_reference, '-', LEFT(MD5(v_payment_id), 10)) <> BINARY v_order_id THEN
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

    -- Một sự kiện cho mỗi khoản: khoản đã có kết quả thì không tới được đây lần thứ hai.
    INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at)
    VALUES (UUID(), v_payment_id, CONCAT('MOMO-', v_order_id), v_result, TRUE, NOW());

    IF v_result = '0' THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), provider_txn_id = v_trans_id,
               response_code = v_result, bank_code = NULLIF(TRIM(p_pay_type), '')
         WHERE id = v_payment_id;

        IF v_status = 'awaiting_payment' THEN
            UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'momo', NULL, 'momo_paid', 'awaiting_payment', 'confirmed',
                    LEFT(CONCAT('Thanh toán MoMo thành công, mã giao dịch ', COALESCE(v_trans_id, v_reference),
                                ' (', v_source, ')'), 255), NOW());

            -- Các lần thanh toán khác chưa xong của đơn không dùng nữa.
            UPDATE payments
               SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
             WHERE booking_id = v_booking_id
               AND id <> v_payment_id
               AND status = 'pending';

            CALL LTP_sp_voucher_issue(v_booking_id);
            SET v_status = 'confirmed';
        ELSE
            -- Tiền đã trừ nhưng đơn không còn chờ thanh toán: tạo yêu cầu hoàn tiền.
            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), v_payment_id, v_amount,
                    -- Lý do in nhãn trạng thái tiếng Việt (khách và quản trị viên đọc được).
                    LEFT(CONCAT('Thanh toán MoMo ', v_reference, ' tới khi đơn đang "',
                           CASE v_status WHEN 'cancelled' THEN 'Đã hủy' WHEN 'confirmed' THEN 'Đã xác nhận'
                                          WHEN 'completed' THEN 'Đã hoàn thành' WHEN 'awaiting_payment' THEN 'Chờ thanh toán'
                                          WHEN 'pending' THEN 'Chờ xác nhận' WHEN 'rejected' THEN 'Đã từ chối'
                                          ELSE v_status END,
                           '"; cần hoàn tiền cho khách.'), 255),
                    'requested', NOW());

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'momo', NULL, 'refund_requested', NULL, NULL,
                    CONCAT('Khoản MoMo ', v_reference, ' tới sau khi đơn không còn chờ thanh toán; đã tạo yêu cầu hoàn tiền.'), NOW());
        END IF;

        COMMIT;
        SELECT 'ok' AS result, v_code AS booking_code, 'paid' AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    UPDATE payments
       SET status = 'failed', provider_txn_id = v_trans_id,
           response_code = v_result, bank_code = NULLIF(TRIM(p_pay_type), '')
     WHERE id = v_payment_id;

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'momo', NULL, 'momo_failed', NULL, NULL,
            LEFT(CONCAT('Thanh toán MoMo không thành công (mã ', v_result, ', ', v_source, ')'), 255), NOW());

    COMMIT;
    SELECT 'failed' AS result, v_code AS booking_code, 'failed' AS payment_status, v_status AS booking_status;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_momo_queue(p_booking_id, p_payment_id)
--   Khoản MoMo chưa rõ kết quả: MoMo chưa báo gì (không có payment_events, response_code
--   NULL), vì khách đóng trang MoMo, IPN không tới được (chạy ở localhost) hoặc lúc trả về
--   chưa tra cứu được. Gồm khoản 'pending' đã quá 15 phút (hết hạn đơn MoMo, MomoGateway) và
--   khoản bị hệ thống đóng 'failed' khi đơn không được thanh toán bằng khoản khác.
--   Quản trị viên bấm "Tra cứu MoMo": ứng dụng gọi API query rồi ghi qua
--   NTK_sp_payment_momo_result.
--   p_booking_id / p_payment_id: NULL = không lọc. Tối đa 200 dòng, tạo trước lên trước.
--   Cột: payment_id, reference, order_id, amount_vnd, status, created_at, booking_id, code,
--   booking_status, hold_expires_at, contact_name, contact_phone, tour_title, starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_momo_queue;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_momo_queue(
    IN p_booking_id CHAR(36),
    IN p_payment_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.reference,
        CONCAT(p.reference, '-', LEFT(MD5(p.id), 10)) AS order_id,
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
    WHERE p.method = 'momo'
      AND p.reference IS NOT NULL
      AND p.response_code IS NULL
      AND NOT EXISTS (SELECT 1 FROM payment_events e WHERE e.payment_id = p.id)
      AND ((p.status = 'pending' AND p.created_at <= NOW() - INTERVAL 15 MINUTE)
           OR (p.status = 'failed' AND b.status NOT IN ('confirmed', 'completed')))
      AND (p_booking_id IS NULL OR b.id = (p_booking_id COLLATE utf8mb4_unicode_ci))
      AND (p_payment_id IS NULL OR p.id = (p_payment_id COLLATE utf8mb4_unicode_ci))
    ORDER BY p.created_at, p.id
    LIMIT 200;
END$$
DELIMITER ;
