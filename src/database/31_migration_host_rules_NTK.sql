-- =====================================================================
-- LocalTour v0.6 - 31_migration_host_rules_NTK.sql
-- Mục đích  : Cột mới cho quy tắc của khu đơn vị tổ chức (Sprint 6):
--   1. providers.bank_verified_at / bank_verified_by : dấu "đã xác minh" trên tài khoản nhận tiền
--        đơn vị đang khai. NULL = chưa xác minh (tài khoản mới khai hoặc vừa đổi). Quản trị viên
--        kiểm tra ngoài hệ thống rồi bấm "Xác minh"; chưa xác minh thì không ghi nhận được khoản
--        chi trả (file 30). Tài khoản đã khai trước file này bắt đầu ở trạng thái chưa xác minh.
--   2. tours.revision_of : "bản sửa" của tour đã duyệt (file 32). Đơn vị không sửa trực tiếp
--        tour đang hiển thị: hệ thống chép tour thành một dòng tours mới (approval_status
--        'draft', revision_of = mã tour gốc), đơn vị sửa trên dòng đó rồi gửi duyệt. Tour gốc
--        giữ nguyên cho khách cho tới khi quản trị viên duyệt bản sửa; lúc đó nội dung bản sửa
--        được chép vào tour gốc và dòng bản sửa bị xóa. NULL = tour thường.
--        UNIQUE: mỗi tour tối đa một bản sửa đang mở. Bản sửa không bao giờ ở trạng thái
--        'approved' nên không hiện ở trang khách.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Chạy sau  : 01 -> 30. Chạy lại được (ADD COLUMN IF NOT EXISTS, ADD UNIQUE KEY IF NOT EXISTS,
--             khóa ngoại kiểm tra trong information_schema trước khi thêm).
-- =====================================================================

SET NAMES utf8mb4;

ALTER TABLE providers
    ADD COLUMN IF NOT EXISTS bank_verified_at DATETIME NULL,
    ADD COLUMN IF NOT EXISTS bank_verified_by CHAR(36) NULL;

ALTER TABLE tours
    ADD COLUMN IF NOT EXISTS revision_of CHAR(36) NULL;

ALTER TABLE tours
    ADD UNIQUE KEY IF NOT EXISTS uq_tours_revision_of (revision_of);

-- Khóa ngoại đã có thì MariaDB báo lỗi 1005 (không phải "trùng tên"): kiểm tra trước (như file 16).
DROP PROCEDURE IF EXISTS NTK_sp_migrate_host_rules;

DELIMITER $$
CREATE PROCEDURE NTK_sp_migrate_host_rules()
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
                    WHERE CONSTRAINT_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'tours'
                      AND CONSTRAINT_NAME = 'fk_tours_revision_of') THEN
        ALTER TABLE tours
            ADD CONSTRAINT fk_tours_revision_of FOREIGN KEY (revision_of)
                REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
END$$
DELIMITER ;

CALL NTK_sp_migrate_host_rules();
DROP PROCEDURE IF EXISTS NTK_sp_migrate_host_rules;
