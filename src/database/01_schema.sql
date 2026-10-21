-- =====================================================================
-- LocalTour v0.1 - 01_schema.sql
-- Mục đích  : Tạo lược đồ CSDL db_localtour cho Sprint 3: điểm đến, danh mục,
--             đơn vị tổ chức, tour và các bảng chi tiết của tour
--             (ảnh, lịch trình, chi phí bao gồm, lịch khởi hành, đánh giá).
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.1.2
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8; InnoDB; utf8mb4_unicode_ci.
-- Chạy lại  : Được. File xóa toàn bộ bảng cũ (theo thứ tự ngược khóa ngoại)
--             rồi tạo lại, nên MỌI DỮ LIỆU CŨ SẼ MẤT.
-- Lưu ý     : File này không có CREATE DATABASE / USE. Chọn database
--             db_localtour trước khi chạy (file gộp db_localtour.sql đã có sẵn).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Xóa bảng cũ: bảng con trước, bảng cha sau.
--    Tạm tắt kiểm tra khóa ngoại để xóa được cả khi còn bảng khác tham chiếu.
-- ---------------------------------------------------------------------
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS tour_schedules;
DROP TABLE IF EXISTS tour_inclusions;
DROP TABLE IF EXISTS tour_itinerary_items;
DROP TABLE IF EXISTS tour_images;
DROP TABLE IF EXISTS tours;
DROP TABLE IF EXISTS providers;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS destinations;

SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;

-- ---------------------------------------------------------------------
-- 2. Bảng danh mục
-- ---------------------------------------------------------------------

