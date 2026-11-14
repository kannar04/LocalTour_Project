-- =====================================================================
-- LocalTour v0.2 - 10_procedures_LTP_booking.sql
-- Mục đích  : Lưu đơn đặt tour (M4 mục 6): tạo đơn 'awaiting_payment' (Chờ thanh toán) và giữ chỗ
--             ngay, kèm dòng vé, phụ thu / hoạt động tùy chọn và danh sách khách trong một
--             transaction, sinh mã đơn LTxxxxxx và ghi lịch sử "tạo đơn".
-- Phụ trách : Lê Trung Phong (LTP) - M4 mục 6; Sprint 4: 4.3.3.1, 4.3.3.2; Sprint 5: US06-S5-01
-- Procedures: LTP_sp_booking_create
-- Quy tắc   : * Chỉ tài khoản khách hàng đang hoạt động đặt được (user_id lấy từ session).
--             * Lịch phải đặt được: tour đang hiển thị, lịch 'open' và còn hơn
--               settings.booking_cutoff_minutes phút (mặc định 60) mới tới giờ khởi hành.
--             * Số khách = số dòng trong danh sách khách; mỗi khách có đúng một loại vé đang
--               bán của lịch đó. booking_lines = số khách theo từng loại vé, nên tổng
--               quantity luôn bằng số hành khách.
--             * Số khách <= tours.max_group_size và <= schedules.remaining (khóa dòng lịch
--               FOR UPDATE khi kiểm tra).
--             * Đặt ngay, không chờ duyệt tay (file 28): đơn mới trừ schedules.remaining theo số
--               khách trong cùng transaction (lịch về 0 chỗ thì chuyển 'full') và ở trạng thái
--               'awaiting_payment'. Hạn giữ chỗ hold_expires_at = NOW() + settings.hold_minutes
--               phút (mặc định 30), không muộn hơn giờ khởi hành. Quá hạn chưa thanh toán:
--               LTP_sp_booking_expire_holds (file 15) hủy đơn và trả lại chỗ.
--             * Phí dịch vụ: settings.commission_percent lúc đặt (mặc định 10) chụp lại vào
--               bookings.commission_rate; đổi thông số sau này không đổi đơn cũ.
--             * Thông số trong settings thiếu hoặc không phải số hợp lệ thì dùng giá trị mặc định.
--             * Phụ thu / hoạt động tùy chọn (Sprint 4, 4.3.2.3): khách chọn các khoản của
--               tour (tour_extras) đã có giá. Đơn vị 'người' / 'khách' -> số lượng = số khách;
--               đơn vị khác ('nhóm', 'xe', 'thuyền', không ghi) -> 1. Tên, loại, đơn vị và giá
--               chụp lại vào booking_extras (file 12). Khoản chưa có giá không chọn được.
--             * Giá vé chụp lại vào unit_price_vnd. Tổng tiền = tiền vé + phụ thu / tùy chọn,
--               tính lại ở database; khác với
--               số tiền khách đã xem (p_expected_total) thì không tạo đơn, trả 'price_changed'
--               kèm tổng mới để khách xác nhận lại.
--             * policy_version = phiên bản chính sách hủy mới nhất của tour lúc đặt
--               (0 = tour chưa có chính sách hủy).
--             * Chống tạo trùng: cùng tài khoản + cùng request_token (một lần mở form) chỉ
--               tạo một đơn; gửi lại trả 'duplicate' kèm mã đơn đã tạo.
--             * Yêu cầu đặc biệt (ăn chay, dị ứng...) lưu ở khách đầu tiên trong danh sách.
--             * Lịch sử (4.3.3.2, FR-11): ghi booking_events 'created' (actor = khách,
--               NULL -> 'awaiting_payment', ghi chú có hạn giữ chỗ).
--             * Gói tour (Sprint 5, US06-S5-01, FR-07): tour có gói đang bán thì phải chọn
--               đúng một gói của tour; giá vé lấy theo gói (người lớn / trẻ em), vé trẻ em chỉ
--               bán khi gói có giá trẻ em. Tour không có gói đang bán thì không gửi gói, giá
--               theo lịch như trước. Mã và tên gói chụp lại vào bookings (file 16).
--             * Không gọi cổng thanh toán, không thu tiền ở bước này: ứng dụng chuyển khách sang
--               trang thanh toán của đơn ngay sau khi tạo (14_procedures_NMT_payment.sql).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8: đọc JSON bằng JSON_EXTRACT theo chỉ số
--             (MariaDB 10.4 chưa có JSON_TABLE).
-- Chạy sau  : 01_schema.sql, 08_migration_booking_NMT.sql, 12_migration_sprint4_NMT.sql,
--             16_migration_sprint5_LTP.sql. Khi gọi cần bảng settings và cột
--             bookings.commission_rate (28_migration_economy_NTK.sql).
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_booking_create(p_user_id, p_schedule_id, p_request_token, p_contact_name,
--                       p_contact_email, p_contact_phone, p_passengers, p_special_request,
--                       p_expected_total, p_extras, p_package_id)
--   p_passengers    : mảng JSON, mỗi khách một phần tử, theo thứ tự trên form:
--                     [{"ticket_type_id": "<uuid>", "full_name": "Nguyễn Văn A"}, ...]
--   p_special_request: NULL / '' = không có.
--   p_expected_total: tổng tiền (VND) khách thấy trên trang trước khi bấm gửi (vé + phụ thu /
--                     tùy chọn đã chọn).
--   p_extras        : mảng JSON mã các khoản phụ thu / tùy chọn khách chọn, vd. ["<uuid>", ...];
--                     NULL / '[]' = không chọn.
--   p_package_id    : gói khách chọn (NULL / '' = không chọn, chỉ hợp lệ khi tour không có gói
--                     đang bán).
--   1 dòng: result, booking_code, total_vnd, remaining, max_group_size.
--     result = 'ok'                   : đã tạo đơn 'awaiting_payment' và giữ chỗ; booking_code =
--                                       mã đơn mới, remaining = số chỗ còn lại sau khi giữ.
--              'duplicate'            : request_token này đã tạo đơn; booking_code = mã đơn đó
--                                       (không giữ thêm chỗ).
--              'forbidden'            : không phải tài khoản khách hàng đang hoạt động.
--              'invalid'              : thiếu thông tin liên hệ / mã yêu cầu, danh sách khách
--                                       rỗng hoặc sai dạng, họ tên khách trống hoặc quá 100 ký tự.
--              'schedule_unavailable' : lịch không còn nhận đặt (không có, tour bị ẩn, đã hủy,
--                                       đã khởi hành hoặc đã qua hạn nhận đặt trước giờ khởi hành).
--              'group_limit'          : số khách vượt max_group_size (trả max_group_size).
--              'no_seats'             : số khách vượt số chỗ còn lại (trả remaining; lịch vừa hết
--                                       chỗ 'full' vì đơn khác đã giữ thì remaining = 0).
--              'tickets_changed'      : có loại vé không còn bán cho lịch này.
--              'extras_changed'       : có khoản phụ thu / tùy chọn không còn hoặc chưa có giá.
--              'package_changed'      : gói đã chọn không còn bán, tour vừa có / hết gói, hoặc
--                                       gói không bán loại vé đã chọn (vé trẻ em).
--              'price_changed'        : tổng tiền hiện tại khác p_expected_total (trả total_vnd mới).
--              'retry'                : trùng mã đơn hiếm gặp khi ghi, khách gửi lại là được.
--     Khi không 'ok', không có gì được ghi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_booking_create;

