-- File sinh tự động từ src/database/01..25, không sửa tay.
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

-- Bảng do các file sau thêm (12: Sprint 4, 16: Sprint 5, 23 - 25): xóa luôn để chạy lại từ đầu không còn dữ liệu thử cũ.
DROP TABLE IF EXISTS email_logs;
DROP TABLE IF EXISTS user_social_accounts;
DROP TABLE IF EXISTS map_place_cache;
DROP TABLE IF EXISTS booking_change_requests;
DROP TABLE IF EXISTS tour_packages;
DROP TABLE IF EXISTS booking_events;
DROP TABLE IF EXISTS booking_extras;

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

-- NGƯỜI_DÙNG (FR-13, NFR-04): tài khoản quản trị viên, khách hàng và đơn vị tổ chức.
-- role: admin = Quản trị viên, customer = tài khoản khách hàng,
--       provider = dòng tài khoản của đơn vị tổ chức (providers.user_id): không có mật
--       khẩu, không đăng nhập được; theo CR1 đơn vị tổ chức chỉ là dữ liệu do quản trị viên
--       quản lý. CR1 bỏ tác nhân Nhân viên hỗ trợ khách hàng nên không còn role support.
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
    role          ENUM('admin','provider','customer') NOT NULL,
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
--         Luồng VietQR kết thúc ở 'awaiting_reconciliation' (chờ quản trị viên đối chiếu)
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
--   users        : 1 = quản trị viên;
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
-- Số dòng: users 48, providers 7, destinations 5, categories 6, tours 12,
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
--   Tài khoản quản trị viên, nhà cung cấp và khách hàng. Mọi tài khoản mẫu có password_hash
--   NULL nên không đăng nhập được; người kiểm thử tự đăng ký tài khoản ở /register.
-- ---------------------------------------------------------------------
INSERT INTO users (id, email, password_hash, name, phone, role, status) VALUES
-- Quản trị viên
('a0000000-0000-4000-8000-000000000001', 'admin@localtour.test', NULL, 'Quản trị viên LocalTour', NULL, 'admin', 'active'),
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
-- Chạy sau  : 01_schema.sql, 16_migration_sprint5_LTP.sql (bảng tour_packages).
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
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
--     Sprint 5 (US06-S5-01): tour có gói đang bán (tour_packages) thì "Từ" = giá người lớn
--     thấp nhất của các gói, vì khách đặt theo giá gói.
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
                      MIN(CASE WHEN tt.name = 'adult' THEN COALESCE(pk.adult_from, tt.price_vnd) END) AS from_price_vnd
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                 -- Tour có gói đang bán: giá người lớn thấp nhất của các gói
                 LEFT JOIN (SELECT tp.tour_id, MIN(tp.adult_price_vnd) AS adult_from
                              FROM tour_packages tp
                             WHERE tp.active = TRUE
                             GROUP BY tp.tour_id) pk
                        ON pk.tour_id = s.tour_id
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
--                      'approved' | 'rejected' | 'archived' (ngừng hiển thị, Sprint 5).
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
--             NMT_sp_admin_revenue_stats, NMT_sp_admin_revenue_payment_list
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
--   tour_rejected (FR-20), tour_archived (ngừng hiển thị, Sprint 5),
--   tour_public (đang hiển thị cho khách), booking_total,
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
        tr.tour_archived,
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
                 COALESCE(SUM(t.approval_status = 'archived'), 0) AS tour_archived,
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

-- ---------------------------------------------------------------------
-- NMT_sp_admin_revenue_payment_list(p_from, p_to)
--   Các khoản thanh toán của một kỳ doanh thu (FR-23, "đối chiếu giao dịch nguồn"):
--   cùng điều kiện với NMT_sp_admin_revenue_stats (khoản 'paid', theo ngày thanh toán,
--   tiền hoàn 'completed' trừ vào khoản gốc), nên tổng của danh sách = dòng của kỳ đó.
--   p_from / p_to: ngày (bao gồm cả hai đầu), NULL = không giới hạn. Tối đa 1000 dòng,
--   thanh toán trước lên trước.
--   Cột: payment_id, paid_at, method, reference, provider_txn_id, amount_vnd, refund_vnd,
--   net_vnd, booking_id, code, tour_title.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_revenue_payment_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_revenue_payment_list(
    IN p_from DATE,
    IN p_to   DATE
)
READS SQL DATA
BEGIN
    SELECT
        p.id              AS payment_id,
        p.paid_at,
        p.method,
        COALESCE(p.reference, p.provider_txn_id) AS reference,
        p.provider_txn_id,
        p.amount_vnd,
        COALESCE(r.refund_vnd, 0)                AS refund_vnd,
        p.amount_vnd - COALESCE(r.refund_vnd, 0) AS net_vnd,
        b.id              AS booking_id,
        b.code,
        t.title           AS tour_title
    FROM payments p
    JOIN bookings b  ON b.id = p.booking_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    LEFT JOIN (SELECT payment_id, SUM(amount_vnd) AS refund_vnd
                 FROM refunds
                WHERE status = 'completed'
                GROUP BY payment_id) r
           ON r.payment_id = p.id
    WHERE p.status = 'paid'
      AND p.paid_at IS NOT NULL
      AND (p_from IS NULL OR p.paid_at >= p_from)
      AND (p_to IS NULL OR p.paid_at < p_to + INTERVAL 1 DAY)
    ORDER BY p.paid_at, p.id
    LIMIT 1000;
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
--             NTK_sp_admin_log_list, NTK_sp_admin_booking_set_status,
--             NTK_sp_admin_vnpay_queue, NTK_sp_admin_vnpay_decide
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
-- Chạy sau  : 01_schema.sql (Sprint 5: cột bookings.package_name ở 16_migration_sprint5_LTP.sql).
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
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
--   Sprint 5: package_name (gói khách chọn, NULL = tour không có gói).
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
        b.package_name,
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

-- ---------------------------------------------------------------------
-- NTK_sp_admin_vnpay_queue(p_booking_id)
--   Giao dịch VNPay chưa rõ kết quả (ISS-03, Sprint 4): khoản VNPay tạo từ trang thanh toán
--   (có reference = vnp_TxnRef) mà VNPay chưa trả kết quả nào (không có payment_events,
--   response_code NULL), vì Return URL và IPN đều không về (khách đóng trình duyệt, chạy ở
--   localhost...). Gồm:
--     * khoản 'pending' đã quá 15 phút (hết hạn link thanh toán VNPay, VnpayGateway), và
--     * khoản bị hệ thống đóng 'failed' (đơn quá hạn / bị hủy) khi đơn không được thanh toán
--       bằng khoản khác.
--   Quản trị viên tra mã thanh toán trên cổng VNPay rồi ghi kết quả (NTK_sp_admin_vnpay_decide).
--   p_booking_id: NULL = mọi đơn (tối đa 200 dòng, tạo trước lên trước); ngược lại một đơn.
--   Cột: payment_id, reference, amount_vnd, status, created_at, booking_id, code,
--   booking_status, hold_expires_at, contact_name, contact_phone, tour_title, starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_vnpay_queue;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_vnpay_queue(
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.reference,
        p.amount_vnd,
        p.status,
        p.created_at,
        b.id            AS booking_id,
        b.code,
        b.status        AS booking_status,
        b.hold_expires_at,
        b.contact_name,
        b.contact_phone,
        t.title         AS tour_title,
        s.starts_at
    FROM payments p
    JOIN bookings b  ON b.id = p.booking_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE p.method = 'vnpay'
      AND p.reference IS NOT NULL
      AND p.response_code IS NULL
      AND NOT EXISTS (SELECT 1 FROM payment_events e WHERE e.payment_id = p.id)
      AND ((p.status = 'pending' AND p.created_at <= NOW() - INTERVAL 15 MINUTE)
           OR (p.status = 'failed' AND b.status NOT IN ('confirmed', 'completed')))
      AND (p_booking_id IS NULL OR b.id = (p_booking_id COLLATE utf8mb4_unicode_ci))
    ORDER BY p.created_at, p.id
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_vnpay_decide(p_payment_id, p_decision, p_actor_user_id, p_txn_no, p_note)
--   Quản trị viên ghi kết quả đã tra trên cổng VNPay cho một khoản của NTK_sp_admin_vnpay_queue.
--   p_decision = 'confirm': VNPay có giao dịch thành công, bắt buộc p_txn_no (mã giao dịch tại
--                VNPay). Khoản -> 'paid'. Đơn còn 'awaiting_payment' -> 'confirmed', cấp voucher,
--                khoản 'pending' khác -> 'failed' (như VNPay báo thành công). Đơn đã hủy -> khoản
--                vẫn 'paid' và tạo yêu cầu hoàn tiền ('requested'), như tiền VNPay tới muộn.
--              'reject' : VNPay không có giao dịch thành công, bắt buộc lý do. Khoản -> 'failed';
--                đơn không đổi (đơn còn hạn thì khách thanh toán lại được).
--   Mỗi quyết định ghi một payment_events 'ADMIN-<reference>' (khoản rời hàng đợi) và
--   admin_logs của đơn. VNPay báo kết quả muộn sau 'reject' vẫn được ghi (file 15).
--   1 dòng: result, booking_id.
--     result = 'ok' | 'forbidden' | 'not_found' | 'invalid' (quyết định sai)
--              'txn_required' (đã nhận tiền mà không có mã giao dịch VNPay)
--              'note_required' (không có giao dịch mà không có lý do)
--              'not_payable' (khoản không còn trong hàng đợi chưa rõ kết quả)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_vnpay_decide;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_vnpay_decide(
    IN p_payment_id    CHAR(36),
    IN p_decision      VARCHAR(10),
    IN p_actor_user_id CHAR(36),
    IN p_txn_no        VARCHAR(100),
    IN p_note          VARCHAR(255) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_code   VARCHAR(10) DEFAULT NULL;
    DECLARE v_created    DATETIME    DEFAULT NULL;
    DECLARE v_amount     BIGINT      DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE v_txn_no     VARCHAR(100) DEFAULT NULLIF(TRIM(p_txn_no), '');
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

    SELECT p.booking_id, p.status, p.response_code, p.created_at, p.amount_vnd, p.reference
      INTO v_booking_id, v_pay_status, v_pay_code, v_created, v_amount, v_reference
      FROM payments p
     WHERE p.id = (p_payment_id COLLATE utf8mb4_unicode_ci)
       AND p.method = 'vnpay'
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS booking_id;
        LEAVE proc;
    END IF;

    -- Khóa đơn (cùng thứ tự khóa với các procedure khác: khoản rồi đơn).
    SELECT b.status INTO v_status FROM bookings b WHERE b.id = v_booking_id FOR UPDATE;

    -- Kiểm tra lại điều kiện của hàng đợi trong transaction (VNPay có thể vừa trả kết quả).
    IF v_reference IS NULL OR v_pay_code IS NOT NULL
       OR EXISTS (SELECT 1 FROM payment_events e WHERE e.payment_id = (p_payment_id COLLATE utf8mb4_unicode_ci))
       OR NOT ((v_pay_status = 'pending' AND v_created <= NOW() - INTERVAL 15 MINUTE)
               OR (v_pay_status = 'failed' AND v_status NOT IN ('confirmed', 'completed'))) THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision = 'confirm' AND v_txn_no IS NULL THEN
        ROLLBACK;
        SELECT 'txn_required' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    IF p_decision = 'reject' AND v_note IS NULL THEN
        ROLLBACK;
        SELECT 'note_required' AS result, v_booking_id AS booking_id;
        LEAVE proc;
    END IF;

    INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at)
    VALUES (UUID(), p_payment_id, CONCAT('ADMIN-', v_reference),
            IF(p_decision = 'confirm', 'ADMIN_PAID', 'ADMIN_NONE'), TRUE, NOW());

    IF p_decision = 'confirm' THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), provider_txn_id = v_txn_no,
               note = LEFT(CONCAT('Đối chiếu trên cổng VNPay', IF(v_note IS NULL, '.', CONCAT(': ', v_note))), 255)
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        IF v_status = 'awaiting_payment' THEN
            UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

            UPDATE payments
               SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
             WHERE booking_id = v_booking_id
               AND id <> (p_payment_id COLLATE utf8mb4_unicode_ci)
               AND status = 'pending';

            INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'vnpay_reconcile_paid', 'awaiting_payment', 'confirmed',
                    LEFT(CONCAT('Đã thấy giao dịch VNPay ', v_reference, ' thành công (mã GD ', v_txn_no, ')',
                                IF(v_note IS NULL, '', CONCAT(': ', v_note))), 255), NOW());

            CALL LTP_sp_voucher_issue(v_booking_id);
        ELSE
            -- Tiền đã trừ nhưng đơn không còn chờ thanh toán: tạo yêu cầu hoàn tiền (như file 15).
            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), p_payment_id, v_amount,
                    CONCAT('Thanh toán VNPay ', v_reference, ' đối chiếu khi đơn đang "', v_status, '"; cần hoàn tiền cho khách.'),
                    'requested', NOW());

            INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'vnpay_reconcile_paid', NULL, NULL,
                    LEFT(CONCAT('Đã thấy giao dịch VNPay ', v_reference, ' thành công (mã GD ', v_txn_no,
                                ') khi đơn không còn chờ thanh toán; đã tạo yêu cầu hoàn tiền.'), 255), NOW());
        END IF;
    ELSE
        UPDATE payments
           SET status = 'failed', note = v_note
         WHERE id = (p_payment_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'vnpay_reconcile_none', NULL, NULL,
                LEFT(CONCAT('Không có giao dịch VNPay ', v_reference, ': ', v_note), 255), NOW());
    END IF;

    COMMIT;
    SELECT 'ok' AS result, v_booking_id AS booking_id;
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
-- Phụ trách : Lê Trung Phong (LTP) - M4 mục 6; Sprint 4: 4.3.3.1, 4.3.3.2; Sprint 5: US06-S5-01
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
--             * Gói tour (Sprint 5, US06-S5-01, FR-07): tour có gói đang bán thì phải chọn
--               đúng một gói của tour; giá vé lấy theo gói (người lớn / trẻ em), vé trẻ em chỉ
--               bán khi gói có giá trẻ em. Tour không có gói đang bán thì không gửi gói, giá
--               theo lịch như trước. Mã và tên gói chụp lại vào bookings (file 16).
--             * Không gọi cổng thanh toán, không thu tiền ở bước này: khách thanh toán sau khi
--               quản trị viên xác nhận chỗ và giá (14_procedures_NMT_payment.sql).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8: đọc JSON bằng JSON_EXTRACT theo chỉ số
--             (MariaDB 10.4 chưa có JSON_TABLE).
-- Chạy sau  : 01_schema.sql, 08_migration_booking_NMT.sql, 12_migration_sprint4_NMT.sql,
--             16_migration_sprint5_LTP.sql.
--             Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_booking_create(p_user_id, p_schedule_id, p_request_token, p_contact_name,
--                       p_contact_email, p_contact_phone, p_passengers, p_special_request,
--                       p_expected_total, p_extras, p_package_id)
--   p_passengers    : mảng JSON, mỗi khách một phần tử, theo thứ tự trên form:
--                     [{"ticket_type_id": "<uuid>", "full_name": "Nguyễn Văn A"}, ...]
--   p_special_request: NULL / '' = không có.
--   p_expected_total: tổng tiền (VND) khách thấy trên trang trước khi bấm gửi (vé + phụ thu /
--                     tùy chọn đã chọn).
--   p_extras        : mảng JSON mã các khoản phụ thu / tùy chọn khách chọn, vd. ["<uuid>", ...];
--                     NULL / '[]' = không chọn.
--   p_package_id    : gói khách chọn (NULL / '' = không chọn, chỉ hợp lệ khi tour không có gói
--                     đang bán).
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
--              'package_changed'      : gói đã chọn không còn bán, tour vừa có / hết gói, hoặc
--                                       gói không bán loại vé đã chọn (vé trẻ em).
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
    IN p_extras          TEXT,
    IN p_package_id      CHAR(36)
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
    DECLARE v_package_id  CHAR(36)     DEFAULT NULLIF(TRIM(p_package_id), '');
    DECLARE v_package     VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_pkg_adult   BIGINT       DEFAULT NULL;
    DECLARE v_pkg_child   BIGINT       DEFAULT NULL;
    DECLARE v_pkg_count   INT          DEFAULT 0;
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

    -- 4b. Gói: tour có gói đang bán thì phải chọn một gói đang bán của tour; không có thì
    --     không được gửi gói.
    SELECT COUNT(*) INTO v_pkg_count
      FROM tour_packages tp
     WHERE tp.tour_id = (v_tour_id COLLATE utf8mb4_unicode_ci)
       AND tp.active = TRUE;

    IF v_package_id IS NOT NULL THEN
        SELECT tp.name, tp.adult_price_vnd, tp.child_price_vnd
          INTO v_package, v_pkg_adult, v_pkg_child
          FROM tour_packages tp
         WHERE tp.id = (v_package_id COLLATE utf8mb4_unicode_ci)
           AND tp.tour_id = (v_tour_id COLLATE utf8mb4_unicode_ci)
           AND tp.active = TRUE
           LOCK IN SHARE MODE;
    END IF;

    IF (v_pkg_count > 0 AND v_package IS NULL) OR (v_pkg_count = 0 AND v_package_id IS NOT NULL) THEN
        ROLLBACK;
        SELECT 'package_changed' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
        LEAVE proc;
    END IF;

    -- 5. Giá hiện tại của từng khách theo loại vé (vé phải còn bán cho đúng lịch này); có gói
    --    thì giá theo gói.
    SET v_i = 0;
    WHILE v_i < v_count DO
        SET v_ticket_id = JSON_UNQUOTE(JSON_EXTRACT(p_passengers, CONCAT('$[', v_i, '].ticket_type_id')));
        SET v_price = NULL;
        SET v_ticket_name = NULL;
        SELECT tt.price_vnd, tt.name INTO v_price, v_ticket_name
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
        IF v_package IS NOT NULL THEN
            SET v_price = IF(LOWER(v_ticket_name) = 'child', v_pkg_child, v_pkg_adult);
            IF v_price IS NULL THEN
                ROLLBACK;
                SELECT 'package_changed' AS result, NULL AS booking_code, NULL AS total_vnd, v_remaining AS remaining, v_max_group AS max_group_size;
                LEAVE proc;
            END IF;
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
    INSERT INTO bookings (id, user_id, schedule_id, package_id, package_name, code, request_token, contact_name,
                          contact_email, contact_phone, status, total_vnd, policy_version, hold_expires_at, created_at)
    VALUES (v_booking_id, p_user_id, p_schedule_id, IF(v_package IS NULL, NULL, v_package_id), v_package, v_code,
            v_token, v_name, v_email, v_phone, 'pending', v_total, v_policy, NULL, NOW());

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
        IF v_package IS NOT NULL THEN
            SET v_price = IF(LOWER(v_ticket_name) = 'child', v_pkg_child, v_pkg_adult);
        END IF;

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
            LEFT(CONCAT(v_count, ' khách', IF(v_package IS NULL, '', CONCAT(', gói ', v_package)),
                        ', tổng ', REPLACE(FORMAT(v_total, 0), ',', '.'), ' VND'), 255), NOW());

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
-- Chạy sau  : 01_schema.sql, 08_migration_booking_NMT.sql, 12_migration_sprint4_NMT.sql,
--             16_migration_sprint5_LTP.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
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
--   Sprint 5: package_name (gói đã chọn khi đặt, NULL = tour không có gói).
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
        b.package_name,
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
-- =====================================================================
-- LocalTour v0.4 - 17_procedures_NMT_compare.sql
-- Mục đích  : Dữ liệu so sánh 2 - 3 tour (US04-S5-02, FR-15): một dòng cho mỗi tour đang hiển
--             thị, cùng đơn vị để đặt cạnh nhau (giá theo người lớn / người, thời lượng theo
--             phút, quy mô nhóm theo khách, chính sách hủy theo giờ và phần trăm).
--             Ô thiếu dữ liệu trả NULL; trang so sánh hiện "Chưa cập nhật" (CompareModel).
-- Phụ trách : Nguyễn Minh Thức (NMT) - Sprint 5
-- Procedures: NMT_sp_tour_compare
-- Chạy sau  : 16_migration_sprint5_LTP.sql (bảng tour_packages). Chạy lại được.
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_tour_compare(p_tour_ids)
--   p_tour_ids: mã tour cách nhau bởi dấu phẩy, không khoảng trắng, theo thứ tự khách chọn,
--               vd. 'c000...0001,c000...0005'. Tối đa 3 tour (ứng dụng chặn trước); tour không
--               có hoặc đang ẩn bị bỏ qua.
--   Mỗi tour một dòng, theo thứ tự trong p_tour_ids. Cột:
--     tour_id, title, provider_name, destination_name, category_name, cover_image_url,
--     cover_alt_text, duration_minutes, max_group_size, language_codes, pickup_mode,
--     meeting_point, dropoff_point, transport, guide_info, meal_terms, reschedule_terms,
--     from_price_vnd (giá người lớn thấp nhất / người: gói đang bán thấp nhất nếu tour có gói,
--                     ngược lại vé 'adult' active thấp nhất của các lịch đặt được),
--     child_from_price_vnd (giá trẻ em thấp nhất / người, cùng cách tính; NULL = không bán),
--     package_count, package_names (tên các gói, ngăn bởi ' · '),
--     next_starts_at, schedule_count (số lịch đặt được),
--     policy_version, free_before_hours, refund_percent (chính sách hủy mới nhất),
--     rating_avg, review_count,
--     included_items, excluded_items (ngăn bởi xuống dòng, theo sort_order),
--     itinerary_items ("HH:MM mô tả" hoặc "mô tả", ngăn bởi xuống dòng),
--     extras_items ("Tên: giá đ / đơn vị" hoặc "Tên: giá cập nhật sau", ngăn bởi xuống dòng).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_tour_compare;

