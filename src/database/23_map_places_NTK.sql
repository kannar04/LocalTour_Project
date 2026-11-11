-- =====================================================================
-- LocalTour v0.5 - 23_map_places_NTK.sql
-- Mục đích  : Bản đồ và địa điểm du lịch quanh điểm khởi hành của tour.
--   1. tours.latitude / tours.longitude (DECIMAL(9,6), NULL = chưa có vị trí): tọa độ điểm
--      khởi hành = điểm hẹn (meeting_point); tour đón tại khách sạn = khu vực đón. Có cả hai
--      hoặc không có cả hai (ràng buộc chk_tours_location_pair).
--   2. Tọa độ của 12 tour mẫu: tra một lần bằng OpenStreetMap Nominatim khi phát triển
--      (11/11/2026) và ghi cố định bên dưới; trang web không gọi Nominatim. Chỉ điền khi tour
--      chưa có tọa độ, chạy lại file không ghi đè vị trí quản trị viên đã sửa.
--   3. map_place_cache: kết quả tra Overpass API (quán ăn, bar, giải trí, quán nước trong bán
--      kính quanh một điểm), lưu dạng JSON theo điểm đã làm tròn 4 chữ số thập phân. Ứng dụng
--      dùng lại kết quả trong 7 ngày; Overpass lỗi thì dùng kết quả cũ, và tạm không gọi lại
--      trong vài phút (failed_at).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Procedures: NTK_sp_tour_location, NTK_sp_tour_location_list,
--             NTK_sp_admin_tour_location, NTK_sp_admin_tour_set_location,
--             NTK_sp_place_cache_get, NTK_sp_place_cache_save, NTK_sp_place_cache_fail
-- Quy tắc   : * Trang khách chỉ đọc vị trí của tour đang hiển thị (tour 'approved', đơn vị tổ chức
--               'approved', tài khoản đơn vị 'active'), giống NMT_sp_tour_detail.
--             * Đặt / xóa vị trí: chỉ quản trị viên đang hoạt động; tọa độ phải nằm trong khung
--               Việt Nam (vĩ độ 8 -> 23,5; kinh độ 102 -> 110); ghi admin_logs (target_type 'tour',
--               action 'location_set' / 'location_clear').
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01 -> 21. Chạy lại được (ADD COLUMN IF NOT EXISTS, CREATE TABLE IF NOT EXISTS,
--             DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. Tọa độ điểm khởi hành của tour
-- ---------------------------------------------------------------------
ALTER TABLE tours
    ADD COLUMN IF NOT EXISTS latitude  DECIMAL(9,6) NULL AFTER meeting_point,
    ADD COLUMN IF NOT EXISTS longitude DECIMAL(9,6) NULL AFTER latitude;

ALTER TABLE tours
    ADD CONSTRAINT IF NOT EXISTS chk_tours_location_pair
        CHECK ((latitude IS NULL) = (longitude IS NULL)),
    ADD CONSTRAINT IF NOT EXISTS chk_tours_location_range
        CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180));

-- ---------------------------------------------------------------------
-- 2. Tọa độ tour mẫu (Nominatim, 11/11/2026). Ghi chú = đối tượng OSM khớp được.
-- ---------------------------------------------------------------------
-- Nhà hát Múa rối nước Thăng Long, 57B Đinh Tiên Hoàng (way 1190941789)
UPDATE tours SET latitude = 21.031704, longitude = 105.853455
 WHERE id = 'c0000000-0000-4000-8000-000000000001' AND latitude IS NULL AND longitude IS NULL;
-- Chợ Đồng Xuân (way 1212230635)
UPDATE tours SET latitude = 21.038256, longitude = 105.849671
 WHERE id = 'c0000000-0000-4000-8000-000000000002' AND latitude IS NULL AND longitude IS NULL;
-- Đền Bạch Mã, 76 Hàng Buồm / Hàng Giầy (way 700840711)
UPDATE tours SET latitude = 21.035935, longitude = 105.850987
 WHERE id = 'c0000000-0000-4000-8000-000000000003' AND latitude IS NULL AND longitude IS NULL;
-- Đón tại khách sạn ở trung tâm Đà Nẵng: tâm Thành phố Đà Nẵng (relation 1891418, mức thành phố)
UPDATE tours SET latitude = 16.068501, longitude = 108.224024
 WHERE id = 'c0000000-0000-4000-8000-000000000004' AND latitude IS NULL AND longitude IS NULL;
