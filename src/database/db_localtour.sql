-- File sinh tự động từ src/database/01..15, không sửa tay.
CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_localtour;
SET NAMES utf8mb4;
-- =====================================================================
-- LocalTour v0.1 - 01_schema.sql
-- Mục đích  : Tạo lược đồ CSDL db_localtour: lược đồ GỘP giữa ERD (trang 01 "Lõi đặt
--             tour" + trang 02 "Khám phá & vận hành") và bảng yêu cầu chức năng (FR
--             board), tổng 27 bảng. Mỗi bảng / cột thêm mới có ghi chú FR mà nó phục vụ.
--
-- ĐÃ BỎ 2 bảng của ERD: post_comments, post_interactions (nút Thích / Bình luận /
--   Chia sẻ trên giao diện chỉ hiện "Sắp có").
-- Các bảng thông báo, bài đăng tour, yêu thích, so sánh và các bảng danh mục/chi tiết
-- tour của thiết kế trước đã được triển khai lại theo khóa UUID của lược đồ hiện tại.
-- Bảng reviews được giữ lại vì trang danh sách và chi tiết hiển thị đánh giá.
--
-- Ba cặp bảng trùng chức năng, mỗi cặp chỉ đọc MỘT nguồn (tài liệu 01 mục 5):
--   * Lịch trình        : tour_itinerary_items (có giờ bắt đầu); itinerary_stops không dùng.
--   * Bao gồm / không bao gồm: tour_inclusions; tours.included_summary / excluded_summary
--                         không dùng.
--   * Lịch khởi hành    : schedules (ticket_types và bookings tham chiếu); tour_schedules
--                         không dùng.
--   Các bảng / cột "không dùng" vẫn giữ trong lược đồ và để trống.
--
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.1.2
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8; InnoDB; utf8mb4_unicode_ci.
-- Quy ước   : * Khóa chính của mọi bảng là id CHAR(36) = UUID dạng chữ
--               (không dùng AUTO_INCREMENT).
--             * Kiểu "timestamp" trong ERD được lưu bằng DATETIME: MariaDB 10.4 tự
--               gắn ON UPDATE CURRENT_TIMESTAMP cho cột TIMESTAMP NOT NULL đầu tiên
--               và TIMESTAMP chỉ chạy tới năm 2038; DATETIME giữ đúng giá trị ghi vào.
--             * Tiền: BIGINT, đơn vị VND (số nguyên, không có số lẻ).
--             * Cột NULL = "chưa cập nhật": giao diện hiện "Chưa cập nhật", không tự đoán.
--             * Khóa ngoại: ON DELETE RESTRICT ON UPDATE CASCADE (không xóa dây chuyền).
--             * Ràng buộc giá trị (vd. rating 1-5) kiểm tra ở tầng ứng dụng, không dùng CHECK.
--             * Khách chưa đăng nhập (chế độ khách) chỉ xem danh sách và chi tiết tour.
--               Muốn đặt tour phải đăng nhập tài khoản khách hàng: mỗi đơn đặt thuộc
--               đúng một tài khoản (bookings.user_id).
-- Chạy lại  : Được. File xóa toàn bộ bảng (kể cả các bảng đã bỏ và bảng của thiết kế
--             cũ) rồi tạo lại, nên MỌI DỮ LIỆU CŨ SẼ MẤT.
-- Lưu ý     : File này không có CREATE DATABASE / USE. Chọn database
--             db_localtour trước khi chạy (file gộp db_localtour.sql đã có sẵn).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Xóa bảng cũ: bảng con trước, bảng cha sau.
--    Tạm tắt kiểm tra khóa ngoại để xóa được cả khi còn bảng khác tham chiếu.
-- ---------------------------------------------------------------------
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- Lược đồ hiện tại có 27 bảng: 17 bảng dưới đây và 10 bảng ở hai nhóm "triển khai lại".
DROP TABLE IF EXISTS payment_events;
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS passengers;
DROP TABLE IF EXISTS booking_lines;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS ticket_types;
DROP TABLE IF EXISTS schedules;
DROP TABLE IF EXISTS cancellation_policies;
DROP TABLE IF EXISTS tour_extras;
DROP TABLE IF EXISTS tour_images;
DROP TABLE IF EXISTS itinerary_stops;
DROP TABLE IF EXISTS admin_logs;
DROP TABLE IF EXISTS tours;
DROP TABLE IF EXISTS providers;
DROP TABLE IF EXISTS users;

-- Các bảng chức năng được triển khai lại
DROP TABLE IF EXISTS comparison_tours;
DROP TABLE IF EXISTS comparisons;
DROP TABLE IF EXISTS tour_posts;
DROP TABLE IF EXISTS favorite_tours;
DROP TABLE IF EXISTS notifications;

-- Các bảng được triển khai lại từ thiết kế trước
DROP TABLE IF EXISTS tour_itinerary_items;
DROP TABLE IF EXISTS tour_inclusions;
DROP TABLE IF EXISTS tour_schedules;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS destinations;

-- Bảng đã bỏ khỏi ERD (lý do ở đầu file)
DROP TABLE IF EXISTS post_interactions;
DROP TABLE IF EXISTS post_comments;

SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;

-- ---------------------------------------------------------------------
-- 2. TÀI KHOẢN & NHÀ CUNG CẤP
-- ---------------------------------------------------------------------