DELIMITER $$
CREATE PROCEDURE NMT_sp_tour_compare(
    IN p_tour_ids VARCHAR(200)
)
READS SQL DATA
BEGIN
    DECLARE v_ids VARCHAR(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT REPLACE(COALESCE(p_tour_ids, ''), ' ', '');

    -- Danh sách bao gồm / lịch trình có thể dài hơn giới hạn mặc định 1024 ký tự.
    SET SESSION group_concat_max_len = 16384;

    SELECT
        t.id                AS tour_id,
        t.title,
        p.business_name     AS provider_name,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        ci.url              AS cover_image_url,
        ci.alt_text         AS cover_alt_text,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.dropoff_point,
        t.transport,
        t.guide_info,
        t.meal_terms,
        t.reschedule_terms,
        IF(bs.tour_id IS NULL, NULL, COALESCE(pk.adult_from, bs.adult_from)) AS from_price_vnd,
        IF(bs.tour_id IS NULL, NULL,
           IF(pk.tour_id IS NULL, bs.child_from, IF(bs.has_child, pk.child_from, NULL))) AS child_from_price_vnd,
        COALESCE(pk.package_count, 0) AS package_count,
        pk.package_names,
        bs.next_starts_at,
        COALESCE(bs.schedule_count, 0) AS schedule_count,
        cp.version          AS policy_version,
        cp.free_before_hours,
        cp.refund_percent,
        rs.rating_avg,
        COALESCE(rs.review_count, 0) AS review_count,
        (SELECT GROUP_CONCAT(i.item_text ORDER BY i.sort_order, i.id SEPARATOR '\n')
           FROM tour_inclusions i WHERE i.tour_id = t.id AND i.is_included = TRUE) AS included_items,
        (SELECT GROUP_CONCAT(i.item_text ORDER BY i.sort_order, i.id SEPARATOR '\n')
           FROM tour_inclusions i WHERE i.tour_id = t.id AND i.is_included = FALSE) AS excluded_items,
        (SELECT GROUP_CONCAT(CONCAT(IF(it.start_time IS NULL, '', CONCAT(TIME_FORMAT(it.start_time, '%H:%i'), ' ')),
                                    it.description)
                             ORDER BY it.sort_order, it.start_time, it.id SEPARATOR '\n')
           FROM tour_itinerary_items it WHERE it.tour_id = t.id) AS itinerary_items,
        (SELECT GROUP_CONCAT(CONCAT(te.name, ': ',
                                    IF(te.price_vnd IS NULL, 'giá cập nhật sau',
                                       CONCAT(REPLACE(FORMAT(te.price_vnd, 0), ',', '.'), 'đ',
                                              IF(NULLIF(TRIM(te.price_unit), '') IS NULL, ' / nhóm',
                                                 CONCAT(' / ', TRIM(te.price_unit))))))
                             ORDER BY te.kind, te.sort_order, te.id SEPARATOR '\n')
           FROM tour_extras te WHERE te.tour_id = t.id) AS extras_items
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    -- Lịch đặt được: giá vé thấp nhất theo loại, lịch gần nhất, số lịch
    LEFT JOIN (SELECT s.tour_id,
                      MIN(s.starts_at) AS next_starts_at,
                      COUNT(DISTINCT s.id) AS schedule_count,
                      MIN(CASE WHEN tt.name = 'adult' THEN tt.price_vnd END) AS adult_from,
                      MIN(CASE WHEN tt.name = 'child' THEN tt.price_vnd END) AS child_from,
                      MAX(tt.name = 'child') AS has_child
                 FROM schedules s
                 JOIN ticket_types tt ON tt.schedule_id = s.id AND tt.active = TRUE
                WHERE FIND_IN_SET(s.tour_id, v_ids) > 0
                  AND s.status = 'open'
                  AND s.starts_at > NOW()
                  AND s.remaining > 0
                GROUP BY s.tour_id) bs
           ON bs.tour_id = t.id
    -- Gói đang bán
    LEFT JOIN (SELECT tp.tour_id,
                      COUNT(*) AS package_count,
                      MIN(tp.adult_price_vnd) AS adult_from,
                      MIN(tp.child_price_vnd) AS child_from,
                      GROUP_CONCAT(tp.name ORDER BY tp.sort_order, tp.adult_price_vnd, tp.name SEPARATOR ' · ') AS package_names
                 FROM tour_packages tp
                WHERE tp.active = TRUE
                  AND FIND_IN_SET(tp.tour_id, v_ids) > 0
                GROUP BY tp.tour_id) pk
           ON pk.tour_id = t.id
    -- Chính sách hủy mới nhất
    LEFT JOIN cancellation_policies cp
           ON cp.tour_id = t.id
          AND cp.version = (SELECT MAX(cp2.version) FROM cancellation_policies cp2 WHERE cp2.tour_id = t.id)
    -- Đánh giá đã duyệt
    LEFT JOIN (SELECT r.tour_id,
                      CAST(ROUND(AVG(r.rating), 1) AS DECIMAL(2,1)) AS rating_avg,
                      COUNT(*) AS review_count
                 FROM reviews r
                WHERE r.moderation_status = 'approved'
                  AND FIND_IN_SET(r.tour_id, v_ids) > 0
                GROUP BY r.tour_id) rs
           ON rs.tour_id = t.id
    -- Ảnh bìa: ảnh có sort_order nhỏ nhất
    LEFT JOIN tour_images ci
           ON ci.id = (SELECT ti.id FROM tour_images ti
                        WHERE ti.tour_id = t.id
                        ORDER BY ti.sort_order, ti.id LIMIT 1)
    WHERE FIND_IN_SET(t.id, v_ids) > 0
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY FIND_IN_SET(t.id, v_ids)
    LIMIT 3;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.4 - 18_procedures_LTP_package.sql
-- Mục đích  : Gói của tour (US06-S5-01, FR-07): khách xem và chọn gói khi đặt tour, quản trị
--             viên thêm / sửa / ngừng bán gói.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 5
-- Procedures: LTP_sp_tour_package_list, LTP_sp_admin_package_list, LTP_sp_admin_package_save
-- Quy tắc   : * Gói phân theo phương tiện hoặc tuyến điểm; lịch khởi hành, lịch trình chính và
--               phụ thu dùng chung với tour. Giá vé của gói áp dụng cho mọi lịch của tour.
--             * Tour có ít nhất một gói đang bán thì khách phải chọn gói khi đặt; giá vé lấy
--               theo gói (vé trẻ em chỉ bán khi gói có giá trẻ em và lịch có vé trẻ em).
--               Tour không có gói đang bán: giá vé theo lịch như trước.
--             * Gói không xóa được (đơn cũ giữ mã gói); ngừng bán = active FALSE.
--             * Đổi giá gói không đổi giá các đơn đã đặt (giá chụp lại ở booking_lines).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 16_migration_sprint5_LTP.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_tour_package_list(p_tour_id)
--   Các gói đang bán của một tour đang hiển thị (cùng điều kiện với trang chi tiết tour).
--   Cột: package_id, name, description, adult_price_vnd, child_price_vnd (NULL = không bán
--        vé trẻ em). Sắp xếp sort_order, giá người lớn, tên.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_tour_package_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_tour_package_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tp.id               AS package_id,
        tp.name,
        tp.description,
        tp.adult_price_vnd,
        tp.child_price_vnd
    FROM tour_packages tp
    JOIN tours     t ON t.id = tp.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND tp.active = TRUE
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY tp.sort_order, tp.adult_price_vnd, tp.name, tp.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_package_list(p_tour_id)
--   Mọi gói của tour (cả gói ngừng bán) cho trang quản trị.
--   Cột: package_id, name, description, adult_price_vnd, child_price_vnd, active,
--        sort_order, created_at, updated_at, booking_count (mọi đơn đã chọn gói),
--        active_booking_count (đơn pending / awaiting_payment / confirmed).
--   Sắp xếp: gói đang bán trước, rồi sort_order, tên.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_package_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_package_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        tp.id               AS package_id,
        tp.name,
        tp.description,
        tp.adult_price_vnd,
        tp.child_price_vnd,
        tp.active,
        tp.sort_order,
        tp.created_at,
        tp.updated_at,
        (SELECT COUNT(*) FROM bookings b WHERE b.package_id = tp.id) AS booking_count,
        (SELECT COUNT(*) FROM bookings b
          WHERE b.package_id = tp.id
            AND b.status IN ('pending', 'awaiting_payment', 'confirmed')) AS active_booking_count
    FROM tour_packages tp
    WHERE tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY tp.active DESC, tp.sort_order, tp.name, tp.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_package_save(p_actor_user_id, p_tour_id, p_package_id, p_name,
--                           p_description, p_adult_price_vnd, p_child_price_vnd,
--                           p_active, p_sort_order)
--   p_package_id NULL / '' = thêm gói mới; ngược lại sửa gói đó (phải thuộc p_tour_id).
--   Giới hạn: tên 1 - 100 ký tự, không trùng tên gói khác của tour; mô tả tối đa 500 ký
--   tự (NULL / '' = không có); giá người lớn 1 - 100.000.000 đ; giá trẻ em NULL hoặc
--   1 - 100.000.000 đ; thứ tự 0 - 999.
--   Ghi admin_logs (target_type 'tour', target_id = mã tour, action 'package_create' /
--   'package_update', note = tên gói và nội dung thay đổi).
--   1 dòng: result, field, package_id.
--     result = 'ok'          : đã lưu.
--              'unchanged'   : sửa nhưng không có gì thay đổi.
--              'forbidden'   : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'   : không có tour, hoặc gói không thuộc tour này.
--              'invalid'     : dữ liệu sai; field = name, description, adult_price,
--                              child_price hoặc sort_order.
--              'duplicate'   : tour đã có gói khác cùng tên (field = name).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_package_save;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_package_save(
    IN p_actor_user_id   CHAR(36),
    IN p_tour_id         CHAR(36),
    IN p_package_id      CHAR(36),
    IN p_name            VARCHAR(255) CHARACTER SET utf8mb4,
    IN p_description     TEXT         CHARACTER SET utf8mb4,
    IN p_adult_price_vnd BIGINT,
    IN p_child_price_vnd BIGINT,
    IN p_active          BOOLEAN,
    IN p_sort_order      INT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_package_id  CHAR(36)     DEFAULT NULLIF(TRIM(p_package_id), '');
    DECLARE v_name        VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_name, ''));
    DECLARE v_description TEXT         CHARACTER SET utf8mb4;
    DECLARE v_field       VARCHAR(30)  DEFAULT NULL;
    DECLARE v_found       INT          DEFAULT 0;
    DECLARE v_old_name    VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_desc    VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_adult   BIGINT       DEFAULT NULL;
    DECLARE v_old_child   BIGINT       DEFAULT NULL;
    DECLARE v_old_active  BOOLEAN      DEFAULT NULL;
    DECLARE v_old_sort    INT          DEFAULT NULL;
    DECLARE v_changes     VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_description = NULLIF(TRIM(p_description), '');

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS package_id;
        LEAVE proc;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)) THEN
        SELECT 'not_found' AS result, NULL AS field, NULL AS package_id;
        LEAVE proc;
    END IF;

    IF v_name = '' OR CHAR_LENGTH(v_name) > 100 THEN
        SET v_field = 'name';
    ELSEIF v_description IS NOT NULL AND CHAR_LENGTH(v_description) > 500 THEN
        SET v_field = 'description';
    ELSEIF p_adult_price_vnd IS NULL OR p_adult_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'adult_price';
    ELSEIF p_child_price_vnd IS NOT NULL AND p_child_price_vnd NOT BETWEEN 1 AND 100000000 THEN
        SET v_field = 'child_price';
    ELSEIF p_sort_order IS NULL OR p_sort_order NOT BETWEEN 0 AND 999 THEN
        SET v_field = 'sort_order';
    END IF;

    IF v_field IS NOT NULL THEN
        SELECT 'invalid' AS result, v_field AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF v_package_id IS NOT NULL THEN
        SELECT COUNT(*), MAX(tp.name), MAX(tp.description), MAX(tp.adult_price_vnd), MAX(tp.child_price_vnd),
               MAX(tp.active), MAX(tp.sort_order)
          INTO v_found, v_old_name, v_old_desc, v_old_adult, v_old_child, v_old_active, v_old_sort
          FROM tour_packages tp
         WHERE tp.id = (v_package_id COLLATE utf8mb4_unicode_ci)
           AND tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
           FOR UPDATE;
        IF v_found = 0 THEN
            ROLLBACK;
            SELECT 'not_found' AS result, NULL AS field, v_package_id AS package_id;
            LEAVE proc;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM tour_packages tp
                WHERE tp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                  AND tp.name = (v_name COLLATE utf8mb4_unicode_ci)
                  AND NOT (tp.id <=> (v_package_id COLLATE utf8mb4_unicode_ci))) THEN
        ROLLBACK;
        SELECT 'duplicate' AS result, 'name' AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    IF v_package_id IS NULL THEN
        SET v_package_id = UUID();
        INSERT INTO tour_packages (id, tour_id, name, description, adult_price_vnd, child_price_vnd,
                                   active, sort_order, created_at)
        VALUES (v_package_id, p_tour_id, v_name, v_description, p_adult_price_vnd, p_child_price_vnd,
                COALESCE(p_active, TRUE), p_sort_order, NOW());

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'package_create', NULL,
                IF(COALESCE(p_active, TRUE), 'active', 'inactive'),
                LEFT(CONCAT('Thêm gói "', v_name, '", người lớn ',
                            REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ',
                            IF(p_child_price_vnd IS NULL, '',
                               CONCAT(', trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ'))), 255),
                NOW());

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    SET v_changes = CONCAT_WS(', ',
        IF(BINARY v_old_name <> BINARY v_name,
           CONCAT('tên "', v_old_name, '" → "', v_name, '"'), NULL),
        IF(NOT (v_old_desc <=> v_description), 'mô tả', NULL),
        IF(v_old_adult <> p_adult_price_vnd,
           CONCAT('người lớn ', REPLACE(FORMAT(p_adult_price_vnd, 0), ',', '.'), 'đ'), NULL),
        IF(NOT (v_old_child <=> p_child_price_vnd),
           IF(p_child_price_vnd IS NULL, 'ngừng bán vé trẻ em',
              CONCAT('trẻ em ', REPLACE(FORMAT(p_child_price_vnd, 0), ',', '.'), 'đ')), NULL),
        IF(v_old_sort <> p_sort_order, CONCAT('thứ tự ', p_sort_order), NULL),
        IF(v_old_active <> COALESCE(p_active, TRUE),
           IF(COALESCE(p_active, TRUE), 'mở bán lại', 'ngừng bán'), NULL));

    IF v_changes = '' THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_package_id AS package_id;
        LEAVE proc;
    END IF;

    UPDATE tour_packages
       SET name = v_name,
           description = v_description,
           adult_price_vnd = p_adult_price_vnd,
           child_price_vnd = p_child_price_vnd,
           active = COALESCE(p_active, TRUE),
           sort_order = p_sort_order,
           updated_at = NOW()
     WHERE id = (v_package_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'package_update',
            IF(v_old_active, 'active', 'inactive'), IF(COALESCE(p_active, TRUE), 'active', 'inactive'),
            LEFT(CONCAT('Gói "', v_name, '": ', v_changes), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_package_id AS package_id;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.4 - 19_procedures_LTP_change.sql
-- Mục đích  : Khách gửi yêu cầu đổi ngày / hủy tour (US14-S5-01, US14-S5-02, FR-12): xem chính
--             sách áp dụng cho đơn và số tiền dự kiến hoàn, chọn lịch mới, lưu yêu cầu và lịch
--             sử. Quản trị viên xử lý thủ công ở 20_procedures_LTP_change_admin.sql.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 5
-- Procedures: LTP_sp_change_quote, LTP_sp_change_schedule_options, LTP_sp_change_request_create,
--             LTP_sp_change_request_list
-- Quy tắc   : * Chỉ chủ đơn (tài khoản khách hàng đang hoạt động) gửi được.
--             * Đơn đang 'pending', 'awaiting_payment' hoặc 'confirmed' và chưa tới giờ khởi
--               hành. Mỗi đơn chỉ một yêu cầu 'pending' (khóa dòng đơn FOR UPDATE khi kiểm tra).
--             * Chính sách áp dụng = phiên bản đã lưu cùng đơn (bookings.policy_version):
--               hủy trước (giờ khởi hành - free_before_hours) được hoàn 100% tiền đã trả;
--               sau mốc đó hoàn refund_percent %. free_before_hours NULL = không có mốc hủy
--               miễn phí, luôn hoàn refund_percent %. Đơn không có chính sách (version 0): dự
--               kiến hoàn 0đ, LocalTour xem xét từng trường hợp.
--             * Tiền đã trả = tổng payments 'paid' của đơn. Đơn chưa thanh toán: hoàn 0đ.
--             * Đổi ngày: lịch mới cùng tour, đang mở bán ('open'), chưa khởi hành, khác lịch
--               hiện tại và còn đủ chỗ cho số khách của đơn. Giá đơn không đổi.
--             * Lý do bắt buộc, tối đa 500 ký tự.
--             * Chưa tự động hoàn tiền, chưa đổi đơn ở bước này: chỉ lưu yêu cầu, chụp lại chính
--               sách và ghi booking_events 'cancel_requested' / 'change_requested'.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 16_migration_sprint5_LTP.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_change_quote(p_user_id, p_code)
--   0 hoặc 1 dòng (đơn của tài khoản p_user_id):
--   booking_id, booking_code, booking_status, tour_id, tour_title, schedule_id, starts_at,
--   ends_at, people, total_vnd, policy_version, free_before_hours, refund_percent,
--   policy_terms, free_until (NULL khi không có mốc hủy miễn phí), in_free_window (1/0),
--   paid_vnd, estimated_refund_vnd (nếu hủy ngay bây giờ),
--   can_request (1 = gửi được yêu cầu), block_reason (NULL, 'status', 'departed',
--   'pending_request'), pending_request_id, pending_request_type.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_quote;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_quote(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        q.*,
        (q.block_reason IS NULL) AS can_request
    FROM (
        SELECT
            x.*,
            CASE
                WHEN x.booking_status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN 'status'
                WHEN x.starts_at <= NOW() THEN 'departed'
                WHEN x.pending_request_id IS NOT NULL THEN 'pending_request'
            END AS block_reason,
            FLOOR(x.paid_vnd * IF(x.in_free_window, 100, COALESCE(x.refund_percent, 0)) / 100) AS estimated_refund_vnd
        FROM (
            SELECT
                b.id                AS booking_id,
                b.code              AS booking_code,
                b.status            AS booking_status,
                t.id                AS tour_id,
                t.title             AS tour_title,
                s.id                AS schedule_id,
                s.starts_at,
                s.ends_at,
                (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id) AS people,
                b.total_vnd,
                b.policy_version,
                cp.free_before_hours,
                cp.refund_percent,
                cp.terms            AS policy_terms,
                IF(cp.free_before_hours IS NULL, NULL,
                   s.starts_at - INTERVAL cp.free_before_hours HOUR) AS free_until,
                (cp.free_before_hours IS NOT NULL
                 AND NOW() < s.starts_at - INTERVAL cp.free_before_hours HOUR) AS in_free_window,
                (SELECT COALESCE(SUM(p.amount_vnd), 0) FROM payments p
                  WHERE p.booking_id = b.id AND p.status = 'paid') AS paid_vnd,
                (SELECT r.id FROM booking_change_requests r
                  WHERE r.booking_id = b.id AND r.status = 'pending'
                  ORDER BY r.created_at DESC, r.id LIMIT 1) AS pending_request_id,
                (SELECT r.type FROM booking_change_requests r
                  WHERE r.booking_id = b.id AND r.status = 'pending'
                  ORDER BY r.created_at DESC, r.id LIMIT 1) AS pending_request_type
            FROM bookings b
            JOIN schedules s ON s.id = b.schedule_id
            JOIN tours     t ON t.id = s.tour_id
            LEFT JOIN cancellation_policies cp
                   ON cp.tour_id = t.id AND cp.version = b.policy_version
            WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
              AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
        ) x
    ) q;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_change_schedule_options(p_user_id, p_code)
--   Các lịch khách có thể đổi sang: cùng tour với đơn, 'open', chưa khởi hành, khác lịch
--   hiện tại, còn đủ chỗ cho số khách của đơn (đơn chưa giữ chỗ cũng tính như vậy) và có
--   loại vé đang bán cùng tên với mọi dòng vé của đơn (người lớn / trẻ em).
--   Rỗng nếu không phải đơn của tài khoản này.
--   Cột: schedule_id, starts_at, ends_at, remaining. Sắp xếp starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_schedule_options;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_schedule_options(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        s2.id          AS schedule_id,
        s2.starts_at,
        s2.ends_at,
        s2.remaining
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN schedules s2 ON s2.tour_id = s.tour_id AND s2.id <> s.id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
      AND s2.status = 'open'
      AND s2.starts_at > NOW()
      AND s2.remaining >= (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id)
      AND NOT EXISTS (SELECT 1
                        FROM booking_lines bl
                        JOIN ticket_types ot ON ot.id = bl.ticket_type_id
                       WHERE bl.booking_id = b.id
                         AND NOT EXISTS (SELECT 1 FROM ticket_types nt
                                          WHERE nt.schedule_id = s2.id AND nt.name = ot.name
                                            AND nt.active = TRUE))
    ORDER BY s2.starts_at, s2.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_change_request_create(p_user_id, p_code, p_type, p_schedule_id, p_reason)
--   p_type: 'cancel' | 'change_date' (p_schedule_id = lịch mới, bỏ qua với 'cancel').
--   1 dòng: result, field, request_id, estimated_refund_vnd.
--     result = 'ok'                   : đã lưu yêu cầu 'pending'.
--              'forbidden'            : không phải tài khoản khách hàng đang hoạt động.
--              'not_found'            : không có đơn này của tài khoản.
--              'invalid'              : field = type, schedule_id hoặc reason (trống / quá 500 ký tự).
--              'not_allowed'          : đơn không còn ở trạng thái đổi / hủy được.
--              'departed'             : đã tới giờ khởi hành.
--              'pending_exists'       : đơn đang có một yêu cầu chờ xử lý.
--              'schedule_unavailable' : lịch mới không đổi sang được (khác tour, đã đóng, đã
--                                       khởi hành, trùng lịch hiện tại, thiếu loại vé của đơn).
--              'no_seats'             : lịch mới không còn đủ chỗ.
--     Khi không 'ok', không có gì được ghi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_request_create;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_request_create(
    IN p_user_id     CHAR(36),
    IN p_code        VARCHAR(20),
    IN p_type        VARCHAR(20),
    IN p_schedule_id CHAR(36),
    IN p_reason      TEXT CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_type        VARCHAR(20)  DEFAULT COALESCE(p_type, '');
    DECLARE v_reason      TEXT         CHARACTER SET utf8mb4;
    DECLARE v_booking_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_status      VARCHAR(30)  DEFAULT NULL;
    DECLARE v_schedule_id CHAR(36)     DEFAULT NULL;
    DECLARE v_tour_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_starts_at   DATETIME     DEFAULT NULL;
    DECLARE v_policy      INT          DEFAULT 0;
    DECLARE v_free_hours  INT          DEFAULT NULL;
    DECLARE v_percent     INT          DEFAULT NULL;
    DECLARE v_in_free     BOOLEAN      DEFAULT FALSE;
    DECLARE v_paid        BIGINT       DEFAULT 0;
    DECLARE v_refund      BIGINT       DEFAULT 0;
    DECLARE v_people      INT          DEFAULT 0;
    DECLARE v_new_id      CHAR(36)     DEFAULT NULL;
    DECLARE v_new_tour    CHAR(36)     DEFAULT NULL;
    DECLARE v_new_starts  DATETIME     DEFAULT NULL;
    DECLARE v_new_status  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_new_left    INT          DEFAULT 0;
    DECLARE v_request_id  CHAR(36)     DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_reason = NULLIF(TRIM(p_reason), '');

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'customer' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    IF v_type NOT IN ('cancel', 'change_date') THEN
        SELECT 'invalid' AS result, 'type' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;
    IF v_type = 'change_date' AND NULLIF(TRIM(p_schedule_id), '') IS NULL THEN
        SELECT 'invalid' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;
    IF v_reason IS NULL OR CHAR_LENGTH(v_reason) > 500 THEN
        SELECT 'invalid' AS result, 'reason' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa dòng đơn: hai yêu cầu gửi cùng lúc chỉ một yêu cầu được lưu.
    SELECT b.id, b.status, b.schedule_id, b.policy_version
      INTO v_booking_id, v_status, v_schedule_id, v_policy
      FROM bookings b
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    SELECT s.tour_id, s.starts_at INTO v_tour_id, v_starts_at
      FROM schedules s
     WHERE s.id = v_schedule_id;

    IF v_status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN
        ROLLBACK;
        SELECT 'not_allowed' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    IF v_starts_at <= NOW() THEN
        ROLLBACK;
        SELECT 'departed' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM booking_change_requests r
                WHERE r.booking_id = v_booking_id AND r.status = 'pending') THEN
        ROLLBACK;
        SELECT 'pending_exists' AS result, NULL AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
        LEAVE proc;
    END IF;

    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
      FROM booking_lines bl
     WHERE bl.booking_id = v_booking_id;

    IF v_type = 'change_date' THEN
        SELECT s.id, s.tour_id, s.starts_at, s.status, s.remaining
          INTO v_new_id, v_new_tour, v_new_starts, v_new_status, v_new_left
          FROM schedules s
         WHERE s.id = (TRIM(p_schedule_id) COLLATE utf8mb4_unicode_ci);

        IF v_new_id IS NULL OR v_new_tour <> v_tour_id OR v_new_id = v_schedule_id
           OR v_new_status <> 'open' OR v_new_starts <= NOW() THEN
            ROLLBACK;
            SELECT 'schedule_unavailable' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
            LEAVE proc;
        END IF;

        IF v_new_left < v_people THEN
            ROLLBACK;
            SELECT 'no_seats' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
            LEAVE proc;
        END IF;

        -- Lịch mới phải có loại vé đang bán cùng tên với mọi dòng vé của đơn.
        IF EXISTS (SELECT 1
                     FROM booking_lines bl
                     JOIN ticket_types ot ON ot.id = bl.ticket_type_id
                    WHERE bl.booking_id = v_booking_id
                      AND NOT EXISTS (SELECT 1 FROM ticket_types nt
                                       WHERE nt.schedule_id = v_new_id AND nt.name = ot.name
                                         AND nt.active = TRUE)) THEN
            ROLLBACK;
            SELECT 'schedule_unavailable' AS result, 'schedule_id' AS field, NULL AS request_id, NULL AS estimated_refund_vnd;
            LEAVE proc;
        END IF;
    END IF;

    -- Chính sách đã lưu cùng đơn và tiền đã trả: chụp lại vào yêu cầu.
    SELECT cp.free_before_hours, cp.refund_percent
      INTO v_free_hours, v_percent
      FROM cancellation_policies cp
     WHERE cp.tour_id = v_tour_id AND cp.version = v_policy;

    SET v_in_free = (v_free_hours IS NOT NULL AND NOW() < v_starts_at - INTERVAL v_free_hours HOUR);

    SELECT COALESCE(SUM(p.amount_vnd), 0) INTO v_paid
      FROM payments p
     WHERE p.booking_id = v_booking_id AND p.status = 'paid';

    SET v_refund = IF(v_type = 'cancel',
                      FLOOR(v_paid * IF(v_in_free, 100, COALESCE(v_percent, 0)) / 100), 0);

    INSERT INTO booking_change_requests (id, booking_id, user_id, type, requested_schedule_id, reason, status,
                                         booking_status, policy_version, free_before_hours, refund_percent,
                                         in_free_window, paid_vnd, estimated_refund_vnd, created_at)
    VALUES (v_request_id, v_booking_id, p_user_id, v_type, v_new_id, v_reason, 'pending',
            v_status, v_policy, v_free_hours, v_percent,
            v_in_free, v_paid, v_refund, NOW());

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'customer', p_user_id,
            IF(v_type = 'cancel', 'cancel_requested', 'change_requested'), v_status, v_status,
            LEFT(CONCAT(IF(v_type = 'cancel', '',
                           CONCAT('Đổi sang ', DATE_FORMAT(v_new_starts, '%d/%m/%Y %H:%i'), '. ')),
                        'Lý do: ', v_reason), 255),
            NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_request_id AS request_id, v_refund AS estimated_refund_vnd;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_change_request_list(p_user_id, p_code)
--   Các yêu cầu đổi / hủy của một đơn (của tài khoản p_user_id), mới nhất trước.
--   Cột: request_id, type, status, requested_starts_at, reason, in_free_window, paid_vnd,
--        estimated_refund_vnd, refund_vnd, result_note, created_at, handled_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_change_request_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_change_request_list(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20)
)
READS SQL DATA
BEGIN
    SELECT
        r.id               AS request_id,
        r.type,
        r.status,
        ns.starts_at       AS requested_starts_at,
        r.reason,
        r.in_free_window,
        r.paid_vnd,
        r.estimated_refund_vnd,
        r.refund_vnd,
        r.result_note,
        r.created_at,
        r.handled_at
    FROM booking_change_requests r
    JOIN bookings b ON b.id = r.booking_id
    LEFT JOIN schedules ns ON ns.id = r.requested_schedule_id
    WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
    ORDER BY r.created_at DESC, r.id;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.4 - 20_procedures_LTP_change_admin.sql
-- Mục đích  : Quản trị viên xem và xử lý thủ công yêu cầu đổi ngày / hủy tour của khách
--             (US14-S5-03, FR-12): đồng ý hoặc từ chối, ghi kết quả, trạng thái và lịch sử.
-- Phụ trách : Lê Trung Phong (LTP) - Sprint 5
-- Procedures: LTP_sp_admin_change_request_list, LTP_sp_admin_change_request_detail,
--             LTP_sp_admin_change_request_decide
-- Quy tắc   : * Chỉ quản trị viên đang hoạt động xử lý được; yêu cầu chỉ xử lý một lần.
--             * Bắt buộc ghi kết quả xử lý (tối đa 500 ký tự), cả khi đồng ý lẫn từ chối.
--             * Đồng ý hủy: đơn chuyển 'cancelled'; đơn đang giữ chỗ được trả lại chỗ; khoản
--               thanh toán chưa xong ('pending', 'processing') chuyển 'failed'. Không đồng ý
--               được khi còn khoản chuyển khoản chờ đối chiếu (xử lý ở trang Thanh toán trước).
--               Có tiền đã trả: ghi một dòng refunds 'requested' với số tiền quản trị viên chốt
--               (0 - tiền đã trả; mặc định = số dự kiến hoàn) để hoàn tay. Chưa tự động hoàn tiền.
--             * Đồng ý đổi ngày: lịch mới phải còn mở bán, chưa khởi hành, cùng tour và còn đủ
--               chỗ; đơn chuyển sang lịch mới (dòng vé đổi sang loại vé cùng tên của lịch mới,
--               giá đơn giữ nguyên). Đơn đang giữ chỗ: trả chỗ lịch cũ, giữ chỗ lịch mới.
--             * Lịch sử: admin_logs của đơn ('cancel_approved', 'cancel_rejected',
--               'change_approved', 'change_rejected', 'refund_requested'); trang đơn của khách
--               và của quản trị viên đọc qua LTP_sp_*booking_history (file 15).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 19_procedures_LTP_change.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_admin_change_request_list(p_status, p_booking_id)
--   p_status    : NULL / '' = mọi trạng thái; 'pending' | 'approved' | 'rejected'.
--   p_booking_id: NULL / '' = mọi đơn; ngược lại chỉ yêu cầu của đơn đó.
--   Cột: request_id, type, status, created_at, handled_at, booking_id, booking_code,
--        booking_status, customer_name, customer_email, tour_title, starts_at (lịch hiện tại
--        của đơn), requested_starts_at, people, paid_vnd, estimated_refund_vnd, refund_vnd,
--        result_note, handler_name.
--   Sắp xếp: chờ xử lý trước (gửi sớm trước), rồi đã xử lý (mới nhất trước). Tối đa 200 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_change_request_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_change_request_list(
    IN p_status     VARCHAR(20),
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        r.id                 AS request_id,
        r.type,
        r.status,
        r.created_at,
        r.handled_at,
        b.id                 AS booking_id,
        b.code               AS booking_code,
        b.status             AS booking_status,
        cu.name              AS customer_name,
        cu.email             AS customer_email,
        t.title              AS tour_title,
        s.starts_at,
        ns.starts_at         AS requested_starts_at,
        (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id) AS people,
        r.paid_vnd,
        r.estimated_refund_vnd,
        r.refund_vnd,
        r.result_note,
        hu.name              AS handler_name
    FROM booking_change_requests r
    JOIN bookings  b  ON b.id = r.booking_id
    JOIN users     cu ON cu.id = r.user_id
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours     t  ON t.id = s.tour_id
    LEFT JOIN schedules ns ON ns.id = r.requested_schedule_id
    LEFT JOIN users     hu ON hu.id = r.handled_by
    WHERE (NULLIF(p_status, '') IS NULL OR r.status = (p_status COLLATE utf8mb4_unicode_ci))
      AND (NULLIF(p_booking_id, '') IS NULL OR r.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci))
    ORDER BY (r.status = 'pending') DESC,
             IF(r.status = 'pending', r.created_at, NULL) ASC,
             COALESCE(r.handled_at, r.created_at) DESC,
             r.id
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_change_request_detail(p_request_id)
--   0 hoặc 1 dòng: mọi cột của yêu cầu và thông tin để quản trị viên quyết định.
--   Cột: request_id, type, status, reason, created_at, handled_at, result_note, refund_vnd,
--        handler_name, booking_status_at_request (booking_status lúc gửi), policy_version,
--        free_before_hours, refund_percent, in_free_window, paid_vnd (lúc gửi),
--        estimated_refund_vnd, policy_terms,
--        booking_id, booking_code, booking_status, total_vnd, package_name, contact_name,
--        contact_email, contact_phone, customer_name, customer_email, tour_id, tour_title,
--        schedule_id, starts_at, ends_at, people, paid_now_vnd (tiền đã trả hiện tại),
--        review_payment_count (khoản chuyển khoản chờ đối chiếu: phải xử lý trước khi hủy),
--        requested_schedule_id, requested_starts_at, requested_ends_at,
--        requested_status, requested_remaining.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_change_request_detail;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_change_request_detail(
    IN p_request_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        r.id                 AS request_id,
        r.type,
        r.status,
        r.reason,
        r.created_at,
        r.handled_at,
        r.result_note,
        r.refund_vnd,
        hu.name              AS handler_name,
        r.booking_status     AS booking_status_at_request,
        r.policy_version,
        r.free_before_hours,
        r.refund_percent,
        r.in_free_window,
        r.paid_vnd,
        r.estimated_refund_vnd,
        cp.terms             AS policy_terms,
        b.id                 AS booking_id,
        b.code               AS booking_code,
        b.status             AS booking_status,
        b.total_vnd,
        b.package_name,
        b.contact_name,
        b.contact_email,
        b.contact_phone,
        cu.name              AS customer_name,
        cu.email             AS customer_email,
        t.id                 AS tour_id,
        t.title              AS tour_title,
        s.id                 AS schedule_id,
        s.starts_at,
        s.ends_at,
        (SELECT COALESCE(SUM(bl.quantity), 0) FROM booking_lines bl WHERE bl.booking_id = b.id) AS people,
        (SELECT COALESCE(SUM(p.amount_vnd), 0) FROM payments p
          WHERE p.booking_id = b.id AND p.status = 'paid') AS paid_now_vnd,
        (SELECT COUNT(*) FROM payments p
          WHERE p.booking_id = b.id AND p.status = 'awaiting_reconciliation') AS review_payment_count,
        ns.id                AS requested_schedule_id,
        ns.starts_at         AS requested_starts_at,
        ns.ends_at           AS requested_ends_at,
        ns.status            AS requested_status,
        ns.remaining         AS requested_remaining
    FROM booking_change_requests r
    JOIN bookings  b  ON b.id = r.booking_id
    JOIN users     cu ON cu.id = r.user_id
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours     t  ON t.id = s.tour_id
    LEFT JOIN schedules ns ON ns.id = r.requested_schedule_id
    LEFT JOIN users     hu ON hu.id = r.handled_by
    LEFT JOIN cancellation_policies cp ON cp.tour_id = t.id AND cp.version = r.policy_version
    WHERE r.id = (p_request_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- LTP_sp_admin_change_request_decide(p_actor_user_id, p_request_id, p_decision, p_note,
--                                    p_refund_vnd)
--   p_decision : 'approved' (đồng ý) | 'rejected' (từ chối).
--   p_note     : kết quả xử lý, bắt buộc, tối đa 500 ký tự.
--   p_refund_vnd: chỉ dùng khi đồng ý hủy: số tiền sẽ hoàn (0 - tiền đã trả). NULL = số dự
--                 kiến hoàn lúc khách gửi (không vượt tiền đã trả hiện tại).
--   1 dòng: result, field, booking_status.
--     result = 'ok'                   : đã xử lý; booking_status = trạng thái đơn sau xử lý.
--              'forbidden'            : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'            : không có yêu cầu này.
--              'invalid'              : field = decision, note hoặc refund_vnd.
--              'already_handled'      : yêu cầu đã được xử lý trước đó.
--              'booking_closed'       : đồng ý khi đơn đã hủy / bị từ chối / hoàn thành.
--              'payment_in_review'    : đồng ý hủy khi còn khoản chuyển khoản chờ đối chiếu.
--              'schedule_unavailable' : đồng ý đổi ngày khi lịch mới đã đóng / đã khởi hành.
--              'no_seats'             : đồng ý đổi ngày khi lịch mới không còn đủ chỗ.
--              'tickets_missing'      : lịch mới không có loại vé đang bán tương ứng với vé của đơn.
--     Khi không 'ok', không có gì thay đổi.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_admin_change_request_decide;

DELIMITER $$
CREATE PROCEDURE LTP_sp_admin_change_request_decide(
    IN p_actor_user_id CHAR(36),
    IN p_request_id    CHAR(36),
    IN p_decision      VARCHAR(20),
    IN p_note          TEXT CHARACTER SET utf8mb4,
    IN p_refund_vnd    BIGINT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_decision    VARCHAR(20)  DEFAULT COALESCE(p_decision, '');
    DECLARE v_note        TEXT         CHARACTER SET utf8mb4;
    DECLARE v_req_status  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_type        VARCHAR(20)  DEFAULT NULL;
    DECLARE v_booking_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_new_sched   CHAR(36)     DEFAULT NULL;
    DECLARE v_estimate    BIGINT       DEFAULT 0;
    DECLARE v_status      VARCHAR(30)  DEFAULT NULL;
    DECLARE v_schedule    CHAR(36)     DEFAULT NULL;
    DECLARE v_tour_id     CHAR(36)     DEFAULT NULL;
    DECLARE v_old_starts  DATETIME     DEFAULT NULL;
    DECLARE v_new_tour    CHAR(36)     DEFAULT NULL;
    DECLARE v_new_starts  DATETIME     DEFAULT NULL;
    DECLARE v_new_status  VARCHAR(20)  DEFAULT NULL;
    DECLARE v_new_left    INT          DEFAULT 0;
    DECLARE v_people      INT          DEFAULT 0;
    DECLARE v_paid        BIGINT       DEFAULT 0;
    DECLARE v_refund      BIGINT       DEFAULT NULL;
    DECLARE v_payment_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_reference   VARCHAR(32)  DEFAULT NULL;
    DECLARE v_holds       BOOLEAN      DEFAULT FALSE;
    DECLARE v_missing     INT          DEFAULT 0;
    DECLARE v_log_note    VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_note = NULLIF(TRIM(p_note), '');

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;

    IF v_decision NOT IN ('approved', 'rejected') THEN
        SELECT 'invalid' AS result, 'decision' AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;
    IF v_note IS NULL OR CHAR_LENGTH(v_note) > 500 THEN
        SELECT 'invalid' AS result, 'note' AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;
    IF p_refund_vnd IS NOT NULL AND p_refund_vnd < 0 THEN
        SELECT 'invalid' AS result, 'refund_vnd' AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT r.status, r.type, r.booking_id, r.requested_schedule_id, r.estimated_refund_vnd
      INTO v_req_status, v_type, v_booking_id, v_new_sched, v_estimate
      FROM booking_change_requests r
     WHERE r.id = (p_request_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_req_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS booking_status;
        LEAVE proc;
    END IF;

    -- Khóa đơn và lịch hiện tại: số chỗ và trạng thái đơn chỉ đổi trong transaction này.
    SELECT b.status, b.schedule_id, s.tour_id, s.starts_at
      INTO v_status, v_schedule, v_tour_id, v_old_starts
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE b.id = v_booking_id
       FOR UPDATE;

    IF v_req_status <> 'pending' THEN
        ROLLBACK;
        SELECT 'already_handled' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    -- Từ chối: chỉ ghi kết quả.
    IF v_decision = 'rejected' THEN
        UPDATE booking_change_requests
           SET status = 'rejected', result_note = v_note,
               handled_by = p_actor_user_id, handled_at = NOW()
         WHERE id = (p_request_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id,
                IF(v_type = 'cancel', 'cancel_rejected', 'change_rejected'), v_status, v_status,
                LEFT(v_note, 255), NOW());

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    IF v_status NOT IN ('pending', 'awaiting_payment', 'confirmed') THEN
        ROLLBACK;
        SELECT 'booking_closed' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    SET v_holds = v_status IN ('awaiting_payment', 'confirmed');
    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_people
      FROM booking_lines bl
     WHERE bl.booking_id = v_booking_id;

    -- ----------------------------- Đồng ý hủy -----------------------------
    IF v_type = 'cancel' THEN
        IF EXISTS (SELECT 1 FROM payments p
                    WHERE p.booking_id = v_booking_id AND p.status = 'awaiting_reconciliation') THEN
            ROLLBACK;
            SELECT 'payment_in_review' AS result, NULL AS field, v_status AS booking_status;
            LEAVE proc;
        END IF;

        SELECT COALESCE(SUM(p.amount_vnd), 0) INTO v_paid
          FROM payments p
         WHERE p.booking_id = v_booking_id AND p.status = 'paid';

        SET v_refund = COALESCE(p_refund_vnd, LEAST(v_estimate, v_paid));
        IF v_refund > v_paid THEN
            ROLLBACK;
            SELECT 'invalid' AS result, 'refund_vnd' AS field, v_status AS booking_status;
            LEAVE proc;
        END IF;

        IF v_holds THEN
            UPDATE schedules
               SET remaining = LEAST(capacity, remaining + v_people),
                   status = IF(status = 'full' AND remaining > 0, 'open', status)
             WHERE id = v_schedule;
        END IF;

        UPDATE bookings SET status = 'cancelled', hold_expires_at = NULL WHERE id = v_booking_id;

        UPDATE payments
           SET status = 'failed', note = 'Đơn đã hủy theo yêu cầu của khách.'
         WHERE booking_id = v_booking_id
           AND status IN ('pending', 'processing');

        UPDATE booking_change_requests
           SET status = 'approved', result_note = v_note, refund_vnd = v_refund,
               handled_by = p_actor_user_id, handled_at = NOW()
         WHERE id = (p_request_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'cancel_approved', v_status, 'cancelled',
                LEFT(v_note, 255), NOW());

        IF v_refund > 0 THEN
            SELECT p.id, p.reference INTO v_payment_id, v_reference
              FROM payments p
             WHERE p.booking_id = v_booking_id AND p.status = 'paid'
             ORDER BY p.amount_vnd DESC, p.paid_at DESC, p.id
             LIMIT 1;

            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), v_payment_id, v_refund,
                    LEFT(CONCAT('Hủy tour theo yêu cầu của khách: ', v_note), 255), 'requested', NOW());

            INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'refund_requested', NULL, NULL,
                    LEFT(CONCAT('Hoàn ', REPLACE(FORMAT(v_refund, 0), ',', '.'), ' VND',
                                IF(v_reference IS NULL, '', CONCAT(' cho khoản ', v_reference)),
                                ', LocalTour hoàn tiền thủ công.'), 255), NOW());
        END IF;

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, 'cancelled' AS booking_status;
        LEAVE proc;
    END IF;

    -- --------------------------- Đồng ý đổi ngày ---------------------------
    SELECT s.tour_id, s.starts_at, s.status, s.remaining
      INTO v_new_tour, v_new_starts, v_new_status, v_new_left
      FROM schedules s
     WHERE s.id = v_new_sched
       FOR UPDATE;

    IF v_new_tour IS NULL OR v_new_tour <> v_tour_id OR v_new_sched = v_schedule
       OR v_new_status <> 'open' OR v_new_starts <= NOW() THEN
        ROLLBACK;
        SELECT 'schedule_unavailable' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    IF v_new_left < v_people THEN
        ROLLBACK;
        SELECT 'no_seats' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    -- Mỗi dòng vé của đơn phải có loại vé đang bán cùng tên ở lịch mới.
    SELECT COUNT(*) INTO v_missing
      FROM booking_lines bl
      JOIN ticket_types ot ON ot.id = bl.ticket_type_id
     WHERE bl.booking_id = v_booking_id
       AND NOT EXISTS (SELECT 1 FROM ticket_types nt
                        WHERE nt.schedule_id = v_new_sched AND nt.name = ot.name
                          AND nt.active = TRUE);

    IF v_missing > 0 THEN
        ROLLBACK;
        SELECT 'tickets_missing' AS result, NULL AS field, v_status AS booking_status;
        LEAVE proc;
    END IF;

    UPDATE booking_lines bl
      JOIN ticket_types ot ON ot.id = bl.ticket_type_id
       SET bl.ticket_type_id = (SELECT nt.id FROM ticket_types nt
                                 WHERE nt.schedule_id = v_new_sched AND nt.name = ot.name
                                   AND nt.active = TRUE
                                 ORDER BY nt.id
                                 LIMIT 1)
     WHERE bl.booking_id = v_booking_id;

    IF v_holds THEN
        UPDATE schedules
           SET remaining = LEAST(capacity, remaining + v_people),
               status = IF(status = 'full' AND remaining > 0, 'open', status)
         WHERE id = v_schedule;

        -- SET chạy từ trái sang phải: status so với remaining đã trừ.
        UPDATE schedules
           SET remaining = remaining - v_people,
               status = IF(remaining = 0 AND status = 'open', 'full', status)
         WHERE id = v_new_sched;
    END IF;

    UPDATE bookings SET schedule_id = v_new_sched WHERE id = v_booking_id;

    UPDATE booking_change_requests
       SET status = 'approved', result_note = v_note,
           handled_by = p_actor_user_id, handled_at = NOW()
     WHERE id = (p_request_id COLLATE utf8mb4_unicode_ci);

    SET v_log_note = LEFT(CONCAT('Đổi lịch ', DATE_FORMAT(v_old_starts, '%d/%m/%Y %H:%i'), ' → ',
                                 DATE_FORMAT(v_new_starts, '%d/%m/%Y %H:%i'), '. ', v_note), 255);
    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'booking', v_booking_id, 'change_approved', v_status, v_status, v_log_note, NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_status AS booking_status;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.4 - 21_procedures_NMT_tour_content.sql
-- Mục đích  : Hoàn thiện quản trị tour (US07-S5-01, FR-13): các phần trước đây chỉ thêm được
--             bằng SQL nay quản lý ở trang quản trị: ảnh, lịch trình, dịch vụ bao gồm / không
--             bao gồm, chính sách hủy (phiên bản mới); xóa tour và xóa đơn vị tổ chức chưa có tour.
-- Phụ trách : Nguyễn Minh Thức (NMT) - Sprint 5
-- Procedures: NMT_sp_admin_image_list, NMT_sp_admin_image_add, NMT_sp_admin_image_delete,
--             NMT_sp_admin_image_set_cover,
--             NMT_sp_admin_itinerary_list, NMT_sp_admin_itinerary_save, NMT_sp_admin_itinerary_delete,
--             NMT_sp_admin_inclusion_list, NMT_sp_admin_inclusion_add, NMT_sp_admin_inclusion_delete,
--             NMT_sp_admin_policy_list, NMT_sp_admin_policy_add,
--             NMT_sp_admin_tour_delete, NMT_sp_admin_tour_restore,
--             NMT_sp_admin_provider_delete
-- Quy tắc   : * Mọi thao tác ghi kiểm tra người thao tác là quản trị viên đang hoạt động và ghi
--               admin_logs (target_type 'tour', target_id = mã tour).
--             * Chỉ sửa dữ liệu của đúng tour (mã mục phải thuộc tour đó): không ảnh hưởng tour khác.
--             * Ảnh: tối đa 12 ảnh / tour; ảnh bìa = ảnh có sort_order nhỏ nhất. File ảnh do ứng
--               dụng lưu (public/assets/uploads/tours); xóa ảnh trả url để ứng dụng xóa file.
--             * Chính sách hủy không sửa phiên bản cũ (đơn đã đặt giữ phiên bản lúc đặt): lưu
--               chính sách mới = thêm phiên bản mới (version + 1).
--             * Xóa tour: tour chưa có đơn nào thì xóa hẳn cùng mọi dữ liệu con; tour đã có
--               đơn thì chuyển 'archived' (ngừng hiển thị, đơn cũ giữ nguyên). Không xóa / ngừng
--               hiển thị khi còn đơn đang xử lý (pending / awaiting_payment / confirmed).
--               Khôi phục tour ngừng hiển thị: về 'pending' để duyệt lại.
--             * Xóa đơn vị tổ chức: chỉ khi đơn vị chưa có tour nào; còn tour thì chuyển
--               "Ngừng hợp tác" để ẩn tour (admin_logs target_type 'provider').
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 16_migration_sprint5_LTP.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- =====================================================================
-- Ảnh tour
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_list(p_tour_id)
--   Cột: image_id, url, alt_text, sort_order, is_cover (1 = ảnh bìa). Sắp xếp sort_order.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        ti.id          AS image_id,
        ti.url,
        ti.alt_text,
        ti.sort_order,
        (ti.id = (SELECT c.id FROM tour_images c
                   WHERE c.tour_id = ti.tour_id
                   ORDER BY c.sort_order, c.id LIMIT 1)) AS is_cover
    FROM tour_images ti
    WHERE ti.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY ti.sort_order, ti.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_add(p_actor_user_id, p_tour_id, p_url, p_alt_text)
--   Thêm ảnh cuối danh sách (sort_order = lớn nhất + 1). p_url: đường dẫn ứng dụng đã lưu
--   (vd. 'uploads/tours/<tên file>'), tối đa 255 ký tự; p_alt_text tối đa 255 ký tự.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid', 'limit'), field, image_id.
--     'limit' = tour đã có 12 ảnh.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_add;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_add(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_url           VARCHAR(500) CHARACTER SET utf8mb4,
    IN p_alt_text      VARCHAR(500) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_url      VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_url), '');
    DECLARE v_alt      VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_alt_text), '');
    DECLARE v_count    INT      DEFAULT 0;
    DECLARE v_sort     INT      DEFAULT 0;
    DECLARE v_image_id CHAR(36) DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS image_id;
        LEAVE proc;
    END IF;

    IF v_url IS NULL OR CHAR_LENGTH(v_url) > 255 THEN
        SELECT 'invalid' AS result, 'image' AS field, NULL AS image_id;
        LEAVE proc;
    END IF;
    IF v_alt IS NOT NULL AND CHAR_LENGTH(v_alt) > 255 THEN
        SELECT 'invalid' AS result, 'alt_text' AS field, NULL AS image_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa dòng tour: hai lần thêm ảnh cùng lúc không vượt giới hạn.
    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS image_id;
        LEAVE proc;
    END IF;

    SELECT COUNT(*), COALESCE(MAX(sort_order), 0) INTO v_count, v_sort
      FROM tour_images
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    IF v_count >= 12 THEN
        ROLLBACK;
        SELECT 'limit' AS result, 'image' AS field, NULL AS image_id;
        LEAVE proc;
    END IF;

    INSERT INTO tour_images (id, tour_id, url, alt_text, sort_order)
    VALUES (v_image_id, p_tour_id, v_url, v_alt, v_sort + 1);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'image_add', NULL, NULL,
            LEFT(CONCAT('Thêm ảnh', IF(v_alt IS NULL, '', CONCAT(' "', v_alt, '"'))), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_image_id AS image_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_delete(p_actor_user_id, p_tour_id, p_image_id)
--   1 dòng: result ('ok', 'forbidden', 'not_found'), url (đường dẫn ảnh vừa xóa).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_image_id      CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_url VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_alt VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS url;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT url, alt_text INTO v_url, v_alt
      FROM tour_images
     WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_url IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS url;
        LEAVE proc;
    END IF;

    DELETE FROM tour_images WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'image_delete', NULL, NULL,
            LEFT(CONCAT('Xóa ảnh', IF(v_alt IS NULL, '', CONCAT(' "', v_alt, '"'))), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, v_url AS url;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_image_set_cover(p_actor_user_id, p_tour_id, p_image_id)
--   Đưa ảnh lên đầu danh sách (sort_order = nhỏ nhất - 1) để làm ảnh bìa.
--   1 dòng: result ('ok', 'unchanged', 'forbidden', 'not_found').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_image_set_cover;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_image_set_cover(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_image_id      CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_found INT      DEFAULT 0;
    DECLARE v_cover CHAR(36) DEFAULT NULL;
    DECLARE v_min   INT      DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_found
      FROM tour_images
     WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_found = 0 THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    SELECT id, sort_order INTO v_cover, v_min
      FROM tour_images
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY sort_order, id
     LIMIT 1;

    IF v_cover = (p_image_id COLLATE utf8mb4_unicode_ci) THEN
        ROLLBACK;
        SELECT 'unchanged' AS result;
        LEAVE proc;
    END IF;

    UPDATE tour_images SET sort_order = v_min - 1 WHERE id = (p_image_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'image_cover', NULL, NULL, 'Đổi ảnh bìa', NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- =====================================================================
-- Lịch trình
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_itinerary_list(p_tour_id)
--   Cột: item_id, start_time, description, sort_order. Sắp xếp như trang chi tiết tour.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_itinerary_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_itinerary_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT it.id AS item_id, it.start_time, it.description, it.sort_order
      FROM tour_itinerary_items it
     WHERE it.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY it.sort_order, it.start_time, it.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_itinerary_save(p_actor_user_id, p_tour_id, p_item_id, p_start_time,
--                             p_description, p_sort_order)
--   p_item_id NULL / '' = thêm mục mới; ngược lại sửa mục đó (phải thuộc tour).
--   p_start_time NULL = mục không ghi giờ. Mô tả 1 - 255 ký tự; thứ tự 0 - 999.
--   Tối đa 30 mục / tour.
--   1 dòng: result ('ok', 'unchanged', 'forbidden', 'not_found', 'invalid', 'limit'),
--           field (description, sort_order), item_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_itinerary_save;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_itinerary_save(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_item_id       CHAR(36),
    IN p_start_time    TIME,
    IN p_description   VARCHAR(500) CHARACTER SET utf8mb4,
    IN p_sort_order    INT
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_item_id  CHAR(36)     DEFAULT NULLIF(TRIM(p_item_id), '');
    DECLARE v_desc     VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_description, ''));
    DECLARE v_found    INT          DEFAULT 0;
    DECLARE v_count    INT          DEFAULT 0;
    DECLARE v_old_time TIME         DEFAULT NULL;
    DECLARE v_old_desc VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_old_sort INT          DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS item_id;
        LEAVE proc;
    END IF;

    IF v_desc = '' OR CHAR_LENGTH(v_desc) > 255 THEN
        SELECT 'invalid' AS result, 'description' AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;
    IF p_sort_order IS NULL OR p_sort_order NOT BETWEEN 0 AND 999 THEN
        SELECT 'invalid' AS result, 'sort_order' AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS item_id;
        LEAVE proc;
    END IF;

    IF v_item_id IS NULL THEN
        SELECT COUNT(*) INTO v_count
          FROM tour_itinerary_items
         WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
        IF v_count >= 30 THEN
            ROLLBACK;
            SELECT 'limit' AS result, NULL AS field, NULL AS item_id;
            LEAVE proc;
        END IF;

        SET v_item_id = UUID();
        INSERT INTO tour_itinerary_items (id, tour_id, start_time, description, sort_order)
        VALUES (v_item_id, p_tour_id, p_start_time, v_desc, p_sort_order);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'itinerary_add', NULL, NULL,
                LEFT(CONCAT('Thêm lịch trình: ', IF(p_start_time IS NULL, '', CONCAT(TIME_FORMAT(p_start_time, '%H:%i'), ' ')), v_desc), 255),
                NOW());

        COMMIT;
        SELECT 'ok' AS result, NULL AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    SELECT COUNT(*), MAX(start_time), MAX(description), MAX(sort_order)
      INTO v_found, v_old_time, v_old_desc, v_old_sort
      FROM tour_itinerary_items
     WHERE id = (v_item_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_found = 0 THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    IF (v_old_time <=> p_start_time) AND BINARY v_old_desc = BINARY v_desc AND v_old_sort = p_sort_order THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_item_id AS item_id;
        LEAVE proc;
    END IF;

    UPDATE tour_itinerary_items
       SET start_time = p_start_time, description = v_desc, sort_order = p_sort_order
     WHERE id = (v_item_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'itinerary_update', NULL, NULL,
            LEFT(CONCAT('Sửa lịch trình: ', IF(p_start_time IS NULL, '', CONCAT(TIME_FORMAT(p_start_time, '%H:%i'), ' ')), v_desc), 255),
            NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_item_id AS item_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_itinerary_delete(p_actor_user_id, p_tour_id, p_item_id)
--   1 dòng: result ('ok', 'forbidden', 'not_found').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_itinerary_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_itinerary_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_item_id       CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_desc VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT description INTO v_desc
      FROM tour_itinerary_items
     WHERE id = (p_item_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_desc IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    DELETE FROM tour_itinerary_items WHERE id = (p_item_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'itinerary_delete', NULL, NULL,
            LEFT(CONCAT('Xóa lịch trình: ', v_desc), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- =====================================================================
-- Dịch vụ bao gồm / không bao gồm
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_inclusion_list(p_tour_id)
--   Cột: inclusion_id, item_text, is_included, sort_order. Bao gồm trước, rồi sort_order.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_inclusion_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_inclusion_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT i.id AS inclusion_id, i.item_text, i.is_included, i.sort_order
      FROM tour_inclusions i
     WHERE i.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY i.is_included DESC, i.sort_order, i.id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_inclusion_add(p_actor_user_id, p_tour_id, p_item_text, p_is_included)
--   Thêm cuối nhóm (bao gồm / không bao gồm). Nội dung 1 - 150 ký tự, tối đa 40 mục / tour.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid', 'limit'), field, inclusion_id.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_inclusion_add;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_inclusion_add(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_item_text     VARCHAR(500) CHARACTER SET utf8mb4,
    IN p_is_included   BOOLEAN
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_text  VARCHAR(500) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_item_text, ''));
    DECLARE v_inc   BOOLEAN  DEFAULT COALESCE(p_is_included, TRUE);
    DECLARE v_count INT      DEFAULT 0;
    DECLARE v_sort  INT      DEFAULT 0;
    DECLARE v_id    CHAR(36) DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS inclusion_id;
        LEAVE proc;
    END IF;

    IF v_text = '' OR CHAR_LENGTH(v_text) > 150 THEN
        SELECT 'invalid' AS result, 'item_text' AS field, NULL AS inclusion_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS inclusion_id;
        LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM tour_inclusions
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    IF v_count >= 40 THEN
        ROLLBACK;
        SELECT 'limit' AS result, NULL AS field, NULL AS inclusion_id;
        LEAVE proc;
    END IF;

    SELECT COALESCE(MAX(sort_order), 0) INTO v_sort
      FROM tour_inclusions
     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci) AND is_included = v_inc;

    INSERT INTO tour_inclusions (id, tour_id, item_text, is_included, sort_order)
    VALUES (v_id, p_tour_id, v_text, v_inc, v_sort + 1);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'inclusion_add', NULL, NULL,
            LEFT(CONCAT(IF(v_inc, 'Thêm mục bao gồm: ', 'Thêm mục không bao gồm: '), v_text), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_id AS inclusion_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_inclusion_delete(p_actor_user_id, p_tour_id, p_inclusion_id)
--   1 dòng: result ('ok', 'forbidden', 'not_found').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_inclusion_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_inclusion_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36),
    IN p_inclusion_id  CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_text VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT item_text INTO v_text
      FROM tour_inclusions
     WHERE id = (p_inclusion_id COLLATE utf8mb4_unicode_ci)
       AND tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_text IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    DELETE FROM tour_inclusions WHERE id = (p_inclusion_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'inclusion_delete', NULL, NULL,
            LEFT(CONCAT('Xóa mục: ', v_text), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- =====================================================================
-- Chính sách hủy
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_policy_list(p_tour_id)
--   Mọi phiên bản chính sách hủy, mới nhất trước.
--   Cột: policy_id, version, free_before_hours, refund_percent, terms, booking_count (số đơn
--        đặt theo phiên bản này).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_policy_list;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_policy_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        cp.id                AS policy_id,
        cp.version,
        cp.free_before_hours,
        cp.refund_percent,
        cp.terms,
        (SELECT COUNT(*) FROM bookings b
           JOIN schedules s ON s.id = b.schedule_id
          WHERE s.tour_id = cp.tour_id AND b.policy_version = cp.version) AS booking_count
    FROM cancellation_policies cp
    WHERE cp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
    ORDER BY cp.version DESC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_policy_add(p_actor_user_id, p_tour_id, p_free_before_hours, p_refund_percent,
--                         p_terms)
--   Thêm phiên bản mới (version = lớn nhất + 1). Đơn đặt sau đó dùng phiên bản mới; đơn cũ
--   giữ phiên bản lúc đặt.
--   p_free_before_hours: NULL = không có mốc hủy miễn phí; 0 - 720 giờ.
--   p_refund_percent   : 0 - 100 (% hoàn khi hủy sau mốc miễn phí, hoặc luôn áp dụng khi không
--                        có mốc). p_terms: 1 - 2000 ký tự.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid', 'unchanged'), field, version.
--     'unchanged' = giống hệt phiên bản mới nhất.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_policy_add;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_policy_add(
    IN p_actor_user_id     CHAR(36),
    IN p_tour_id           CHAR(36),
    IN p_free_before_hours INT,
    IN p_refund_percent    INT,
    IN p_terms             TEXT CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_terms     TEXT     CHARACTER SET utf8mb4;
    DECLARE v_version   INT      DEFAULT 0;
    DECLARE v_old_hours INT      DEFAULT NULL;
    DECLARE v_old_pct   INT      DEFAULT NULL;
    DECLARE v_old_terms TEXT     CHARACTER SET utf8mb4;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_terms = TRIM(COALESCE(p_terms, ''));

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS field, NULL AS version;
        LEAVE proc;
    END IF;

    IF p_free_before_hours IS NOT NULL AND p_free_before_hours NOT BETWEEN 0 AND 720 THEN
        SELECT 'invalid' AS result, 'free_before_hours' AS field, NULL AS version;
        LEAVE proc;
    END IF;
    IF p_refund_percent IS NULL OR p_refund_percent NOT BETWEEN 0 AND 100 THEN
        SELECT 'invalid' AS result, 'refund_percent' AS field, NULL AS version;
        LEAVE proc;
    END IF;
    IF v_terms = '' OR CHAR_LENGTH(v_terms) > 2000 THEN
        SELECT 'invalid' AS result, 'terms' AS field, NULL AS version;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM tours WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci) FOR UPDATE) THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS field, NULL AS version;
        LEAVE proc;
    END IF;

    SELECT cp.version, cp.free_before_hours, cp.refund_percent, cp.terms
      INTO v_version, v_old_hours, v_old_pct, v_old_terms
      FROM cancellation_policies cp
     WHERE cp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY cp.version DESC
     LIMIT 1;

    IF v_version > 0 AND (v_old_hours <=> p_free_before_hours) AND v_old_pct = p_refund_percent
       AND BINARY v_old_terms = BINARY v_terms THEN
        ROLLBACK;
        SELECT 'unchanged' AS result, NULL AS field, v_version AS version;
        LEAVE proc;
    END IF;

    SET v_version = COALESCE(v_version, 0) + 1;
    INSERT INTO cancellation_policies (id, tour_id, free_before_hours, refund_percent, terms, version)
    VALUES (UUID(), p_tour_id, p_free_before_hours, p_refund_percent, v_terms, v_version);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'policy_add', NULL, NULL,
            LEFT(CONCAT('Chính sách hủy phiên bản ', v_version, ': ',
                        IF(p_free_before_hours IS NULL, 'không có mốc hủy miễn phí',
                           CONCAT('hủy miễn phí trước ', p_free_before_hours, ' giờ')),
                        ', hoàn ', p_refund_percent, '%'), 255), NOW());

    COMMIT;
    SELECT 'ok' AS result, NULL AS field, v_version AS version;
END$$
DELIMITER ;

-- =====================================================================
-- Xóa / ngừng hiển thị / khôi phục tour
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_delete(p_actor_user_id, p_tour_id)
--   Tour chưa có đơn: xóa hẳn tour và dữ liệu con (ảnh, lịch trình, bao gồm, phụ thu, chính
--   sách hủy, gói, lịch khởi hành và giá vé, bài viết, yêu thích, so sánh). admin_logs giữ lại
--   (action 'tour_delete', note = tên tour).
--   Tour đã có đơn: chuyển 'archived' (action 'tour_archive').
--   1 dòng: result, title, active_bookings.
--     result = 'deleted' | 'archived'
--              'forbidden'       : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found'       : không có tour này.
--              'already_archived': tour đã ngừng hiển thị.
--              'has_bookings'    : còn đơn pending / awaiting_payment / confirmed
--                                  (active_bookings = số đơn đó).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_delete(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_title    VARCHAR(300) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_bookings INT          DEFAULT 0;
    DECLARE v_active   INT          DEFAULT 0;
    DECLARE v_locked   INT          DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS title, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT title, approval_status INTO v_title, v_status
      FROM tours
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_title IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS title, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    IF v_status = 'archived' THEN
        ROLLBACK;
        SELECT 'already_archived' AS result, v_title AS title, 0 AS active_bookings;
        LEAVE proc;
    END IF;

    -- Khóa các lịch của tour: không có đơn mới được tạo trong lúc kiểm tra.
    SELECT COUNT(*) INTO v_locked
      FROM schedules s
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    SELECT COUNT(*), COALESCE(SUM(b.status IN ('pending', 'awaiting_payment', 'confirmed')), 0)
      INTO v_bookings, v_active
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    IF v_active > 0 THEN
        ROLLBACK;
        SELECT 'has_bookings' AS result, v_title AS title, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    IF v_bookings > 0 THEN
        UPDATE tours SET approval_status = 'archived' WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_archive', v_status, 'archived',
                LEFT(CONCAT('Ngừng hiển thị (tour đã có ', v_bookings, ' đơn)'), 255), NOW());

        COMMIT;
        SELECT 'archived' AS result, v_title AS title, 0 AS active_bookings;
        LEAVE proc;
    END IF;

    DELETE tt FROM ticket_types tt
      JOIN schedules s ON s.id = tt.schedule_id
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM schedules            WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_schedules       WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_images          WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM itinerary_stops      WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_itinerary_items WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_inclusions      WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_extras          WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM cancellation_policies WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_packages        WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tour_posts           WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM favorite_tours       WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM comparison_tours     WHERE tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM tours                WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_delete', v_status, NULL,
            LEFT(CONCAT('Xóa tour "', v_title, '"'), 255), NOW());

    COMMIT;
    SELECT 'deleted' AS result, v_title AS title, 0 AS active_bookings;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NMT_sp_admin_tour_restore(p_actor_user_id, p_tour_id)
--   Tour 'archived' -> 'pending' (chờ duyệt lại ở trang Duyệt tour). Ghi 'tour_restore'.
--   1 dòng: result ('ok', 'forbidden', 'not_found', 'invalid_transition').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_tour_restore;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_tour_restore(
    IN p_actor_user_id CHAR(36),
    IN p_tour_id       CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT approval_status INTO v_status
      FROM tours
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    IF v_status <> 'archived' THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result;
        LEAVE proc;
    END IF;

    UPDATE tours SET approval_status = 'pending' WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', p_tour_id, 'tour_restore', 'archived', 'pending',
            'Hiển thị lại: chờ duyệt', NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;


-- =====================================================================
-- Xóa đơn vị tổ chức
-- =====================================================================

-- ---------------------------------------------------------------------
-- NMT_sp_admin_provider_delete(p_actor_user_id, p_provider_id)
--   Chỉ xóa được đơn vị chưa có tour nào (kể cả tour chờ duyệt / ngừng hiển thị): xóa dòng
--   providers và tài khoản 'provider' không đăng nhập đi kèm. Tài khoản còn được bảng khác dùng
--   thì giữ lại ở trạng thái 'locked'. admin_logs giữ lại (action 'provider_delete').
--   Đơn vị còn tour: không xóa; muốn ẩn tour của đơn vị thì chuyển "Ngừng hợp tác" ('rejected').
--   1 dòng: result, business_name, tour_count.
--     result = 'deleted'
--              'forbidden' : người thao tác không phải quản trị viên đang hoạt động.
--              'not_found' : không có đơn vị này.
--              'has_tours' : đơn vị còn tour (tour_count = số tour).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NMT_sp_admin_provider_delete;

DELIMITER $$
CREATE PROCEDURE NMT_sp_admin_provider_delete(
    IN p_actor_user_id CHAR(36),
    IN p_provider_id   CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_name      VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_status    VARCHAR(20)  DEFAULT NULL;
    DECLARE v_user_id   CHAR(36)     DEFAULT NULL;
    DECLARE v_tours     INT          DEFAULT 0;
    DECLARE v_user_used BOOLEAN      DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- Tài khoản đi kèm còn được bảng khác tham chiếu (khóa ngoại RESTRICT): giữ lại, khóa tài khoản.
    DECLARE CONTINUE HANDLER FOR 1451 SET v_user_used = TRUE;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result, NULL AS business_name, NULL AS tour_count;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT business_name, approval_status, user_id INTO v_name, v_status, v_user_id
      FROM providers
     WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_name IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS business_name, NULL AS tour_count;
        LEAVE proc;
    END IF;

    -- Khóa các tour của đơn vị: không có tour mới được thêm trong lúc kiểm tra.
    SELECT COUNT(*) INTO v_tours
      FROM tours
     WHERE provider_id = (p_provider_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_tours > 0 THEN
        ROLLBACK;
        SELECT 'has_tours' AS result, v_name AS business_name, v_tours AS tour_count;
        LEAVE proc;
    END IF;

    DELETE FROM providers WHERE id = (p_provider_id COLLATE utf8mb4_unicode_ci);
    DELETE FROM users WHERE id = v_user_id AND role = 'provider';
    IF v_user_used THEN
        UPDATE users SET status = 'locked' WHERE id = v_user_id AND role = 'provider';
    END IF;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'provider', p_provider_id, 'provider_delete', v_status, NULL,
            LEFT(CONCAT('Xóa đơn vị "', v_name, '"'), 255), NOW());

    COMMIT;
    SELECT 'deleted' AS result, v_name AS business_name, 0 AS tour_count;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.5 - 22_payment_momo_NTK.sql
-- Mục đích  : Thêm MoMo (API v2, môi trường thử) làm phương thức thanh toán thứ ba bên cạnh
--             VNPay và VietQR cho đơn "Chờ thanh toán".
--   1. payments.method thêm 'momo'; booking_events.actor thêm 'momo' (kết quả MoMo).
--      Giữ nguyên các giá trị đang có của hai ENUM (kể cả giá trị file khác thêm vào).
--   2. NTK_sp_payment_momo_start : tạo khoản MoMo 'pending' mới cho đơn (như VNPay), trả
--      orderId gửi MoMo = reference + '-' + 10 ký tự đầu MD5(payment_id), vd.
--      LT518204P2-3f9a1c2b7d (orderId không trùng giữa các lần import lại database).
--   3. NTK_sp_payment_momo_result: ghi kết quả MoMo đã xác minh (trang trả về sau khi tra
--      cứu bằng API query có chữ ký, IPN, hoặc quản trị viên tra cứu). Idempotent như
--      LTP_sp_payment_vnpay_result: lần đầu ghi, các lần sau trả 'already'.
--   4. NTK_sp_admin_momo_queue   : khoản MoMo chưa rõ kết quả cho trang quản trị.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Quy tắc   : * Ứng dụng kiểm tra chữ ký MoMo (HMAC-SHA256) và tra cứu lại giao dịch TRƯỚC
--               khi gọi NTK_sp_payment_momo_result; procedure chỉ nhận kết quả đã xác minh.
--             * Số tiền MoMo báo phải bằng payments.amount_vnd, ngược lại không đổi gì.
--             * MoMo thành công khi đơn còn 'awaiting_payment' -> đơn 'confirmed', cấp voucher,
--               các khoản 'pending' khác -> 'failed'. Đơn đã hết hạn / đã hủy / đã thanh toán
--               bằng khoản khác -> khoản vẫn 'paid' và tạo yêu cầu hoàn tiền ('requested').
--             * Khoản bị hệ thống đóng ('failed', chưa có kết quả MoMo: response_code NULL)
--               vẫn nhận kết quả MoMo tới muộn.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Chạy sau  : 01 -> 21 (gọi LTP_sp_voucher_issue của file 15).
--             Chạy lại được (ENUM đã có 'momo' thì bỏ qua, DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. Thêm 'momo' vào payments.method và booking_events.actor.
--    Đọc ENUM hiện tại rồi nối thêm 'momo' (không ghi đè giá trị file khác đã thêm).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_migrate_momo;

DELIMITER $$
CREATE PROCEDURE NTK_sp_migrate_momo()
MODIFIES SQL DATA
BEGIN
    DECLARE v_type TEXT DEFAULT NULL;

    SELECT c.COLUMN_TYPE INTO v_type
      FROM information_schema.COLUMNS c
     WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = 'payments' AND c.COLUMN_NAME = 'method';
    IF v_type IS NOT NULL AND v_type NOT LIKE '%''momo''%' THEN
        SET @ntk_momo_sql = CONCAT('ALTER TABLE payments MODIFY COLUMN method ',
                                   LEFT(v_type, CHAR_LENGTH(v_type) - 1), ',''momo'') NOT NULL');
        PREPARE ntk_momo_stmt FROM @ntk_momo_sql;
        EXECUTE ntk_momo_stmt;
        DEALLOCATE PREPARE ntk_momo_stmt;
    END IF;

    SET v_type = NULL;
    SELECT c.COLUMN_TYPE INTO v_type
      FROM information_schema.COLUMNS c
     WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = 'booking_events' AND c.COLUMN_NAME = 'actor';
    IF v_type IS NOT NULL AND v_type NOT LIKE '%''momo''%' THEN
        SET @ntk_momo_sql = CONCAT('ALTER TABLE booking_events MODIFY COLUMN actor ',
                                   LEFT(v_type, CHAR_LENGTH(v_type) - 1), ',''momo'') NOT NULL');
        PREPARE ntk_momo_stmt FROM @ntk_momo_sql;
        EXECUTE ntk_momo_stmt;
        DEALLOCATE PREPARE ntk_momo_stmt;
    END IF;
END$$
DELIMITER ;

CALL NTK_sp_migrate_momo();
DROP PROCEDURE IF EXISTS NTK_sp_migrate_momo;

-- ---------------------------------------------------------------------
-- NTK_sp_payment_momo_start(p_user_id, p_code, p_min_vnd, p_max_vnd)
--   Bắt đầu thanh toán MoMo cho đơn p_code của tài khoản p_user_id: mỗi lần là một khoản
--   'pending' mới (orderId MoMo chỉ dùng được một lần). p_min_vnd / p_max_vnd: giới hạn số
--   tiền MoMo nhận (MomoGateway).
--   1 dòng: result, payment_id, reference, order_id, amount_vnd, expires_at.
--     result = 'ok'                      : khoản mới sẵn sàng gửi MoMo.
--              'not_found'               : không có đơn này trong tài khoản.
--              'not_payable'             : đơn không ở 'awaiting_payment' hoặc đã thanh toán.
--              'expired'                 : đã quá hạn giữ chỗ (đơn sẽ bị tự hủy).
--              'awaiting_reconciliation' : đã báo chuyển khoản VietQR, đang chờ đối chiếu.
--              'invalid_amount'          : tổng tiền ngoài giới hạn của MoMo.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_payment_momo_start;

DELIMITER $$
CREATE PROCEDURE NTK_sp_payment_momo_start(
    IN p_user_id CHAR(36),
    IN p_code    VARCHAR(20),
    IN p_min_vnd BIGINT,
    IN p_max_vnd BIGINT
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

    START TRANSACTION;

    SELECT b.id, b.code, b.status, b.total_vnd, b.hold_expires_at
      INTO v_booking_id, v_code, v_status, v_total, v_hold
      FROM bookings b
     WHERE b.user_id = (p_user_id COLLATE utf8mb4_unicode_ci)
       AND b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_status <> 'awaiting_payment'
       OR EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'paid') THEN
        ROLLBACK;
        SELECT 'not_payable' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = v_booking_id AND p.status = 'awaiting_reconciliation') THEN
        ROLLBACK;
        SELECT 'awaiting_reconciliation' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_hold IS NULL OR v_hold <= NOW() THEN
        ROLLBACK;
        SELECT 'expired' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, NULL AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    IF v_total IS NULL OR v_total < p_min_vnd OR v_total > p_max_vnd THEN
        ROLLBACK;
        SELECT 'invalid_amount' AS result, NULL AS payment_id, NULL AS reference, NULL AS order_id, v_total AS amount_vnd, NULL AS expires_at;
        LEAVE proc;
    END IF;

    SELECT COUNT(*) INTO v_count FROM payments p WHERE p.booking_id = v_booking_id;
    SET v_payment_id = UUID();
    SET v_reference = CONCAT(v_code, 'P', v_count + 1);

    INSERT INTO payments (id, booking_id, method, reference, provider_txn_id, amount_vnd, status,
                          expires_at, paid_at, created_at)
    VALUES (v_payment_id, v_booking_id, 'momo', v_reference, NULL, v_total, 'pending',
            v_hold, NULL, NOW());

    COMMIT;
    SELECT 'ok' AS result, v_payment_id AS payment_id, v_reference AS reference,
           CONCAT(v_reference, '-', LEFT(MD5(v_payment_id), 10)) AS order_id,
           v_total AS amount_vnd, v_hold AS expires_at;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_payment_momo_result(p_order_id, p_amount_vnd, p_result_code, p_trans_id,
--                            p_pay_type, p_source)
--   p_order_id   : orderId gửi MoMo (NTK_sp_payment_momo_start.order_id).
--   p_amount_vnd : số tiền MoMo báo; -1 = sai dạng.
--   p_result_code: resultCode của MoMo ('0' = thành công); p_trans_id: transId tại MoMo;
--   p_pay_type   : payType (napas, credit, qr, webApp...).
--   p_source     : 'return' (trang trả về), 'ipn', 'admin' (quản trị viên tra cứu),
--                  'create' (MoMo từ chối tạo giao dịch). Chỉ ghi vào lịch sử đơn.
--   1 dòng: result, booking_code, payment_status, booking_status.
--     result = 'ok'             : lần đầu khoản này thành 'paid' (đơn 'confirmed', hoặc đơn đã
--                                 hủy / hết hạn: tạo yêu cầu hoàn tiền).
--              'failed'         : lần đầu ghi kết quả không thành công.
--              'already'        : khoản đã có kết quả (trang trả về và IPN cùng báo).
--              'not_found'      : không có khoản MoMo với orderId này.
--              'invalid_amount' : số tiền MoMo báo khác số tiền của khoản; không đổi gì.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_payment_momo_result;

DELIMITER $$
CREATE PROCEDURE NTK_sp_payment_momo_result(
    IN p_order_id    VARCHAR(64),
    IN p_amount_vnd  BIGINT,
    IN p_result_code VARCHAR(10),
    IN p_trans_id    VARCHAR(100),
    IN p_pay_type    VARCHAR(20),
    IN p_source      VARCHAR(10)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_payment_id CHAR(36)    DEFAULT NULL;
    DECLARE v_booking_id CHAR(36)    DEFAULT NULL;
    DECLARE v_reference  VARCHAR(32) DEFAULT NULL;
    DECLARE v_amount     BIGINT      DEFAULT NULL;
    DECLARE v_pay_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_pay_code   VARCHAR(10) DEFAULT NULL;
    DECLARE v_code       VARCHAR(20) DEFAULT NULL;
    DECLARE v_status     VARCHAR(30) DEFAULT NULL;
    DECLARE v_order_id   VARCHAR(64) DEFAULT TRIM(p_order_id);
    DECLARE v_result     VARCHAR(10) DEFAULT COALESCE(NULLIF(TRIM(p_result_code), ''), '??');
    DECLARE v_trans_id   VARCHAR(100) DEFAULT NULLIF(NULLIF(TRIM(p_trans_id), ''), '0');
    DECLARE v_source     VARCHAR(40) CHARACTER SET utf8mb4 DEFAULT
        CASE p_source WHEN 'ipn' THEN 'qua IPN' WHEN 'admin' THEN 'quản trị viên tra cứu'
                      WHEN 'create' THEN 'lúc tạo giao dịch' ELSE 'qua trang trả về' END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT p.id, p.booking_id, p.reference, p.amount_vnd, p.status, p.response_code
      INTO v_payment_id, v_booking_id, v_reference, v_amount, v_pay_status, v_pay_code
      FROM payments p
     WHERE p.reference = (SUBSTRING_INDEX(v_order_id, '-', 1) COLLATE utf8mb4_unicode_ci)
       AND p.method = 'momo'
       FOR UPDATE;

    -- orderId phải đúng khoản này (không nhận orderId của lần import database trước).
    IF v_payment_id IS NULL
       OR BINARY CONCAT(v_reference, '-', LEFT(MD5(v_payment_id), 10)) <> BINARY v_order_id THEN
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

    -- Một sự kiện cho mỗi khoản: khoản đã có kết quả thì không tới được đây lần thứ hai.
    INSERT INTO payment_events (id, payment_id, provider_event_id, result_code, verified, received_at)
    VALUES (UUID(), v_payment_id, CONCAT('MOMO-', v_order_id), v_result, TRUE, NOW());

    IF v_result = '0' THEN
        UPDATE payments
           SET status = 'paid', paid_at = NOW(), provider_txn_id = v_trans_id,
               response_code = v_result, bank_code = NULLIF(TRIM(p_pay_type), '')
         WHERE id = v_payment_id;

        IF v_status = 'awaiting_payment' THEN
            UPDATE bookings SET status = 'confirmed', hold_expires_at = NULL WHERE id = v_booking_id;

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'momo', NULL, 'momo_paid', 'awaiting_payment', 'confirmed',
                    LEFT(CONCAT('Thanh toán MoMo thành công, mã giao dịch ', COALESCE(v_trans_id, v_reference),
                                ' (', v_source, ')'), 255), NOW());

            -- Các lần thanh toán khác chưa xong của đơn không dùng nữa.
            UPDATE payments
               SET status = 'failed', note = 'Đơn đã được thanh toán bằng khoản khác.'
             WHERE booking_id = v_booking_id
               AND id <> v_payment_id
               AND status = 'pending';

            CALL LTP_sp_voucher_issue(v_booking_id);
            SET v_status = 'confirmed';
        ELSE
            -- Tiền đã trừ nhưng đơn không còn chờ thanh toán: tạo yêu cầu hoàn tiền.
            INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at)
            VALUES (UUID(), v_payment_id, v_amount,
                    LEFT(CONCAT('Thanh toán MoMo ', v_reference, ' tới khi đơn đang "', v_status, '"; cần hoàn tiền cho khách.'), 255),
                    'requested', NOW());

            INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
            VALUES (UUID(), v_booking_id, 'momo', NULL, 'refund_requested', NULL, NULL,
                    CONCAT('Khoản MoMo ', v_reference, ' tới sau khi đơn không còn chờ thanh toán; đã tạo yêu cầu hoàn tiền.'), NOW());
        END IF;

        COMMIT;
        SELECT 'ok' AS result, v_code AS booking_code, 'paid' AS payment_status, v_status AS booking_status;
        LEAVE proc;
    END IF;

    UPDATE payments
       SET status = 'failed', provider_txn_id = v_trans_id,
           response_code = v_result, bank_code = NULLIF(TRIM(p_pay_type), '')
     WHERE id = v_payment_id;

    INSERT INTO booking_events (id, booking_id, actor, actor_user_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), v_booking_id, 'momo', NULL, 'momo_failed', NULL, NULL,
            LEFT(CONCAT('Thanh toán MoMo không thành công (mã ', v_result, ', ', v_source, ')'), 255), NOW());

    COMMIT;
    SELECT 'failed' AS result, v_code AS booking_code, 'failed' AS payment_status, v_status AS booking_status;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_momo_queue(p_booking_id, p_payment_id)
--   Khoản MoMo chưa rõ kết quả: MoMo chưa báo gì (không có payment_events, response_code
--   NULL), vì khách đóng trang MoMo, IPN không tới được (chạy ở localhost) hoặc lúc trả về
--   chưa tra cứu được. Gồm khoản 'pending' đã quá 15 phút (hết hạn đơn MoMo, MomoGateway) và
--   khoản bị hệ thống đóng 'failed' khi đơn không được thanh toán bằng khoản khác.
--   Quản trị viên bấm "Tra cứu MoMo": ứng dụng gọi API query rồi ghi qua
--   NTK_sp_payment_momo_result.
--   p_booking_id / p_payment_id: NULL = không lọc. Tối đa 200 dòng, tạo trước lên trước.
--   Cột: payment_id, reference, order_id, amount_vnd, status, created_at, booking_id, code,
--   booking_status, hold_expires_at, contact_name, contact_phone, tour_title, starts_at.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_momo_queue;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_momo_queue(
    IN p_booking_id CHAR(36),
    IN p_payment_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id            AS payment_id,
        p.reference,
        CONCAT(p.reference, '-', LEFT(MD5(p.id), 10)) AS order_id,
        p.amount_vnd,
        p.status,
        p.created_at,
        b.id            AS booking_id,
        b.code,
        b.status        AS booking_status,
        b.hold_expires_at,
        b.contact_name,
        b.contact_phone,
        t.title         AS tour_title,
        s.starts_at
    FROM payments p
    JOIN bookings b  ON b.id = p.booking_id
    JOIN schedules s ON s.id = b.schedule_id
    JOIN tours t     ON t.id = s.tour_id
    WHERE p.method = 'momo'
      AND p.reference IS NOT NULL
      AND p.response_code IS NULL
      AND NOT EXISTS (SELECT 1 FROM payment_events e WHERE e.payment_id = p.id)
      AND ((p.status = 'pending' AND p.created_at <= NOW() - INTERVAL 15 MINUTE)
           OR (p.status = 'failed' AND b.status NOT IN ('confirmed', 'completed')))
      AND (p_booking_id IS NULL OR b.id = (p_booking_id COLLATE utf8mb4_unicode_ci))
      AND (p_payment_id IS NULL OR p.id = (p_payment_id COLLATE utf8mb4_unicode_ci))
    ORDER BY p.created_at, p.id
    LIMIT 200;
END$$
DELIMITER ;
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
-- =====================================================================
-- LocalTour v0.5 - 24_social_login_NTK.sql
-- Mục đích  : Đăng nhập bằng Google / Facebook cho tài khoản khách hàng (OAuth 2.0).
--   1. Bảng user_social_accounts: liên kết một tài khoản Google / Facebook (mã người dùng
--      do nhà cung cấp cấp) với một tài khoản LocalTour. Mỗi tài khoản Google / Facebook
--      chỉ gắn với một tài khoản LocalTour (UNIQUE provider + provider_user_id); một tài
--      khoản LocalTour có thể gắn cả Google lẫn Facebook. Xóa tài khoản thì xóa liên kết.
--   2. Procedure NTK_sp_social_login: tìm / liên kết / tạo tài khoản trong một transaction.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - Sprint 6
-- Procedures: NTK_sp_social_login
-- Quy tắc   : Ứng dụng đã đổi mã xác thực lấy thông tin tài khoản với Google / Facebook và
--             kiểm tra email (Google: email đã xác minh) trước khi gọi procedure.
--             Tài khoản tạo bằng Google / Facebook có password_hash NULL: chỉ đăng nhập lại
--             bằng Google / Facebook, không đăng nhập bằng mật khẩu được.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01_schema.sql. Chạy lại được (CREATE TABLE IF NOT EXISTS, DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. user_social_accounts
--   provider_user_id: mã người dùng của nhà cung cấp (Google "sub", Facebook "id").
--   email: email nhà cung cấp trả về ở lần đăng nhập gần nhất (chỉ để tra cứu).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_social_accounts (
    id               CHAR(36)      NOT NULL,
    user_id          CHAR(36)      NOT NULL,
    provider         ENUM('google','facebook') NOT NULL,
    provider_user_id VARCHAR(255)  NOT NULL,
    email            VARCHAR(150)  NULL,
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_social_accounts_provider_user (provider, provider_user_id),
    KEY idx_social_accounts_user (user_id),
    CONSTRAINT fk_social_accounts_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. NTK_sp_social_login(p_provider, p_provider_user_id, p_email, p_name)
--   p_provider: 'google' / 'facebook'. p_email: email đã kiểm tra định dạng. p_name: tên
--   hiển thị (NULL / '' = lấy phần trước @ của email).
--   Thứ tự xử lý (một transaction, khóa dòng FOR UPDATE):
--     a. Đã có liên kết (provider, provider_user_id) -> tài khoản đã liên kết.
--     b. Chưa có liên kết, đã có tài khoản cùng email -> liên kết vào tài khoản đó.
--     c. Chưa có tài khoản -> tạo tài khoản khách hàng (password_hash NULL) và liên kết.
--     Tài khoản ở a / b không phải 'customer' -> 'not_customer' (không liên kết, không
--     đăng nhập); đang bị khóa -> 'locked'.
--   1 dòng, cột: result, user_id, name, email, role.
--     result 'existing' / 'linked' / 'created': đăng nhập được, các cột còn lại là tài khoản.
--     result 'not_customer' / 'locked' / 'invalid' (thiếu dữ liệu) / 'retry' (hai lần đăng
--     nhập cùng lúc tạo trùng, thử lại): các cột còn lại NULL.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_social_login;

DELIMITER $$
CREATE PROCEDURE NTK_sp_social_login(
    IN p_provider         VARCHAR(20),
    IN p_provider_user_id VARCHAR(255),
    IN p_email            VARCHAR(150),
    IN p_name             VARCHAR(100) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_provider VARCHAR(20)  CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(COALESCE(p_provider, '')));
    DECLARE v_subject  VARCHAR(255) CHARACTER SET utf8mb4 DEFAULT TRIM(COALESCE(p_provider_user_id, ''));
    DECLARE v_email    VARCHAR(150) CHARACTER SET utf8mb4 DEFAULT LOWER(TRIM(COALESCE(p_email, '')));
    DECLARE v_name     VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULLIF(TRIM(p_name), '');
    DECLARE v_user_id  CHAR(36)     DEFAULT NULL;
    DECLARE v_role     VARCHAR(20)  DEFAULT NULL;
    DECLARE v_status   VARCHAR(20)  DEFAULT NULL;
    DECLARE v_result   VARCHAR(20)  DEFAULT NULL;
    -- 1062 = trùng khóa UNIQUE: lần đăng nhập khác vừa tạo cùng tài khoản / liên kết.
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SELECT 'retry' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
    END;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF v_provider NOT IN ('google', 'facebook') OR v_subject = '' OR v_email = '' THEN
        SELECT 'invalid' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- a. Đã liên kết.
    SELECT u.id, u.role, u.status
      INTO v_user_id, v_role, v_status
      FROM user_social_accounts s
      JOIN users u ON u.id = s.user_id
     WHERE s.provider = (v_provider COLLATE utf8mb4_unicode_ci)
       AND s.provider_user_id = (v_subject COLLATE utf8mb4_unicode_ci)
     LIMIT 1
       FOR UPDATE;

    IF v_user_id IS NOT NULL THEN
        SET v_result = 'existing';
    ELSE
        -- b. Tài khoản cùng email.
        SELECT u.id, u.role, u.status
          INTO v_user_id, v_role, v_status
          FROM users u
         WHERE u.email = (v_email COLLATE utf8mb4_unicode_ci)
         LIMIT 1
           FOR UPDATE;

        IF v_user_id IS NOT NULL THEN
            SET v_result = 'linked';
        ELSE
            -- c. Tài khoản khách hàng mới, chưa có mật khẩu.
            SET v_user_id = UUID();
            SET v_role = 'customer';
            SET v_status = 'active';
            SET v_result = 'created';
            INSERT INTO users (id, email, password_hash, name, phone, role, status)
            VALUES (v_user_id, v_email, NULL, COALESCE(v_name, SUBSTRING_INDEX(v_email, '@', 1)),
                    NULL, 'customer', 'active');
        END IF;
    END IF;

    IF v_role <> 'customer' THEN
        ROLLBACK;
        SELECT 'not_customer' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
        LEAVE proc;
    END IF;

    IF v_status <> 'active' THEN
        ROLLBACK;
        SELECT 'locked' AS result, NULL AS user_id, NULL AS name, NULL AS email, NULL AS role;
        LEAVE proc;
    END IF;

    IF v_result = 'existing' THEN
        UPDATE user_social_accounts
           SET email = v_email
         WHERE provider = (v_provider COLLATE utf8mb4_unicode_ci)
           AND provider_user_id = (v_subject COLLATE utf8mb4_unicode_ci);
    ELSE
        INSERT INTO user_social_accounts (id, user_id, provider, provider_user_id, email)
        VALUES (UUID(), v_user_id, v_provider, v_subject, v_email);
    END IF;

    COMMIT;

    SELECT v_result AS result, u.id AS user_id, u.name, u.email, u.role
      FROM users u
     WHERE u.id = v_user_id;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour - 25_email_NTK.sql
-- Mục đích  : Email "Đặt tour thành công" gửi cho khách khi đơn chuyển sang "Đã xác nhận"
--             (VNPay, đối chiếu VietQR, quản trị viên xác nhận, ...). Thêm:
--   1. Bảng email_logs: nhật ký mỗi lượt gửi email của đơn (người nhận, kết quả, lỗi).
--      Mỗi đơn có tối đa một email loại 'booking_confirmed' gửi thành công ('sent'):
--      Return URL và IPN của VNPay, hay quản trị viên bấm lại, không làm khách nhận hai email.
--   2. Procedure: NTK_sp_email_booking_get, NTK_sp_email_log_start,
--      NTK_sp_email_log_finish, NTK_sp_email_log_latest.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Quy tắc   : status của email_logs:
--               sending : đang gửi (giữ lượt trước khi kết nối SMTP, chống hai yêu cầu cùng
--                         gửi một lúc); quá 2 phút vẫn 'sending' = lượt bị ngắt, coi như lỗi.
--               sent    : máy chủ SMTP đã nhận email.
--               failed  : gửi lỗi (error ghi lỗi SMTP / mạng); lần xác nhận sau gửi lại được.
--               skipped : không gửi (chưa cấu hình MAIL_HOST, đơn không còn "Đã xác nhận"...).
--             Dữ liệu trong email đọc bằng procedure có sẵn của trang "Đơn của tôi"
--             (NTK_sp_customer_booking_detail, NTK_sp_customer_booking_line_list,
--             NMT_sp_payment_list); NTK_sp_email_booking_get chỉ tìm tài khoản của đơn.
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci; không có DEFINER.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01 -> 21. Chạy lại được: bảng đã có thì giữ nguyên dữ liệu, procedure tạo lại.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. email_logs
--   kind       : loại email, hiện có 'booking_confirmed' (Đặt tour thành công).
--   to_email   : địa chỉ nhận (bookings.contact_email lúc gửi).
--   error      : lỗi khi 'failed' / lý do khi 'skipped' (NULL khi 'sent').
--   message_id : Message-ID của email đã gửi.
--   finished_at: lúc có kết quả (NULL khi còn 'sending').
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS email_logs (
    id          CHAR(36)      NOT NULL,
    booking_id  CHAR(36)      NOT NULL,
    kind        VARCHAR(30)   NOT NULL,
    to_email    VARCHAR(150)  NOT NULL,
    status      ENUM('sending','sent','failed','skipped') NOT NULL DEFAULT 'sending',
    error       VARCHAR(1000) NULL,
    message_id  VARCHAR(200)  NULL,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME      NULL,
    PRIMARY KEY (id),
    KEY idx_email_logs_booking (booking_id, kind, status),
    KEY idx_email_logs_created (created_at),
    CONSTRAINT fk_email_logs_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Import lại 01_schema.sql tạo lại bảng bookings nhưng không xóa email_logs: bỏ nhật ký của
-- đơn không còn tồn tại.
DELETE FROM email_logs
 WHERE NOT EXISTS (SELECT 1 FROM bookings b WHERE b.id = email_logs.booking_id);

-- ---------------------------------------------------------------------
-- NTK_sp_email_booking_get(p_booking_id, p_code)
--   Tìm đơn cần gửi email theo booking_id (trang quản trị) hoặc theo mã đơn (VNPay, MoMo);
--   truyền một trong hai, giá trị còn lại NULL.
--   0 hoặc 1 dòng: booking_id, code, user_id, status, contact_name, contact_email.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_booking_get;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_booking_get(
    IN p_booking_id CHAR(36),
    IN p_code       VARCHAR(20)
)
READS SQL DATA
BEGIN
    IF NULLIF(TRIM(p_booking_id), '') IS NOT NULL THEN
        SELECT b.id AS booking_id, b.code, b.user_id, b.status, b.contact_name, b.contact_email
          FROM bookings b
         WHERE b.id = (TRIM(p_booking_id) COLLATE utf8mb4_unicode_ci);
    ELSE
        SELECT b.id AS booking_id, b.code, b.user_id, b.status, b.contact_name, b.contact_email
          FROM bookings b
         WHERE b.code = (UPPER(TRIM(p_code)) COLLATE utf8mb4_unicode_ci);
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_log_start(p_booking_id, p_kind, p_to_email)
--   Giữ lượt gửi email loại p_kind của đơn trước khi kết nối SMTP. Khóa dòng của đơn nên hai
--   yêu cầu tới cùng lúc (vd. Return URL và IPN) chạy lần lượt.
--   1 dòng: result, email_log_id.
--     result = 'ok'        : đã thêm dòng 'sending' (email_log_id); ứng dụng gửi rồi gọi
--                            NTK_sp_email_log_finish.
--              'duplicate' : đơn đã có email loại này gửi thành công; không gửi lại.
--              'busy'      : đang có lượt gửi khác của đơn (dòng 'sending' chưa quá 2 phút).
--              'not_found' : không có đơn.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_log_start;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_log_start(
    IN p_booking_id CHAR(36),
    IN p_kind       VARCHAR(30),
    IN p_to_email   VARCHAR(150) CHARACTER SET utf8mb4
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_booking_id CHAR(36) DEFAULT NULL;
    DECLARE v_log_id     CHAR(36) DEFAULT UUID();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT b.id INTO v_booking_id
      FROM bookings b
     WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_booking_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS email_log_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM email_logs l
                WHERE l.booking_id = v_booking_id
                  AND l.kind = (p_kind COLLATE utf8mb4_unicode_ci)
                  AND l.status = 'sent') THEN
        ROLLBACK;
        SELECT 'duplicate' AS result, NULL AS email_log_id;
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM email_logs l
                WHERE l.booking_id = v_booking_id
                  AND l.kind = (p_kind COLLATE utf8mb4_unicode_ci)
                  AND l.status = 'sending'
                  AND l.created_at > NOW() - INTERVAL 2 MINUTE) THEN
        ROLLBACK;
        SELECT 'busy' AS result, NULL AS email_log_id;
        LEAVE proc;
    END IF;

    -- Lượt cũ quá 2 phút chưa có kết quả (tiến trình PHP bị ngắt): ghi lỗi rồi cho gửi lại.
    UPDATE email_logs
       SET status = 'failed', error = 'Lượt gửi bị ngắt giữa chừng (quá 2 phút chưa có kết quả).', finished_at = NOW()
     WHERE booking_id = v_booking_id
       AND kind = (p_kind COLLATE utf8mb4_unicode_ci)
       AND status = 'sending';

    INSERT INTO email_logs (id, booking_id, kind, to_email, status, created_at)
    VALUES (v_log_id, v_booking_id, p_kind, LEFT(COALESCE(p_to_email, ''), 150), 'sending', NOW());

    COMMIT;
    SELECT 'ok' AS result, v_log_id AS email_log_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_log_finish(p_email_log_id, p_status, p_error, p_message_id)
--   Ghi kết quả của lượt gửi do NTK_sp_email_log_start tạo (chỉ đổi dòng còn 'sending').
--   p_status = 'sent' | 'failed' | 'skipped'; p_error: lỗi / lý do (bỏ qua khi 'sent').
--   1 dòng: result = 'ok' | 'invalid' (p_status sai) | 'not_found' (không có dòng 'sending').
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_log_finish;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_log_finish(
    IN p_email_log_id CHAR(36),
    IN p_status       VARCHAR(10),
    IN p_error        VARCHAR(1000) CHARACTER SET utf8mb4,
    IN p_message_id   VARCHAR(200)
)
MODIFIES SQL DATA
proc: BEGIN
    IF p_status IS NULL OR p_status NOT IN ('sent', 'failed', 'skipped') THEN
        SELECT 'invalid' AS result;
        LEAVE proc;
    END IF;

    UPDATE email_logs
       SET status = p_status,
           error = IF(p_status = 'sent', NULL, LEFT(NULLIF(TRIM(p_error), ''), 1000)),
           message_id = IF(p_status = 'sent', LEFT(NULLIF(TRIM(p_message_id), ''), 200), NULL),
           finished_at = NOW()
     WHERE id = (p_email_log_id COLLATE utf8mb4_unicode_ci)
       AND status = 'sending';

    SELECT IF(ROW_COUNT() > 0, 'ok', 'not_found') AS result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_email_log_latest(p_booking_id, p_kind)
--   Tình trạng email loại p_kind của đơn cho trang quản trị: lượt gửi thành công nếu có,
--   ngược lại lượt mới nhất.
--   0 hoặc 1 dòng: email_log_id, to_email, status, error, created_at, finished_at,
--   attempts (số lượt đã ghi của loại email này).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_email_log_latest;

DELIMITER $$
CREATE PROCEDURE NTK_sp_email_log_latest(
    IN p_booking_id CHAR(36),
    IN p_kind       VARCHAR(30)
)
READS SQL DATA
BEGIN
    SELECT
        l.id          AS email_log_id,
        l.to_email,
        l.status,
        l.error,
        l.created_at,
        l.finished_at,
        (SELECT COUNT(*)
           FROM email_logs x
          WHERE x.booking_id = l.booking_id
            AND x.kind = l.kind) AS attempts
    FROM email_logs l
    WHERE l.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
      AND l.kind = (p_kind COLLATE utf8mb4_unicode_ci)
    ORDER BY l.status = 'sent' DESC, l.created_at DESC, l.id DESC
    LIMIT 1;
END$$
DELIMITER ;
