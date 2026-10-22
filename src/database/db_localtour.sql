-- File sinh tự động từ src/database/01..05, không sửa tay.
CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_localtour;
SET NAMES utf8mb4;
-- =====================================================================
-- LocalTour v0.1 - 01_schema.sql
-- Mục đích  : Tạo lược đồ CSDL db_localtour: lược đồ GỘP giữa ERD (trang 01 "Lõi đặt
--             tour" + trang 02 "Khám phá & vận hành") và bảng yêu cầu chức năng (FR
--             board), tổng 17 bảng. Mỗi bảng / cột thêm mới có ghi chú FR mà nó phục vụ.
--
-- ĐÃ BỎ 7 bảng của ERD trang 02: notifications, tour_posts, post_comments,
--   post_interactions, favorite_tours, comparisons, comparison_tours.
--   * Bài đăng / thích / bình luận / lưu tour / thông báo đều cần tài khoản khách hàng;
--     FR board xếp tài khoản khách vào "Won't Have" và không có FR nào cho các chức năng này.
--   * FR-15 (so sánh tour) chỉ diễn ra trong phiên duyệt web; ghi chú trên ERD trang 02
--     nói bỏ 2 bảng so sánh trong trường hợp đó.
--   Vẫn giữ DROP TABLE IF EXISTS cho 7 bảng này để import đè lên bản cũ không lỗi.
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
--             * Khách hàng vẫn là tác nhân nghiệp vụ nhưng KHÔNG có tài khoản (FR board).
--               Mỗi booking lưu ảnh chụp thông tin người đặt tại contact_name,
--               contact_email, contact_phone; hành khách nằm trong passengers.
--             * Khách tra cứu booking bằng code + contact_email / contact_phone. Sau khi
--               nhân viên xác nhận chỗ và tổng tiền, payment liên kết trực tiếp với booking
--               qua payments.booking_id; vì vậy thanh toán không cần customer_id hay đăng nhập.
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

-- Bảng của lược đồ hiện tại (17 bảng)
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

-- 7 bảng đã bỏ khỏi ERD trang 02 (lý do ở đầu file)
DROP TABLE IF EXISTS comparison_tours;
DROP TABLE IF EXISTS comparisons;
DROP TABLE IF EXISTS post_interactions;
DROP TABLE IF EXISTS post_comments;
DROP TABLE IF EXISTS tour_posts;
DROP TABLE IF EXISTS favorite_tours;
DROP TABLE IF EXISTS notifications;

-- Bảng của thiết kế cũ (trước ERD): xóa để không sót dữ liệu cũ
DROP TABLE IF EXISTS tour_itinerary_items;
DROP TABLE IF EXISTS tour_inclusions;
DROP TABLE IF EXISTS tour_schedules;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS destinations;

SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;

-- ---------------------------------------------------------------------
-- 2. TÀI KHOẢN NHÂN VIÊN & NHÀ CUNG CẤP
-- ---------------------------------------------------------------------