-- Điểm đến (Hà Nội, Đà Nẵng, ...). sort_order quyết định thứ tự hiển thị.
CREATE TABLE destinations (
    destination_id INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    name           VARCHAR(100)  NOT NULL,
    slug           VARCHAR(100)  NOT NULL,
    sort_order     SMALLINT      NOT NULL DEFAULT 0,
    PRIMARY KEY (destination_id),
    UNIQUE KEY uq_destinations_name (name),
    UNIQUE KEY uq_destinations_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Loại tour (ẩm thực, văn hóa - lịch sử, thiên nhiên, tour đêm).
CREATE TABLE categories (
    category_id INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100)  NOT NULL,
    slug        VARCHAR(100)  NOT NULL,
    PRIMARY KEY (category_id),
    UNIQUE KEY uq_categories_name (name),
    UNIQUE KEY uq_categories_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Đơn vị tổ chức tour (người dẫn địa phương / công ty nhỏ).
-- is_active = 0: ngừng hợp tác, toàn bộ tour của đơn vị bị ẩn khỏi website.
CREATE TABLE providers (
    provider_id INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    name        VARCHAR(150)  NOT NULL,
    description VARCHAR(255)  NULL,
    phone       VARCHAR(20)   NULL,
    email       VARCHAR(150)  NULL,
    is_verified TINYINT(1)    NOT NULL DEFAULT 0,
    is_active   TINYINT(1)    NOT NULL DEFAULT 1,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (provider_id),
    KEY idx_providers_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3. Bảng tour (bảng trung tâm)
--    price_per_person: VND, số nguyên. status = 'hidden': không bao giờ hiển thị.
-- ---------------------------------------------------------------------
CREATE TABLE tours (
    tour_id             INT UNSIGNED       NOT NULL AUTO_INCREMENT,
    provider_id         INT UNSIGNED       NOT NULL,
    destination_id      INT UNSIGNED       NOT NULL,
    category_id         INT UNSIGNED       NOT NULL,
    title               VARCHAR(200)       NOT NULL,
    summary             VARCHAR(300)       NOT NULL,
    description         TEXT               NOT NULL,
    duration_hours      DECIMAL(4,1)       NOT NULL,
    max_group_size      SMALLINT UNSIGNED  NOT NULL,
    languages           VARCHAR(100)       NOT NULL,
    price_per_person    INT UNSIGNED       NOT NULL,
    price_note          VARCHAR(150)       NULL,
    meeting_point       VARCHAR(255)       NOT NULL,
    meeting_note        VARCHAR(255)       NULL,
    transport_note      VARCHAR(255)       NULL,
    cancellation_policy VARCHAR(255)       NOT NULL,
    status              ENUM('published','hidden') NOT NULL DEFAULT 'published',
    created_at          DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tour_id),
    KEY idx_tours_status_destination (status, destination_id),
    KEY idx_tours_destination (destination_id),
    KEY idx_tours_provider (provider_id),
    KEY idx_tours_category (category_id),
    CONSTRAINT fk_tours_provider FOREIGN KEY (provider_id)
        REFERENCES providers (provider_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tours_destination FOREIGN KEY (destination_id)
        REFERENCES destinations (destination_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tours_category FOREIGN KEY (category_id)
        REFERENCES categories (category_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4. Bảng chi tiết của tour: xóa tour thì xóa kèm (ON DELETE CASCADE).
-- ---------------------------------------------------------------------

-- Ảnh tour. image_path tính từ thư mục public/, ví dụ 'assets/img/tours/hanoi-1.svg'.
-- NULL = chưa có ảnh, giao diện hiện khung xám kèm caption.
CREATE TABLE tour_images (
    image_id   INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    tour_id    INT UNSIGNED      NOT NULL,
    image_path VARCHAR(255)      NULL,
    caption    VARCHAR(150)      NOT NULL,
    sort_order TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    PRIMARY KEY (image_id),
    KEY idx_tour_images_tour_sort (tour_id, sort_order),
    CONSTRAINT fk_tour_images_tour FOREIGN KEY (tour_id)
        REFERENCES tours (tour_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Lịch trình trong ngày. start_time NULL = tour linh hoạt, không cố định giờ.
CREATE TABLE tour_itinerary_items (
    item_id     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    tour_id     INT UNSIGNED      NOT NULL,
    start_time  TIME              NULL,
    description VARCHAR(255)      NOT NULL,
    sort_order  TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    PRIMARY KEY (item_id),
    KEY idx_itinerary_tour_sort (tour_id, sort_order),
    CONSTRAINT fk_itinerary_tour FOREIGN KEY (tour_id)
        REFERENCES tours (tour_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chi phí bao gồm (is_included = 1) / không gồm (is_included = 0).
CREATE TABLE tour_inclusions (
    inclusion_id INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    tour_id      INT UNSIGNED      NOT NULL,
    item_text    VARCHAR(150)      NOT NULL,
    is_included  TINYINT(1)        NOT NULL DEFAULT 1,
    sort_order   TINYINT UNSIGNED  NOT NULL DEFAULT 0,
    PRIMARY KEY (inclusion_id),
    KEY idx_inclusions_tour_sort (tour_id, sort_order),
    CONSTRAINT fk_inclusions_tour FOREIGN KEY (tour_id)
        REFERENCES tours (tour_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Lịch khởi hành. Còn chỗ = seats_total - seats_booked.
-- Mỗi tour không có hai lịch trùng ngày và giờ bắt đầu.
CREATE TABLE tour_schedules (
    schedule_id    INT UNSIGNED       NOT NULL AUTO_INCREMENT,
    tour_id        INT UNSIGNED       NOT NULL,
    departure_date DATE               NOT NULL,
    start_time     TIME               NOT NULL,
    seats_total    SMALLINT UNSIGNED  NOT NULL,
    seats_booked   SMALLINT UNSIGNED  NOT NULL DEFAULT 0,
    status         ENUM('open','full','cancelled') NOT NULL DEFAULT 'open',
    PRIMARY KEY (schedule_id),
    UNIQUE KEY uq_schedules_tour_date_time (tour_id, departure_date, start_time),
    KEY idx_schedules_status_date (status, departure_date),
    CONSTRAINT fk_schedules_tour FOREIGN KEY (tour_id)
        REFERENCES tours (tour_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Đánh giá của khách. rating từ 1 đến 5 (kiểm tra ở tầng ứng dụng khi có chức năng gửi đánh giá).
CREATE TABLE reviews (
    review_id     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    tour_id       INT UNSIGNED      NOT NULL,
    reviewer_name VARCHAR(100)      NOT NULL,
    rating        TINYINT UNSIGNED  NOT NULL,
    comment       VARCHAR(500)      NOT NULL,
    created_at    DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (review_id),
    KEY idx_reviews_tour_created (tour_id, created_at),
    CONSTRAINT fk_reviews_tour FOREIGN KEY (tour_id)
        REFERENCES tours (tour_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
