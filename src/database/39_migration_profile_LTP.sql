-- =====================================================================
-- LocalTour v0.7 - 39_migration_profile_LTP.sql
-- Mục đích  : Thông tin cá nhân thêm ở trang "Tài khoản" của khách hàng (CR3): 4 cột mới của bảng
--             users, đều không bắt buộc (NULL = chưa cập nhật):
--   1. citizen_id    : số căn cước công dân (CCCD), đúng 12 chữ số. Thông tin nhạy cảm: chỉ chủ tài
--        khoản xem ở trang "Tài khoản"; không hiện ở trang quản trị, không ghi vào nhật ký / thông báo lỗi.
--   2. date_of_birth : ngày sinh, từ 01/01/1900, không ở tương lai; ứng dụng yêu cầu đủ 10 tuổi.
--   3. gender        : giới tính 'male' (Nam) / 'female' (Nữ) / 'other' (Khác); NULL = không nêu.
--   4. address       : địa chỉ, tối đa 255 ký tự (đã bỏ khoảng trắng đầu / cuối).
--   Đọc / lưu bằng LTP_sp_account_get, LTP_sp_account_update_profile (37_procedures_LTP_account.sql).
-- Phụ trách : Lê Trung Phong (LTP)
-- Chạy sau  : 01 -> 38. Chạy lại được (ADD COLUMN IF NOT EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS citizen_id    VARCHAR(12)  NULL,
    ADD COLUMN IF NOT EXISTS date_of_birth DATE         NULL,
    ADD COLUMN IF NOT EXISTS gender        ENUM('male','female','other') NULL,
    ADD COLUMN IF NOT EXISTS address       VARCHAR(255) NULL;
