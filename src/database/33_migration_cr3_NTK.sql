-- =====================================================================
-- LocalTour v0.7 - 33_migration_cr3_NTK.sql
-- Mục đích  : Bảng và cột mới cho các chức năng của CR3 (tương tác với tour, đánh giá, tài khoản):
--   1. tour_likes      : lượt "Thích" của tài khoản khách hàng trên tour (mỗi tài khoản – tour một dòng).
--   2. tour_comments   : bình luận của tài khoản khách hàng trên trang tour. status 'visible' = đang
--        hiển thị; 'hidden' = quản trị viên đã ẩn (kèm người ẩn, thời điểm, lý do). Người viết tự xóa
--        bình luận của mình (xóa hẳn dòng). Nội dung 1–1000 ký tự (kiểm tra trong procedure).
--   3. reviews         : thêm thời điểm gửi và thông tin kiểm duyệt (người duyệt, thời điểm, ghi chú /
--        lý do từ chối). Đánh giá đã có trong dữ liệu mẫu giữ nguyên trạng thái; created_at của các
--        dòng cũ = thời điểm chạy file này.
--   4. users.avatar_url : ảnh đại diện (đường dẫn tương đối từ public/assets/, vd.
--        'uploads/avatars/<tên ngẫu nhiên>.jpg'); NULL = chưa có ảnh, giao diện hiện chữ cái đầu tên.
--   Bảng favorite_tours (Lưu tour) đã có từ 01_schema.sql, không đổi.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Chạy sau  : 01 -> 32. Chạy lại được (CREATE TABLE IF NOT EXISTS, ADD COLUMN IF NOT EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS tour_likes (
    id         CHAR(36)  NOT NULL,
    user_id    CHAR(36)  NOT NULL,
    tour_id    CHAR(36)  NOT NULL,
    created_at DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_tour_likes_user_tour (user_id, tour_id),
    KEY idx_tour_likes_tour (tour_id),
    CONSTRAINT fk_tour_likes_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tour_likes_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tour_comments (
    id            CHAR(36)      NOT NULL,
    tour_id       CHAR(36)      NOT NULL,
    user_id       CHAR(36)      NOT NULL,
    content       TEXT          NOT NULL,
    status        ENUM('visible','hidden') NOT NULL DEFAULT 'visible',
    hidden_by     CHAR(36)      NULL,
    hidden_at     DATETIME      NULL,
    hidden_reason VARCHAR(255)  NULL,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_tour_comments_tour (tour_id, status, created_at),
    KEY idx_tour_comments_user (user_id),
    KEY idx_tour_comments_status (status, created_at),
    CONSTRAINT fk_tour_comments_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tour_comments_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tour_comments_hidden_by FOREIGN KEY (hidden_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE reviews
    ADD COLUMN IF NOT EXISTS created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS moderated_by    CHAR(36)     NULL,
    ADD COLUMN IF NOT EXISTS moderated_at    DATETIME     NULL,
    ADD COLUMN IF NOT EXISTS moderation_note VARCHAR(255) NULL;

ALTER TABLE reviews
    ADD KEY IF NOT EXISTS idx_reviews_status_created (moderation_status, created_at);

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(255) NULL;

-- Khóa ngoại đã có thì MariaDB báo lỗi 1005: kiểm tra trong information_schema trước (như file 31).
DROP PROCEDURE IF EXISTS NTK_sp_migrate_cr3;

DELIMITER $$
CREATE PROCEDURE NTK_sp_migrate_cr3()
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
                    WHERE CONSTRAINT_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'reviews'
                      AND CONSTRAINT_NAME = 'fk_reviews_moderated_by') THEN
        ALTER TABLE reviews
            ADD CONSTRAINT fk_reviews_moderated_by FOREIGN KEY (moderated_by)
                REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
END$$
DELIMITER ;

CALL NTK_sp_migrate_cr3();
DROP PROCEDURE IF EXISTS NTK_sp_migrate_cr3;
