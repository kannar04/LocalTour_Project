-- =====================================================================
-- LocalTour v0.4 - 16_migration_sprint5_LTP.sql
-- Mục đích  : Bổ sung cấu trúc dữ liệu cho Sprint 5 (06/11 - 12/11). Không xóa bảng,
--             không mất dữ liệu đang có.
--   1. tour_packages (US06-S5-01, FR-07): gói của tour, phân theo phương tiện hoặc tuyến
--      điểm. Mỗi gói có tên, mô tả và giá vé riêng (người lớn, trẻ em); lịch khởi hành và
--      lịch trình chính dùng chung với tour, điểm khác ghi trong mô tả gói.
--      child_price_vnd NULL = gói không bán vé trẻ em. Gói ngừng bán (active = FALSE)
--      không xóa để các đơn cũ vẫn đọc được tên gói.
--   2. bookings.package_id, bookings.package_name: gói khách chọn khi đặt (NULL = tour
--      không có gói). Tên gói được chụp lại lúc đặt, đổi tên gói sau không đổi đơn cũ.
--   3. booking_change_requests (US14-S5-01 -> 03, FR-12): yêu cầu đổi ngày / hủy tour của
--      khách và kết quả xử lý thủ công của quản trị viên. Chụp lại chính sách hủy lúc gửi
--      (phiên bản, số giờ hủy miễn phí, phần trăm hoàn) và số tiền dự kiến hoàn; chưa tự
--      động hoàn tiền: khoản hoàn (nếu có) được ghi vào refunds để xử lý tay.
--   4. tours.approval_status thêm 'archived' (US07-S5-01, FR-13): tour đã có đơn không xóa
--      hẳn được thì ngừng hiển thị, dữ liệu đơn cũ giữ nguyên.
--   5. Dữ liệu mẫu: 3 gói cho tour "Phố cổ theo cách của bạn".
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 5
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01 -> 15. Chạy lại được: bảng / cột / khóa đã có thì bỏ qua.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. tour_packages
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tour_packages (
    id              CHAR(36)      NOT NULL,
    tour_id         CHAR(36)      NOT NULL,
    name            VARCHAR(100)  NOT NULL,
    description     VARCHAR(500)  NULL,
    adult_price_vnd BIGINT        NOT NULL,
    child_price_vnd BIGINT        NULL,          -- NULL = gói không bán vé trẻ em
    active          BOOLEAN       NOT NULL DEFAULT TRUE,
    sort_order      INT           NOT NULL DEFAULT 0,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_tour_packages_name (tour_id, name),
    KEY idx_tour_packages_tour (tour_id, active, sort_order),
    CONSTRAINT fk_tour_packages_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. Cột và khóa mới của bookings. ALTER TABLE chạy trong procedure tạm để bỏ qua lỗi
--    "đã có" (1060 cột trùng tên, 1061 khóa trùng tên) khi chạy lại file; khóa ngoại
--    kiểm tra trong information_schema trước khi thêm.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_migrate_sprint5;

DELIMITER $$
CREATE PROCEDURE LTP_sp_migrate_sprint5()
MODIFIES SQL DATA
BEGIN
    DECLARE v_skipped INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR 1060, 1061 SET v_skipped = v_skipped + 1;

    ALTER TABLE bookings
        ADD COLUMN package_id CHAR(36) NULL AFTER schedule_id;
    ALTER TABLE bookings
        ADD COLUMN package_name VARCHAR(100) NULL AFTER package_id;
    ALTER TABLE bookings
        ADD KEY idx_bookings_package (package_id);
    -- Khóa ngoại đã có thì MariaDB báo lỗi 1005 (không phải "trùng tên"): kiểm tra trước.
    IF NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
                    WHERE CONSTRAINT_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'bookings'
                      AND CONSTRAINT_NAME = 'fk_bookings_package') THEN
        ALTER TABLE bookings
            ADD CONSTRAINT fk_bookings_package FOREIGN KEY (package_id)
                REFERENCES tour_packages (id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
END$$
DELIMITER ;

CALL LTP_sp_migrate_sprint5();
DROP PROCEDURE IF EXISTS LTP_sp_migrate_sprint5;

-- ---------------------------------------------------------------------
-- 3. booking_change_requests
--   type   : 'cancel' (hủy tour) | 'change_date' (đổi sang lịch khác của cùng tour,
--            requested_schedule_id = lịch mới).
--   status : 'pending' (chờ xử lý) -> 'approved' (đã đồng ý) | 'rejected' (từ chối).
--            Mỗi đơn chỉ có một yêu cầu 'pending' tại một thời điểm.
--   in_free_window : 1 = gửi trước hạn hủy miễn phí (giờ khởi hành - free_before_hours).
--   paid_vnd       : tiền khách đã thanh toán (payments 'paid') lúc gửi yêu cầu.
--   estimated_refund_vnd : số tiền dự kiến hoàn theo chính sách (chỉ với 'cancel').
--   refund_vnd     : số tiền quản trị viên ghi nhận sẽ hoàn khi đồng ý hủy (NULL = chưa đồng ý hủy
--                    hoặc yêu cầu đổi ngày; 0 = đồng ý hủy nhưng không hoàn tiền).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_change_requests (
    id                    CHAR(36)      NOT NULL,
    booking_id            CHAR(36)      NOT NULL,
    user_id               CHAR(36)      NOT NULL,
    type                  ENUM('cancel','change_date') NOT NULL,
    requested_schedule_id CHAR(36)      NULL,
    reason                VARCHAR(500)  NOT NULL,
    status                ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    booking_status        VARCHAR(30)   NOT NULL,      -- trạng thái đơn lúc gửi yêu cầu
    policy_version        INT           NOT NULL DEFAULT 0,
    free_before_hours     INT           NULL,
    refund_percent        INT           NULL,
    in_free_window        BOOLEAN       NOT NULL DEFAULT FALSE,
    paid_vnd              BIGINT        NOT NULL DEFAULT 0,
    estimated_refund_vnd  BIGINT        NOT NULL DEFAULT 0,
    refund_vnd            BIGINT        NULL,
    result_note           VARCHAR(500)  NULL,
    handled_by            CHAR(36)      NULL,
    handled_at            DATETIME      NULL,
    created_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_change_requests_booking (booking_id, created_at),
    KEY idx_change_requests_status (status, created_at),
    KEY idx_change_requests_user (user_id),
    KEY idx_change_requests_schedule (requested_schedule_id),
    KEY idx_change_requests_handler (handled_by),
    CONSTRAINT fk_change_requests_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_change_requests_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_change_requests_schedule FOREIGN KEY (requested_schedule_id)
        REFERENCES schedules (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_change_requests_handler FOREIGN KEY (handled_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4. Tour ngừng hiển thị. MODIFY giữ nguyên giá trị đang có, chạy lại không đổi gì.
-- ---------------------------------------------------------------------
ALTER TABLE tours
    MODIFY COLUMN approval_status ENUM('draft','pending','approved','rejected','archived')
        NOT NULL DEFAULT 'draft';

-- ---------------------------------------------------------------------
-- 5. Dữ liệu mẫu: tour riêng "Phố cổ theo cách của bạn" chia gói theo tuyến điểm.
--    Mã cố định, chỉ thêm khi chưa có (chạy lại file không thêm trùng).
-- ---------------------------------------------------------------------
INSERT INTO tour_packages (id, tour_id, name, description, adult_price_vnd, child_price_vnd, active, sort_order, created_at)
SELECT x.id, x.tour_id, x.name, x.description, x.adult_price_vnd, x.child_price_vnd, TRUE, x.sort_order, NOW()
  FROM (SELECT 'f5000000-0000-4000-8000-000000000001' AS id,
               'c0000000-0000-4000-8000-000000000003' AS tour_id,
               'Kiến trúc và phố nghề' AS name,
               'Nhà ống, nhà cổ Mã Mây và các phố Hàng Bạc, Hàng Mã, Hàng Thiếc. Đi bộ, cuối tuyến ngồi xích lô 20 phút quanh hồ Hoàn Kiếm.' AS description,
               900000 AS adult_price_vnd, NULL AS child_price_vnd, 1 AS sort_order
        UNION ALL
        SELECT 'f5000000-0000-4000-8000-000000000002',
               'c0000000-0000-4000-8000-000000000003',
               'Đền chùa và tín ngưỡng',
               'Đền Bạch Mã, đình Kim Ngân, chùa Cầu Đông và một hội quán người Hoa. Đi bộ, có xích lô 20 phút.',
               950000, NULL, 2
        UNION ALL
        SELECT 'f5000000-0000-4000-8000-000000000003',
               'c0000000-0000-4000-8000-000000000003',
               'Góc ảnh phố cổ',
               'Người dẫn kiêm chụp ảnh, khoảng 40 ảnh đã chỉnh gửi sau 3 ngày. Tuyến cầu Long Biên, chợ Đồng Xuân và phố bích họa Phùng Hưng.',
               1200000, NULL, 3) x
 WHERE EXISTS (SELECT 1 FROM tours t WHERE t.id = x.tour_id)
   AND NOT EXISTS (SELECT 1 FROM tour_packages tp WHERE tp.id = x.id);