-- NGƯỜI_DÙNG (FR-13, NFR-04): tài khoản khách hàng, nhân viên và nhà cung cấp.
-- role: admin = Quản trị viên, support = Nhân viên hỗ trợ khách hàng,
--       provider = tài khoản của nhà cung cấp, customer = tài khoản khách hàng.
--       Trang đăng ký chỉ tạo tài khoản customer; trang đăng nhập chỉ nhận customer.
-- email lưu chữ thường (ứng dụng chuẩn hóa trước khi ghi và khi tìm).
-- password_hash: chuỗi do password_hash() của PHP tạo (bcrypt), không bao giờ lưu mật
--       khẩu gốc. NULL = chưa đặt mật khẩu (tài khoản mẫu): không đăng nhập được.
-- status = 'locked': tài khoản bị khóa, không đăng nhập được; nếu là nhà cung cấp thì
--       mọi tour bị ẩn (FR-01).
CREATE TABLE users (
    id            CHAR(36)      NOT NULL,
    email         VARCHAR(150)  NOT NULL,
    password_hash VARCHAR(255)  NULL,
    name          VARCHAR(100)  NOT NULL,
    phone         VARCHAR(20)   NULL,
    role          ENUM('admin','support','provider','customer') NOT NULL,
    status        ENUM('active','locked')            NOT NULL DEFAULT 'active',
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- NHÀ_CUNG_CẤP (FR-13 đơn vị tổ chức): hồ sơ kinh doanh gắn với đúng 1 tài khoản
-- (quan hệ 1 - 0..1). Chỉ nhà cung cấp approval_status = 'approved' mới có tour
-- hiển thị (FR-01).
CREATE TABLE providers (
    id              CHAR(36)      NOT NULL,
    user_id         CHAR(36)      NOT NULL,
    business_name   VARCHAR(150)  NOT NULL,
    contact_phone   VARCHAR(20)   NOT NULL,
    approval_status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    approved_at     DATETIME      NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_providers_user (user_id),
    CONSTRAINT fk_providers_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3. DANH MỤC TOUR
-- ---------------------------------------------------------------------

-- ĐIỂM_ĐẾN (FR-06 lọc theo điểm đến): bộ lọc và thanh bên lấy từ bảng này, lọc tour theo
-- tours.destination_id. sort_order: thứ tự hiển thị (nhỏ trước).
CREATE TABLE destinations (
    id         CHAR(36)      NOT NULL,
    name       VARCHAR(100)  NOT NULL,
    slug       VARCHAR(100)  NOT NULL,
    sort_order INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_destinations_name (name),
    UNIQUE KEY uq_destinations_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- LOẠI_HÌNH (bộ lọc "Loại hình"): vd. Ẩm thực, Đi bộ khám phá. Lọc theo tours.category_id.
CREATE TABLE categories (
    id   CHAR(36)      NOT NULL,
    name VARCHAR(100)  NOT NULL,
    slug VARCHAR(100)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_categories_name (name),
    UNIQUE KEY uq_categories_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4. TOUR & NỘI DUNG TOUR
-- ---------------------------------------------------------------------

-- TOUR (FR-01 danh mục, FR-02 chi tiết, FR-06 tìm theo tên / điểm đến).
-- destination_id / category_id: điểm đến và loại hình (NULL = chưa cập nhật).
-- destination: tên điểm đến dạng chữ (vd. 'Hà Nội'), giữ để tương thích; giao diện ưu tiên
--   destinations.name, chỉ dùng cột này khi destination_id IS NULL.
-- language_codes: mã ngôn ngữ cách nhau bởi dấu phẩy (vd. 'vi,en').
-- pickup_mode = 'meeting_point': khách tự đến meeting_point;
--             = 'hotel_pickup' : đón tại khách sạn, meeting_point mô tả khu vực đón.
-- included_summary / excluded_summary: không dùng (để NULL); danh sách bao gồm / không
--   bao gồm nằm ở tour_inclusions.
-- Các cột thêm từ transport trở đi: NULL = chưa cập nhật.
-- Chỉ tour approval_status = 'approved' mới được hiển thị.
CREATE TABLE tours (
    id                  CHAR(36)      NOT NULL,
    provider_id         CHAR(36)      NOT NULL,
    destination_id      CHAR(36)      NULL,
    category_id         CHAR(36)      NULL,
    title               VARCHAR(200)  NOT NULL,
    description         TEXT          NOT NULL,
    destination         VARCHAR(100)  NOT NULL,
    duration_minutes    INT           NOT NULL,
    max_group_size      INT           NOT NULL,
    language_codes      VARCHAR(50)   NOT NULL,
    pickup_mode         ENUM('meeting_point','hotel_pickup') NOT NULL,
    meeting_point       VARCHAR(255)  NULL,
    included_summary    TEXT          NULL,          -- không dùng (nguồn: tour_inclusions)
    transport           VARCHAR(255)  NULL,          -- FR-02 phương tiện
    guide_info          VARCHAR(255)  NULL,          -- FR-02 hướng dẫn viên
    dropoff_point       VARCHAR(255)  NULL,          -- FR-02 điểm trả khách
    excluded_summary    TEXT          NULL,          -- không dùng (nguồn: tour_inclusions)
    document_terms      TEXT          NULL,          -- FR-05 giấy tờ
    meal_terms          TEXT          NULL,          -- FR-05 ăn uống
    voucher_terms       TEXT          NULL,          -- FR-05 voucher
    reschedule_terms    TEXT          NULL,          -- FR-05 đổi lịch
    source_url          VARCHAR(500)  NULL,          -- NFR-07 nguồn tham khảo
    verified_at         DATE          NULL,          -- NFR-07 ngày xác minh gần nhất
    verification_status ENUM('unverified','verified') NOT NULL DEFAULT 'unverified',   -- NFR-07 trạng thái xác minh
    approval_status     ENUM('draft','pending','approved','rejected') NOT NULL DEFAULT 'draft',
    PRIMARY KEY (id),
    KEY idx_tours_status_destination (approval_status, destination),
    KEY idx_tours_provider (provider_id),
    KEY idx_tours_destination_id (destination_id),
    KEY idx_tours_category_id (category_id),
    CONSTRAINT fk_tours_provider FOREIGN KEY (provider_id)
        REFERENCES providers (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tours_destination FOREIGN KEY (destination_id)
        REFERENCES destinations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tours_category FOREIGN KEY (category_id)
        REFERENCES categories (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ẢNH_TOUR (FR-01 ảnh bìa, FR-02 bộ ảnh): ảnh riêng của từng tour
-- (không dùng chung ảnh giữa các tour).
-- url: đường dẫn tương đối từ src/public/assets/ (vd. 'img/tours/hanoi-1.svg')
--      hoặc URL đầy đủ http(s)://...
-- Ảnh bìa = ảnh có sort_order nhỏ nhất (cùng sort_order thì id nhỏ hơn).
CREATE TABLE tour_images (
    id         CHAR(36)      NOT NULL,
    tour_id    CHAR(36)      NOT NULL,
    url        VARCHAR(255)  NOT NULL,
    alt_text   VARCHAR(255)  NULL,
    sort_order INT           NOT NULL,
    PRIMARY KEY (id),
    KEY idx_tour_images_tour_sort (tour_id, sort_order),   -- dùng luôn làm chỉ mục cho FK tour_id
    CONSTRAINT fk_tour_images_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ĐIỂM_LỊCH_TRÌNH: các chặng của tour theo thứ tự stop_order (1, 2, 3, ...).
-- Không dùng (để trống): lịch trình trên trang chi tiết đọc từ tour_itinerary_items.
CREATE TABLE itinerary_stops (
    id               CHAR(36)      NOT NULL,
    tour_id          CHAR(36)      NOT NULL,
    stop_order       INT           NOT NULL,
    title            VARCHAR(200)  NOT NULL,
    description      TEXT          NULL,
    duration_minutes INT           NULL,
    PRIMARY KEY (id),
    KEY idx_itinerary_stops_tour_order (tour_id, stop_order),   -- dùng luôn làm chỉ mục cho FK tour_id
    CONSTRAINT fk_itinerary_stops_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- PHỤ_THU / HOẠT_ĐỘNG_TÙY_CHỌN (FR-04 phụ thu và hoạt động tùy chọn, FR-10 giá tách
-- riêng): khoản phát sinh ngoài giá tour. Không bao giờ cộng vào giá "Từ" hay tổng đơn.
-- Hiển thị: phụ thu trước, rồi sort_order, rồi id.
CREATE TABLE tour_extras (
    id         CHAR(36)      NOT NULL,
    tour_id    CHAR(36)      NOT NULL,
    kind       ENUM('surcharge','optional') NOT NULL,   -- FR-04: surcharge = phụ thu, optional = hoạt động tùy chọn
    name       VARCHAR(200)  NOT NULL,                  -- FR-04 tên khoản
    price_vnd  BIGINT        NULL,                      -- FR-10 giá (NULL = chưa cập nhật)
    price_unit VARCHAR(50)   NULL,                      -- FR-10 đơn vị tính (vd. 'người', 'nhóm')
    conditions TEXT          NULL,                      -- FR-04 điều kiện áp dụng
    sort_order INT           NOT NULL DEFAULT 0,        -- thứ tự hiển thị trong cùng loại
    PRIMARY KEY (id),
    KEY idx_tour_extras_tour_sort (tour_id, sort_order),   -- dùng luôn làm chỉ mục cho FK tour_id
    CONSTRAINT fk_tour_extras_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- LỊCH_TRÌNH_TOUR (FR-03): nguồn lịch trình của trang chi tiết, theo sort_order.
-- start_time NULL = mục không ghi giờ (giao diện chỉ hiện giờ khi có).
CREATE TABLE tour_itinerary_items (
    id          CHAR(36)      NOT NULL,
    tour_id     CHAR(36)      NOT NULL,
    start_time  TIME          NULL,
    description VARCHAR(255)  NOT NULL,
    sort_order  INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_tour_itinerary_items_tour_sort (tour_id, sort_order),
    CONSTRAINT fk_tour_itinerary_items_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- BAO_GỒM_TOUR (FR-04): danh sách dịch vụ bao gồm (is_included = TRUE) và không bao gồm
-- (FALSE) của tour, theo sort_order.
CREATE TABLE tour_inclusions (
    id          CHAR(36)      NOT NULL,
    tour_id     CHAR(36)      NOT NULL,
    item_text   VARCHAR(150)  NOT NULL,
    is_included BOOLEAN       NOT NULL DEFAULT TRUE,
    sort_order  INT           NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_tour_inclusions_tour_sort (tour_id, sort_order),
    CONSTRAINT fk_tour_inclusions_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- LỊCH_TOUR (tương thích thiết kế trước): lịch theo ngày và giờ bắt đầu.
-- Không dùng (để trống): lịch khởi hành và vé nằm ở schedules / ticket_types.
CREATE TABLE tour_schedules (
    id             CHAR(36)  NOT NULL,
    tour_id        CHAR(36)  NOT NULL,
    departure_date DATE      NOT NULL,
    start_time     TIME      NOT NULL,
    seats_total    INT       NOT NULL,
    seats_booked   INT       NOT NULL DEFAULT 0,
    status         ENUM('open','full','cancelled') NOT NULL DEFAULT 'open',
    PRIMARY KEY (id),
    UNIQUE KEY uq_tour_schedules_tour_date_time (tour_id, departure_date, start_time),
    KEY idx_tour_schedules_status_date (status, departure_date),
    CONSTRAINT fk_tour_schedules_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 5. LỊCH KHỞI HÀNH, VÉ & CHÍNH SÁCH
-- ---------------------------------------------------------------------

-- LỊCH_KHỞI_HÀNH (FR-14 ngày khởi hành và sức chứa, FR-08 chọn ngày khi đặt).
-- remaining = số chỗ còn nhận (không vượt quá capacity).
-- Lịch đặt được: status = 'open', starts_at sau thời điểm hiện tại, remaining > 0
-- và có ít nhất một loại vé đang bán.
CREATE TABLE schedules (
    id        CHAR(36)  NOT NULL,
    tour_id   CHAR(36)  NOT NULL,
    starts_at DATETIME  NOT NULL,
    ends_at   DATETIME  NOT NULL,
    capacity  INT       NOT NULL,
    remaining INT       NOT NULL,
    status    ENUM('open','full','cancelled','completed') NOT NULL DEFAULT 'open',
    PRIMARY KEY (id),
    KEY idx_schedules_tour_starts (tour_id, starts_at),   -- dùng luôn làm chỉ mục cho FK tour_id
    CONSTRAINT fk_schedules_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- VÉ_THEO_LỊCH (FR-10 giá cơ bản, FR-05 độ tuổi): giá vé theo từng lịch khởi hành
-- ('adult', 'child', ...). min_age / max_age NULL = không giới hạn.
-- active = FALSE: ngừng bán loại vé này.
CREATE TABLE ticket_types (
    id          CHAR(36)     NOT NULL,
    schedule_id CHAR(36)     NOT NULL,
    name        VARCHAR(50)  NOT NULL,
    min_age     INT          NULL,
    max_age     INT          NULL,
    price_vnd   BIGINT       NOT NULL,
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id),
    KEY idx_ticket_types_schedule (schedule_id),
    CONSTRAINT fk_ticket_types_schedule FOREIGN KEY (schedule_id)
        REFERENCES schedules (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CHÍNH_SÁCH_HỦY (FR-05 hoàn tiền, FR-12 đổi/hủy theo chính sách của đúng tour):
-- mỗi lần đổi chính sách thì thêm phiên bản mới (version + 1), không sửa bản cũ,
-- vì đơn đặt lưu policy_version lúc đặt.
-- free_before_hours: hủy trước giờ khởi hành ít nhất từng ấy giờ thì được miễn phí
--                    (NULL = không có hủy miễn phí).
-- refund_percent   : phần trăm hoàn tiền khi hủy sau mốc miễn phí (0-100).
CREATE TABLE cancellation_policies (
    id                CHAR(36)  NOT NULL,
    tour_id           CHAR(36)  NOT NULL,
    free_before_hours INT       NULL,
    refund_percent    SMALLINT  NOT NULL,
    terms             TEXT      NOT NULL,
    version           INT       NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_policies_tour_version (tour_id, version),   -- dùng luôn làm chỉ mục cho FK tour_id
    CONSTRAINT fk_policies_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 6. ĐẶT CHỖ
-- ---------------------------------------------------------------------

-- ĐƠN_ĐẶT_TOUR (FR-08 yêu cầu đặt tour, FR-11 mã và trạng thái, FR-09 thông tin liên hệ).
-- user_id: tài khoản khách hàng đặt đơn (bắt buộc: chế độ khách không đặt được tour).
--   Khách xem lại đơn của mình qua tài khoản.
-- contact_name / contact_email / contact_phone: người liên hệ của đơn, lưu lại lúc đặt
--   (mặc định lấy từ tài khoản, khách có thể sửa khi đặt cho người khác).
-- code: mã đơn đưa cho khách (vd. 'LT123456').
-- status: pending = Chờ xác nhận, awaiting_payment = Chờ thanh toán,
--         confirmed = Đã xác nhận, rejected = Từ chối, cancelled = Đã hủy,
--         completed = Đã hoàn thành (chỉ đơn completed mới được đánh giá).
-- total_vnd = tổng line_total_vnd của các dòng đơn (không gồm tour_extras).
-- policy_version: phiên bản chính sách hủy của tour tại thời điểm đặt.
-- hold_expires_at: hạn giữ chỗ khi đơn đang chờ thanh toán (NULL = không giữ chỗ).
-- created_at: thời điểm khách gửi yêu cầu (FR-22 thống kê theo thời gian, FR-25 sắp xếp
--   danh sách yêu cầu ở trang quản trị).
CREATE TABLE bookings (
    id              CHAR(36)      NOT NULL,
    user_id         CHAR(36)      NOT NULL,
    schedule_id     CHAR(36)      NOT NULL,
    code            VARCHAR(20)   NOT NULL,
    contact_name    VARCHAR(100)  NOT NULL,
    contact_email   VARCHAR(150)  NOT NULL,
    contact_phone   VARCHAR(20)   NOT NULL,
    status          ENUM('pending','awaiting_payment','confirmed','rejected','cancelled','completed')
                    NOT NULL DEFAULT 'pending',
    total_vnd       BIGINT        NOT NULL,
    policy_version  INT           NOT NULL,
    hold_expires_at DATETIME      NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- FR-22, FR-25
    PRIMARY KEY (id),
    UNIQUE KEY uq_bookings_code (code),
    KEY idx_bookings_user (user_id),
    KEY idx_bookings_schedule (schedule_id),
    KEY idx_bookings_status_created (status, created_at),               -- FR-21, FR-22
    CONSTRAINT fk_bookings_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_bookings_schedule FOREIGN KEY (schedule_id)
        REFERENCES schedules (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- DÒNG_ĐƠN (FR-08 số lượng người, FR-10 giá): mỗi loại vé trong đơn một dòng.
-- Giá được chụp lại lúc đặt (unit_price_vnd), line_total_vnd = quantity * unit_price_vnd.
CREATE TABLE booking_lines (
    id             CHAR(36)  NOT NULL,
    booking_id     CHAR(36)  NOT NULL,
    ticket_type_id CHAR(36)  NOT NULL,
    quantity       INT       NOT NULL,
    unit_price_vnd BIGINT    NOT NULL,
    line_total_vnd BIGINT    NOT NULL,
    PRIMARY KEY (id),
    KEY idx_booking_lines_booking (booking_id),
    KEY idx_booking_lines_ticket_type (ticket_type_id),
    CONSTRAINT fk_booking_lines_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_booking_lines_ticket_type FOREIGN KEY (ticket_type_id)
        REFERENCES ticket_types (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- HÀNH_KHÁCH (FR-09 người tham gia và yêu cầu đặc biệt): mỗi người tham gia tour
-- một dòng (người đặt thường là khách đầu tiên). special_request: ăn chay, dị ứng, ...
CREATE TABLE passengers (
    id              CHAR(36)      NOT NULL,
    booking_id      CHAR(36)      NOT NULL,
    full_name       VARCHAR(100)  NOT NULL,
    age_group       ENUM('adult','child','infant') NOT NULL,
    special_request TEXT          NULL,
    PRIMARY KEY (id),
    KEY idx_passengers_booking (booking_id),
    CONSTRAINT fk_passengers_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 7. GIAO DỊCH
-- ---------------------------------------------------------------------

-- THANH_TOÁN (FR-17 thanh toán trực tuyến): method chỉ có 'vnpay' hoặc 'vietqr'
-- (FR board không có hình thức trả sau / trả tại điểm hẹn).
-- provider_txn_id: mã giao dịch phía cổng VNPay / VietQR (NULL khi chưa tạo giao dịch).
-- status: pending = Chưa thanh toán, processing = Đang xử lý,
--         awaiting_reconciliation = Chờ đối chiếu, paid = Thành công, failed = Thất bại.
--         Luồng VietQR kết thúc ở 'awaiting_reconciliation' (chờ nhân viên đối chiếu)
--         hoặc 'paid'.
--         Không có trạng thái "đã hoàn tiền": tiền hoàn được ghi ở bảng refunds.
-- paid_at: thời điểm ghi nhận thanh toán thành công (status chuyển sang 'paid'); NULL khi
--         chưa thành công. FR-23 thống kê doanh thu theo ngày thanh toán.
CREATE TABLE payments (
    id              CHAR(36)      NOT NULL,
    booking_id      CHAR(36)      NOT NULL,
    method          ENUM('vnpay','vietqr') NOT NULL,   -- FR-17: chỉ 2 cổng thanh toán trực tuyến
    provider_txn_id VARCHAR(100)  NULL,
    amount_vnd      BIGINT        NOT NULL,
    status          ENUM('pending','processing','awaiting_reconciliation','paid','failed')
                    NOT NULL DEFAULT 'pending',
    expires_at      DATETIME      NULL,
    paid_at         DATETIME      NULL,                                 -- FR-23
    PRIMARY KEY (id),
    KEY idx_payments_booking (booking_id),
    KEY idx_payments_status_paid (status, paid_at),                     -- FR-23
    CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SỰ_KIỆN_THANH_TOÁN (FR-17 xác nhận từ cổng VNPay): thông báo (IPN / webhook) cổng
-- thanh toán gửi về. provider_event_id UNIQUE để không xử lý trùng một thông báo.
-- verified = TRUE: chữ ký của thông báo đã được kiểm tra hợp lệ.
CREATE TABLE payment_events (
    id                CHAR(36)      NOT NULL,
    payment_id        CHAR(36)      NOT NULL,
    provider_event_id VARCHAR(100)  NOT NULL,
    result_code       VARCHAR(20)   NOT NULL,
    verified          BOOLEAN       NOT NULL DEFAULT FALSE,
    received_at       DATETIME      NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_payment_events_provider_event (provider_event_id),
    KEY idx_payment_events_payment (payment_id),
    CONSTRAINT fk_payment_events_payment FOREIGN KEY (payment_id)
        REFERENCES payments (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- HOÀN_TIỀN (FR-12 kết quả hủy, FR-17): yêu cầu hoàn tiền cho một khoản thanh toán.
CREATE TABLE refunds (
    id           CHAR(36)      NOT NULL,
    payment_id   CHAR(36)      NOT NULL,
    amount_vnd   BIGINT        NOT NULL,
    reason       VARCHAR(255)  NOT NULL,
    status       ENUM('requested','approved','rejected','completed') NOT NULL DEFAULT 'requested',
    requested_at DATETIME      NOT NULL,
    PRIMARY KEY (id),
    KEY idx_refunds_payment (payment_id),
    CONSTRAINT fk_refunds_payment FOREIGN KEY (payment_id)
        REFERENCES payments (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 8. ĐÁNH GIÁ
-- ---------------------------------------------------------------------

-- ĐÁNH_GIÁ (FR-16): mỗi đơn đặt được đánh giá tối đa một lần (booking_id UNIQUE), nên
-- người đánh giá là chủ tài khoản của đơn (bookings.user_id); tên hiển thị = users.name.
-- rating từ 1 đến 5. Chỉ đánh giá moderation_status = 'approved' mới được hiển thị và
-- tính vào điểm trung bình.
CREATE TABLE reviews (
    id                CHAR(36)  NOT NULL,
    booking_id        CHAR(36)  NOT NULL,
    tour_id           CHAR(36)  NOT NULL,
    rating            SMALLINT  NOT NULL,
    content           TEXT      NOT NULL,
    moderation_status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    PRIMARY KEY (id),
    UNIQUE KEY uq_reviews_booking (booking_id),
    KEY idx_reviews_tour (tour_id),
    CONSTRAINT fk_reviews_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_reviews_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 9. KHÁM PHÁ, YÊU THÍCH, SO SÁNH & THÔNG BÁO
--    Sprint 3 chưa dùng: các nút Lưu tour / So sánh hiện "Sắp có", bảng để trống.
-- ---------------------------------------------------------------------

CREATE TABLE tour_posts (
    id             CHAR(36)  NOT NULL,
    tour_id        CHAR(36)  NOT NULL,
    author_user_id CHAR(36)  NOT NULL,
    caption        TEXT      NOT NULL,
    published_at   DATETIME  NULL,
    status         ENUM('draft','published') NOT NULL DEFAULT 'draft',
    PRIMARY KEY (id),
    KEY idx_tour_posts_tour (tour_id),
    KEY idx_tour_posts_author (author_user_id),
    KEY idx_tour_posts_status_published (status, published_at),
    CONSTRAINT fk_tour_posts_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tour_posts_author FOREIGN KEY (author_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE favorite_tours (
    id         CHAR(36)  NOT NULL,
    user_id    CHAR(36)  NOT NULL,
    tour_id    CHAR(36)  NOT NULL,
    created_at DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_favorite_tours_user_tour (user_id, tour_id),
    KEY idx_favorite_tours_tour (tour_id),
    CONSTRAINT fk_favorite_tours_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_favorite_tours_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE notifications (
    id                CHAR(36)      NOT NULL,
    recipient_user_id CHAR(36)      NOT NULL,
    type              VARCHAR(50)   NOT NULL,
    payload_ref       VARCHAR(255)  NULL,
    read_at           DATETIME      NULL,
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_notifications_recipient_created (recipient_user_id, created_at),
    KEY idx_notifications_recipient_read (recipient_user_id, read_at),
    CONSTRAINT fk_notifications_recipient FOREIGN KEY (recipient_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- user_id NULL cho phép so sánh trong phiên khách; session_key dùng cho phiên chưa đăng nhập.
CREATE TABLE comparisons (
    id          CHAR(36)      NOT NULL,
    user_id     CHAR(36)      NULL,
    session_key VARCHAR(100)  NULL,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_comparisons_user (user_id),
    KEY idx_comparisons_session (session_key),
    CONSTRAINT fk_comparisons_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE comparison_tours (
    id            CHAR(36)  NOT NULL,
    comparison_id CHAR(36)  NOT NULL,
    tour_id       CHAR(36)  NOT NULL,
    sort_order    INT       NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_comparison_tours_comparison_tour (comparison_id, tour_id),
    KEY idx_comparison_tours_tour (tour_id),
    CONSTRAINT fk_comparison_tours_comparison FOREIGN KEY (comparison_id)
        REFERENCES comparisons (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_comparison_tours_tour FOREIGN KEY (tour_id)
        REFERENCES tours (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 10. NHẬT KÝ
-- ---------------------------------------------------------------------

-- NHẬT_KÝ_QUẢN_TRỊ (NFR-09 lịch sử xử lý): thao tác của quản trị viên (FR-24 duyệt /
-- từ chối tour, FR-25 đổi trạng thái yêu cầu đặt tour). target_type + target_id: đối
-- tượng bị tác động ('tour' hoặc 'booking' + UUID); không có khóa ngoại vì đối tượng có
-- thể nằm ở nhiều bảng khác nhau.
-- action: 'tour_approve', 'tour_reject', 'booking_status'.
-- from_status / to_status: trạng thái trước và sau thao tác.
-- note: lý do từ chối / hủy hoặc ghi chú xử lý (NULL = không có ghi chú).
CREATE TABLE admin_logs (
    id            CHAR(36)     NOT NULL,
    actor_user_id CHAR(36)     NOT NULL,
    target_type   VARCHAR(50)  NOT NULL,
    target_id     VARCHAR(36)  NOT NULL,
    action        VARCHAR(50)  NOT NULL,
    from_status   VARCHAR(30)  NULL,
    to_status     VARCHAR(30)  NULL,
    note          VARCHAR(255) NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_admin_logs_actor (actor_user_id),
    KEY idx_admin_logs_target (target_type, target_id, created_at),
    CONSTRAINT fk_admin_logs_actor FOREIGN KEY (actor_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =====================================================================
-- LocalTour v0.1 - 02_seed.sql
-- Mục đích  : Nạp dữ liệu mẫu để kiểm thử trang danh sách, trang chi tiết tour,
--             tài khoản khách hàng và trang quản trị cho lược đồ gộp 27 bảng
--             (01_schema.sql). Các bảng chưa dùng để trống: itinerary_stops,
--             tour_schedules, tour_posts, favorite_tours, notifications, comparisons,
--             comparison_tours.
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.2
-- Dữ liệu   : TẤT CẢ dữ liệu (tài khoản, nhà cung cấp, tour, giá, lịch, đơn đặt,
--             thanh toán, đánh giá) là dữ liệu MINH HỌA, không phải thông tin thật
--             của bất kỳ người hay đơn vị nào:
--               * email dùng tên miền @localtour.test (không tồn tại);
--               * số điện thoại là số giả dạng 0000000xxx; users.phone để NULL;
--               * mọi tài khoản mẫu có password_hash NULL nên KHÔNG đăng nhập được.
--                 Người kiểm thử tự tạo tài khoản khách hàng ở trang đăng ký (/register);
--               * NFR-07: mọi tour có source_url NULL, verified_at NULL,
--                 verification_status 'unverified' vì dữ liệu là minh họa (không gán
--                 nguồn hay ngày kiểm tra giả).
--               * mã VNP-DEMO-…, VQR-DEMO-…, EVT-DEMO-… là mã giả, không qua cổng thật.
-- Chạy sau  : 01_schema.sql (bảng phải đang trống).
-- Ngày tháng: Tính tương đối theo CURDATE()/NOW() lúc import, nên luôn có lịch "sắp tới".
--
-- ID: UUID cố định, dễ đọc: <tiền tố bảng>-0000-4000-8000-<số 12 chữ số>
--   users a0000000 · providers b0000000 · tours c0000000 · schedules d0000000
--   ticket_types e0000000 · cancellation_policies f0000000 · bookings 10000000
--   booking_lines 20000000 · passengers 30000000 · payments 40000000
--   payment_events 50000000 · refunds 60000000 · reviews 70000000
--   tour_images 80000000 · tour_extras c1000000 · destinations c2000000
--   categories c3000000 · tour_itinerary_items c4000000 · tour_inclusions c5000000
--   admin_logs 90000000
--   Tour N = c0000000-0000-4000-8000-00000000000N; tour 1 = "Hà Nội qua những món ăn phố cổ".
-- Cách đánh số:
--   users        : 1 = quản trị viên; 2 = nhân viên hỗ trợ khách hàng;
--                  11-17 = tài khoản của nhà cung cấp 1-7;
--                  101-139 = tài khoản khách hàng: khách hàng 100 + N là người đặt đơn N
--                  (name = contact_name, email = contact_email của đơn);
--                  140 = khách hàng bị khóa (không có đơn).
--   destinations : 1 = Hà Nội, 2 = Đà Nẵng, 3 = Hội An, 4 = TP. Hồ Chí Minh,
--                  5 = Huế (chỉ có tour 11 đang chờ duyệt).
--   categories   : 1 = Ẩm thực, 2 = Văn hóa – lịch sử, 3 = Thiên nhiên, 4 = Về đêm,
--                  5 = Trải nghiệm địa phương, 6 = Đạp xe.
--   schedules    : 1-37 = lịch của các tour; 38-39 = lịch của tour 11;
--                  101-128 = lịch đã đi của đơn có đánh giá
--                  (lịch 100 + N thuộc đơn N).
--   ticket_types : số lịch x 10 + 1 = người lớn, + 2 = trẻ em (vd. lịch 3 -> 31, 32).
--   bookings     : 1-28 = đơn có đánh giá đã duyệt (đơn N <-> đánh giá N);
--                  29 = đơn có đánh giá đang chờ duyệt; 30 = đơn đã hủy;
--                  31-39 = đơn cho trang quản trị (mục 20).
--   booking_lines, passengers: số đơn x 10 + thứ tự. payments: trùng số đơn.
--   tour_images, tour_itinerary_items, tour_inclusions, tour_extras: đánh số theo thứ tự
--                  chèn, cố ý lệch với thứ tự hiển thị để kiểm tra ORDER BY.
--
-- Ca kiểm thử có sẵn trong dữ liệu:
--   * Tour 1-9 hiển thị. Tour 10 approval_status = 'pending': KHÔNG BAO GIỜ hiển thị,
--     dù có lịch mở và 3 đánh giá 5 sao (nếu bị lộ sẽ đứng đầu tab "Nổi bật").
--   * Tour 9: chưa có đánh giá, không có lịch đặt được (chỉ 1 lịch đã hủy) -> giá NULL;
--     không có ảnh, lịch trình, dịch vụ (tour_inclusions) và loại hình -> giao diện hiện
--     "Chưa cập nhật".
--   * Tour 10 có ảnh, lịch trình và dịch vụ riêng: không bao giờ được trả về.
--   * Tour 11 (Huế) 'pending' và tour 12 (Hội An) 'rejected' cũng không hiển thị.
--     Quản trị viên phê duyệt tour 11 thì trang khách có 10 tour và Huế xuất hiện.
--   * Tour 1: lịch đã qua 'completed' (lịch 1), lịch 'full' (lịch 2) và lịch giá cao hơn
--     690.000đ (lịch 6). Có 1 đánh giá 'pending' 1 sao: không hiện, không tính điểm.
--   * Tour 2: lịch 'open' nhưng remaining = 0 (lịch 7) -> bị lọc; vé trẻ em của lịch 8
--     ngừng bán (active = FALSE).
--   * Tour 3, 8: chỉ bán vé người lớn (tour 8 từ 16 tuổi). Tour 3 có 2 lịch cùng ngày khác giờ.
--   * Tour 4: lịch 'cancelled' (lịch 15) -> bị lọc; chính sách hủy có 2 phiên bản (hiện bản 2).
--   * Tour 4, 8: đón tại khách sạn (hotel_pickup); các tour còn lại có điểm hẹn.
--   * Đơn 30 (tour 1) đã hủy: thanh toán 'paid' (đã trả) + khoản hoàn tiền 'completed'
--     trong bảng refunds (payments không có trạng thái "đã hoàn tiền").
--   * Ảnh: mỗi file SVG chỉ thuộc 1 tour. Tour 2 không có ảnh (Hà Nội chỉ có 3 file cho
--     4 tour). Tour 4: 2 ảnh cùng sort_order -> ảnh bìa là ảnh có id nhỏ hơn. Tour 6: ảnh
--     bìa có id lớn hơn ảnh thứ 2. Tour 8: 3 ảnh chèn lệch thứ tự, 1 ảnh alt_text NULL.
--   * Điểm đến (destinations): bộ lọc và thanh bên chỉ hiện điểm đến có tour hiển thị:
--     Hà Nội 3 tour (1-3; tour 10 chờ duyệt không tính), Đà Nẵng 2, Hội An 2,
--     TP. Hồ Chí Minh 2. Huế chỉ có tour 11 chờ duyệt -> bị ẩn. sort_order theo Bắc -> Nam
--     (Hà Nội, Huế, Đà Nẵng, Hội An, TP. Hồ Chí Minh), khác thứ tự id.
--   * Loại hình (categories): Ẩm thực 2 tour (1, 2), Văn hóa – lịch sử 2 (3, 6),
--     Về đêm 2 (5, 8), Thiên nhiên 1 (4), Trải nghiệm địa phương 1 (7). Đạp xe chỉ có
--     tour 10 (chờ duyệt) -> bị ẩn. Tour 9 category_id NULL -> "Loại hình" hiện
--     "Chưa cập nhật" và tour 9 không thuộc bộ lọc loại hình nào.
--   * Lịch trình (tour_itinerary_items): tour 1-8 có 4-5 mục chèn lệch thứ tự.
--     start_time = giờ khởi hành của lịch + thời lượng các chặng trước. Tour 3 (lộ trình
--     linh hoạt, lịch 08:30 hoặc 14:00): mọi mục start_time NULL -> chỉ hiện mô tả.
--     Tour 4, 8: mục trả khách về khách sạn start_time NULL (giờ tùy khách sạn).
--   * Dịch vụ (tour_inclusions): tour 1-8 có danh sách bao gồm; tour 5 không có dòng
--     không bao gồm -> phần "không bao gồm" hiện "Chưa cập nhật". Tour 4 chèn dòng không
--     bao gồm trước và lệch sort_order (kiểm tra ORDER BY is_included DESC, sort_order).
--   * Thông tin tour (FR-02/05): tour 9 chưa cập nhật cả 7 trường (transport, guide_info,
--     dropoff_point, document_terms, meal_terms, voucher_terms, reschedule_terms); tour 3
--     thiếu dropoff_point, voucher_terms; tour 7 thiếu guide_info, reschedule_terms.
--     Các trường thiếu -> giao diện hiện "Chưa cập nhật".
--   * Phụ thu / tùy chọn (tour_extras): 0-3 dòng mỗi tour; tour 2 và tour 9 không có.
--     Có dòng thiếu giá, thiếu đơn vị hoặc thiếu điều kiện (NULL). Tour 10 có 2 dòng.
--   * Điểm TB (chỉ đánh giá 'approved'): tour 3 = 5,0; tour 1, 6 = 4,8; tour 2, 7 = 4,7;
--     tour 4, 8 = 4,5; tour 5 = 4,3; tour 9 chưa có.
--   * Giá "Từ" = vé người lớn rẻ nhất trong các lịch đặt được (nghìn đồng):
--     tour 1: 650, tour 2: 720, tour 3: 900, tour 4: 550, tour 5: 480,
--     tour 6: 590, tour 7: 750, tour 8: 850, tour 9: NULL.
--   * Tài khoản: mọi tài khoản mẫu (quản trị, hỗ trợ, nhà cung cấp, khách hàng 101-140)
--     có password_hash NULL -> đăng nhập luôn báo "Email hoặc mật khẩu không đúng.".
--     Đăng ký bằng email đã có, kể cả khác chữ hoa / thường (vd. quoc.huy@localtour.test,
--     Quoc.Huy@LocalTour.test) -> "Email này đã được dùng.".
--   * Đánh giá: tên người đánh giá = users.name của chủ đơn (bookings.user_id), trùng
--     contact_name của đơn.
--   * Trang quản trị (FR-19 → FR-25): đơn 31-39 ở đủ 6 trạng thái, tour 11 chờ duyệt,
--     tour 12 bị từ chối, khách hàng 140 bị khóa, 10 dòng lịch sử xử lý; xem mục 20.
--
-- Số dòng: users 49, providers 7, destinations 5, categories 6, tours 12,
--          cancellation_policies 12, schedules 67, ticket_types 122, bookings 39,
--          booking_lines 45, passengers 79, payments 33, payment_events 32, refunds 1,
--          reviews 29, tour_images 12, tour_itinerary_items 43, tour_inclusions 45,
--          tour_extras 15, admin_logs 10. Để trống (0 dòng): itinerary_stops,
--          tour_schedules, tour_posts, favorite_tours, notifications, comparisons,
--          comparison_tours.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. users (NGƯỜI_DÙNG)
--   Tài khoản nhân viên, nhà cung cấp và khách hàng. Mọi tài khoản mẫu có password_hash
--   NULL nên không đăng nhập được; người kiểm thử tự đăng ký tài khoản ở /register.
-- ---------------------------------------------------------------------
INSERT INTO users (id, email, password_hash, name, phone, role, status) VALUES
-- Quản trị viên
('a0000000-0000-4000-8000-000000000001', 'admin@localtour.test', NULL, 'Quản trị viên LocalTour', NULL, 'admin', 'active'),
-- Nhân viên hỗ trợ khách hàng
('a0000000-0000-4000-8000-000000000002', 'hotro@localtour.test', NULL, 'Nhân viên hỗ trợ LocalTour', NULL, 'support', 'active'),
-- Tài khoản của nhà cung cấp 1-7
('a0000000-0000-4000-8000-000000000011', 'hanoilocal@localtour.test', NULL, 'Hà Nội Local', NULL, 'provider', 'active'),
('a0000000-0000-4000-8000-000000000012', 'phocostories@localtour.test', NULL, 'Phố Cổ Stories', NULL, 'provider', 'active'),
('a0000000-0000-4000-8000-000000000013', 'sontraxanh@localtour.test', NULL, 'Sơn Trà Xanh', NULL, 'provider', 'active'),
('a0000000-0000-4000-8000-000000000014', 'demsonghan@localtour.test', NULL, 'Đêm Sông Hàn', NULL, 'provider', 'active'),
('a0000000-0000-4000-8000-000000000015', 'phohoicham@localtour.test', NULL, 'Phố Hội Chậm', NULL, 'provider', 'active'),
('a0000000-0000-4000-8000-000000000016', 'saigonvedem@localtour.test', NULL, 'Sài Gòn Về Đêm', NULL, 'provider', 'active'),
('a0000000-0000-4000-8000-000000000017', 'cholonkechuyen@localtour.test', NULL, 'Chợ Lớn Kể Chuyện', NULL, 'provider', 'active'),
-- Tài khoản khách hàng 101-130: khách hàng 100 + N là người đặt đơn N
-- (name = contact_name, email = contact_email của đơn; 129 = đơn có đánh giá chờ duyệt, 130 = đơn đã hủy)
('a0000000-0000-4000-8000-000000000101', 'quoc.huy@localtour.test', NULL, 'Quốc Huy', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000102', 'lan.phuong@localtour.test', NULL, 'Lan Phương', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000103', 'thu.trang@localtour.test', NULL, 'Thu Trang', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000104', 'minh.anh@localtour.test', NULL, 'Minh Anh', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000105', 'hoang.yen@localtour.test', NULL, 'Hoàng Yến', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000106', 'duc.thinh@localtour.test', NULL, 'Đức Thịnh', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000107', 'bao.ngoc@localtour.test', NULL, 'Bảo Ngọc', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000108', 'gia.bao@localtour.test', NULL, 'Gia Bảo', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000109', 'khanh.linh@localtour.test', NULL, 'Khánh Linh', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000110', 'hai.dang@localtour.test', NULL, 'Hải Đăng', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000111', 'thanh.ha@localtour.test', NULL, 'Thanh Hà', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000112', 'van.long@localtour.test', NULL, 'Văn Long', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000113', 'ngoc.mai@localtour.test', NULL, 'Ngọc Mai', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000114', 'tuan.kiet@localtour.test', NULL, 'Tuấn Kiệt', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000115', 'mai.chi@localtour.test', NULL, 'Mai Chi', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000116', 'phuong.thao@localtour.test', NULL, 'Phương Thảo', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000117', 'kim.ngan@localtour.test', NULL, 'Kim Ngân', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000118', 'trong.nghia@localtour.test', NULL, 'Trọng Nghĩa', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000119', 'thao.vy@localtour.test', NULL, 'Thảo Vy', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000120', 'nhat.minh@localtour.test', NULL, 'Nhật Minh', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000121', 'diem.my@localtour.test', NULL, 'Diễm My', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000122', 'huu.phuoc@localtour.test', NULL, 'Hữu Phước', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000123', 'anh.thu@localtour.test', NULL, 'Anh Thư', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000124', 'thanh.tung@localtour.test', NULL, 'Thanh Tùng', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000125', 'quynh.nhu@localtour.test', NULL, 'Quỳnh Như', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000126', 'bich.ngoc@localtour.test', NULL, 'Bích Ngọc', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000127', 'hoai.nam@localtour.test', NULL, 'Hoài Nam', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000128', 'thu.hang@localtour.test', NULL, 'Thu Hằng', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000129', 'dinh.khoa@localtour.test', NULL, 'Đình Khoa', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000130', 'minh.chau@localtour.test', NULL, 'Minh Châu', NULL, 'customer', 'active');

-- ---------------------------------------------------------------------
-- 2. providers (NHÀ_CUNG_CẤP)
--   Cả 7 nhà cung cấp đã được duyệt; contact_phone là số giả.
-- ---------------------------------------------------------------------
INSERT INTO providers (id, user_id, business_name, contact_phone, approval_status, approved_at) VALUES
('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000011', 'Hà Nội Local', '0000000001', 'approved', NOW() - INTERVAL 398 DAY),
('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000012', 'Phố Cổ Stories', '0000000002', 'approved', NOW() - INTERVAL 378 DAY),
('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000013', 'Sơn Trà Xanh', '0000000003', 'approved', NOW() - INTERVAL 298 DAY),
('b0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000014', 'Đêm Sông Hàn', '0000000004', 'approved', NOW() - INTERVAL 198 DAY),
('b0000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000015', 'Phố Hội Chậm', '0000000005', 'approved', NOW() - INTERVAL 358 DAY),
('b0000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000016', 'Sài Gòn Về Đêm', '0000000006', 'approved', NOW() - INTERVAL 248 DAY),
('b0000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000017', 'Chợ Lớn Kể Chuyện', '0000000007', 'approved', NOW() - INTERVAL 7 DAY);

-- ---------------------------------------------------------------------
-- 3. destinations (ĐIỂM_ĐẾN)
--   name trùng đúng cột tours.destination. sort_order theo Bắc -> Nam, khác thứ tự id.
--   Huế (5) chưa có tour nào: không được hiện trong bộ lọc và thanh bên.
-- ---------------------------------------------------------------------
INSERT INTO destinations (id, name, slug, sort_order) VALUES
('c2000000-0000-4000-8000-000000000001', 'Hà Nội', 'ha-noi', 1),
('c2000000-0000-4000-8000-000000000002', 'Đà Nẵng', 'da-nang', 3),
('c2000000-0000-4000-8000-000000000003', 'Hội An', 'hoi-an', 4),
('c2000000-0000-4000-8000-000000000004', 'TP. Hồ Chí Minh', 'tp-ho-chi-minh', 5),
('c2000000-0000-4000-8000-000000000005', 'Huế', 'hue', 2);

-- ---------------------------------------------------------------------
-- 4. categories (LOẠI_HÌNH)
--   Tour 9 chưa có loại hình (category_id NULL). Đạp xe chỉ có tour 10 (chờ duyệt):
--   không được hiện trong bộ lọc "Loại hình".
-- ---------------------------------------------------------------------
INSERT INTO categories (id, name, slug) VALUES
('c3000000-0000-4000-8000-000000000001', 'Ẩm thực', 'am-thuc'),
('c3000000-0000-4000-8000-000000000002', 'Văn hóa – lịch sử', 'van-hoa-lich-su'),
('c3000000-0000-4000-8000-000000000003', 'Thiên nhiên', 'thien-nhien'),
('c3000000-0000-4000-8000-000000000004', 'Về đêm', 've-dem'),
('c3000000-0000-4000-8000-000000000005', 'Trải nghiệm địa phương', 'trai-nghiem-dia-phuong'),
('c3000000-0000-4000-8000-000000000006', 'Đạp xe', 'dap-xe');

-- ---------------------------------------------------------------------
-- 5. tours (TOUR)
--   destination_id / category_id: điểm đến (mục 3) và loại hình (mục 4). Cột destination giữ
--   tên điểm đến dạng chữ, trùng destinations.name. Tour 9 chưa có loại hình (NULL).
--   description = tóm tắt + dòng trống + mô tả. CHAR(10) = ký tự xuống dòng.
--   Lịch trình nằm ở tour_itinerary_items (mục 17); dịch vụ bao gồm / không bao gồm nằm ở
--   tour_inclusions (mục 18). included_summary / excluded_summary để NULL (không dùng).
--   NFR-07: source_url, verified_at NULL và verification_status 'unverified' cho mọi tour.
--   Tour 10: approval_status = 'pending' (đang chờ duyệt lại sau khi đổi lộ trình).
-- ---------------------------------------------------------------------
INSERT INTO tours (id, provider_id, destination_id, category_id, title, description, destination,
                   duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point, included_summary,
                   transport, guide_info, dropoff_point, excluded_summary,
                   document_terms, meal_terms, voucher_terms, reschedule_terms,
                   source_url, verified_at, verification_status, approval_status) VALUES
-- Tour 1 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
    'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001',   -- Hà Nội, Ẩm thực
    'Hà Nội qua những món ăn phố cổ',
    CONCAT_WS(CHAR(10),
        'Đi bộ cùng người địa phương, khám phá món ngon và câu chuyện phố cổ.',
        '',
        'Tour đi bộ 4 giờ cùng người dẫn địa phương. Ghé các quán nhỏ, thưởng thức món ăn và tìm hiểu cuộc sống thường ngày tại Hà Nội. Lộ trình đi qua những con phố nhỏ quanh hồ Hoàn Kiếm, mỗi điểm dừng là một món ăn và một câu chuyện về con phố đó.'),
    'Hà Nội', 240, 8, 'vi,en', 'meeting_point', 'Nhà hát Múa rối Thăng Long',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ (khoảng 3 km)',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Khu vực hồ Hoàn Kiếm',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm 5 món ăn và 1 đồ uống. Báo trước khi đặt nếu ăn chay hoặc dị ứng thực phẩm.',
    'Xuất trình mã đặt chỗ (bản điện tử) cho người dẫn tại điểm hẹn.',
    'Đổi sang lịch khác miễn phí nếu báo trước ít nhất 24 giờ và lịch mới còn chỗ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 2 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002',
    'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001',   -- Hà Nội, Ẩm thực
    'Ẩm thực Hà Nội & cà phê trứng',
    CONCAT_WS(CHAR(10),
        'Một góc nhìn khác về phố cổ, với nhóm nhỏ và thời gian thư thả.',
        '',
        'Bắt đầu từ chợ Đồng Xuân, nhóm đi qua các phố quanh chợ để thử bánh cuốn nóng và những món ăn vặt quen thuộc của người Hà Nội. Tour kết thúc ở một quán cà phê trứng trên tầng cao nhìn ra phố. Nhịp đi chậm, phù hợp với người lần đầu đến Hà Nội.'),
    'Hà Nội', 180, 6, 'vi,en', 'meeting_point', 'Chợ Đồng Xuân (cổng chính)',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Quán cà phê trứng ở chặng cuối, trong khu phố cổ',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bánh cuốn, 3 món ăn vặt và 1 ly cà phê trứng (có thể đổi sang đồ uống khác).',
    'Xuất trình mã đặt chỗ cho người dẫn tại cổng chính chợ Đồng Xuân.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 3 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000002',
    'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000002',   -- Hà Nội, Văn hóa – lịch sử
    'Phố cổ theo cách của bạn',
    CONCAT_WS(CHAR(10),
        'Tour riêng cho nhóm nhỏ: bạn chọn chủ đề, người dẫn thiết kế lộ trình quanh phố cổ.',
        '',
        'Trước ngày đi, người dẫn liên hệ để hỏi sở thích của nhóm: kiến trúc nhà ống, phố nghề, đền chùa hay những góc chụp ảnh. Lộ trình được sắp xếp riêng trong khoảng 4 giờ, đi bộ kết hợp một đoạn xích lô ngắn. Phù hợp với gia đình hoặc nhóm bạn muốn tìm hiểu phố cổ sâu hơn.'),
    'Hà Nội', 240, 4, 'vi,en,fr', 'meeting_point', 'Đền Bạch Mã, phố Hàng Buồm',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả (thiếu: dropoff_point, voucher_terms)
    'Đi bộ kết hợp xích lô 20 phút',
    'Người dẫn riêng cho nhóm, nói tiếng Việt, tiếng Anh hoặc tiếng Pháp',
    NULL,
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Không gồm bữa ăn. Người dẫn gợi ý quán ăn tối sau tour.',
    NULL,
    'Đổi lịch miễn phí nếu báo trước ít nhất 48 giờ; người dẫn liên hệ lại để thống nhất lộ trình.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 4 (Đà Nẵng) -------------------------------------------
('c0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000003',
    'c2000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000003',   -- Đà Nẵng, Thiên nhiên
    'Bình minh trên bán đảo Sơn Trà',
    CONCAT_WS(CHAR(10),
        'Đón bình minh trên bán đảo Sơn Trà, đi bộ đường rừng nhẹ và tìm voọc chà vá chân nâu.',
        '',
        'Xe đón nhóm ở trung tâm thành phố lúc 5 giờ sáng để kịp ngắm mặt trời mọc trên đỉnh Bàn Cờ. Sau đó cả nhóm đi bộ một cung đường rừng ngắn, nghe người dẫn giới thiệu hệ sinh thái của bán đảo và quan sát voọc chà vá chân nâu nếu may mắn. Tour kết thúc bằng bữa sáng mì Quảng gần chân núi.'),
    'Đà Nẵng', 300, 10, 'vi,en,ko', 'hotel_pickup', 'Khách sạn ở trung tâm Đà Nẵng',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe 16 chỗ đưa đón hai chiều; đi bộ đường rừng khoảng 2 km',
    'Hướng dẫn viên nói tiếng Việt, tiếng Anh và tiếng Hàn',
    'Khách sạn ở trung tâm Đà Nẵng',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bữa sáng mì Quảng và nước uống. Có mì chay nếu báo trước.',
    'Xuất trình mã đặt chỗ cho tài xế khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ. Trời mưa lớn: tour được dời lịch theo chính sách hủy hiện hành.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 5 (Đà Nẵng) -------------------------------------------
('c0000000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000004',
    'c2000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000004',   -- Đà Nẵng, Về đêm
    'Đà Nẵng về đêm: cầu Rồng và chợ đêm',
    CONCAT_WS(CHAR(10),
        'Dạo bờ sông Hàn, ngắm cầu Rồng lên đèn và ăn tối ở chợ đêm cùng người địa phương.',
        '',
        'Tour bắt đầu khi thành phố lên đèn, đi bộ dọc bờ sông Hàn và dừng lại ở những góc ngắm cầu Rồng đẹp nhất. Sau đó nhóm ghé chợ đêm thử bánh tráng cuốn thịt heo, ốc hút và chè. Vào tối thứ Bảy và Chủ nhật, nhóm xem cầu Rồng phun lửa, phun nước lúc 21:00.'),
    'Đà Nẵng', 210, 12, 'vi,en', 'meeting_point', 'Đầu cầu Rồng, phía đường Bạch Đằng',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ dọc bờ sông Hàn, taxi sang chợ đêm',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Chợ đêm, nơi kết thúc tour',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm ăn tối nhẹ 3 món ở chợ đêm.',
    'Xuất trình mã đặt chỗ cho người dẫn ở đầu cầu Rồng.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 12 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 6 (Hội An) --------------------------------------------
('c0000000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000005',
    'c2000000-0000-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000002',   -- Hội An, Văn hóa – lịch sử
    'Hội An: phố cổ, đèn lồng và hoa đăng',
    CONCAT_WS(CHAR(10),
        'Đi chậm qua phố cổ Hội An lúc chiều tối, nghe chuyện hội quán và thả hoa đăng trên sông Hoài.',
        '',
        'Người dẫn đưa nhóm qua chùa Cầu, một ngôi nhà cổ và hội quán Phúc Kiến, kể về thương cảng Hội An xưa. Khi phố lên đèn, cả nhóm học làm một chiếc đèn lồng nhỏ và thả hoa đăng trên sông Hoài. Nhịp đi chậm, có nhiều thời gian chụp ảnh.'),
    'Hội An', 180, 10, 'vi,en', 'meeting_point', 'Chùa Cầu, đầu phố Trần Phú',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ trong phố cổ',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Chợ đêm Nguyễn Hoàng',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Không gồm bữa ăn. Người dẫn gợi ý quán ăn tối gần chợ đêm.',
    'Xuất trình mã đặt chỗ cho người dẫn tại Chùa Cầu.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 7 (Hội An) --------------------------------------------
('c0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000005',
    'c2000000-0000-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000005',   -- Hội An, Trải nghiệm địa phương
    'Làng rau Trà Quế: đạp xe và học nấu ăn',
    CONCAT_WS(CHAR(10),
        'Đạp xe qua đồng lúa ra làng rau Trà Quế, làm vườn cùng nông dân và tự nấu bữa trưa kiểu Hội An.',
        '',
        'Từ trung tâm Hội An, nhóm đạp xe khoảng 4 km ra làng rau Trà Quế. Bạn được nông dân hướng dẫn xới đất, gánh nước tưới rau và tìm hiểu cách bón rau bằng rong sông. Phần cuối là lớp nấu ăn nhỏ: tự làm bánh xèo, gỏi cuốn và cùng ăn trưa trong vườn.'),
    'Hội An', 270, 8, 'vi,en', 'meeting_point', 'Bãi xe đạp cạnh chợ Hội An',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả (thiếu: guide_info, reschedule_terms)
    'Xe đạp, khoảng 4 km mỗi chiều',
    NULL,
    'Bãi xe đạp cạnh chợ Hội An',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bữa trưa tự nấu (bánh xèo, gỏi cuốn). Có thực đơn chay nếu báo trước.',
    'Xuất trình mã đặt chỗ khi nhận xe đạp.',
    NULL,
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 8 (TP. Hồ Chí Minh) -----------------------------------
('c0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000006',
    'c2000000-0000-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000004',   -- TP. Hồ Chí Minh, Về đêm
    'Sài Gòn về đêm trên xe máy',
    CONCAT_WS(CHAR(10),
        'Ngồi sau xe máy cùng người dẫn, đi qua các quận trung tâm và ăn tối như người Sài Gòn.',
        '',
        'Mỗi khách ngồi sau một tài xế kiêm người dẫn có kinh nghiệm. Nhóm đi qua quận 1, quận 4 và quận 5, ghé quán ốc, xe chè và một quán cà phê nhạc sống. Tour có mũ bảo hiểm đạt chuẩn, áo mưa và bảo hiểm du lịch cho từng khách.'),
    'TP. Hồ Chí Minh', 240, 6, 'vi,en', 'hotel_pickup', 'Khách sạn ở quận 1 hoặc quận 3',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe máy, mỗi khách ngồi sau một tài xế',
    'Tài xế kiêm người dẫn, nói tiếng Việt và tiếng Anh',
    'Khách sạn ở quận 1 hoặc quận 3',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Mang theo giấy tờ tùy thân (bản chụp cũng được) để làm bảo hiểm du lịch.',
    'Gồm ăn tối 4 món. Báo trước nếu ăn chay hoặc dị ứng hải sản.',
    'Xuất trình mã đặt chỗ cho tài xế khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ; trời mưa tour vẫn khởi hành, có áo mưa.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 9 (TP. Hồ Chí Minh) -----------------------------------
('c0000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000007',
    'c2000000-0000-4000-8000-000000000004', NULL,   -- TP. Hồ Chí Minh, chưa có loại hình
    'Chợ Lớn: hẻm nhỏ, hội quán và món Hoa',
    CONCAT_WS(CHAR(10),
        'Khám phá Chợ Lớn qua các hội quán, tiệm thuốc bắc lâu đời và món ăn của người Hoa.',
        '',
        'Tour đi bộ qua các con hẻm ở quận 5, ghé chùa Bà Thiên Hậu và vài hội quán, nghe chuyện về cộng đồng người Hoa ở Sài Gòn. Nhóm dừng chân ở một tiệm thuốc bắc và kết thúc bằng bữa ăn nhẹ với sủi cảo, há cảo. Lịch khởi hành đang được cập nhật.'),
    'TP. Hồ Chí Minh', 210, 10, 'vi,en,zh', 'meeting_point', 'Chùa Bà Thiên Hậu, đường Nguyễn Trãi, quận 5',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả (thiếu: cả 7 trường FR-02 / FR-05)
    NULL,
    NULL,
    NULL,
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    NULL,
    NULL,
    NULL,
    NULL,
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 10 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000010', 'b0000000-0000-4000-8000-000000000001',
    'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000006',   -- Hà Nội, Đạp xe
    'Đạp xe quanh Hồ Tây lúc bình minh',
    CONCAT_WS(CHAR(10),
        'Đạp xe một vòng Hồ Tây buổi sớm, ghé chùa Trấn Quốc và ăn sáng bún ốc.',
        '',
        'Nhóm nhận xe đạp ở đường Thanh Niên, đạp một vòng Hồ Tây khi mặt trời mọc, ghé chùa Trấn Quốc trước giờ đông khách và kết thúc bằng bát bún ốc nóng. Tour đang tạm ẩn để cập nhật lộ trình.'),
    'Hà Nội', 150, 8, 'vi,en', 'meeting_point', 'Đầu đường Thanh Niên, phía Hồ Tây',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 18)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe đạp',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Quán bún ốc gần Hồ Tây',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 18)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bữa sáng bún ốc.',
    'Xuất trình mã đặt chỗ khi nhận xe đạp ở đường Thanh Niên.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'pending');

-- ---------------------------------------------------------------------
-- 6. cancellation_policies (CHÍNH_SÁCH_HỦY)
--   id = số tour x 10 + phiên bản. Tour 4 có phiên bản 2 (thêm quy định dời lịch khi trời mưa lớn),
--   áp dụng cho đơn đặt trong 30 ngày gần đây.
-- ---------------------------------------------------------------------
INSERT INTO cancellation_policies (id, tour_id, free_before_hours, refund_percent, terms, version) VALUES
('f0000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000001', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0000-4000-8000-000000000021', 'c0000000-0000-4000-8000-000000000002', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0000-4000-8000-000000000031', 'c0000000-0000-4000-8000-000000000003', 48, 50, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 48 giờ. Hủy sau mốc này được hoàn 50% giá trị đơn.', 1),
('f0000000-0000-4000-8000-000000000041', 'c0000000-0000-4000-8000-000000000004', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0000-4000-8000-000000000042', 'c0000000-0000-4000-8000-000000000004', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền. Tour được dời lịch nếu trời mưa lớn, khách chọn lịch khác hoặc nhận lại toàn bộ tiền.', 2),
('f0000000-0000-4000-8000-000000000051', 'c0000000-0000-4000-8000-000000000005', 12, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 12 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0000-4000-8000-000000000061', 'c0000000-0000-4000-8000-000000000006', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0000-4000-8000-000000000071', 'c0000000-0000-4000-8000-000000000007', 24, 50, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này được hoàn 50% giá trị đơn.', 1),
('f0000000-0000-4000-8000-000000000081', 'c0000000-0000-4000-8000-000000000008', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0000-4000-8000-000000000091', 'c0000000-0000-4000-8000-000000000009', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0000-4000-8000-000000000101', 'c0000000-0000-4000-8000-000000000010', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1);

-- ---------------------------------------------------------------------
-- 7. schedules (LỊCH_KHỞI_HÀNH)
--   starts_at = ngày (so với hôm nay) + giờ khởi hành; ends_at = starts_at + duration_minutes của tour.
--   Lịch đặt được: status 'open', chưa khởi hành, remaining > 0, có vé đang bán.
--   Bị lọc: lịch 1 (đã qua), 2 (full), 7 (open nhưng remaining = 0), 15 và 34 (cancelled).
--   Lịch 101-128: lịch đã đi (completed) của các đơn có đánh giá.
-- ---------------------------------------------------------------------
INSERT INTO schedules (id, tour_id, starts_at, ends_at, capacity, remaining, status) VALUES
-- Tour 1 (240 phút)
-- lịch 1: đã qua -> completed
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '17:00:00'), TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '21:00:00'), 8, 2, 'completed'),
-- lịch 2: hết chỗ (full)
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '21:00:00'), 8, 0, 'full'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '21:00:00'), 8, 6, 'open'),
('d0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 11 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 11 DAY, '21:00:00'), 8, 3, 'open'),
-- lịch 6: cuối tuần, giá 690.000đ
('d0000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '21:00:00'), 8, 8, 'open'),
-- Tour 2 (180 phút)
-- lịch 7: open nhưng remaining = 0 -> bị lọc
('d0000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '18:00:00'), 6, 0, 'open'),
-- lịch 8: vé trẻ em ngừng bán
('d0000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '18:00:00'), 6, 4, 'open'),
('d0000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '18:00:00'), 6, 6, 'open'),
('d0000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '18:00:00'), 6, 2, 'open'),
-- Tour 3 (240 phút)
-- lịch 11: cùng ngày với lịch 12, khác giờ
('d0000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '18:00:00'), 4, 2, 'open'),
('d0000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '12:30:00'), 4, 4, 'open'),
('d0000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '12:30:00'), 4, 3, 'open'),
-- Tour 4 (300 phút)
('d0000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '05:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '10:00:00'), 10, 3, 'open'),
-- lịch 15: đã hủy
('d0000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '05:00:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '10:00:00'), 10, 7, 'cancelled'),
('d0000000-0000-4000-8000-000000000016', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '05:00:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '10:00:00'), 10, 7, 'open'),
('d0000000-0000-4000-8000-000000000017', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 23 DAY, '05:00:00'), TIMESTAMP(CURDATE() + INTERVAL 23 DAY, '10:00:00'), 10, 10, 'open'),
-- Tour 5 (210 phút)
('d0000000-0000-4000-8000-000000000018', 'c0000000-0000-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '22:00:00'), 12, 2, 'open'),
('d0000000-0000-4000-8000-000000000019', 'c0000000-0000-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '22:00:00'), 12, 8, 'open'),
('d0000000-0000-4000-8000-000000000020', 'c0000000-0000-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 15 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 15 DAY, '22:00:00'), 12, 12, 'open'),
('d0000000-0000-4000-8000-000000000021', 'c0000000-0000-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '22:00:00'), 12, 12, 'open'),
-- Tour 6 (180 phút)
('d0000000-0000-4000-8000-000000000022', 'c0000000-0000-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '16:30:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '19:30:00'), 10, 4, 'open'),
('d0000000-0000-4000-8000-000000000023', 'c0000000-0000-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '16:30:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '19:30:00'), 10, 8, 'open'),
('d0000000-0000-4000-8000-000000000024', 'c0000000-0000-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 12 DAY, '16:30:00'), TIMESTAMP(CURDATE() + INTERVAL 12 DAY, '19:30:00'), 10, 10, 'open'),
-- Tour 7 (270 phút)
('d0000000-0000-4000-8000-000000000025', 'c0000000-0000-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '12:30:00'), 8, 5, 'open'),
('d0000000-0000-4000-8000-000000000026', 'c0000000-0000-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '12:30:00'), 8, 8, 'open'),
('d0000000-0000-4000-8000-000000000027', 'c0000000-0000-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '12:30:00'), 8, 8, 'open'),
('d0000000-0000-4000-8000-000000000028', 'c0000000-0000-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '12:30:00'), 8, 8, 'open'),
-- Tour 8 (240 phút)
('d0000000-0000-4000-8000-000000000029', 'c0000000-0000-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '22:00:00'), 6, 2, 'open'),
('d0000000-0000-4000-8000-000000000030', 'c0000000-0000-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '22:00:00'), 6, 5, 'open'),
('d0000000-0000-4000-8000-000000000031', 'c0000000-0000-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '22:00:00'), 6, 6, 'open'),
('d0000000-0000-4000-8000-000000000032', 'c0000000-0000-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 20 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 20 DAY, '22:00:00'), 6, 6, 'open'),
('d0000000-0000-4000-8000-000000000033', 'c0000000-0000-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 27 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 27 DAY, '22:00:00'), 6, 6, 'open'),
-- Tour 9 (210 phút)
-- lịch 34: đã hủy -> tour 9 không có lịch đặt được
('d0000000-0000-4000-8000-000000000034', 'c0000000-0000-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '12:00:00'), 10, 10, 'cancelled'),
-- Tour 10 (150 phút)
('d0000000-0000-4000-8000-000000000035', 'c0000000-0000-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 3 DAY, '08:00:00'), 8, 6, 'open'),
('d0000000-0000-4000-8000-000000000036', 'c0000000-0000-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '08:00:00'), 8, 8, 'open'),
('d0000000-0000-4000-8000-000000000037', 'c0000000-0000-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '08:00:00'), 8, 8, 'open'),
-- Lịch đã đi của đơn có đánh giá - tour 1 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000101', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() - INTERVAL 46 DAY, '17:00:00'), TIMESTAMP(CURDATE() - INTERVAL 46 DAY, '21:00:00'), 8, 5, 'completed'),
('d0000000-0000-4000-8000-000000000102', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '17:00:00'), TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '21:00:00'), 8, 5, 'completed'),
('d0000000-0000-4000-8000-000000000103', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '17:00:00'), TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '21:00:00'), 8, 7, 'completed'),
('d0000000-0000-4000-8000-000000000104', 'c0000000-0000-4000-8000-000000000001',
    TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '17:00:00'), TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '21:00:00'), 8, 6, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 2 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000105', 'c0000000-0000-4000-8000-000000000002',
    TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '15:00:00'), TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '18:00:00'), 6, 4, 'completed'),
('d0000000-0000-4000-8000-000000000106', 'c0000000-0000-4000-8000-000000000002',
    TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '15:00:00'), TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '18:00:00'), 6, 4, 'completed'),
('d0000000-0000-4000-8000-000000000107', 'c0000000-0000-4000-8000-000000000002',
    TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '15:00:00'), TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '18:00:00'), 6, 4, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 3 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000108', 'c0000000-0000-4000-8000-000000000003',
    TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '08:30:00'), TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '12:30:00'), 4, 1, 'completed'),
('d0000000-0000-4000-8000-000000000109', 'c0000000-0000-4000-8000-000000000003',
    TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '08:30:00'), TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '12:30:00'), 4, 2, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 4 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000110', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '05:00:00'), TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '10:00:00'), 10, 8, 'completed'),
('d0000000-0000-4000-8000-000000000111', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '05:00:00'), TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '10:00:00'), 10, 9, 'completed'),
('d0000000-0000-4000-8000-000000000112', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() - INTERVAL 16 DAY, '05:00:00'), TIMESTAMP(CURDATE() - INTERVAL 16 DAY, '10:00:00'), 10, 7, 'completed'),
('d0000000-0000-4000-8000-000000000113', 'c0000000-0000-4000-8000-000000000004',
    TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '05:00:00'), TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '10:00:00'), 10, 8, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 5 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000114', 'c0000000-0000-4000-8000-000000000005',
    TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '18:30:00'), TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '22:00:00'), 12, 10, 'completed'),
('d0000000-0000-4000-8000-000000000115', 'c0000000-0000-4000-8000-000000000005',
    TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '18:30:00'), TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '22:00:00'), 12, 11, 'completed'),
('d0000000-0000-4000-8000-000000000116', 'c0000000-0000-4000-8000-000000000005',
    TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '18:30:00'), TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '22:00:00'), 12, 9, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 6 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000117', 'c0000000-0000-4000-8000-000000000006',
    TIMESTAMP(CURDATE() - INTERVAL 91 DAY, '16:30:00'), TIMESTAMP(CURDATE() - INTERVAL 91 DAY, '19:30:00'), 10, 8, 'completed'),
('d0000000-0000-4000-8000-000000000118', 'c0000000-0000-4000-8000-000000000006',
    TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '16:30:00'), TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '19:30:00'), 10, 8, 'completed'),
('d0000000-0000-4000-8000-000000000119', 'c0000000-0000-4000-8000-000000000006',
    TIMESTAMP(CURDATE() - INTERVAL 29 DAY, '16:30:00'), TIMESTAMP(CURDATE() - INTERVAL 29 DAY, '19:30:00'), 10, 8, 'completed'),
('d0000000-0000-4000-8000-000000000120', 'c0000000-0000-4000-8000-000000000006',
    TIMESTAMP(CURDATE() - INTERVAL 9 DAY, '16:30:00'), TIMESTAMP(CURDATE() - INTERVAL 9 DAY, '19:30:00'), 10, 9, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 7 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000121', 'c0000000-0000-4000-8000-000000000007',
    TIMESTAMP(CURDATE() - INTERVAL 42 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 42 DAY, '12:30:00'), 8, 6, 'completed'),
('d0000000-0000-4000-8000-000000000122', 'c0000000-0000-4000-8000-000000000007',
    TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '12:30:00'), 8, 7, 'completed'),
('d0000000-0000-4000-8000-000000000123', 'c0000000-0000-4000-8000-000000000007',
    TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '12:30:00'), 8, 4, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 8 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000124', 'c0000000-0000-4000-8000-000000000008',
    TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '18:00:00'), TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '22:00:00'), 6, 5, 'completed'),
('d0000000-0000-4000-8000-000000000125', 'c0000000-0000-4000-8000-000000000008',
    TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '18:00:00'), TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '22:00:00'), 6, 4, 'completed'),
-- Lịch đã đi của đơn có đánh giá - tour 10 (ngày đi = ngày viết đánh giá - 1)
('d0000000-0000-4000-8000-000000000126', 'c0000000-0000-4000-8000-000000000010',
    TIMESTAMP(CURDATE() - INTERVAL 181 DAY, '05:30:00'), TIMESTAMP(CURDATE() - INTERVAL 181 DAY, '08:00:00'), 8, 6, 'completed'),
('d0000000-0000-4000-8000-000000000127', 'c0000000-0000-4000-8000-000000000010',
    TIMESTAMP(CURDATE() - INTERVAL 151 DAY, '05:30:00'), TIMESTAMP(CURDATE() - INTERVAL 151 DAY, '08:00:00'), 8, 7, 'completed'),
('d0000000-0000-4000-8000-000000000128', 'c0000000-0000-4000-8000-000000000010',
    TIMESTAMP(CURDATE() - INTERVAL 101 DAY, '05:30:00'), TIMESTAMP(CURDATE() - INTERVAL 101 DAY, '08:00:00'), 8, 5, 'completed');

-- ---------------------------------------------------------------------
-- 8. ticket_types (VÉ_THEO_LỊCH)
--   adult: từ 12 tuổi (tour 8 từ 16 tuổi), giá vé của tour; child: 4-11 tuổi, 70% giá người lớn
--   làm tròn tới 10.000đ. Tour 3 và 8 chỉ bán vé người lớn.
--   Lịch 6 (tour 1, cuối tuần) giá người lớn 690.000đ. Vé trẻ em của lịch 8 (tour 2) ngừng bán.
-- ---------------------------------------------------------------------
INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active) VALUES
-- Tour 1
('e0000000-0000-4000-8000-000000000011', 'd0000000-0000-4000-8000-000000000001', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000000012', 'd0000000-0000-4000-8000-000000000001', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000000021', 'd0000000-0000-4000-8000-000000000002', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000000022', 'd0000000-0000-4000-8000-000000000002', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000000031', 'd0000000-0000-4000-8000-000000000003', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000000032', 'd0000000-0000-4000-8000-000000000003', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000000041', 'd0000000-0000-4000-8000-000000000004', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000000042', 'd0000000-0000-4000-8000-000000000004', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000000051', 'd0000000-0000-4000-8000-000000000005', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000000052', 'd0000000-0000-4000-8000-000000000005', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000000061', 'd0000000-0000-4000-8000-000000000006', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0000-4000-8000-000000000062', 'd0000000-0000-4000-8000-000000000006', 'child', 4, 11, 480000, TRUE),
-- Tour 2
('e0000000-0000-4000-8000-000000000071', 'd0000000-0000-4000-8000-000000000007', 'adult', 12, NULL, 720000, TRUE),
('e0000000-0000-4000-8000-000000000072', 'd0000000-0000-4000-8000-000000000007', 'child', 4, 11, 500000, TRUE),
('e0000000-0000-4000-8000-000000000081', 'd0000000-0000-4000-8000-000000000008', 'adult', 12, NULL, 720000, TRUE),
('e0000000-0000-4000-8000-000000000082', 'd0000000-0000-4000-8000-000000000008', 'child', 4, 11, 500000, FALSE),
('e0000000-0000-4000-8000-000000000091', 'd0000000-0000-4000-8000-000000000009', 'adult', 12, NULL, 720000, TRUE),
('e0000000-0000-4000-8000-000000000092', 'd0000000-0000-4000-8000-000000000009', 'child', 4, 11, 500000, TRUE),
('e0000000-0000-4000-8000-000000000101', 'd0000000-0000-4000-8000-000000000010', 'adult', 12, NULL, 720000, TRUE),
('e0000000-0000-4000-8000-000000000102', 'd0000000-0000-4000-8000-000000000010', 'child', 4, 11, 500000, TRUE),
-- Tour 3
('e0000000-0000-4000-8000-000000000111', 'd0000000-0000-4000-8000-000000000011', 'adult', 12, NULL, 900000, TRUE),
('e0000000-0000-4000-8000-000000000121', 'd0000000-0000-4000-8000-000000000012', 'adult', 12, NULL, 900000, TRUE),
('e0000000-0000-4000-8000-000000000131', 'd0000000-0000-4000-8000-000000000013', 'adult', 12, NULL, 900000, TRUE),
-- Tour 4
('e0000000-0000-4000-8000-000000000141', 'd0000000-0000-4000-8000-000000000014', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000000142', 'd0000000-0000-4000-8000-000000000014', 'child', 4, 11, 390000, TRUE),
('e0000000-0000-4000-8000-000000000151', 'd0000000-0000-4000-8000-000000000015', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000000152', 'd0000000-0000-4000-8000-000000000015', 'child', 4, 11, 390000, TRUE),
('e0000000-0000-4000-8000-000000000161', 'd0000000-0000-4000-8000-000000000016', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000000162', 'd0000000-0000-4000-8000-000000000016', 'child', 4, 11, 390000, TRUE),
('e0000000-0000-4000-8000-000000000171', 'd0000000-0000-4000-8000-000000000017', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000000172', 'd0000000-0000-4000-8000-000000000017', 'child', 4, 11, 390000, TRUE),
-- Tour 5
('e0000000-0000-4000-8000-000000000181', 'd0000000-0000-4000-8000-000000000018', 'adult', 12, NULL, 480000, TRUE),
('e0000000-0000-4000-8000-000000000182', 'd0000000-0000-4000-8000-000000000018', 'child', 4, 11, 340000, TRUE),
('e0000000-0000-4000-8000-000000000191', 'd0000000-0000-4000-8000-000000000019', 'adult', 12, NULL, 480000, TRUE),
('e0000000-0000-4000-8000-000000000192', 'd0000000-0000-4000-8000-000000000019', 'child', 4, 11, 340000, TRUE),
('e0000000-0000-4000-8000-000000000201', 'd0000000-0000-4000-8000-000000000020', 'adult', 12, NULL, 480000, TRUE),
('e0000000-0000-4000-8000-000000000202', 'd0000000-0000-4000-8000-000000000020', 'child', 4, 11, 340000, TRUE),
('e0000000-0000-4000-8000-000000000211', 'd0000000-0000-4000-8000-000000000021', 'adult', 12, NULL, 480000, TRUE),
('e0000000-0000-4000-8000-000000000212', 'd0000000-0000-4000-8000-000000000021', 'child', 4, 11, 340000, TRUE),
-- Tour 6
('e0000000-0000-4000-8000-000000000221', 'd0000000-0000-4000-8000-000000000022', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0000-4000-8000-000000000222', 'd0000000-0000-4000-8000-000000000022', 'child', 4, 11, 410000, TRUE),
('e0000000-0000-4000-8000-000000000231', 'd0000000-0000-4000-8000-000000000023', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0000-4000-8000-000000000232', 'd0000000-0000-4000-8000-000000000023', 'child', 4, 11, 410000, TRUE),
('e0000000-0000-4000-8000-000000000241', 'd0000000-0000-4000-8000-000000000024', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0000-4000-8000-000000000242', 'd0000000-0000-4000-8000-000000000024', 'child', 4, 11, 410000, TRUE),
-- Tour 7
('e0000000-0000-4000-8000-000000000251', 'd0000000-0000-4000-8000-000000000025', 'adult', 12, NULL, 750000, TRUE),
('e0000000-0000-4000-8000-000000000252', 'd0000000-0000-4000-8000-000000000025', 'child', 4, 11, 530000, TRUE),
('e0000000-0000-4000-8000-000000000261', 'd0000000-0000-4000-8000-000000000026', 'adult', 12, NULL, 750000, TRUE),
('e0000000-0000-4000-8000-000000000262', 'd0000000-0000-4000-8000-000000000026', 'child', 4, 11, 530000, TRUE),
('e0000000-0000-4000-8000-000000000271', 'd0000000-0000-4000-8000-000000000027', 'adult', 12, NULL, 750000, TRUE),
('e0000000-0000-4000-8000-000000000272', 'd0000000-0000-4000-8000-000000000027', 'child', 4, 11, 530000, TRUE),
('e0000000-0000-4000-8000-000000000281', 'd0000000-0000-4000-8000-000000000028', 'adult', 12, NULL, 750000, TRUE),
('e0000000-0000-4000-8000-000000000282', 'd0000000-0000-4000-8000-000000000028', 'child', 4, 11, 530000, TRUE),
-- Tour 8
('e0000000-0000-4000-8000-000000000291', 'd0000000-0000-4000-8000-000000000029', 'adult', 16, NULL, 850000, TRUE),
('e0000000-0000-4000-8000-000000000301', 'd0000000-0000-4000-8000-000000000030', 'adult', 16, NULL, 850000, TRUE),
('e0000000-0000-4000-8000-000000000311', 'd0000000-0000-4000-8000-000000000031', 'adult', 16, NULL, 850000, TRUE),
('e0000000-0000-4000-8000-000000000321', 'd0000000-0000-4000-8000-000000000032', 'adult', 16, NULL, 850000, TRUE),
('e0000000-0000-4000-8000-000000000331', 'd0000000-0000-4000-8000-000000000033', 'adult', 16, NULL, 850000, TRUE),
-- Tour 9
('e0000000-0000-4000-8000-000000000341', 'd0000000-0000-4000-8000-000000000034', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0000-4000-8000-000000000342', 'd0000000-0000-4000-8000-000000000034', 'child', 4, 11, 360000, TRUE),
-- Tour 10
('e0000000-0000-4000-8000-000000000351', 'd0000000-0000-4000-8000-000000000035', 'adult', 12, NULL, 400000, TRUE),
('e0000000-0000-4000-8000-000000000352', 'd0000000-0000-4000-8000-000000000035', 'child', 4, 11, 280000, TRUE),
('e0000000-0000-4000-8000-000000000361', 'd0000000-0000-4000-8000-000000000036', 'adult', 12, NULL, 400000, TRUE),
('e0000000-0000-4000-8000-000000000362', 'd0000000-0000-4000-8000-000000000036', 'child', 4, 11, 280000, TRUE),
('e0000000-0000-4000-8000-000000000371', 'd0000000-0000-4000-8000-000000000037', 'adult', 12, NULL, 400000, TRUE),
('e0000000-0000-4000-8000-000000000372', 'd0000000-0000-4000-8000-000000000037', 'child', 4, 11, 280000, TRUE),
-- Vé của các lịch đã đi (101-128)
('e0000000-0000-4000-8000-000000001011', 'd0000000-0000-4000-8000-000000000101', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000001012', 'd0000000-0000-4000-8000-000000000101', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000001021', 'd0000000-0000-4000-8000-000000000102', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000001022', 'd0000000-0000-4000-8000-000000000102', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000001031', 'd0000000-0000-4000-8000-000000000103', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000001032', 'd0000000-0000-4000-8000-000000000103', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000001041', 'd0000000-0000-4000-8000-000000000104', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0000-4000-8000-000000001042', 'd0000000-0000-4000-8000-000000000104', 'child', 4, 11, 460000, TRUE),
('e0000000-0000-4000-8000-000000001051', 'd0000000-0000-4000-8000-000000000105', 'adult', 12, NULL, 720000, TRUE),
('e0000000-0000-4000-8000-000000001052', 'd0000000-0000-4000-8000-000000000105', 'child', 4, 11, 500000, TRUE),
('e0000000-0000-4000-8000-000000001061', 'd0000000-0000-4000-8000-000000000106', 'adult', 12, NULL, 720000, TRUE),
('e0000000-0000-4000-8000-000000001062', 'd0000000-0000-4000-8000-000000000106', 'child', 4, 11, 500000, TRUE),
('e0000000-0000-4000-8000-000000001071', 'd0000000-0000-4000-8000-000000000107', 'adult', 12, NULL, 720000, TRUE),
('e0000000-0000-4000-8000-000000001072', 'd0000000-0000-4000-8000-000000000107', 'child', 4, 11, 500000, TRUE),
('e0000000-0000-4000-8000-000000001081', 'd0000000-0000-4000-8000-000000000108', 'adult', 12, NULL, 900000, TRUE),
('e0000000-0000-4000-8000-000000001091', 'd0000000-0000-4000-8000-000000000109', 'adult', 12, NULL, 900000, TRUE),
('e0000000-0000-4000-8000-000000001101', 'd0000000-0000-4000-8000-000000000110', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000001102', 'd0000000-0000-4000-8000-000000000110', 'child', 4, 11, 390000, TRUE),
('e0000000-0000-4000-8000-000000001111', 'd0000000-0000-4000-8000-000000000111', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000001112', 'd0000000-0000-4000-8000-000000000111', 'child', 4, 11, 390000, TRUE),
('e0000000-0000-4000-8000-000000001121', 'd0000000-0000-4000-8000-000000000112', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000001122', 'd0000000-0000-4000-8000-000000000112', 'child', 4, 11, 390000, TRUE),
('e0000000-0000-4000-8000-000000001131', 'd0000000-0000-4000-8000-000000000113', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0000-4000-8000-000000001132', 'd0000000-0000-4000-8000-000000000113', 'child', 4, 11, 390000, TRUE),
('e0000000-0000-4000-8000-000000001141', 'd0000000-0000-4000-8000-000000000114', 'adult', 12, NULL, 480000, TRUE),
('e0000000-0000-4000-8000-000000001142', 'd0000000-0000-4000-8000-000000000114', 'child', 4, 11, 340000, TRUE),
('e0000000-0000-4000-8000-000000001151', 'd0000000-0000-4000-8000-000000000115', 'adult', 12, NULL, 480000, TRUE),
('e0000000-0000-4000-8000-000000001152', 'd0000000-0000-4000-8000-000000000115', 'child', 4, 11, 340000, TRUE),
('e0000000-0000-4000-8000-000000001161', 'd0000000-0000-4000-8000-000000000116', 'adult', 12, NULL, 480000, TRUE),
('e0000000-0000-4000-8000-000000001162', 'd0000000-0000-4000-8000-000000000116', 'child', 4, 11, 340000, TRUE),
('e0000000-0000-4000-8000-000000001171', 'd0000000-0000-4000-8000-000000000117', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0000-4000-8000-000000001172', 'd0000000-0000-4000-8000-000000000117', 'child', 4, 11, 410000, TRUE),
('e0000000-0000-4000-8000-000000001181', 'd0000000-0000-4000-8000-000000000118', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0000-4000-8000-000000001182', 'd0000000-0000-4000-8000-000000000118', 'child', 4, 11, 410000, TRUE),
('e0000000-0000-4000-8000-000000001191', 'd0000000-0000-4000-8000-000000000119', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0000-4000-8000-000000001192', 'd0000000-0000-4000-8000-000000000119', 'child', 4, 11, 410000, TRUE),
('e0000000-0000-4000-8000-000000001201', 'd0000000-0000-4000-8000-000000000120', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0000-4000-8000-000000001202', 'd0000000-0000-4000-8000-000000000120', 'child', 4, 11, 410000, TRUE),
('e0000000-0000-4000-8000-000000001211', 'd0000000-0000-4000-8000-000000000121', 'adult', 12, NULL, 750000, TRUE),
('e0000000-0000-4000-8000-000000001212', 'd0000000-0000-4000-8000-000000000121', 'child', 4, 11, 530000, TRUE),
('e0000000-0000-4000-8000-000000001221', 'd0000000-0000-4000-8000-000000000122', 'adult', 12, NULL, 750000, TRUE),
('e0000000-0000-4000-8000-000000001222', 'd0000000-0000-4000-8000-000000000122', 'child', 4, 11, 530000, TRUE),
('e0000000-0000-4000-8000-000000001231', 'd0000000-0000-4000-8000-000000000123', 'adult', 12, NULL, 750000, TRUE),
('e0000000-0000-4000-8000-000000001232', 'd0000000-0000-4000-8000-000000000123', 'child', 4, 11, 530000, TRUE),
('e0000000-0000-4000-8000-000000001241', 'd0000000-0000-4000-8000-000000000124', 'adult', 16, NULL, 850000, TRUE),
('e0000000-0000-4000-8000-000000001251', 'd0000000-0000-4000-8000-000000000125', 'adult', 16, NULL, 850000, TRUE),
('e0000000-0000-4000-8000-000000001261', 'd0000000-0000-4000-8000-000000000126', 'adult', 12, NULL, 400000, TRUE),
('e0000000-0000-4000-8000-000000001262', 'd0000000-0000-4000-8000-000000000126', 'child', 4, 11, 280000, TRUE),
('e0000000-0000-4000-8000-000000001271', 'd0000000-0000-4000-8000-000000000127', 'adult', 12, NULL, 400000, TRUE),
('e0000000-0000-4000-8000-000000001272', 'd0000000-0000-4000-8000-000000000127', 'child', 4, 11, 280000, TRUE),
('e0000000-0000-4000-8000-000000001281', 'd0000000-0000-4000-8000-000000000128', 'adult', 12, NULL, 400000, TRUE),
('e0000000-0000-4000-8000-000000001282', 'd0000000-0000-4000-8000-000000000128', 'child', 4, 11, 280000, TRUE);

-- ---------------------------------------------------------------------
-- 9. bookings (ĐƠN_ĐẶT_TOUR)
--   Đơn 1-29: 'completed' (đã đi tour). Đơn 30: 'cancelled' (lịch 4 của tour 1, đã hoàn tiền).
--   total_vnd = tổng line_total_vnd. policy_version = phiên bản chính sách hủy lúc đặt.
--   Mỗi đơn thuộc một tài khoản khách hàng: user_id = khách hàng 100 + N (đơn N); contact_name /
--   contact_email trùng tên và email của tài khoản. Khách chưa đăng nhập (chế độ khách) chỉ xem
--   tour, không đặt được.
-- ---------------------------------------------------------------------
INSERT INTO bookings (id, user_id, schedule_id, code, contact_name, contact_email, contact_phone,
                      status, total_vnd, policy_version, hold_expires_at) VALUES
-- Tour 1
('10000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000101', 'd0000000-0000-4000-8000-000000000101',
    'LT812768', 'Quốc Huy', 'quoc.huy@localtour.test', '0000000101', 'completed', 1760000, 1, NULL),
('10000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000102', 'd0000000-0000-4000-8000-000000000102',
    'LT469739', 'Lan Phương', 'lan.phuong@localtour.test', '0000000102', 'completed', 1950000, 1, NULL),
('10000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000103', 'd0000000-0000-4000-8000-000000000103',
    'LT707426', 'Thu Trang', 'thu.trang@localtour.test', '0000000103', 'completed', 650000, 1, NULL),
('10000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000104', 'd0000000-0000-4000-8000-000000000104',
    'LT396700', 'Minh Anh', 'minh.anh@localtour.test', '0000000104', 'completed', 1300000, 1, NULL),
-- Tour 2
('10000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000105', 'd0000000-0000-4000-8000-000000000105',
    'LT995361', 'Hoàng Yến', 'hoang.yen@localtour.test', '0000000105', 'completed', 1440000, 1, NULL),
('10000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000106', 'd0000000-0000-4000-8000-000000000106',
    'LT280930', 'Đức Thịnh', 'duc.thinh@localtour.test', '0000000106', 'completed', 1220000, 1, NULL),
('10000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000107', 'd0000000-0000-4000-8000-000000000107',
    'LT150872', 'Bảo Ngọc', 'bao.ngoc@localtour.test', '0000000107', 'completed', 1440000, 1, NULL),
-- Tour 3
('10000000-0000-4000-8000-000000000008', 'a0000000-0000-4000-8000-000000000108', 'd0000000-0000-4000-8000-000000000108',
    'LT963617', 'Gia Bảo', 'gia.bao@localtour.test', '0000000108', 'completed', 2700000, 1, NULL),
('10000000-0000-4000-8000-000000000009', 'a0000000-0000-4000-8000-000000000109', 'd0000000-0000-4000-8000-000000000109',
    'LT353315', 'Khánh Linh', 'khanh.linh@localtour.test', '0000000109', 'completed', 1800000, 1, NULL),
-- Tour 4
('10000000-0000-4000-8000-000000000010', 'a0000000-0000-4000-8000-000000000110', 'd0000000-0000-4000-8000-000000000110',
    'LT341641', 'Hải Đăng', 'hai.dang@localtour.test', '0000000110', 'completed', 1100000, 1, NULL),
('10000000-0000-4000-8000-000000000011', 'a0000000-0000-4000-8000-000000000111', 'd0000000-0000-4000-8000-000000000111',
    'LT345953', 'Thanh Hà', 'thanh.ha@localtour.test', '0000000111', 'completed', 550000, 1, NULL),
('10000000-0000-4000-8000-000000000012', 'a0000000-0000-4000-8000-000000000112', 'd0000000-0000-4000-8000-000000000112',
    'LT103067', 'Văn Long', 'van.long@localtour.test', '0000000112', 'completed', 1490000, 2, NULL),
('10000000-0000-4000-8000-000000000013', 'a0000000-0000-4000-8000-000000000113', 'd0000000-0000-4000-8000-000000000113',
    'LT848329', 'Ngọc Mai', 'ngoc.mai@localtour.test', '0000000113', 'completed', 1100000, 2, NULL),
-- Tour 5
('10000000-0000-4000-8000-000000000014', 'a0000000-0000-4000-8000-000000000114', 'd0000000-0000-4000-8000-000000000114',
    'LT965599', 'Tuấn Kiệt', 'tuan.kiet@localtour.test', '0000000114', 'completed', 960000, 1, NULL),
('10000000-0000-4000-8000-000000000015', 'a0000000-0000-4000-8000-000000000115', 'd0000000-0000-4000-8000-000000000115',
    'LT673352', 'Mai Chi', 'mai.chi@localtour.test', '0000000115', 'completed', 480000, 1, NULL),
('10000000-0000-4000-8000-000000000016', 'a0000000-0000-4000-8000-000000000116', 'd0000000-0000-4000-8000-000000000116',
    'LT238066', 'Phương Thảo', 'phuong.thao@localtour.test', '0000000116', 'completed', 1440000, 1, NULL),
-- Tour 6
('10000000-0000-4000-8000-000000000017', 'a0000000-0000-4000-8000-000000000117', 'd0000000-0000-4000-8000-000000000117',
    'LT161961', 'Kim Ngân', 'kim.ngan@localtour.test', '0000000117', 'completed', 1180000, 1, NULL),
('10000000-0000-4000-8000-000000000018', 'a0000000-0000-4000-8000-000000000118', 'd0000000-0000-4000-8000-000000000118',
    'LT308511', 'Trọng Nghĩa', 'trong.nghia@localtour.test', '0000000118', 'completed', 1000000, 1, NULL),
('10000000-0000-4000-8000-000000000019', 'a0000000-0000-4000-8000-000000000119', 'd0000000-0000-4000-8000-000000000119',
    'LT302797', 'Thảo Vy', 'thao.vy@localtour.test', '0000000119', 'completed', 1180000, 1, NULL),
('10000000-0000-4000-8000-000000000020', 'a0000000-0000-4000-8000-000000000120', 'd0000000-0000-4000-8000-000000000120',
    'LT423521', 'Nhật Minh', 'nhat.minh@localtour.test', '0000000120', 'completed', 590000, 1, NULL),
-- Tour 7
('10000000-0000-4000-8000-000000000021', 'a0000000-0000-4000-8000-000000000121', 'd0000000-0000-4000-8000-000000000121',
    'LT770177', 'Diễm My', 'diem.my@localtour.test', '0000000121', 'completed', 1500000, 1, NULL),
('10000000-0000-4000-8000-000000000022', 'a0000000-0000-4000-8000-000000000122', 'd0000000-0000-4000-8000-000000000122',
    'LT836154', 'Hữu Phước', 'huu.phuoc@localtour.test', '0000000122', 'completed', 750000, 1, NULL),
('10000000-0000-4000-8000-000000000023', 'a0000000-0000-4000-8000-000000000123', 'd0000000-0000-4000-8000-000000000123',
    'LT970081', 'Anh Thư', 'anh.thu@localtour.test', '0000000123', 'completed', 2560000, 1, NULL),
-- Tour 8
('10000000-0000-4000-8000-000000000024', 'a0000000-0000-4000-8000-000000000124', 'd0000000-0000-4000-8000-000000000124',
    'LT789608', 'Thanh Tùng', 'thanh.tung@localtour.test', '0000000124', 'completed', 850000, 1, NULL),
('10000000-0000-4000-8000-000000000025', 'a0000000-0000-4000-8000-000000000125', 'd0000000-0000-4000-8000-000000000125',
    'LT753275', 'Quỳnh Như', 'quynh.nhu@localtour.test', '0000000125', 'completed', 1700000, 1, NULL),
-- Tour 10
('10000000-0000-4000-8000-000000000026', 'a0000000-0000-4000-8000-000000000126', 'd0000000-0000-4000-8000-000000000126',
    'LT211777', 'Bích Ngọc', 'bich.ngoc@localtour.test', '0000000126', 'completed', 800000, 1, NULL),
('10000000-0000-4000-8000-000000000027', 'a0000000-0000-4000-8000-000000000127', 'd0000000-0000-4000-8000-000000000127',
    'LT876132', 'Hoài Nam', 'hoai.nam@localtour.test', '0000000127', 'completed', 400000, 1, NULL),
('10000000-0000-4000-8000-000000000028', 'a0000000-0000-4000-8000-000000000128', 'd0000000-0000-4000-8000-000000000128',
    'LT302831', 'Thu Hằng', 'thu.hang@localtour.test', '0000000128', 'completed', 1200000, 1, NULL),
-- Đơn có đánh giá đang chờ duyệt
('10000000-0000-4000-8000-000000000029', 'a0000000-0000-4000-8000-000000000129', 'd0000000-0000-4000-8000-000000000001',
    'LT893219', 'Đình Khoa', 'dinh.khoa@localtour.test', '0000000129', 'completed', 650000, 1, NULL),
-- Đơn đã hủy
('10000000-0000-4000-8000-000000000030', 'a0000000-0000-4000-8000-000000000130', 'd0000000-0000-4000-8000-000000000004',
    'LT257589', 'Minh Châu', 'minh.chau@localtour.test', '0000000130', 'cancelled', 1300000, 1, NULL);

-- ---------------------------------------------------------------------
-- 10. booking_lines (DÒNG_ĐƠN)
--   line_total_vnd = quantity x unit_price_vnd.
-- ---------------------------------------------------------------------
INSERT INTO booking_lines (id, booking_id, ticket_type_id, quantity, unit_price_vnd, line_total_vnd) VALUES
('20000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000001011', 2, 650000, 1300000),
('20000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000001012', 1, 460000, 460000),
('20000000-0000-4000-8000-000000000021', '10000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000001021', 3, 650000, 1950000),
('20000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000001031', 1, 650000, 650000),
('20000000-0000-4000-8000-000000000041', '10000000-0000-4000-8000-000000000004', 'e0000000-0000-4000-8000-000000001041', 2, 650000, 1300000),
('20000000-0000-4000-8000-000000000051', '10000000-0000-4000-8000-000000000005', 'e0000000-0000-4000-8000-000000001051', 2, 720000, 1440000),
('20000000-0000-4000-8000-000000000061', '10000000-0000-4000-8000-000000000006', 'e0000000-0000-4000-8000-000000001061', 1, 720000, 720000),
('20000000-0000-4000-8000-000000000062', '10000000-0000-4000-8000-000000000006', 'e0000000-0000-4000-8000-000000001062', 1, 500000, 500000),
('20000000-0000-4000-8000-000000000071', '10000000-0000-4000-8000-000000000007', 'e0000000-0000-4000-8000-000000001071', 2, 720000, 1440000),
('20000000-0000-4000-8000-000000000081', '10000000-0000-4000-8000-000000000008', 'e0000000-0000-4000-8000-000000001081', 3, 900000, 2700000),
('20000000-0000-4000-8000-000000000091', '10000000-0000-4000-8000-000000000009', 'e0000000-0000-4000-8000-000000001091', 2, 900000, 1800000),
('20000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000000010', 'e0000000-0000-4000-8000-000000001101', 2, 550000, 1100000),
('20000000-0000-4000-8000-000000000111', '10000000-0000-4000-8000-000000000011', 'e0000000-0000-4000-8000-000000001111', 1, 550000, 550000),
('20000000-0000-4000-8000-000000000121', '10000000-0000-4000-8000-000000000012', 'e0000000-0000-4000-8000-000000001121', 2, 550000, 1100000),
('20000000-0000-4000-8000-000000000122', '10000000-0000-4000-8000-000000000012', 'e0000000-0000-4000-8000-000000001122', 1, 390000, 390000),
('20000000-0000-4000-8000-000000000131', '10000000-0000-4000-8000-000000000013', 'e0000000-0000-4000-8000-000000001131', 2, 550000, 1100000),
('20000000-0000-4000-8000-000000000141', '10000000-0000-4000-8000-000000000014', 'e0000000-0000-4000-8000-000000001141', 2, 480000, 960000),
('20000000-0000-4000-8000-000000000151', '10000000-0000-4000-8000-000000000015', 'e0000000-0000-4000-8000-000000001151', 1, 480000, 480000),
('20000000-0000-4000-8000-000000000161', '10000000-0000-4000-8000-000000000016', 'e0000000-0000-4000-8000-000000001161', 3, 480000, 1440000),
('20000000-0000-4000-8000-000000000171', '10000000-0000-4000-8000-000000000017', 'e0000000-0000-4000-8000-000000001171', 2, 590000, 1180000),
('20000000-0000-4000-8000-000000000181', '10000000-0000-4000-8000-000000000018', 'e0000000-0000-4000-8000-000000001181', 1, 590000, 590000),
('20000000-0000-4000-8000-000000000182', '10000000-0000-4000-8000-000000000018', 'e0000000-0000-4000-8000-000000001182', 1, 410000, 410000),
('20000000-0000-4000-8000-000000000191', '10000000-0000-4000-8000-000000000019', 'e0000000-0000-4000-8000-000000001191', 2, 590000, 1180000),
('20000000-0000-4000-8000-000000000201', '10000000-0000-4000-8000-000000000020', 'e0000000-0000-4000-8000-000000001201', 1, 590000, 590000),
('20000000-0000-4000-8000-000000000211', '10000000-0000-4000-8000-000000000021', 'e0000000-0000-4000-8000-000000001211', 2, 750000, 1500000),
('20000000-0000-4000-8000-000000000221', '10000000-0000-4000-8000-000000000022', 'e0000000-0000-4000-8000-000000001221', 1, 750000, 750000),
('20000000-0000-4000-8000-000000000231', '10000000-0000-4000-8000-000000000023', 'e0000000-0000-4000-8000-000000001231', 2, 750000, 1500000),
('20000000-0000-4000-8000-000000000232', '10000000-0000-4000-8000-000000000023', 'e0000000-0000-4000-8000-000000001232', 2, 530000, 1060000),
('20000000-0000-4000-8000-000000000241', '10000000-0000-4000-8000-000000000024', 'e0000000-0000-4000-8000-000000001241', 1, 850000, 850000),
('20000000-0000-4000-8000-000000000251', '10000000-0000-4000-8000-000000000025', 'e0000000-0000-4000-8000-000000001251', 2, 850000, 1700000),
('20000000-0000-4000-8000-000000000261', '10000000-0000-4000-8000-000000000026', 'e0000000-0000-4000-8000-000000001261', 2, 400000, 800000),
('20000000-0000-4000-8000-000000000271', '10000000-0000-4000-8000-000000000027', 'e0000000-0000-4000-8000-000000001271', 1, 400000, 400000),
('20000000-0000-4000-8000-000000000281', '10000000-0000-4000-8000-000000000028', 'e0000000-0000-4000-8000-000000001281', 3, 400000, 1200000),
('20000000-0000-4000-8000-000000000291', '10000000-0000-4000-8000-000000000029', 'e0000000-0000-4000-8000-000000000011', 1, 650000, 650000),
('20000000-0000-4000-8000-000000000301', '10000000-0000-4000-8000-000000000030', 'e0000000-0000-4000-8000-000000000041', 2, 650000, 1300000);

-- ---------------------------------------------------------------------
-- 11. passengers (HÀNH_KHÁCH)
--   Mỗi vé một hành khách; người đặt là hành khách đầu tiên.
-- ---------------------------------------------------------------------
INSERT INTO passengers (id, booking_id, full_name, age_group, special_request) VALUES
('30000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000001', 'Quốc Huy', 'adult', NULL),
('30000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000001', 'Thanh Bình', 'adult', NULL),
('30000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000001', 'Gia Hân', 'child', NULL),
('30000000-0000-4000-8000-000000000021', '10000000-0000-4000-8000-000000000002', 'Lan Phương', 'adult', NULL),
('30000000-0000-4000-8000-000000000022', '10000000-0000-4000-8000-000000000002', 'Văn Hùng', 'adult', NULL),
('30000000-0000-4000-8000-000000000023', '10000000-0000-4000-8000-000000000002', 'Thị Hoa', 'adult', 'Không ăn được đồ cay.'),
('30000000-0000-4000-8000-000000000031', '10000000-0000-4000-8000-000000000003', 'Thu Trang', 'adult', NULL),
('30000000-0000-4000-8000-000000000041', '10000000-0000-4000-8000-000000000004', 'Minh Anh', 'adult', NULL),
('30000000-0000-4000-8000-000000000042', '10000000-0000-4000-8000-000000000004', 'Đức Anh', 'adult', NULL),
('30000000-0000-4000-8000-000000000051', '10000000-0000-4000-8000-000000000005', 'Hoàng Yến', 'adult', NULL),
('30000000-0000-4000-8000-000000000052', '10000000-0000-4000-8000-000000000005', 'Mỹ Linh', 'adult', NULL),
('30000000-0000-4000-8000-000000000061', '10000000-0000-4000-8000-000000000006', 'Đức Thịnh', 'adult', NULL),
('30000000-0000-4000-8000-000000000062', '10000000-0000-4000-8000-000000000006', 'Bảo Khang', 'child', NULL),
('30000000-0000-4000-8000-000000000071', '10000000-0000-4000-8000-000000000007', 'Bảo Ngọc', 'adult', NULL),
('30000000-0000-4000-8000-000000000072', '10000000-0000-4000-8000-000000000007', 'Hồng Nhung', 'adult', NULL),
('30000000-0000-4000-8000-000000000081', '10000000-0000-4000-8000-000000000008', 'Gia Bảo', 'adult', 'Nhóm muốn tập trung vào kiến trúc nhà ống và phố nghề.'),
('30000000-0000-4000-8000-000000000082', '10000000-0000-4000-8000-000000000008', 'Quang Vinh', 'adult', NULL),
('30000000-0000-4000-8000-000000000083', '10000000-0000-4000-8000-000000000008', 'Thùy Dung', 'adult', NULL),
('30000000-0000-4000-8000-000000000091', '10000000-0000-4000-8000-000000000009', 'Khánh Linh', 'adult', NULL),
('30000000-0000-4000-8000-000000000092', '10000000-0000-4000-8000-000000000009', 'Văn Thành', 'adult', NULL),
('30000000-0000-4000-8000-000000000101', '10000000-0000-4000-8000-000000000010', 'Hải Đăng', 'adult', NULL),
('30000000-0000-4000-8000-000000000102', '10000000-0000-4000-8000-000000000010', 'Tấn Phát', 'adult', 'Ăn chay, cần bữa sáng chay.'),
('30000000-0000-4000-8000-000000000111', '10000000-0000-4000-8000-000000000011', 'Thanh Hà', 'adult', NULL),
('30000000-0000-4000-8000-000000000121', '10000000-0000-4000-8000-000000000012', 'Văn Long', 'adult', NULL),
('30000000-0000-4000-8000-000000000122', '10000000-0000-4000-8000-000000000012', 'Kiều Oanh', 'adult', NULL),
('30000000-0000-4000-8000-000000000123', '10000000-0000-4000-8000-000000000012', 'Minh Đăng', 'child', NULL),
('30000000-0000-4000-8000-000000000131', '10000000-0000-4000-8000-000000000013', 'Ngọc Mai', 'adult', NULL),
('30000000-0000-4000-8000-000000000132', '10000000-0000-4000-8000-000000000013', 'Việt Hoàng', 'adult', NULL),
('30000000-0000-4000-8000-000000000141', '10000000-0000-4000-8000-000000000014', 'Tuấn Kiệt', 'adult', NULL),
('30000000-0000-4000-8000-000000000142', '10000000-0000-4000-8000-000000000014', 'Trung Kiên', 'adult', NULL),
('30000000-0000-4000-8000-000000000151', '10000000-0000-4000-8000-000000000015', 'Mai Chi', 'adult', NULL),
('30000000-0000-4000-8000-000000000161', '10000000-0000-4000-8000-000000000016', 'Phương Thảo', 'adult', NULL),
('30000000-0000-4000-8000-000000000162', '10000000-0000-4000-8000-000000000016', 'Cẩm Tú', 'adult', NULL),
('30000000-0000-4000-8000-000000000163', '10000000-0000-4000-8000-000000000016', 'Hà My', 'adult', NULL),
('30000000-0000-4000-8000-000000000171', '10000000-0000-4000-8000-000000000017', 'Kim Ngân', 'adult', NULL),
('30000000-0000-4000-8000-000000000172', '10000000-0000-4000-8000-000000000017', 'Thế Vinh', 'adult', NULL),
('30000000-0000-4000-8000-000000000181', '10000000-0000-4000-8000-000000000018', 'Trọng Nghĩa', 'adult', NULL),
('30000000-0000-4000-8000-000000000182', '10000000-0000-4000-8000-000000000018', 'An Nhiên', 'child', NULL),
('30000000-0000-4000-8000-000000000191', '10000000-0000-4000-8000-000000000019', 'Thảo Vy', 'adult', NULL),
('30000000-0000-4000-8000-000000000192', '10000000-0000-4000-8000-000000000019', 'Phương Linh', 'adult', NULL),
('30000000-0000-4000-8000-000000000201', '10000000-0000-4000-8000-000000000020', 'Nhật Minh', 'adult', NULL),
('30000000-0000-4000-8000-000000000211', '10000000-0000-4000-8000-000000000021', 'Diễm My', 'adult', NULL),
('30000000-0000-4000-8000-000000000212', '10000000-0000-4000-8000-000000000021', 'Khải Minh', 'adult', NULL),
('30000000-0000-4000-8000-000000000221', '10000000-0000-4000-8000-000000000022', 'Hữu Phước', 'adult', NULL),
('30000000-0000-4000-8000-000000000231', '10000000-0000-4000-8000-000000000023', 'Anh Thư', 'adult', NULL),
('30000000-0000-4000-8000-000000000232', '10000000-0000-4000-8000-000000000023', 'Quốc Bảo', 'adult', NULL),
('30000000-0000-4000-8000-000000000233', '10000000-0000-4000-8000-000000000023', 'Tuệ Minh', 'child', NULL),
('30000000-0000-4000-8000-000000000234', '10000000-0000-4000-8000-000000000023', 'Bảo Ngân', 'child', 'Bé dị ứng đậu phộng.'),
('30000000-0000-4000-8000-000000000241', '10000000-0000-4000-8000-000000000024', 'Thanh Tùng', 'adult', NULL),
('30000000-0000-4000-8000-000000000251', '10000000-0000-4000-8000-000000000025', 'Quỳnh Như', 'adult', NULL),
('30000000-0000-4000-8000-000000000252', '10000000-0000-4000-8000-000000000025', 'Ánh Dương', 'adult', NULL),
('30000000-0000-4000-8000-000000000261', '10000000-0000-4000-8000-000000000026', 'Bích Ngọc', 'adult', NULL),
('30000000-0000-4000-8000-000000000262', '10000000-0000-4000-8000-000000000026', 'Gia Huy', 'adult', NULL),
('30000000-0000-4000-8000-000000000271', '10000000-0000-4000-8000-000000000027', 'Hoài Nam', 'adult', NULL),
('30000000-0000-4000-8000-000000000281', '10000000-0000-4000-8000-000000000028', 'Thu Hằng', 'adult', NULL),
('30000000-0000-4000-8000-000000000282', '10000000-0000-4000-8000-000000000028', 'Ngọc Hân', 'adult', NULL),
('30000000-0000-4000-8000-000000000283', '10000000-0000-4000-8000-000000000028', 'Minh Khôi', 'adult', NULL),
('30000000-0000-4000-8000-000000000291', '10000000-0000-4000-8000-000000000029', 'Đình Khoa', 'adult', NULL),
('30000000-0000-4000-8000-000000000301', '10000000-0000-4000-8000-000000000030', 'Minh Châu', 'adult', NULL),
('30000000-0000-4000-8000-000000000302', '10000000-0000-4000-8000-000000000030', 'Hoàng Long', 'adult', NULL);

-- ---------------------------------------------------------------------
-- 12. payments (THANH_TOÁN)
--   FR-17: chỉ vnpay / vietqr (không có trả sau). Đơn 3k+1 -> vnpay, 3k+2 -> vietqr,
--   đơn 3k luân phiên vietqr / vnpay. Mọi thanh toán đã 'paid' và có mã giao dịch giả.
--   Đơn 30 đã trả bằng VNPay (status 'paid'); tiền hoàn ghi ở bảng refunds (mục 14).
-- ---------------------------------------------------------------------
INSERT INTO payments (id, booking_id, method, provider_txn_id, amount_vnd, status, expires_at) VALUES
('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'vnpay', 'VNP-DEMO-000001', 1760000, 'paid', NULL),
('40000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'vietqr', 'VQR-DEMO-000001', 1950000, 'paid', NULL),
('40000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', 'vietqr', 'VQR-DEMO-000002', 650000, 'paid', NULL),
('40000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000004', 'vnpay', 'VNP-DEMO-000002', 1300000, 'paid', NULL),
('40000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000005', 'vietqr', 'VQR-DEMO-000003', 1440000, 'paid', NULL),
('40000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000006', 'vnpay', 'VNP-DEMO-000003', 1220000, 'paid', NULL),
('40000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000007', 'vnpay', 'VNP-DEMO-000004', 1440000, 'paid', NULL),
('40000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000008', 'vietqr', 'VQR-DEMO-000004', 2700000, 'paid', NULL),
('40000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000009', 'vietqr', 'VQR-DEMO-000005', 1800000, 'paid', NULL),
('40000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000010', 'vnpay', 'VNP-DEMO-000005', 1100000, 'paid', NULL),
('40000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000011', 'vietqr', 'VQR-DEMO-000006', 550000, 'paid', NULL),
('40000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000012', 'vnpay', 'VNP-DEMO-000006', 1490000, 'paid', NULL),
('40000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000013', 'vnpay', 'VNP-DEMO-000007', 1100000, 'paid', NULL),
('40000000-0000-4000-8000-000000000014', '10000000-0000-4000-8000-000000000014', 'vietqr', 'VQR-DEMO-000007', 960000, 'paid', NULL),
('40000000-0000-4000-8000-000000000015', '10000000-0000-4000-8000-000000000015', 'vietqr', 'VQR-DEMO-000008', 480000, 'paid', NULL),
('40000000-0000-4000-8000-000000000016', '10000000-0000-4000-8000-000000000016', 'vnpay', 'VNP-DEMO-000008', 1440000, 'paid', NULL),
('40000000-0000-4000-8000-000000000017', '10000000-0000-4000-8000-000000000017', 'vietqr', 'VQR-DEMO-000009', 1180000, 'paid', NULL),
('40000000-0000-4000-8000-000000000018', '10000000-0000-4000-8000-000000000018', 'vnpay', 'VNP-DEMO-000009', 1000000, 'paid', NULL),
('40000000-0000-4000-8000-000000000019', '10000000-0000-4000-8000-000000000019', 'vnpay', 'VNP-DEMO-000010', 1180000, 'paid', NULL),
('40000000-0000-4000-8000-000000000020', '10000000-0000-4000-8000-000000000020', 'vietqr', 'VQR-DEMO-000010', 590000, 'paid', NULL),
('40000000-0000-4000-8000-000000000021', '10000000-0000-4000-8000-000000000021', 'vietqr', 'VQR-DEMO-000011', 1500000, 'paid', NULL),
('40000000-0000-4000-8000-000000000022', '10000000-0000-4000-8000-000000000022', 'vnpay', 'VNP-DEMO-000011', 750000, 'paid', NULL),
('40000000-0000-4000-8000-000000000023', '10000000-0000-4000-8000-000000000023', 'vietqr', 'VQR-DEMO-000012', 2560000, 'paid', NULL),
('40000000-0000-4000-8000-000000000024', '10000000-0000-4000-8000-000000000024', 'vnpay', 'VNP-DEMO-000012', 850000, 'paid', NULL),
('40000000-0000-4000-8000-000000000025', '10000000-0000-4000-8000-000000000025', 'vnpay', 'VNP-DEMO-000013', 1700000, 'paid', NULL),
('40000000-0000-4000-8000-000000000026', '10000000-0000-4000-8000-000000000026', 'vietqr', 'VQR-DEMO-000013', 800000, 'paid', NULL),
('40000000-0000-4000-8000-000000000027', '10000000-0000-4000-8000-000000000027', 'vietqr', 'VQR-DEMO-000014', 400000, 'paid', NULL),
('40000000-0000-4000-8000-000000000028', '10000000-0000-4000-8000-000000000028', 'vnpay', 'VNP-DEMO-000014', 1200000, 'paid', NULL),
('40000000-0000-4000-8000-000000000029', '10000000-0000-4000-8000-000000000029', 'vietqr', 'VQR-DEMO-000015', 650000, 'paid', NULL),
('40000000-0000-4000-8000-000000000030', '10000000-0000-4000-8000-000000000030', 'vnpay', 'VNP-DEMO-000015', 1300000, 'paid', NULL);

-- ---------------------------------------------------------------------
-- 13. payment_events (SỰ_KIỆN_THANH_TOÁN)
--   Một thông báo thành công (result_code '00', đã xác thực) cho mỗi thanh toán VNPay / VietQR.
--   received_at = lúc khách thanh toán (khoảng 7 ngày trước ngày đi tour).
-- ---------------------------------------------------------------------
INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at) VALUES
('50000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'EVT-DEMO-000001', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 53 DAY, '09:40:00')),
('50000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', 'EVT-DEMO-000002', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '13:05:00')),
('50000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000003', 'EVT-DEMO-000003', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '21:30:00')),
('50000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000004', 'EVT-DEMO-000004', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '07:55:00')),
('50000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000005', 'EVT-DEMO-000005', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 58 DAY, '18:20:00')),
('50000000-0000-4000-8000-000000000006', '40000000-0000-4000-8000-000000000006', 'EVT-DEMO-000006', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 28 DAY, '11:10:00')),
('50000000-0000-4000-8000-000000000007', '40000000-0000-4000-8000-000000000007', 'EVT-DEMO-000007', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 14 DAY, '20:15:00')),
('50000000-0000-4000-8000-000000000008', '40000000-0000-4000-8000-000000000008', 'EVT-DEMO-000008', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '09:40:00')),
('50000000-0000-4000-8000-000000000009', '40000000-0000-4000-8000-000000000009', 'EVT-DEMO-000009', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 17 DAY, '13:05:00')),
('50000000-0000-4000-8000-000000000010', '40000000-0000-4000-8000-000000000010', 'EVT-DEMO-000010', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 68 DAY, '21:30:00')),
('50000000-0000-4000-8000-000000000011', '40000000-0000-4000-8000-000000000011', 'EVT-DEMO-000011', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 41 DAY, '07:55:00')),
('50000000-0000-4000-8000-000000000012', '40000000-0000-4000-8000-000000000012', 'EVT-DEMO-000012', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '18:20:00')),
('50000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000013', 'EVT-DEMO-000013', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '11:10:00')),
('50000000-0000-4000-8000-000000000014', '40000000-0000-4000-8000-000000000014', 'EVT-DEMO-000014', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 30 DAY, '20:15:00')),
('50000000-0000-4000-8000-000000000015', '40000000-0000-4000-8000-000000000015', 'EVT-DEMO-000015', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '09:40:00')),
('50000000-0000-4000-8000-000000000016', '40000000-0000-4000-8000-000000000016', 'EVT-DEMO-000016', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '13:05:00')),
('50000000-0000-4000-8000-000000000017', '40000000-0000-4000-8000-000000000017', 'EVT-DEMO-000017', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 98 DAY, '21:30:00')),
('50000000-0000-4000-8000-000000000018', '40000000-0000-4000-8000-000000000018', 'EVT-DEMO-000018', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '07:55:00')),
('50000000-0000-4000-8000-000000000019', '40000000-0000-4000-8000-000000000019', 'EVT-DEMO-000019', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '18:20:00')),
('50000000-0000-4000-8000-000000000020', '40000000-0000-4000-8000-000000000020', 'EVT-DEMO-000020', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 16 DAY, '11:10:00')),
('50000000-0000-4000-8000-000000000021', '40000000-0000-4000-8000-000000000021', 'EVT-DEMO-000021', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 49 DAY, '20:15:00')),
('50000000-0000-4000-8000-000000000022', '40000000-0000-4000-8000-000000000022', 'EVT-DEMO-000022', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '09:40:00')),
('50000000-0000-4000-8000-000000000023', '40000000-0000-4000-8000-000000000023', 'EVT-DEMO-000023', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '13:05:00')),
('50000000-0000-4000-8000-000000000024', '40000000-0000-4000-8000-000000000024', 'EVT-DEMO-000024', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '21:30:00')),
('50000000-0000-4000-8000-000000000025', '40000000-0000-4000-8000-000000000025', 'EVT-DEMO-000025', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '07:55:00')),
('50000000-0000-4000-8000-000000000026', '40000000-0000-4000-8000-000000000026', 'EVT-DEMO-000026', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 188 DAY, '18:20:00')),
('50000000-0000-4000-8000-000000000027', '40000000-0000-4000-8000-000000000027', 'EVT-DEMO-000027', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 158 DAY, '11:10:00')),
('50000000-0000-4000-8000-000000000028', '40000000-0000-4000-8000-000000000028', 'EVT-DEMO-000028', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 108 DAY, '20:15:00')),
('50000000-0000-4000-8000-000000000029', '40000000-0000-4000-8000-000000000029', 'EVT-DEMO-000029', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '09:40:00')),
('50000000-0000-4000-8000-000000000030', '40000000-0000-4000-8000-000000000030', 'EVT-DEMO-000030', '00', TRUE, TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '13:05:00'));

-- ---------------------------------------------------------------------
-- 14. refunds (HOÀN_TIỀN)
--   Đơn 30 hủy trước giờ khởi hành hơn 24 giờ -> hoàn 100%.
-- ---------------------------------------------------------------------
INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at) VALUES
('60000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000030', 1300000, 'Khách đổi kế hoạch du lịch, hủy trước giờ khởi hành hơn 24 giờ nên được hoàn toàn bộ tiền.', 'completed', TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '08:30:00'));

-- ---------------------------------------------------------------------
-- 15. reviews (ĐÁNH_GIÁ)
--   Đánh giá N thuộc đơn N. Chỉ 'approved' được hiển thị và tính điểm trung bình.
--   Đánh giá 29 (tour 1, 1 sao) đang 'pending': không được hiện, không được tính.
--   Tên người đánh giá hiển thị = users.name của chủ đơn (bookings.user_id), trùng contact_name.
-- ---------------------------------------------------------------------
INSERT INTO reviews (id, booking_id, tour_id, rating, content, moderation_status) VALUES
-- Tour 1
('70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
    4, 'Món ăn ngon, lịch trình hợp lý. Đoạn cuối hơi vội vì nhóm mình dừng lại chụp ảnh khá lâu.', 'approved'),
('70000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001',
    5, 'Dẫn bố mẹ đi cùng, cả nhà đều thích. Cà phê trứng là điểm nhấn của buổi tối.', 'approved'),
('70000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001',
    5, 'Anh hướng dẫn kể chuyện phố cổ rất cuốn, quán nào cũng ngon và sạch sẽ.', 'approved'),
('70000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001',
    5, 'Nhóm nhỏ, đồ ăn đa dạng. Đi bộ khá nhiều, nên mang giày thoải mái.', 'approved'),
-- Tour 2
('70000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000002',
    4, 'Tour nhẹ nhàng, hợp đi buổi chiều. Mong có thêm vài món mặn.', 'approved'),
('70000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000002',
    5, 'Cà phê trứng ngon đúng như mong đợi, chị hướng dẫn rất dễ thương.', 'approved'),
('70000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000002',
    5, 'Nhóm chỉ có năm người nên rất thoải mái, được nghe nhiều chuyện về cách người Hà Nội ăn uống.', 'approved'),
-- Tour 3
('70000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000003',
    5, 'Đáng tiền vì được đi đúng những chỗ nhóm muốn, không bị kéo vào cửa hàng lưu niệm.', 'approved'),
('70000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000003',
    5, 'Người dẫn nắm lịch sử rất chắc, trả lời được hết câu hỏi của bố mình. Sẽ giới thiệu cho bạn bè.', 'approved'),
-- Tour 4
('70000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000004',
    4, 'Hôm đó trời nhiều mây nên bình minh không rõ lắm, bù lại đường rừng rất mát.', 'approved'),
('70000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000004',
    5, 'Bình minh trên Sơn Trà đẹp hơn mình tưởng. Dậy sớm hoàn toàn xứng đáng.', 'approved'),
('70000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000004',
    4, 'Không gặp được voọc nhưng anh hướng dẫn giải thích rất kỹ về rừng. Mì Quảng buổi sáng ngon.', 'approved'),
('70000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000004',
    5, 'Xe đón đúng giờ, nhóm nhỏ nên đi bộ không bị chen. Có cho mượn ống nhòm, rất chu đáo.', 'approved'),
-- Tour 5
('70000000-0000-4000-8000-000000000014', '10000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000005',
    4, 'Vui, đồ ăn chợ đêm ngon. Hôm mình đi là thứ Tư nên không xem được cầu Rồng phun lửa.', 'approved'),
('70000000-0000-4000-8000-000000000015', '10000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000005',
    4, 'Lịch trình ổn, nhưng nhóm 12 người hơi đông lúc ngồi ăn.', 'approved'),
('70000000-0000-4000-8000-000000000016', '10000000-0000-4000-8000-000000000016', 'c0000000-0000-4000-8000-000000000005',
    5, 'Đi tối thứ Bảy, xem cầu Rồng phun lửa xong còn được dẫn đi ăn chè. Rất đáng!', 'approved'),
-- Tour 6
('70000000-0000-4000-8000-000000000017', '10000000-0000-4000-8000-000000000017', 'c0000000-0000-4000-8000-000000000006',
    4, 'Phố cổ đẹp nhưng buổi tối khá đông, nên đi vào ngày thường.', 'approved'),
('70000000-0000-4000-8000-000000000018', '10000000-0000-4000-8000-000000000018', 'c0000000-0000-4000-8000-000000000006',
    5, 'Làm đèn lồng vui hơn mình nghĩ, mang về được một chiếc làm kỷ niệm.', 'approved'),
('70000000-0000-4000-8000-000000000019', '10000000-0000-4000-8000-000000000019', 'c0000000-0000-4000-8000-000000000006',
    5, 'Chị hướng dẫn nói chuyện duyên, kể nhiều chuyện về hội quán mà sách không có.', 'approved'),
('70000000-0000-4000-8000-000000000020', '10000000-0000-4000-8000-000000000020', 'c0000000-0000-4000-8000-000000000006',
    5, 'Thả hoa đăng trên sông Hoài lúc phố lên đèn là khoảnh khắc đáng nhớ nhất chuyến đi.', 'approved'),
-- Tour 7
('70000000-0000-4000-8000-000000000021', '10000000-0000-4000-8000-000000000021', 'c0000000-0000-4000-8000-000000000007',
    4, 'Trời nắng nên đạp xe hơi mệt, may có xe điện hỗ trợ. Bánh xèo tự làm rất ngon.', 'approved'),
('70000000-0000-4000-8000-000000000022', '10000000-0000-4000-8000-000000000022', 'c0000000-0000-4000-8000-000000000007',
    5, 'Lần đầu thử gánh nước tưới rau, các bác nông dân rất vui tính.', 'approved'),
('70000000-0000-4000-8000-000000000023', '10000000-0000-4000-8000-000000000023', 'c0000000-0000-4000-8000-000000000007',
    5, 'Hợp với gia đình có trẻ nhỏ, bé nhà mình thích nhất phần làm vườn.', 'approved'),
-- Tour 8
('70000000-0000-4000-8000-000000000024', '10000000-0000-4000-8000-000000000024', 'c0000000-0000-4000-8000-000000000008',
    4, 'Tài xế chạy cẩn thận, đồ ăn ngon. Đường hơi kẹt lúc 7 giờ tối nên mất thêm thời gian.', 'approved'),
('70000000-0000-4000-8000-000000000025', '10000000-0000-4000-8000-000000000025', 'c0000000-0000-4000-8000-000000000008',
    5, 'Ngồi sau xe máy nhìn Sài Gòn về đêm rất khác. Quán ốc quận 4 là chân ái!', 'approved'),
-- Tour 10
('70000000-0000-4000-8000-000000000026', '10000000-0000-4000-8000-000000000026', 'c0000000-0000-4000-8000-000000000010',
    5, 'Hồ Tây buổi sáng rất yên, ghé chùa Trấn Quốc lúc chưa đông khách.', 'approved'),
('70000000-0000-4000-8000-000000000027', '10000000-0000-4000-8000-000000000027', 'c0000000-0000-4000-8000-000000000010',
    5, 'Đạp xe nhẹ nhàng, bún ốc buổi sáng ngon tuyệt.', 'approved'),
('70000000-0000-4000-8000-000000000028', '10000000-0000-4000-8000-000000000028', 'c0000000-0000-4000-8000-000000000010',
    5, 'Người dẫn nhiệt tình, chụp cho cả nhóm rất nhiều ảnh đẹp.', 'approved'),
-- Đơn có đánh giá đang chờ duyệt
('70000000-0000-4000-8000-000000000029', '10000000-0000-4000-8000-000000000029', 'c0000000-0000-4000-8000-000000000001',
    1, 'Người dẫn đến muộn gần 30 phút và không báo trước, cả nhóm phải đứng chờ.', 'pending');

-- ---------------------------------------------------------------------
-- 16. tour_images (ẢNH_TOUR) - FR-01, FR-02
--   url tương đối từ src/public/assets/. Mỗi file chỉ thuộc 1 tour; tour 2 và tour 9 không có ảnh.
--   Ảnh bìa = sort_order nhỏ nhất, rồi id nhỏ nhất. id theo thứ tự chèn.
-- ---------------------------------------------------------------------
INSERT INTO tour_images (id, tour_id, url, alt_text, sort_order) VALUES
-- Tour 1 (Hà Nội)
('80000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
    'img/tours/hanoi-1.svg', 'Dãy nhà ống phố cổ Hà Nội lúc chiều tối', 1),
-- Tour 3 (Hà Nội)
('80000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000003',
    'img/tours/hanoi-3.svg', 'Tháp Rùa giữa hồ Hoàn Kiếm buổi sáng', 1),
-- Tour 4 (Đà Nẵng): 2 ảnh cùng sort_order 1 -> ảnh bìa là ảnh có id nhỏ hơn (danang-3)
('80000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004',
    'img/tours/danang-3.svg', 'Ngôi chùa nhỏ trên núi xanh trong sương sớm', 1),
('80000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000004',
    'img/tours/danang-2.svg', 'Bãi biển Đà Nẵng với hàng dừa và ô che nắng', 1),
-- Tour 5 (Đà Nẵng)
('80000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000005',
    'img/tours/danang-1.svg', 'Cầu Rồng bắc qua sông Hàn lên đèn về đêm', 1),
-- Tour 6 (Hội An): ảnh bìa hoian-1 (sort_order 1) có id LỚN hơn ảnh sort_order 2
('80000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000006',
    'img/tours/hoian-3.svg', 'Thuyền và hoa đăng trên sông Hoài lúc hoàng hôn', 2),
('80000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000006',
    'img/tours/hoian-1.svg', 'Dãy đèn lồng nhiều màu ở phố cổ Hội An về đêm', 1),
-- Tour 7 (Hội An)
('80000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000007',
    'img/tours/hoian-2.svg', 'Chùa Cầu và dãy nhà vàng bên sông ở Hội An', 1),
-- Tour 8 (TP. Hồ Chí Minh): chèn theo thứ tự 3, 1, 2; ảnh hcm-1 không có alt_text (NULL)
('80000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000008',
    'img/tours/hcm-1.svg', NULL, 3),
('80000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000008',
    'img/tours/hcm-3.svg', 'Sài Gòn về đêm với biển hiệu neon và vệt đèn xe', 1),
('80000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000008',
    'img/tours/hcm-2.svg', 'Tòa nhà cổ có tháp đồng hồ, xe máy chạy phía trước', 2),
-- Tour 10 (Hà Nội): tour đang chờ duyệt, ảnh không bao giờ được hiển thị
('80000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000010',
    'img/tours/hanoi-2.svg', 'Quán ăn sáng vỉa hè với nồi nước dùng bốc khói', 1);

-- ---------------------------------------------------------------------
-- 17. tour_itinerary_items (LỊCH_TRÌNH_TOUR) - FR-03
--   Chèn lệch thứ tự trong từng tour; trang chi tiết sắp xếp theo sort_order.
--   description = tên chặng, thêm ". " + mô tả chặng nếu có.
--   start_time = giờ khởi hành của lịch (mục 7) + thời lượng các chặng trước;
--   NULL = không ghi giờ (giao diện chỉ hiện mô tả). Tour 9 không có lịch trình.
--   Bảng itinerary_stops (thiết kế cũ) để trống.
-- ---------------------------------------------------------------------
INSERT INTO tour_itinerary_items (id, tour_id, start_time, description, sort_order) VALUES
-- Tour 1 (lịch 17:00): 5 mục, chèn theo thứ tự 3, 1, 5, 2, 4
('c4000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '18:30:00',
    'Bún chả và nem rán trong một con ngõ nhỏ', 3),
('c4000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '17:00:00',
    'Gặp nhau tại Nhà hát Múa rối Thăng Long. Người dẫn giới thiệu lộ trình và phát nước uống cho cả nhóm.', 1),
('c4000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '21:00:00',
    'Kết thúc tại khu vực hồ Hoàn Kiếm', 5),
('c4000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001', '17:15:00',
    'Đi bộ và thử món ăn quanh phố cổ. Mỗi điểm dừng là một món ăn và một câu chuyện về con phố đó.', 2),
('c4000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000001', '19:30:00',
    'Cà phê trứng và câu chuyện địa phương. Ngồi lại ở quán cà phê, nghe người dẫn kể về cuộc sống thường ngày ở phố cổ.', 4),
-- Tour 2 (lịch 15:00): 4 mục, chèn theo thứ tự 3, 1, 4, 2
('c4000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000002', '16:15:00',
    'Bánh cuốn nóng trong một quán gia đình. Xem cách tráng bánh cuốn trên nồi hấp và ăn ngay khi bánh còn nóng.', 3),
('c4000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000002', '15:00:00',
    'Gặp nhau tại cổng chính chợ Đồng Xuân', 1),
('c4000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000002', '17:15:00',
    'Cà phê trứng trên tầng cao nhìn ra phố. Tour kết thúc tại quán lúc 18:00.', 4),
('c4000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000002', '15:20:00',
    'Dạo chợ, thử ô mai và các món ăn vặt. Người dẫn chỉ cách chọn ô mai và giới thiệu các món ăn vặt quen thuộc của người Hà Nội.', 2),
-- Tour 3: 5 mục, chèn theo thứ tự 3, 1, 5, 2, 4. Lộ trình linh hoạt (lịch 08:30 hoặc 14:00)
--   -> mọi mục start_time NULL, giao diện chỉ hiện mô tả
('c4000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000003', NULL,
    'Ghé một phố nghề truyền thống theo lựa chọn của nhóm', 3),
('c4000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000003', NULL,
    'Gặp người dẫn tại đền Bạch Mã, thống nhất lộ trình. Nhóm chọn chủ đề cho buổi đi: kiến trúc, phố nghề, đền chùa hoặc góc chụp ảnh.', 1),
('c4000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000003', NULL,
    'Kết thúc ở quán trà, gợi ý chỗ ăn tối. Trò chuyện cùng người dẫn và nhận danh sách quán ăn gợi ý.', 5),
('c4000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000003', NULL,
    'Tham quan một ngôi nhà cổ. Tìm hiểu kiến trúc nhà ống: mặt tiền hẹp, giếng trời và cách nhiều thế hệ sống chung.', 2),
('c4000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000003', NULL,
    'Đi xích lô một vòng quanh hồ Hoàn Kiếm', 4),
-- Tour 4 (lịch 05:00): 5 mục, chèn theo thứ tự 4, 2, 5, 1, 3; mục 5 trả khách về khách sạn
--   không ghi giờ (NULL, tùy khách sạn)
('c4000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000004', '08:30:00',
    'Ăn sáng mì Quảng gần chân núi', 4),
('c4000000-0000-4000-8000-000000000016', 'c0000000-0000-4000-8000-000000000004', '05:30:00',
    'Ngắm bình minh trên đỉnh Bàn Cờ. Đỉnh Bàn Cờ nhìn ra biển và toàn cảnh thành phố; nên mang áo khoác mỏng.', 2),
('c4000000-0000-4000-8000-000000000017', 'c0000000-0000-4000-8000-000000000004', NULL,
    'Xe đưa về khách sạn', 5),
('c4000000-0000-4000-8000-000000000018', 'c0000000-0000-4000-8000-000000000004', '05:00:00',
    'Xe đón tại khách sạn ở trung tâm', 1),
('c4000000-0000-4000-8000-000000000019', 'c0000000-0000-4000-8000-000000000004', '06:30:00',
    'Đi bộ đường rừng, tìm voọc chà vá chân nâu. Cung đường ngắn, độ dốc vừa phải. Có ống nhòm cho mượn để quan sát voọc.', 3),
-- Tour 5 (lịch 18:30): 5 mục, chèn theo thứ tự 3, 1, 5, 2, 4
('c4000000-0000-4000-8000-000000000020', 'c0000000-0000-4000-8000-000000000005', '19:45:00',
    'Ăn tối nhẹ ở chợ đêm. Thử bánh tráng cuốn thịt heo, ốc hút và chè.', 3),
('c4000000-0000-4000-8000-000000000021', 'c0000000-0000-4000-8000-000000000005', '18:30:00',
    'Gặp nhau ở đầu cầu Rồng, phía đường Bạch Đằng', 1),
('c4000000-0000-4000-8000-000000000022', 'c0000000-0000-4000-8000-000000000005', '22:00:00',
    'Kết thúc tour tại chợ đêm', 5),
('c4000000-0000-4000-8000-000000000023', 'c0000000-0000-4000-8000-000000000005', '18:45:00',
    'Dạo bờ sông Hàn, ngắm cầu Rồng lên đèn. Dừng ở những góc ngắm cầu Rồng đẹp nhất để chụp ảnh.', 2),
('c4000000-0000-4000-8000-000000000024', 'c0000000-0000-4000-8000-000000000005', '21:00:00',
    'Xem cầu Rồng phun lửa, phun nước. Chỉ có vào tối thứ Bảy và Chủ nhật, lúc 21:00.', 4),
-- Tour 6 (lịch 16:30): 5 mục, chèn theo thứ tự 4, 2, 5, 1, 3
('c4000000-0000-4000-8000-000000000025', 'c0000000-0000-4000-8000-000000000006', '18:45:00',
    'Thả hoa đăng trên sông Hoài', 4),
('c4000000-0000-4000-8000-000000000026', 'c0000000-0000-4000-8000-000000000006', '16:45:00',
    'Tham quan nhà cổ và hội quán Phúc Kiến. Nghe chuyện về thương cảng Hội An xưa.', 2),
('c4000000-0000-4000-8000-000000000027', 'c0000000-0000-4000-8000-000000000006', '19:30:00',
    'Kết thúc tour ở chợ đêm Nguyễn Hoàng', 5),
('c4000000-0000-4000-8000-000000000028', 'c0000000-0000-4000-8000-000000000006', '16:30:00',
    'Gặp nhau tại Chùa Cầu', 1),
('c4000000-0000-4000-8000-000000000029', 'c0000000-0000-4000-8000-000000000006', '17:45:00',
    'Học làm đèn lồng cùng nghệ nhân. Mỗi khách tự làm một chiếc đèn lồng nhỏ để mang về.', 3),
-- Tour 7 (lịch 08:00): 5 mục, chèn theo thứ tự 3, 1, 5, 2, 4
('c4000000-0000-4000-8000-000000000030', 'c0000000-0000-4000-8000-000000000007', '09:45:00',
    'Lớp nấu ăn: bánh xèo và gỏi cuốn', 3),
('c4000000-0000-4000-8000-000000000031', 'c0000000-0000-4000-8000-000000000007', '08:00:00',
    'Nhận xe đạp, đạp xe ra làng rau Trà Quế. Quãng đường khoảng 4 km qua đồng lúa.', 1),
('c4000000-0000-4000-8000-000000000032', 'c0000000-0000-4000-8000-000000000007', '12:30:00',
    'Đạp xe về trung tâm Hội An', 5),
('c4000000-0000-4000-8000-000000000033', 'c0000000-0000-4000-8000-000000000007', '08:30:00',
    'Làm vườn cùng nông dân trong làng. Xới đất, gánh nước tưới rau và tìm hiểu cách bón rau bằng rong sông.', 2),
('c4000000-0000-4000-8000-000000000034', 'c0000000-0000-4000-8000-000000000007', '11:30:00',
    'Ăn trưa trong vườn', 4),
-- Tour 8 (lịch 18:00): 5 mục, chèn theo thứ tự 4, 2, 5, 1, 3; mục 5 trả khách về khách sạn
--   không ghi giờ (NULL, tùy khách sạn)
('c4000000-0000-4000-8000-000000000035', 'c0000000-0000-4000-8000-000000000008', '20:30:00',
    'Cà phê nhạc sống. Nghỉ chân ở một quán cà phê có ban nhạc chơi nhạc sống.', 4),
('c4000000-0000-4000-8000-000000000036', 'c0000000-0000-4000-8000-000000000008', '18:30:00',
    'Ăn ốc ở quận 4', 2),
('c4000000-0000-4000-8000-000000000037', 'c0000000-0000-4000-8000-000000000008', NULL,
    'Đưa khách về khách sạn', 5),
('c4000000-0000-4000-8000-000000000038', 'c0000000-0000-4000-8000-000000000008', '18:00:00',
    'Đón khách tại khách sạn. Nhận mũ bảo hiểm, áo mưa và làm quen với tài xế.', 1),
('c4000000-0000-4000-8000-000000000039', 'c0000000-0000-4000-8000-000000000008', '19:30:00',
    'Dạo Chợ Lớn và ăn chè', 3),
-- Tour 10 (lịch 05:30): 4 mục, chèn theo thứ tự 3, 1, 4, 2 (tour đang chờ duyệt: không được hiển thị)
('c4000000-0000-4000-8000-000000000040', 'c0000000-0000-4000-8000-000000000010', '06:45:00',
    'Ghé chùa Trấn Quốc. Đến trước giờ đông khách.', 3),
('c4000000-0000-4000-8000-000000000041', 'c0000000-0000-4000-8000-000000000010', '05:30:00',
    'Nhận xe đạp ở đầu đường Thanh Niên', 1),
('c4000000-0000-4000-8000-000000000042', 'c0000000-0000-4000-8000-000000000010', '07:30:00',
    'Ăn sáng bún ốc và kết thúc tour', 4),
('c4000000-0000-4000-8000-000000000043', 'c0000000-0000-4000-8000-000000000010', '05:45:00',
    'Đạp xe quanh Hồ Tây, ngắm bình minh. Đạp chậm, dừng ở vài điểm ngắm mặt trời mọc trên hồ.', 2);

-- ---------------------------------------------------------------------
-- 18. tour_inclusions (BAO_GỒM_TOUR) - FR-04
--   is_included TRUE = đã gồm trong giá, FALSE = không bao gồm; sort_order 1, 2, ... trong
--   từng nhóm. Hiển thị: bao gồm trước, rồi sort_order, rồi id.
--   Tour 5 chỉ có danh sách bao gồm; tour 9 không có dòng nào.
-- ---------------------------------------------------------------------
INSERT INTO tour_inclusions (id, tour_id, item_text, is_included, sort_order) VALUES
-- Tour 1: 3 mục bao gồm, 3 mục không bao gồm
('c5000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '5 món ăn', TRUE, 2),
('c5000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '1 đồ uống', TRUE, 3),
('c5000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001', 'Đồ uống gọi thêm ngoài 1 đồ uống của tour', FALSE, 1),
('c5000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000001', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
('c5000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000001', 'Chi phí đi lại đến điểm hẹn', FALSE, 3),
-- Tour 2: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000002', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000002', 'Bánh cuốn và 3 món ăn vặt', TRUE, 2),
('c5000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000002', '1 ly cà phê trứng', TRUE, 3),
('c5000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000002', 'Món ăn, đồ uống gọi thêm', FALSE, 1),
('c5000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000002', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 3: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000003', 'Người dẫn riêng cho nhóm', TRUE, 1),
('c5000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000003', 'Vé vào nhà cổ', TRUE, 2),
('c5000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000003', 'Xích lô 20 phút', TRUE, 3),
('c5000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000003', 'Bữa ăn và đồ uống', FALSE, 1),
('c5000000-0000-4000-8000-000000000016', 'c0000000-0000-4000-8000-000000000003', 'Mua sắm cá nhân tại phố nghề', FALSE, 2),
-- Tour 4: chèn 2 mục không bao gồm trước, rồi 4 mục bao gồm theo thứ tự 3, 1, 4, 2
('c5000000-0000-4000-8000-000000000017', 'c0000000-0000-4000-8000-000000000004', 'Đồ uống ngoài nước suối', FALSE, 1),
('c5000000-0000-4000-8000-000000000018', 'c0000000-0000-4000-8000-000000000004', 'Chi phí cá nhân', FALSE, 2),
('c5000000-0000-4000-8000-000000000019', 'c0000000-0000-4000-8000-000000000004', 'Nước uống', TRUE, 3),
('c5000000-0000-4000-8000-000000000020', 'c0000000-0000-4000-8000-000000000004', 'Xe đưa đón hai chiều', TRUE, 1),
('c5000000-0000-4000-8000-000000000021', 'c0000000-0000-4000-8000-000000000004', 'Ống nhòm cho mượn', TRUE, 4),
('c5000000-0000-4000-8000-000000000022', 'c0000000-0000-4000-8000-000000000004', 'Bữa sáng mì Quảng', TRUE, 2),
-- Tour 5: chỉ có 3 mục bao gồm (không có danh sách không bao gồm)
('c5000000-0000-4000-8000-000000000023', 'c0000000-0000-4000-8000-000000000005', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0000-4000-8000-000000000024', 'c0000000-0000-4000-8000-000000000005', 'Ăn tối nhẹ 3 món', TRUE, 2),
('c5000000-0000-4000-8000-000000000025', 'c0000000-0000-4000-8000-000000000005', 'Taxi sang chợ đêm', TRUE, 3),
-- Tour 6: 3 mục bao gồm, 3 mục không bao gồm
('c5000000-0000-4000-8000-000000000026', 'c0000000-0000-4000-8000-000000000006', 'Vé tham quan phố cổ', TRUE, 1),
('c5000000-0000-4000-8000-000000000027', 'c0000000-0000-4000-8000-000000000006', 'Đèn lồng tự làm mang về', TRUE, 2),
('c5000000-0000-4000-8000-000000000028', 'c0000000-0000-4000-8000-000000000006', 'Hoa đăng', TRUE, 3),
('c5000000-0000-4000-8000-000000000029', 'c0000000-0000-4000-8000-000000000006', 'Ăn tối', FALSE, 1),
('c5000000-0000-4000-8000-000000000030', 'c0000000-0000-4000-8000-000000000006', 'Đi thuyền trên sông Hoài (xem hoạt động tùy chọn)', FALSE, 2),
('c5000000-0000-4000-8000-000000000031', 'c0000000-0000-4000-8000-000000000006', 'Chi phí cá nhân', FALSE, 3),
-- Tour 7: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0000-4000-8000-000000000032', 'c0000000-0000-4000-8000-000000000007', 'Xe đạp và nón lá', TRUE, 1),
('c5000000-0000-4000-8000-000000000033', 'c0000000-0000-4000-8000-000000000007', 'Lớp nấu ăn và bữa trưa', TRUE, 2),
('c5000000-0000-4000-8000-000000000034', 'c0000000-0000-4000-8000-000000000007', 'Nước uống', TRUE, 3),
('c5000000-0000-4000-8000-000000000035', 'c0000000-0000-4000-8000-000000000007', 'Đồ uống gọi thêm', FALSE, 1),
('c5000000-0000-4000-8000-000000000036', 'c0000000-0000-4000-8000-000000000007', 'Chi phí cá nhân', FALSE, 2),
-- Tour 8: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0000-4000-8000-000000000037', 'c0000000-0000-4000-8000-000000000008', 'Xe máy và tài xế riêng cho mỗi khách', TRUE, 1),
('c5000000-0000-4000-8000-000000000038', 'c0000000-0000-4000-8000-000000000008', 'Ăn tối 4 món', TRUE, 2),
('c5000000-0000-4000-8000-000000000039', 'c0000000-0000-4000-8000-000000000008', 'Mũ bảo hiểm và áo mưa', TRUE, 3),
('c5000000-0000-4000-8000-000000000040', 'c0000000-0000-4000-8000-000000000008', 'Bảo hiểm du lịch', TRUE, 4),
('c5000000-0000-4000-8000-000000000041', 'c0000000-0000-4000-8000-000000000008', 'Đồ uống gọi thêm tại quán cà phê', FALSE, 1),
('c5000000-0000-4000-8000-000000000042', 'c0000000-0000-4000-8000-000000000008', 'Tiền tip cho tài xế (tùy ý)', FALSE, 2),
-- Tour 10: tour đang chờ duyệt, không bao giờ được hiển thị
('c5000000-0000-4000-8000-000000000043', 'c0000000-0000-4000-8000-000000000010', 'Xe đạp và mũ bảo hiểm', TRUE, 1),
('c5000000-0000-4000-8000-000000000044', 'c0000000-0000-4000-8000-000000000010', 'Bữa sáng bún ốc', TRUE, 2),
('c5000000-0000-4000-8000-000000000045', 'c0000000-0000-4000-8000-000000000010', 'Đồ uống gọi thêm', FALSE, 1);

-- ---------------------------------------------------------------------
-- 19. tour_extras (PHỤ_THU / HOẠT_ĐỘNG_TÙY_CHỌN) - FR-04, FR-10
--   kind: surcharge = phụ thu, optional = hoạt động tùy chọn. Giá tách riêng, không cộng vào giá tour.
--   price_vnd / price_unit / conditions NULL = chưa cập nhật. Tour 2 và tour 9 không có dòng nào.
--   Hiển thị: phụ thu trước, rồi sort_order, rồi id. id theo thứ tự chèn.
-- ---------------------------------------------------------------------
INSERT INTO tour_extras (id, tour_id, kind, name, price_vnd, price_unit, conditions, sort_order) VALUES
-- Tour 1: chèn tùy chọn trước, nhưng phụ thu luôn hiển thị trước
('c1000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'optional', 'Thêm phần chè cuối tour',
    35000, 'người', NULL, 1),
('c1000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', 'surcharge', 'Phụ thu đi riêng, không ghép khách',
    500000, 'nhóm', 'Áp dụng khi nhóm muốn đi riêng; tối đa 8 khách.', 1),
-- Tour 3: thứ tự hiển thị: phụ thu, rồi tùy chọn sort_order 1, 2
('c1000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000003', 'optional', 'Chụp ảnh cùng nhiếp ảnh gia',
    800000, 'nhóm', 'Đặt trước ít nhất 48 giờ.', 2),
('c1000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000003', 'surcharge', 'Phụ thu người dẫn nói tiếng Pháp',
    200000, 'nhóm', NULL, 1),
('c1000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000003', 'optional', 'Thêm 30 phút xích lô',
    100000, 'người', NULL, 1),
-- Tour 4: phụ thu ngày lễ chưa có giá, đơn vị, điều kiện (NULL)
('c1000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000004', 'surcharge', 'Phụ thu ngày lễ',
    NULL, NULL, NULL, 2),
('c1000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000004', 'surcharge', 'Phụ thu đón ngoài khu trung tâm',
    100000, 'xe', 'Áp dụng cho khách sạn cách trung tâm trên 5 km.', 1),
-- Tour 5
('c1000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000005', 'optional', 'Đi thuyền ngắm cầu Rồng trên sông Hàn',
    150000, 'người', 'Chỉ khi thời tiết cho phép.', 1),
-- Tour 6: cùng sort_order 0 (mặc định) -> xếp theo id; áo dài chưa có đơn vị tính
('c1000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000006', 'optional', 'Đi thuyền trên sông Hoài',
    150000, 'thuyền', 'Mỗi thuyền tối đa 4 khách.', 0),
('c1000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000006', 'optional', 'Thuê áo dài chụp ảnh',
    120000, NULL, NULL, 0),
-- Tour 7
('c1000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000007', 'optional', 'Đổi sang xe đạp điện',
    50000, 'người', 'Số lượng có hạn, đăng ký khi đặt tour.', 1),
-- Tour 8: bar trên cao chưa có giá (NULL) nhưng có đơn vị
('c1000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000008', 'optional', 'Thêm điểm dừng ở quán bar trên cao',
    NULL, 'người', 'Đồ uống tính theo thực đơn của quán; chỉ nhận khách từ 18 tuổi.', 1),
('c1000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000008', 'surcharge', 'Phụ thu đón ngoài quận 1 và quận 3',
    100000, 'khách', 'Báo địa chỉ khách sạn khi đặt tour.', 1),
-- Tour 10: tour đang chờ duyệt, không bao giờ được hiển thị
('c1000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000010', 'optional', 'Thuê xe đạp đôi',
    50000, 'xe', NULL, 1),
('c1000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000010', 'surcharge', 'Phụ thu đi riêng',
    300000, 'nhóm', NULL, 1);

-- ---------------------------------------------------------------------
-- 20. Dữ liệu cho trang quản trị (FR-19 → FR-25, theo CR1)
--   a) Ngày tạo đơn và ngày thanh toán của đơn 1-30: paid_at = lúc nhận thông báo thanh toán
--      thành công (payment_events.received_at); created_at = 2 ngày trước khi thanh toán.
--   b) Khách hàng 131-139 (người đặt đơn 31-39) và khách hàng 140 bị khóa (FR-19).
--   c) Tour 11 (Huế) đang chờ duyệt, có lịch và giá; tour 12 (Hội An) đã bị từ chối (FR-20, FR-24).
--      Cả hai không hiển thị công khai: trang khách vẫn chỉ có 9 tour, 4 điểm đến, 5 loại hình.
--   d) Đơn 31-39 ở đủ các trạng thái (FR-21, FR-25), trên các lịch còn trống chỗ
--      (capacity - remaining đã đủ cho số khách của đơn, nên số chỗ còn lại trên trang khách
--      không đổi):
--        31, 32, 33 Chờ xác nhận | 34 Chờ thanh toán (chưa thanh toán)
--        35 Chờ thanh toán + chuyển khoản VietQR Chờ đối chiếu
--        36 Đã xác nhận (VNPay) | 37 Đã xác nhận, lịch đã khởi hành 3 ngày trước
--        38 Từ chối | 39 Đã hủy (quá hạn thanh toán 24 giờ)
--   e) admin_logs (NFR-09): lịch sử xử lý của tour 12 và đơn 34-39, người thao tác là tài
--      khoản quản trị viên mẫu. Đơn 1-30 không có lịch sử (lịch sử bắt đầu từ CR1).
-- ---------------------------------------------------------------------

-- a) Ngày thanh toán và ngày tạo của đơn 1-30
UPDATE payments p
JOIN payment_events e ON e.payment_id = p.id
SET p.paid_at = e.received_at
WHERE p.status = 'paid';

UPDATE bookings b
JOIN payments p ON p.booking_id = b.id
SET b.created_at = p.paid_at - INTERVAL 2 DAY;

-- b) Khách hàng 131-140
INSERT INTO users (id, email, password_hash, name, phone, role, status) VALUES
('a0000000-0000-4000-8000-000000000131', 'viet.hung@localtour.test', NULL, 'Việt Hùng', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000132', 'my.duyen@localtour.test', NULL, 'Mỹ Duyên', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000133', 'duc.anh@localtour.test', NULL, 'Đức Anh', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000134', 'ngoc.tram@localtour.test', NULL, 'Ngọc Trâm', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000135', 'van.toan@localtour.test', NULL, 'Văn Toàn', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000136', 'dieu.linh@localtour.test', NULL, 'Diệu Linh', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000137', 'tien.dat@localtour.test', NULL, 'Tiến Đạt', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000138', 'tuyet.mai@localtour.test', NULL, 'Tuyết Mai', NULL, 'customer', 'active'),
('a0000000-0000-4000-8000-000000000139', 'hong.nhung@localtour.test', NULL, 'Hồng Nhung', NULL, 'customer', 'active'),
-- Tài khoản bị khóa: vẫn được tính vào tổng số khách hàng, hiển thị riêng ở mục "Bị khóa"
('a0000000-0000-4000-8000-000000000140', 'kha.vy@localtour.test', NULL, 'Khả Vy', NULL, 'customer', 'locked');

-- c) Tour 11 (chờ duyệt) và tour 12 (bị từ chối)
INSERT INTO tours (id, provider_id, destination_id, category_id, title, description, destination,
                   duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point, included_summary,
                   transport, guide_info, dropoff_point, excluded_summary,
                   document_terms, meal_terms, voucher_terms, reschedule_terms,
                   source_url, verified_at, verification_status, approval_status) VALUES
('c0000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000003',
    'c2000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000002',   -- Huế, Văn hóa – lịch sử
    'Một buổi chiều trong Đại Nội Huế',
    CONCAT_WS(CHAR(10),
        'Dạo Đại Nội Huế buổi chiều cùng người dẫn địa phương, nghe chuyện cung đình và ngắm hoàng hôn trên sông Hương.',
        '',
        'Nhóm gặp nhau ở cổng Ngọ Môn, đi qua điện Thái Hòa, Tử Cấm Thành và vườn Cơ Hạ, kết thúc bằng tách trà cung đình bên bờ sông Hương.'),
    'Huế', 180, 10, 'vi,en', 'meeting_point', 'Cổng Ngọ Môn, Đại Nội Huế',
    NULL,   -- included_summary: không dùng
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Bến thuyền Tòa Khâm',
    NULL,   -- excluded_summary: không dùng
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm trà và bánh cung đình.',
    'Xuất trình mã đặt chỗ tại cổng Ngọ Môn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'pending'),
('c0000000-0000-4000-8000-000000000012', 'b0000000-0000-4000-8000-000000000005',
    'c2000000-0000-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000005',   -- Hội An, Trải nghiệm địa phương
    'Làm đèn lồng cùng nghệ nhân phố Hội',
    'Tự tay làm một chiếc đèn lồng tre và lụa cùng nghệ nhân phố Hội.',
    'Hội An', 120, 8, 'vi', 'meeting_point', 'Xưởng đèn lồng trên đường Nguyễn Thị Minh Khai, Hội An',
    NULL,
    NULL, NULL, NULL,
    NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, 'unverified',
    'rejected');

INSERT INTO cancellation_policies (id, tour_id, free_before_hours, refund_percent, terms, version) VALUES
('f0000000-0000-4000-8000-000000000111', 'c0000000-0000-4000-8000-000000000011', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1);

-- Tour 11 (180 phút): lịch 38, 39
INSERT INTO schedules (id, tour_id, starts_at, ends_at, capacity, remaining, status) VALUES
('d0000000-0000-4000-8000-000000000038', 'c0000000-0000-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '17:00:00'), 10, 10, 'open'),
('d0000000-0000-4000-8000-000000000039', 'c0000000-0000-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '17:00:00'), 10, 10, 'open');

INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active) VALUES
('e0000000-0000-4000-8000-000000000381', 'd0000000-0000-4000-8000-000000000038', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0000-4000-8000-000000000382', 'd0000000-0000-4000-8000-000000000038', 'child', 4, 11, 360000, TRUE),
('e0000000-0000-4000-8000-000000000391', 'd0000000-0000-4000-8000-000000000039', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0000-4000-8000-000000000392', 'd0000000-0000-4000-8000-000000000039', 'child', 4, 11, 360000, TRUE);

-- d) Đơn 31-39
INSERT INTO bookings (id, user_id, schedule_id, code, contact_name, contact_email, contact_phone,
                      status, total_vnd, policy_version, hold_expires_at, created_at) VALUES
-- Chờ xác nhận
('10000000-0000-4000-8000-000000000031', 'a0000000-0000-4000-8000-000000000131', 'd0000000-0000-4000-8000-000000000003',
    'LT518204', 'Việt Hùng', 'viet.hung@localtour.test', '0000000131', 'pending', 1300000, 1, NULL, NOW() - INTERVAL 2 HOUR),
('10000000-0000-4000-8000-000000000032', 'a0000000-0000-4000-8000-000000000132', 'd0000000-0000-4000-8000-000000000018',
    'LT527716', 'Mỹ Duyên', 'my.duyen@localtour.test', '0000000132', 'pending', 1300000, 1, NULL, NOW() - INTERVAL 26 HOUR),
('10000000-0000-4000-8000-000000000033', 'a0000000-0000-4000-8000-000000000133', 'd0000000-0000-4000-8000-000000000022',
    'LT533940', 'Đức Anh', 'duc.anh@localtour.test', '0000000133', 'pending', 590000, 1, NULL, NOW() - INTERVAL 50 HOUR),
-- Chờ thanh toán: hạn 24 giờ tính từ lúc quản trị viên xác nhận chỗ (xem admin_logs)
('10000000-0000-4000-8000-000000000034', 'a0000000-0000-4000-8000-000000000134', 'd0000000-0000-4000-8000-000000000014',
    'LT541385', 'Ngọc Trâm', 'ngoc.tram@localtour.test', '0000000134', 'awaiting_payment', 1100000, 2, NOW() + INTERVAL 20 HOUR, NOW() - INTERVAL 30 HOUR),
('10000000-0000-4000-8000-000000000035', 'a0000000-0000-4000-8000-000000000135', 'd0000000-0000-4000-8000-000000000016',
    'LT556021', 'Văn Toàn', 'van.toan@localtour.test', '0000000135', 'awaiting_payment', 550000, 2, NOW() + INTERVAL 6 HOUR, NOW() - INTERVAL 40 HOUR),
-- Đã xác nhận
('10000000-0000-4000-8000-000000000036', 'a0000000-0000-4000-8000-000000000136', 'd0000000-0000-4000-8000-000000000010',
    'LT562478', 'Diệu Linh', 'dieu.linh@localtour.test', '0000000136', 'confirmed', 1440000, 1, NULL, NOW() - INTERVAL 96 HOUR),
('10000000-0000-4000-8000-000000000037', 'a0000000-0000-4000-8000-000000000137', 'd0000000-0000-4000-8000-000000000001',
    'LT574913', 'Tiến Đạt', 'tien.dat@localtour.test', '0000000137', 'confirmed', 1300000, 1, NULL, NOW() - INTERVAL 216 HOUR),
-- Từ chối
('10000000-0000-4000-8000-000000000038', 'a0000000-0000-4000-8000-000000000138', 'd0000000-0000-4000-8000-000000000005',
    'LT581356', 'Tuyết Mai', 'tuyet.mai@localtour.test', '0000000138', 'rejected', 2600000, 1, NULL, NOW() - INTERVAL 120 HOUR),
-- Đã hủy
('10000000-0000-4000-8000-000000000039', 'a0000000-0000-4000-8000-000000000139', 'd0000000-0000-4000-8000-000000000023',
    'LT598742', 'Hồng Nhung', 'hong.nhung@localtour.test', '0000000139', 'cancelled', 1180000, 1, NULL, NOW() - INTERVAL 144 HOUR);

INSERT INTO booking_lines (id, booking_id, ticket_type_id, quantity, unit_price_vnd, line_total_vnd) VALUES
('20000000-0000-4000-8000-000000000311', '10000000-0000-4000-8000-000000000031', 'e0000000-0000-4000-8000-000000000031', 2, 650000, 1300000),
('20000000-0000-4000-8000-000000000321', '10000000-0000-4000-8000-000000000032', 'e0000000-0000-4000-8000-000000000181', 2, 480000, 960000),
('20000000-0000-4000-8000-000000000322', '10000000-0000-4000-8000-000000000032', 'e0000000-0000-4000-8000-000000000182', 1, 340000, 340000),
('20000000-0000-4000-8000-000000000331', '10000000-0000-4000-8000-000000000033', 'e0000000-0000-4000-8000-000000000221', 1, 590000, 590000),
('20000000-0000-4000-8000-000000000341', '10000000-0000-4000-8000-000000000034', 'e0000000-0000-4000-8000-000000000141', 2, 550000, 1100000),
('20000000-0000-4000-8000-000000000351', '10000000-0000-4000-8000-000000000035', 'e0000000-0000-4000-8000-000000000161', 1, 550000, 550000),
('20000000-0000-4000-8000-000000000361', '10000000-0000-4000-8000-000000000036', 'e0000000-0000-4000-8000-000000000101', 2, 720000, 1440000),
('20000000-0000-4000-8000-000000000371', '10000000-0000-4000-8000-000000000037', 'e0000000-0000-4000-8000-000000000011', 2, 650000, 1300000),
('20000000-0000-4000-8000-000000000381', '10000000-0000-4000-8000-000000000038', 'e0000000-0000-4000-8000-000000000051', 4, 650000, 2600000),
('20000000-0000-4000-8000-000000000391', '10000000-0000-4000-8000-000000000039', 'e0000000-0000-4000-8000-000000000231', 2, 590000, 1180000);

INSERT INTO passengers (id, booking_id, full_name, age_group, special_request) VALUES
('30000000-0000-4000-8000-000000000311', '10000000-0000-4000-8000-000000000031', 'Việt Hùng', 'adult', NULL),
('30000000-0000-4000-8000-000000000312', '10000000-0000-4000-8000-000000000031', 'Bảo Trân', 'adult', NULL),
('30000000-0000-4000-8000-000000000321', '10000000-0000-4000-8000-000000000032', 'Mỹ Duyên', 'adult', 'Ăn chay.'),
('30000000-0000-4000-8000-000000000322', '10000000-0000-4000-8000-000000000032', 'Minh Đức', 'adult', NULL),
('30000000-0000-4000-8000-000000000323', '10000000-0000-4000-8000-000000000032', 'Phúc An', 'child', NULL),
('30000000-0000-4000-8000-000000000331', '10000000-0000-4000-8000-000000000033', 'Đức Anh', 'adult', 'Dị ứng hải sản.'),
('30000000-0000-4000-8000-000000000341', '10000000-0000-4000-8000-000000000034', 'Ngọc Trâm', 'adult', NULL),
('30000000-0000-4000-8000-000000000342', '10000000-0000-4000-8000-000000000034', 'Hữu Tài', 'adult', NULL),
('30000000-0000-4000-8000-000000000351', '10000000-0000-4000-8000-000000000035', 'Văn Toàn', 'adult', NULL),
('30000000-0000-4000-8000-000000000361', '10000000-0000-4000-8000-000000000036', 'Diệu Linh', 'adult', NULL),
('30000000-0000-4000-8000-000000000362', '10000000-0000-4000-8000-000000000036', 'Khánh Duy', 'adult', NULL),
('30000000-0000-4000-8000-000000000371', '10000000-0000-4000-8000-000000000037', 'Tiến Đạt', 'adult', NULL),
('30000000-0000-4000-8000-000000000372', '10000000-0000-4000-8000-000000000037', 'Thanh Thảo', 'adult', NULL),
('30000000-0000-4000-8000-000000000381', '10000000-0000-4000-8000-000000000038', 'Tuyết Mai', 'adult', NULL),
('30000000-0000-4000-8000-000000000382', '10000000-0000-4000-8000-000000000038', 'Quốc Bảo', 'adult', NULL),
('30000000-0000-4000-8000-000000000383', '10000000-0000-4000-8000-000000000038', 'Lan Anh', 'adult', NULL),
('30000000-0000-4000-8000-000000000384', '10000000-0000-4000-8000-000000000038', 'Đức Thịnh', 'adult', NULL),
('30000000-0000-4000-8000-000000000391', '10000000-0000-4000-8000-000000000039', 'Hồng Nhung', 'adult', NULL),
('30000000-0000-4000-8000-000000000392', '10000000-0000-4000-8000-000000000039', 'Thùy Trang', 'adult', NULL);

-- Đơn 35: khách đã chuyển khoản VietQR, chờ quản trị viên đối chiếu (paid_at NULL).
-- Đơn 36 (VNPay) và 37 (VietQR đã đối chiếu): thanh toán thành công.
INSERT INTO payments (id, booking_id, method, provider_txn_id, amount_vnd, status, expires_at, paid_at) VALUES
('40000000-0000-4000-8000-000000000035', '10000000-0000-4000-8000-000000000035', 'vietqr', 'VQR-DEMO-000016', 550000, 'awaiting_reconciliation', NOW() + INTERVAL 6 HOUR, NULL),
('40000000-0000-4000-8000-000000000036', '10000000-0000-4000-8000-000000000036', 'vnpay', 'VNP-DEMO-000016', 1440000, 'paid', NULL, NOW() - INTERVAL 72 HOUR),
('40000000-0000-4000-8000-000000000037', '10000000-0000-4000-8000-000000000037', 'vietqr', 'VQR-DEMO-000017', 1300000, 'paid', NULL, NOW() - INTERVAL 190 HOUR);

INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at) VALUES
('50000000-0000-4000-8000-000000000036', '40000000-0000-4000-8000-000000000036', 'EVT-DEMO-000036', '00', TRUE, NOW() - INTERVAL 72 HOUR),
('50000000-0000-4000-8000-000000000037', '40000000-0000-4000-8000-000000000037', 'EVT-DEMO-000037', '00', TRUE, NOW() - INTERVAL 190 HOUR);

-- e) Lịch sử xử lý (NFR-09)
INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at) VALUES
('90000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'tour', 'c0000000-0000-4000-8000-000000000012',
    'tour_reject', 'pending', 'rejected', 'Thiếu lịch khởi hành, giá vé và chính sách hủy; đã báo đơn vị tổ chức gửi lại đủ thông tin.', NOW() - INTERVAL 72 HOUR),
('90000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000034',
    'booking_status', 'pending', 'awaiting_payment', 'Đơn vị tổ chức xác nhận còn chỗ và giá.', NOW() - INTERVAL 4 HOUR),
('90000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000035',
    'booking_status', 'pending', 'awaiting_payment', NULL, NOW() - INTERVAL 18 HOUR),
('90000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000036',
    'booking_status', 'pending', 'awaiting_payment', NULL, NOW() - INTERVAL 90 HOUR),
('90000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000036',
    'booking_status', 'awaiting_payment', 'confirmed', 'Thanh toán VNPay thành công.', NOW() - INTERVAL 71 HOUR),
('90000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000037',
    'booking_status', 'pending', 'awaiting_payment', NULL, NOW() - INTERVAL 212 HOUR),
('90000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000037',
    'booking_status', 'awaiting_payment', 'confirmed', 'Đã đối chiếu khoản chuyển khoản VietQR.', NOW() - INTERVAL 189 HOUR),
('90000000-0000-4000-8000-000000000008', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000038',
    'booking_status', 'pending', 'rejected', 'Đơn vị tổ chức báo lịch này không còn đủ 4 chỗ; đã gợi ý khách chọn lịch khác.', NOW() - INTERVAL 117 HOUR),
('90000000-0000-4000-8000-000000000009', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000039',
    'booking_status', 'pending', 'awaiting_payment', NULL, NOW() - INTERVAL 140 HOUR),
('90000000-0000-4000-8000-000000000010', 'a0000000-0000-4000-8000-000000000001', 'booking', '10000000-0000-4000-8000-000000000039',
    'booking_status', 'awaiting_payment', 'cancelled', 'Quá hạn thanh toán 24 giờ, khách không thanh toán.', NOW() - INTERVAL 112 HOUR);
-- =====================================================================
-- LocalTour v0.1 - 03_procedures_LTP.sql
-- Mục đích  : Stored procedures cho trang danh sách tour (Bảng tin du lịch) và trang
--             duyệt tour của quản trị viên (FR-24).
-- Phụ trách : Lê Trung Phong (LTP) - WBS 3.2.3
-- Procedures: LTP_sp_tour_list, LTP_sp_destination_list, LTP_sp_category_list,
--             LTP_sp_admin_tour_list, LTP_sp_admin_tour_detail,
--             LTP_sp_admin_tour_set_approval
-- Quy tắc   : Trang khách: tour được hiển thị khi tours.approval_status = 'approved' VÀ
--             providers.approval_status = 'approved' VÀ tài khoản của nhà cung cấp
--             (users.status) = 'active'. Tour khác -> không bao giờ trả về.
--             Lịch đặt được: status = 'open', starts_at > NOW(), remaining > 0 và có
--             ít nhất một loại vé active.
--             Điểm đánh giá chỉ tính đánh giá moderation_status = 'approved'.
--             Ảnh bìa: ảnh của chính tour có sort_order nhỏ nhất (rồi id nhỏ nhất).
--             Tên điểm đến = destinations.name; tour chưa gán destination_id thì dùng
--             tours.destination.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci để không lỗi
--             "Illegal mix of collations" khi database mặc định dùng collation khác.
--             Trang quản trị: xem mọi tour, quy tắc riêng ở phần "Trang quản trị" cuối file.
--             Không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_tour_list(p_keyword, p_destination_id, p_category_id, p_sort)
--   p_keyword        : NULL / '' / toàn khoảng trắng = không lọc; ngược lại tìm
--                      LIKE '%từ khóa%' trong tên tour, mô tả, điểm đến, loại hình,
--                      tên nhà cung cấp. Ký tự % và _ được tìm đúng nghĩa đen (ký tự
--                      thoát là !).
--   p_destination_id : NULL / '' = mọi điểm đến; ngược lại chỉ tour có
--                      tours.destination_id = p_destination_id.
--   p_category_id    : NULL / '' = mọi loại hình; ngược lại chỉ tour có
--                      tours.category_id = p_category_id.
--   p_sort           : 'recommended' (mặc định) | 'upcoming' | 'price_asc' | 'price_desc';
--                      giá trị khác = 'recommended'.
--     recommended: tour có đánh giá trước, rating_avg giảm dần, review_count giảm dần
--     upcoming   : next_starts_at tăng dần, tour chưa có lịch đặt được xếp cuối
--     price_asc / price_desc: from_price_vnd, tour chưa có giá (NULL) xếp cuối
--     Cùng thứ hạng thì xếp theo title, rồi id.
--   Cột trả về: tour_id, title, description, destination_id, destination_name,
--     category_id, category_name (NULL nếu chưa gán loại hình), provider_name,
--     duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point,
--     from_price_vnd, rating_avg (DECIMAL(2,1), NULL nếu chưa có đánh giá),
--     review_count, next_starts_at, cover_image_url, cover_alt_text
--   from_price_vnd: giá vé 'adult' active thấp nhất trong các lịch đặt được. Chỉ lấy vé
--     người lớn (giá hiển thị là "/ người lớn", FR-10); không lấy giá vé trẻ em thay thế.
--     NULL khi không có lịch đặt được hoặc không lịch nào còn vé người lớn đang bán
--     (giao diện xếp vào nhóm "chưa cập nhật giá").
--   next_starts_at: giờ khởi hành sớm nhất trong các lịch đặt được (NULL nếu không có).
--   cover_image_url / cover_alt_text: url và alt_text của ảnh bìa trong tour_images
--     (sort_order nhỏ nhất, cùng sort_order thì id nhỏ nhất); NULL nếu tour chưa có ảnh.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_tour_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_tour_list(
    IN p_keyword        VARCHAR(100),
    IN p_destination_id CHAR(36),
    IN p_category_id    CHAR(36),
    IN p_sort           VARCHAR(20)
)
READS SQL DATA
BEGIN
    DECLARE v_pattern        VARCHAR(310) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_destination_id CHAR(36) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_category_id    CHAR(36) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_sort           VARCHAR(20) DEFAULT 'recommended';

    -- Thoát ký tự đặc biệt của LIKE: '!' trước (vì là ký tự thoát), sau đó '%' và '_'.
    IF p_keyword IS NOT NULL AND TRIM(p_keyword) <> '' THEN
        SET v_pattern = CONCAT('%',
            REPLACE(REPLACE(REPLACE(TRIM(p_keyword), '!', '!!'), '%', '!%'), '_', '!_'),
            '%');
    END IF;

    IF p_destination_id IS NOT NULL AND p_destination_id <> '' THEN
        SET v_destination_id = p_destination_id;
    END IF;

    IF p_category_id IS NOT NULL AND p_category_id <> '' THEN
        SET v_category_id = p_category_id;
    END IF;

    IF p_sort IN ('upcoming', 'price_asc', 'price_desc') THEN
        SET v_sort = p_sort;
    END IF;

    SELECT
        t.id                            AS tour_id,
        t.title,
        t.description,
        t.destination_id,
        COALESCE(d.name, t.destination) AS destination_name,
        t.category_id,
        c.name                          AS category_name,
        p.business_name                 AS provider_name,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        bs.from_price_vnd,
        rs.rating_avg,
        COALESCE(rs.review_count, 0)    AS review_count,
        bs.next_starts_at,
        ci.url                          AS cover_image_url,
        ci.alt_text                     AS cover_alt_text
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    -- Lịch đặt được của từng tour: giá "Từ" và lịch khởi hành gần nhất
    LEFT JOIN (SELECT s.tour_id,
                      MIN(s.starts_at) AS next_starts_at,
                      MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS from_price_vnd
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                WHERE s.status = 'open'
                  AND s.starts_at > NOW()
                  AND s.remaining > 0
                GROUP BY s.tour_id) bs
           ON bs.tour_id = t.id
    -- Điểm trung bình và số đánh giá đã duyệt
    LEFT JOIN (SELECT r.tour_id,
                      CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1)) AS rating_avg,
                      COUNT(*)                                      AS review_count
                 FROM reviews r
                WHERE r.moderation_status = 'approved'
                GROUP BY r.tour_id) rs
           ON rs.tour_id = t.id
    -- Ảnh bìa: đúng 1 ảnh của tour (hoặc không có)
    LEFT JOIN tour_images ci
           ON ci.id = (SELECT ti.id
                         FROM tour_images ti
                        WHERE ti.tour_id = t.id
                        ORDER BY ti.sort_order ASC, ti.id ASC
                        LIMIT 1)
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
      AND (v_destination_id IS NULL
           OR t.destination_id = (v_destination_id COLLATE utf8mb4_unicode_ci))
      AND (v_category_id IS NULL
           OR t.category_id = (v_category_id COLLATE utf8mb4_unicode_ci))
      AND (v_pattern IS NULL
           OR t.title                         LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR t.description                   LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR COALESCE(d.name, t.destination) LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR c.name                          LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR p.business_name                 LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!')
    ORDER BY
        CASE WHEN v_sort = 'recommended' THEN (rs.rating_avg IS NULL) END ASC,
        CASE WHEN v_sort = 'recommended' THEN rs.rating_avg END DESC,
        CASE WHEN v_sort = 'recommended' THEN COALESCE(rs.review_count, 0) END DESC,
        CASE WHEN v_sort = 'upcoming'    THEN (bs.next_starts_at IS NULL) END ASC,
        CASE WHEN v_sort = 'upcoming'    THEN bs.next_starts_at END ASC,
        CASE WHEN v_sort IN ('price_asc', 'price_desc') THEN (bs.from_price_vnd IS NULL) END ASC,
        CASE WHEN v_sort = 'price_asc'   THEN bs.from_price_vnd END ASC,
        CASE WHEN v_sort = 'price_desc'  THEN bs.from_price_vnd END DESC,
        t.title ASC,
        t.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_destination_list()
--   Điểm đến cho bộ lọc và thanh bên, lấy từ bảng destinations. Chỉ trả điểm đến
--   đang có ít nhất một tour hiển thị, kèm số tour hiển thị.
--   Cột trả về: destination_id, name, slug, tour_count.
--   Sắp xếp theo destinations.sort_order, rồi name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_destination_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_destination_list()
READS SQL DATA
BEGIN
    SELECT
        d.id     AS destination_id,
        d.name,
        d.slug,
        COUNT(*) AS tour_count
    FROM destinations d
    JOIN tours     t ON t.destination_id = d.id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    GROUP BY d.id, d.name, d.slug, d.sort_order
    ORDER BY d.sort_order ASC, d.name ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_category_list()
--   Loại hình cho bộ lọc "Loại hình", lấy từ bảng categories. Chỉ trả loại hình
--   đang có ít nhất một tour hiển thị, kèm số tour hiển thị.
--   Cột trả về: category_id, name, slug, tour_count. Sắp xếp theo name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_category_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_category_list()
READS SQL DATA
BEGIN
    SELECT
        c.id     AS category_id,
        c.name,
        c.slug,
        COUNT(*) AS tour_count
    FROM categories c
    JOIN tours     t ON t.category_id = c.id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    GROUP BY c.id, c.name, c.slug
    ORDER BY c.name ASC;
END$$
DELIMITER ;

-- =====================================================================
-- Trang quản trị: duyệt tour (FR-24, NFR-09)
--   Các procedure dưới đây KHÔNG lọc tour công khai: quản trị viên xem mọi tour.
--   Chỉ trang quản trị gọi chúng (ứng dụng kiểm tra tài khoản quản trị viên trước).
--   Chuyển trạng thái duyệt: pending -> approved, pending -> rejected (bắt buộc lý do).
--   Tour bị từ chối không mở lại được; đơn vị tổ chức gửi lại thông tin thì quản trị
--   viên nhập thành tour mới ở trạng thái 'pending'.
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_admin_tour_list(p_approval_status)
--   p_approval_status: NULL / '' = mọi trạng thái; ngược lại 'draft' | 'pending' |
--                      'approved' | 'rejected'.
--   Cột trả về: tour_id, title, provider_name, provider_approval_status,
--     provider_user_status, destination_name, category_name, approval_status,
--     is_public (1 = đang hiển thị cho khách), schedule_count (mọi lịch của tour),
--     last_action_at (lần xử lý gần nhất trong admin_logs, NULL nếu chưa có).
--   Sắp xếp: tour chờ duyệt trước, rồi title, rồi id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_tour_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_tour_list(
    IN p_approval_status VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                AS tour_id,
        t.title,
        p.business_name     AS provider_name,
        p.approval_status   AS provider_approval_status,
        u.status            AS provider_user_status,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        t.approval_status,
        (t.approval_status = 'approved'
         AND p.approval_status = 'approved'
         AND u.status = 'active') AS is_public,
        (SELECT COUNT(*)
           FROM schedules s
          WHERE s.tour_id = t.id) AS schedule_count,
        (SELECT MAX(l.created_at)
           FROM admin_logs l
          WHERE l.target_type = 'tour'
            AND l.target_id = t.id) AS last_action_at
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    WHERE NULLIF(p_approval_status, '') IS NULL
       OR t.approval_status = (p_approval_status COLLATE utf8mb4_unicode_ci)
    ORDER BY (t.approval_status = 'pending') DESC, t.title ASC, t.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_tour_detail(p_tour_id)
--   0 hoặc 1 dòng, mọi trạng thái duyệt. Cột: tour_id, title, description,
--   destination_name, category_name, duration_minutes, max_group_size, language_codes,
--   pickup_mode, meeting_point, transport, guide_info, dropoff_point,
--   source_url, verified_at, verification_status (NFR-07),
--   provider_name, provider_phone, provider_approval_status, provider_user_status,
--   approval_status, is_public,
--   schedule_count, ticket_count (loại vé active), image_count, itinerary_count,
--   inclusion_count, policy_count (số phiên bản chính sách hủy).
--   Chỉ trả số lượng các phần con: trang quản trị dùng để xem tour đã đủ thông tin chưa.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_tour_detail;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_tour_detail(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                AS tour_id,
        t.title,
        t.description,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.transport,
        t.guide_info,
        t.dropoff_point,
        t.source_url,
        t.verified_at,
        t.verification_status,
        p.business_name     AS provider_name,
        p.contact_phone     AS provider_phone,
        p.approval_status   AS provider_approval_status,
        u.status            AS provider_user_status,
        t.approval_status,
        (t.approval_status = 'approved'
         AND p.approval_status = 'approved'
         AND u.status = 'active') AS is_public,
        (SELECT COUNT(*) FROM schedules s WHERE s.tour_id = t.id) AS schedule_count,
        (SELECT COUNT(*)
           FROM ticket_types tt
           JOIN schedules s ON s.id = tt.schedule_id
          WHERE s.tour_id = t.id
            AND tt.active = TRUE) AS ticket_count,
        (SELECT COUNT(*) FROM tour_images ti WHERE ti.tour_id = t.id) AS image_count,
        (SELECT COUNT(*) FROM tour_itinerary_items ii WHERE ii.tour_id = t.id) AS itinerary_count,
        (SELECT COUNT(*) FROM tour_inclusions tn WHERE tn.tour_id = t.id) AS inclusion_count,
        (SELECT COUNT(*) FROM cancellation_policies cp WHERE cp.tour_id = t.id) AS policy_count
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_tour_set_approval(p_tour_id, p_new_status, p_actor_user_id, p_note)
--   p_new_status: 'approved' (phê duyệt) | 'rejected' (từ chối, bắt buộc p_note).
--   Đổi trạng thái và ghi admin_logs ('tour_approve' / 'tour_reject') trong cùng một
--   transaction. p_note tối đa 255 ký tự (NULL / '' = không có).
--   1 dòng: result, approval_status.
--     result = 'ok'                 : đã đổi; approval_status = trạng thái mới.
--              'forbidden'          : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'          : không có tour này.
--              'invalid_transition' : tour không ở trạng thái 'pending', hoặc p_new_status sai.
--              'note_required'      : từ chối mà không có lý do.
--     Khi không 'ok', approval_status = trạng thái hiện tại, không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_tour_set_approval;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_tour_set_approval(
    IN p_tour_id       CHAR(36),
    IN p_new_status    VARCHAR(20),
    IN p_actor_user_id CHAR(36),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_old  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_new  VARCHAR(20)  DEFAULT COALESCE(p_new_status, '');
    DECLARE v_note VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS approval_status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT approval_status
      INTO v_old
      FROM tours
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS approval_status;
        LEAVE proc;
    END IF;

    IF v_old <> 'pending' OR v_new NOT IN ('approved', 'rejected') THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, v_old AS approval_status;
        LEAVE proc;
    END IF;

    IF v_new = 'rejected' AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_old AS approval_status;
        LEAVE proc;
    END IF;

    UPDATE tours
       SET approval_status = v_new
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id,
            IF(v_new = 'approved', 'tour_approve', 'tour_reject'), v_old, v_new, v_note, NOW());

    COMMIT;
    SELECT 'ok' AS result, v_new AS approval_status;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.1 - 04_procedures_NMT.sql
-- Mục đích  : Stored procedures cho trang chi tiết tour (thông tin chính kèm điểm đến,
--             loại hình, phương tiện, điều kiện; lịch khởi hành đặt được, loại vé và
--             giá vé, bộ ảnh của tour) và trang thống kê của quản trị viên (FR-19 -> FR-23).
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.4
-- Procedures: NMT_sp_tour_detail, NMT_sp_tour_schedule_list, NMT_sp_tour_ticket_list,
--             NMT_sp_tour_image_list, NMT_sp_admin_summary,
--             NMT_sp_admin_booking_status_stats, NMT_sp_admin_booking_time_stats,
--             NMT_sp_admin_revenue_stats
-- Quy tắc   : Trang chi tiết tour chỉ trả dữ liệu của tour đang hiển thị: tours.approval_status = 'approved'
--             VÀ providers.approval_status = 'approved' VÀ users.status = 'active'
--             (tài khoản của nhà cung cấp). Tour khác hoặc không tồn tại -> 0 dòng.
--             Lịch đặt được: status = 'open', starts_at > NOW(), remaining > 0 và có
--             ít nhất một loại vé active.
--             p_tour_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Thống kê: tính trên toàn hệ thống, quy tắc ở phần "Trang quản trị" cuối file.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- Procedure của thiết kế cũ: lịch trình nay đọc bằng NTK_sp_tour_itinerary_list (file 05).
DROP PROCEDURE IF EXISTS NMT_sp_tour_itinerary_list;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_detail(p_tour_id)
--   0 hoặc 1 dòng. Cột: tour_id, provider_id, title, description, destination_id,
--   destination_name (destinations.name; tour chưa gán destination_id thì dùng
--   tours.destination), category_id, category_name (NULL nếu chưa gán loại hình),
--   duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point,
--   provider_name, provider_approved_at,
--   rating_avg (DECIMAL(2,1), NULL nếu chưa có đánh giá đã duyệt), review_count,
--   from_price_vnd (vé 'adult' active rẻ nhất trong các lịch đặt được; NULL nếu không
--   có lịch đặt được hoặc không lịch nào còn vé người lớn đang bán), next_starts_at,
--   transport, guide_info, dropoff_point (FR-02),
--   document_terms, meal_terms, voucher_terms, reschedule_terms (FR-05).
--   7 cột cuối NULL = chưa cập nhật (giao diện hiện "Chưa cập nhật").
--   Dịch vụ bao gồm / không bao gồm (FR-04) đọc bằng NTK_sp_tour_inclusion_list (file 05).
--   Không trả các cột NFR-07 (source_url, verified_at, verification_status):
--   chúng dành cho trang quản trị sau này.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_detail;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_detail(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                AS tour_id,
        t.provider_id,
        t.title,
        t.description,
        t.destination_id,
        COALESCE(d.name, t.destination) AS destination_name,
        t.category_id,
        c.name              AS category_name,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        p.business_name     AS provider_name,
        p.approved_at       AS provider_approved_at,
        (SELECT CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1))
           FROM reviews r
          WHERE r.tour_id = t.id
            AND r.moderation_status = 'approved') AS rating_avg,
        (SELECT COUNT(*)
           FROM reviews r
          WHERE r.tour_id = t.id
            AND r.moderation_status = 'approved') AS review_count,
        bs.from_price_vnd,
        bs.next_starts_at,
        t.transport,                -- FR-02 phương tiện
        t.guide_info,               -- FR-02 hướng dẫn viên
        t.dropoff_point,            -- FR-02 điểm trả
        t.document_terms,           -- FR-05 giấy tờ
        t.meal_terms,               -- FR-05 ăn uống
        t.voucher_terms,            -- FR-05 voucher
        t.reschedule_terms          -- FR-05 đổi lịch
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    -- Lịch đặt được của tour: giá "Từ" và lịch khởi hành gần nhất
    LEFT JOIN (SELECT s.tour_id,
                      MIN(s.starts_at) AS next_starts_at,
                      MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS from_price_vnd
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                  AND s.status = 'open'
                  AND s.starts_at > NOW()
                  AND s.remaining > 0
                GROUP BY s.tour_id) bs
           ON bs.tour_id = t.id
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_schedule_list(p_tour_id)
--   Các lịch đặt được của tour.
--   Cột: schedule_id, starts_at, ends_at, capacity, remaining,
--        from_price_vnd (vé 'adult' active rẻ nhất của lịch; lịch chỉ còn vé trẻ em
--        đang bán vẫn được trả về nhưng from_price_vnd = NULL, không lấy giá trẻ em
--        thay thế, FR-10). Sắp xếp starts_at, schedule_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_schedule_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_schedule_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id            AS schedule_id,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS from_price_vnd
    FROM schedules s
    JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
      AND s.status = 'open'
      AND s.starts_at > NOW()
      AND s.remaining > 0
    GROUP BY s.id, s.starts_at, s.ends_at, s.capacity, s.remaining
    ORDER BY s.starts_at, s.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_ticket_list(p_tour_id)
--   Các loại vé active của mọi lịch đặt được (giao diện lọc theo schedule_id
--   khi khách chọn lịch).
--   Cột: ticket_type_id, schedule_id, name ('adult', 'child', ...), min_age, max_age
--        (NULL = không giới hạn), price_vnd.
--   Sắp xếp: lịch sớm trước; trong một lịch vé đắt trước (người lớn trước trẻ em), rồi name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_ticket_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_ticket_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tt.id           AS ticket_type_id,
        tt.schedule_id,
        tt.name,
        tt.min_age,
        tt.max_age,
        tt.price_vnd
    FROM ticket_types tt
    JOIN schedules s ON s.id = tt.schedule_id
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
      AND s.status = 'open'
      AND s.starts_at > NOW()
      AND s.remaining > 0
      AND tt.active = TRUE
    ORDER BY s.starts_at, s.id, tt.price_vnd DESC, tt.name, tt.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_image_list(p_tour_id)
--   Bộ ảnh (gallery) của chính tour đó, không lấy ảnh của tour khác.
--   Cột: image_id, url (tương đối từ src/public/assets/ hoặc http(s)://...),
--        alt_text (NULL nếu chưa có mô tả ảnh), sort_order.
--   Sắp xếp sort_order, rồi image_id. Ảnh đầu tiên = ảnh bìa ở trang danh sách.
--   Tour không hiển thị hoặc chưa có ảnh -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_image_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_image_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        ti.id           AS image_id,
        ti.url,
        ti.alt_text,
        ti.sort_order
    FROM tour_images ti
    JOIN tours     t ON t.id = ti.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE ti.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY ti.sort_order ASC, ti.id ASC;
END$$
DELIMITER ;

-- =====================================================================
-- Trang quản trị: thống kê (FR-19 -> FR-23)
--   Các procedure dưới đây KHÔNG lọc tour công khai: số liệu tính trên toàn hệ thống.
--   Chỉ trang quản trị gọi chúng (ứng dụng kiểm tra tài khoản quản trị viên trước).
--   p_period: 'day' | 'month' | 'year'; giá trị khác = 'month'.
--   p_from / p_to: khoảng ngày (tính cả hai đầu). NULL = không giới hạn đầu đó.
--   Chỉ trả các kỳ có dữ liệu; kỳ trống do giao diện tự bỏ qua.
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_summary()
--   1 dòng. Cột: customer_total, customer_active, customer_locked (FR-19, tài khoản
--   role = 'customer'), tour_total, tour_draft, tour_pending, tour_approved,
--   tour_rejected (FR-20), tour_public (đang hiển thị cho khách), booking_total,
--   booking_pending (yêu cầu chờ xác nhận, cần quản trị viên xử lý).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_summary;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_summary()
READS SQL DATA
BEGIN
    SELECT
        cu.customer_total,
        cu.customer_active,
        cu.customer_locked,
        tr.tour_total,
        tr.tour_draft,
        tr.tour_pending,
        tr.tour_approved,
        tr.tour_rejected,
        tr.tour_public,
        bk.booking_total,
        bk.booking_pending
    FROM (SELECT COUNT(*)                      AS customer_total,
                 COALESCE(SUM(status = 'active'), 0) AS customer_active,
                 COALESCE(SUM(status = 'locked'), 0) AS customer_locked
            FROM users
           WHERE role = 'customer') cu
    CROSS JOIN
         (SELECT COUNT(*)                                     AS tour_total,
                 COALESCE(SUM(t.approval_status = 'draft'), 0)    AS tour_draft,
                 COALESCE(SUM(t.approval_status = 'pending'), 0)  AS tour_pending,
                 COALESCE(SUM(t.approval_status = 'approved'), 0) AS tour_approved,
                 COALESCE(SUM(t.approval_status = 'rejected'), 0) AS tour_rejected,
                 COALESCE(SUM(t.approval_status = 'approved'
                              AND p.approval_status = 'approved'
                              AND u.status = 'active'), 0)        AS tour_public
            FROM tours t
            JOIN providers p ON p.id = t.provider_id
            JOIN users     u ON u.id = p.user_id) tr
    CROSS JOIN
         (SELECT COUNT(*)                            AS booking_total,
                 COALESCE(SUM(status = 'pending'), 0) AS booking_pending
            FROM bookings) bk;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_booking_status_stats()
--   FR-21. Luôn 6 dòng, kể cả trạng thái chưa có yêu cầu nào.
--   Cột: status, booking_count. Thứ tự theo luồng xử lý.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_booking_status_stats;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_booking_status_stats()
READS SQL DATA
BEGIN
    SELECT
        st.status,
        COUNT(b.id) AS booking_count
    FROM (SELECT 1 AS sort_order, 'pending' AS status
          UNION ALL SELECT 2, 'awaiting_payment'
          UNION ALL SELECT 3, 'confirmed'
          UNION ALL SELECT 4, 'completed'
          UNION ALL SELECT 5, 'rejected'
          UNION ALL SELECT 6, 'cancelled') st
    LEFT JOIN bookings b ON b.status = (st.status COLLATE utf8mb4_unicode_ci)
    GROUP BY st.sort_order, st.status
    ORDER BY st.sort_order;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_booking_time_stats(p_period, p_from, p_to)
--   FR-22. Số yêu cầu đặt tour theo ngày tạo (bookings.created_at), mọi trạng thái.
--   Cột: period_key ('YYYY-MM-DD' | 'YYYY-MM' | 'YYYY'), booking_count.
--   Sắp xếp period_key tăng dần.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_booking_time_stats;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_booking_time_stats(
    IN p_period VARCHAR(10),
    IN p_from   DATE,
    IN p_to     DATE
)
READS SQL DATA
BEGIN
    DECLARE v_format VARCHAR(10) DEFAULT '%Y-%m';

    IF p_period = 'day' THEN
        SET v_format = '%Y-%m-%d';
    ELSEIF p_period = 'year' THEN
        SET v_format = '%Y';
    END IF;

    SELECT
        DATE_FORMAT(b.created_at, v_format) AS period_key,
        COUNT(*)                            AS booking_count
    FROM bookings b
    WHERE (p_from IS NULL OR b.created_at >= p_from)
      AND (p_to IS NULL OR b.created_at < p_to + INTERVAL 1 DAY)
    GROUP BY period_key
    ORDER BY period_key;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_revenue_stats(p_period, p_from, p_to)
--   FR-23. Doanh thu theo ngày thanh toán (payments.paid_at) của khoản 'paid'.
--   Cột: period_key, paid_count, gross_vnd (tổng tiền đã thanh toán), refund_vnd (tiền
--   đã hoàn, refunds.status = 'completed', tính vào kỳ của khoản thanh toán gốc),
--   net_vnd = gross_vnd - refund_vnd. Sắp xếp period_key tăng dần.
--   Tiền hoàn được cộng trước theo từng khoản thanh toán để không bị nhân dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_revenue_stats;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_revenue_stats(
    IN p_period VARCHAR(10),
    IN p_from   DATE,
    IN p_to     DATE
)
READS SQL DATA
BEGIN
    DECLARE v_format VARCHAR(10) DEFAULT '%Y-%m';

    IF p_period = 'day' THEN
        SET v_format = '%Y-%m-%d';
    ELSEIF p_period = 'year' THEN
        SET v_format = '%Y';
    END IF;

    SELECT
        DATE_FORMAT(p.paid_at, v_format)                AS period_key,
        COUNT(*)                                        AS paid_count,
        SUM(p.amount_vnd)                               AS gross_vnd,
        COALESCE(SUM(r.refund_vnd), 0)                  AS refund_vnd,
        SUM(p.amount_vnd) - COALESCE(SUM(r.refund_vnd), 0) AS net_vnd
    FROM payments p
    LEFT JOIN (SELECT payment_id, SUM(amount_vnd) AS refund_vnd
                 FROM refunds
                WHERE status = 'completed'
                GROUP BY payment_id) r
           ON r.payment_id = p.id
    WHERE p.status = 'paid'
      AND p.paid_at IS NOT NULL
      AND (p_from IS NULL OR p.paid_at >= p_from)
      AND (p_to IS NULL OR p.paid_at < p_to + INTERVAL 1 DAY)
    GROUP BY period_key
    ORDER BY period_key;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.1 - 05_procedures_NTK.sql
-- Mục đích  : Stored procedures cho nội dung trang chi tiết tour
--             (đánh giá của khách, chính sách hủy, lịch trình, dịch vụ bao gồm /
--             không bao gồm, phụ thu / hoạt động tùy chọn).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - WBS 3.2.6
-- Procedures: NTK_sp_tour_review_list, NTK_sp_tour_cancellation_policy,
--             NTK_sp_tour_itinerary_list, NTK_sp_tour_inclusion_list,
--             NTK_sp_tour_extra_list
-- Quy tắc   : Chỉ trả dữ liệu của tour đang hiển thị: tours.approval_status = 'approved'
--             VÀ providers.approval_status = 'approved' VÀ users.status = 'active'
--             (tài khoản của nhà cung cấp). Tour khác hoặc không tồn tại -> 0 dòng.
--             p_tour_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- Procedure của thiết kế cũ: bộ ảnh nay đọc bằng NMT_sp_tour_image_list (file 04).
DROP PROCEDURE IF EXISTS NTK_sp_tour_image_list;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_review_list(p_tour_id, p_limit)
--   Chỉ đánh giá moderation_status = 'approved'.
--   Cột: review_id, reviewer_name (= users.name của tài khoản đã đặt đơn được đánh giá),
--        rating, content,
--        tour_date (giờ khởi hành của lịch trong đơn được đánh giá).
--   Sắp xếp: tour_date mới nhất trước. p_limit NULL hoặc 0 = lấy 5 đánh giá.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_review_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_review_list(
    IN p_tour_id CHAR(36),
    IN p_limit   TINYINT UNSIGNED
)
READS SQL DATA
BEGIN
    DECLARE v_limit INT UNSIGNED DEFAULT 5;

    IF p_limit IS NOT NULL AND p_limit > 0 THEN
        SET v_limit = p_limit;
    END IF;

    SELECT
        r.id            AS review_id,
        c.name          AS reviewer_name,
        r.rating,
        r.content,
        s.starts_at     AS tour_date
    FROM reviews r
    JOIN bookings  b  ON b.id  = r.booking_id       -- đơn được đánh giá
    JOIN users     c  ON c.id  = b.user_id          -- tài khoản khách hàng đã đặt đơn
    JOIN schedules s  ON s.id  = b.schedule_id
    JOIN tours     t  ON t.id  = r.tour_id
    JOIN providers p  ON p.id  = t.provider_id
    JOIN users     u  ON u.id  = p.user_id          -- tài khoản của nhà cung cấp
    WHERE r.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND r.moderation_status = 'approved'
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY s.starts_at DESC, r.id DESC
    LIMIT v_limit;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_cancellation_policy(p_tour_id)
--   0 hoặc 1 dòng: phiên bản chính sách hủy mới nhất (version lớn nhất) của tour.
--   Cột: policy_id, free_before_hours (NULL = không có hủy miễn phí),
--        refund_percent, terms, version.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_cancellation_policy;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_cancellation_policy(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        cp.id           AS policy_id,
        cp.free_before_hours,
        cp.refund_percent,
        cp.terms,
        cp.version
    FROM cancellation_policies cp
    JOIN tours     t ON t.id = cp.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE cp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY cp.version DESC
    LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_itinerary_list(p_tour_id)
--   Các mục lịch trình của tour (bảng tour_itinerary_items), theo sort_order.
--   Cột: item_id, start_time (TIME; NULL = mục không ghi giờ, giao diện chỉ hiện giờ
--        khi có), description, sort_order.
--   Sắp xếp sort_order, rồi item_id. Tour không hiển thị hoặc chưa có lịch trình -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_itinerary_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_itinerary_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        it.id           AS item_id,
        it.start_time,
        it.description,
        it.sort_order
    FROM tour_itinerary_items it
    JOIN tours     t ON t.id = it.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE it.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY it.sort_order ASC, it.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_inclusion_list(p_tour_id)
--   Dịch vụ bao gồm / không bao gồm của tour (FR-04, bảng tour_inclusions).
--   Cột: inclusion_id, item_text, is_included (1 = đã bao gồm, 0 = không bao gồm),
--        sort_order.
--   Sắp xếp: mục bao gồm trước, rồi sort_order, rồi inclusion_id.
--   Tour không hiển thị hoặc chưa có dòng nào -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_inclusion_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_inclusion_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        ti.id           AS inclusion_id,
        ti.item_text,
        ti.is_included,
        ti.sort_order
    FROM tour_inclusions ti
    JOIN tours     t ON t.id = ti.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE ti.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY ti.is_included DESC, ti.sort_order ASC, ti.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_extra_list(p_tour_id)
--   Phụ thu và hoạt động tùy chọn của tour (FR-04, FR-10). Giá tách riêng,
--   không cộng vào giá tour hay tổng đơn.
--   Cột: extra_id, kind ('surcharge' = phụ thu, 'optional' = hoạt động tùy chọn),
--        name, price_vnd (NULL = chưa cập nhật giá), price_unit (NULL = không ghi
--        đơn vị), conditions (NULL = không có điều kiện), sort_order.
--   Sắp xếp: phụ thu trước, rồi sort_order, rồi extra_id.
--   Tour không hiển thị hoặc chưa có dòng nào -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_extra_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_extra_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        te.id           AS extra_id,
        te.kind,
        te.name,
        te.price_vnd,
        te.price_unit,
        te.conditions,
        te.sort_order
    FROM tour_extras te
    JOIN tours     t ON t.id = te.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE te.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY te.kind = 'surcharge' DESC, te.sort_order ASC, te.id ASC;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.1 - 06_procedures_NTK_account.sql
-- Mục đích  : Stored procedures cho tài khoản khách hàng (đăng ký, đăng nhập).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - WBS 3.2.8
-- Procedures: NTK_sp_customer_register, NTK_sp_user_find_by_email
-- Quy tắc   : Mật khẩu được băm bằng password_hash() của PHP trước khi gọi procedure;
--             database chỉ lưu chuỗi băm, không bao giờ nhận mật khẩu gốc.
--             Email lưu chữ thường, so sánh với COLLATE utf8mb4_unicode_ci.
--             Không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_customer_register(p_name, p_email, p_phone, p_password_hash)
--   Tạo tài khoản role = 'customer', status = 'active' với id UUID mới.
--   p_phone NULL / '' = không có số điện thoại.
--   1 dòng, cột user_id: id của tài khoản mới; NULL khi email đã được dùng
--   (khóa uq_users_email, kể cả email của tài khoản nhân viên / nhà cung cấp).
--   Kiểm tra định dạng dữ liệu (độ dài, email, mật khẩu) do ứng dụng làm trước khi gọi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_register;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_register(
    IN p_name          VARCHAR(100),
    IN p_email         VARCHAR(150),
    IN p_phone         VARCHAR(20),
    IN p_password_hash VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_user_id   CHAR(36) DEFAULT NULL;
    DECLARE v_duplicate BOOLEAN  DEFAULT FALSE;
    -- 1062 = trùng khóa UNIQUE (email đã có)
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    SET v_user_id = UUID();

    INSERT INTO users (id, email, password_hash, name, phone, role, status)
    VALUES (v_user_id,
            LOWER(TRIM(p_email)),
            p_password_hash,
            TRIM(p_name),
            NULLIF(TRIM(p_phone), ''),
            'customer',
            'active');

    IF v_duplicate THEN
        SET v_user_id = NULL;
    END IF;

    SELECT v_user_id AS user_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_user_find_by_email(p_email)
--   0 hoặc 1 dòng: tài khoản có email này (không phân biệt hoa thường).
--   Cột: user_id, name, email, password_hash (NULL = chưa đặt mật khẩu), role, status.
--   Ứng dụng tự kiểm tra role = 'customer', status = 'active' và mật khẩu
--   (password_verify) trước khi cho đăng nhập.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_user_find_by_email;

DELIMITER $$
CREATE PROCEDURE NTK_sp_user_find_by_email(
    IN p_email VARCHAR(150)
)
READS SQL DATA
BEGIN
    SELECT
        u.id            AS user_id,
        u.name,
        u.email,
        u.password_hash,
        u.role,
        u.status
    FROM users u
    WHERE u.email = (LOWER(TRIM(p_email)) COLLATE utf8mb4_unicode_ci)
    LIMIT 1;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.1 - 07_procedures_NTK_admin.sql
-- Mục đích  : Stored procedures cho trang quản trị yêu cầu đặt tour (FR-25) và lịch sử
--             xử lý (NFR-09) dùng chung cho trang tour và trang yêu cầu đặt tour.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Procedures: NTK_sp_admin_booking_list, NTK_sp_admin_booking_detail,
--             NTK_sp_admin_booking_line_list, NTK_sp_admin_booking_extra_list,
--             NTK_sp_admin_booking_passenger_list, NTK_sp_admin_booking_payment_list,
--             NTK_sp_admin_log_list, NTK_sp_admin_booking_set_status
-- Quy tắc   : Chỉ trang quản trị gọi các procedure này (ứng dụng kiểm tra tài khoản
--             quản trị viên trước). Procedure ghi dữ liệu kiểm tra lại người thao tác là
--             quản trị viên đang hoạt động, vì quyền trong session có thể đã cũ.
--             Chuyển trạng thái yêu cầu đặt tour (quản trị viên):
--               pending          -> awaiting_payment (xác nhận chỗ và chốt tổng giá; hạn thanh
--                                   toán 24 giờ), rejected (bắt buộc lý do), cancelled (bắt buộc lý do)
--               awaiting_payment -> confirmed (cần thanh toán 'paid' hoặc chuyển khoản
--                                   VietQR 'awaiting_reconciliation': khoản này được ghi
--                                   'paid' = quản trị viên đã đối chiếu), cancelled (bắt buộc lý do)
--               confirmed        -> completed (chỉ sau giờ khởi hành), cancelled (bắt buộc lý do)
--               rejected, cancelled, completed: trạng thái cuối, không đổi được nữa.
--             Đổi ngày hoặc số người không thuộc FR-25 (thuộc FR-12, phát triển sau).
--             Giữ chỗ (M4): đơn 'pending' chưa giữ chỗ. Xác nhận chỗ (pending ->
--             awaiting_payment) trừ schedules.remaining theo số khách của đơn, lịch về 0 chỗ
--             thì chuyển 'full'. Hủy đơn đang giữ chỗ (awaiting_payment / confirmed ->
--             cancelled) cộng lại số chỗ (không vượt capacity), lịch 'full' mở lại 'open'.
--             Từ chối / hủy đơn 'pending' và hoàn thành đơn không đổi số chỗ.
--             Chốt tổng giá (Sprint 4, 4.4.3.2): khi xác nhận chỗ, quản trị viên nhập lại tổng
--             giá nếu cần (vd. phụ thu ngày lễ, đón ngoài khu trung tâm). Đổi giá phải ghi lý do;
--             admin_logs ghi "Tổng giá: A -> B". Khách thanh toán đúng tổng giá đã chốt.
--             Xác nhận đơn (-> confirmed) cấp voucher (LTP_sp_voucher_issue, file 15).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
--             Các procedure đọc cột / bảng của file 08 và 12 và gọi LTP_sp_voucher_issue
--             (file 15), nên cần import đủ 01 -> 15 trước khi mở trang quản trị.
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_list(p_status, p_keyword)
--   p_status : NULL / '' = mọi trạng thái; ngược lại một giá trị của bookings.status.
--   p_keyword: NULL / '' = không lọc; ngược lại tìm trong mã đơn, tên, email, số điện
--              thoại liên hệ (không phân biệt hoa thường).
--   Tối đa 200 dòng, đơn mới tạo trước. Cột: booking_id, code, status, created_at,
--   contact_name, contact_email, contact_phone, tour_title, starts_at, people (tổng số vé),
--   total_vnd, payment_status (khoản thanh toán tiêu biểu, NULL = chưa có), hold_expires_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_list(
    IN p_status  VARCHAR(30),
    IN p_keyword VARCHAR(100) CHARACTER SET utf8mb4
)
READS SQL DATA
BEGIN
    DECLARE v_keyword VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_keyword), '');

    SELECT
        b.id              AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        t.title           AS tour_title,
        s.starts_at,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        b.total_vnd,
        (SELECT p.status
           FROM payments p
          WHERE p.booking_id = b.id
          ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
          LIMIT 1)        AS payment_status,
        b.hold_expires_at
    FROM bookings b
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE (NULLIF(p_status, '') IS NULL OR b.status = (p_status COLLATE utf8mb4_unicode_ci))
      AND (v_keyword IS NULL
           OR LOCATE(v_keyword COLLATE utf8mb4_unicode_ci,
                     CONCAT_WS(' ', b.code, b.contact_name, b.contact_email, b.contact_phone)) > 0)
    ORDER BY b.created_at DESC, b.code
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_detail(p_booking_id)
--   0 hoặc 1 dòng: thông tin đơn, tài khoản đặt, tour, đơn vị tổ chức, lịch khởi hành
--   (kèm schedule_capacity, schedule_remaining, schedule_status), số khách, khoản thanh toán tiêu biểu (ưu tiên 'paid', rồi 'awaiting_reconciliation',
--   'processing', 'pending', 'failed'), tổng tiền đã hoàn ('completed'), số tiền đang chờ
--   hoàn ('requested'), tiền vé (tickets_vnd), phụ thu / tùy chọn khách chọn (extras_vnd)
--   và voucher (voucher_code, voucher_issued_at; NULL = chưa cấp).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_detail;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_detail(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id                AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.hold_expires_at,
        b.total_vnd,
        (SELECT COALESCE(SUM(bl.line_total_vnd), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS tickets_vnd,
        (SELECT COALESCE(SUM(bx.line_total_vnd), 0)
           FROM booking_extras bx
          WHERE bx.booking_id = b.id) AS extras_vnd,
        b.voucher_code,
        b.voucher_issued_at,
        b.policy_version,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        u.name              AS account_name,
        u.email             AS account_email,
        u.status            AS account_status,
        t.id                AS tour_id,
        t.title             AS tour_title,
        pr.business_name    AS provider_name,
        pr.contact_phone    AS provider_phone,
        s.starts_at,
        s.ends_at,
        s.capacity          AS schedule_capacity,
        s.remaining         AS schedule_remaining,
        s.status            AS schedule_status,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        pay.method          AS payment_method,
        pay.status          AS payment_status,
        pay.amount_vnd      AS payment_amount_vnd,
        pay.paid_at,
        pay.provider_txn_id,
        (SELECT COALESCE(SUM(r.amount_vnd), 0)
           FROM refunds r
           JOIN payments p2 ON p2.id = r.payment_id
          WHERE p2.booking_id = b.id
            AND r.status = 'completed') AS refund_completed_vnd,
        (SELECT COALESCE(SUM(r.amount_vnd), 0)
           FROM refunds r
           JOIN payments p2 ON p2.id = r.payment_id
          WHERE p2.booking_id = b.id
            AND r.status = 'requested') AS refund_requested_vnd
    FROM bookings b
    JOIN users u      ON u.id = b.user_id
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    LEFT JOIN payments pay ON pay.id = (
        SELECT p.id
          FROM payments p
         WHERE p.booking_id = b.id
         ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
         LIMIT 1)
    WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_line_list(p_booking_id)
--   Các dòng vé của đơn. Cột: ticket_name, quantity, unit_price_vnd, line_total_vnd.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_line_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_line_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tt.name           AS ticket_name,
        bl.quantity,
        bl.unit_price_vnd,
        bl.line_total_vnd
    FROM booking_lines bl
    JOIN ticket_types tt ON tt.id = bl.ticket_type_id
    WHERE bl.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY bl.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_extra_list(p_booking_id)
--   Phụ thu / hoạt động tùy chọn khách chọn khi đặt (bảng booking_extras, file 12).
--   Cột: kind, name, price_unit, quantity, unit_price_vnd, line_total_vnd.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_extra_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_extra_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        bx.kind,
        bx.name,
        bx.price_unit,
        bx.quantity,
        bx.unit_price_vnd,
        bx.line_total_vnd
    FROM booking_extras bx
    WHERE bx.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY bx.kind = 'surcharge' DESC, bx.sort_order, bx.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_payment_list(p_booking_id)
--   Mọi khoản thanh toán của đơn, mới trước (Sprint 4: VNPay, VietQR, đối chiếu).
--   Cột: payment_id, method, reference (mã gửi cổng / nội dung chuyển khoản; khoản cũ dùng
--   provider_txn_id), provider_txn_id, amount_vnd, status, created_at, submitted_at, paid_at,
--   response_code, bank_code, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_payment_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_payment_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id              AS payment_id,
        p.method,
        COALESCE(p.reference, p.provider_txn_id) AS reference,
        p.provider_txn_id,
        p.amount_vnd,
        p.status,
        p.created_at,
        p.submitted_at,
        p.paid_at,
        p.response_code,
        p.bank_code,
        p.note
    FROM payments p
    WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY COALESCE(p.created_at, p.paid_at) DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_passenger_list(p_booking_id)
--   Danh sách khách của đơn theo thứ tự nhập trên form (passengers.sort_order, cột của
--   file 08). Cột: full_name, age_group (adult / child / infant),
--   special_request (NULL = không có).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_passenger_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_passenger_list(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.full_name,
        p.age_group,
        p.special_request
    FROM passengers p
    WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
    ORDER BY p.sort_order, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_log_list(p_target_type, p_target_id)
--   Lịch sử xử lý của một đối tượng ('tour' hoặc 'booking' + UUID), cũ trước.
--   Cột: created_at, actor_name, action, from_status, to_status, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_log_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_log_list(
    IN p_target_type VARCHAR(50),
    IN p_target_id   CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        l.created_at,
        u.name            AS actor_name,
        l.action,
        l.from_status,
        l.to_status,
        l.note
    FROM admin_logs l
    JOIN users u ON u.id = l.actor_user_id
    WHERE l.target_type = (p_target_type COLLATE utf8mb4_unicode_ci)
      AND l.target_id = (p_target_id COLLATE utf8mb4_unicode_ci)
    ORDER BY l.created_at, l.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_booking_set_status(p_booking_id, p_new_status, p_actor_user_id, p_note, p_total_vnd)
--   Đổi trạng thái theo bảng chuyển trạng thái ở đầu file và ghi admin_logs trong cùng
--   một transaction. p_note: lý do / ghi chú (NULL / '' = không có), tối đa 255 ký tự.
--   p_total_vnd: tổng giá chốt khi xác nhận chỗ (pending -> awaiting_payment); NULL = giữ
--   tổng hiện tại. Bỏ qua với các chuyển trạng thái khác.
--   1 dòng: result, status.
--     result = 'ok'                 : đã đổi; status = trạng thái mới.
--              'forbidden'          : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'          : không có đơn này.
--              'invalid_transition' : không được chuyển từ trạng thái hiện tại sang p_new_status.
--              'note_required'      : từ chối / hủy mà không có lý do.
--              'needs_payment'      : xác nhận khi chưa có thanh toán thành công / chờ đối chiếu.
--              'not_departed'       : hoàn thành khi chưa tới giờ khởi hành.
--              'schedule_closed'    : xác nhận chỗ khi lịch đã hủy, đã hoàn thành hoặc đã khởi hành.
--              'no_seats'           : xác nhận chỗ khi lịch không còn đủ chỗ cho số khách của đơn.
--              'invalid_total'      : tổng giá chốt <= 0.
--              'total_note_required': đổi tổng giá mà không ghi lý do.
--     Khi không 'ok', status = trạng thái hiện tại (NULL nếu không có đơn), không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_booking_set_status;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_booking_set_status(
    IN p_booking_id    CHAR(36),
    IN p_new_status    VARCHAR(30),
    IN p_actor_user_id CHAR(36),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4,
    IN p_total_vnd     BIGINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_old        VARCHAR(30)  DEFAULT NULL;
    DECLARE v_total      BIGINT       DEFAULT NULL;
    DECLARE v_starts_at  DATETIME     DEFAULT NULL;
    DECLARE v_schedule   CHAR(36)     DEFAULT NULL;
    DECLARE v_sched_st   VARCHAR(30)  DEFAULT NULL;
    DECLARE v_remaining  INT          DEFAULT NULL;
    DECLARE v_people     INT          DEFAULT 0;
    DECLARE v_payment_id CHAR(36)     DEFAULT NULL;
    DECLARE v_payment_st VARCHAR(30)  DEFAULT NULL;
    DECLARE v_new        VARCHAR(30)  DEFAULT COALESCE(p_new_status, '');
    DECLARE v_note       VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa cả đơn và lịch: số chỗ chỉ đổi trong transaction này.
    SELECT b.status, b.total_vnd, b.schedule_id, s.starts_at, s.status, s.remaining
      INTO v_old, v_total, v_schedule, v_starts_at, v_sched_st, v_remaining
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS status;
        LEAVE proc;
    END IF;

    IF NOT ((v_old = 'pending'          AND v_new IN ('awaiting_payment', 'rejected', 'cancelled'))
         OR (v_old = 'awaiting_payment' AND v_new IN ('confirmed', 'cancelled'))
         OR (v_old = 'confirmed'        AND v_new IN ('completed', 'cancelled'))) THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    IF v_new IN ('rejected', 'cancelled') AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    IF v_new = 'completed' AND v_starts_at > NOW() THEN
        ROLLBACK;
        SELECT 'not_departed' AS result, v_old AS status;
        LEAVE proc;
    END IF;

    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
      FROM booking_lines bl
     WHERE bl.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci);

    -- Xác nhận chỗ: tổng giá chốt hợp lệ, lịch phải còn nhận khách và còn đủ chỗ, rồi giữ chỗ.
    IF v_new = 'awaiting_payment' AND p_total_vnd IS NOT NULL AND NOT (p_total_vnd <=> v_total) THEN
        IF p_total_vnd <= 0 THEN
            ROLLBACK;
            SELECT 'invalid_total' AS result, v_old AS status;
            LEAVE proc;
        END IF;
        IF v_note IS NULL THEN
            ROLLBACK;
            SELECT 'total_note_required' AS result, v_old AS status;
            LEAVE proc;
        END IF;
    END IF;

    IF v_new = 'awaiting_payment' THEN
        IF v_sched_st NOT IN ('open', 'full') OR v_starts_at <= NOW() THEN
            ROLLBACK;
            SELECT 'schedule_closed' AS result, v_old AS status;
            LEAVE proc;
        END IF;

        IF v_remaining < v_people THEN
            ROLLBACK;
            SELECT 'no_seats' AS result, v_old AS status;
            LEAVE proc;
        END IF;

        -- SET chạy từ trái sang phải: status so với remaining đã trừ.
        UPDATE schedules
           SET remaining = remaining - v_people,
               status = IF(remaining = 0 AND status = 'open', 'full', status)
         WHERE id = (v_schedule COLLATE utf8mb4_unicode_ci);
    END IF;

    -- Hủy đơn đang giữ chỗ: trả lại chỗ.
    IF v_new = 'cancelled' AND v_old IN ('awaiting_payment', 'confirmed') THEN
        UPDATE schedules
           SET remaining = LEAST(capacity, remaining + v_people),
               status = IF(status = 'full' AND remaining > 0, 'open', status)
         WHERE id = (v_schedule COLLATE utf8mb4_unicode_ci);
    END IF;

    IF v_new = 'confirmed' THEN
        SELECT p.id, p.status
          INTO v_payment_id, v_payment_st
          FROM payments p
         WHERE p.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
           AND p.status IN ('paid', 'awaiting_reconciliation')
         ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation'), p.id
         LIMIT 1
           FOR UPDATE;

        IF v_payment_id IS NULL THEN
            ROLLBACK;
            SELECT 'needs_payment' AS result, v_old AS status;
            LEAVE proc;
        END IF;

        -- Quản trị viên xác nhận = đã đối chiếu khoản chuyển khoản VietQR.
        IF v_payment_st = 'awaiting_reconciliation' THEN
            UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = v_payment_id;
        END IF;
    END IF;

    -- Chốt tổng giá trước khi chuyển "Chờ thanh toán": ghi lịch sử riêng cho lần đổi giá.
    IF v_new = 'awaiting_payment' AND p_total_vnd IS NOT NULL AND NOT (p_total_vnd <=> v_total) THEN
        UPDATE bookings SET total_vnd = p_total_vnd WHERE id = (p_booking_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', p_booking_id, 'booking_total', NULL, NULL,
                LEFT(CONCAT('Tổng giá: ', REPLACE(FORMAT(v_total, 0), ',', '.'), ' → ',
                            REPLACE(FORMAT(p_total_vnd, 0), ',', '.'), ' VND'), 255), NOW());
    END IF;

    UPDATE bookings
       SET status = v_new,
           hold_expires_at = IF(v_new = 'awaiting_payment', NOW() + INTERVAL 24 HOUR, NULL)
     WHERE id = (p_booking_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'booking', p_booking_id, 'booking_status', v_old, v_new, v_note, NOW());

    IF v_new = 'confirmed' THEN
        -- Khoản khác còn chờ của đơn không dùng nữa; cấp voucher (file 15).
        UPDATE payments
           SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
         WHERE booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
           AND id <> v_payment_id
           AND status = 'pending';

        CALL LTP_sp_voucher_issue(p_booking_id);
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_new AS status;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.2 - 08_migration_booking_NMT.sql
-- Mục đích  : Bổ sung cấu trúc dữ liệu Booking cho luồng đặt tour MVP (M4) và dữ liệu
--             kiểm thử đặt tour. Không xóa bảng, không mất dữ liệu đang có.
--   1. bookings.request_token: mã của một lần mở form đặt tour (trang đặt tour sinh ra,
--      32 ký tự hex). Khách bấm "Gửi yêu cầu" hai lần hoặc mạng lỗi rồi gửi lại cùng mã
--      -> không tạo đơn thứ hai: UNIQUE (user_id, request_token). Đơn cũ để NULL.
--   2. booking_lines: mỗi loại vé chỉ một dòng trong một đơn: UNIQUE (booking_id, ticket_type_id).
--   3. passengers.sort_order: thứ tự khách trên form đặt tour (1, 2, ...), để danh sách khách
--      luôn hiện đúng thứ tự đã nhập. Khách của đơn cũ để 0 (sắp tiếp theo id).
--   4. Dữ liệu kiểm thử: lịch 40 của tour 6 (Hội An) chỉ còn 1 chỗ, để thử "không đủ chỗ"
--      (đặt 2 khách) và "đặt vừa đủ" (đặt 1 khách).
-- Quy tắc giữ chỗ (M4, theo User Flow đặt tour và BPMN đặt tour):
--   * Đơn mới = 'pending' (Chờ xác nhận): CHƯA trừ schedules.remaining, chỉ kiểm tra
--     remaining >= số khách lúc tạo đơn.
--   * Quản trị viên xác nhận chỗ (pending -> awaiting_payment): trừ remaining (giữ chỗ 24 giờ);
--     không đủ chỗ thì báo lỗi, không đổi gì. remaining về 0 -> lịch chuyển 'full'.
--   * Hủy đơn đang giữ chỗ (awaiting_payment / confirmed -> cancelled): cộng lại remaining
--     (không vượt capacity), lịch 'full' mở lại 'open'.
--   * Tự hủy khi quá hạn giữ chỗ 24 giờ thuộc M5 (thanh toán).
-- Phụ trách : Nguyễn Minh Thức (NMT) - M4 mục 3
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01_schema.sql, 02_seed.sql. Chạy lại được: cột / khóa đã có thì bỏ qua,
--             dữ liệu kiểm thử đã có thì không chèn lại.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1 + 2 + 3. Cột và khóa mới. ALTER TABLE chạy trong procedure tạm để bỏ qua lỗi
--        "đã có" (1060 cột trùng tên, 1061 khóa trùng tên) khi chạy lại file.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_migrate_booking_m4;

DELIMITER $$
CREATE PROCEDURE NMT_sp_migrate_booking_m4()
MODIFIES SQL DATA
BEGIN
    DECLARE v_skipped INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR 1060, 1061 SET v_skipped = v_skipped + 1;

    ALTER TABLE bookings
        ADD COLUMN request_token VARCHAR(64) NULL AFTER code;
    ALTER TABLE bookings
        ADD UNIQUE KEY uq_bookings_user_request (user_id, request_token);
    ALTER TABLE booking_lines
        ADD UNIQUE KEY uq_booking_lines_ticket (booking_id, ticket_type_id);
    ALTER TABLE passengers
        ADD COLUMN sort_order INT NOT NULL DEFAULT 0 AFTER special_request;
END$$
DELIMITER ;

CALL NMT_sp_migrate_booking_m4();
DROP PROCEDURE IF EXISTS NMT_sp_migrate_booking_m4;

-- ---------------------------------------------------------------------
-- 4. Dữ liệu kiểm thử đặt tour
--   Lịch 40: tour 6 (Hội An, 180 phút), 5 ngày nữa lúc 16:30, sức chứa 10, còn 1 chỗ.
--   Vé 401 người lớn 590.000đ, 402 trẻ em (4-11 tuổi) 410.000đ, cùng giá lịch 22-24.
--   Chỉ chèn khi tour 6 có trong database và lịch 40 chưa có.
-- ---------------------------------------------------------------------
INSERT INTO schedules (id, tour_id, starts_at, ends_at, capacity, remaining, status)
SELECT 'd0000000-0000-4000-8000-000000000040', t.id,
       TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '16:30:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '19:30:00'),
       10, 1, 'open'
  FROM tours t
 WHERE t.id = 'c0000000-0000-4000-8000-000000000006'
   AND NOT EXISTS (SELECT 1 FROM schedules s WHERE s.id = 'd0000000-0000-4000-8000-000000000040');

INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
SELECT v.id, s.id, v.name, v.min_age, v.max_age, v.price_vnd, TRUE
  FROM schedules s
  JOIN (SELECT 'e0000000-0000-4000-8000-000000000401' AS id, 'adult' AS name, 12 AS min_age, NULL AS max_age, 590000 AS price_vnd
        UNION ALL
        SELECT 'e0000000-0000-4000-8000-000000000402', 'child', 4, 11, 410000) v
 WHERE s.id = 'd0000000-0000-4000-8000-000000000040'
   AND NOT EXISTS (SELECT 1 FROM ticket_types tt WHERE tt.id = v.id);
-- =====================================================================
-- LocalTour v0.2 - 09_procedures_NMT_booking.sql
-- Mục đích  : Kiểm tra lịch khởi hành và số chỗ trước khi tạo yêu cầu đặt tour (M4 mục 5):
--             trang đặt tour gọi trước bước "Xem lại & xác nhận" để biết lịch còn nhận khách,
--             còn đủ chỗ và giá vé hiện tại có đổi không.
-- Phụ trách : Nguyễn Minh Thức (NMT) - M4 mục 5
-- Procedures: NMT_sp_schedule_availability, NMT_sp_schedule_ticket_list
-- Quy tắc   : Chỉ trả lịch của tour đang hiển thị: tours.approval_status = 'approved' VÀ
--             providers.approval_status = 'approved' VÀ users.status = 'active' (tài khoản
--             của nhà cung cấp). Lịch của tour khác hoặc không tồn tại -> 0 dòng.
--             Lịch đặt được (bookable): status = 'open', starts_at > NOW(), remaining > 0 và
--             có ít nhất một loại vé active (giống NMT_sp_tour_schedule_list, file 04).
--             Đây chỉ là kiểm tra trước; LTP_sp_booking_create (file 10) kiểm tra lại trong
--             transaction khi tạo đơn.
--             p_schedule_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_schedule_availability(p_schedule_id)
--   0 hoặc 1 dòng. Cột: schedule_id, tour_id, starts_at, ends_at, capacity, remaining,
--   status (open / full / cancelled / completed), max_group_size (của tour),
--   active_ticket_count (số loại vé đang bán),
--   bookable (1 = lịch còn nhận đặt, 0 = không: đã hủy, đã qua, hết chỗ hoặc không có vé).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_schedule_availability;

DELIMITER $$
CREATE PROCEDURE NMT_sp_schedule_availability(
    IN p_schedule_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id            AS schedule_id,
        s.tour_id,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        s.status,
        t.max_group_size,
        (SELECT COUNT(*)
           FROM ticket_types tt
          WHERE tt.schedule_id = s.id
            AND tt.active = TRUE) AS active_ticket_count,
        (s.status = 'open'
         AND s.starts_at > NOW()
         AND s.remaining > 0
         AND EXISTS (SELECT 1
                       FROM ticket_types tt
                      WHERE tt.schedule_id = s.id
                        AND tt.active = TRUE)) AS bookable
    FROM schedules s
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_schedule_ticket_list(p_schedule_id)
--   Các loại vé active của một lịch (tour đang hiển thị), giá hiện tại.
--   Cột: ticket_type_id, name ('adult', 'child', ...), min_age, max_age (NULL = không
--   giới hạn), price_vnd. Sắp xếp: vé đắt trước (người lớn trước trẻ em), rồi name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_schedule_ticket_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_schedule_ticket_list(
    IN p_schedule_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tt.id           AS ticket_type_id,
        tt.name,
        tt.min_age,
        tt.max_age,
        tt.price_vnd
    FROM ticket_types tt
    JOIN schedules s ON s.id = tt.schedule_id
    JOIN tours     t ON t.id = s.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE tt.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
      AND tt.active = TRUE
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY tt.price_vnd DESC, tt.name, tt.id;
END$$
DELIMITER ;
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
-- =====================================================================
-- LocalTour v0.2 - 11_procedures_NTK_booking.sql
-- Mục đích  : Trang "Đơn của tôi" của khách hàng (M4): danh sách đơn, chi tiết một đơn
--             (trạng thái, lý do từ chối / hủy, hạn thanh toán, voucher), dòng vé, phụ thu /
--             tùy chọn đã chọn và danh sách khách.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - M4 mục 7, 8; Sprint 4: 4.2.3.1, 4.2.3.2
-- Procedures: NTK_sp_customer_booking_list, NTK_sp_customer_booking_detail,
--             NTK_sp_customer_booking_line_list, NTK_sp_customer_booking_extra_list,
--             NTK_sp_customer_booking_passenger_list
-- Quy tắc   : Mọi procedure nhận p_user_id (lấy từ session) và chỉ trả đơn của chính tài
--             khoản đó: đơn của người khác hoặc mã không có -> 0 dòng (trang hiện "Không
--             tìm thấy đơn", không lộ đơn của người khác).
--             Đơn vẫn hiện khi tour đã bị ẩn sau lúc đặt; cột tour_public cho biết còn mở
--             được trang chi tiết tour hay không.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01_schema.sql, 08_migration_booking_NMT.sql, 12_migration_sprint4_NMT.sql.
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_list(p_user_id)
--   Tối đa 100 đơn, mới đặt trước. Cột: booking_id, code, status, created_at,
--   hold_expires_at, total_vnd, tour_id, tour_title, tour_public (1/0), destination_name,
--   starts_at, ends_at, people (tổng số vé), cover_url (ảnh bìa của tour, NULL = chưa có ảnh).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_list(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id              AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.hold_expires_at,
        b.total_vnd,
        t.id              AS tour_id,
        t.title           AS tour_title,
        (t.approval_status = 'approved' AND pr.approval_status = 'approved' AND pu.status = 'active') AS tour_public,
        COALESCE(d.name, t.destination) AS destination_name,
        s.starts_at,
        s.ends_at,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        (SELECT ti.url
           FROM tour_images ti
          WHERE ti.tour_id = t.id
          ORDER BY ti.sort_order, ti.id
          LIMIT 1)        AS cover_url
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    JOIN users pu     ON pu.id = pr.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
    ORDER BY b.created_at DESC, b.code
    LIMIT 100;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_detail(p_user_id, p_code)
--   0 hoặc 1 dòng: đơn có mã p_code của tài khoản p_user_id.
--   Cột: booking_id, code, status, created_at, hold_expires_at, total_vnd, policy_version,
--   contact_name, contact_email, contact_phone, tour_id, tour_title, tour_public,
--   destination_name, duration_minutes, language_codes, pickup_mode, meeting_point,
--   provider_name, starts_at, ends_at, people, cover_url,
--   policy_free_before_hours, policy_refund_percent (chính sách hủy đúng phiên bản lúc đặt;
--   NULL = tour chưa có chính sách),
--   payment_status (khoản thanh toán tiêu biểu, NULL = chưa có),
--   tickets_vnd (tiền vé), extras_vnd (phụ thu / tùy chọn đã chọn); total_vnd là tổng giá
--   quản trị viên đã chốt, có thể khác tickets_vnd + extras_vnd,
--   hold_expired (1 = đã quá hạn thanh toán, đơn sắp bị tự hủy),
--   voucher_code, voucher_issued_at (NULL = chưa cấp voucher),
--   status_note, status_changed_at (ghi chú và thời điểm của lần gần nhất đơn chuyển sang
--   trạng thái hiện tại, do quản trị viên (admin_logs) hoặc hệ thống / VNPay (booking_events);
--   NULL khi đơn còn 'pending' hoặc không có ghi chú).
--   Trang chỉ hiện status_note cho đơn bị từ chối / bị hủy (lý do).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_detail;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_detail(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        b.id                AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.hold_expires_at,
        (b.hold_expires_at IS NOT NULL AND b.hold_expires_at <= NOW()) AS hold_expired,
        b.total_vnd,
        (SELECT COALESCE(SUM(bl.line_total_vnd), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS tickets_vnd,
        (SELECT COALESCE(SUM(bx.line_total_vnd), 0)
           FROM booking_extras bx
          WHERE bx.booking_id = b.id) AS extras_vnd,
        b.voucher_code,
        b.voucher_issued_at,
        b.policy_version,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        t.id                AS tour_id,
        t.title             AS tour_title,
        (t.approval_status = 'approved' AND pr.approval_status = 'approved' AND pu.status = 'active') AS tour_public,
        COALESCE(d.name, t.destination) AS destination_name,
        t.duration_minutes,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        pr.business_name    AS provider_name,
        s.starts_at,
        s.ends_at,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        (SELECT ti.url
           FROM tour_images ti
          WHERE ti.tour_id = t.id
          ORDER BY ti.sort_order, ti.id
          LIMIT 1)          AS cover_url,
        cp.free_before_hours AS policy_free_before_hours,
        cp.refund_percent   AS policy_refund_percent,
        (SELECT p.status
           FROM payments p
          WHERE p.booking_id = b.id
          ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
          LIMIT 1)          AS payment_status,
        IF(ev.created_at IS NOT NULL AND (lg.created_at IS NULL OR ev.created_at > lg.created_at),
           ev.note, lg.note)             AS status_note,
        IF(ev.created_at IS NOT NULL AND (lg.created_at IS NULL OR ev.created_at > lg.created_at),
           ev.created_at, lg.created_at) AS status_changed_at
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    JOIN users pu     ON pu.id = pr.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN cancellation_policies cp ON cp.tour_id = t.id AND cp.version = b.policy_version
    LEFT JOIN admin_logs lg ON lg.id = (
        SELECT l.id
          FROM admin_logs l
         WHERE l.target_type = 'booking'
           AND l.target_id = b.id
           AND l.to_status = b.status
         ORDER BY l.created_at DESC, l.id DESC
         LIMIT 1)
    LEFT JOIN booking_events ev ON ev.id = (
        SELECT e.id
          FROM booking_events e
         WHERE e.booking_id = b.id
           AND e.to_status = b.status
         ORDER BY e.created_at DESC, e.id DESC
         LIMIT 1)
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_line_list(p_user_id, p_code)
--   Các dòng vé của đơn (chỉ đơn của tài khoản này).
--   Cột: ticket_name, quantity, unit_price_vnd, line_total_vnd. Vé đắt trước.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_line_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_line_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        tt.name           AS ticket_name,
        bl.quantity,
        bl.unit_price_vnd,
        bl.line_total_vnd
    FROM booking_lines bl
    JOIN bookings b      ON b.id = bl.booking_id
    JOIN ticket_types tt ON tt.id = bl.ticket_type_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY bl.unit_price_vnd DESC, tt.name, bl.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_extra_list(p_user_id, p_code)
--   Phụ thu / hoạt động tùy chọn khách đã chọn (chỉ đơn của tài khoản này).
--   Cột: kind, name, price_unit, quantity, unit_price_vnd, line_total_vnd. Phụ thu trước.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_extra_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_extra_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        bx.kind,
        bx.name,
        bx.price_unit,
        bx.quantity,
        bx.unit_price_vnd,
        bx.line_total_vnd
    FROM booking_extras bx
    JOIN bookings b ON b.id = bx.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY bx.kind = 'surcharge' DESC, bx.sort_order, bx.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_customer_booking_passenger_list(p_user_id, p_code)
--   Danh sách khách của đơn (chỉ đơn của tài khoản này).
--   Cột: full_name, age_group (adult / child / infant), special_request (NULL = không có).
--   Thứ tự = thứ tự nhập trên form (passengers.sort_order, cột của file 08).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_customer_booking_passenger_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_customer_booking_passenger_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        p.full_name,
        p.age_group,
        p.special_request
    FROM passengers p
    JOIN bookings b ON b.id = p.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY p.sort_order, p.id;
END$$
DELIMITER ;
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
-- =====================================================================
-- LocalTour v0.2 - 13_procedures_NMT_catalog.sql
-- Mục đích  : CRUD nền tảng cho trang quản trị (Sprint 4 - WBS 4.3.1.1, 4.4.2.1, 4.4.2.2):
--             đơn vị tổ chức (FR-13), thêm / sửa thông tin tour và trạng thái xác minh
--             (FR-13, NFR-07), lịch khởi hành, sức chứa và giá vé theo lịch (FR-14).
-- Phụ trách : Nguyễn Minh Thức (NMT)
-- Procedures: NMT_sp_admin_provider_list, NMT_sp_admin_provider_detail,
--             NMT_sp_admin_provider_create, NMT_sp_admin_provider_update,
--             NMT_sp_admin_destination_list, NMT_sp_admin_category_list,
--             NMT_sp_admin_tour_form, NMT_sp_admin_tour_validate (dùng nội bộ),
--             NMT_sp_admin_tour_create, NMT_sp_admin_tour_update,
--             NMT_sp_admin_schedule_list, NMT_sp_admin_schedule_detail,
--             NMT_sp_admin_schedule_create, NMT_sp_admin_schedule_update,
--             NMT_sp_admin_schedule_log_list
-- Quy tắc   : Chỉ trang quản trị gọi các procedure này (ứng dụng kiểm tra tài khoản quản
--             trị viên và dữ liệu nhập trước). Procedure ghi dữ liệu kiểm tra lại người
--             thao tác là quản trị viên đang hoạt động và kiểm tra lại dữ liệu (lớp chặn
--             cuối), rồi ghi đúng một dòng admin_logs trong cùng transaction
--             (target_type 'provider' / 'tour' / 'schedule').
--             Đơn vị tổ chức: chưa có tài khoản đăng nhập riêng. Thêm đơn vị = thêm một
--             dòng users (role 'provider', password_hash NULL, status 'active', name = tên
--             đơn vị, email = email liên hệ viết thường) và một dòng providers.
--             approved_at = thời điểm chuyển sang 'approved' (giữ nguyên khi vẫn
--             'approved', NULL khi không còn 'approved').
--             Tour mới luôn ở approval_status 'pending' (chờ duyệt ở trang Duyệt tour);
--             sửa tour giữ nguyên trạng thái duyệt. verification_status 'verified' cần
--             source_url; verified_at = ngày chuyển sang 'verified', NULL khi 'unverified'
--             (NFR-07: thiếu nguồn hoặc ngày thì để unverified).
--             Lịch khởi hành: lịch mới 'open', remaining = capacity, vé 'adult' (từ 12 tuổi)
--             và vé 'child' (4 - 11 tuổi, không bắt buộc).
--             Số chỗ đang giữ (held) = capacity - remaining (đơn 'pending' chưa giữ chỗ).
--             Sửa lịch: chỉ đổi giờ khi lịch chưa khởi hành; capacity mới >= held;
--             remaining = capacity mới - held (0 <= remaining <= capacity); 'open' / 'full'
--             tính lại theo remaining. Hủy lịch bị chặn khi còn đơn pending /
--             awaiting_payment / confirmed. Đổi giá chỉ đổi ticket_types.price_vnd: đơn
--             đã đặt giữ giá đã chụp ở booking_lines.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; so sánh "có thay
--             đổi không" dùng BINARY để nhận cả đổi hoa thường và dấu. Không có DEFINER.
-- Chạy sau  : 01_schema.sql -> 11. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_list()
--   Mọi đơn vị tổ chức, xếp theo tên. Cột: provider_id, business_name, contact_phone,
--   email, approval_status, approved_at, user_status, tour_count (mọi trạng thái duyệt).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_list()
READS SQL DATA
BEGIN
    SELECT
        p.id              AS provider_id,
        p.business_name,
        p.contact_phone,
        u.email,
        p.approval_status,
        p.approved_at,
        u.status          AS user_status,
        (SELECT COUNT(*)
           FROM tours t
          WHERE t.provider_id = p.id) AS tour_count
    FROM providers p
    JOIN users u ON u.id = p.user_id
    ORDER BY p.business_name, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_detail(p_provider_id)
--   0 hoặc 1 dòng, cùng các cột với NMT_sp_admin_provider_list.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_detail;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_detail(
    IN p_provider_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id              AS provider_id,
        p.business_name,
        p.contact_phone,
        u.email,
        p.approval_status,
        p.approved_at,
        u.status          AS user_status,
        (SELECT COUNT(*)
           FROM tours t
          WHERE t.provider_id = p.id) AS tour_count
    FROM providers p
    JOIN users u ON u.id = p.user_id
    WHERE p.id = (p_provider_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_create(p_actor_user_id, p_business_name, p_contact_phone,
--                              p_email, p_approval_status)
--   Thêm tài khoản users (role 'provider') và dòng providers, ghi admin_logs
--   'provider_create'.
--   1 dòng: result, field, provider_id.
--     result = 'ok'          : đã thêm; provider_id = mã đơn vị mới.
--              'forbidden'   : người thao tác không phải quản trị viên đang hoạt động.
--              'invalid'     : dữ liệu sai; field = ô sai đầu tiên (business_name,
--                              contact_phone, email, approval_status).
--              'email_taken' : email đã thuộc một tài khoản khác.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_create;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_create(
    IN p_actor_user_id   CHAR(36),
    IN p_business_name   VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_contact_phone   VARCHAR(50),
    IN p_email           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_approval_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_name        VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT TRIM(p_business_name);
    DECLARE v_phone       VARCHAR(50)  DEFAULT TRIM(p_contact_phone);
    DECLARE v_email       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(p_email));
    DECLARE v_status      VARCHAR(20)  DEFAULT COALESCE(p_approval_status, '');
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_user_id     CHAR(36)     DEFAULT UUID();
    DECLARE v_provider_id CHAR(36)     DEFAULT UUID();
    DECLARE v_duplicate   BOOLEAN      DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- 1062 = trùng khóa UNIQUE (email vừa được tài khoản khác dùng)
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF v_name IS NULL OR v_name = '' OR CHAR_LENGTH(v_name) > 150 THEN
        SET v_field = 'business_name';
    ELSEIF v_phone IS NULL OR CHAR_LENGTH(v_phone) NOT BETWEEN 8 AND 20
        OR v_phone NOT REGEXP '^[+]?[0-9 ]+$' THEN
        SET v_field = 'contact_phone';
    ELSEIF v_email IS NULL OR CHAR_LENGTH(v_email) > 150
        OR v_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SET v_field = 'email';
    ELSEIF v_status NOT IN ('pending', 'approved', 'rejected') THEN
        SET v_field = 'approval_status';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE email = (v_email COLLATE utf8mb4_unicode_ci)) THEN
        SELECT 'email_taken' AS result, 'email' AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- users.name tối đa 100 ký tự; tên đầy đủ nằm ở providers.business_name.
    INSERT INTO users (id, email, password_hash, name, phone, role, status)
    VALUES (v_user_id, v_email, NULL, LEFT(v_name, 100), NULL, 'provider', 'active');

    IF v_duplicate THEN
        ROLLBACK;
        SELECT 'email_taken' AS result, 'email' AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    INSERT INTO providers (id, user_id, business_name, contact_phone, approval_status, approved_at)
    VALUES (v_provider_id, v_user_id, v_name, v_phone, v_status,
            IF(v_status = 'approved', NOW(), NULL));

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'provider', v_provider_id, 'provider_create', NULL, v_status, NULL, NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_provider_id AS provider_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_update(p_actor_user_id, p_provider_id, p_business_name,
--                              p_contact_phone, p_email, p_approval_status)
--   Sửa thông tin đơn vị (và name / email của tài khoản users đi kèm), ghi admin_logs
--   'provider_update' (from / to = trạng thái hợp tác, note = các ô đã sửa).
--   1 dòng: result, field, provider_id.
--     result = 'ok'          : đã lưu.
--              'unchanged'   : dữ liệu giống hệt hiện tại, không ghi gì.
--              'forbidden'   : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'   : không có đơn vị này.
--              'invalid'     : dữ liệu sai; field như NMT_sp_admin_provider_create.
--              'email_taken' : email đã thuộc một tài khoản khác.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_update;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_update(
    IN p_actor_user_id   CHAR(36),
    IN p_provider_id     CHAR(36),
    IN p_business_name   VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_contact_phone   VARCHAR(50),
    IN p_email           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_approval_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_name       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT TRIM(p_business_name);
    DECLARE v_phone      VARCHAR(50)  DEFAULT TRIM(p_contact_phone);
    DECLARE v_email      VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(p_email));
    DECLARE v_status     VARCHAR(20)  DEFAULT COALESCE(p_approval_status, '');
    DECLARE v_field      VARCHAR(30)  DEFAULT NULL;
    DECLARE v_user_id    CHAR(36)     DEFAULT NULL;
    DECLARE v_old_name   VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_phone  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_old_email  VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_status VARCHAR(20)  DEFAULT NULL;
    DECLARE v_changes    VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT '';
    DECLARE v_duplicate  BOOLEAN      DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    DECLARE CONTINUE HANDLER FOR 1062 SET v_duplicate = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF v_name IS NULL OR v_name = '' OR CHAR_LENGTH(v_name) > 150 THEN
        SET v_field = 'business_name';
    ELSEIF v_phone IS NULL OR CHAR_LENGTH(v_phone) NOT BETWEEN 8 AND 20
        OR v_phone NOT REGEXP '^[+]?[0-9 ]+$' THEN
        SET v_field = 'contact_phone';
    ELSEIF v_email IS NULL OR CHAR_LENGTH(v_email) > 150
        OR v_email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$' THEN
        SET v_field = 'email';
    ELSEIF v_status NOT IN ('pending', 'approved', 'rejected') THEN
        SET v_field = 'approval_status';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT p.user_id, p.business_name, p.contact_phone, u.email, p.approval_status
      INTO v_user_id, v_old_name, v_old_phone, v_old_email, v_old_status
      FROM providers p
      JOIN users u ON u.id = p.user_id
     WHERE p.id = (p_provider_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_user_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS provider_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM users
                WHERE email = (v_email COLLATE utf8mb4_unicode_ci)
                  AND id <> v_user_id) THEN
        ROLLBACK;
        SELECT 'email_taken' AS result, 'email' AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    SET v_changes = CONCAT_WS(', ',
        IF(BINARY v_old_name  <> BINARY v_name,  'tên đơn vị', NULL),
        IF(BINARY v_old_phone <> BINARY v_phone, 'số điện thoại', NULL),
        IF(BINARY v_old_email <> BINARY v_email, 'email', NULL));

    IF v_changes = '' AND v_old_status = v_status THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    UPDATE users
       SET email = v_email,
           name = LEFT(v_name, 100)
     WHERE id = v_user_id;

    IF v_duplicate THEN
        ROLLBACK;
        SELECT 'email_taken' AS result, 'email' AS field, p_provider_id AS provider_id;
        LEAVE proc;
    END IF;

    UPDATE providers
       SET business_name = v_name,
           contact_phone = v_phone,
           approved_at = CASE
                             WHEN v_status <> 'approved' THEN NULL
                             WHEN approval_status = 'approved' THEN approved_at
                             ELSE NOW()
                         END,
           approval_status = v_status
     WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'provider', p_provider_id, 'provider_update',
            v_old_status, v_status, NULLIF(CONCAT('Sửa: ', v_changes), 'Sửa: '), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, p_provider_id AS provider_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_destination_list() / NMT_sp_admin_category_list()
--   Mọi điểm đến / loại hình (kể cả chưa có tour hiển thị), dùng cho ô chọn trong
--   form tour. Cột: destination_id, name / category_id, name.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_destination_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_destination_list()
READS SQL DATA
BEGIN
    SELECT d.id AS destination_id, d.name
      FROM destinations d
     ORDER BY d.sort_order, d.name, d.id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS NMT_sp_admin_category_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_category_list()
READS SQL DATA
BEGIN
    SELECT c.id AS category_id, c.name
      FROM categories c
     ORDER BY c.name, c.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_form(p_tour_id)
--   0 hoặc 1 dòng: giá trị gốc của các cột trong form sửa tour, mọi trạng thái duyệt.
--   Cột: tour_id, provider_id, destination_id, category_id, title, description,
--   destination, duration_minutes, max_group_size, language_codes, pickup_mode,
--   meeting_point, transport, guide_info, dropoff_point, document_terms, meal_terms,
--   voucher_terms, reschedule_terms, source_url, verification_status, verified_at,
--   approval_status.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_form;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_form(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id AS tour_id,
        t.provider_id,
        t.destination_id,
        t.category_id,
        t.title,
        t.description,
        t.destination,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.transport,
        t.guide_info,
        t.dropoff_point,
        t.document_terms,
        t.meal_terms,
        t.voucher_terms,
        t.reschedule_terms,
        t.source_url,
        t.verification_status,
        t.verified_at,
        t.approval_status
    FROM tours t
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_validate(...)
--   Dùng nội bộ cho NMT_sp_admin_tour_create / NMT_sp_admin_tour_update (ứng dụng không
--   gọi). Nhận giá trị đã TRIM (ô không bắt buộc để trống = NULL).
--   OUT p_field: NULL = hợp lệ; ngược lại tên ô sai đầu tiên (provider_id, destination_id,
--     category_id, title, description, duration_minutes, max_group_size, language_codes,
--     pickup_mode, meeting_point, transport, guide_info, dropoff_point, source_url,
--     verification_status).
--   OUT p_destination_name: destinations.name của điểm đến đã chọn (ghi vào
--     tours.destination).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_validate;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_validate(
    IN  p_provider_id         CHAR(36),
    IN  p_destination_id      CHAR(36),
    IN  p_category_id         CHAR(36),
    IN  p_title               VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_description         TEXT CHARACTER SET utf8mb4,
    IN  p_duration_minutes    INT,
    IN  p_max_group_size      INT,
    IN  p_language_codes      VARCHAR(100),
    IN  p_pickup_mode         VARCHAR(20),
    IN  p_meeting_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_transport           VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_guide_info          VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_dropoff_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN  p_source_url          VARCHAR(600),
    IN  p_verification_status VARCHAR(20),
    OUT p_field               VARCHAR(30),
    OUT p_destination_name    VARCHAR(100) CHARACTER SET utf8mb4
)
READS SQL DATA
BEGIN
    SET p_field = NULL;
    SET p_destination_name = NULL;

    SELECT d.name INTO p_destination_name
      FROM destinations d
     WHERE d.id = (p_destination_id COLLATE utf8mb4_unicode_ci);

    IF p_provider_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM providers WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci)) THEN
        SET p_field = 'provider_id';
    ELSEIF p_destination_name IS NULL THEN
        SET p_field = 'destination_id';
    ELSEIF p_category_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM categories WHERE id = (p_category_id COLLATE utf8mb4_unicode_ci)) THEN
        SET p_field = 'category_id';
    ELSEIF p_title IS NULL OR p_title = '' OR CHAR_LENGTH(p_title) > 200 THEN
        SET p_field = 'title';
    ELSEIF p_description IS NULL OR p_description = '' THEN
        SET p_field = 'description';
    ELSEIF p_duration_minutes IS NULL OR p_duration_minutes NOT BETWEEN 15 AND 10080 THEN
        SET p_field = 'duration_minutes';
    ELSEIF p_max_group_size IS NULL OR p_max_group_size NOT BETWEEN 1 AND 500 THEN
        SET p_field = 'max_group_size';
    ELSEIF p_language_codes IS NULL OR CHAR_LENGTH(p_language_codes) > 50
        OR BINARY p_language_codes NOT REGEXP '^[a-z]{2}(,[a-z]{2})*$' THEN
        -- BINARY: REGEXP theo collation _ci không phân biệt hoa thường.
        SET p_field = 'language_codes';
    ELSEIF COALESCE(p_pickup_mode, '') NOT IN ('meeting_point', 'hotel_pickup') THEN
        SET p_field = 'pickup_mode';
    ELSEIF (p_pickup_mode = 'meeting_point' AND p_meeting_point IS NULL)
        OR CHAR_LENGTH(p_meeting_point) > 255 THEN
        SET p_field = 'meeting_point';
    ELSEIF CHAR_LENGTH(p_transport) > 255 THEN
        SET p_field = 'transport';
    ELSEIF CHAR_LENGTH(p_guide_info) > 255 THEN
        SET p_field = 'guide_info';
    ELSEIF CHAR_LENGTH(p_dropoff_point) > 255 THEN
        SET p_field = 'dropoff_point';
    ELSEIF CHAR_LENGTH(p_source_url) > 500
        OR (p_source_url IS NOT NULL AND p_source_url NOT REGEXP '^https?://[^ ]+$') THEN
        SET p_field = 'source_url';
    ELSEIF COALESCE(p_verification_status, '') NOT IN ('unverified', 'verified') THEN
        SET p_field = 'verification_status';
    ELSEIF p_verification_status = 'verified' AND p_source_url IS NULL THEN
        -- NFR-07: thiếu nguồn thì không được đánh dấu đã xác minh.
        SET p_field = 'source_url';
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_create(p_actor_user_id, p_provider_id, p_destination_id,
--   p_category_id, p_title, p_description, p_duration_minutes, p_max_group_size,
--   p_language_codes, p_pickup_mode, p_meeting_point, p_transport, p_guide_info,
--   p_dropoff_point, p_document_terms, p_meal_terms, p_voucher_terms,
--   p_reschedule_terms, p_source_url, p_verification_status)
--   Thêm tour ở trạng thái 'pending' (chờ duyệt), ghi admin_logs 'tour_create'
--   (from NULL, to 'pending'). Ô không bắt buộc để trống = NULL.
--   1 dòng: result, field, tour_id.
--     result = 'ok'        : đã thêm; tour_id = mã tour mới.
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'invalid'   : dữ liệu sai; field = ô sai đầu tiên (xem
--                            NMT_sp_admin_tour_validate).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_create;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_create(
    IN p_actor_user_id       CHAR(36),
    IN p_provider_id         CHAR(36),
    IN p_destination_id      CHAR(36),
    IN p_category_id         CHAR(36),
    IN p_title               VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_description         TEXT CHARACTER SET utf8mb4,
    IN p_duration_minutes    INT,
    IN p_max_group_size      INT,
    IN p_language_codes      VARCHAR(100),
    IN p_pickup_mode         VARCHAR(20),
    IN p_meeting_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_transport           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_guide_info          VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_dropoff_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_document_terms      TEXT CHARACTER SET utf8mb4,
    IN p_meal_terms          TEXT CHARACTER SET utf8mb4,
    IN p_voucher_terms       TEXT CHARACTER SET utf8mb4,
    IN p_reschedule_terms    TEXT CHARACTER SET utf8mb4,
    IN p_source_url          VARCHAR(600),
    IN p_verification_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_title       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_title), '');
    DECLARE v_description TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_description), '');
    DECLARE v_languages   VARCHAR(100) DEFAULT NULLIF(TRIM(p_language_codes), '');
    DECLARE v_meeting     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_meeting_point), '');
    DECLARE v_transport   VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_transport), '');
    DECLARE v_guide       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_guide_info), '');
    DECLARE v_dropoff     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_dropoff_point), '');
    DECLARE v_source      VARCHAR(600) DEFAULT NULLIF(TRIM(p_source_url), '');
    DECLARE v_category    CHAR(36)     DEFAULT NULLIF(p_category_id, '');
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_destination VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_tour_id     CHAR(36)     DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    CALL NMT_sp_admin_tour_validate(p_provider_id, p_destination_id, v_category, v_title,
        v_description, p_duration_minutes, p_max_group_size, v_languages, p_pickup_mode,
        v_meeting, v_transport, v_guide, v_dropoff, v_source, p_verification_status,
        v_field, v_destination);

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    INSERT INTO tours (id, provider_id, destination_id, category_id, title, description,
                       destination, duration_minutes, max_group_size, language_codes,
                       pickup_mode, meeting_point, included_summary, transport, guide_info,
                       dropoff_point, excluded_summary, document_terms, meal_terms,
                       voucher_terms, reschedule_terms, source_url, verified_at,
                       verification_status, approval_status)
    VALUES (v_tour_id, p_provider_id, p_destination_id, v_category, v_title, v_description,
            v_destination, p_duration_minutes, p_max_group_size, v_languages,
            p_pickup_mode, v_meeting, NULL, v_transport, v_guide,
            v_dropoff, NULL, NULLIF(TRIM(p_document_terms), ''), NULLIF(TRIM(p_meal_terms), ''),
            NULLIF(TRIM(p_voucher_terms), ''), NULLIF(TRIM(p_reschedule_terms), ''), v_source,
            IF(p_verification_status = 'verified', CURDATE(), NULL),
            p_verification_status, 'pending');

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', v_tour_id, 'tour_create', NULL, 'pending', NULL, NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_tour_id AS tour_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_update(p_actor_user_id, p_tour_id, ... cùng tham số với
--   NMT_sp_admin_tour_create)
--   Sửa thông tin tour, giữ nguyên approval_status. Ghi admin_logs 'tour_update':
--   from / to = trạng thái xác minh trước / sau, note = các ô đã sửa.
--   1 dòng: result, field, tour_id.
--     result = 'ok'        : đã lưu.
--              'unchanged' : dữ liệu giống hệt hiện tại, không ghi gì.
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found' : không có tour này.
--              'invalid'   : dữ liệu sai; field như NMT_sp_admin_tour_create.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_update;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_update(
    IN p_actor_user_id       CHAR(36),
    IN p_tour_id             CHAR(36),
    IN p_provider_id         CHAR(36),
    IN p_destination_id      CHAR(36),
    IN p_category_id         CHAR(36),
    IN p_title               VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_description         TEXT CHARACTER SET utf8mb4,
    IN p_duration_minutes    INT,
    IN p_max_group_size      INT,
    IN p_language_codes      VARCHAR(100),
    IN p_pickup_mode         VARCHAR(20),
    IN p_meeting_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_transport           VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_guide_info          VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_dropoff_point       VARCHAR(300) CHARACTER SET utf8mb4,
    IN p_document_terms      TEXT CHARACTER SET utf8mb4,
    IN p_meal_terms          TEXT CHARACTER SET utf8mb4,
    IN p_voucher_terms       TEXT CHARACTER SET utf8mb4,
    IN p_reschedule_terms    TEXT CHARACTER SET utf8mb4,
    IN p_source_url          VARCHAR(600),
    IN p_verification_status VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_title       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_title), '');
    DECLARE v_description TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_description), '');
    DECLARE v_languages   VARCHAR(100) DEFAULT NULLIF(TRIM(p_language_codes), '');
    DECLARE v_meeting     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_meeting_point), '');
    DECLARE v_transport   VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_transport), '');
    DECLARE v_guide       VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_guide_info), '');
    DECLARE v_dropoff     VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_dropoff_point), '');
    DECLARE v_documents   TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_document_terms), '');
    DECLARE v_meals       TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_meal_terms), '');
    DECLARE v_vouchers    TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_voucher_terms), '');
    DECLARE v_reschedule  TEXT CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_reschedule_terms), '');
    DECLARE v_source      VARCHAR(600) DEFAULT NULLIF(TRIM(p_source_url), '');
    DECLARE v_category    CHAR(36)     DEFAULT NULLIF(p_category_id, '');
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_destination VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_changes     VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT '';
    -- Giá trị hiện tại (o_ = old)
    DECLARE o_provider    CHAR(36)     DEFAULT NULL;
    DECLARE o_destination CHAR(36)     DEFAULT NULL;
    DECLARE o_category    CHAR(36)     DEFAULT NULL;
    DECLARE o_title       VARCHAR(200) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_description TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_duration    INT          DEFAULT NULL;
    DECLARE o_group       INT          DEFAULT NULL;
    DECLARE o_languages   VARCHAR(50)  DEFAULT NULL;
    DECLARE o_pickup      VARCHAR(20)  DEFAULT NULL;
    DECLARE o_meeting     VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_transport   VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_guide       VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_dropoff     VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_documents   TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_meals       TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_vouchers    TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_reschedule  TEXT CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE o_source      VARCHAR(500) DEFAULT NULL;
    DECLARE o_verified    VARCHAR(20)  DEFAULT NULL;
    DECLARE o_verified_at DATE         DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    CALL NMT_sp_admin_tour_validate(p_provider_id, p_destination_id, v_category, v_title,
        v_description, p_duration_minutes, p_max_group_size, v_languages, p_pickup_mode,
        v_meeting, v_transport, v_guide, v_dropoff, v_source, p_verification_status,
        v_field, v_destination);

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, p_tour_id AS tour_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT t.provider_id, t.destination_id, t.category_id, t.title, t.description,
           t.duration_minutes, t.max_group_size, t.language_codes, t.pickup_mode,
           t.meeting_point, t.transport, t.guide_info, t.dropoff_point, t.document_terms,
           t.meal_terms, t.voucher_terms, t.reschedule_terms, t.source_url,
           t.verification_status, t.verified_at
      INTO o_provider, o_destination, o_category, o_title, o_description,
           o_duration, o_group, o_languages, o_pickup,
           o_meeting, o_transport, o_guide, o_dropoff, o_documents,
           o_meals, o_vouchers, o_reschedule, o_source,
           o_verified, o_verified_at
      FROM tours t
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF o_title IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS tour_id;
        LEAVE proc;
    END IF;

    SET v_changes = CONCAT_WS(', ',
        IF(NOT (BINARY o_title       <=> BINARY v_title),          'tên tour', NULL),
        IF(NOT (BINARY o_provider    <=> BINARY p_provider_id),    'đơn vị tổ chức', NULL),
        IF(NOT (BINARY o_destination <=> BINARY p_destination_id), 'điểm đến', NULL),
        IF(NOT (BINARY o_category    <=> BINARY v_category),       'loại hình', NULL),
        IF(NOT (BINARY o_description <=> BINARY v_description),    'mô tả', NULL),
        IF(NOT (o_duration <=> p_duration_minutes),                'thời lượng', NULL),
        IF(NOT (o_group    <=> p_max_group_size),                  'số khách tối đa', NULL),
        IF(NOT (BINARY o_languages   <=> BINARY v_languages),      'ngôn ngữ', NULL),
        IF(NOT (BINARY o_pickup      <=> BINARY p_pickup_mode),    'hình thức đón', NULL),
        IF(NOT (BINARY o_meeting     <=> BINARY v_meeting),        'điểm hẹn', NULL),
        IF(NOT (BINARY o_transport   <=> BINARY v_transport),      'phương tiện', NULL),
        IF(NOT (BINARY o_guide       <=> BINARY v_guide),          'hướng dẫn viên', NULL),
        IF(NOT (BINARY o_dropoff     <=> BINARY v_dropoff),        'điểm trả khách', NULL),
        IF(NOT (BINARY o_documents   <=> BINARY v_documents),      'giấy tờ', NULL),
        IF(NOT (BINARY o_meals       <=> BINARY v_meals),          'ăn uống', NULL),
        IF(NOT (BINARY o_vouchers    <=> BINARY v_vouchers),       'voucher', NULL),
        IF(NOT (BINARY o_reschedule  <=> BINARY v_reschedule),     'đổi lịch', NULL),
        IF(NOT (BINARY o_source      <=> BINARY v_source),         'nguồn tham khảo', NULL));

    IF v_changes = '' AND o_verified = p_verification_status THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, p_tour_id AS tour_id;
        LEAVE proc;
    END IF;

    UPDATE tours
       SET provider_id = p_provider_id,
           destination_id = p_destination_id,
           category_id = v_category,
           title = v_title,
           description = v_description,
           destination = v_destination,
           duration_minutes = p_duration_minutes,
           max_group_size = p_max_group_size,
           language_codes = v_languages,
           pickup_mode = p_pickup_mode,
           meeting_point = v_meeting,
           transport = v_transport,
           guide_info = v_guide,
           dropoff_point = v_dropoff,
           document_terms = v_documents,
           meal_terms = v_meals,
           voucher_terms = v_vouchers,
           reschedule_terms = v_reschedule,
           source_url = v_source,
           verified_at = CASE
                             WHEN p_verification_status = 'unverified' THEN NULL
                             WHEN o_verified = 'verified' AND o_verified_at IS NOT NULL THEN o_verified_at
                             ELSE CURDATE()
                         END,
           verification_status = p_verification_status
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_update', o_verified, p_verification_status,
            IF(v_changes = '', NULL, LEFT(CONCAT('Sửa: ', v_changes), 255)), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, p_tour_id AS tour_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_list(p_tour_id)
