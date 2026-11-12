-- =====================================================================
-- LocalTour v0.6 - 30_procedures_NTK_payout.sql
-- Mục đích  : Dòng tiền sau tour: đơn tự "Đã hoàn thành" khi lịch khởi hành kết thúc, phí dịch vụ
--             LocalTour, khoản chi trả cho đơn vị tổ chức (quản trị viên chuyển khoản ngoài hệ
--             thống rồi ghi nhận đã chi trả), thông số vận hành và tài khoản nhận tiền của đơn vị.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Procedures: NTK_sp_setting_commission_rate, NTK_sp_setting_payouts_from, NTK_sp_setting_put,
--             NTK_sp_payout_schedule_ready (4 procedure dùng nội bộ),
--             NTK_sp_setting_list, NTK_sp_admin_setting_save,
--             NTK_sp_payout_sweep,
--             NTK_sp_admin_payout_list, NTK_sp_admin_payout_summary, NTK_sp_admin_payout_detail,
--             NTK_sp_admin_payout_item_list, NTK_sp_admin_payout_pay,
--             NTK_sp_admin_payout_waiting_list, NTK_sp_admin_refund_open_list,
--             NTK_sp_admin_refund_complete,
--             NTK_sp_host_bank, NTK_sp_host_bank_save,
--             NTK_sp_host_payout_summary, NTK_sp_host_payout_list, NTK_sp_host_payout_detail,
--             NTK_sp_host_payout_item_list
-- Quy tắc   : * Khách trả đúng giá niêm yết cho LocalTour. Phí dịch vụ LocalTour lấy từ phần của
--               đơn vị tổ chức: thực nhận = tiền thực thu - phí dịch vụ. Tổng tiền đơn và số tiền
--               thanh toán không đổi.
--             * % phí dịch vụ: một thông số chung (settings 'commission_percent', mặc định 10),
--               chụp vào bookings.commission_rate lúc đặt. Đơn có commission_rate NULL (đơn tạo
--               trước file 28) tính theo thông số lúc lập khoản chi trả.
--             * Tự hoàn thành: đơn 'confirmed' của lịch đã kết thúc (schedules.ends_at <= NOW())
--               chuyển 'completed', ghi booking_events (actor 'system', action 'booking_status').
--               Đơn đang có yêu cầu đổi ngày / hủy tour chờ xử lý thì chưa tự hoàn thành (quản trị
--               viên xử lý yêu cầu trước). Lịch 'open' / 'full' đã kết thúc chuyển 'completed'.
--               Nút "Hoàn thành" của quản trị viên (file 07) vẫn dùng được.
--             * Khoản chi trả: mỗi lịch khởi hành đã kết thúc MỘT khoản (host_payouts, UNIQUE
--               schedule_id). Chỉ lịch kết thúc từ mốc settings 'payouts_from' (thời điểm file 28
--               chạy lần đầu) mới được lập: lịch cũ của database nâng cấp và dữ liệu mẫu không
--               sinh khoản chi trả (thiếu dòng hoặc sai dạng = không có mốc). Tự hoàn thành đơn
--               vẫn áp dụng cho mọi lịch đã kết thúc. Chỉ lập khi lịch không còn gì dang dở:
--                 - không còn đơn 'awaiting_payment' / 'confirmed';
--                 - không còn khoản thanh toán 'awaiting_reconciliation' / 'processing';
--                 - không còn khoản hoàn tiền 'requested' / 'approved' (tiền sắp trả lại khách);
--                 - không còn yêu cầu đổi ngày / hủy tour 'pending' của đơn còn hiệu lực
--                   ('pending', 'awaiting_payment', 'confirmed'); yêu cầu sót lại của đơn đã
--                   đóng không chặn khoản chi trả.
--               Từng đơn 'completed' hoặc 'cancelled' của lịch:
--                 tiền thực thu = tổng khoản thanh toán 'paid' - tổng khoản hoàn 'completed';
--                 đơn có tiền thực thu > 0 được đưa vào khoản chi trả (đơn hủy còn giữ phí hủy
--                 tính như đơn thường);
--                 phí dịch vụ = ROUND(tiền thực thu x % / 100), thực nhận = tiền thực thu - phí.
--               Tổng của khoản chi trả = tổng các dòng. Không đơn nào có tiền thực thu > 0 thì
--               không lập khoản chi trả.
--             * Khoản hoàn tiền được tạo ở trạng thái 'requested' (file 07, 15, 20, 22) và LocalTour
--               chuyển khoản lại cho khách ngoài hệ thống. Quản trị viên ghi "Đã hoàn tiền"
--               (NTK_sp_admin_refund_complete) thì khoản hoàn mới 'completed' và lịch mới được lập
--               khoản chi trả: tiền sắp hoàn cho khách không bao giờ bị chi trả cho đơn vị.
--             * Ghi nhận đã chi trả: quản trị viên đang hoạt động, khoản đang 'pending', có mã giao
--               dịch chuyển khoản, đơn vị đã khai đủ tài khoản nhận tiền và số tài khoản vẫn đúng
--               số quản trị viên thấy trên trang lúc chuyển khoản (chụp vào khoản chi trả lúc đó).
--               Ghi admin_logs 'payout_paid' (số tài khoản chỉ hiện 4 số cuối).
--             * Đơn vị tổ chức chỉ thấy khoản chi trả của chính mình (kiểm tra trong SQL như file
--               27), và chỉ khi đơn vị đang hợp tác, tài khoản đang hoạt động.
--             * NTK_sp_payout_sweep gọi được nhiều lần và cùng lúc từ nhiều phiên: khóa dòng rồi
--               kiểm tra lại, mỗi đơn / mỗi lịch một transaction. Không có DEFINER.
-- Chạy sau  : 01 -> 28. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- NTK_sp_setting_commission_rate(OUT p_rate)   (dùng nội bộ)
--   % phí dịch vụ hiện tại (settings 'commission_percent'); thiếu hoặc sai dạng -> 10.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setting_commission_rate;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setting_commission_rate(
    OUT p_rate DECIMAL(5,2)
)
READS SQL DATA
BEGIN
    DECLARE v_value VARCHAR(100) DEFAULT NULL;

    SELECT MAX(s.value) INTO v_value
      FROM settings s
     WHERE s.name = 'commission_percent';

    -- Cùng một quy tắc đọc với LTP_sp_booking_create (file 10) và NTK_sp_admin_setting_save.
    IF v_value IS NOT NULL AND v_value REGEXP '^[0-9]{1,3}([.][0-9]{1,2})?$'
       AND CAST(v_value AS DECIMAL(7,2)) <= 100 THEN
        SET p_rate = CAST(v_value AS DECIMAL(5,2));
    ELSE
        SET p_rate = 10;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_setting_payouts_from(OUT p_from)   (dùng nội bộ)
