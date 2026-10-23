-- =====================================================================
-- LocalTour v0.1 - 02_seed.sql
-- Mục đích  : Nạp dữ liệu mẫu để kiểm thử trang danh sách, trang chi tiết tour và
--             tài khoản khách hàng cho lược đồ gộp 27 bảng (01_schema.sql).
--             Các bảng chưa dùng để trống: itinerary_stops, tour_schedules, tour_posts,
--             favorite_tours, notifications, comparisons, comparison_tours, admin_logs.
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
--   Tour N = c0000000-0000-4000-8000-00000000000N; tour 1 = "Hà Nội qua những món ăn phố cổ".
-- Cách đánh số:
--   users        : 1 = quản trị viên; 2 = nhân viên hỗ trợ khách hàng;
--                  11-17 = tài khoản của nhà cung cấp 1-7;
--                  101-130 = tài khoản khách hàng: khách hàng 100 + N là người đặt đơn N
--                  (name = contact_name, email = contact_email của đơn).
--   destinations : 1 = Hà Nội, 2 = Đà Nẵng, 3 = Hội An, 4 = TP. Hồ Chí Minh,
--                  5 = Huế (chưa có tour).
--   categories   : 1 = Ẩm thực, 2 = Văn hóa – lịch sử, 3 = Thiên nhiên, 4 = Về đêm,
--                  5 = Trải nghiệm địa phương, 6 = Đạp xe.
--   schedules    : 1-37 = lịch của các tour; 101-128 = lịch đã đi của đơn có đánh giá
--                  (lịch 100 + N thuộc đơn N).
--   ticket_types : số lịch x 10 + 1 = người lớn, + 2 = trẻ em (vd. lịch 3 -> 31, 32).
--   bookings     : 1-28 = đơn có đánh giá đã duyệt (đơn N <-> đánh giá N);
--                  29 = đơn có đánh giá đang chờ duyệt; 30 = đơn đã hủy.
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
--     TP. Hồ Chí Minh 2. Huế không có tour -> bị ẩn. sort_order theo Bắc -> Nam
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
--   * Tài khoản: mọi tài khoản mẫu (quản trị, hỗ trợ, nhà cung cấp, khách hàng 101-130)
--     có password_hash NULL -> đăng nhập luôn báo "Email hoặc mật khẩu không đúng.".
--     Đăng ký bằng email đã có, kể cả khác chữ hoa / thường (vd. quoc.huy@localtour.test,
--     Quoc.Huy@LocalTour.test) -> "Email này đã được dùng.".
--   * Đánh giá: tên người đánh giá = users.name của chủ đơn (bookings.user_id), trùng
--     contact_name của đơn.
--
-- Số dòng: users 39, providers 7, destinations 5, categories 6, tours 10,
--          cancellation_policies 11, schedules 65, ticket_types 118, bookings 30,
--          booking_lines 35, passengers 60, payments 30, payment_events 30, refunds 1,
--          reviews 29, tour_images 12, tour_itinerary_items 43, tour_inclusions 45,
--          tour_extras 15. Để trống (0 dòng): itinerary_stops, tour_schedules,
--          tour_posts, favorite_tours, notifications, comparisons, comparison_tours,
--          admin_logs.
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