--   Mọi lịch của tour: lịch chưa khởi hành trước (sớm nhất trước), rồi lịch đã qua
--   (gần nhất trước). Cột: schedule_id, starts_at, ends_at, capacity, remaining,
--   held (= capacity - remaining, số chỗ đang giữ), status, departed (1 = đã tới giờ
--   khởi hành), adult_ticket_id, adult_price_vnd, adult_active, child_ticket_id,
--   child_price_vnd, child_active (NULL khi lịch không có loại vé đó),
--   active_booking_count (đơn pending / awaiting_payment / confirmed).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id                                   AS schedule_id,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        GREATEST(0, s.capacity - s.remaining)  AS held,
        s.status,
        (s.starts_at <= NOW())                 AS departed,
        ad.id                                  AS adult_ticket_id,
        ad.price_vnd                           AS adult_price_vnd,
        ad.active                              AS adult_active,
        ch.id                                  AS child_ticket_id,
        ch.price_vnd                           AS child_price_vnd,
        ch.active                              AS child_active,
        (SELECT COUNT(*)
           FROM bookings b
          WHERE b.schedule_id = s.id
            AND b.status IN ('pending', 'awaiting_payment', 'confirmed')) AS active_booking_count
    FROM schedules s
    LEFT JOIN ticket_types ad ON ad.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'adult'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    LEFT JOIN ticket_types ch ON ch.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'child'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY (s.starts_at <= NOW()),
             IF(s.starts_at <= NOW(), NULL, s.starts_at),
             s.starts_at DESC,
             s.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_detail(p_schedule_id)
