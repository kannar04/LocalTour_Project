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
