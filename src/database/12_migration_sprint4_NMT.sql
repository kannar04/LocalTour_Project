-- =====================================================================
-- LocalTour v0.3 - 12_migration_sprint4_NMT.sql
-- Mục đích  : Bổ sung cấu trúc dữ liệu cho Sprint 4 (kế hoạch Sprint 4, 30/10 - 05/11).
--             Không xóa bảng, không mất dữ liệu đang có.
--   1. booking_extras (4.3.2.3): phụ thu / hoạt động tùy chọn khách chọn khi đặt tour.
--      Chụp lại tên, loại, đơn vị và đơn giá lúc đặt (giá tour_extras đổi sau không làm
--      đổi đơn cũ). Mỗi khoản chỉ một dòng trong một đơn: UNIQUE (booking_id, extra_id).
--   2. booking_events (4.3.3.2, FR-11, NFR-09): lịch sử của đơn do khách, hệ thống hoặc
--      VNPay tạo ra (tạo đơn, báo chuyển khoản, VNPay trả kết quả, tự hủy khi quá hạn).
--      Thao tác của quản trị viên vẫn ghi ở admin_logs; trang đơn đọc cả hai.
--   3. bookings.voucher_code, voucher_issued_at (4.5.4.2): mã voucher cấp khi thanh toán đã
--      được xác minh (VNPay thành công hoặc quản trị viên đối chiếu khoản VietQR).
--      Chỉ mục (status, hold_expires_at) cho việc tự hủy đơn quá hạn giữ chỗ (4.5.4.1).
--   4. payments (4.5.1 - 4.5.3):
--      reference      : mã giao dịch LocalTour gửi cổng thanh toán (vnp_TxnRef của VNPay,
--                       nội dung chuyển khoản của VietQR), vd. LT518204P1. UNIQUE.
--      created_at     : lúc tạo khoản thanh toán.
--      submitted_at   : lúc khách báo "đã chuyển khoản" (VietQR).
--      response_code  : mã kết quả VNPay (vnp_ResponseCode), '00' = thành công.
--      bank_code      : ngân hàng khách dùng ở VNPay (vnp_BankCode).
--      note           : ghi chú của quản trị viên khi đối chiếu (vd. lý do không khớp).
-- Phụ trách : Nguyễn Minh Thức (NMT) - Sprint 4
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01 -> 11. Chạy lại được: bảng / cột / khóa đã có thì bỏ qua.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. booking_extras
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_extras (
    id             CHAR(36)      NOT NULL,
    booking_id     CHAR(36)      NOT NULL,
    extra_id       CHAR(36)      NOT NULL,
    kind           ENUM('surcharge','optional') NOT NULL,   -- chụp từ tour_extras.kind
    name           VARCHAR(200)  NOT NULL,                  -- chụp từ tour_extras.name
    price_unit     VARCHAR(50)   NULL,                      -- chụp từ tour_extras.price_unit
    quantity       INT           NOT NULL,                  -- theo người: = số khách; còn lại: 1
    unit_price_vnd BIGINT        NOT NULL,
    line_total_vnd BIGINT        NOT NULL,
    sort_order     INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_booking_extras_extra (booking_id, extra_id),
    KEY idx_booking_extras_extra (extra_id),
    CONSTRAINT fk_booking_extras_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_booking_extras_extra FOREIGN KEY (extra_id)
        REFERENCES tour_extras (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. booking_events
--   actor: 'customer' (khách, actor_user_id = tài khoản khách), 'system' (tự hủy quá hạn),
--          'vnpay' (kết quả VNPay). action: created, transfer_submitted, vnpay_paid,
--          vnpay_failed, hold_expired, voucher_issued, refund_requested.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_events (
    id            CHAR(36)      NOT NULL,
    booking_id    CHAR(36)      NOT NULL,
    actor         ENUM('customer','system','vnpay') NOT NULL,
    actor_user_id CHAR(36)      NULL,
    action        VARCHAR(50)   NOT NULL,
    from_status   VARCHAR(30)   NULL,
    to_status     VARCHAR(30)   NULL,
    note          VARCHAR(255)  NULL,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_booking_events_booking (booking_id, created_at),
    KEY idx_booking_events_actor (actor_user_id),
    CONSTRAINT fk_booking_events_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_booking_events_actor FOREIGN KEY (actor_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3 + 4. Cột và khóa mới. ALTER TABLE chạy trong procedure tạm để bỏ qua lỗi
--        "đã có" (1060 cột trùng tên, 1061 khóa trùng tên) khi chạy lại file.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_migrate_sprint4;

DELIMITER $$
CREATE PROCEDURE NMT_sp_migrate_sprint4()
MODIFIES SQL DATA
BEGIN
    DECLARE v_skipped INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR 1060, 1061 SET v_skipped = v_skipped + 1;

    ALTER TABLE bookings
        ADD COLUMN voucher_code VARCHAR(20) NULL AFTER hold_expires_at;
    ALTER TABLE bookings
        ADD COLUMN voucher_issued_at DATETIME NULL AFTER voucher_code;
    ALTER TABLE bookings
        ADD UNIQUE KEY uq_bookings_voucher (voucher_code);
    ALTER TABLE bookings
        ADD KEY idx_bookings_status_hold (status, hold_expires_at);

    ALTER TABLE payments
        ADD COLUMN reference VARCHAR(32) NULL AFTER method;
    ALTER TABLE payments
        ADD UNIQUE KEY uq_payments_reference (reference);
    ALTER TABLE payments
        ADD COLUMN created_at DATETIME NULL AFTER paid_at;
    ALTER TABLE payments
        ADD COLUMN submitted_at DATETIME NULL AFTER created_at;
    ALTER TABLE payments
        ADD COLUMN response_code VARCHAR(10) NULL AFTER submitted_at;
    ALTER TABLE payments
        ADD COLUMN bank_code VARCHAR(20) NULL AFTER response_code;
    ALTER TABLE payments
        ADD COLUMN note VARCHAR(255) NULL AFTER bank_code;
END$$
DELIMITER ;

CALL NMT_sp_migrate_sprint4();
DROP PROCEDURE IF EXISTS NMT_sp_migrate_sprint4;

-- Đơn đã xác nhận / hoàn thành trong dữ liệu mẫu đã thanh toán: cấp voucher cho đủ dữ liệu
-- (mã cố định theo mã đơn để chạy lại file không đổi mã).
UPDATE bookings
   SET voucher_code = CONCAT('LTV', SUBSTRING(code, 3), '0000'),
       voucher_issued_at = COALESCE((SELECT MAX(p.paid_at) FROM payments p
                                      WHERE p.booking_id = bookings.id AND p.status = 'paid'), created_at)
 WHERE status IN ('confirmed', 'completed')
   AND voucher_code IS NULL
   AND EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = bookings.id AND p.status = 'paid');

-- Khoản thanh toán mẫu chưa có lúc tạo: lấy lúc thanh toán, không có thì lúc đặt đơn.
UPDATE payments
   SET created_at = COALESCE(paid_at, (SELECT b.created_at FROM bookings b WHERE b.id = payments.booking_id))
 WHERE created_at IS NULL;

-- Khoản VietQR mẫu đang chờ đối chiếu: nội dung chuyển khoản = mã đơn + P1, như khoản mới.
UPDATE payments p
  JOIN bookings b ON b.id = p.booking_id
   SET p.reference = CONCAT(b.code, 'P1')
 WHERE p.method = 'vietqr'
   AND p.status = 'awaiting_reconciliation'
   AND p.reference IS NULL;