--   0 hoặc 1 dòng: các cột của NMT_sp_admin_schedule_list cho một lịch, thêm tour_id,
--   tour_title, pending_booking_count và pending_people (đơn 'pending' chưa giữ chỗ:
--   số đơn và tổng số khách).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_detail;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_detail(
    IN p_schedule_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        s.id                                   AS schedule_id,
        t.id                                   AS tour_id,
        t.title                                AS tour_title,
        s.starts_at,
        s.ends_at,
        s.capacity,
        s.remaining,
        GREATEST(0, s.capacity - s.remaining)  AS held,
        s.status,
        (s.starts_at <= NOW())                 AS departed,
        ad.id                                  AS adult_ticket_id,
        ad.price_vnd                           AS adult_price_vnd,
        ad.active                              AS adult_active,
        ch.id                                  AS child_ticket_id,
        ch.price_vnd                           AS child_price_vnd,
        ch.active                              AS child_active,
        (SELECT COUNT(*)
           FROM bookings b
          WHERE b.schedule_id = s.id
            AND b.status IN ('pending', 'awaiting_payment', 'confirmed')) AS active_booking_count,
        (SELECT COUNT(*)
           FROM bookings b
          WHERE b.schedule_id = s.id AND b.status = 'pending') AS pending_booking_count,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM bookings b
           JOIN booking_lines bl ON bl.booking_id = b.id
          WHERE b.schedule_id = s.id AND b.status = 'pending') AS pending_people
    FROM schedules s
    JOIN tours t ON t.id = s.tour_id
    LEFT JOIN ticket_types ad ON ad.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'adult'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    LEFT JOIN ticket_types ch ON ch.id = (
        SELECT tt.id FROM ticket_types tt
         WHERE tt.schedule_id = s.id AND tt.name = 'child'
         ORDER BY tt.active DESC, tt.id LIMIT 1)
    WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_create(p_actor_user_id, p_tour_id, p_starts_at, p_ends_at,
--                              p_capacity, p_adult_price_vnd, p_child_price_vnd)
--   Thêm lịch 'open' (remaining = capacity), vé 'adult' (từ 12 tuổi) và vé 'child'
--   (4 - 11 tuổi) khi p_child_price_vnd khác NULL. Ghi admin_logs 'schedule_create'.
--   Giới hạn: starts_at sau hiện tại, ends_at sau starts_at, capacity 1 - 500, giá vé
--   1 - 100.000.000 đ.
--   1 dòng: result, field, schedule_id.
--     result = 'ok'        : đã thêm; schedule_id = mã lịch mới.
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found' : không có tour này.
--              'invalid'   : dữ liệu sai; field = starts_at, ends_at, capacity,
--                            adult_price hoặc child_price.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_create;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_create(
    IN p_actor_user_id   CHAR(36),
    IN p_tour_id         CHAR(36),
    IN p_starts_at       DATETIME,
    IN p_ends_at         DATETIME,
    IN p_capacity        INT,
    IN p_adult_price_vnd BIGINT,
    IN p_child_price_vnd BIGINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_field       VARCHAR(30) DEFAULT NULL;
    DECLARE v_schedule_id CHAR(36)    DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS schedule_id;
        LEAVE proc;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)) THEN
        SELECT 'not_found' AS result, NULL AS field, NULL AS schedule_id;
        LEAVE proc;
    END IF;

    IF p_starts_at IS NULL OR p_starts_at <= NOW() THEN
        SET v_field = 'starts_at';
    ELSEIF p_ends_at IS NULL OR p_ends_at <= p_starts_at THEN
        SET v_field = 'ends_at';
    ELSEIF p_capacity IS NULL OR p_capacity NOT BETWEEN 1 AND 500 THEN
        SET v_field = 'capacity';
    ELSEIF p_adult_price_vnd IS NULL OR p_adult_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'adult_price';
    ELSEIF p_child_price_vnd IS NOT NULL AND p_child_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'child_price';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, NULL AS schedule_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    INSERT INTO schedules (id, tour_id, starts_at, ends_at, capacity, remaining, status)
    VALUES (v_schedule_id, p_tour_id, p_starts_at, p_ends_at, p_capacity, p_capacity, 'open');

    INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
    VALUES (UUID(), v_schedule_id, 'adult', 12, NULL, p_adult_price_vnd, TRUE);

    IF p_child_price_vnd IS NOT NULL THEN
        INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
        VALUES (UUID(), v_schedule_id, 'child', 4, 11, p_child_price_vnd, TRUE);
    END IF;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'schedule', v_schedule_id, 'schedule_create', NULL, 'open',
            CONCAT('Khởi hành ', DATE_FORMAT(p_starts_at, '%d/%m/%Y %H:%i'),
                   ', ', p_capacity, ' chỗ, người lớn ',
                   REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ',
                   IF(p_child_price_vnd IS NULL, '',
                      CONCAT(', trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ'))),
            NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_schedule_id AS schedule_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_update(p_actor_user_id, p_schedule_id, p_starts_at, p_ends_at,
--                              p_capacity, p_adult_price_vnd, p_child_price_vnd, p_status)
--   Sửa lịch trong một transaction (khóa dòng lịch FOR UPDATE):
--     - giờ khởi hành / kết thúc chỉ đổi khi lịch chưa khởi hành; giờ mới phải sau hiện
--       tại và ends_at sau starts_at;
--     - capacity mới >= held; remaining = capacity mới - held;
--     - p_status 'open' (đang mở bán) hoặc 'cancelled' (hủy lịch). Lịch không hủy thì
--       status = 'full' khi remaining = 0, ngược lại 'open';
--     - giá vé: cập nhật price_vnd của vé 'adult' / 'child' (thêm vé nếu chưa có);
--       p_child_price_vnd NULL = ngừng bán vé trẻ em (active = FALSE).
--   Ghi admin_logs 'schedule_update' (from / to = trạng thái lịch, note = nội dung sửa).
--   1 dòng: result, field, status, held, active_bookings.
--     result = 'ok'                  : đã lưu; status = trạng thái mới.
--              'unchanged'           : không có gì thay đổi.
--              'forbidden'           : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'           : không có lịch này.
--              'invalid'             : dữ liệu sai; field = starts_at, ends_at, capacity,
--                                      adult_price, child_price hoặc status.
--              'completed'           : lịch đã hoàn thành, không sửa được.
--              'departed'            : đổi giờ hoặc đổi trạng thái khi lịch đã khởi hành.
--              'capacity_below_held' : capacity mới nhỏ hơn số chỗ đang giữ (held).
--              'has_bookings'        : hủy lịch khi còn đơn pending / awaiting_payment /
--                                      confirmed (active_bookings = số đơn đó).
--     Khi không 'ok', status / held là giá trị hiện tại, không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_update;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_update(
    IN p_actor_user_id   CHAR(36),
    IN p_schedule_id     CHAR(36),
    IN p_starts_at       DATETIME,
    IN p_ends_at         DATETIME,
    IN p_capacity        INT,
    IN p_adult_price_vnd BIGINT,
    IN p_child_price_vnd BIGINT,
    IN p_status          VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_field        VARCHAR(30)  DEFAULT NULL;
    DECLARE v_old_starts   DATETIME     DEFAULT NULL;
    DECLARE v_old_ends     DATETIME     DEFAULT NULL;
    DECLARE v_old_capacity INT          DEFAULT NULL;
    DECLARE v_old_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_held         INT          DEFAULT 0;
    DECLARE v_remaining    INT          DEFAULT 0;
    DECLARE v_new_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_departed     BOOLEAN      DEFAULT FALSE;
    DECLARE v_time_changed BOOLEAN      DEFAULT FALSE;
    DECLARE v_active       INT          DEFAULT 0;
    DECLARE v_adult_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_adult_price  BIGINT       DEFAULT NULL;
    DECLARE v_adult_active BOOLEAN      DEFAULT NULL;
    DECLARE v_child_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_child_price  BIGINT       DEFAULT NULL;
    DECLARE v_child_active BOOLEAN      DEFAULT NULL;
    DECLARE v_old_child    BIGINT       DEFAULT NULL;
    DECLARE v_changes      VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS status, NULL AS held, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa dòng lịch: số chỗ và trạng thái chỉ đổi trong transaction này (đặt tour và
    -- xác nhận chỗ cũng khóa dòng này).
    SELECT s.starts_at, s.ends_at, s.capacity, s.status, GREATEST(0, s.capacity - s.remaining)
      INTO v_old_starts, v_old_ends, v_old_capacity, v_old_status, v_held
      FROM schedules s
     WHERE s.id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_old_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS status, NULL AS held, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_active
      FROM bookings b
     WHERE b.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci)
       AND b.status IN ('pending', 'awaiting_payment', 'confirmed');

    IF v_old_status = 'completed' THEN
        ROLLBACK;
        SELECT 'completed' AS result, NULL AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    SET v_departed = (v_old_starts <= NOW());
    SET v_time_changed = NOT (p_starts_at <=> v_old_starts) OR NOT (p_ends_at <=> v_old_ends);

    IF COALESCE(p_status, '') NOT IN ('open', 'cancelled') THEN
        SET v_field = 'status';
    ELSEIF p_starts_at IS NULL OR (v_time_changed AND NOT v_departed AND p_starts_at <= NOW()) THEN
        SET v_field = 'starts_at';
    ELSEIF p_ends_at IS NULL OR p_ends_at <= p_starts_at THEN
        SET v_field = 'ends_at';
    ELSEIF p_capacity IS NULL OR p_capacity NOT BETWEEN 1 AND 500 THEN
        SET v_field = 'capacity';
    ELSEIF p_adult_price_vnd IS NULL OR p_adult_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'adult_price';
    ELSEIF p_child_price_vnd IS NOT NULL AND p_child_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'child_price';
    END IF;

    IF v_field IS NOT NULL THEN
        ROLLBACK;
        SELECT 'invalid' AS result, v_field AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    -- Lịch đã khởi hành: không đổi giờ, không hủy / mở lại.
    IF v_departed AND (v_time_changed
                       OR (p_status = 'cancelled') <> (v_old_status = 'cancelled')) THEN
        ROLLBACK;
        SELECT 'departed' AS result, NULL AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    IF p_capacity < v_held THEN
        ROLLBACK;
        SELECT 'capacity_below_held' AS result, 'capacity' AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    IF p_status = 'cancelled' AND v_old_status <> 'cancelled' AND v_active > 0 THEN
        ROLLBACK;
        SELECT 'has_bookings' AS result, 'status' AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    SET v_remaining = p_capacity - v_held;
    SET v_new_status = IF(p_status = 'cancelled', 'cancelled', IF(v_remaining = 0, 'full', 'open'));

    -- Vé hiện tại (ưu tiên vé đang bán)
    SELECT tt.id, tt.price_vnd, tt.active INTO v_adult_id, v_adult_price, v_adult_active
      FROM ticket_types tt
     WHERE tt.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci) AND tt.name = 'adult'
     ORDER BY tt.active DESC, tt.id
     LIMIT 1
       FOR UPDATE;

    SELECT tt.id, tt.price_vnd, tt.active INTO v_child_id, v_child_price, v_child_active
      FROM ticket_types tt
     WHERE tt.schedule_id = (p_schedule_id COLLATE utf8mb4_unicode_ci) AND tt.name = 'child'
     ORDER BY tt.active DESC, tt.id
     LIMIT 1
       FOR UPDATE;

    -- Giá trẻ em đang bán (NULL = không bán vé trẻ em)
    SET v_old_child = IF(v_child_active, v_child_price, NULL);

    SET v_changes = CONCAT_WS(', ',
        IF(v_time_changed,
           CONCAT('giờ ', DATE_FORMAT(p_starts_at, '%d/%m/%Y %H:%i'), ' - ', DATE_FORMAT(p_ends_at, '%d/%m/%Y %H:%i')),
           NULL),
        IF(p_capacity <> v_old_capacity, CONCAT('sức chứa ', v_old_capacity, ' → ', p_capacity), NULL),
        IF(v_adult_id IS NULL OR NOT v_adult_active OR v_adult_price <> p_adult_price_vnd,
           CONCAT('giá người lớn ', REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ'), NULL),
        IF(NOT (v_old_child <=> p_child_price_vnd),
           IF(p_child_price_vnd IS NULL, 'ngừng bán vé trẻ em',
              CONCAT('giá trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ')),
           NULL));

    IF v_changes = '' AND v_new_status = v_old_status THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_old_status AS status, v_held AS held, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    UPDATE schedules
       SET starts_at = p_starts_at,
           ends_at = p_ends_at,
           capacity = p_capacity,
           remaining = v_remaining,
           status = v_new_status
     WHERE id = (p_schedule_id COLLATE utf8mb4_unicode_ci);

    IF v_adult_id IS NULL THEN
        INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
        VALUES (UUID(), p_schedule_id, 'adult', 12, NULL, p_adult_price_vnd, TRUE);
    ELSEIF NOT v_adult_active OR v_adult_price <> p_adult_price_vnd THEN
        UPDATE ticket_types SET price_vnd = p_adult_price_vnd, active = TRUE WHERE id = v_adult_id;
    END IF;

    IF p_child_price_vnd IS NULL THEN
        IF v_child_active THEN
            UPDATE ticket_types SET active = FALSE WHERE id = v_child_id;
        END IF;
    ELSEIF v_child_id IS NULL THEN
        INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active)
        VALUES (UUID(), p_schedule_id, 'child', 4, 11, p_child_price_vnd, TRUE);
    ELSEIF NOT v_child_active OR v_child_price <> p_child_price_vnd THEN
        UPDATE ticket_types SET price_vnd = p_child_price_vnd, active = TRUE WHERE id = v_child_id;
    END IF;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'schedule', p_schedule_id, 'schedule_update', v_old_status, v_new_status,
            IF(v_changes = '', NULL, LEFT(CONCAT('Sửa: ', v_changes), 255)), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_new_status AS status, v_held AS held, v_active AS active_bookings;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_schedule_log_list(p_tour_id)
--   Lịch sử thêm / sửa các lịch khởi hành của một tour, mới nhất trước, tối đa 100 dòng.
--   Cột: created_at, actor_name, action, from_status, to_status, note, schedule_id,
--   starts_at (giờ khởi hành hiện tại của lịch).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_schedule_log_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_schedule_log_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        l.created_at,
        u.name            AS actor_name,
        l.action,
        l.from_status,
        l.to_status,
        l.note,
        s.id              AS schedule_id,
        s.starts_at
    FROM admin_logs l
    JOIN schedules s ON s.id = l.target_id
    JOIN users u     ON u.id = l.actor_user_id
    WHERE l.target_type = 'schedule'
      AND s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY l.created_at DESC, l.id
    LIMIT 100;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.3 - 14_procedures_NMT_payment.sql
-- Mục đích  : Thanh toán của khách hàng (VNPay, VietQR) và đối chiếu chuyển khoản VietQR
--             của quản trị viên.
-- Phụ trách : Nguyễn Minh Thức (NMT) - Sprint 4: 4.5.1.2, 4.5.3.1, 4.5.3.2
-- Procedures: NMT_sp_payment_list, NMT_sp_payment_start, NMT_sp_payment_get,
--             NMT_sp_payment_transfer_submit, NMT_sp_admin_payment_queue,
--             NMT_sp_admin_payment_decide
-- Quy tắc   : * Chỉ đơn 'awaiting_payment' (đã xác nhận chỗ và giá) còn trong hạn giữ chỗ
--               mới thanh toán được. Số tiền = bookings.total_vnd (giá quản trị viên đã chốt).
--             * Mỗi lần bắt đầu thanh toán VNPay là một khoản 'pending' mới với mã riêng
--               (reference = mã đơn + P + số thứ tự, vd. LT518204P2) gửi làm vnp_TxnRef.
--             * VietQR dùng lại khoản VietQR 'pending' đang có của đơn (cùng nội dung chuyển
--               khoản); khách bấm "Tôi đã chuyển khoản" -> 'awaiting_reconciliation'.
--             * Đơn đang có khoản chờ đối chiếu thì không bắt đầu khoản mới (tránh thu hai lần);
--               đơn này cũng không bị tự hủy khi quá hạn (15_procedures_LTP_payment.sql).
--             * Quản trị viên đối chiếu: "Đã nhận tiền" -> khoản 'paid', đơn 'confirmed', cấp
--               voucher; "Không khớp" (bắt buộc lý do) -> khoản 'failed', đơn vẫn chờ thanh toán
--               tới hết hạn. Mỗi lần đối chiếu ghi admin_logs của đơn (NFR-09).
--             * Nhiều khoản tạo trong cùng một giây được xếp theo số thứ tự trong reference.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 12. NMT_sp_admin_payment_decide gọi LTP_sp_voucher_issue (file 15).
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_payment_list(p_user_id, p_code)
--   Các khoản thanh toán của đơn (chỉ đơn của tài khoản này), mới trước.
--   Cột: payment_id, method, reference, amount_vnd, status, created_at, submitted_at,
--   paid_at, response_code, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.method,
        COALESCE(p.reference, p.provider_txn_id) AS reference,
        p.amount_vnd,
        p.status,
        p.created_at,
        p.submitted_at,
        p.paid_at,
        p.response_code,
        p.note
    FROM payments p
    JOIN bookings b ON b.id = p.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY p.created_at DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_payment_start(p_user_id, p_code, p_method)
--   Bắt đầu thanh toán đơn p_code bằng p_method ('vnpay' / 'vietqr').
--   1 dòng: result, payment_id, reference, amount_vnd, expires_at.
--     result = 'ok'                      : khoản sẵn sàng (VNPay: khoản mới; VietQR: khoản
--                                          'pending' đang có hoặc khoản mới).
--              'not_found'               : không có đơn này trong tài khoản.
--              'not_payable'             : đơn không ở 'awaiting_payment' hoặc đã thanh toán.
--              'expired'                 : đã quá hạn giữ chỗ (đơn sẽ bị tự hủy).
--              'awaiting_reconciliation' : đã báo chuyển khoản, đang chờ đối chiếu.
--              'invalid'                 : phương thức không hợp lệ.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_start;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_start(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20),
    IN p_method  VARCHAR(10)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_code       VARCHAR(20) DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_total      BIGINT      DEFAULT NULL;
    DECLARE v_hold       DATETIME    DEFAULT NULL;
    DECLARE v_payment_id CHAR(36)    DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE v_count      INT         DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_method IS NULL OR p_method NOT IN ('vnpay', 'vietqr') THEN
        SELECT 'invalid' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT b.id, b.code, b.status, b.total_vnd, b.hold_expires_at
      INTO v_booking_id, v_code, v_status, v_total, v_hold
      FROM bookings b
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_status <> 'awaiting_payment'
       OR EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'paid') THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'awaiting_reconciliation') THEN
        ROLLBACK;
        SELECT 'awaiting_reconciliation' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_hold IS NULL OR v_hold <= NOW() THEN
        ROLLBACK;
        SELECT 'expired' AS result, NULL AS payment_id, NULL AS reference, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    -- VietQR: dùng lại khoản đang chờ chuyển khoản nếu đúng số tiền hiện tại.
    IF p_method = 'vietqr' THEN
        SELECT p.id, p.reference INTO v_payment_id, v_reference
          FROM payments p
         WHERE p.booking_id = v_booking_id
           AND p.method = 'vietqr'
           AND p.status = 'pending'
           AND p.amount_vnd = v_total
           AND p.reference IS NOT NULL
         ORDER BY p.created_at DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id
         LIMIT 1;
    END IF;

    IF v_payment_id IS NULL THEN
        SELECT COUNT(*) INTO v_count FROM payments p WHERE p.booking_id = v_booking_id;
        SET v_payment_id = UUID();
        SET v_reference = CONCAT(v_code, 'P', v_count + 1);

        INSERT INTO payments (id, booking_id, method, reference, provider_txn_id, amount_vnd, status,
                              expires_at, paid_at, created_at)
        VALUES (v_payment_id, v_booking_id, p_method, v_reference, NULL, v_total, 'pending',
                v_hold, NULL, NOW());
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_payment_id AS payment_id, v_reference AS reference, v_total AS amount_vnd, v_hold AS expires_at;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_payment_get(p_user_id, p_code, p_method)
--   Khoản mới nhất của đơn theo phương thức (trang chuyển khoản VietQR), 0 hoặc 1 dòng.
--   Cột: payment_id, method, reference, amount_vnd, status, created_at, submitted_at, note,
--   booking_status, hold_expires_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_get;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_get(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20),
    IN p_method  VARCHAR(10)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.method,
        p.reference,
        p.amount_vnd,
        p.status,
        p.created_at,
        p.submitted_at,
        p.note,
        b.status        AS booking_status,
        b.hold_expires_at
    FROM payments p
    JOIN bookings b ON b.id = p.booking_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
      AND p.method = (p_method COLLATE utf8mb4_unicode_ci)
      AND p.reference IS NOT NULL
    ORDER BY p.created_at DESC, CAST(SUBSTRING_INDEX(p.reference, 'P', -1) AS UNSIGNED) DESC, p.id
    LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_payment_transfer_submit(p_user_id, p_code, p_payment_id)