-- NGƯỜI_DÙNG (FR-13, NFR-04): chỉ tài khoản của nhân viên và nhà cung cấp.
-- role: admin = Quản trị viên, support = Nhân viên hỗ trợ khách hàng,
--       provider = tài khoản của nhà cung cấp (đơn vị tổ chức tour).
--       Không có vai trò khách hàng: khách đặt tour không cần tài khoản.
-- password_hash NULL = chưa đặt mật khẩu (Sprint 3 chưa có đăng nhập).
-- status = 'locked': tài khoản bị khóa; nếu là nhà cung cấp thì mọi tour bị ẩn (FR-01).
CREATE TABLE users (
    id            CHAR(36)      NOT NULL,
    email         VARCHAR(150)  NOT NULL,
    password_hash VARCHAR(255)  NULL,
    name          VARCHAR(100)  NOT NULL,
    phone         VARCHAR(20)   NULL,
    role          ENUM('admin','support','provider') NOT NULL,
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
-- 3. TOUR & NỘI DUNG TOUR
-- ---------------------------------------------------------------------

-- TOUR (FR-01 danh mục, FR-02 chi tiết, FR-06 tìm theo tên / điểm đến).
-- destination là tên điểm đến dạng chữ (vd. 'Hà Nội').
-- language_codes: mã ngôn ngữ cách nhau bởi dấu phẩy (vd. 'vi,en').
-- pickup_mode = 'meeting_point': khách tự đến meeting_point;
--             = 'hotel_pickup' : đón tại khách sạn, meeting_point mô tả khu vực đón.
-- included_summary / excluded_summary: mỗi mục một dòng (ký tự xuống dòng).
-- Các cột thêm từ transport trở đi: NULL = chưa cập nhật.
-- Chỉ tour approval_status = 'approved' mới được hiển thị.
CREATE TABLE tours (
    id                  CHAR(36)      NOT NULL,
    provider_id         CHAR(36)      NOT NULL,
    title               VARCHAR(200)  NOT NULL,
    description         TEXT          NOT NULL,
    destination         VARCHAR(100)  NOT NULL,
    duration_minutes    INT           NOT NULL,
    max_group_size      INT           NOT NULL,
    language_codes      VARCHAR(50)   NOT NULL,
    pickup_mode         ENUM('meeting_point','hotel_pickup') NOT NULL,
    meeting_point       VARCHAR(255)  NULL,
    included_summary    TEXT          NOT NULL,      -- FR-04 đã bao gồm
    transport           VARCHAR(255)  NULL,          -- FR-02 phương tiện
    guide_info          VARCHAR(255)  NULL,          -- FR-02 hướng dẫn viên
    dropoff_point       VARCHAR(255)  NULL,          -- FR-02 điểm trả khách
    excluded_summary    TEXT          NULL,          -- FR-04 không bao gồm (mỗi mục một dòng)
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
    CONSTRAINT fk_tours_provider FOREIGN KEY (provider_id)
        REFERENCES providers (id) ON DELETE RESTRICT ON UPDATE CASCADE
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

-- ĐIỂM_LỊCH_TRÌNH (FR-03): các chặng của tour theo thứ tự stop_order (1, 2, 3, ...).
-- description / duration_minutes NULL = chưa cập nhật (FR-03: chỉ hiện giờ khi có ghi).
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

-- ---------------------------------------------------------------------
-- 4. LỊCH KHỞI HÀNH, VÉ & CHÍNH SÁCH
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
-- 5. KHÁCH HÀNG KHÔNG TÀI KHOẢN & ĐẶT CHỖ
-- ---------------------------------------------------------------------

-- ĐƠN_ĐẶT_TOUR (FR-08 yêu cầu đặt tour, FR-11 mã và trạng thái, FR-09 thông tin liên hệ).
-- Mỗi dòng bookings đại diện cho một giao dịch của khách hàng theo mô hình guest checkout.
-- contact_* là ảnh chụp thông tin người đặt tại thời điểm gửi yêu cầu, không phải tài khoản;
-- cùng một người đặt nhiều lần có thể xuất hiện ở nhiều booking mà không bị gộp hồ sơ.
-- Khách tra cứu đúng đơn bằng code + contact_email / contact_phone.
-- code: mã đơn đưa cho khách (vd. 'LT123456').
-- status: pending = Chờ xác nhận, awaiting_payment = Chờ thanh toán,
--         confirmed = Đã xác nhận, rejected = Từ chối, cancelled = Đã hủy,
--         completed = Đã hoàn thành (chỉ đơn completed mới được đánh giá).
-- total_vnd = tổng line_total_vnd của các dòng đơn (không gồm tour_extras).
-- policy_version: phiên bản chính sách hủy của tour tại thời điểm đặt.
-- hold_expires_at: hạn giữ chỗ khi đơn đang chờ thanh toán (NULL = không giữ chỗ).
CREATE TABLE bookings (
    id              CHAR(36)      NOT NULL,
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
    PRIMARY KEY (id),
    UNIQUE KEY uq_bookings_code (code),
    KEY idx_bookings_schedule (schedule_id),
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
-- 6. GIAO DỊCH
-- ---------------------------------------------------------------------

-- THANH_TOÁN (FR-17 thanh toán trực tuyến): khách hàng được xác định qua booking_id;
-- JOIN payments -> bookings lấy được mã đơn và contact_name/contact_email/contact_phone,
-- nên không cần bảng customers hoặc khóa ngoại tới users.
-- Chỉ tạo thanh toán sau khi booking được nhân viên xác nhận và chuyển sang
-- status = 'awaiting_payment'; quy tắc chuyển trạng thái được kiểm tra ở tầng ứng dụng.
-- method chỉ có 'vnpay' hoặc 'vietqr' (FR board không có hình thức trả sau / trả tại điểm hẹn).
-- provider_txn_id: mã giao dịch phía cổng VNPay / VietQR (NULL khi chưa tạo giao dịch).
-- status: pending = Chưa thanh toán, processing = Đang xử lý,
--         awaiting_reconciliation = Chờ đối chiếu, paid = Thành công, failed = Thất bại.
--         Luồng VietQR kết thúc ở 'awaiting_reconciliation' (chờ nhân viên đối chiếu)
--         hoặc 'paid'.
--         Không có trạng thái "đã hoàn tiền": tiền hoàn được ghi ở bảng refunds.
CREATE TABLE payments (
    id              CHAR(36)      NOT NULL,
    booking_id      CHAR(36)      NOT NULL,
    method          ENUM('vnpay','vietqr') NOT NULL,   -- FR-17: chỉ 2 cổng thanh toán trực tuyến
    provider_txn_id VARCHAR(100)  NULL,
    amount_vnd      BIGINT        NOT NULL,
    status          ENUM('pending','processing','awaiting_reconciliation','paid','failed')
                    NOT NULL DEFAULT 'pending',
    expires_at      DATETIME      NULL,
    PRIMARY KEY (id),
    KEY idx_payments_booking (booking_id),
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
-- 7. ĐÁNH GIÁ
-- ---------------------------------------------------------------------

-- ĐÁNH_GIÁ (FR-16): mỗi đơn đặt được đánh giá tối đa một lần (booking_id UNIQUE),
-- nên người đánh giá đã được xác thực qua đơn; tên hiển thị = bookings.contact_name.
-- rating từ 1 đến 5. Chỉ đánh giá moderation_status = 'approved' mới được
-- hiển thị và tính vào điểm trung bình.
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
-- 8. NHẬT KÝ
-- ---------------------------------------------------------------------

-- NHẬT_KÝ_QUẢN_TRỊ (NFR-09 lịch sử xử lý): thao tác của nhân viên (vd. duyệt tour,
-- đổi trạng thái đơn, khóa tài khoản). target_type + target_id: đối tượng bị tác
-- động (vd. 'tour' + UUID của tour); không có khóa ngoại vì đối tượng có thể nằm ở
-- nhiều bảng khác nhau. Sprint 3 để trống.
CREATE TABLE admin_logs (
    id            CHAR(36)     NOT NULL,
    actor_user_id CHAR(36)     NOT NULL,
    target_type   VARCHAR(50)  NOT NULL,
    target_id     VARCHAR(36)  NOT NULL,
    action        VARCHAR(50)  NOT NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_admin_logs_actor (actor_user_id),
    CONSTRAINT fk_admin_logs_actor FOREIGN KEY (actor_user_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- =====================================================================
-- LocalTour v0.1 - 02_seed.sql
-- Mục đích  : Nạp dữ liệu mẫu để kiểm thử trang danh sách và trang chi tiết tour
--             cho lược đồ gộp 17 bảng (01_schema.sql). Bảng admin_logs để trống.
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.2
-- Dữ liệu   : TẤT CẢ dữ liệu (tài khoản, nhà cung cấp, tour, giá, lịch, đơn đặt,
--             thanh toán, đánh giá) là dữ liệu MINH HỌA, không phải thông tin thật
--             của bất kỳ người hay đơn vị nào:
--               * email dùng tên miền @localtour.test (không tồn tại);
--               * số điện thoại là số giả dạng 0000000xxx; users.phone để NULL;
--               * password_hash NULL (Sprint 3 chưa có đăng nhập);
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
--   tour_images 80000000 · itinerary_stops 90000000 · tour_extras c1000000
--   Tour N = c0000000-0000-4000-8000-00000000000N; tour 1 = "Hà Nội qua những món ăn phố cổ".
-- Cách đánh số:
--   users        : 1 = quản trị viên; 2 = nhân viên hỗ trợ khách hàng;
--                  11-17 = tài khoản của nhà cung cấp 1-7. Khách KHÔNG có tài khoản
--                  (FR board: Won't Have); đơn đặt chỉ lưu thông tin liên hệ.
--   schedules    : 1-37 = lịch của các tour; 101-128 = lịch đã đi của đơn có đánh giá
--                  (lịch 100 + N thuộc đơn N).
--   ticket_types : số lịch x 10 + 1 = người lớn, + 2 = trẻ em (vd. lịch 3 -> 31, 32).
--   bookings     : 1-28 = đơn có đánh giá đã duyệt (đơn N <-> đánh giá N);
--                  29 = đơn có đánh giá đang chờ duyệt; 30 = đơn đã hủy.
--   booking_lines, passengers: số đơn x 10 + thứ tự. payments: trùng số đơn.
--   tour_images, itinerary_stops, tour_extras: đánh số theo thứ tự chèn, cố ý lệch
--                  với thứ tự hiển thị để kiểm tra ORDER BY.
--
-- Ca kiểm thử có sẵn trong dữ liệu:
--   * Tour 1-9 hiển thị. Tour 10 approval_status = 'pending': KHÔNG BAO GIỜ hiển thị,
--     dù có lịch mở và 3 đánh giá 5 sao (nếu bị lộ sẽ đứng đầu tab "Nổi bật").
--   * Tour 9: chưa có đánh giá, không có lịch đặt được (chỉ 1 lịch đã hủy) -> giá NULL;
--     không có ảnh và lịch trình -> giao diện hiện "Chưa cập nhật".
--   * Tour 10 có ảnh và lịch trình riêng: không bao giờ được trả về.
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
--   * Lịch trình: tour 1-8 có 4-5 chặng chèn lệch thứ tự; một số chặng không có mô tả
--     hoặc thời lượng (NULL).
--   * Thông tin tour (FR-02/04/05): tour 9 chưa cập nhật cả 8 trường; tour 3 thiếu
--     dropoff_point, voucher_terms; tour 5 thiếu excluded_summary; tour 7 thiếu guide_info,
--     reschedule_terms. Các trường thiếu -> giao diện hiện "Chưa cập nhật".
--   * Phụ thu / tùy chọn (tour_extras): 0-3 dòng mỗi tour; tour 2 và tour 9 không có.
--     Có dòng thiếu giá, thiếu đơn vị hoặc thiếu điều kiện (NULL). Tour 10 có 2 dòng.
--   * Điểm TB (chỉ đánh giá 'approved'): tour 3 = 5,0; tour 1, 6 = 4,8; tour 2, 7 = 4,7;
--     tour 4, 8 = 4,5; tour 5 = 4,3; tour 9 chưa có.
--   * Giá "Từ" = vé người lớn rẻ nhất trong các lịch đặt được (nghìn đồng):
--     tour 1: 650, tour 2: 720, tour 3: 900, tour 4: 550, tour 5: 480,
--     tour 6: 590, tour 7: 750, tour 8: 850, tour 9: NULL.
--
-- Số dòng: users 9, providers 7, tours 10, cancellation_policies 11, schedules 65,
--          ticket_types 118, bookings 30, booking_lines 35, passengers 60,
--          payments 30, payment_events 30, refunds 1, reviews 29,
--          tour_images 12, itinerary_stops 43, tour_extras 15,
--          admin_logs 0 (để trống).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. users (NGƯỜI_DÙNG)
--   Chỉ tài khoản nhân viên và nhà cung cấp; khách đặt tour không có tài khoản.
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
('a0000000-0000-4000-8000-000000000017', 'cholonkechuyen@localtour.test', NULL, 'Chợ Lớn Kể Chuyện', NULL, 'provider', 'active');

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
-- 3. tours (TOUR)
--   description = tóm tắt + dòng trống + mô tả. Lịch trình nằm ở bảng itinerary_stops (mục 15).
--   included_summary: mỗi mục đã gồm trong giá một dòng. CHAR(10) = ký tự xuống dòng.
--   excluded_summary: mục không bao gồm, mỗi mục một dòng. NULL = chưa cập nhật.
--   NFR-07: source_url, verified_at NULL và verification_status 'unverified' cho mọi tour.
--   Tour 10: approval_status = 'pending' (đang chờ duyệt lại sau khi đổi lộ trình).
-- ---------------------------------------------------------------------
INSERT INTO tours (id, provider_id, title, description, destination, duration_minutes, max_group_size,
                   language_codes, pickup_mode, meeting_point, included_summary,
                   transport, guide_info, dropoff_point, excluded_summary,
                   document_terms, meal_terms, voucher_terms, reschedule_terms,
                   source_url, verified_at, verification_status, approval_status) VALUES
-- Tour 1 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
    'Hà Nội qua những món ăn phố cổ',
    CONCAT_WS(CHAR(10),
        'Đi bộ cùng người địa phương, khám phá món ngon và câu chuyện phố cổ.',
        '',
        'Tour đi bộ 4 giờ cùng người dẫn địa phương. Ghé các quán nhỏ, thưởng thức món ăn và tìm hiểu cuộc sống thường ngày tại Hà Nội. Lộ trình đi qua những con phố nhỏ quanh hồ Hoàn Kiếm, mỗi điểm dừng là một món ăn và một câu chuyện về con phố đó.'),
    'Hà Nội', 240, 8, 'vi,en', 'meeting_point', 'Nhà hát Múa rối Thăng Long',
    CONCAT_WS(CHAR(10),
        'Người dẫn địa phương',
        '5 món ăn',
        '1 đồ uống'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ (khoảng 3 km)',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Khu vực hồ Hoàn Kiếm',
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Đồ uống gọi thêm ngoài 1 đồ uống của tour',
        'Tiền tip cho người dẫn (tùy ý)',
        'Chi phí đi lại đến điểm hẹn'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm 5 món ăn và 1 đồ uống. Báo trước khi đặt nếu ăn chay hoặc dị ứng thực phẩm.',
    'Xuất trình mã đặt chỗ (bản điện tử) cho người dẫn tại điểm hẹn.',
    'Đổi sang lịch khác miễn phí nếu báo trước ít nhất 24 giờ và lịch mới còn chỗ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 2 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002',
    'Ẩm thực Hà Nội & cà phê trứng',
    CONCAT_WS(CHAR(10),
        'Một góc nhìn khác về phố cổ, với nhóm nhỏ và thời gian thư thả.',
        '',
        'Bắt đầu từ chợ Đồng Xuân, nhóm đi qua các phố quanh chợ để thử bánh cuốn nóng và những món ăn vặt quen thuộc của người Hà Nội. Tour kết thúc ở một quán cà phê trứng trên tầng cao nhìn ra phố. Nhịp đi chậm, phù hợp với người lần đầu đến Hà Nội.'),
    'Hà Nội', 180, 6, 'vi,en', 'meeting_point', 'Chợ Đồng Xuân (cổng chính)',
    CONCAT_WS(CHAR(10),
        'Người dẫn địa phương',
        'Bánh cuốn và 3 món ăn vặt',
        '1 ly cà phê trứng'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Quán cà phê trứng ở chặng cuối, trong khu phố cổ',
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Món ăn, đồ uống gọi thêm',
        'Tiền tip cho người dẫn (tùy ý)'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bánh cuốn, 3 món ăn vặt và 1 ly cà phê trứng (có thể đổi sang đồ uống khác).',
    'Xuất trình mã đặt chỗ cho người dẫn tại cổng chính chợ Đồng Xuân.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 3 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000002',
    'Phố cổ theo cách của bạn',
    CONCAT_WS(CHAR(10),
        'Tour riêng cho nhóm nhỏ: bạn chọn chủ đề, người dẫn thiết kế lộ trình quanh phố cổ.',
        '',
        'Trước ngày đi, người dẫn liên hệ để hỏi sở thích của nhóm: kiến trúc nhà ống, phố nghề, đền chùa hay những góc chụp ảnh. Lộ trình được sắp xếp riêng trong khoảng 4 giờ, đi bộ kết hợp một đoạn xích lô ngắn. Phù hợp với gia đình hoặc nhóm bạn muốn tìm hiểu phố cổ sâu hơn.'),
    'Hà Nội', 240, 4, 'vi,en,fr', 'meeting_point', 'Đền Bạch Mã, phố Hàng Buồm',
    CONCAT_WS(CHAR(10),
        'Người dẫn riêng cho nhóm',
        'Vé vào nhà cổ',
        'Xích lô 20 phút'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả (thiếu: dropoff_point, voucher_terms)
    'Đi bộ kết hợp xích lô 20 phút',
    'Người dẫn riêng cho nhóm, nói tiếng Việt, tiếng Anh hoặc tiếng Pháp',
    NULL,
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Bữa ăn và đồ uống',
        'Mua sắm cá nhân tại phố nghề'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Không gồm bữa ăn. Người dẫn gợi ý quán ăn tối sau tour.',
    NULL,
    'Đổi lịch miễn phí nếu báo trước ít nhất 48 giờ; người dẫn liên hệ lại để thống nhất lộ trình.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 4 (Đà Nẵng) -------------------------------------------
('c0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000003',
    'Bình minh trên bán đảo Sơn Trà',
    CONCAT_WS(CHAR(10),
        'Đón bình minh trên bán đảo Sơn Trà, đi bộ đường rừng nhẹ và tìm voọc chà vá chân nâu.',
        '',
        'Xe đón nhóm ở trung tâm thành phố lúc 5 giờ sáng để kịp ngắm mặt trời mọc trên đỉnh Bàn Cờ. Sau đó cả nhóm đi bộ một cung đường rừng ngắn, nghe người dẫn giới thiệu hệ sinh thái của bán đảo và quan sát voọc chà vá chân nâu nếu may mắn. Tour kết thúc bằng bữa sáng mì Quảng gần chân núi.'),
    'Đà Nẵng', 300, 10, 'vi,en,ko', 'hotel_pickup', 'Khách sạn ở trung tâm Đà Nẵng',
    CONCAT_WS(CHAR(10),
        'Xe đưa đón hai chiều',
        'Bữa sáng mì Quảng',
        'Nước uống',
        'Ống nhòm cho mượn'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe 16 chỗ đưa đón hai chiều; đi bộ đường rừng khoảng 2 km',
    'Hướng dẫn viên nói tiếng Việt, tiếng Anh và tiếng Hàn',
    'Khách sạn ở trung tâm Đà Nẵng',
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Đồ uống ngoài nước suối',
        'Chi phí cá nhân'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bữa sáng mì Quảng và nước uống. Có mì chay nếu báo trước.',
    'Xuất trình mã đặt chỗ cho tài xế khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ. Trời mưa lớn: tour được dời lịch theo chính sách hủy hiện hành.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 5 (Đà Nẵng) -------------------------------------------
('c0000000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000004',
    'Đà Nẵng về đêm: cầu Rồng và chợ đêm',
    CONCAT_WS(CHAR(10),
        'Dạo bờ sông Hàn, ngắm cầu Rồng lên đèn và ăn tối ở chợ đêm cùng người địa phương.',
        '',
        'Tour bắt đầu khi thành phố lên đèn, đi bộ dọc bờ sông Hàn và dừng lại ở những góc ngắm cầu Rồng đẹp nhất. Sau đó nhóm ghé chợ đêm thử bánh tráng cuốn thịt heo, ốc hút và chè. Vào tối thứ Bảy và Chủ nhật, nhóm xem cầu Rồng phun lửa, phun nước lúc 21:00.'),
    'Đà Nẵng', 210, 12, 'vi,en', 'meeting_point', 'Đầu cầu Rồng, phía đường Bạch Đằng',
    CONCAT_WS(CHAR(10),
        'Người dẫn địa phương',
        'Ăn tối nhẹ 3 món',
        'Taxi sang chợ đêm'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả (thiếu: excluded_summary)
    'Đi bộ dọc bờ sông Hàn, taxi sang chợ đêm',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Chợ đêm, nơi kết thúc tour',
    -- FR-04 không bao gồm
    NULL,
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm ăn tối nhẹ 3 món ở chợ đêm.',
    'Xuất trình mã đặt chỗ cho người dẫn ở đầu cầu Rồng.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 12 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 6 (Hội An) --------------------------------------------
('c0000000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000005',
    'Hội An: phố cổ, đèn lồng và hoa đăng',
    CONCAT_WS(CHAR(10),
        'Đi chậm qua phố cổ Hội An lúc chiều tối, nghe chuyện hội quán và thả hoa đăng trên sông Hoài.',
        '',
        'Người dẫn đưa nhóm qua chùa Cầu, một ngôi nhà cổ và hội quán Phúc Kiến, kể về thương cảng Hội An xưa. Khi phố lên đèn, cả nhóm học làm một chiếc đèn lồng nhỏ và thả hoa đăng trên sông Hoài. Nhịp đi chậm, có nhiều thời gian chụp ảnh.'),
    'Hội An', 180, 10, 'vi,en', 'meeting_point', 'Chùa Cầu, đầu phố Trần Phú',
    CONCAT_WS(CHAR(10),
        'Vé tham quan phố cổ',
        'Đèn lồng tự làm mang về',
        'Hoa đăng'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ trong phố cổ',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Chợ đêm Nguyễn Hoàng',
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Ăn tối',
        'Đi thuyền trên sông Hoài (xem hoạt động tùy chọn)',
        'Chi phí cá nhân'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Không gồm bữa ăn. Người dẫn gợi ý quán ăn tối gần chợ đêm.',
    'Xuất trình mã đặt chỗ cho người dẫn tại Chùa Cầu.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 7 (Hội An) --------------------------------------------
('c0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000005',
    'Làng rau Trà Quế: đạp xe và học nấu ăn',
    CONCAT_WS(CHAR(10),
        'Đạp xe qua đồng lúa ra làng rau Trà Quế, làm vườn cùng nông dân và tự nấu bữa trưa kiểu Hội An.',
        '',
        'Từ trung tâm Hội An, nhóm đạp xe khoảng 4 km ra làng rau Trà Quế. Bạn được nông dân hướng dẫn xới đất, gánh nước tưới rau và tìm hiểu cách bón rau bằng rong sông. Phần cuối là lớp nấu ăn nhỏ: tự làm bánh xèo, gỏi cuốn và cùng ăn trưa trong vườn.'),
    'Hội An', 270, 8, 'vi,en', 'meeting_point', 'Bãi xe đạp cạnh chợ Hội An',
    CONCAT_WS(CHAR(10),
        'Xe đạp và nón lá',
        'Lớp nấu ăn và bữa trưa',
        'Nước uống'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả (thiếu: guide_info, reschedule_terms)
    'Xe đạp, khoảng 4 km mỗi chiều',
    NULL,
    'Bãi xe đạp cạnh chợ Hội An',
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Đồ uống gọi thêm',
        'Chi phí cá nhân'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bữa trưa tự nấu (bánh xèo, gỏi cuốn). Có thực đơn chay nếu báo trước.',
    'Xuất trình mã đặt chỗ khi nhận xe đạp.',
    NULL,
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 8 (TP. Hồ Chí Minh) -----------------------------------
('c0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000006',
    'Sài Gòn về đêm trên xe máy',
    CONCAT_WS(CHAR(10),
        'Ngồi sau xe máy cùng người dẫn, đi qua các quận trung tâm và ăn tối như người Sài Gòn.',
        '',
        'Mỗi khách ngồi sau một tài xế kiêm người dẫn có kinh nghiệm. Nhóm đi qua quận 1, quận 4 và quận 5, ghé quán ốc, xe chè và một quán cà phê nhạc sống. Tour có mũ bảo hiểm đạt chuẩn, áo mưa và bảo hiểm du lịch cho từng khách.'),
    'TP. Hồ Chí Minh', 240, 6, 'vi,en', 'hotel_pickup', 'Khách sạn ở quận 1 hoặc quận 3',
    CONCAT_WS(CHAR(10),
        'Xe máy và tài xế riêng cho mỗi khách',
        'Ăn tối 4 món',
        'Mũ bảo hiểm và áo mưa',
        'Bảo hiểm du lịch'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe máy, mỗi khách ngồi sau một tài xế',
    'Tài xế kiêm người dẫn, nói tiếng Việt và tiếng Anh',
    'Khách sạn ở quận 1 hoặc quận 3',
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Đồ uống gọi thêm tại quán cà phê',
        'Tiền tip cho tài xế (tùy ý)'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Mang theo giấy tờ tùy thân (bản chụp cũng được) để làm bảo hiểm du lịch.',
    'Gồm ăn tối 4 món. Báo trước nếu ăn chay hoặc dị ứng hải sản.',
    'Xuất trình mã đặt chỗ cho tài xế khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ; trời mưa tour vẫn khởi hành, có áo mưa.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 9 (TP. Hồ Chí Minh) -----------------------------------
('c0000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000007',
    'Chợ Lớn: hẻm nhỏ, hội quán và món Hoa',
    CONCAT_WS(CHAR(10),
        'Khám phá Chợ Lớn qua các hội quán, tiệm thuốc bắc lâu đời và món ăn của người Hoa.',
        '',
        'Tour đi bộ qua các con hẻm ở quận 5, ghé chùa Bà Thiên Hậu và vài hội quán, nghe chuyện về cộng đồng người Hoa ở Sài Gòn. Nhóm dừng chân ở một tiệm thuốc bắc và kết thúc bằng bữa ăn nhẹ với sủi cảo, há cảo. Lịch khởi hành đang được cập nhật.'),
    'TP. Hồ Chí Minh', 210, 10, 'vi,en,zh', 'meeting_point', 'Chùa Bà Thiên Hậu, đường Nguyễn Trãi, quận 5',
    CONCAT_WS(CHAR(10),
        'Người dẫn địa phương',
        'Phần ăn nhẹ'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả (thiếu: cả 8 trường)
    NULL,
    NULL,
    NULL,
    -- FR-04 không bao gồm
    NULL,
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    NULL,
    NULL,
    NULL,
    NULL,
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 10 (Hà Nội) --------------------------------------------
('c0000000-0000-4000-8000-000000000010', 'b0000000-0000-4000-8000-000000000001',
    'Đạp xe quanh Hồ Tây lúc bình minh',
    CONCAT_WS(CHAR(10),
        'Đạp xe một vòng Hồ Tây buổi sớm, ghé chùa Trấn Quốc và ăn sáng bún ốc.',
        '',
        'Nhóm nhận xe đạp ở đường Thanh Niên, đạp một vòng Hồ Tây khi mặt trời mọc, ghé chùa Trấn Quốc trước giờ đông khách và kết thúc bằng bát bún ốc nóng. Tour đang tạm ẩn để cập nhật lộ trình.'),
    'Hà Nội', 150, 8, 'vi,en', 'meeting_point', 'Đầu đường Thanh Niên, phía Hồ Tây',
    CONCAT_WS(CHAR(10),
        'Xe đạp và mũ bảo hiểm',
        'Bữa sáng bún ốc'),
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe đạp',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Quán bún ốc gần Hồ Tây',
    -- FR-04 không bao gồm
    CONCAT_WS(CHAR(10),
        'Đồ uống gọi thêm'),
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bữa sáng bún ốc.',
    'Xuất trình mã đặt chỗ khi nhận xe đạp ở đường Thanh Niên.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'pending');

-- ---------------------------------------------------------------------
-- 4. cancellation_policies (CHÍNH_SÁCH_HỦY)
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
-- 5. schedules (LỊCH_KHỞI_HÀNH)
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
-- 6. ticket_types (VÉ_THEO_LỊCH)
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
-- 7. bookings (ĐƠN_ĐẶT_TOUR)
--   Đơn 1-29: 'completed' (đã đi tour). Đơn 30: 'cancelled' (lịch 4 của tour 1, đã hoàn tiền).
--   total_vnd = tổng line_total_vnd. policy_version = phiên bản chính sách hủy lúc đặt.
--   Khách không có tài khoản: tra cứu đơn bằng mã đơn + contact_email / contact_phone.
-- ---------------------------------------------------------------------
INSERT INTO bookings (id, schedule_id, code, contact_name, contact_email, contact_phone,
                      status, total_vnd, policy_version, hold_expires_at) VALUES
-- Tour 1
('10000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000101',
    'LT812768', 'Quốc Huy', 'quoc.huy@localtour.test', '0000000101', 'completed', 1760000, 1, NULL),
('10000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000102',
    'LT469739', 'Lan Phương', 'lan.phuong@localtour.test', '0000000102', 'completed', 1950000, 1, NULL),
('10000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000103',
    'LT707426', 'Thu Trang', 'thu.trang@localtour.test', '0000000103', 'completed', 650000, 1, NULL),
('10000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8000-000000000104',
    'LT396700', 'Minh Anh', 'minh.anh@localtour.test', '0000000104', 'completed', 1300000, 1, NULL),
-- Tour 2
('10000000-0000-4000-8000-000000000005', 'd0000000-0000-4000-8000-000000000105',
    'LT995361', 'Hoàng Yến', 'hoang.yen@localtour.test', '0000000105', 'completed', 1440000, 1, NULL),
('10000000-0000-4000-8000-000000000006', 'd0000000-0000-4000-8000-000000000106',
    'LT280930', 'Đức Thịnh', 'duc.thinh@localtour.test', '0000000106', 'completed', 1220000, 1, NULL),
('10000000-0000-4000-8000-000000000007', 'd0000000-0000-4000-8000-000000000107',
    'LT150872', 'Bảo Ngọc', 'bao.ngoc@localtour.test', '0000000107', 'completed', 1440000, 1, NULL),
-- Tour 3
('10000000-0000-4000-8000-000000000008', 'd0000000-0000-4000-8000-000000000108',
    'LT963617', 'Gia Bảo', 'gia.bao@localtour.test', '0000000108', 'completed', 2700000, 1, NULL),
('10000000-0000-4000-8000-000000000009', 'd0000000-0000-4000-8000-000000000109',
    'LT353315', 'Khánh Linh', 'khanh.linh@localtour.test', '0000000109', 'completed', 1800000, 1, NULL),
-- Tour 4
('10000000-0000-4000-8000-000000000010', 'd0000000-0000-4000-8000-000000000110',
    'LT341641', 'Hải Đăng', 'hai.dang@localtour.test', '0000000110', 'completed', 1100000, 1, NULL),
('10000000-0000-4000-8000-000000000011', 'd0000000-0000-4000-8000-000000000111',
    'LT345953', 'Thanh Hà', 'thanh.ha@localtour.test', '0000000111', 'completed', 550000, 1, NULL),
('10000000-0000-4000-8000-000000000012', 'd0000000-0000-4000-8000-000000000112',
    'LT103067', 'Văn Long', 'van.long@localtour.test', '0000000112', 'completed', 1490000, 2, NULL),
('10000000-0000-4000-8000-000000000013', 'd0000000-0000-4000-8000-000000000113',
    'LT848329', 'Ngọc Mai', 'ngoc.mai@localtour.test', '0000000113', 'completed', 1100000, 2, NULL),
-- Tour 5
('10000000-0000-4000-8000-000000000014', 'd0000000-0000-4000-8000-000000000114',
    'LT965599', 'Tuấn Kiệt', 'tuan.kiet@localtour.test', '0000000114', 'completed', 960000, 1, NULL),
('10000000-0000-4000-8000-000000000015', 'd0000000-0000-4000-8000-000000000115',
    'LT673352', 'Mai Chi', 'mai.chi@localtour.test', '0000000115', 'completed', 480000, 1, NULL),
('10000000-0000-4000-8000-000000000016', 'd0000000-0000-4000-8000-000000000116',
    'LT238066', 'Phương Thảo', 'phuong.thao@localtour.test', '0000000116', 'completed', 1440000, 1, NULL),
-- Tour 6
('10000000-0000-4000-8000-000000000017', 'd0000000-0000-4000-8000-000000000117',
    'LT161961', 'Kim Ngân', 'kim.ngan@localtour.test', '0000000117', 'completed', 1180000, 1, NULL),
('10000000-0000-4000-8000-000000000018', 'd0000000-0000-4000-8000-000000000118',
    'LT308511', 'Trọng Nghĩa', 'trong.nghia@localtour.test', '0000000118', 'completed', 1000000, 1, NULL),
('10000000-0000-4000-8000-000000000019', 'd0000000-0000-4000-8000-000000000119',
    'LT302797', 'Thảo Vy', 'thao.vy@localtour.test', '0000000119', 'completed', 1180000, 1, NULL),
('10000000-0000-4000-8000-000000000020', 'd0000000-0000-4000-8000-000000000120',
    'LT423521', 'Nhật Minh', 'nhat.minh@localtour.test', '0000000120', 'completed', 590000, 1, NULL),
-- Tour 7
('10000000-0000-4000-8000-000000000021', 'd0000000-0000-4000-8000-000000000121',
    'LT770177', 'Diễm My', 'diem.my@localtour.test', '0000000121', 'completed', 1500000, 1, NULL),
('10000000-0000-4000-8000-000000000022', 'd0000000-0000-4000-8000-000000000122',
    'LT836154', 'Hữu Phước', 'huu.phuoc@localtour.test', '0000000122', 'completed', 750000, 1, NULL),
('10000000-0000-4000-8000-000000000023', 'd0000000-0000-4000-8000-000000000123',
    'LT970081', 'Anh Thư', 'anh.thu@localtour.test', '0000000123', 'completed', 2560000, 1, NULL),
-- Tour 8
('10000000-0000-4000-8000-000000000024', 'd0000000-0000-4000-8000-000000000124',
    'LT789608', 'Thanh Tùng', 'thanh.tung@localtour.test', '0000000124', 'completed', 850000, 1, NULL),
('10000000-0000-4000-8000-000000000025', 'd0000000-0000-4000-8000-000000000125',
    'LT753275', 'Quỳnh Như', 'quynh.nhu@localtour.test', '0000000125', 'completed', 1700000, 1, NULL),
-- Tour 10
('10000000-0000-4000-8000-000000000026', 'd0000000-0000-4000-8000-000000000126',
    'LT211777', 'Bích Ngọc', 'bich.ngoc@localtour.test', '0000000126', 'completed', 800000, 1, NULL),
('10000000-0000-4000-8000-000000000027', 'd0000000-0000-4000-8000-000000000127',
    'LT876132', 'Hoài Nam', 'hoai.nam@localtour.test', '0000000127', 'completed', 400000, 1, NULL),
('10000000-0000-4000-8000-000000000028', 'd0000000-0000-4000-8000-000000000128',
    'LT302831', 'Thu Hằng', 'thu.hang@localtour.test', '0000000128', 'completed', 1200000, 1, NULL),
-- Đơn có đánh giá đang chờ duyệt
('10000000-0000-4000-8000-000000000029', 'd0000000-0000-4000-8000-000000000001',
    'LT893219', 'Đình Khoa', 'dinh.khoa@localtour.test', '0000000129', 'completed', 650000, 1, NULL),
-- Đơn đã hủy
('10000000-0000-4000-8000-000000000030', 'd0000000-0000-4000-8000-000000000004',
    'LT257589', 'Minh Châu', 'minh.chau@localtour.test', '0000000130', 'cancelled', 1300000, 1, NULL);

-- ---------------------------------------------------------------------
-- 8. booking_lines (DÒNG_ĐƠN)
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
-- 9. passengers (HÀNH_KHÁCH)
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
-- 10. payments (THANH_TOÁN)
--   FR-17: chỉ vnpay / vietqr (không có trả sau). Đơn 3k+1 -> vnpay, 3k+2 -> vietqr,
--   đơn 3k luân phiên vietqr / vnpay. Mọi thanh toán đã 'paid' và có mã giao dịch giả.
--   Đơn 30 đã trả bằng VNPay (status 'paid'); tiền hoàn ghi ở bảng refunds (mục 12).
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
-- 11. payment_events (SỰ_KIỆN_THANH_TOÁN)
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
-- 12. refunds (HOÀN_TIỀN)
--   Đơn 30 hủy trước giờ khởi hành hơn 24 giờ -> hoàn 100%.
-- ---------------------------------------------------------------------
INSERT INTO refunds (id, payment_id, amount_vnd, reason, status, requested_at) VALUES
('60000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000030', 1300000, 'Khách đổi kế hoạch du lịch, hủy trước giờ khởi hành hơn 24 giờ nên được hoàn toàn bộ tiền.', 'completed', TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '08:30:00'));

-- ---------------------------------------------------------------------
-- 13. reviews (ĐÁNH_GIÁ)
--   Đánh giá N thuộc đơn N. Chỉ 'approved' được hiển thị và tính điểm trung bình.
--   Đánh giá 29 (tour 1, 1 sao) đang 'pending': không được hiện, không được tính.
--   Tên người đánh giá hiển thị = bookings.contact_name của đơn tương ứng.
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
-- 14. tour_images (ẢNH_TOUR) - FR-01, FR-02
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
-- 15. itinerary_stops (ĐIỂM_LỊCH_TRÌNH) - FR-03
--   Chèn lệch thứ tự trong từng tour; trang chi tiết sắp xếp theo stop_order.
--   description / duration_minutes NULL = chưa cập nhật. Tour 9 không có lịch trình.
-- ---------------------------------------------------------------------
INSERT INTO itinerary_stops (id, tour_id, stop_order, title, description, duration_minutes) VALUES
-- Tour 1: 5 chặng, chèn theo thứ tự 3, 1, 5, 2, 4
('90000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 3, 'Bún chả và nem rán trong một con ngõ nhỏ',
    NULL, 60),
('90000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', 1, 'Gặp nhau tại Nhà hát Múa rối Thăng Long',
    'Người dẫn giới thiệu lộ trình và phát nước uống cho cả nhóm.', 15),
('90000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', 5, 'Kết thúc tại khu vực hồ Hoàn Kiếm',
    NULL, NULL),
('90000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000001', 2, 'Đi bộ và thử món ăn quanh phố cổ',
    'Mỗi điểm dừng là một món ăn và một câu chuyện về con phố đó.', 75),
('90000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000001', 4, 'Cà phê trứng và câu chuyện địa phương',
    'Ngồi lại ở quán cà phê, nghe người dẫn kể về cuộc sống thường ngày ở phố cổ.', 90),
-- Tour 2: 4 chặng, chèn theo thứ tự 3, 1, 4, 2
('90000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000002', 3, 'Bánh cuốn nóng trong một quán gia đình',
    'Xem cách tráng bánh cuốn trên nồi hấp và ăn ngay khi bánh còn nóng.', 60),
('90000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000002', 1, 'Gặp nhau tại cổng chính chợ Đồng Xuân',
    NULL, 20),
('90000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000002', 4, 'Cà phê trứng trên tầng cao nhìn ra phố',
    'Tour kết thúc tại quán lúc 18:00.', 45),
('90000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000002', 2, 'Dạo chợ, thử ô mai và các món ăn vặt',
    'Người dẫn chỉ cách chọn ô mai và giới thiệu các món ăn vặt quen thuộc của người Hà Nội.', 55),
-- Tour 3: 5 chặng, chèn theo thứ tự 3, 1, 5, 2, 4
('90000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000003', 3, 'Ghé một phố nghề truyền thống theo lựa chọn của nhóm',
    NULL, NULL),
('90000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000003', 1, 'Gặp người dẫn tại đền Bạch Mã, thống nhất lộ trình',
    'Nhóm chọn chủ đề cho buổi đi: kiến trúc, phố nghề, đền chùa hoặc góc chụp ảnh.', NULL),
('90000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000003', 5, 'Kết thúc ở quán trà, gợi ý chỗ ăn tối',
    'Trò chuyện cùng người dẫn và nhận danh sách quán ăn gợi ý.', NULL),
('90000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000003', 2, 'Tham quan một ngôi nhà cổ',
    'Tìm hiểu kiến trúc nhà ống: mặt tiền hẹp, giếng trời và cách nhiều thế hệ sống chung.', NULL),
('90000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000003', 4, 'Đi xích lô một vòng quanh hồ Hoàn Kiếm',
    NULL, 20),
-- Tour 4: 5 chặng, chèn theo thứ tự 4, 2, 5, 1, 3
('90000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000004', 4, 'Ăn sáng mì Quảng gần chân núi',
    NULL, 90),
('90000000-0000-4000-8000-000000000016', 'c0000000-0000-4000-8000-000000000004', 2, 'Ngắm bình minh trên đỉnh Bàn Cờ',
    'Đỉnh Bàn Cờ nhìn ra biển và toàn cảnh thành phố; nên mang áo khoác mỏng.', 60),
('90000000-0000-4000-8000-000000000017', 'c0000000-0000-4000-8000-000000000004', 5, 'Xe đưa về khách sạn',
    NULL, NULL),
('90000000-0000-4000-8000-000000000018', 'c0000000-0000-4000-8000-000000000004', 1, 'Xe đón tại khách sạn ở trung tâm',
    NULL, 30),
('90000000-0000-4000-8000-000000000019', 'c0000000-0000-4000-8000-000000000004', 3, 'Đi bộ đường rừng, tìm voọc chà vá chân nâu',
    'Cung đường ngắn, độ dốc vừa phải. Có ống nhòm cho mượn để quan sát voọc.', 120),
-- Tour 5: 5 chặng, chèn theo thứ tự 3, 1, 5, 2, 4
('90000000-0000-4000-8000-000000000020', 'c0000000-0000-4000-8000-000000000005', 3, 'Ăn tối nhẹ ở chợ đêm',
    'Thử bánh tráng cuốn thịt heo, ốc hút và chè.', 75),
('90000000-0000-4000-8000-000000000021', 'c0000000-0000-4000-8000-000000000005', 1, 'Gặp nhau ở đầu cầu Rồng, phía đường Bạch Đằng',
    NULL, 15),
('90000000-0000-4000-8000-000000000022', 'c0000000-0000-4000-8000-000000000005', 5, 'Kết thúc tour tại chợ đêm',
    NULL, NULL),
('90000000-0000-4000-8000-000000000023', 'c0000000-0000-4000-8000-000000000005', 2, 'Dạo bờ sông Hàn, ngắm cầu Rồng lên đèn',
    'Dừng ở những góc ngắm cầu Rồng đẹp nhất để chụp ảnh.', 60),
('90000000-0000-4000-8000-000000000024', 'c0000000-0000-4000-8000-000000000005', 4, 'Xem cầu Rồng phun lửa, phun nước',
    'Chỉ có vào tối thứ Bảy và Chủ nhật, lúc 21:00.', 60),
-- Tour 6: 5 chặng, chèn theo thứ tự 4, 2, 5, 1, 3
('90000000-0000-4000-8000-000000000025', 'c0000000-0000-4000-8000-000000000006', 4, 'Thả hoa đăng trên sông Hoài',
    NULL, 45),
('90000000-0000-4000-8000-000000000026', 'c0000000-0000-4000-8000-000000000006', 2, 'Tham quan nhà cổ và hội quán Phúc Kiến',
    'Nghe chuyện về thương cảng Hội An xưa.', 60),
('90000000-0000-4000-8000-000000000027', 'c0000000-0000-4000-8000-000000000006', 5, 'Kết thúc tour ở chợ đêm Nguyễn Hoàng',
    NULL, NULL),
('90000000-0000-4000-8000-000000000028', 'c0000000-0000-4000-8000-000000000006', 1, 'Gặp nhau tại Chùa Cầu',
    NULL, 15),
('90000000-0000-4000-8000-000000000029', 'c0000000-0000-4000-8000-000000000006', 3, 'Học làm đèn lồng cùng nghệ nhân',
    'Mỗi khách tự làm một chiếc đèn lồng nhỏ để mang về.', 60),
-- Tour 7: 5 chặng, chèn theo thứ tự 3, 1, 5, 2, 4
('90000000-0000-4000-8000-000000000030', 'c0000000-0000-4000-8000-000000000007', 3, 'Lớp nấu ăn: bánh xèo và gỏi cuốn',
    NULL, 105),
('90000000-0000-4000-8000-000000000031', 'c0000000-0000-4000-8000-000000000007', 1, 'Nhận xe đạp, đạp xe ra làng rau Trà Quế',
    'Quãng đường khoảng 4 km qua đồng lúa.', 30),
('90000000-0000-4000-8000-000000000032', 'c0000000-0000-4000-8000-000000000007', 5, 'Đạp xe về trung tâm Hội An',
    NULL, NULL),
('90000000-0000-4000-8000-000000000033', 'c0000000-0000-4000-8000-000000000007', 2, 'Làm vườn cùng nông dân trong làng',
    'Xới đất, gánh nước tưới rau và tìm hiểu cách bón rau bằng rong sông.', 75),
('90000000-0000-4000-8000-000000000034', 'c0000000-0000-4000-8000-000000000007', 4, 'Ăn trưa trong vườn',
    NULL, 60),
-- Tour 8: 5 chặng, chèn theo thứ tự 4, 2, 5, 1, 3
('90000000-0000-4000-8000-000000000035', 'c0000000-0000-4000-8000-000000000008', 4, 'Cà phê nhạc sống',
    'Nghỉ chân ở một quán cà phê có ban nhạc chơi nhạc sống.', 90),
('90000000-0000-4000-8000-000000000036', 'c0000000-0000-4000-8000-000000000008', 2, 'Ăn ốc ở quận 4',
    NULL, 60),
('90000000-0000-4000-8000-000000000037', 'c0000000-0000-4000-8000-000000000008', 5, 'Đưa khách về khách sạn',
    NULL, NULL),
('90000000-0000-4000-8000-000000000038', 'c0000000-0000-4000-8000-000000000008', 1, 'Đón khách tại khách sạn',
    'Nhận mũ bảo hiểm, áo mưa và làm quen với tài xế.', 30),
('90000000-0000-4000-8000-000000000039', 'c0000000-0000-4000-8000-000000000008', 3, 'Dạo Chợ Lớn và ăn chè',
    NULL, 60),
-- Tour 10: 4 chặng, chèn theo thứ tự 3, 1, 4, 2 (tour đang chờ duyệt: không được hiển thị)
('90000000-0000-4000-8000-000000000040', 'c0000000-0000-4000-8000-000000000010', 3, 'Ghé chùa Trấn Quốc',
    'Đến trước giờ đông khách.', 45),
('90000000-0000-4000-8000-000000000041', 'c0000000-0000-4000-8000-000000000010', 1, 'Nhận xe đạp ở đầu đường Thanh Niên',
    NULL, 15),
('90000000-0000-4000-8000-000000000042', 'c0000000-0000-4000-8000-000000000010', 4, 'Ăn sáng bún ốc và kết thúc tour',
    NULL, 30),
('90000000-0000-4000-8000-000000000043', 'c0000000-0000-4000-8000-000000000010', 2, 'Đạp xe quanh Hồ Tây, ngắm bình minh',
    'Đạp chậm, dừng ở vài điểm ngắm mặt trời mọc trên hồ.', 60);

-- ---------------------------------------------------------------------
-- 16. tour_extras (PHỤ_THU / HOẠT_ĐỘNG_TÙY_CHỌN) - FR-04, FR-10
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
-- =====================================================================
-- LocalTour v0.1 - 03_procedures_LTP.sql
-- Mục đích  : Stored procedures cho trang danh sách tour (Bảng tin du lịch).
-- Phụ trách : Lê Trung Phong (LTP) - WBS 3.2.3
-- Procedures: LTP_sp_tour_list, LTP_sp_destination_list
-- Quy tắc   : Tour được hiển thị khi tours.approval_status = 'approved' VÀ
--             providers.approval_status = 'approved' VÀ tài khoản của nhà cung cấp
--             (users.status) = 'active'. Tour khác -> không bao giờ trả về.
--             Lịch đặt được: status = 'open', starts_at > NOW(), remaining > 0 và có
--             ít nhất một loại vé active.
--             Điểm đánh giá chỉ tính đánh giá moderation_status = 'approved'.
--             Ảnh bìa: ảnh của chính tour có sort_order nhỏ nhất (rồi id nhỏ nhất).
--             Tham số chuỗi được so sánh với COLLATE utf8mb4_unicode_ci để không lỗi
--             "Illegal mix of collations" khi database mặc định dùng collation khác.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- LTP_sp_tour_list(p_keyword, p_destination, p_sort)
--   p_keyword     : NULL / '' / toàn khoảng trắng = không lọc; ngược lại tìm
--                   LIKE '%từ khóa%' trong tên tour, mô tả, điểm đến, tên nhà cung cấp.
--                   Ký tự % và _ được tìm đúng nghĩa đen (ký tự thoát là !).
--   p_destination : NULL / '' = mọi điểm đến; ngược lại so khớp nguyên tên điểm đến
--                   (không phân biệt hoa thường), vd. 'Hà Nội'.
--   p_sort        : 'recommended' (mặc định) | 'upcoming' | 'price_asc' | 'price_desc';
--                   giá trị khác = 'recommended'.
--     recommended: tour có đánh giá trước, rating_avg giảm dần, review_count giảm dần
--     upcoming   : next_starts_at tăng dần, tour chưa có lịch đặt được xếp cuối
--     price_asc / price_desc: from_price_vnd, tour chưa có giá (NULL) xếp cuối
--     Cùng thứ hạng thì xếp theo title, rồi id.
--   Cột trả về: tour_id, title, description, destination, provider_name,
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
    IN p_keyword     VARCHAR(100),
    IN p_destination VARCHAR(100),
    IN p_sort        VARCHAR(20)
)
READS SQL DATA
BEGIN
    DECLARE v_pattern     VARCHAR(310) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_destination VARCHAR(100) CHARACTER SET utf8mb4 DEFAULT NULL;
    DECLARE v_sort        VARCHAR(20) DEFAULT 'recommended';

    -- Thoát ký tự đặc biệt của LIKE: '!' trước (vì là ký tự thoát), sau đó '%' và '_'.
    IF p_keyword IS NOT NULL AND TRIM(p_keyword) <> '' THEN
        SET v_pattern = CONCAT('%',
            REPLACE(REPLACE(REPLACE(TRIM(p_keyword), '!', '!!'), '%', '!%'), '_', '!_'),
            '%');
    END IF;

    IF p_destination IS NOT NULL AND TRIM(p_destination) <> '' THEN
        SET v_destination = TRIM(p_destination);
    END IF;

    IF p_sort IN ('upcoming', 'price_asc', 'price_desc') THEN
        SET v_sort = p_sort;
    END IF;

    SELECT
        t.id                            AS tour_id,
        t.title,
        t.description,
        t.destination,
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
      AND (v_destination IS NULL
           OR t.destination = (v_destination COLLATE utf8mb4_unicode_ci))
      AND (v_pattern IS NULL
           OR t.title           LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR t.description     LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR t.destination     LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!'
           OR p.business_name   LIKE (v_pattern COLLATE utf8mb4_unicode_ci) ESCAPE '!')
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
--   Điểm đến cho bộ lọc và thanh bên: mỗi điểm đến (tours.destination) đang có
--   tour hiển thị một dòng, kèm số tour hiển thị.
--   Cột trả về: destination, tour_count. Sắp xếp tour_count giảm dần, destination.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS LTP_sp_destination_list;

DELIMITER $$
CREATE PROCEDURE LTP_sp_destination_list()
READS SQL DATA
BEGIN
    SELECT
        t.destination,
        COUNT(*) AS tour_count
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    GROUP BY t.destination
    ORDER BY tour_count DESC, t.destination ASC;
END$$
DELIMITER ;
-- =====================================================================
-- LocalTour v0.1 - 04_procedures_NMT.sql
-- Mục đích  : Stored procedures cho trang chi tiết tour (thông tin chính kèm
--             phương tiện, dịch vụ không bao gồm, điều kiện; lịch khởi hành đặt được,
--             loại vé và giá vé, bộ ảnh của tour).
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.4
-- Procedures: NMT_sp_tour_detail, NMT_sp_tour_schedule_list, NMT_sp_tour_ticket_list,
--             NMT_sp_tour_image_list
-- Quy tắc   : Chỉ trả dữ liệu của tour đang hiển thị: tours.approval_status = 'approved'
--             VÀ providers.approval_status = 'approved' VÀ users.status = 'active'
--             (tài khoản của nhà cung cấp). Tour khác hoặc không tồn tại -> 0 dòng.
--             Lịch đặt được: status = 'open', starts_at > NOW(), remaining > 0 và có
--             ít nhất một loại vé active.
--             p_tour_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- Procedure của thiết kế cũ: bảng tour_itinerary_items không còn trong ERD
-- (lịch trình nay là bảng itinerary_stops, đọc bằng NTK_sp_tour_itinerary_list ở file 05).
DROP PROCEDURE IF EXISTS NMT_sp_tour_itinerary_list;

-- ---------------------------------------------------------------------
-- NMT_sp_tour_detail(p_tour_id)
--   0 hoặc 1 dòng. Cột: tour_id, provider_id, title, description, destination,
--   duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point,
--   included_summary, provider_name, provider_approved_at,
--   rating_avg (DECIMAL(2,1), NULL nếu chưa có đánh giá đã duyệt), review_count,
--   from_price_vnd (vé 'adult' active rẻ nhất trong các lịch đặt được; NULL nếu không
--   có lịch đặt được hoặc không lịch nào còn vé người lớn đang bán), next_starts_at,
--   transport, guide_info, dropoff_point (FR-02), excluded_summary (FR-04),
--   document_terms, meal_terms, voucher_terms, reschedule_terms (FR-05).
--   8 cột cuối NULL = chưa cập nhật (giao diện hiện "Chưa cập nhật").
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
        t.destination,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.included_summary,
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
        t.excluded_summary,         -- FR-04 không bao gồm (mỗi mục một dòng)
        t.document_terms,           -- FR-05 giấy tờ
        t.meal_terms,               -- FR-05 ăn uống
        t.voucher_terms,            -- FR-05 voucher
        t.reschedule_terms          -- FR-05 đổi lịch
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
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
-- LocalTour v0.1 - 05_procedures_NTK.sql
-- Mục đích  : Stored procedures cho nội dung trang chi tiết tour
--             (đánh giá của khách, chính sách hủy, lịch trình theo từng chặng,
--             phụ thu / hoạt động tùy chọn).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - WBS 3.2.6
-- Procedures: NTK_sp_tour_review_list, NTK_sp_tour_cancellation_policy,
--             NTK_sp_tour_itinerary_list, NTK_sp_tour_extra_list
-- Quy tắc   : Chỉ trả dữ liệu của tour đang hiển thị: tours.approval_status = 'approved'
--             VÀ providers.approval_status = 'approved' VÀ users.status = 'active'
--             (tài khoản của nhà cung cấp). Tour khác hoặc không tồn tại -> 0 dòng.
--             p_tour_id là UUID dạng chữ, so sánh với COLLATE utf8mb4_unicode_ci.
--             Chỉ đọc dữ liệu (READS SQL DATA), không có DEFINER.
-- Chạy sau  : 01_schema.sql. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- Procedure của thiết kế cũ: bộ ảnh nay đọc bằng NMT_sp_tour_image_list (file 04);
-- bảng tour_inclusions không còn trong ERD (nay là tours.included_summary).
DROP PROCEDURE IF EXISTS NTK_sp_tour_image_list;
DROP PROCEDURE IF EXISTS NTK_sp_tour_inclusion_list;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_review_list(p_tour_id, p_limit)
--   Chỉ đánh giá moderation_status = 'approved'.
--   Cột: review_id, reviewer_name (= bookings.contact_name của đơn được đánh giá;
--        khách không có tài khoản), rating, content,
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
        b.contact_name  AS reviewer_name,
        r.rating,
        r.content,
        s.starts_at     AS tour_date
    FROM reviews r
    JOIN bookings  b  ON b.id  = r.booking_id       -- đơn được đánh giá (tên người đặt)
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
--   Các chặng trong lịch trình của tour, theo đúng thứ tự stop_order.
--   Cột: stop_id, stop_order, title, description (NULL = chưa có mô tả),
--        duration_minutes (NULL = chưa có thời lượng; giao diện chỉ hiện khi có).
--   Sắp xếp stop_order, rồi stop_id. Tour không hiển thị hoặc chưa có lịch trình -> 0 dòng.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_itinerary_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_itinerary_list(
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        st.id           AS stop_id,
        st.stop_order,
        st.title,
        st.description,
        st.duration_minutes
    FROM itinerary_stops st
    JOIN tours     t ON t.id = st.tour_id
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    WHERE st.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND t.approval_status = 'approved'
      AND p.approval_status = 'approved'
      AND u.status = 'active'
    ORDER BY st.stop_order ASC, st.id ASC;
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
