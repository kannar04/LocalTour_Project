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
--             * Khách hàng KHÔNG có tài khoản (FR board): đơn đặt chỉ lưu thông tin liên hệ,
--               tra cứu đơn bằng mã đơn + email / số điện thoại.
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
-- 5. ĐẶT CHỖ
-- ---------------------------------------------------------------------

-- ĐƠN_ĐẶT_TOUR (FR-08 yêu cầu đặt tour, FR-11 mã và trạng thái, FR-09 thông tin liên hệ).
-- Khách không có tài khoản: tra cứu đơn bằng code + contact_email / contact_phone.
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

-- THANH_TOÁN (FR-17 thanh toán trực tuyến): method chỉ có 'vnpay' hoặc 'vietqr'
-- (FR board không có hình thức trả sau / trả tại điểm hẹn).
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