DELIMITER $$
CREATE PROCEDURE LTP_sp_booking_create(
    IN p_user_id         CHAR(36),
    IN p_schedule_id     CHAR(36),
    IN p_request_token   VARCHAR(64),
    IN p_contact_name    VARCHAR(100) CHARACTER SET utf8mb4,
    IN p_contact_email   VARCHAR(150) CHARACTER SET utf8mb4,
    IN p_contact_phone   VARCHAR(20)  CHARACTER SET utf8mb4,
    IN p_passengers      TEXT         CHARACTER SET utf8mb4,
    IN p_special_request TEXT         CHARACTER SET utf8mb4,
    IN p_expected_total  BIGINT,
    IN p_extras          TEXT,
    IN p_package_id      CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_code        VARCHAR(20)  DEFAULT NULL;
    DECLARE v_token       VARCHAR(64)  DEFAULT NULL;
    DECLARE v_name        VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_email       VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_phone       VARCHAR(20)  CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_request     TEXT         CHARACTER SET utf8mb4;
    DECLARE v_tour_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_remaining   INT          DEFAULT NULL;
    DECLARE v_max_group   INT          DEFAULT NULL;
    DECLARE v_policy      INT          DEFAULT 0;
    DECLARE v_count       INT          DEFAULT 0;
    DECLARE v_i           INT          DEFAULT 0;
    DECLARE v_total       BIGINT       DEFAULT 0;
    DECLARE v_ticket_id   VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_full_name   TEXT         CHARACTER SET utf8mb4;
    DECLARE v_ticket_name VARCHAR(50)  CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_price       BIGINT       DEFAULT NULL;
    DECLARE v_duplicate   BOOLEAN      DEFAULT FALSE;
    DECLARE v_extra_count INT          DEFAULT 0;
    DECLARE v_extra_id    VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_extra_seen  TEXT         CHARACTER SET utf8mb4 DEFAULT '';
    DECLARE v_extra_qty   INT          DEFAULT 0;
    DECLARE v_extra_unit  VARCHAR(50)  CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_package_id  CHAR(36)     DEFAULT NULLIF(TRIM(p_package_id), '');
    DECLARE v_package     VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_pkg_adult   BIGINT       DEFAULT NULL;
    DECLARE v_pkg_child   BIGINT       DEFAULT NULL;
    DECLARE v_pkg_count   INT          DEFAULT 0;
    DECLARE v_starts_at   DATETIME     DEFAULT NULL;
    DECLARE v_sched_st    VARCHAR(30)  DEFAULT NULL;
    DECLARE v_hold_until  DATETIME     DEFAULT NULL;
    DECLARE v_cutoff_min  INT          DEFAULT 60;
    DECLARE v_hold_min    INT          DEFAULT 30;
    DECLARE v_commission  DECIMAL(5,2) DEFAULT 10.00;
    -- 1062 = trùng khóa UNIQUE: cùng request_token vừa được gửi song song, hoặc trùng mã đơn.
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_token   = NULLIF(TRIM(p_request_token), '');
    SET v_name    = NULLIF(TRIM(p_contact_name), '');
    SET v_email   = NULLIF(LOWER(TRIM(p_contact_email)), '');
    SET v_phone   = NULLIF(TRIM(p_contact_phone), '');
    SET v_request = NULLIF(TRIM(p_special_request), '');

    -- 1. Người đặt: tài khoản khách hàng đang hoạt động.
    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'customer' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
        LEAVE proc;
    END IF;

    -- 2. Dữ liệu gửi lên (ứng dụng đã kiểm tra định dạng; đây là chốt chặn cuối).
    IF v_token IS NULL OR v_name IS NULL OR v_email IS NULL OR v_phone IS NULL
       OR COALESCE(JSON_VALID(p_passengers), 0) = 0 THEN
        SELECT 'invalid' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
        LEAVE proc;
    END IF;
    -- Tách riêng: MySQL 8 báo lỗi nếu gọi JSON_TYPE với chuỗi không phải JSON.
    IF JSON_TYPE(p_passengers) <> 'ARRAY' OR JSON_LENGTH(p_passengers) = 0 THEN
        SELECT 'invalid' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
        LEAVE proc;
    END IF;

    SET v_count = JSON_LENGTH(p_passengers);
    SET v_i = 0;
    WHILE v_i < v_count DO
        SET v_ticket_id = JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].ticket_type_id')));
        SET v_full_name = TRIM(JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].full_name'))));
        IF v_ticket_id IS NULL OR v_full_name IS NULL OR v_full_name = '' OR CHAR_LENGTH(v_full_name) > 100 THEN
            SELECT 'invalid' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
            LEAVE proc;
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    -- Phụ thu / tùy chọn: mảng mã, không trùng nhau.
    IF NULLIF(TRIM(p_extras), '') IS NOT NULL THEN
        IF COALESCE(JSON_VALID(p_extras), 0) = 0 THEN
            SELECT 'invalid' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
            LEAVE proc;
        END IF;
        IF JSON_TYPE(p_extras) <> 'ARRAY' THEN
            SELECT 'invalid' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
            LEAVE proc;
        END IF;
        SET v_extra_count = JSON_LENGTH(p_extras);
    END IF;

    SET v_i = 0;
    WHILE v_i < v_extra_count DO
        SET v_extra_id = JSON_UNQUOTE(JSON_EXTRACT(p_extras, CONCAT('$[', v_i, ']')));
        IF v_extra_id IS NULL OR CHAR_LENGTH(v_extra_id) <> 36 OR FIND_IN_SET(v_extra_id, v_extra_seen) > 0 THEN
            SELECT 'invalid' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
            LEAVE proc;
        END IF;
        SET v_extra_seen = CONCAT(v_extra_seen, ',', v_extra_id);
        SET v_i = v_i + 1;
    END WHILE;

    -- 3. Gửi lại cùng một lần mở form: trả đơn đã tạo.
    SELECT b.code INTO v_code
      FROM bookings b
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.request_token = (v_token COLLATE utf8mb4_unicode_ci)
     LIMIT 1;
    IF v_code IS NOT NULL THEN
        SELECT 'duplicate' AS result, v_code AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
        LEAVE proc;
    END IF;

    -- Thông số vận hành (file 28); thiếu dòng hoặc giá trị không hợp lệ thì dùng mặc định.
    SET v_cutoff_min = COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,5}$', CAST(st.value AS UNSIGNED), NULL)
                                   FROM settings st WHERE st.name = 'booking_cutoff_minutes'), 60);
    SET v_hold_min   = COALESCE((SELECT IF(st.value REGEXP '^[1-9][0-9]{0,4}$', CAST(st.value AS UNSIGNED), NULL)
                                   FROM settings st WHERE st.name = 'hold_minutes'), 30);
    -- % phí dịch vụ: cùng một quy tắc đọc với NTK_sp_setting_commission_rate (file 30).
    SET v_commission = COALESCE((SELECT IF(st.value REGEXP '^[0-9]{1,3}([.][0-9]{1,2})?$' AND CAST(st.value AS DECIMAL(7,2)) <= 100,
                                           CAST(st.value AS DECIMAL(5,2)), NULL)
                                   FROM settings st WHERE st.name = 'commission_percent'), 10.00);

    START TRANSACTION;

    -- 4. Khóa dòng lịch để số chỗ không đổi trong lúc kiểm tra và giữ chỗ.
    --    Lịch 'full' vẫn được đọc để báo "hết chỗ" (no_seats) thay vì "không còn nhận đặt".
    SELECT s.tour_id, IF(s.status = 'full', 0, s.remaining), s.starts_at, s.status
      INTO v_tour_id, v_remaining, v_starts_at, v_sched_st
      FROM schedules s
     WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
       AND s.status IN ('open', 'full')
       AND s.starts_at > NOW() + INTERVAL v_cutoff_min MINUTE
       FOR UPDATE;

    SELECT t.max_group_size INTO v_max_group
      FROM tours t
      JOIN providers p ON p.id = t.provider_id
      JOIN users     u ON u.id = p.user_id
     WHERE t.id = (v_tour_id COLLATE utf8mb4_unicode_ci)
       AND t.approval_status = 'approved'
       AND p.approval_status = 'approved'
       AND u.status = 'active';

    IF v_tour_id IS NULL OR v_max_group IS NULL THEN
        ROLLBACK;
        SELECT 'schedule_unavailable' AS result, NULL AS booking_code, NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
        LEAVE proc;
    END IF;

    IF v_count > v_max_group THEN
        ROLLBACK;
        SELECT 'group_limit' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
        LEAVE proc;
    END IF;

    IF v_count > v_remaining THEN
        ROLLBACK;
        SELECT 'no_seats' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
        LEAVE proc;
    END IF;

    -- 4b. Gói: tour có gói đang bán thì phải chọn một gói đang bán của tour; không có thì
    --     không được gửi gói.
    SELECT COUNT(*) INTO v_pkg_count
      FROM tour_packages tp
     WHERE tp.tour_id = (v_tour_id COLLATE utf8mb4_unicode_ci)
       AND tp.active = TRUE;

    IF v_package_id IS NOT NULL THEN
        SELECT tp.name, tp.adult_price_vnd, tp.child_price_vnd
          INTO v_package, v_pkg_adult, v_pkg_child
          FROM tour_packages tp
         WHERE tp.id = (v_package_id COLLATE utf8mb4_unicode_ci)
           AND tp.tour_id = (v_tour_id COLLATE utf8mb4_unicode_ci)
           AND tp.active = TRUE
           LOCK IN SHARE MODE;
    END IF;

    IF (v_pkg_count > 0 AND v_package IS NULL) OR (v_pkg_count = 0 AND v_package_id IS NOT NULL) THEN
        ROLLBACK;
        SELECT 'package_changed' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
        LEAVE proc;
    END IF;

    -- 5. Giá hiện tại của từng khách theo loại vé (vé phải còn bán cho đúng lịch này); có gói
    --    thì giá theo gói.
    SET v_i = 0;
    WHILE v_i < v_count DO
        SET v_ticket_id = JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].ticket_type_id')));
        SET v_price = NULL;
        SET v_ticket_name = NULL;
        SELECT tt.price_vnd, tt.name INTO v_price, v_ticket_name
          FROM ticket_types tt
         WHERE tt.id = (v_ticket_id COLLATE utf8mb4_unicode_ci)
           AND tt.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
           AND tt.active = TRUE
           LOCK IN SHARE MODE;
        IF v_price IS NULL THEN
            ROLLBACK;
            SELECT 'tickets_changed' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
            LEAVE proc;
        END IF;
        IF v_package IS NOT NULL THEN
            SET v_price = IF(LOWER(v_ticket_name) = 'child', v_pkg_child, v_pkg_adult);
            IF v_price IS NULL THEN
                ROLLBACK;
                SELECT 'package_changed' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
                LEAVE proc;
            END IF;
        END IF;
        SET v_total = v_total + v_price;
        SET v_i = v_i + 1;
    END WHILE;

    -- 5b. Phụ thu / tùy chọn: phải thuộc tour này và đã có giá.
    SET v_i = 0;
    WHILE v_i < v_extra_count DO
        SET v_extra_id = JSON_UNQUOTE(JSON_EXTRACT(p_extras, CONCAT('$[', v_i, ']')));
        SET v_price = NULL;
        SET v_extra_unit = NULL;
        SELECT te.price_vnd, te.price_unit INTO v_price, v_extra_unit
          FROM tour_extras te
         WHERE te.id = (v_extra_id COLLATE utf8mb4_unicode_ci)
           AND te.tour_id = (v_tour_id COLLATE utf8mb4_unicode_ci)
           LOCK IN SHARE MODE;
        IF v_price IS NULL THEN
            ROLLBACK;
            SELECT 'extras_changed' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
            LEAVE proc;
        END IF;
        SET v_extra_qty = IF(LOWER(TRIM(v_extra_unit)) IN ('người', 'khách'), v_count, 1);
        SET v_total = v_total + v_price * v_extra_qty;
        SET v_i = v_i + 1;
    END WHILE;

    IF NOT (v_total <=> p_expected_total) THEN
        ROLLBACK;
        SELECT 'price_changed' AS result, NULL AS booking_code, v_total AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
        LEAVE proc;
    END IF;

    -- 6. Tạo đơn 'awaiting_payment': chính sách hủy mới nhất, mã đơn LT + 6 chữ số chưa dùng,
    --    hạn giữ chỗ không muộn hơn giờ khởi hành.
    SELECT COALESCE(MAX(cp.version), 0) INTO v_policy
      FROM cancellation_policies cp
     WHERE cp.tour_id = (v_tour_id COLLATE utf8mb4_unicode_ci);

    SET v_code = NULL;
    REPEAT
        SET v_code = CONCAT('LT', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
    UNTIL NOT EXISTS (SELECT 1 FROM bookings b WHERE b.code = v_code) END REPEAT;

    SET v_hold_until = LEAST(NOW() + INTERVAL v_hold_min MINUTE, v_starts_at);
    SET v_booking_id = UUID();
    INSERT INTO bookings (id, user_id, schedule_id, package_id, package_name, code, request_token, contact_name,
                          contact_email, contact_phone, status, total_vnd, commission_rate, policy_version,
                          hold_expires_at, created_at)
    VALUES (v_booking_id, p_user_id, p_schedule_id, IF(v_package IS NULL, NULL, v_package_id), v_package, v_code,
            v_token, v_name, v_email, v_phone, 'awaiting_payment', v_total, v_commission, v_policy,
            v_hold_until, NOW());

    IF v_duplicate THEN
        ROLLBACK;
        SET v_code = NULL;
        SELECT b.code INTO v_code
          FROM bookings b
         WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND b.request_token = (v_token COLLATE utf8mb4_unicode_ci)
         LIMIT 1;
        SELECT IF(v_code IS NULL, 'retry', 'duplicate') AS result, v_code AS booking_code,
               NULL AS total_vnd, NULL AS remaining, NULL AS max_group_size;
        LEAVE proc;
    END IF;

    -- 6b. Giữ chỗ (sau khi chắc chắn không phải gửi trùng, để không trừ chỗ hai lần).
    --     SET chạy từ trái sang phải: status so với remaining đã trừ.
    UPDATE schedules
       SET remaining = remaining - v_count,
           status = IF(remaining = 0 AND status = 'open', 'full', status)
     WHERE id = (p_schedule_id COLLATE utf8mb4_unicode_ci);

    -- 7. Khách (giữ thứ tự trên form) và dòng vé (mỗi loại vé một dòng, cộng dồn số lượng).
    SET v_i = 0;
    WHILE v_i < v_count DO
        SET v_ticket_id = JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].ticket_type_id')));
        SET v_full_name = TRIM(JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].full_name'))));
        SELECT tt.name, tt.price_vnd INTO v_ticket_name, v_price
          FROM ticket_types tt
         WHERE tt.id = (v_ticket_id COLLATE utf8mb4_unicode_ci);
        IF v_package IS NOT NULL THEN
            SET v_price = IF(LOWER(v_ticket_name) = 'child', v_pkg_child, v_pkg_adult);
        END IF;

        INSERT INTO passengers (id, booking_id, full_name, age_group, special_request, sort_order)
        VALUES (UUID(), v_booking_id, v_full_name,
                CASE LOWER(v_ticket_name) WHEN 'child' THEN 'child' WHEN 'infant' THEN 'infant' ELSE 'adult' END,
                IF(v_i = 0, v_request, NULL), v_i + 1);

        INSERT INTO booking_lines (id, booking_id, ticket_type_id, quantity, unit_price_vnd, line_total_vnd)
        VALUES (UUID(), v_booking_id, v_ticket_id, 1, v_price, v_price)
        ON DUPLICATE KEY UPDATE quantity = quantity + 1,
                                line_total_vnd = quantity * unit_price_vnd;

        SET v_i = v_i + 1;
    END WHILE;

    -- 8. Phụ thu / tùy chọn đã chọn (chụp lại tên, loại, đơn vị, giá).
    SET v_i = 0;
    WHILE v_i < v_extra_count DO
        SET v_extra_id = JSON_UNQUOTE(JSON_EXTRACT(p_extras, CONCAT('$[', v_i, ']')));
        INSERT INTO booking_extras (id, booking_id, extra_id, kind, name, price_unit, quantity,
                                    unit_price_vnd, line_total_vnd, sort_order)
        SELECT UUID(), v_booking_id, te.id, te.kind, te.name, te.price_unit,
               IF(LOWER(TRIM(te.price_unit)) IN ('người', 'khách'), v_count, 1),
               te.price_vnd,
               te.price_vnd * IF(LOWER(TRIM(te.price_unit)) IN ('người', 'khách'), v_count, 1),
               v_i + 1
          FROM tour_extras te
         WHERE te.id = (v_extra_id COLLATE utf8mb4_unicode_ci);
        SET v_i = v_i + 1;
    END WHILE;

    -- 9. Lịch sử của đơn (FR-11, NFR-09).
    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'customer', p_user_id, 'created', NULL, 'awaiting_payment',
            LEFT(CONCAT(v_count, ' khách', IF(v_package IS NULL, '', CONCAT(', gói ', v_package)),
                        ', tổng ', REPLACE(FORMAT(v_total, 0), ',', '.'), ' VND; giữ chỗ tới ',
                        DATE_FORMAT(v_hold_until, '%H:%i %d/%m/%Y')), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, v_code AS booking_code, v_total AS total_vnd, v_remaining - v_count AS remaining, v_max_group AS max_group_size;
END$$
DELIMITER ;