--   Mốc bắt đầu lập khoản chi trả (settings 'payouts_from', 'YYYY-MM-DD HH:MM:SS', file 28).
--   Thiếu dòng hoặc sai dạng -> NULL = không có mốc (mọi lịch đã kết thúc đều được xét).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setting_payouts_from;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setting_payouts_from(
    OUT p_from DATETIME
)
READS SQL DATA
BEGIN
    DECLARE v_value VARCHAR(100) DEFAULT NULL;

    SELECT MAX(s.value) INTO v_value
      FROM settings s
     WHERE s.name = 'payouts_from';

    -- Đúng dạng và là ngày giờ có thật (tháng 1-12, ngày theo lịch, giờ 0-23) mới dùng.
    IF v_value IS NOT NULL
       AND v_value REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01]) ([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$'
       AND CAST(SUBSTRING(v_value, 9, 2) AS UNSIGNED) <= DAY(LAST_DAY(CONCAT(LEFT(v_value, 7), '-01'))) THEN
        SET p_from = CAST(v_value AS DATETIME);
    ELSE
        SET p_from = NULL;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_setting_put(p_actor_user_id, p_name, p_value, INOUT p_changed)   (dùng nội bộ)
--   Gọi bên trong transaction của NTK_sp_admin_setting_save (không tự START TRANSACTION /
--   COMMIT, không trả dòng nào). Giá trị khác giá trị đang lưu thì ghi lại, ghi người sửa và
--   admin_logs 'setting_update' (target_type 'setting', target_id = tên thông số,
--   from / to = giá trị cũ / mới), p_changed tăng 1.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setting_put;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setting_put(
    IN    p_actor_user_id CHAR(36),
    IN    p_name          VARCHAR(50),
    IN    p_value         VARCHAR(30),
    INOUT p_changed       INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_old VARCHAR(100) DEFAULT NULL;

    SELECT MAX(s.value) INTO v_old
      FROM settings s
     WHERE s.name = (p_name COLLATE utf8mb4_unicode_ci);

    IF v_old IS NULL OR v_old <> (p_value COLLATE utf8mb4_unicode_ci) THEN
        INSERT INTO settings (name, value, updated_at, updated_by)
        VALUES (p_name, p_value, NOW(), p_actor_user_id)
        ON DUPLICATE KEY UPDATE value = VALUES(value), updated_at = VALUES(updated_at), updated_by = VALUES(updated_by);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'setting', p_name, 'setting_update', LEFT(v_old, 30), p_value,
                CONCAT('Đổi thông số ', p_name, ': ', COALESCE(v_old, '(chưa có)'), ' → ', p_value), NOW());

        SET p_changed = p_changed + 1;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_setting_list()
--   Thông số vận hành cho trang "Thông số vận hành" và ghi chú % phí dịch vụ ở khu /host.
--   Gồm cả 'payouts_from' (mốc bắt đầu lập khoản chi trả): chỉ để hiện, không có trong form lưu.
--   Cột: name, value, updated_at, updated_by_name (NULL = chưa ai sửa).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_setting_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_setting_list()
READS SQL DATA
BEGIN
    SELECT s.name, s.value, s.updated_at, u.name AS updated_by_name
      FROM settings s
      LEFT JOIN users u ON u.id = s.updated_by
     ORDER BY s.name;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_setting_save(p_actor_user_id, p_commission_percent, p_hold_minutes,
--                           p_booking_cutoff_minutes, p_vietqr_cutoff_hours)
--   Quản trị viên lưu 4 thông số vận hành.
--     p_commission_percent     : chuỗi số 0 - 100, tối đa 2 chữ số thập phân, dấu chấm (vd. '10',
--                                '12.5'). Lưu dạng gọn ('12.50' -> '12.5').
--     p_hold_minutes           : 5 - 1440.
--     p_booking_cutoff_minutes : 0 - 1440.
--     p_vietqr_cutoff_hours    : 0 - 168.
--   Thông số nào đổi thì ghi người sửa, giờ sửa và một dòng admin_logs 'setting_update'.
--   1 dòng: result, field.
--     result = 'ok' | 'unchanged' (không thông số nào đổi)
--              'forbidden' (không phải quản trị viên đang hoạt động)
--              'invalid'   (field = commission_percent, hold_minutes, booking_cutoff_minutes
--                           hoặc vietqr_cutoff_hours; không lưu gì)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_setting_save;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_setting_save(
    IN p_actor_user_id          CHAR(36),
    IN p_commission_percent     VARCHAR(20),
    IN p_hold_minutes           INT,
    IN p_booking_cutoff_minutes INT,
    IN p_vietqr_cutoff_hours    INT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_commission VARCHAR(20) DEFAULT TRIM(COALESCE(p_commission_percent, ''));
    DECLARE v_field      VARCHAR(30) DEFAULT NULL;
    DECLARE v_changed    INT         DEFAULT 0;
    DECLARE v_locked     INT         DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field;
        LEAVE proc;
    END IF;

    IF NOT (v_commission REGEXP '^[0-9]{1,3}([.][0-9]{1,2})?$') OR CAST(v_commission AS DECIMAL(7,2)) > 100 THEN
        SET v_field = 'commission_percent';
    ELSEIF p_hold_minutes IS NULL OR p_hold_minutes NOT BETWEEN 5 AND 1440 THEN
        SET v_field = 'hold_minutes';
    ELSEIF p_booking_cutoff_minutes IS NULL OR p_booking_cutoff_minutes NOT BETWEEN 0 AND 1440 THEN
        SET v_field = 'booking_cutoff_minutes';
    ELSEIF p_vietqr_cutoff_hours IS NULL OR p_vietqr_cutoff_hours NOT BETWEEN 0 AND 168 THEN
        SET v_field = 'vietqr_cutoff_hours';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field;
        LEAVE proc;
    END IF;

    -- Dạng gọn: '12.50' -> '12.5', '10.00' -> '10', '007' -> '7'.
    SET v_commission = TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM CAST(CAST(v_commission AS DECIMAL(5,2)) AS CHAR)));

    START TRANSACTION;

    -- Khóa các dòng thông số: hai quản trị viên lưu cùng lúc thì lần lượt.
    SELECT COUNT(*) INTO v_locked
      FROM (SELECT s.name FROM settings s FOR UPDATE) x;

    CALL NTK_sp_setting_put(p_actor_user_id, 'commission_percent', v_commission, v_changed);
    CALL NTK_sp_setting_put(p_actor_user_id, 'hold_minutes', CAST(p_hold_minutes AS CHAR), v_changed);
    CALL NTK_sp_setting_put(p_actor_user_id, 'booking_cutoff_minutes', CAST(p_booking_cutoff_minutes AS CHAR), v_changed);
    CALL NTK_sp_setting_put(p_actor_user_id, 'vietqr_cutoff_hours', CAST(p_vietqr_cutoff_hours AS CHAR), v_changed);

    COMMIT;
    SELECT IF(v_changed > 0, 'ok', 'unchanged') AS result, NULL AS field;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_payout_schedule_ready(p_schedule_id, OUT p_ready)   (dùng nội bộ)
--   p_ready = TRUE khi lịch đã kết thúc từ mốc 'payouts_from', chưa có khoản chi trả, không còn gì dang dở (xem
--   "Quy tắc" đầu file) và có ít nhất một đơn 'completed' / 'cancelled' còn tiền thực thu > 0.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_payout_schedule_ready;

DELIMITER $$
CREATE PROCEDURE NTK_sp_payout_schedule_ready(
    IN  p_schedule_id CHAR(36),
    OUT p_ready       BOOLEAN
)
READS SQL DATA
BEGIN
    DECLARE v_from DATETIME DEFAULT NULL;

    CALL NTK_sp_setting_payouts_from(v_from);

    SET p_ready = EXISTS (
        SELECT 1
          FROM schedules s
         WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
           AND s.ends_at <= NOW()
           AND (v_from IS NULL OR s.ends_at >= v_from)
           AND NOT EXISTS (SELECT 1 FROM host_payouts hp WHERE hp.schedule_id = s.id)
           AND NOT EXISTS (SELECT 1 FROM bookings b
                            WHERE b.schedule_id = s.id
                              AND b.status IN ('awaiting_payment', 'confirmed'))
           AND NOT EXISTS (SELECT 1 FROM bookings b
                             JOIN payments p ON p.booking_id = b.id
                            WHERE b.schedule_id = s.id
                              AND p.status IN ('awaiting_reconciliation', 'processing'))
           AND NOT EXISTS (SELECT 1 FROM bookings b
                             JOIN payments p ON p.booking_id = b.id
                             JOIN refunds r  ON r.payment_id = p.id
                            WHERE b.schedule_id = s.id
                              AND r.status IN ('requested', 'approved'))
           AND NOT EXISTS (SELECT 1 FROM bookings b
                             JOIN booking_change_requests cr ON cr.booking_id = b.id
                            WHERE b.schedule_id = s.id
                              AND b.status IN ('pending', 'awaiting_payment', 'confirmed')
                              AND cr.status = 'pending')
           AND EXISTS (SELECT 1 FROM bookings b
                        WHERE b.schedule_id = s.id
                          AND b.status IN ('completed', 'cancelled')
                          AND (SELECT COALESCE(SUM(p.amount_vnd), 0)
                                 FROM payments p
                                WHERE p.booking_id = b.id AND p.status = 'paid')
                            - (SELECT COALESCE(SUM(r.amount_vnd), 0)
                                 FROM refunds r
                                 JOIN payments p ON p.id = r.payment_id
                                WHERE p.booking_id = b.id AND r.status = 'completed') > 0));
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_payout_sweep()
--   Việc định kỳ sau tour, gọi cùng chỗ với LTP_sp_booking_expire_holds (mỗi khi mở trang đơn /
--   trang quản trị và từ scripts/expire_holds.php):
--     1. Đơn 'confirmed' của lịch đã kết thúc, không có yêu cầu đổi ngày / hủy tour chờ xử lý
--        -> 'completed', ghi booking_events (system, 'booking_status'). Mỗi đơn một transaction.
--     2. Lịch 'open' / 'full' đã kết thúc -> 'completed'.
--     3. Lịch kết thúc từ mốc 'payouts_from', chưa có khoản chi trả và không còn gì dang dở ->
--        lập khoản chi trả 'pending' cùng các dòng đơn. Mỗi lịch một transaction, khóa dòng lịch rồi kiểm tra lại.
--   Chạy nhiều lần cùng lúc vẫn an toàn: lần chạy sau thấy đơn đã 'completed' / lịch đã có
--   khoản chi trả thì bỏ qua (thêm UNIQUE schedule_id của host_payouts làm lớp chặn cuối).
--   1 dòng: completed (số đơn vừa tự hoàn thành), schedules_completed, payouts (số khoản chi
--   trả vừa lập).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_payout_sweep;

DELIMITER $$
CREATE PROCEDURE NTK_sp_payout_sweep()
MODIFIES SQL DATA
BEGIN
    DECLARE v_completed INT DEFAULT 0;
    DECLARE v_schedules INT DEFAULT 0;
    DECLARE v_payouts   INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 1. Đơn tự hoàn thành.
    complete_block: BEGIN
        DECLARE v_booking_id CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
        DECLARE v_status     VARCHAR(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
        DECLARE v_schedule   CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
        DECLARE v_ok         INT         DEFAULT 0;
        DECLARE v_done       BOOLEAN     DEFAULT FALSE;
        DECLARE cur_bookings CURSOR FOR
            SELECT b.id
              FROM bookings b
              JOIN schedules s ON s.id = b.schedule_id
             WHERE b.status = 'confirmed'
               AND s.ends_at <= NOW()
               AND NOT EXISTS (SELECT 1 FROM booking_change_requests cr
                                WHERE cr.booking_id = b.id AND cr.status = 'pending')
             ORDER BY s.ends_at, b.id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

        OPEN cur_bookings;
        booking_loop: LOOP
            FETCH cur_bookings INTO v_booking_id;
            IF v_done THEN
                LEAVE booking_loop;
            END IF;

            START TRANSACTION;

            -- Khóa đúng dòng đơn rồi kiểm tra lại (phiên khác có thể vừa hoàn thành / hủy đơn).
            SELECT MAX(b.status), MAX(b.schedule_id) INTO v_status, v_schedule
              FROM (SELECT b0.status, b0.schedule_id FROM bookings b0 WHERE b0.id = v_booking_id FOR UPDATE) b;

            SELECT COUNT(*) INTO v_ok
              FROM schedules s
             WHERE s.id = v_schedule
               AND s.ends_at <= NOW()
               AND NOT EXISTS (SELECT 1 FROM booking_change_requests cr
                                WHERE cr.booking_id = v_booking_id AND cr.status = 'pending');

            IF v_status = 'confirmed' AND v_ok = 1 THEN
                UPDATE bookings SET status = 'completed', hold_expires_at = NULL WHERE id = v_booking_id;

                INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
                VALUES (UUID(), v_booking_id, 'system', NULL, 'booking_status', 'confirmed', 'completed',
                        'Tour đã kết thúc: hệ thống tự chuyển đơn sang "Đã hoàn thành".', NOW());

                COMMIT;
                SET v_completed = v_completed + 1;
            ELSE
                ROLLBACK;
            END IF;

            SET v_done = FALSE;
        END LOOP;
        CLOSE cur_bookings;
    END complete_block;

    -- 2. Lịch đã kết thúc -> 'completed' (từng lịch theo khóa chính, không khóa cả bảng).
    schedule_block: BEGIN
        DECLARE v_schedule_id CHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
        DECLARE v_done        BOOLEAN  DEFAULT FALSE;
        DECLARE cur_schedules CURSOR FOR
            SELECT s.id
              FROM schedules s
             WHERE s.status IN ('open', 'full')
               AND s.ends_at <= NOW()
             ORDER BY s.ends_at, s.id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

        OPEN cur_schedules;
        schedule_loop: LOOP
            FETCH cur_schedules INTO v_schedule_id;
            IF v_done THEN
                LEAVE schedule_loop;
            END IF;

            UPDATE schedules
               SET status = 'completed'
             WHERE id = v_schedule_id
               AND status IN ('open', 'full')
               AND ends_at <= NOW();
            SET v_schedules = v_schedules + ROW_COUNT();

            SET v_done = FALSE;
        END LOOP;
        CLOSE cur_schedules;
    END schedule_block;

    -- 3. Khoản chi trả cho từng lịch đã kết thúc, không còn gì dang dở.
    payout_block: BEGIN
        DECLARE v_schedule_id CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
        DECLARE v_provider_id CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
        DECLARE v_payout_id   CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
        DECLARE v_rate        DECIMAL(5,2) DEFAULT 10;
        DECLARE v_ready       BOOLEAN      DEFAULT FALSE;
        DECLARE v_locked      INT          DEFAULT 0;
        DECLARE v_items       INT          DEFAULT 0;
        DECLARE v_from        DATETIME     DEFAULT NULL;
        DECLARE v_done        BOOLEAN      DEFAULT FALSE;
        -- Lịch đã kết thúc từ mốc 'payouts_from', chưa có khoản chi trả, có ít nhất một khoản
        -- thanh toán thành công (v_from được gán trước khi OPEN).
        DECLARE cur_ended CURSOR FOR
            SELECT s.id
              FROM schedules s
             WHERE s.ends_at <= NOW()
               AND (v_from IS NULL OR s.ends_at >= v_from)
               AND NOT EXISTS (SELECT 1 FROM host_payouts hp WHERE hp.schedule_id = s.id)
               AND EXISTS (SELECT 1 FROM bookings b
                             JOIN payments p ON p.booking_id = b.id
                            WHERE b.schedule_id = s.id AND p.status = 'paid')
             ORDER BY s.ends_at, s.id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

        CALL NTK_sp_setting_payouts_from(v_from);

        OPEN cur_ended;
        ended_loop: LOOP
            FETCH cur_ended INTO v_schedule_id;
            IF v_done THEN
                LEAVE ended_loop;
            END IF;

            -- Kiểm tra trước, chưa khóa gì: lịch còn dang dở thì bỏ qua ngay.
            CALL NTK_sp_payout_schedule_ready(v_schedule_id, v_ready);

            IF v_ready THEN
                START TRANSACTION;

                -- Khóa dòng lịch: hai phiên cùng quét thì lần lượt, phiên sau thấy khoản đã lập.
                SELECT COUNT(*) INTO v_locked
                  FROM (SELECT s0.id FROM schedules s0 WHERE s0.id = v_schedule_id FOR UPDATE) x;

                CALL NTK_sp_payout_schedule_ready(v_schedule_id, v_ready);

                IF v_ready THEN
                    SELECT MAX(t.provider_id) INTO v_provider_id
                      FROM schedules s
                      JOIN tours t ON t.id = s.tour_id
                     WHERE s.id = v_schedule_id;

                    -- Đơn chưa chụp % phí (tạo trước file 28) tính theo thông số hiện tại.
                    CALL NTK_sp_setting_commission_rate(v_rate);

                    SET v_payout_id = UUID();
                    INSERT INTO host_payouts (id, provider_id, schedule_id, booking_count, gross_vnd, commission_vnd, net_vnd, status, created_at)
                    VALUES (v_payout_id, v_provider_id, v_schedule_id, 0, 0, 0, 0, 'pending', NOW());

                    item_block: BEGIN
                        DECLARE v_booking_id CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
                        DECLARE v_kept       BIGINT       DEFAULT 0;
                        DECLARE v_item_rate  DECIMAL(5,2) DEFAULT 0;
                        DECLARE v_commission BIGINT       DEFAULT 0;
                        DECLARE v_item_done  BOOLEAN      DEFAULT FALSE;
                        -- Đọc không khóa (không giữ khóa trên payments / refunds trong lúc ghi).
                        DECLARE cur_items CURSOR FOR
                            SELECT x.booking_id, x.kept_vnd, x.rate
                              FROM (SELECT b.id   AS booking_id,
                                           b.code AS code,
                                           (SELECT COALESCE(SUM(p.amount_vnd), 0)
                                              FROM payments p
                                             WHERE p.booking_id = b.id AND p.status = 'paid')
                                         - (SELECT COALESCE(SUM(r.amount_vnd), 0)
                                              FROM refunds r
                                              JOIN payments p ON p.id = r.payment_id
                                             WHERE p.booking_id = b.id AND r.status = 'completed') AS kept_vnd,
                                           LEAST(100, GREATEST(0, COALESCE(b.commission_rate, v_rate))) AS rate
                                      FROM bookings b
                                     WHERE b.schedule_id = v_schedule_id
                                       AND b.status IN ('completed', 'cancelled')) x
                             WHERE x.kept_vnd > 0
                             ORDER BY x.code;
                        DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_item_done = TRUE;

                        OPEN cur_items;
                        item_loop: LOOP
                            FETCH cur_items INTO v_booking_id, v_kept, v_item_rate;
                            IF v_item_done THEN
                                LEAVE item_loop;
                            END IF;

                            SET v_commission = ROUND(v_kept * v_item_rate / 100);

                            INSERT INTO host_payout_items (id, payout_id, booking_id, kept_vnd, commission_rate, commission_vnd, net_vnd)
                            VALUES (UUID(), v_payout_id, v_booking_id, v_kept, v_item_rate, v_commission, v_kept - v_commission);
                        END LOOP;
                        CLOSE cur_items;
                    END item_block;

                    SELECT COUNT(*) INTO v_items
                      FROM host_payout_items i
                     WHERE i.payout_id = v_payout_id;

                    IF v_items > 0 THEN
                        UPDATE host_payouts hp
                           SET hp.booking_count  = v_items,
                               hp.gross_vnd      = (SELECT SUM(i.kept_vnd) FROM host_payout_items i WHERE i.payout_id = v_payout_id),
                               hp.commission_vnd = (SELECT SUM(i.commission_vnd) FROM host_payout_items i WHERE i.payout_id = v_payout_id),
                               hp.net_vnd        = (SELECT SUM(i.net_vnd) FROM host_payout_items i WHERE i.payout_id = v_payout_id)
                         WHERE hp.id = v_payout_id;

                        COMMIT;
                        SET v_payouts = v_payouts + 1;
                    ELSE
                        ROLLBACK;
                    END IF;
                ELSE
                    ROLLBACK;
                END IF;
            END IF;

            SET v_done = FALSE;
        END LOOP;
        CLOSE cur_ended;
    END payout_block;

    SELECT v_completed AS completed, v_schedules AS schedules_completed, v_payouts AS payouts;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_payout_list(p_status)
--   Khoản chi trả cho trang quản trị. p_status NULL / '' = tất cả, 'pending' hoặc 'paid'.
--   "Chờ chi trả" trước (lập trước lên trước), rồi "Đã chi trả" (mới chuyển lên trước).
--   Cột: payout_id, status, created_at, paid_at, transfer_reference, booking_count, gross_vnd,
--        commission_vnd, net_vnd, schedule_id, starts_at, ends_at, tour_id, tour_title,
--        provider_id, business_name, has_bank (1 = đơn vị đã khai đủ tài khoản nhận tiền).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_payout_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_payout_list(
    IN p_status VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        hp.id             AS payout_id,
        hp.status,
        hp.created_at,
        hp.paid_at,
        hp.transfer_reference,
        hp.booking_count,
        hp.gross_vnd,
        hp.commission_vnd,
        hp.net_vnd,
        s.id              AS schedule_id,
        s.starts_at,
        s.ends_at,
        t.id              AS tour_id,
        t.title           AS tour_title,
        pr.id             AS provider_id,
        pr.business_name,
        (COALESCE(pr.bank_name, '') <> ''
         AND COALESCE(pr.bank_account_no, '') <> ''
         AND COALESCE(pr.bank_account_name, '') <> '') AS has_bank
    FROM host_payouts hp
    JOIN schedules s  ON s.id = hp.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = hp.provider_id
    WHERE NULLIF(p_status, '') IS NULL OR hp.status = (p_status COLLATE utf8mb4_unicode_ci)
    ORDER BY FIELD(hp.status, 'pending', 'paid'),
             IF(hp.status = 'pending', hp.created_at, NULL) ASC,
             hp.paid_at DESC, hp.id
    LIMIT 500;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_payout_summary()
--   Tổng của mọi khoản chi trả. 1 dòng: payout_count, pending_count, paid_count,
--   gross_vnd (tiền thực thu), commission_vnd (phí dịch vụ LocalTour thu được),
--   net_pending_vnd (thực nhận còn chờ chi trả), net_paid_vnd (thực nhận đã chi trả).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_payout_summary;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_payout_summary()
READS SQL DATA
BEGIN
    SELECT
        COUNT(*)                                                      AS payout_count,
        COALESCE(SUM(hp.status = 'pending'), 0)                       AS pending_count,
        COALESCE(SUM(hp.status = 'paid'), 0)                          AS paid_count,
        COALESCE(SUM(hp.gross_vnd), 0)                                AS gross_vnd,
        COALESCE(SUM(hp.commission_vnd), 0)                           AS commission_vnd,
        COALESCE(SUM(IF(hp.status = 'pending', hp.net_vnd, 0)), 0)    AS net_pending_vnd,
        COALESCE(SUM(IF(hp.status = 'paid', hp.net_vnd, 0)), 0)       AS net_paid_vnd
    FROM host_payouts hp;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_payout_detail(p_payout_id)
--   Một khoản chi trả. 0 hoặc 1 dòng: payout_id, status, created_at, paid_at, paid_by_name,
--   transfer_reference, note, booking_count, gross_vnd, commission_vnd, net_vnd,
--   bank_name, bank_account_no, bank_account_name (tài khoản đã chụp lúc ghi nhận đã chi trả; NULL khi
--   còn chờ), schedule_id, starts_at, ends_at, schedule_status, tour_id, tour_title,
--   provider_id, business_name, contact_phone, provider_email, provider_status,
--   provider_bank_name, provider_bank_account_no, provider_bank_account_name (tài khoản đơn vị
--   đang khai).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_payout_detail;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_payout_detail(
    IN p_payout_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        hp.id              AS payout_id,
        hp.status,
        hp.created_at,
        hp.paid_at,
        a.name             AS paid_by_name,
        hp.transfer_reference,
        hp.note,
        hp.booking_count,
        hp.gross_vnd,
        hp.commission_vnd,
        hp.net_vnd,
        hp.bank_name,
        hp.bank_account_no,
        hp.bank_account_name,
        s.id               AS schedule_id,
        s.starts_at,
        s.ends_at,
        s.status           AS schedule_status,
        t.id               AS tour_id,
        t.title            AS tour_title,
        pr.id              AS provider_id,
        pr.business_name,
        pr.contact_phone,
        u.email            AS provider_email,
        pr.approval_status AS provider_status,
        pr.bank_name         AS provider_bank_name,
        pr.bank_account_no   AS provider_bank_account_no,
        pr.bank_account_name AS provider_bank_account_name
    FROM host_payouts hp
    JOIN schedules s  ON s.id = hp.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = hp.provider_id
    JOIN users u      ON u.id = pr.user_id
    LEFT JOIN users a ON a.id = hp.paid_by
    WHERE hp.id = (p_payout_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_payout_item_list(p_payout_id)
--   Các đơn trong một khoản chi trả, theo mã đơn.
--   Cột: booking_id, code, booking_status, contact_name, people, total_vnd, kept_vnd,
--        commission_rate, commission_vnd, net_vnd.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_payout_item_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_payout_item_list(
    IN p_payout_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id      AS booking_id,
        b.code,
        b.status  AS booking_status,
        b.contact_name,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        b.total_vnd,
        i.kept_vnd,
        i.commission_rate,
        i.commission_vnd,
        i.net_vnd
    FROM host_payout_items i
    JOIN bookings b ON b.id = i.booking_id
    WHERE i.payout_id = (p_payout_id COLLATE utf8mb4_unicode_ci)
    ORDER BY b.code, i.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_payout_pay(p_actor_user_id, p_payout_id, p_transfer_reference, p_note,
--                         p_seen_account_no)
--   Quản trị viên ghi nhận đã chi trả sau khi chuyển khoản cho đơn vị ngoài hệ thống. Khoản chi
--   trả -> 'paid', lưu mã giao dịch, ghi chú, người ghi, giờ ghi và chụp tài khoản nhận tiền đơn
--   vị đang khai. p_seen_account_no = số tài khoản quản trị viên thấy trên trang lúc chuyển khoản
--   (ô ẩn của form): đơn vị vừa đổi số tài khoản thì không ghi. Ghi admin_logs 'payout_paid'
--   (target_type 'payout'; số tài khoản chỉ hiện 4 số cuối như 'provider_bank').
--   1 dòng: result.
--     result = 'ok'
--              'forbidden'          : không phải quản trị viên đang hoạt động.
--              'reference_required' : chưa nhập mã giao dịch chuyển khoản.
--              'invalid'            : mã giao dịch dài quá 100 hoặc ghi chú dài quá 255 ký tự.
--              'not_found'          : không có khoản chi trả này.
--              'already_paid'       : khoản đã được ghi "Đã chi trả" trước đó.
--              'bank_missing'       : đơn vị chưa khai đủ tài khoản nhận tiền.
--              'bank_changed'       : số tài khoản đơn vị đang khai khác số quản trị viên đã thấy.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_payout_pay;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_payout_pay(
    IN p_actor_user_id      CHAR(36),
    IN p_payout_id          CHAR(36),
    IN p_transfer_reference VARCHAR(255) CHARACTER SET utf8mb4,
    IN p_note               VARCHAR(500) CHARACTER SET utf8mb4,
    IN p_seen_account_no    VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status      VARCHAR(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_provider_id CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_net         BIGINT       DEFAULT 0;
    DECLARE v_bank_name   VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_bank_no     VARCHAR(30)  CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_bank_holder VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_reference   VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_transfer_reference), '');
    DECLARE v_note        VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    IF v_reference IS NULL THEN
        SELECT 'reference_required' AS result;
        LEAVE proc;
    END IF;

    IF CHAR_LENGTH(v_reference) > 100 OR CHAR_LENGTH(COALESCE(v_note, '')) > 255 THEN
        SELECT 'invalid' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT MAX(x.status), MAX(x.provider_id), MAX(x.net_vnd) INTO v_status, v_provider_id, v_net
      FROM (SELECT hp.status, hp.provider_id, hp.net_vnd
              FROM host_payouts hp
             WHERE hp.id = (p_payout_id COLLATE utf8mb4_unicode_ci)
               FOR UPDATE) x;

    IF v_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    IF v_status <> 'pending' THEN
        ROLLBACK;
        SELECT 'already_paid' AS result;
        LEAVE proc;
    END IF;

    SELECT MAX(NULLIF(TRIM(pr.bank_name), '')), MAX(NULLIF(TRIM(pr.bank_account_no), '')), MAX(NULLIF(TRIM(pr.bank_account_name), ''))
      INTO v_bank_name, v_bank_no, v_bank_holder
      FROM providers pr
     WHERE pr.id = v_provider_id;

    IF v_bank_name IS NULL OR v_bank_no IS NULL OR v_bank_holder IS NULL THEN
        ROLLBACK;
        SELECT 'bank_missing' AS result;
        LEAVE proc;
    END IF;

    -- Đơn vị đổi số tài khoản sau khi quản trị viên mở trang: tiền có thể đã chuyển tới số cũ.
    IF v_bank_no <> TRIM(COALESCE(p_seen_account_no, '')) THEN
        ROLLBACK;
        SELECT 'bank_changed' AS result;
        LEAVE proc;
    END IF;

    UPDATE host_payouts
       SET status = 'paid',
           bank_name = v_bank_name,
           bank_account_no = v_bank_no,
           bank_account_name = v_bank_holder,
           transfer_reference = v_reference,
           note = v_note,
           paid_at = NOW(),
           paid_by = p_actor_user_id
     WHERE id = (p_payout_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'payout', p_payout_id, 'payout_paid', 'pending', 'paid',
            LEFT(CONCAT('Đã chuyển ', REPLACE(FORMAT(v_net, 0), ',', '.'), ' VND tới ', v_bank_name, ', số tài khoản ****', RIGHT(v_bank_no, 4),
                        ', mã giao dịch ', v_reference, IF(v_note IS NULL, '', CONCAT(': ', v_note))), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_payout_waiting_list()
--   Lịch đã kết thúc từ mốc 'payouts_from', có tiền khách đã trả, chưa lập được khoản chi trả vì
--   còn việc dang dở.
--   Cột: schedule_id, starts_at, ends_at, tour_id, tour_title, business_name,
--        open_bookings (đơn còn 'awaiting_payment' / 'confirmed'),
--        payments_in_review (khoản 'awaiting_reconciliation' / 'processing'),
--        refunds_open (khoản hoàn 'requested' / 'approved'),
--        changes_pending (yêu cầu đổi ngày / hủy tour 'pending' của đơn còn hiệu lực),
--        paid_vnd (tổng khoản 'paid' của lịch).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_payout_waiting_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_payout_waiting_list()
READS SQL DATA
BEGIN
    DECLARE v_from DATETIME DEFAULT NULL;

    CALL NTK_sp_setting_payouts_from(v_from);

    SELECT w.*
      FROM (
        SELECT
            s.id        AS schedule_id,
            s.starts_at,
            s.ends_at,
            t.id        AS tour_id,
            t.title     AS tour_title,
            pr.business_name,
            (SELECT COUNT(*) FROM bookings b
              WHERE b.schedule_id = s.id
                AND b.status IN ('awaiting_payment', 'confirmed')) AS open_bookings,
            (SELECT COUNT(*) FROM bookings b
               JOIN payments p ON p.booking_id = b.id
              WHERE b.schedule_id = s.id
                AND p.status IN ('awaiting_reconciliation', 'processing')) AS payments_in_review,
            (SELECT COUNT(*) FROM bookings b
               JOIN payments p ON p.booking_id = b.id
               JOIN refunds r  ON r.payment_id = p.id
              WHERE b.schedule_id = s.id
                AND r.status IN ('requested', 'approved')) AS refunds_open,
            (SELECT COUNT(*) FROM bookings b
               JOIN booking_change_requests cr ON cr.booking_id = b.id
              WHERE b.schedule_id = s.id
                AND b.status IN ('pending', 'awaiting_payment', 'confirmed')
                AND cr.status = 'pending') AS changes_pending,
            (SELECT COALESCE(SUM(p.amount_vnd), 0) FROM bookings b
               JOIN payments p ON p.booking_id = b.id
              WHERE b.schedule_id = s.id
                AND p.status = 'paid') AS paid_vnd
        FROM schedules s
        JOIN tours t      ON t.id = s.tour_id
        JOIN providers pr ON pr.id = t.provider_id
        WHERE s.ends_at <= NOW()
          AND (v_from IS NULL OR s.ends_at >= v_from)
          AND NOT EXISTS (SELECT 1 FROM host_payouts hp WHERE hp.schedule_id = s.id)
          AND EXISTS (SELECT 1 FROM bookings b
                        JOIN payments p ON p.booking_id = b.id
                       WHERE b.schedule_id = s.id
                         AND p.status IN ('paid', 'awaiting_reconciliation', 'processing'))
      ) w
     WHERE w.open_bookings + w.payments_in_review + w.refunds_open + w.changes_pending > 0
     ORDER BY w.ends_at, w.schedule_id
     LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_refund_open_list()
--   Khoản hoàn tiền LocalTour còn phải chuyển lại cho khách ('requested' / 'approved'), cũ trước.
--   Cột: refund_id, amount_vnd, reason, status, requested_at, payment_method, payment_reference,
--        booking_id, code, booking_status, contact_name, contact_phone, tour_title, starts_at,
--        ends_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_refund_open_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_refund_open_list()
READS SQL DATA
BEGIN
    SELECT
        r.id         AS refund_id,
        r.amount_vnd,
        r.reason,
        r.status,
        r.requested_at,
        p.method     AS payment_method,
        p.reference  AS payment_reference,
        b.id         AS booking_id,
        b.code,
        b.status     AS booking_status,
        b.contact_name,
        b.contact_phone,
        t.title      AS tour_title,
        s.starts_at,
        s.ends_at
    FROM refunds r
    JOIN payments p  ON p.id = r.payment_id
    JOIN bookings b  ON b.id = p.booking_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE r.status IN ('requested', 'approved')
    ORDER BY r.requested_at, r.id
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_refund_complete(p_actor_user_id, p_refund_id, p_transfer_reference)
--   Quản trị viên ghi "Đã hoàn tiền" sau khi chuyển khoản lại cho khách ngoài hệ thống. Khoản
--   hoàn 'requested' / 'approved' -> 'completed' (từ lúc này được trừ vào doanh thu và vào tiền
--   thực thu của đơn). Ghi admin_logs của đơn, action 'refund_completed'.
--   1 dòng: result, booking_id.
--     result = 'ok' | 'forbidden' | 'not_found'
--              'reference_required' (chưa nhập mã giao dịch hoàn tiền)
--              'invalid'            (mã giao dịch dài quá 100 ký tự)
--              'not_open'           (khoản hoàn đã 'completed' hoặc 'rejected')
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_refund_complete;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_refund_complete(
    IN p_actor_user_id      CHAR(36),
    IN p_refund_id          CHAR(36),
    IN p_transfer_reference VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status     VARCHAR(20)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_payment_id CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_booking_id CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_amount     BIGINT       DEFAULT 0;
    DECLARE v_reference  VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_transfer_reference), '');
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

    IF v_reference IS NULL THEN
        SELECT 'reference_required' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    IF CHAR_LENGTH(v_reference) > 100 THEN
        SELECT 'invalid' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT MAX(x.status), MAX(x.payment_id), MAX(x.amount_vnd) INTO v_status, v_payment_id, v_amount
      FROM (SELECT r.status, r.payment_id, r.amount_vnd
              FROM refunds r
             WHERE r.id = (p_refund_id COLLATE utf8mb4_unicode_ci)
               FOR UPDATE) x;

    IF v_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    SELECT MAX(p.booking_id) INTO v_booking_id
      FROM payments p
     WHERE p.id = v_payment_id;

    IF v_status NOT IN ('requested', 'approved') THEN
        ROLLBACK;
        SELECT 'not_open' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    UPDATE refunds
       SET status = 'completed'
     WHERE id = (p_refund_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'refund_completed', NULL, NULL,
            LEFT(CONCAT('Đã hoàn ', REPLACE(FORMAT(v_amount, 0), ',', '.'), ' VND cho khách, mã giao dịch ', v_reference), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, v_booking_id AS booking_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_bank(p_user_id)
--   Tài khoản nhận tiền chi trả của đơn vị đang đăng nhập. 0 hoặc 1 dòng: provider_id,
--   bank_name, bank_account_no, bank_account_name (NULL = chưa khai).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_bank;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_bank(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT pr.id AS provider_id, pr.bank_name, pr.bank_account_no, pr.bank_account_name
      FROM providers pr
      JOIN users u ON u.id = pr.user_id
     WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND u.role = 'provider'
       AND u.status = 'active'
       AND pr.approval_status = 'approved';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_bank_save(p_user_id, p_bank_name, p_bank_account_no, p_bank_account_name)
--   Đơn vị tự khai / sửa tài khoản nhận tiền của chính mình.
--     p_bank_name         : tên ngân hàng, 2 - 100 ký tự.
--     p_bank_account_no   : số tài khoản, chỉ chữ số, 6 - 20 chữ số.
--     p_bank_account_name : tên chủ tài khoản, 2 - 100 ký tự.
--   Ghi admin_logs 'provider_bank' (target_type 'provider_bank', target_id = mã đơn vị; số tài
--   khoản trong ghi chú chỉ hiện 4 số cuối). Khoản đã "Đã chi trả" giữ tài khoản đã chụp.
--   1 dòng: result, field.
--     result = 'ok' | 'unchanged'
--              'forbidden' (không phải tài khoản đơn vị đang hoạt động, đơn vị đang hợp tác)
--              'invalid'   (field = bank_name, bank_account_no hoặc bank_account_name)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_bank_save;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_bank_save(
    IN p_user_id           CHAR(36),
    IN p_bank_name         VARCHAR(255) CHARACTER SET utf8mb4,
    IN p_bank_account_no   VARCHAR(255) CHARACTER SET utf8mb4,
    IN p_bank_account_name VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_provider_id CHAR(36)     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_name        VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_bank_name, ''));
    DECLARE v_no          VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_bank_account_no, ''));
    DECLARE v_holder      VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_bank_account_name, ''));
    DECLARE v_old_name    VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_no      VARCHAR(30)  CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_holder  VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF CHAR_LENGTH(v_name) NOT BETWEEN 2 AND 100 THEN
        SELECT 'invalid' AS result, 'bank_name' AS field;
        LEAVE proc;
    END IF;
    IF NOT (v_no REGEXP '^[0-9]{6,20}$') THEN
        SELECT 'invalid' AS result, 'bank_account_no' AS field;
        LEAVE proc;
    END IF;
    IF CHAR_LENGTH(v_holder) NOT BETWEEN 2 AND 100 THEN
        SELECT 'invalid' AS result, 'bank_account_name' AS field;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT MAX(x.id), MAX(x.bank_name), MAX(x.bank_account_no), MAX(x.bank_account_name)
      INTO v_provider_id, v_old_name, v_old_no, v_old_holder
      FROM (SELECT pr.id, pr.bank_name, pr.bank_account_no, pr.bank_account_name
              FROM providers pr
              JOIN users u ON u.id = pr.user_id
             WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
               AND u.role = 'provider'
               AND u.status = 'active'
               AND pr.approval_status = 'approved'
               FOR UPDATE) x;

    IF v_provider_id IS NULL THEN
        ROLLBACK;
        SELECT 'forbidden' AS result, NULL AS field;
        LEAVE proc;
    END IF;

    IF (v_old_name <=> v_name) AND (v_old_no <=> v_no) AND (v_old_holder <=> v_holder) THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field;
        LEAVE proc;
    END IF;

    UPDATE providers
       SET bank_name = v_name, bank_account_no = v_no, bank_account_name = v_holder
     WHERE id = v_provider_id;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_user_id, 'provider_bank', v_provider_id, 'provider_bank', NULL, NULL,
            LEFT(CONCAT(IF(v_old_no IS NULL, 'Đơn vị khai tài khoản nhận tiền: ', 'Đơn vị đổi tài khoản nhận tiền: '),
                        v_name, ', số tài khoản ****', RIGHT(v_no, 4), ', ', v_holder), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_payout_summary(p_user_id)
--   Số liệu đầu trang "Doanh thu & chi trả" của đơn vị đang đăng nhập. 0 hoặc 1 dòng:
--   commission_percent (% phí dịch vụ hiện tại, áp dụng cho đơn đặt từ lúc này),
--   has_bank (1 = đã khai đủ tài khoản nhận tiền), payout_count, gross_vnd, commission_vnd,
--   net_pending_vnd, net_paid_vnd.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_payout_summary;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_payout_summary(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    DECLARE v_rate DECIMAL(5,2) DEFAULT 10;

    CALL NTK_sp_setting_commission_rate(v_rate);

    SELECT
        v_rate AS commission_percent,
        (COALESCE(pr.bank_name, '') <> ''
         AND COALESCE(pr.bank_account_no, '') <> ''
         AND COALESCE(pr.bank_account_name, '') <> '') AS has_bank,
        (SELECT COUNT(*) FROM host_payouts hp WHERE hp.provider_id = pr.id) AS payout_count,
        (SELECT COALESCE(SUM(hp.gross_vnd), 0) FROM host_payouts hp WHERE hp.provider_id = pr.id) AS gross_vnd,
        (SELECT COALESCE(SUM(hp.commission_vnd), 0) FROM host_payouts hp WHERE hp.provider_id = pr.id) AS commission_vnd,
        (SELECT COALESCE(SUM(hp.net_vnd), 0) FROM host_payouts hp
          WHERE hp.provider_id = pr.id AND hp.status = 'pending') AS net_pending_vnd,
        (SELECT COALESCE(SUM(hp.net_vnd), 0) FROM host_payouts hp
          WHERE hp.provider_id = pr.id AND hp.status = 'paid') AS net_paid_vnd
    FROM providers pr
    JOIN users u ON u.id = pr.user_id
    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND u.status = 'active'
      AND pr.approval_status = 'approved';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_payout_list(p_user_id)
--   Khoản chi trả của đơn vị đang đăng nhập, lịch kết thúc gần đây trước.
--   Cột: payout_id, status, created_at, paid_at, transfer_reference, booking_count, gross_vnd,
--        commission_vnd, net_vnd, schedule_id, starts_at, ends_at, tour_id, tour_title.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_payout_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_payout_list(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        hp.id     AS payout_id,
        hp.status,
        hp.created_at,
        hp.paid_at,
        hp.transfer_reference,
        hp.booking_count,
        hp.gross_vnd,
        hp.commission_vnd,
        hp.net_vnd,
        s.id      AS schedule_id,
        s.starts_at,
        s.ends_at,
        t.id      AS tour_id,
        t.title   AS tour_title
    FROM host_payouts hp
    JOIN schedules s  ON s.id = hp.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = hp.provider_id
    JOIN users u      ON u.id = pr.user_id
    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND u.status = 'active'
      AND pr.approval_status = 'approved'
    ORDER BY s.ends_at DESC, hp.id
    LIMIT 500;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_payout_detail(p_user_id, p_payout_id)
--   Một khoản chi trả của đơn vị đang đăng nhập; 0 dòng = không có hoặc của đơn vị khác.
--   Cột: payout_id, status, created_at, paid_at, transfer_reference, booking_count, gross_vnd,
--        commission_vnd, net_vnd, bank_name, bank_account_no, bank_account_name (tài khoản đã
--        nhận tiền; NULL khi còn chờ), schedule_id, starts_at, ends_at, tour_id, tour_title.
--   Không trả ghi chú nội bộ và tên quản trị viên.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_payout_detail;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_payout_detail(
    IN p_user_id   CHAR(36),
    IN p_payout_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        hp.id     AS payout_id,
        hp.status,
        hp.created_at,
        hp.paid_at,
        hp.transfer_reference,
        hp.booking_count,
        hp.gross_vnd,
        hp.commission_vnd,
        hp.net_vnd,
        hp.bank_name,
        hp.bank_account_no,
        hp.bank_account_name,
        s.id      AS schedule_id,
        s.starts_at,
        s.ends_at,
        t.id      AS tour_id,
        t.title   AS tour_title
    FROM host_payouts hp
    JOIN schedules s  ON s.id = hp.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = hp.provider_id
    JOIN users u      ON u.id = pr.user_id
    WHERE hp.id = (p_payout_id COLLATE utf8mb4_unicode_ci)
      AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND u.status = 'active'
      AND pr.approval_status = 'approved';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_payout_item_list(p_user_id, p_payout_id)
--   Các đơn trong một khoản chi trả của đơn vị đang đăng nhập (khoản của đơn vị khác: 0 dòng).
--   Cột: booking_id, code, booking_status, contact_name, people, kept_vnd, commission_rate,
--        commission_vnd, net_vnd.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_payout_item_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_payout_item_list(
    IN p_user_id   CHAR(36),
    IN p_payout_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id      AS booking_id,
        b.code,
        b.status  AS booking_status,
        b.contact_name,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        i.kept_vnd,
        i.commission_rate,
        i.commission_vnd,
        i.net_vnd
    FROM host_payout_items i
    JOIN host_payouts hp ON hp.id = i.payout_id
    JOIN bookings b      ON b.id = i.booking_id
    JOIN providers pr    ON pr.id = hp.provider_id
    JOIN users u         ON u.id = pr.user_id
    WHERE hp.id = (p_payout_id COLLATE utf8mb4_unicode_ci)
      AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND u.status = 'active'
      AND pr.approval_status = 'approved'
    ORDER BY b.code, i.id;
END$$
DELIMITER ;