--   Khách báo đã chuyển khoản VietQR: khoản 'pending' -> 'awaiting_reconciliation'.
--   1 dòng: result = 'ok' | 'already' (đã báo rồi) | 'not_found' | 'not_payable' | 'expired'.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_payment_transfer_submit;

DELIMITER $$
CREATE PROCEDURE NMT_sp_payment_transfer_submit(
    IN p_user_id    CHAR(36),
    IN p_code       VARCHAR(20),
    IN p_payment_id CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_hold       DATETIME    DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT p.status, p.reference, b.id, b.status, b.hold_expires_at
      INTO v_pay_status, v_reference, v_booking_id, v_status, v_hold
      FROM payments p
      JOIN bookings b ON b.id = p.booking_id
     WHERE p.id = (p_payment_id COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vietqr'
       AND b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    IF v_pay_status = 'awaiting_reconciliation' THEN
        ROLLBACK;
        SELECT 'already' AS result;
        LEAVE proc;
    END IF;

    IF v_status <> 'awaiting_payment' OR v_pay_status <> 'pending' THEN
        ROLLBACK;
        SELECT 'not_payable' AS result;
        LEAVE proc;
    END IF;

    IF v_hold IS NULL OR v_hold <= NOW() THEN
        ROLLBACK;
        SELECT 'expired' AS result;
        LEAVE proc;
    END IF;

    UPDATE payments
       SET status = 'awaiting_reconciliation', submitted_at = NOW()
     WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'customer', p_user_id, 'transfer_submitted', NULL, NULL,
            CONCAT('Khách báo đã chuyển khoản VietQR, nội dung ', v_reference), NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_payment_queue()
--   Khoản VietQR khách đã báo chuyển khoản, đang chờ quản trị viên đối chiếu (báo trước
--   lên trước). Cột: payment_id, reference, amount_vnd, submitted_at, created_at, booking_id,
--   code, booking_status, total_vnd, hold_expires_at, contact_name, contact_phone,
--   tour_title, starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_payment_queue;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_payment_queue()
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        COALESCE(p.reference, p.provider_txn_id) AS reference,
        p.amount_vnd,
        p.submitted_at,
        p.created_at,
        b.id            AS booking_id,
        b.code,
        b.status        AS booking_status,
        b.total_vnd,
        b.hold_expires_at,
        b.contact_name,
        b.contact_phone,
        t.title         AS tour_title,
        s.starts_at
    FROM payments p
    JOIN bookings b  ON b.id = p.booking_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE p.method = 'vietqr'
      AND p.status = 'awaiting_reconciliation'
    ORDER BY COALESCE(p.submitted_at, p.created_at), p.id
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_payment_decide(p_payment_id, p_decision, p_actor_user_id, p_note)
--   Đối chiếu một khoản VietQR đang 'awaiting_reconciliation'.
--   p_decision = 'confirm' (đã nhận đúng số tiền) hoặc 'reject' (không thấy / không khớp).
--   1 dòng: result, booking_id.
--     result = 'ok' | 'forbidden' | 'not_found' | 'invalid' (quyết định sai)
--              'note_required' (từ chối mà không có lý do)
--              'not_payable' (khoản không còn chờ đối chiếu hoặc đơn không còn chờ thanh toán)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_payment_decide;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_payment_decide(
    IN p_payment_id    CHAR(36),
    IN p_decision      VARCHAR(10),
    IN p_actor_user_id CHAR(36),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_reference  VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_note       VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_note), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision IS NULL OR p_decision NOT IN ('confirm', 'reject') THEN
        SELECT 'invalid' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT p.booking_id, p.status, COALESCE(p.reference, p.provider_txn_id)
      INTO v_booking_id, v_pay_status, v_reference
      FROM payments p
     WHERE p.id = (p_payment_id COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vietqr'
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    SELECT b.status INTO v_status FROM bookings b WHERE b.id = v_booking_id FOR UPDATE;

    IF v_pay_status <> 'awaiting_reconciliation' OR v_status <> 'awaiting_payment' THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision = 'reject' AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision = 'confirm' THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), note = v_note
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

        -- Khoản khác còn chờ của đơn không dùng nữa.
        UPDATE payments
           SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
         WHERE booking_id = v_booking_id
           AND id <> (p_payment_id COLLATE utf8mb4_unicode_ci)
           AND status = 'pending';

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'payment_confirm', 'awaiting_payment', 'confirmed',
                LEFT(CONCAT('Đã nhận chuyển khoản VietQR ', v_reference, IF(v_note IS NULL, '', CONCAT(': ', v_note))), 255), NOW());

        CALL LTP_sp_voucher_issue(v_booking_id);
    ELSE
        UPDATE payments
           SET status = 'failed', note = v_note
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'payment_reject', NULL, NULL,
                LEFT(CONCAT('Không khớp chuyển khoản VietQR ', v_reference, ': ', v_note), 255), NOW());
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_booking_id AS booking_id;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.3 - 15_procedures_LTP_payment.sql
-- Mục đích  : Kết quả thanh toán VNPay (Return URL và IPN), tự hủy đơn quá hạn giữ chỗ,
--             cấp voucher sau khi thanh toán được xác minh và lịch sử của đơn.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 4: 4.3.3.2, 4.5.2.1, 4.5.2.2, 4.5.4.1, 4.5.4.2
-- Procedures: LTP_sp_voucher_issue (dùng nội bộ, không trả dòng),
--             LTP_sp_payment_vnpay_result, LTP_sp_booking_expire_holds,
--             LTP_sp_booking_history, LTP_sp_customer_booking_history
-- Quy tắc   : * Ứng dụng kiểm tra chữ ký VNPay (HMAC-SHA512) TRƯỚC khi gọi
--               LTP_sp_payment_vnpay_result; procedure chỉ nhận kết quả đã xác minh.
--             * Idempotent: Return URL và IPN cùng báo một giao dịch -> lần đầu ghi kết quả,
--               các lần sau trả 'already', không đổi gì. Khoản bị hệ thống đóng ('failed' khi
--               đơn quá hạn, chưa có kết quả VNPay: response_code NULL) vẫn nhận kết quả VNPay
--               tới muộn, để khách đã bị trừ tiền được hoàn tiền.
--             * VNPay thành công khi đơn còn 'awaiting_payment' -> đơn 'confirmed', cấp voucher,
--               các khoản khác còn 'pending' của đơn -> 'failed'. Đơn đã hết hạn / đã hủy /
--               đã thanh toán bằng khoản khác -> khoản vẫn ghi 'paid' và tạo yêu cầu hoàn tiền
--               ('requested') để quản trị viên xử lý.
--             * Tự hủy (4.5.4.1): đơn 'awaiting_payment' quá hold_expires_at (24 giờ từ lúc
--               xác nhận chỗ) và KHÔNG có khoản VietQR đang chờ đối chiếu hay khoản đã thanh
--               toán -> 'cancelled', trả lại chỗ, khoản 'pending' -> 'failed'.
--             * Voucher (4.5.4.2): chỉ cấp cho đơn 'confirmed' / 'completed', mỗi đơn một mã
--               LTV + 6 số của mã đơn + 4 số ngẫu nhiên (vd. LTV5182040427), không cấp lại.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 12 (bảng booking_events, cột voucher_code, payments.reference).
--             07 và 14 gọi LTP_sp_voucher_issue: import đủ 01 -> 15 trước khi chạy ứng dụng.
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_voucher_issue(p_booking_id)
--   Dùng nội bộ (CALL từ procedure khác, trong transaction của procedure gọi).
--   Không SELECT gì để không chen result set vào kết quả của procedure gọi.
--   Đơn chưa 'confirmed' / 'completed' hoặc đã có voucher -> không làm gì.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_voucher_issue;

