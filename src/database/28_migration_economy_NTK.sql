-- =====================================================================
-- LocalTour v0.6 - 28_migration_economy_NTK.sql
-- Mục đích  : Bảng và cột cho đặt tour không cần duyệt tay và cho dòng tiền sau tour
--             (phí dịch vụ của LocalTour, chi trả cho đơn vị tổ chức).
--   1. settings           : thông số vận hành quản trị viên chỉnh được (mỗi khóa một dòng).
--        commission_percent     = % phí dịch vụ LocalTour giữ lại trên số tiền thực thu (mặc định 10).
--        hold_minutes           = số phút giữ chỗ cho đơn "Chờ thanh toán" (mặc định 30).
--        booking_cutoff_minutes = ngừng nhận đặt trước giờ khởi hành bao nhiêu phút (mặc định 60).
--        vietqr_cutoff_hours    = còn dưới bấy nhiêu giờ tới giờ khởi hành thì không nhận chuyển
--                                 khoản VietQR, chỉ nhận cổng tự xác nhận (mặc định 24).
--        payouts_from           = mốc bắt đầu lập khoản chi trả, dạng 'YYYY-MM-DD HH:MM:SS' = thời
--                                 điểm file này chạy lần đầu (chạy lại giữ giá trị cũ). Chỉ lịch
--                                 kết thúc từ mốc này mới được lập khoản chi trả (file 30): lịch
--                                 cũ của database nâng cấp và dữ liệu mẫu không sinh khoản chi
--                                 trả. Không sửa ở trang "Thông số vận hành".
--   2. bookings.commission_rate : % phí dịch vụ chụp lại lúc đặt (đổi thông số sau này không
--        làm đổi đơn cũ). NULL = đơn tạo trước file này, tính theo thông số hiện tại.
--   3. providers.bank_name / bank_account_no / bank_account_name : tài khoản nhận chi trả
--        của đơn vị tổ chức (đơn vị tự khai ở cổng /host).
--   4. host_payouts       : mỗi lịch khởi hành đã kết thúc có tiền thực thu một khoản chi trả.
--        gross_vnd = tiền thực thu (đã trừ tiền hoàn), commission_vnd = phí dịch vụ,
--        net_vnd = gross_vnd - commission_vnd = số tiền chuyển cho đơn vị.
--        status: pending = Chờ chi trả, paid = Đã chi trả (quản trị viên chuyển khoản ngoài
--        hệ thống rồi ghi mã giao dịch). Tài khoản nhận được chụp lại lúc ghi "Đã chi trả".
--   5. host_payout_items  : từng đơn trong khoản chi trả (tiền thực thu, % phí, phí, thực nhận).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Chạy sau  : 01 -> 27. Chạy lại được (CREATE TABLE IF NOT EXISTS, ADD COLUMN IF NOT EXISTS,
--             INSERT IGNORE).
-- =====================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS settings (
    name       VARCHAR(50)   NOT NULL,
    value      VARCHAR(100)  NOT NULL,
    updated_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by CHAR(36)      NULL,
    PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO settings (name, value) VALUES
    ('commission_percent', '10'),
    ('hold_minutes', '30'),
    ('booking_cutoff_minutes', '60'),
    ('vietqr_cutoff_hours', '24');

-- Mốc bắt đầu lập khoản chi trả: thời điểm file này chạy lần đầu (INSERT IGNORE giữ giá trị cũ).
INSERT IGNORE INTO settings (name, value) VALUES
    ('payouts_from', DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s'));

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS commission_rate DECIMAL(5,2) NULL AFTER total_vnd;

ALTER TABLE providers
    ADD COLUMN IF NOT EXISTS bank_name         VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS bank_account_no   VARCHAR(30)  NULL,
    ADD COLUMN IF NOT EXISTS bank_account_name VARCHAR(100) NULL;

CREATE TABLE IF NOT EXISTS host_payouts (
    id                 CHAR(36)      NOT NULL,
    provider_id        CHAR(36)      NOT NULL,
    schedule_id        CHAR(36)      NOT NULL,
    booking_count      INT           NOT NULL,
    gross_vnd          BIGINT        NOT NULL,
    commission_vnd     BIGINT        NOT NULL,
    net_vnd            BIGINT        NOT NULL,
    status             ENUM('pending','paid') NOT NULL DEFAULT 'pending',
    bank_name          VARCHAR(100)  NULL,
    bank_account_no    VARCHAR(30)   NULL,
    bank_account_name  VARCHAR(100)  NULL,
    transfer_reference VARCHAR(100)  NULL,
    note               VARCHAR(255)  NULL,
    created_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at            DATETIME      NULL,
    paid_by            CHAR(36)      NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_host_payouts_schedule (schedule_id),
    KEY idx_host_payouts_provider_status (provider_id, status),
    KEY idx_host_payouts_status_created (status, created_at),
    CONSTRAINT fk_host_payouts_provider FOREIGN KEY (provider_id)
        REFERENCES providers (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_host_payouts_schedule FOREIGN KEY (schedule_id)
        REFERENCES schedules (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS host_payout_items (
    id              CHAR(36)      NOT NULL,
    payout_id       CHAR(36)      NOT NULL,
    booking_id      CHAR(36)      NOT NULL,
    kept_vnd        BIGINT        NOT NULL,
    commission_rate DECIMAL(5,2)  NOT NULL,
    commission_vnd  BIGINT        NOT NULL,
    net_vnd         BIGINT        NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_host_payout_items_booking (booking_id),
    KEY idx_host_payout_items_payout (payout_id),
    CONSTRAINT fk_host_payout_items_payout FOREIGN KEY (payout_id)
        REFERENCES host_payouts (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_host_payout_items_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