-- Đầu cầu Rồng phía đường Bạch Đằng: đầu phía tây của cầu (way 694831926)
UPDATE tours SET latitude = 16.061136, longitude = 108.224342
 WHERE id = 'c0000000-0000-4000-8000-000000000005' AND latitude IS NULL AND longitude IS NULL;
-- Chùa Cầu, Hội An (way 631074476)
UPDATE tours SET latitude = 15.877154, longitude = 108.326003
 WHERE id = 'c0000000-0000-4000-8000-000000000006' AND latitude IS NULL AND longitude IS NULL;
-- Bãi xe đạp cạnh chợ Hội An: Chợ Hội An (way 35952504)
UPDATE tours SET latitude = 15.876818, longitude = 108.331344
 WHERE id = 'c0000000-0000-4000-8000-000000000007' AND latitude IS NULL AND longitude IS NULL;
-- Đón tại khách sạn ở quận 1 hoặc quận 3: tâm quận 1 cũ (relation 2587287, mức quận)
UPDATE tours SET latitude = 10.775394, longitude = 106.699626
 WHERE id = 'c0000000-0000-4000-8000-000000000008' AND latitude IS NULL AND longitude IS NULL;
-- Chùa Bà Thiên Hậu = Hội quán Tuệ Thành, 710 Nguyễn Trãi (way 1497050780)
UPDATE tours SET latitude = 10.753564, longitude = 106.661192
 WHERE id = 'c0000000-0000-4000-8000-000000000009' AND latitude IS NULL AND longitude IS NULL;
-- Đường Thanh Niên, đoạn thuộc phường Ba Đình (way 1290128836, mức con đường)
UPDATE tours SET latitude = 21.043310, longitude = 105.836027
 WHERE id = 'c0000000-0000-4000-8000-000000000010' AND latitude IS NULL AND longitude IS NULL;
-- Cổng Ngọ Môn, Đại Nội Huế (way 172657562)
UPDATE tours SET latitude = 16.467684, longitude = 107.579080
 WHERE id = 'c0000000-0000-4000-8000-000000000011' AND latitude IS NULL AND longitude IS NULL;
-- Đường Nguyễn Thị Minh Khai trong phố cổ Hội An (way 160628168, mức con đường)
UPDATE tours SET latitude = 15.878491, longitude = 108.323320
 WHERE id = 'c0000000-0000-4000-8000-000000000012' AND latitude IS NULL AND longitude IS NULL;