DELIMITER $$
CREATE PROCEDURE LTP_sp_voucher_issue(
    IN p_booking_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    UPDATE bookings
       SET voucher_code = CONCAT('LTV', SUBSTRING(code, 3), LPAD(FLOOR(RAND() * 10000), 4, '0')),
           voucher_issued_at = NOW()
     WHERE id = (p_booking_id COLLATE utf8mb4_unicode_ci)
       AND status IN ('confirmed', 'completed')
       AND voucher_code IS NULL;

    IF ROW_COUNT() > 0 THEN
        INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
        SELECT UUID(), b.id, 'system', NULL, 'voucher_issued', NULL, NULL, CONCAT('Mã voucher ', b.voucher_code), NOW()
          FROM bookings b
         WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci);
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_payment_vnpay_result(p_reference, p_amount_vnd, p_response_code, p_txn_status,
--                             p_txn_no, p_bank_code)
--   p_reference    : vnp_TxnRef (payments.reference).
--   p_amount_vnd   : vnp_Amount / 100 (ứng dụng đã đổi); -1 = sai dạng.
--   p_response_code: vnp_ResponseCode; p_txn_status: vnp_TransactionStatus ('00' = thành công).
--   p_txn_no       : vnp_TransactionNo (mã giao dịch tại VNPay); p_bank_code: vnp_BankCode.
--   1 dòng: result, booking_code, payment_status, booking_status.
--     result = 'ok'             : đã ghi kết quả lần đầu.
--              'already'        : giao dịch này đã có kết quả (Return URL và IPN cùng báo).
--              'not_found'      : không có khoản VNPay với mã này.
--              'invalid_amount' : số tiền VNPay báo khác số tiền của khoản; không đổi gì.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_payment_vnpay_result;

