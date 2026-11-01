-- =====================================================================
-- LocalTour v0.2 - 10_procedures_LTP_booking.sql
-- Mục đích  : Lưu yêu cầu đặt tour (M4 mục 6): tạo đơn 'pending' (Chờ xác nhận) kèm dòng vé,
--             phụ thu / hoạt động tùy chọn và danh sách khách trong một transaction, sinh mã
--             đơn LTxxxxxx và ghi lịch sử "tạo đơn".
-- Phụ trách : Lê Trung Phong (LTP) - M4 mục 6; Sprint 4: 4.3.3.1, 4.3.3.2
-- Procedures: LTP_sp_booking_create
-- Quy tắc   : * Chỉ tài khoản khách hàng đang hoạt động đặt được (user_id lấy từ session).
--             * Lịch phải đặt được: tour đang hiển thị, lịch 'open', chưa khởi hành.
--             * Số khách = số dòng trong danh sách khách; mỗi khách có đúng một loại vé đang
--               bán của lịch đó. booking_lines = số khách theo từng loại vé, nên tổng
--               quantity luôn bằng số hành khách.
--             * Số khách <= tours.max_group_size và <= schedules.remaining (khóa dòng lịch
--               FOR UPDATE khi kiểm tra). Đơn mới KHÔNG trừ remaining: quản trị viên xác nhận
--               chỗ (pending -> awaiting_payment, file 07) mới giữ chỗ.
--             * Phụ thu / hoạt động tùy chọn (Sprint 4, 4.3.2.3): khách chọn các khoản của
--               tour (tour_extras) đã có giá. Đơn vị 'người' / 'khách' -> số lượng = số khách;
--               đơn vị khác ('nhóm', 'xe', 'thuyền', không ghi) -> 1. Tên, loại, đơn vị và giá
--               chụp lại vào booking_extras (file 12). Quản trị viên chốt lại tổng giá khi xác
--               nhận chỗ nếu cần (vd. phụ thu ngày lễ, 07_procedures_NTK_admin.sql).
--             * Giá vé chụp lại vào unit_price_vnd. Tổng tiền = tiền vé + phụ thu / tùy chọn,
--               tính lại ở database; khác với
--               số tiền khách đã xem (p_expected_total) thì không tạo đơn, trả 'price_changed'
--               kèm tổng mới để khách xác nhận lại.
--             * policy_version = phiên bản chính sách hủy mới nhất của tour lúc đặt
--               (0 = tour chưa có chính sách hủy).
--             * Chống tạo trùng: cùng tài khoản + cùng request_token (một lần mở form) chỉ
--               tạo một đơn; gửi lại trả 'duplicate' kèm mã đơn đã tạo.
--             * Yêu cầu đặc biệt (ăn chay, dị ứng...) lưu ở khách đầu tiên trong danh sách.
--             * Lịch sử (4.3.3.2, FR-11): ghi booking_events 'created' (actor = khách).
--             * Không gọi cổng thanh toán, không thu tiền ở bước này: khách thanh toán sau khi
--               quản trị viên xác nhận chỗ và giá (14_procedures_NMT_payment.sql).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8: đọc JSON bằng JSON_EXTRACT theo chỉ số
--             (MariaDB 10.4 chưa có JSON_TABLE).
-- Chạy sau  : 01_schema.sql, 08_migration_booking_NMT.sql, 12_migration_sprint4_NMT.sql.
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_booking_create(p_user_id, p_schedule_id, p_request_token, p_contact_name,
--                       p_contact_email, p_contact_phone, p_passengers, p_special_request,
--                       p_expected_total, p_extras)
--   p_passengers    : mảng JSON, mỗi khách một phần tử, theo thứ tự trên form:
--                     [{"ticket_type_id": "<uuid>", "full_name": "Nguyễn Văn A"}, ...]
--   p_special_request: NULL / '' = không có.
--   p_expected_total: tổng tiền (VND) khách thấy trên trang trước khi bấm gửi (vé + phụ thu /
--                     tùy chọn đã chọn).
--   p_extras        : mảng JSON mã các khoản phụ thu / tùy chọn khách chọn, vd. ["<uuid>", ...];
--                     NULL / '[]' = không chọn.
--   1 dòng: result, booking_code, total_vnd, remaining, max_group_size.
--     result = 'ok'                   : đã tạo đơn pending; booking_code = mã đơn mới.
--              'duplicate'            : request_token này đã tạo đơn; booking_code = mã đơn đó.
--              'forbidden'            : không phải tài khoản khách hàng đang hoạt động.
--              'invalid'              : thiếu thông tin liên hệ / mã yêu cầu, danh sách khách
--                                       rỗng hoặc sai dạng, họ tên khách trống hoặc quá 100 ký tự.
--              'schedule_unavailable' : lịch không còn nhận đặt (không có, tour bị ẩn, đã hủy,
--                                       hết chỗ 'full' hoặc đã khởi hành).
--              'group_limit'          : số khách vượt max_group_size (trả max_group_size).
--              'no_seats'             : số khách vượt số chỗ còn lại (trả remaining).
--              'tickets_changed'      : có loại vé không còn bán cho lịch này.
--              'extras_changed'       : có khoản phụ thu / tùy chọn không còn hoặc chưa có giá.
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
    IN p_extras          TEXT
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

    START TRANSACTION;

    -- 4. Khóa dòng lịch để số chỗ không đổi trong lúc kiểm tra.
    SELECT s.tour_id, s.remaining
      INTO v_tour_id, v_remaining
      FROM schedules s
     WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
       AND s.status = 'open'
       AND s.starts_at > NOW()
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

    -- 5. Giá hiện tại của từng khách theo loại vé (vé phải còn bán cho đúng lịch này).
    SET v_i = 0;
    WHILE v_i < v_count DO
        SET v_ticket_id = JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].ticket_type_id')));
        SET v_price = NULL;
        SELECT tt.price_vnd INTO v_price
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

    -- 6. Tạo đơn: chính sách hủy mới nhất, mã đơn LT + 6 chữ số chưa dùng.
    SELECT COALESCE(MAX(cp.version), 0) INTO v_policy
      FROM cancellation_policies cp
     WHERE cp.tour_id = (v_tour_id COLLATE utf8mb4_unicode_ci);

    SET v_code = NULL;
    REPEAT
        SET v_code = CONCAT('LT', LPAD(FLOOR(RAND() * 1000000), 6, '0'));
    UNTIL NOT EXISTS (SELECT 1 FROM bookings b WHERE b.code = v_code) END REPEAT;

    SET v_booking_id = UUID();
    INSERT INTO bookings (id, user_id, schedule_id, code, request_token, contact_name, contact_email,
                          contact_phone, status, total_vnd, policy_version, hold_expires_at, created_at)
    VALUES (v_booking_id, p_user_id, p_schedule_id, v_code, v_token, v_name, v_email,
            v_phone, 'pending', v_total, v_policy, NULL, NOW());

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

    -- 7. Khách (giữ thứ tự trên form) và dòng vé (mỗi loại vé một dòng, cộng dồn số lượng).
    SET v_i = 0;
    WHILE v_i < v_count DO
        SET v_ticket_id = JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].ticket_type_id')));
        SET v_full_name = TRIM(JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].full_name'))));
        SELECT tt.name, tt.price_vnd INTO v_ticket_name, v_price
          FROM ticket_types tt
         WHERE tt.id = (v_ticket_id COLLATE utf8mb4_unicode_ci);

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
    VALUES (UUID(), v_booking_id, 'customer', p_user_id, 'created', NULL, 'pending',
            CONCAT(v_count, ' khách, tổng ', REPLACE(FORMAT(v_total, 0), ',', '.'), ' VND'), NOW());

    COMMIT;
    SELECT 'ok' AS result, v_code AS booking_code, v_total AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
END$$
DELIMITER ;