-- ---------------------------------------------------------------------
-- 3. Bộ nhớ đệm địa điểm quanh một điểm (Overpass API)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS map_place_cache (
    cache_key   VARCHAR(64)  NOT NULL,          -- "vĩ độ,kinh độ,bán kính" đã làm tròn, vd. "21.0317,105.8535,1500"
    latitude    DECIMAL(9,6) NOT NULL,          -- tâm đã làm tròn
    longitude   DECIMAL(9,6) NOT NULL,
    radius_m    INT          NOT NULL,
    payload     MEDIUMTEXT   NULL,              -- JSON địa điểm theo nhóm; NULL = chưa tải được lần nào
    place_count INT          NOT NULL DEFAULT 0,
    source      VARCHAR(100) NULL,              -- máy chủ Overpass đã trả kết quả
    fetched_at  DATETIME     NULL,              -- lần tải thành công gần nhất
    failed_at   DATETIME     NULL,              -- lần tải lỗi gần nhất (NULL sau khi tải lại thành công)
    PRIMARY KEY (cache_key),
    KEY idx_map_place_cache_fetched (fetched_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS NTK_sp_tour_location;
DROP PROCEDURE IF EXISTS NTK_sp_tour_location_list;
DROP PROCEDURE IF EXISTS NTK_sp_admin_tour_location;
DROP PROCEDURE IF EXISTS NTK_sp_admin_tour_set_location;
DROP PROCEDURE IF EXISTS NTK_sp_place_cache_get;
DROP PROCEDURE IF EXISTS NTK_sp_place_cache_save;
DROP PROCEDURE IF EXISTS NTK_sp_place_cache_fail;

DELIMITER $$

-- ---------------------------------------------------------------------
-- NTK_sp_tour_location(p_tour_id)
--   Điểm khởi hành của một tour đang hiển thị: tour_id, title, pickup_mode, meeting_point,
--   latitude, longitude (NULL = tour chưa có vị trí). Không có dòng = tour không hiển thị.
-- ---------------------------------------------------------------------
CREATE PROCEDURE NTK_sp_tour_location(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id            AS tour_id,
        t.title,
        t.pickup_mode,
        t.meeting_point,
        t.latitude,
        t.longitude
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active';
END$$

-- ---------------------------------------------------------------------
-- NTK_sp_tour_location_list()
--   Các tour đang hiển thị đã có vị trí, cho trang /ban-do: tour_id, title, destination_name,
--   category_name, pickup_mode, meeting_point, duration_minutes, latitude, longitude,
--   cover_image_url, cover_alt_text (ảnh bìa = sort_order nhỏ nhất). Sắp xếp theo điểm đến, tên tour.
-- ---------------------------------------------------------------------
CREATE PROCEDURE NTK_sp_tour_location_list()
READS SQL DATA
BEGIN
    SELECT
        t.id                            AS tour_id,
        t.title,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name                          AS category_name,
        t.pickup_mode,
        t.meeting_point,
        t.duration_minutes,
        t.latitude,
        t.longitude,
        ci.url                          AS cover_image_url,
        ci.alt_text                     AS cover_alt_text
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    LEFT JOIN tour_images ci
           ON ci.id = (SELECT ti.id
                         FROM tour_images ti
                        WHERE ti.tour_id = t.id
                        ORDER BY ti.sort_order ASC, ti.id ASC
                        LIMIT 1)
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
      AND t.latitude IS NOT NULL
      AND t.longitude IS NOT NULL
    ORDER BY destination_name ASC, t.title ASC;
END$$

-- ---------------------------------------------------------------------
-- NTK_sp_admin_tour_location(p_tour_id)
--   Vị trí của một tour ở mọi trạng thái (trang quản trị): tour_id, title, approval_status,
--   destination_name, pickup_mode, meeting_point, latitude, longitude.
-- ---------------------------------------------------------------------
CREATE PROCEDURE NTK_sp_admin_tour_location(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                            AS tour_id,
        t.title,
        t.approval_status,
        COALESCE(d.name, t.destination) AS destination_name,
        t.pickup_mode,
        t.meeting_point,
        t.latitude,
        t.longitude
    FROM tours t
    LEFT JOIN destinations d ON d.id = t.destination_id
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci);
END$$

-- ---------------------------------------------------------------------
-- NTK_sp_admin_tour_set_location(p_actor_user_id, p_tour_id, p_latitude, p_longitude)
--   Đặt (cả hai tọa độ) hoặc xóa (cả hai NULL) vị trí điểm khởi hành.
--   Kết quả: result = 'ok' (đã đặt), 'cleared' (đã xóa), 'unchanged', 'forbidden', 'not_found',
--   'invalid' (field = 'latitude' / 'longitude' / 'location').
-- ---------------------------------------------------------------------
CREATE PROCEDURE NTK_sp_admin_tour_set_location(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_latitude      DECIMAL(9,6),
    IN p_longitude     DECIMAL(9,6)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_found INT          DEFAULT 0;
    DECLARE v_lat   DECIMAL(9,6) DEFAULT NULL;
    DECLARE v_lng   DECIMAL(9,6) DEFAULT NULL;
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

    -- Có cả hai hoặc không có cả hai; tọa độ trong khung Việt Nam.
    IF (p_latitude IS NULL) <> (p_longitude IS NULL) THEN
        SELECT 'invalid' AS result, 'location' AS field;
        LEAVE proc;
    END IF;
    IF p_latitude IS NOT NULL AND (p_latitude < 8 OR p_latitude > 23.5) THEN
        SELECT 'invalid' AS result, 'latitude' AS field;
        LEAVE proc;
    END IF;
    IF p_longitude IS NOT NULL AND (p_longitude < 102 OR p_longitude > 110) THEN
        SELECT 'invalid' AS result, 'longitude' AS field;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT COUNT(*), MAX(latitude), MAX(longitude) INTO v_found, v_lat, v_lng
      FROM tours
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_found = 0 THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field;
        LEAVE proc;
    END IF;

    IF (v_lat <=> p_latitude) AND (v_lng <=> p_longitude) THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field;
        LEAVE proc;
    END IF;

    UPDATE tours
       SET latitude = p_latitude, longitude = p_longitude
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id,
            IF(p_latitude IS NULL, 'location_clear', 'location_set'), NULL, NULL,
            IF(p_latitude IS NULL,
               CONCAT('Xóa vị trí điểm khởi hành (cũ: ', COALESCE(CONCAT(v_lat, ', ', v_lng), 'chưa có'), ')'),
               CONCAT('Vị trí điểm khởi hành: ', p_latitude, ', ', p_longitude,
                      ' (cũ: ', COALESCE(CONCAT(v_lat, ', ', v_lng), 'chưa có'), ')')),
            NOW());

    COMMIT;
    SELECT IF(p_latitude IS NULL, 'cleared', 'ok') AS result, NULL AS field;
END$$

-- ---------------------------------------------------------------------
-- NTK_sp_place_cache_get(p_cache_key)
--   Một dòng bộ nhớ đệm (hoặc không có dòng): payload, place_count, source, fetched_at, failed_at,
--   age_seconds (giây từ lần tải thành công, NULL nếu chưa có), failed_seconds (giây từ lần lỗi gần nhất).
-- ---------------------------------------------------------------------
CREATE PROCEDURE NTK_sp_place_cache_get(
    IN p_cache_key VARCHAR(64)
)
READS SQL DATA
BEGIN
    SELECT
        cache_key,
        latitude,
        longitude,
        radius_m,
        payload,
        place_count,
        source,
        fetched_at,
        failed_at,
        TIMESTAMPDIFF(SECOND, fetched_at, NOW()) AS age_seconds,
        TIMESTAMPDIFF(SECOND, failed_at, NOW())  AS failed_seconds
    FROM map_place_cache
    WHERE cache_key = (p_cache_key COLLATE utf8mb4_unicode_ci);
END$$

-- ---------------------------------------------------------------------
-- NTK_sp_place_cache_save(p_cache_key, p_latitude, p_longitude, p_radius_m, p_payload, p_place_count, p_source)
--   Lưu kết quả tải thành công (ghi đè kết quả cũ), fetched_at = NOW(), xóa failed_at.
-- ---------------------------------------------------------------------
CREATE PROCEDURE NTK_sp_place_cache_save(
    IN p_cache_key   VARCHAR(64),
    IN p_latitude    DECIMAL(9,6),
    IN p_longitude   DECIMAL(9,6),
    IN p_radius_m    INT,
    IN p_payload     MEDIUMTEXT,
    IN p_place_count INT,
    IN p_source      VARCHAR(100)
)
MODIFIES SQL DATA
BEGIN
    INSERT INTO map_place_cache (cache_key, latitude, longitude, radius_m, payload, place_count, source, fetched_at, failed_at)
    VALUES (p_cache_key, p_latitude, p_longitude, p_radius_m, p_payload, COALESCE(p_place_count, 0), p_source, NOW(), NULL)
    ON DUPLICATE KEY UPDATE
        payload     = VALUES(payload),
        place_count = VALUES(place_count),
        source      = VALUES(source),
        fetched_at  = NOW(),
        failed_at   = NULL;
END$$

-- ---------------------------------------------------------------------
-- NTK_sp_place_cache_fail(p_cache_key, p_latitude, p_longitude, p_radius_m)
--   Ghi lần tải lỗi (failed_at = NOW()); giữ nguyên kết quả cũ nếu có.
-- ---------------------------------------------------------------------
CREATE PROCEDURE NTK_sp_place_cache_fail(
    IN p_cache_key VARCHAR(64),
    IN p_latitude  DECIMAL(9,6),
    IN p_longitude DECIMAL(9,6),
    IN p_radius_m  INT
)
MODIFIES SQL DATA
BEGIN
    INSERT INTO map_place_cache (cache_key, latitude, longitude, radius_m, payload, place_count, source, fetched_at, failed_at)
    VALUES (p_cache_key, p_latitude, p_longitude, p_radius_m, NULL, 0, NULL, NULL, NOW())
    ON DUPLICATE KEY UPDATE failed_at = NOW();
END$$

DELIMITER ;