DELIMITER $$
CREATE PROCEDURE LTP_sp_payment_vnpay_result(
    IN p_reference     VARCHAR(32),
    IN p_amount_vnd    BIGINT,
    IN p_response_code VARCHAR(10),
    IN p_txn_status    VARCHAR(10),
    IN p_txn_no        VARCHAR(100),
    IN p_bank_code     VARCHAR(20)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_payment_id CHAR(36)    DEFAULT NULL;
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_amount     BIGINT      DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_code   VARCHAR(10) DEFAULT NULL;
    DECLARE v_code       VARCHAR(20) DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_success    BOOLEAN     DEFAULT FALSE;
    DECLARE v_txn_no     VARCHAR(100) DEFAULT NULLIF(TRIM(p_txn_no), '');
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT p.id, p.booking_id, p.amount_vnd, p.status, p.response_code
      INTO v_payment_id, v_booking_id, v_amount, v_pay_status, v_pay_code
      FROM payments p
     WHERE p.reference = (TRIM(p_reference) COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vnpay'
       FOR UPDATE;

    IF v_payment_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS booking_code, NULL AS payment_status, NULL AS booking_status;
        LEAVE proc;
    END IF;

    -- Khóa đơn (cùng thứ tự khóa với các procedure khác: khoản rồi đơn).
    SELECT b.code, b.status INTO v_code, v_status
      FROM bookings b
     WHERE b.id = v_booking_id
       FOR UPDATE;

    IF NOT (p_amount_vnd <=> v_amount) THEN
        ROLLBACK;
        SELECT 'invalid_amount' AS result, v_code AS booking_code, v_pay_status AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    IF v_pay_status <> 'pending' AND NOT (v_pay_status = 'failed' AND v_pay_code IS NULL) THEN
        ROLLBACK;
        SELECT 'already' AS result, v_code AS booking_code, v_pay_status AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    SET v_success = (p_response_code = '00' AND p_txn_status = '00');

    -- Một sự kiện cho mỗi khoản: khoản đã có kết quả thì không tới được đây lần thứ hai.
    INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at)
    VALUES (UUID(), v_payment_id, CONCAT('VNPAY-', p_reference), COALESCE(NULLIF(p_response_code, ''), '??'), TRUE, NOW());

    IF v_success THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), provider_txn_id = v_txn_no,
               response_code = p_response_code, bank_code = NULLIF(p_bank_code, '')
         WHERE id = v_payment_id;

        IF v_status = 'awaiting_payment' THEN
            UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'vnpay', NULL, 'vnpay_paid', 'awaiting_payment', 'confirmed',
                    CONCAT('Thanh toán VNPay thành công, mã giao dịch ', COALESCE(v_txn_no, p_reference)), NOW());

            -- Các lần thanh toán khác chưa xong của đơn không dùng nữa.
            UPDATE payments
               SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
             WHERE booking_id = v_booking_id
               AND id <> v_payment_id
               AND status = 'pending';

            CALL LTP_sp_voucher_issue(v_booking_id);
            SET v_status = 'confirmed';
        ELSE
            -- Tiền đã trừ ở ngân hàng nhưng đơn không còn chờ thanh toán: tạo yêu cầu hoàn tiền.
            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), v_payment_id, v_amount,
                    CONCAT('Thanh toán VNPay ', p_reference, ' tới khi đơn đang "', v_status, '"; cần hoàn tiền cho khách.'),
                    'requested', NOW());

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'vnpay', NULL, 'refund_requested', NULL, NULL,
                    CONCAT('Khoản VNPay ', p_reference, ' tới sau khi đơn không còn chờ thanh toán; đã tạo yêu cầu hoàn tiền.'), NOW());
        END IF;

        COMMIT;
        SELECT 'ok' AS result, v_code AS booking_code, 'paid' AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    UPDATE payments
       SET status = 'failed', provider_txn_id = NULLIF(v_txn_no, '0'),
           response_code = NULLIF(p_response_code, ''), bank_code = NULLIF(p_bank_code, '')
     WHERE id = v_payment_id;

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'vnpay', NULL, 'vnpay_failed', NULL, NULL,
            CONCAT('Thanh toán VNPay không thành công (mã ', COALESCE(NULLIF(p_response_code, ''), '??'), ')'), NOW());

    COMMIT;
    SELECT 'ok' AS result, v_code AS booking_code, 'failed' AS payment_status, v_status AS booking_status;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_booking_expire_holds()
--   Hủy các đơn 'awaiting_payment' đã quá hạn giữ chỗ (hold_expires_at <= NOW()) mà không
--   có khoản 'awaiting_reconciliation' (VietQR chờ đối chiếu) hay 'paid'. Mỗi đơn một
--   transaction: trả lại chỗ, khoản 'pending' -> 'failed', ghi booking_events (system).
--   Gọi từ ứng dụng mỗi khi mở trang đơn / trang quản trị, và từ scripts/expire_holds.php
--   (Task Scheduler). Chạy nhiều lần cùng lúc vẫn an toàn (khóa dòng, kiểm tra lại).
--   1 dòng: expired (số đơn đã hủy lần này).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_booking_expire_holds;

DELIMITER $$
CREATE PROCEDURE LTP_sp_booking_expire_holds()
MODIFIES SQL DATA
BEGIN
    DECLARE v_booking_id CHAR(36) DEFAULT NULL;
    DECLARE v_schedule   CHAR(36) DEFAULT NULL;
    DECLARE v_people     INT      DEFAULT 0;
    DECLARE v_expired    INT      DEFAULT 0;
    DECLARE v_done       BOOLEAN  DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    WHILE NOT v_done DO
        SET v_booking_id = NULL;
        START TRANSACTION;

        SELECT b.id, b.schedule_id INTO v_booking_id, v_schedule
          FROM bookings b
         WHERE b.status = 'awaiting_payment'
           AND b.hold_expires_at <= NOW()
           AND NOT EXISTS (SELECT 1 FROM payments p
                            WHERE p.booking_id = b.id
                              AND p.status IN ('awaiting_reconciliation', 'paid'))
         ORDER BY b.hold_expires_at, b.id
         LIMIT 1
           FOR UPDATE;

        IF v_booking_id IS NULL THEN
            COMMIT;
            SET v_done = TRUE;
        ELSE
            SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
              FROM booking_lines bl
             WHERE bl.booking_id = v_booking_id;

            -- Trả lại chỗ như khi hủy đơn đang giữ chỗ (07): không vượt capacity, 'full' mở lại.
            UPDATE schedules
               SET remaining = LEAST(capacity, remaining + v_people),
                   status = IF(status = 'full' AND remaining > 0, 'open', status)
             WHERE id = v_schedule;

            UPDATE bookings SET status = 'cancelled', hold_expires_at = NULL WHERE id = v_booking_id;

            UPDATE payments
               SET status = 'failed', note = 'Đơn đã quá hạn thanh toán.'
             WHERE booking_id = v_booking_id
               AND status IN ('pending', 'processing');

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'system', NULL, 'hold_expired', 'awaiting_payment', 'cancelled',
                    'Quá hạn thanh toán 24 giờ: hệ thống tự hủy đơn và trả lại chỗ.', NOW());

            COMMIT;
            SET v_expired = v_expired + 1;
        END IF;
    END WHILE;

    SELECT v_expired AS expired;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_booking_history(p_booking_id)
--   Lịch sử đầy đủ của một đơn cho trang quản trị (NFR-09): booking_events (khách, hệ thống,
--   VNPay) và admin_logs của đơn (quản trị viên), cũ trước.
--   Cột: created_at, actor ('customer' / 'system' / 'vnpay' / 'admin'), actor_name (NULL với
--   hệ thống, VNPay), action, from_status, to_status, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_booking_history;

DELIMITER $$
CREATE PROCEDURE LTP_sp_booking_history(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT h.created_at, h.actor, h.actor_name, h.action, h.from_status, h.to_status, h.note
      FROM (
        SELECT e.created_at, e.actor, u.name AS actor_name, e.action, e.from_status, e.to_status, e.note, e.id
          FROM booking_events e
          LEFT JOIN users u ON u.id = e.actor_user_id
         WHERE e.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
        UNION ALL
        SELECT l.created_at, 'admin', u.name, l.action, l.from_status, l.to_status, l.note, l.id
          FROM admin_logs l
          JOIN users u ON u.id = l.actor_user_id
         WHERE l.target_type = 'booking'
           AND l.target_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
      ) h
     ORDER BY h.created_at,
              -- Các dòng ghi trong cùng một giao dịch: tạo đơn, chốt giá, đổi trạng thái, rồi voucher / hoàn tiền.
              CASE h.action WHEN 'created' THEN 0 WHEN 'booking_total' THEN 1
                            WHEN 'voucher_issued' THEN 3 WHEN 'refund_requested' THEN 3 ELSE 2 END,
              h.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_customer_booking_history(p_user_id, p_code)
--   Lịch sử của đơn cho trang "Đơn của tôi" (FR-11): như LTP_sp_booking_history nhưng chỉ
--   đơn của tài khoản p_user_id và không trả tên quản trị viên (trang hiện "LocalTour").
--   Cột: created_at, actor, action, from_status, to_status, note.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_customer_booking_history;

DELIMITER $$
CREATE PROCEDURE LTP_sp_customer_booking_history(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT h.created_at, h.actor, h.action, h.from_status, h.to_status, h.note
      FROM (
        SELECT e.created_at, e.actor, e.action, e.from_status, e.to_status, e.note, e.id
          FROM booking_events e
          JOIN bookings b ON b.id = e.booking_id
         WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
        UNION ALL
        SELECT l.created_at, 'admin', l.action, l.from_status, l.to_status, l.note, l.id
          FROM admin_logs l
          JOIN bookings b ON b.id = l.target_id
         WHERE l.target_type = 'booking'
           AND b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
      ) h
     ORDER BY h.created_at,
              -- Các dòng ghi trong cùng một giao dịch: tạo đơn, chốt giá, đổi trạng thái, rồi voucher / hoàn tiền.
              CASE h.action WHEN 'created' THEN 0 WHEN 'booking_total' THEN 1
                            WHEN 'voucher_issued' THEN 3 WHEN 'refund_requested' THEN 3 ELSE 2 END,
              h.id;
END$$
DELIMITER ;
