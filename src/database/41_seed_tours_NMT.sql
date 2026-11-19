-- =====================================================================
-- LocalTour v0.7 - 41_seed_tours_NMT.sql
-- Mục đích  : Thêm tour mẫu cho trang danh sách tour và các bộ lọc của CR2 (ngày đi, khoảng giá,
--             thời lượng, ngôn ngữ hướng dẫn, đón tại khách sạn): 7 nhà cung cấp địa phương với
--             20 tour đã duyệt ở 6 điểm đến chưa có tour hiển thị: Sa Pa, Ninh Bình, Huế, Đà Lạt,
--             Cần Thơ, Phú Quốc. Mỗi tour có đủ thông tin như tour 1-8 của 02_seed.sql: loại hình,
--             thời lượng, ngôn ngữ, điểm hẹn hoặc khu vực đón, số khách tối đa, phương tiện, hướng
--             dẫn viên, điểm trả, điều khoản (FR-02/05), lịch trình, dịch vụ bao gồm / không bao gồm,
--             phụ thu / tùy chọn, chính sách hủy, lịch khởi hành và giá vé; 3 tour có gói tour.
--             Bốn điểm đến cũ (Hà Nội, Đà Nẵng, Hội An, TP. Hồ Chí Minh) giữ nguyên số tour.
-- Phụ trách : Nguyễn Minh Thức (NMT)
-- Dữ liệu   : TẤT CẢ là dữ liệu MINH HỌA (cùng quy ước với 02_seed.sql), không phải thông tin thật
--             của bất kỳ người hay đơn vị nào:
--               * tên nhà cung cấp là tên tự đặt; email dùng tên miền @localtour.test (không tồn
--                 tại); số điện thoại là số giả dạng 0000000xxx; users.phone để NULL;
--               * tài khoản nhà cung cấp có password_hash NULL nên KHÔNG đăng nhập được;
--               * giá, thời lượng, số khách tối đa: tham khảo khoảng giá, thời lượng phổ biến của
--                 tour địa phương; giá làm tròn tới 10.000đ, vé trẻ em khoảng 70% giá người lớn;
--               * NFR-07: source_url NULL, verified_at NULL, verification_status 'unverified';
--               * mỗi tour có 1 ảnh chụp địa điểm lấy từ Wikimedia Commons (JPG 1280x720 trong
--                 src/public/assets/img/tours/, tên file theo điểm đến: sapa, ninhbinh, hue, dalat,
--                 cantho, phuquoc); tác giả và giấy phép của từng ảnh ghi trong NGUON_ANH.md cùng thư mục;
--               * không có đánh giá, đơn đặt, lượt thích hay bình luận: người kiểm thử tự tạo bằng
--                 tài khoản của mình.
-- Chạy sau  : 01 -> 38 (cần categories và điểm đến Huế của 02_seed.sql, tour_packages của file 16).
--             Chạy lại được: xóa các dòng có mã của file này rồi thêm lại, tất cả trong một giao
--             dịch. Nếu đã có dữ liệu phát sinh trên các dòng này (đơn đặt, lượt thích, bình luận,
--             tour đã lưu, ảnh tải lên, bản sửa tour, tour mới ở điểm đến của file này...) thì lệnh
--             xóa báo lỗi khóa ngoại và không có thay đổi nào được lưu.
-- Ngày tháng: Tính tương đối theo CURDATE()/NOW() lúc import. Lịch khởi hành từ ngày +1 đến ngày
--             +34; tour nào cũng còn lịch mở ít nhất tới ngày +32.
--
-- ID: UUID cố định, dễ đọc, cùng tiền tố bảng với 02_seed.sql nhưng nhóm thứ hai là 0041:
--   <tiền tố bảng>-0041-4000-8000-<số 12 chữ số>
--   users a0000000 · providers b0000000 · destinations c2000000 · tours c0000000
--   cancellation_policies f0000000 · schedules d0000000 · ticket_types e0000000
--   tour_packages f5000000 · tour_itinerary_items c4000000 · tour_inclusions c5000000
--   tour_extras c1000000 · tour_images 80000000
--   Tour N = c0000000-0041-4000-8000-00000000000N;
--   tour 1 = "Đi bộ thung lũng Mường Hoa: Lao Chải – Tả Van".
-- Cách đánh số:
--   users        : 11-17 = tài khoản của nhà cung cấp 1-7.
--   destinations : 1 = Sa Pa, 2 = Ninh Bình, 3 = Đà Lạt, 4 = Cần Thơ, 5 = Phú Quốc. Huế dùng lại
--                  dòng c2000000-0000-4000-8000-000000000005 của 02_seed.sql (không sửa dòng đó).
--   schedules    : số tour x 100 + thứ tự lịch (vd. tour 7, lịch 3 -> 703).
--   ticket_types : số lịch x 10 + 1 = người lớn, + 2 = trẻ em (vd. lịch 703 -> 7031, 7032).
--   cancellation_policies: số tour x 10 + phiên bản. tour_packages: số tour x 10 + thứ tự.
--   tour_itinerary_items, tour_inclusions, tour_extras: số tour x 100 + thứ tự.
--   tour_images  : số tour (1 ảnh mỗi tour).
--
-- Ca kiểm thử có sẵn trong dữ liệu (cộng với dữ liệu của 02_seed.sql). Trong mục này "tour N" là
-- tour N của file này (c0000000-0041-...), trừ khi ghi "của 02_seed.sql".
--   * Trang khách có 29 tour hiển thị (tour 1-9 của 02_seed.sql + 20 tour của file này).
--   * Điểm đến theo sort_order (Bắc -> Nam): Sa Pa 3, Hà Nội 3, Ninh Bình 3, Huế 4, Đà Nẵng 2,
--     Hội An 2, Đà Lạt 4, TP. Hồ Chí Minh 2, Cần Thơ 3, Phú Quốc 3. Ninh Bình (sort_order 1) và
--     Đà Lạt (5) trùng sort_order với Hà Nội và TP. Hồ Chí Minh: thứ tự phụ theo tên.
--     Huế không còn bị ẩn: duyệt tour 11 của 02_seed.sql thì có 30 tour hiển thị, Huế 5 tour.
--   * Loại hình: Ẩm thực 4 (tour 3, 9, 12, 16), Văn hóa – lịch sử 2 (7, 20),
--     Thiên nhiên 6 (1, 4, 6, 11, 15, 17), Về đêm 2 (8, 18),
--     Trải nghiệm địa phương 6 (2, 5, 10, 13, 14, 19). Không tour nào thuộc Đạp xe: loại hình
--     này vẫn bị ẩn như trước (chỉ có tour 10 của 02_seed.sql, đang chờ duyệt).
--   * Thời lượng: đến 3 giờ (<= 180 phút) tour 2, 3, 5, 8, 9, 12, 16;
--     trên 3 - 4 giờ tour 6, 10, 15, 18, 19, 20; trên 4 giờ tour 1, 4, 7, 11, 13, 14, 17.
--   * Ngôn ngữ: mọi tour có vi và en; fr: tour 1, 4, 7, 11, 14;
--     zh: tour 3, 4, 7, 8, 12, 16, 17, 19; ko: tour 8, 10, 13, 14, 16;
--     ja: tour 6, 9, 12, 13, 18, 19, 20 (02_seed.sql chưa có tour tiếng Nhật).
--   * Đón tại khách sạn (hotel_pickup): tour 1, 4, 7, 11, 17, 18; các tour còn lại có điểm hẹn.
--     Không tour nào của file này vừa có tiếng Hàn vừa đón tại khách sạn: lọc "Tiếng Hàn" + "Có
--     đón tại khách sạn" vẫn chỉ ra tour 4 của 02_seed.sql (UAT-55 bước 4).
--     Mục lịch trình trả khách về khách sạn có start_time NULL (như tour 4, 8 của 02_seed.sql).
--   * Giá "Từ" = vé người lớn rẻ nhất trong các lịch đặt được (nghìn đồng):
--     tour 1: 1190, tour 2: 450, tour 3: 520, tour 4: 1250, tour 5: 420, tour 6: 690, tour 7: 950,
--     tour 8: 320, tour 9: 470, tour 10: 650, tour 11: 1590, tour 12: 350, tour 13: 1020, tour 14: 740,
--     tour 15: 590, tour 16: 390, tour 17: 1490, tour 18: 790, tour 19: 550, tour 20: 560.
--     Nút giá nhanh: đến 500.000đ tour 2, 5, 8, 9, 12, 16;
--     500.000đ - 800.000đ tour 3, 6, 10, 14, 15, 18, 19, 20;
--     từ 800.000đ tour 1, 4, 7, 11, 13, 17. Không tour nào có giá đúng 500.000đ hay 800.000đ.
--   * Gói tour (tour_packages): tour 1, 7, 17 có 2 gói; giá vé người lớn của lịch = giá gói rẻ nhất,
--     vé trẻ em = giá trẻ em rẻ nhất trong các gói. Gói "Xe máy cùng người dẫn" (tour 7) không bán
--     vé trẻ em (child_price_vnd NULL).
--   * Vé: người lớn từ 12 tuổi (tour 11 từ 16 tuổi); trẻ em 4-11 tuổi, riêng tour 1, 5, 15 từ 8
--     tuổi và tour 17, 20 từ 6 tuổi. Tour 11 và 13 chỉ bán vé người lớn.
--   * Tour 6 có 2 giờ khởi hành mỗi ngày (06:00 và 14:30): mọi mục lịch trình start_time NULL.
--   * Mọi lịch là 'open', capacity = remaining = max_group_size (chưa có đơn đặt).
--   * Chưa có đánh giá: ở tab "Nổi bật" các tour này đứng sau 8 tour đã có điểm của 02_seed.sql,
--     xếp theo tên.
--
-- Số dòng: users 7, providers 7, destinations 5, tours 20, cancellation_policies 20,
--          schedules 207, ticket_types 396, tour_packages 6, tour_itinerary_items 116,
--          tour_inclusions 118, tour_extras 20, tour_images 20. Không thêm dòng vào các bảng khác.
-- =====================================================================

SET NAMES utf8mb4;

START TRANSACTION;

-- ---------------------------------------------------------------------
-- 0. Xóa dữ liệu cũ của file này (chỉ các dòng có mã nhóm 0041), con trước cha.
-- ---------------------------------------------------------------------
DELETE FROM tour_images WHERE id LIKE '80000000-0041-%';
DELETE FROM tour_packages WHERE id LIKE 'f5000000-0041-%';
DELETE FROM ticket_types WHERE id LIKE 'e0000000-0041-%';
DELETE FROM schedules WHERE id LIKE 'd0000000-0041-%';
DELETE FROM cancellation_policies WHERE id LIKE 'f0000000-0041-%';
DELETE FROM tour_extras WHERE id LIKE 'c1000000-0041-%';
DELETE FROM tour_inclusions WHERE id LIKE 'c5000000-0041-%';
DELETE FROM tour_itinerary_items WHERE id LIKE 'c4000000-0041-%';
DELETE FROM tours WHERE id LIKE 'c0000000-0041-%';
DELETE FROM destinations WHERE id LIKE 'c2000000-0041-%';
DELETE FROM providers WHERE id LIKE 'b0000000-0041-%';
DELETE FROM users WHERE id LIKE 'a0000000-0041-%';

-- ---------------------------------------------------------------------
-- 1. users (NGƯỜI_DÙNG): tài khoản của nhà cung cấp 1-7, password_hash NULL.
-- ---------------------------------------------------------------------
INSERT INTO users (id, email, password_hash, name, phone, role, status) VALUES
('a0000000-0041-4000-8000-000000000011', 'loimonhoanglien@localtour.test', NULL, 'Lối Mòn Hoàng Liên', NULL, 'provider', 'active'),
('a0000000-0041-4000-8000-000000000012', 'ninhbinhcham@localtour.test', NULL, 'Ninh Bình Chậm', NULL, 'provider', 'active'),
('a0000000-0041-4000-8000-000000000013', 'codothongtha@localtour.test', NULL, 'Cố Đô Thong Thả', NULL, 'provider', 'active'),
('a0000000-0041-4000-8000-000000000014', 'phonuisuongmu@localtour.test', NULL, 'Phố Núi Sương Mù', NULL, 'provider', 'active'),
('a0000000-0041-4000-8000-000000000015', 'caonguyennguocgio@localtour.test', NULL, 'Cao Nguyên Ngược Gió', NULL, 'provider', 'active'),
('a0000000-0041-4000-8000-000000000016', 'ghexuongsommai@localtour.test', NULL, 'Ghe Xuồng Sớm Mai', NULL, 'provider', 'active'),
('a0000000-0041-4000-8000-000000000017', 'daongocrakhoi@localtour.test', NULL, 'Đảo Ngọc Ra Khơi', NULL, 'provider', 'active');

-- ---------------------------------------------------------------------
-- 2. providers (NHÀ_CUNG_CẤP): cả 7 đã được duyệt; contact_phone là số giả; chưa có tài khoản
--    nhận tiền (bank_* NULL, như nhà cung cấp của 02_seed.sql).
-- ---------------------------------------------------------------------
INSERT INTO providers (id, user_id, business_name, contact_phone, approval_status, approved_at) VALUES
('b0000000-0041-4000-8000-000000000001', 'a0000000-0041-4000-8000-000000000011', 'Lối Mòn Hoàng Liên', '0000000411', 'approved', NOW() - INTERVAL 320 DAY),
('b0000000-0041-4000-8000-000000000002', 'a0000000-0041-4000-8000-000000000012', 'Ninh Bình Chậm', '0000000412', 'approved', NOW() - INTERVAL 290 DAY),
('b0000000-0041-4000-8000-000000000003', 'a0000000-0041-4000-8000-000000000013', 'Cố Đô Thong Thả', '0000000413', 'approved', NOW() - INTERVAL 260 DAY),
('b0000000-0041-4000-8000-000000000004', 'a0000000-0041-4000-8000-000000000014', 'Phố Núi Sương Mù', '0000000414', 'approved', NOW() - INTERVAL 230 DAY),
('b0000000-0041-4000-8000-000000000005', 'a0000000-0041-4000-8000-000000000015', 'Cao Nguyên Ngược Gió', '0000000415', 'approved', NOW() - INTERVAL 180 DAY),
('b0000000-0041-4000-8000-000000000006', 'a0000000-0041-4000-8000-000000000016', 'Ghe Xuồng Sớm Mai', '0000000416', 'approved', NOW() - INTERVAL 150 DAY),
('b0000000-0041-4000-8000-000000000007', 'a0000000-0041-4000-8000-000000000017', 'Đảo Ngọc Ra Khơi', '0000000417', 'approved', NOW() - INTERVAL 120 DAY);

-- ---------------------------------------------------------------------
-- 3. destinations (ĐIỂM_ĐẾN): 5 điểm đến mới. sort_order xếp Bắc -> Nam cùng các điểm đến cũ
--    (Hà Nội 1, Huế 2, Đà Nẵng 3, Hội An 4, TP. Hồ Chí Minh 5); trùng sort_order thì xếp theo tên.
-- ---------------------------------------------------------------------
INSERT INTO destinations (id, name, slug, sort_order) VALUES
('c2000000-0041-4000-8000-000000000001', 'Sa Pa', 'sa-pa', 0),
('c2000000-0041-4000-8000-000000000002', 'Ninh Bình', 'ninh-binh', 1),
('c2000000-0041-4000-8000-000000000003', 'Đà Lạt', 'da-lat', 5),
('c2000000-0041-4000-8000-000000000004', 'Cần Thơ', 'can-tho', 6),
('c2000000-0041-4000-8000-000000000005', 'Phú Quốc', 'phu-quoc', 7);

-- ---------------------------------------------------------------------
-- 4. tours (TOUR): cùng cách ghi với mục 5 của 02_seed.sql. description = tóm tắt + dòng trống
--    + mô tả (CHAR(10) = xuống dòng). included_summary / excluded_summary NULL (dùng
--    tour_inclusions).
-- ---------------------------------------------------------------------
INSERT INTO tours (id, provider_id, destination_id, category_id, title, description, destination,
                   duration_minutes, max_group_size, language_codes, pickup_mode, meeting_point,
                   included_summary, transport, guide_info, dropoff_point, excluded_summary,
                   document_terms, meal_terms, voucher_terms, reschedule_terms,
                   source_url, verified_at, verification_status, approval_status) VALUES
-- Tour 1 (Sa Pa) ------------------------------------------------------
('c0000000-0041-4000-8000-000000000001', 'b0000000-0041-4000-8000-000000000001',
    'c2000000-0041-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000003',   -- Sa Pa, Thiên nhiên
    'Đi bộ thung lũng Mường Hoa: Lao Chải – Tả Van',
    CONCAT_WS(CHAR(10),
        'Một ngày đi bộ xuống thung lũng Mường Hoa, qua ruộng bậc thang và các bản của người H''Mông, người Giáy.',
        '',
        'Người dẫn đón nhóm tại khách sạn lúc 8 giờ sáng, đi bộ khoảng 12 km theo đường mòn xuống thung lũng Mường Hoa. Dọc đường đi qua ruộng bậc thang, rừng tre và các bản Lao Chải, Tả Van. Bữa trưa ăn tại nhà một gia đình trong bản. Cuối ngày xe đưa nhóm về lại thị trấn. Cung đường có đoạn dốc và trơn khi trời mưa, phù hợp với người có sức khỏe bình thường.'),
    'Sa Pa', 420, 12, 'vi,en,fr', 'hotel_pickup', 'Khách sạn ở trung tâm thị trấn Sa Pa',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ khoảng 12 km; xe 16 chỗ đưa nhóm về thị trấn cuối ngày',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh hoặc tiếng Pháp',
    'Khách sạn của khách ở trung tâm thị trấn Sa Pa',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Nên mang giày đi bộ có đế bám tốt.',
    'Gồm bữa trưa tại nhà một gia đình trong bản và nước uống trên đường. Báo trước nếu ăn chay.',
    'Xuất trình mã đặt chỗ (bản điện tử) cho người dẫn khi được đón.',
    'Đổi sang lịch khác miễn phí nếu báo trước ít nhất 24 giờ. Trời mưa lớn, người dẫn có thể đổi sang cung đường ngắn hơn.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 2 (Sa Pa) ------------------------------------------------------
('c0000000-0041-4000-8000-000000000002', 'b0000000-0041-4000-8000-000000000001',
    'c2000000-0041-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000005',   -- Sa Pa, Trải nghiệm địa phương
    'Bản Cát Cát lúc chiều muộn',
    CONCAT_WS(CHAR(10),
        'Đi bộ nhẹ xuống bản Cát Cát, xem dệt vải lanh, nhuộm chàm và nghe chuyện của người H''Mông.',
        '',
        'Từ nhà thờ đá, nhóm đi bộ khoảng 3 km xuống bản Cát Cát khi nắng đã dịu. Người dẫn giới thiệu nghề dệt vải lanh, nhuộm chàm và cách người H''Mông dựng nhà. Nhóm dừng ở thác nước cuối bản rồi đi taxi ngược dốc về lại trung tâm. Tour nhẹ nhàng, hợp với gia đình có trẻ nhỏ.'),
    'Sa Pa', 180, 10, 'vi,en', 'meeting_point', 'Nhà thờ đá Sa Pa',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ khoảng 3 km; taxi về lại trung tâm',
    'Người dẫn là người H''Mông ở Sa Pa, nói tiếng Việt và tiếng Anh',
    'Nhà thờ đá Sa Pa',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Không gồm bữa ăn. Có một ly trà gừng nóng ở cuối bản.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 12 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 3 (Sa Pa) ------------------------------------------------------
('c0000000-0041-4000-8000-000000000003', 'b0000000-0041-4000-8000-000000000001',
    'c2000000-0041-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001',   -- Sa Pa, Ẩm thực
    'Lẩu cá hồi và chợ đêm Sa Pa',
    CONCAT_WS(CHAR(10),
        'Ăn tối kiểu vùng cao: lẩu cá hồi, thịt xiên nướng và các món ở chợ đêm.',
        '',
        'Buổi tối Sa Pa se lạnh là lúc hợp nhất để ngồi bên nồi lẩu cá hồi nuôi bằng nước suối lạnh. Sau bữa chính, người dẫn đưa nhóm dạo chợ đêm, thử trứng nướng, khoai nướng, rượu ngô và mua vài món đặc sản mang về. Phù hợp với khách muốn biết người Sa Pa ăn gì vào buổi tối.'),
    'Sa Pa', 150, 8, 'vi,en,zh', 'meeting_point', 'Bờ hồ Sa Pa, phía đường Xuân Viên',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ trong khu trung tâm',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh hoặc tiếng Trung',
    'Chợ đêm Sa Pa',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Khách dưới 18 tuổi không dùng đồ uống có cồn.',
    'Gồm lẩu cá hồi (1 phần cho 2 khách), 4 món nướng ở chợ đêm và 1 đồ uống.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 4 (Ninh Bình) --------------------------------------------------
('c0000000-0041-4000-8000-000000000004', 'b0000000-0041-4000-8000-000000000002',
    'c2000000-0041-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000003',   -- Ninh Bình, Thiên nhiên
    'Tràng An và Hang Múa trọn ngày',
    CONCAT_WS(CHAR(10),
        'Ngồi thuyền qua các hang động Tràng An, ăn trưa cơm cháy, dê núi và leo Hang Múa ngắm toàn cảnh.',
        '',
        'Xe đón nhóm tại khách sạn lúc 8 giờ. Buổi sáng ngồi thuyền khoảng 2 giờ 30 phút trên sông ở khu danh thắng Tràng An, qua các hang xuyên thủy và đền nhỏ ven núi. Bữa trưa có cơm cháy và dê núi. Buổi chiều leo khoảng 500 bậc đá lên đỉnh Hang Múa để nhìn xuống cánh đồng và dòng sông. Nhóm nhỏ, nhịp đi vừa phải.'),
    'Ninh Bình', 480, 12, 'vi,en,fr,zh', 'hotel_pickup', 'Khách sạn ở thành phố Ninh Bình hoặc khu Tam Cốc',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe 16 chỗ đưa đón; thuyền chèo tay ở Tràng An (4 khách một thuyền)',
    'Hướng dẫn viên nói tiếng Việt, tiếng Anh, tiếng Pháp hoặc tiếng Trung',
    'Khách sạn của khách ở thành phố Ninh Bình hoặc khu Tam Cốc',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Nên mang mũ, kem chống nắng và giày đế bằng.',
    'Gồm bữa trưa (cơm cháy, dê núi, rau rừng) và nước uống. Có thực đơn chay nếu báo trước.',
    'Xuất trình mã đặt chỗ cho hướng dẫn viên khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ và lịch mới còn chỗ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 5 (Ninh Bình) --------------------------------------------------
('c0000000-0041-4000-8000-000000000005', 'b0000000-0041-4000-8000-000000000002',
    'c2000000-0041-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000005',   -- Ninh Bình, Trải nghiệm địa phương
    'Đạp xe làng quê Tam Cốc lúc hoàng hôn',
    CONCAT_WS(CHAR(10),
        'Đạp xe chậm qua đồng lúa, làng nhỏ và chân núi đá vôi, dừng ngắm hoàng hôn trên cánh đồng.',
        '',
        'Cung đường khoảng 15 km, gần như bằng phẳng, đi qua làng quê quanh Tam Cốc. Nhóm ghé một nhà nấu rượu, một ngôi chùa nhỏ dưới chân núi và dừng lại ở bờ ruộng khi mặt trời lặn. Xe đạp có giỏ và mũ bảo hiểm. Phù hợp cả với người lâu không đạp xe.'),
    'Ninh Bình', 180, 10, 'vi,en', 'meeting_point', 'Bến thuyền Tam Cốc',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe đạp (có mũ bảo hiểm), khoảng 15 km đường bằng',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Bến thuyền Tam Cốc',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Không gồm bữa ăn. Có nước suối và trái cây theo mùa.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 12 giờ. Trời mưa, tour được dời sang ngày khác.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 6 (Ninh Bình) --------------------------------------------------
('c0000000-0041-4000-8000-000000000006', 'b0000000-0041-4000-8000-000000000002',
    'c2000000-0041-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000003',   -- Ninh Bình, Thiên nhiên
    'Thuyền nan đầm Vân Long',
    CONCAT_WS(CHAR(10),
        'Ngồi thuyền nan trên đầm nước lặng giữa núi đá vôi, ngắm chim và tìm voọc mông trắng.',
        '',
        'Đầm Vân Long ít khách hơn các bến thuyền khác ở Ninh Bình, mặt nước phẳng và yên. Mỗi thuyền chở tối đa 2 khách, người chèo là người làng ven đầm. Chuyến sáng sớm có sương và nhiều chim; chuyến chiều có nắng đẹp để chụp ảnh. Nếu may mắn có thể thấy voọc mông trắng trên vách núi. Người dẫn mang ống nhòm cho cả nhóm.'),
    'Ninh Bình', 210, 8, 'vi,en,ja', 'meeting_point', 'Bến thuyền khu bảo tồn Vân Long',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Thuyền nan chèo tay, 2 khách một thuyền',
    'Người dẫn nói tiếng Việt, tiếng Anh hoặc tiếng Nhật',
    'Bến thuyền khu bảo tồn Vân Long',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Trẻ em đi cùng người lớn.',
    'Gồm trà nóng và bánh gạo trên thuyền.',
    'Xuất trình mã đặt chỗ cho người dẫn tại bến thuyền.',
    'Đổi giữa chuyến sáng và chuyến chiều miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 7 (Huế) --------------------------------------------------------
('c0000000-0041-4000-8000-000000000007', 'b0000000-0041-4000-8000-000000000003',
    'c2000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000002',   -- Huế, Văn hóa – lịch sử
    'Đại Nội và lăng vua Nguyễn trọn ngày',
    CONCAT_WS(CHAR(10),
        'Một ngày ở kinh thành và hai lăng vua, nghe kể chuyện triều Nguyễn qua từng công trình.',
        '',
        'Buổi sáng tham quan Đại Nội: Ngọ Môn, điện Thái Hòa, Tử Cấm Thành và vườn cây trong thành. Ăn trưa món Huế gần cửa Thượng Tứ. Buổi chiều đi lăng Tự Đức và lăng Khải Định, hai công trình có phong cách rất khác nhau. Chọn đi xe máy cùng người dẫn để len qua làng ven sông, hoặc đi ô tô có điều hòa.'),
    'Huế', 480, 10, 'vi,en,fr,zh', 'hotel_pickup', 'Khách sạn ở trung tâm thành phố Huế',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe máy (người dẫn lái) hoặc ô tô có điều hòa, tùy gói đã chọn',
    'Hướng dẫn viên nói tiếng Việt, tiếng Anh, tiếng Pháp hoặc tiếng Trung',
    'Khách sạn của khách ở trung tâm thành phố Huế',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Vào điện, lăng nên mặc áo có tay và quần dài qua gối.',
    'Gồm bữa trưa món Huế (bún bò hoặc cơm hến, bánh bèo, bánh nậm) và nước uống.',
    'Xuất trình mã đặt chỗ cho hướng dẫn viên khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 8 (Huế) --------------------------------------------------------
('c0000000-0041-4000-8000-000000000008', 'b0000000-0041-4000-8000-000000000003',
    'c2000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000004',   -- Huế, Về đêm
    'Thuyền rồng nghe ca Huế trên sông Hương',
    CONCAT_WS(CHAR(10),
        'Ngồi thuyền trên sông Hương buổi tối, nghe ca Huế và thả hoa đăng.',
        '',
        'Thuyền rời bến lúc trời vừa tối, chạy chậm về phía cầu Trường Tiền rồi dừng giữa sông. Nhóm nghệ nhân hát các làn điệu ca Huế với đàn tranh, đàn nguyệt và sáo. Cuối buổi mỗi khách thả một chiếc hoa đăng xuống sông. Người dẫn giải thích lời ca bằng tiếng Việt, tiếng Anh, tiếng Trung hoặc tiếng Hàn.'),
    'Huế', 120, 20, 'vi,en,zh,ko', 'meeting_point', 'Bến thuyền Tòa Khâm, đường Lê Lợi',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Thuyền rồng có mái che',
    'Người dẫn nói tiếng Việt, tiếng Anh, tiếng Trung hoặc tiếng Hàn; nhóm nghệ nhân ca Huế',
    'Bến thuyền Tòa Khâm',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm trà nóng và chè hạt sen.',
    'Xuất trình mã đặt chỗ tại bến thuyền.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 12 giờ. Mưa to hoặc nước sông lên cao, chuyến được dời sang tối khác.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 9 (Huế) --------------------------------------------------------
('c0000000-0041-4000-8000-000000000009', 'b0000000-0041-4000-8000-000000000003',
    'c2000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000001',   -- Huế, Ẩm thực
    'Ẩm thực đường phố Huế',
    CONCAT_WS(CHAR(10),
        'Bún bò, bánh khoái, các loại bánh bột lọc và chè Huế trong một buổi chiều.',
        '',
        'Bắt đầu ở chợ Đông Ba, nhóm đi bộ và ngồi xích lô qua các quán nhỏ trong thành phố. Thử bún bò, bánh bèo, bánh nậm, bánh lọc, bánh khoái và kết thúc bằng một chén chè trong con hẻm gần sông. Người dẫn kể cách người Huế ăn uống theo bữa, theo mùa.'),
    'Huế', 180, 8, 'vi,en,ja', 'meeting_point', 'Cổng chính chợ Đông Ba',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ kết hợp xích lô 30 phút',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh hoặc tiếng Nhật',
    'Khu vực cầu Trường Tiền',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm 6 món và 1 phần chè. Báo trước nếu ăn chay hoặc không ăn được cay.',
    'Xuất trình mã đặt chỗ cho người dẫn tại cổng chợ.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 10 (Đà Lạt) ----------------------------------------------------
('c0000000-0041-4000-8000-000000000010', 'b0000000-0041-4000-8000-000000000004',
    'c2000000-0041-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000005',   -- Đà Lạt, Trải nghiệm địa phương
    'Đà Lạt buổi sớm: chợ, vườn rau và cà phê',
    CONCAT_WS(CHAR(10),
        'Dậy sớm cùng người Đà Lạt: chợ sáng, vườn rau trên đồi và cà phê nhìn ra thung lũng.',
        '',
        'Tour bắt đầu khi phố còn sương. Nhóm đi chợ sáng xem rau, hoa và dâu tây từ các vườn quanh thành phố, ăn bánh căn nóng, rồi đi xe ra một vườn rau trên đồi để nghe người trồng kể chuyện làm nông ở cao nguyên. Cuối buổi ngồi cà phê ở một quán gỗ nhìn xuống thung lũng.'),
    'Đà Lạt', 240, 10, 'vi,en,ko', 'meeting_point', 'Bờ hồ Xuân Hương, phía chợ Đà Lạt',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ ở chợ; xe 7 chỗ ra vườn rau và quán cà phê',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh hoặc tiếng Hàn',
    'Bờ hồ Xuân Hương',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Buổi sớm trời lạnh, nên mang áo khoác.',
    'Gồm bữa sáng bánh căn, sữa đậu nành và 1 ly cà phê hoặc trà.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 11 (Đà Lạt) ----------------------------------------------------
('c0000000-0041-4000-8000-000000000011', 'b0000000-0041-4000-8000-000000000005',
    'c2000000-0041-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000003',   -- Đà Lạt, Thiên nhiên
    'Vượt thác bằng dây ở ngoại ô Đà Lạt',
    CONCAT_WS(CHAR(10),
        'Đu dây xuống thác, trượt máng đá tự nhiên và bơi trong hồ suối giữa rừng thông.',
        '',
        'Một ngày vận động ở con suối ngoài thành phố. Buổi sáng học kỹ thuật đu dây trên vách đá khô, sau đó đi xuống từng tầng thác cao từ 10 đến 25 m, trượt máng đá và nhảy xuống hồ nước sâu (có thể bỏ qua). Hướng dẫn viên có chứng chỉ cứu hộ, mỗi hướng dẫn viên phụ trách tối đa 4 khách. Yêu cầu biết bơi và đủ 16 tuổi.'),
    'Đà Lạt', 420, 12, 'vi,en,fr', 'hotel_pickup', 'Khách sạn ở trung tâm Đà Lạt',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe 16 chỗ đưa đón; đi bộ khoảng 2 km đường rừng',
    'Hướng dẫn viên có chứng chỉ cứu hộ, nói tiếng Việt, tiếng Anh hoặc tiếng Pháp',
    'Khách sạn của khách ở trung tâm Đà Lạt',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Mang giấy tờ tùy thân để làm bảo hiểm. Khách ký cam kết an toàn trước khi xuống thác.',
    'Gồm bữa trưa dã ngoại bên suối và nước uống.',
    'Xuất trình mã đặt chỗ cho hướng dẫn viên khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 48 giờ. Nước suối lên cao sau mưa lớn, tour được dời lịch.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 12 (Đà Lạt) ----------------------------------------------------
('c0000000-0041-4000-8000-000000000012', 'b0000000-0041-4000-8000-000000000004',
    'c2000000-0041-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000001',   -- Đà Lạt, Ẩm thực
    'Chợ đêm Đà Lạt và món ăn vặt',
    CONCAT_WS(CHAR(10),
        'Bánh tráng nướng, sữa đậu nành nóng, xiên nướng và chè trong một buổi tối se lạnh.',
        '',
        'Chợ đêm Đà Lạt đông nhất từ 7 giờ tối. Người dẫn đưa nhóm qua các sạp ăn vặt quen của người địa phương: bánh tráng nướng, bánh ướt lòng gà, xiên nướng, sữa đậu nành nóng và chè. Giữa buổi nhóm dừng trên dốc phố ngắm đèn bên hồ Xuân Hương.'),
    'Đà Lạt', 150, 10, 'vi,en,zh,ja', 'meeting_point', 'Bậc thang lên chợ đêm Đà Lạt',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ trong khu chợ và quanh hồ Xuân Hương',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh, tiếng Trung hoặc tiếng Nhật',
    'Chợ đêm Đà Lạt',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm 6 món ăn vặt và 1 ly sữa đậu nành hoặc chè.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 12 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 13 (Đà Lạt) ----------------------------------------------------
('c0000000-0041-4000-8000-000000000013', 'b0000000-0041-4000-8000-000000000005',
    'c2000000-0041-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000005',   -- Đà Lạt, Trải nghiệm địa phương
    'Xe máy qua làng hoa và đồi thông',
    CONCAT_WS(CHAR(10),
        'Ngồi sau xe máy cùng người lái địa phương, qua làng hoa, đồi thông, vườn cà phê và một thác nước nhỏ.',
        '',
        'Mỗi khách một xe máy và một người lái quen đường đèo. Lộ trình khoảng 80 km quanh Đà Lạt: làng hoa trồng trong nhà kính, đồi thông, một trại nuôi tằm dệt lụa, vườn cà phê arabica và một thác nước nhỏ. Bữa trưa cơm nhà ở một quán ven đường. Xe chạy chậm, dừng chụp ảnh khi khách muốn.'),
    'Đà Lạt', 420, 6, 'vi,en,ko,ja', 'meeting_point', 'Quảng trường Lâm Viên',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe máy (mỗi khách một xe, người lái địa phương), khoảng 80 km',
    'Người lái kiêm hướng dẫn, nói tiếng Việt, tiếng Anh, tiếng Hàn hoặc tiếng Nhật',
    'Quảng trường Lâm Viên hoặc khách sạn trong trung tâm',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Có mũ bảo hiểm đạt chuẩn và áo mưa cho khách.',
    'Gồm bữa trưa cơm nhà và nước uống. Báo trước nếu ăn chay.',
    'Xuất trình mã đặt chỗ cho người lái tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 14 (Cần Thơ) ---------------------------------------------------
('c0000000-0041-4000-8000-000000000014', 'b0000000-0041-4000-8000-000000000006',
    'c2000000-0041-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000005',   -- Cần Thơ, Trải nghiệm địa phương
    'Chợ nổi Cái Răng lúc bình minh',
    CONCAT_WS(CHAR(10),
        'Đi ghe ra chợ nổi khi trời vừa sáng, ăn hủ tiếu trên ghe và ghé lò hủ tiếu, vườn trái cây.',
        '',
        'Ghe rời bến Ninh Kiều lúc 5 giờ 30 sáng, chạy khoảng 30 phút tới chợ nổi Cái Răng khi các ghe buôn đang bán sỉ trái cây, rau củ. Khách ăn sáng hủ tiếu ngay trên ghe, mua trái cây từ ghe bạn. Sau chợ, nhóm ghé một lò làm hủ tiếu, đi xuồng nhỏ vào kênh rạch và dừng ở một vườn trái cây trước khi về lại bến.'),
    'Cần Thơ', 300, 15, 'vi,en,fr,ko', 'meeting_point', 'Bến Ninh Kiều',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Ghe máy có mái che (tối đa 15 khách); xuồng chèo trong kênh nhỏ',
    'Hướng dẫn viên nói tiếng Việt, tiếng Anh, tiếng Pháp hoặc tiếng Hàn',
    'Bến Ninh Kiều',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Có áo phao cho mọi khách; trẻ em mặc áo phao suốt chuyến.',
    'Gồm bữa sáng hủ tiếu trên ghe, cà phê và trái cây theo mùa.',
    'Xuất trình mã đặt chỗ cho hướng dẫn viên tại bến.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 15 (Cần Thơ) ---------------------------------------------------
('c0000000-0041-4000-8000-000000000015', 'b0000000-0041-4000-8000-000000000006',
    'c2000000-0041-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000003',   -- Cần Thơ, Thiên nhiên
    'Đạp xe vườn trái cây Phong Điền',
    CONCAT_WS(CHAR(10),
        'Đạp xe đường làng dưới tán dừa, qua cầu khỉ và ăn trái cây ngay tại vườn.',
        '',
        'Cung đường khoảng 18 km trên đường bê tông nhỏ ven kênh, có bóng mát gần như suốt đường. Nhóm ghé hai vườn trái cây theo mùa, xem làm bánh tráng và thử qua một cây cầu khỉ (có cầu bê tông bên cạnh). Bữa trưa nhẹ tại nhà vườn với cá lóc nướng và rau vườn.'),
    'Cần Thơ', 240, 10, 'vi,en', 'meeting_point', 'Chợ Phong Điền',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe đạp (có mũ bảo hiểm), khoảng 18 km đường làng',
    'Người dẫn địa phương nói tiếng Việt và tiếng Anh',
    'Chợ Phong Điền',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm bữa trưa nhẹ tại nhà vườn và trái cây theo mùa.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 12 giờ. Trời mưa lớn, tour được dời sang ngày khác.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 16 (Cần Thơ) ---------------------------------------------------
('c0000000-0041-4000-8000-000000000016', 'b0000000-0041-4000-8000-000000000006',
    'c2000000-0041-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000001',   -- Cần Thơ, Ẩm thực
    'Ẩm thực đêm bên bến Ninh Kiều',
    CONCAT_WS(CHAR(10),
        'Bánh xèo, ốc, lẩu mắm và chè bưởi: một buổi tối ăn như người Cần Thơ.',
        '',
        'Nhóm đi bộ dọc phố đi bộ và các con đường quanh chợ cổ, ghé quán bánh xèo, một quán ốc vỉa hè và một quán lẩu mắm nhỏ. Kết thúc bằng chè bưởi bên bờ sông. Người dẫn kể về chợ nổi, nghề ghe và đời sống ven sông Hậu.'),
    'Cần Thơ', 180, 8, 'vi,en,zh,ko', 'meeting_point', 'Phố đi bộ Hai Bà Trưng, gần chợ cổ Cần Thơ',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ khoảng 2 km',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh, tiếng Trung hoặc tiếng Hàn',
    'Bến Ninh Kiều',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm 5 món và 1 phần chè. Báo trước nếu ăn chay hoặc dị ứng hải sản.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 17 (Phú Quốc) --------------------------------------------------
('c0000000-0041-4000-8000-000000000017', 'b0000000-0041-4000-8000-000000000007',
    'c2000000-0041-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000003',   -- Phú Quốc, Thiên nhiên
    'Lặn ngắm san hô quần đảo An Thới',
    CONCAT_WS(CHAR(10),
        'Một ngày trên biển phía nam đảo: lặn ống thở ở hai điểm san hô, ăn trưa hải sản và tắm biển trên đảo nhỏ.',
        '',
        'Xe đón khách tại khách sạn lúc 8 giờ, đưa xuống cảng An Thới. Tàu chạy ra quần đảo phía nam, dừng ở hai điểm san hô nước nông để lặn ống thở hoặc câu cá. Bữa trưa hải sản nấu ngay trên tàu. Buổi chiều tắm biển và nghỉ trên một đảo nhỏ trước khi về cảng. Có áo phao và kính lặn cho mọi khách; người không biết bơi vẫn tham gia được với áo phao.'),
    'Phú Quốc', 480, 25, 'vi,en,zh', 'hotel_pickup', 'Khách sạn ở Dương Đông và Bãi Trường',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe đưa đón đến cảng An Thới; tàu gỗ hoặc ca nô tùy gói đã chọn',
    'Hướng dẫn viên nói tiếng Việt, tiếng Anh hoặc tiếng Trung; nhân viên cứu hộ trên tàu',
    'Khách sạn của khách ở Dương Đông hoặc Bãi Trường',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Mang giấy tờ tùy thân (căn cước hoặc hộ chiếu) để làm thủ tục ra đảo.',
    'Gồm bữa trưa hải sản trên tàu, nước suối và trái cây.',
    'Xuất trình mã đặt chỗ cho hướng dẫn viên khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 48 giờ. Biển động hoặc có cảnh báo thời tiết, tour được dời lịch.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 18 (Phú Quốc) --------------------------------------------------
('c0000000-0041-4000-8000-000000000018', 'b0000000-0041-4000-8000-000000000007',
    'c2000000-0041-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000004',   -- Phú Quốc, Về đêm
    'Hoàng hôn và câu mực đêm',
    CONCAT_WS(CHAR(10),
        'Ra khơi lúc chiều tà, ngắm hoàng hôn trên biển rồi thả câu mực dưới ánh đèn.',
        '',
        'Tàu rời bến khoảng 5 giờ 30 chiều, chạy ra vùng nước lặng ven bờ tây để ngắm mặt trời lặn. Khi trời tối, tàu bật đèn và thả neo, người dẫn chỉ cách câu mực bằng cần tay. Mực câu được nướng ngay trên tàu, ăn cùng cháo hải sản. Tàu về bến khoảng 8 giờ 30 tối, xe đưa khách về khách sạn.'),
    'Phú Quốc', 240, 20, 'vi,en,ja', 'hotel_pickup', 'Khách sạn ở khu vực Bãi Trường',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe đưa đón; tàu gỗ có mái che',
    'Hướng dẫn viên nói tiếng Việt, tiếng Anh hoặc tiếng Nhật',
    'Khách sạn của khách ở khu vực Bãi Trường',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Trẻ em mặc áo phao suốt chuyến.',
    'Gồm cháo hải sản, mực nướng (theo lượng câu được) và nước uống.',
    'Xuất trình mã đặt chỗ cho hướng dẫn viên khi được đón.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ. Biển động, chuyến được dời sang tối khác.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 19 (Phú Quốc) --------------------------------------------------
('c0000000-0041-4000-8000-000000000019', 'b0000000-0041-4000-8000-000000000007',
    'c2000000-0041-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005',   -- Phú Quốc, Trải nghiệm địa phương
    'Vườn tiêu, nhà thùng nước mắm và chợ Dương Đông',
    CONCAT_WS(CHAR(10),
        'Tìm hiểu hai đặc sản của đảo là hồ tiêu và nước mắm, rồi đi chợ Dương Đông cùng người địa phương.',
        '',
        'Nhóm đi xe ra một vườn tiêu của gia đình ở ngoại ô, xem cách trồng, phơi và phân loại tiêu. Sau đó ghé một nhà thùng ủ nước mắm truyền thống, nghe giải thích về cá cơm, muối và thời gian ủ. Cuối buổi đi chợ Dương Đông, thử bánh, hải sản khô và trái cây.'),
    'Phú Quốc', 210, 10, 'vi,en,zh,ja', 'meeting_point', 'Cổng chợ Dương Đông',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Xe 16 chỗ; đi bộ trong chợ',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh, tiếng Trung hoặc tiếng Nhật',
    'Cổng chợ Dương Đông',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân. Nước mắm mang lên máy bay cần đóng gói theo quy định của hãng bay.',
    'Gồm trà tiêu, trái cây và 3 món ăn vặt ở chợ.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved'),
-- Tour 20 (Huế) -------------------------------------------------------
('c0000000-0041-4000-8000-000000000020', 'b0000000-0041-4000-8000-000000000003',
    'c2000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000002',   -- Huế, Văn hóa – lịch sử
    'Làng hương Thủy Xuân và làm nón lá',
    CONCAT_WS(CHAR(10),
        'Xem làm nhang ở làng Thủy Xuân, tự tay chằm một chiếc nón lá và uống trà trong nhà vườn Huế.',
        '',
        'Buổi chiều ở vùng ven thành phố: người dẫn đưa nhóm qua các xưởng làm nhang nhiều màu, giải thích nguyên liệu và cách se nhang. Sau đó nhóm đến nhà một nghệ nhân làm nón, tự chằm vài vòng nón lá và mang về một chiếc nón bài thơ. Kết thúc bằng trà và bánh trong một nhà vườn có từ đầu thế kỷ trước.'),
    'Huế', 210, 10, 'vi,en,ja', 'meeting_point', 'Đầu làng hương Thủy Xuân',
    NULL,   -- included_summary: không dùng (tour_inclusions, mục 10)
    -- FR-02 phương tiện / hướng dẫn viên / điểm trả
    'Đi bộ trong làng; xe 7 chỗ giữa các điểm',
    'Người dẫn địa phương nói tiếng Việt, tiếng Anh hoặc tiếng Nhật',
    'Đầu làng hương Thủy Xuân',
    NULL,   -- excluded_summary: không dùng (tour_inclusions, mục 10)
    -- FR-05 giấy tờ / ăn uống / voucher / đổi lịch
    'Không yêu cầu giấy tờ tùy thân.',
    'Gồm trà và bánh Huế tại nhà vườn.',
    'Xuất trình mã đặt chỗ cho người dẫn tại điểm hẹn.',
    'Đổi lịch miễn phí nếu báo trước ít nhất 24 giờ.',
    NULL, NULL, 'unverified',   -- NFR-07: nguồn, ngày kiểm tra, trạng thái xác minh
    'approved');

-- ---------------------------------------------------------------------
-- 5. cancellation_policies (CHÍNH_SÁCH_HỦY): 1 phiên bản mỗi tour; id = số tour x 10 + 1.
-- ---------------------------------------------------------------------
INSERT INTO cancellation_policies (id, tour_id, free_before_hours, refund_percent, terms, version) VALUES
('f0000000-0041-4000-8000-000000000011', 'c0000000-0041-4000-8000-000000000001', 48, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 48 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000021', 'c0000000-0041-4000-8000-000000000002', 12, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 12 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000031', 'c0000000-0041-4000-8000-000000000003', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000041', 'c0000000-0041-4000-8000-000000000004', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000051', 'c0000000-0041-4000-8000-000000000005', 12, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 12 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000061', 'c0000000-0041-4000-8000-000000000006', 24, 50, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này được hoàn 50% giá trị đơn.', 1),
('f0000000-0041-4000-8000-000000000071', 'c0000000-0041-4000-8000-000000000007', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000081', 'c0000000-0041-4000-8000-000000000008', 12, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 12 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000091', 'c0000000-0041-4000-8000-000000000009', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000101', 'c0000000-0041-4000-8000-000000000010', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000111', 'c0000000-0041-4000-8000-000000000011', 48, 50, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 48 giờ. Hủy sau mốc này được hoàn 50% giá trị đơn.', 1),
('f0000000-0041-4000-8000-000000000121', 'c0000000-0041-4000-8000-000000000012', 12, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 12 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000131', 'c0000000-0041-4000-8000-000000000013', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000141', 'c0000000-0041-4000-8000-000000000014', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000151', 'c0000000-0041-4000-8000-000000000015', 12, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 12 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000161', 'c0000000-0041-4000-8000-000000000016', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000171', 'c0000000-0041-4000-8000-000000000017', 48, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 48 giờ. Hủy sau mốc này không được hoàn tiền. Tour được dời lịch nếu biển động, khách chọn lịch khác hoặc nhận lại toàn bộ tiền.', 1),
('f0000000-0041-4000-8000-000000000181', 'c0000000-0041-4000-8000-000000000018', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền. Tour được dời lịch nếu biển động, khách chọn lịch khác hoặc nhận lại toàn bộ tiền.', 1),
('f0000000-0041-4000-8000-000000000191', 'c0000000-0041-4000-8000-000000000019', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1),
('f0000000-0041-4000-8000-000000000201', 'c0000000-0041-4000-8000-000000000020', 24, 0, 'Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.', 1);

-- ---------------------------------------------------------------------
-- 6. tour_packages (GÓI_TOUR, file 16): tour 1, 7, 17. Khách phải chọn gói khi đặt; giá "Từ" =
--    giá người lớn thấp nhất của các gói. child_price_vnd NULL = gói không bán vé trẻ em.
-- ---------------------------------------------------------------------
INSERT INTO tour_packages (id, tour_id, name, description, adult_price_vnd, child_price_vnd, active, sort_order, created_at) VALUES
('f5000000-0041-4000-8000-000000000011', 'c0000000-0041-4000-8000-000000000001', 'Ghép đoàn',
    'Đi cùng các khách khác, tối đa 12 người một đoàn.',
    1190000, 830000, TRUE, 1, NOW()),
('f5000000-0041-4000-8000-000000000012', 'c0000000-0041-4000-8000-000000000001', 'Nhóm riêng',
    'Chỉ nhóm của bạn và người dẫn; được chọn cung đường ngắn (khoảng 8 km) hoặc dài (khoảng 12 km).',
    1890000, 1320000, TRUE, 2, NOW()),
('f5000000-0041-4000-8000-000000000071', 'c0000000-0041-4000-8000-000000000007', 'Xe máy cùng người dẫn',
    'Mỗi khách ngồi sau một xe máy do người dẫn lái, có mũ bảo hiểm và áo mưa. Không nhận trẻ em.',
    950000, NULL, TRUE, 1, NOW()),
('f5000000-0041-4000-8000-000000000072', 'c0000000-0041-4000-8000-000000000007', 'Ô tô có điều hòa',
    'Xe 7 chỗ hoặc 16 chỗ tùy số khách; phù hợp với gia đình có trẻ em.',
    1350000, 950000, TRUE, 2, NOW()),
('f5000000-0041-4000-8000-000000000171', 'c0000000-0041-4000-8000-000000000017', 'Tàu gỗ ghép đoàn',
    'Tàu gỗ 2 tầng, tối đa 25 khách, có nhà vệ sinh và chỗ nằm nghỉ.',
    1490000, 1040000, TRUE, 1, NOW()),
('f5000000-0041-4000-8000-000000000172', 'c0000000-0041-4000-8000-000000000017', 'Ca nô cao tốc',
    'Ca nô tối đa 12 khách, đi nhanh hơn và thêm một điểm lặn.',
    1890000, 1320000, TRUE, 2, NOW());

-- ---------------------------------------------------------------------
-- 7. schedules (LỊCH_KHỞI_HÀNH): starts_at = ngày (so với hôm nay) + giờ khởi hành; ends_at =
--    starts_at + duration_minutes. Mọi lịch 'open', remaining = capacity = max_group_size.
-- ---------------------------------------------------------------------
INSERT INTO schedules (id, tour_id, starts_at, ends_at, capacity, remaining, status) VALUES
-- Tour 1 (420 phút, 08:00; ngày +1, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000000101', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000102', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000103', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000104', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000105', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000106', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000107', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000108', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000109', 'c0000000-0041-4000-8000-000000000001',
    TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '15:00:00'), 12, 12, 'open'),
-- Tour 2 (180 phút, 14:30; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000000201', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000202', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000203', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000204', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000205', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000206', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000207', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000208', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000209', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000210', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000211', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000212', 'c0000000-0041-4000-8000-000000000002',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '17:30:00'), 10, 10, 'open'),
-- Tour 3 (150 phút, 18:30; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000000301', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000302', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000303', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000304', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000305', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000306', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000307', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000308', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000309', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000310', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000311', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000312', 'c0000000-0041-4000-8000-000000000003',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '18:30:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '21:00:00'), 8, 8, 'open'),
-- Tour 4 (480 phút, 08:00; ngày +2, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000000401', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000402', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000403', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000404', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000405', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000406', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000407', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000408', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '16:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000000409', 'c0000000-0041-4000-8000-000000000004',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '16:00:00'), 12, 12, 'open'),
-- Tour 5 (180 phút, 15:00; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000000501', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000502', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000503', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000504', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000505', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000506', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000507', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000508', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000509', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000510', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000511', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '18:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000512', 'c0000000-0041-4000-8000-000000000005',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '15:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '18:00:00'), 10, 10, 'open'),
-- Tour 6 (210 phút, 06:00 và 14:30; ngày +2, 6 ngày một lịch)
('d0000000-0041-4000-8000-000000000601', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '09:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000602', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '18:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000603', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '09:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000604', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 8 DAY, '18:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000605', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '09:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000606', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '18:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000607', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 20 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 20 DAY, '09:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000608', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 20 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 20 DAY, '18:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000609', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '09:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000610', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '18:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000611', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 32 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 32 DAY, '09:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000612', 'c0000000-0041-4000-8000-000000000006',
    TIMESTAMP(CURDATE() + INTERVAL 32 DAY, '14:30:00'), TIMESTAMP(CURDATE() + INTERVAL 32 DAY, '18:00:00'), 8, 8, 'open'),
-- Tour 7 (480 phút, 08:00; ngày +1, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000000701', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000702', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000703', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000704', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000705', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000706', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000707', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000708', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '16:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000000709', 'c0000000-0041-4000-8000-000000000007',
    TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '16:00:00'), 10, 10, 'open'),
-- Tour 8 (120 phút, 19:00; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000000801', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000802', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000803', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000804', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000805', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000806', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000807', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000808', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000809', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000810', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000811', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000000812', 'c0000000-0041-4000-8000-000000000008',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '21:00:00'), 20, 20, 'open'),
-- Tour 9 (180 phút, 15:30; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000000901', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000902', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000903', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000904', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000905', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000906', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000907', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000908', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000909', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000910', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000911', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '18:30:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000000912', 'c0000000-0041-4000-8000-000000000009',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '15:30:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '18:30:00'), 8, 8, 'open'),
-- Tour 10 (240 phút, 06:00; ngày +1, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000001001', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001002', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001003', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001004', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001005', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001006', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001007', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001008', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '10:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001009', 'c0000000-0041-4000-8000-000000000010',
    TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '06:00:00'), TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '10:00:00'), 10, 10, 'open'),
-- Tour 11 (420 phút, 08:00; ngày +2, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000001101', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001102', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001103', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001104', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001105', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001106', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001107', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001108', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '15:00:00'), 12, 12, 'open'),
('d0000000-0041-4000-8000-000000001109', 'c0000000-0041-4000-8000-000000000011',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '15:00:00'), 12, 12, 'open'),
-- Tour 12 (150 phút, 19:00; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000001201', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001202', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001203', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001204', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001205', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001206', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001207', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001208', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001209', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001210', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001211', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '21:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001212', 'c0000000-0041-4000-8000-000000000012',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '19:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '21:30:00'), 10, 10, 'open'),
-- Tour 13 (420 phút, 08:30; ngày +1, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000001301', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001302', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001303', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001304', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001305', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001306', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001307', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001308', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '15:30:00'), 6, 6, 'open'),
('d0000000-0041-4000-8000-000000001309', 'c0000000-0041-4000-8000-000000000013',
    TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '08:30:00'), TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '15:30:00'), 6, 6, 'open'),
-- Tour 14 (300 phút, 05:30; ngày +1, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000001401', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001402', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001403', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001404', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001405', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001406', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001407', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001408', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '10:30:00'), 15, 15, 'open'),
('d0000000-0041-4000-8000-000000001409', 'c0000000-0041-4000-8000-000000000014',
    TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '05:30:00'), TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '10:30:00'), 15, 15, 'open'),
-- Tour 15 (240 phút, 08:00; ngày +2, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000001501', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001502', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001503', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001504', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001505', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001506', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001507', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001508', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '12:00:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001509', 'c0000000-0041-4000-8000-000000000015',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '12:00:00'), 10, 10, 'open'),
-- Tour 16 (180 phút, 18:00; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000001601', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001602', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001603', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001604', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001605', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001606', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001607', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001608', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001609', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001610', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001611', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '21:00:00'), 8, 8, 'open'),
('d0000000-0041-4000-8000-000000001612', 'c0000000-0041-4000-8000-000000000016',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '18:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '21:00:00'), 8, 8, 'open'),
-- Tour 17 (480 phút, 08:00; ngày +2, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000001701', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001702', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001703', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001704', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001705', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001706', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001707', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001708', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '16:00:00'), 25, 25, 'open'),
('d0000000-0041-4000-8000-000000001709', 'c0000000-0041-4000-8000-000000000017',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '08:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '16:00:00'), 25, 25, 'open'),
-- Tour 18 (240 phút, 17:00; ngày +1, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000001801', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001802', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 5 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001803', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 9 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001804', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001805', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 17 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001806', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001807', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001808', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 29 DAY, '21:00:00'), 20, 20, 'open'),
('d0000000-0041-4000-8000-000000001809', 'c0000000-0041-4000-8000-000000000018',
    TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '17:00:00'), TIMESTAMP(CURDATE() + INTERVAL 33 DAY, '21:00:00'), 20, 20, 'open'),
-- Tour 19 (210 phút, 14:00; ngày +1, 3 ngày một lịch)
('d0000000-0041-4000-8000-000000001901', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001902', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 4 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001903', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001904', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001905', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 13 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001906', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 16 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001907', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 19 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001908', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001909', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 25 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001910', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 28 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001911', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 31 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000001912', 'c0000000-0041-4000-8000-000000000019',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '17:30:00'), 10, 10, 'open'),
-- Tour 20 (210 phút, 14:00; ngày +2, 4 ngày một lịch)
('d0000000-0041-4000-8000-000000002001', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002002', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002003', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 10 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002004', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002005', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 18 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002006', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 22 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002007', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 26 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002008', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '17:30:00'), 10, 10, 'open'),
('d0000000-0041-4000-8000-000000002009', 'c0000000-0041-4000-8000-000000000020',
    TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '14:00:00'), TIMESTAMP(CURDATE() + INTERVAL 34 DAY, '17:30:00'), 10, 10, 'open');

-- ---------------------------------------------------------------------
-- 8. ticket_types (VÉ_THEO_LỊCH): id = số lịch x 10 + 1 (người lớn) / + 2 (trẻ em).
--    Cùng một giá cho mọi lịch của tour. Tour 11 và 13 chỉ bán vé người lớn.
-- ---------------------------------------------------------------------
INSERT INTO ticket_types (id, schedule_id, name, min_age, max_age, price_vnd, active) VALUES
-- Tour 1
('e0000000-0041-4000-8000-000000001011', 'd0000000-0041-4000-8000-000000000101', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001012', 'd0000000-0041-4000-8000-000000000101', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001021', 'd0000000-0041-4000-8000-000000000102', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001022', 'd0000000-0041-4000-8000-000000000102', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001031', 'd0000000-0041-4000-8000-000000000103', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001032', 'd0000000-0041-4000-8000-000000000103', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001041', 'd0000000-0041-4000-8000-000000000104', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001042', 'd0000000-0041-4000-8000-000000000104', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001051', 'd0000000-0041-4000-8000-000000000105', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001052', 'd0000000-0041-4000-8000-000000000105', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001061', 'd0000000-0041-4000-8000-000000000106', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001062', 'd0000000-0041-4000-8000-000000000106', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001071', 'd0000000-0041-4000-8000-000000000107', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001072', 'd0000000-0041-4000-8000-000000000107', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001081', 'd0000000-0041-4000-8000-000000000108', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001082', 'd0000000-0041-4000-8000-000000000108', 'child', 8, 11, 830000, TRUE),
('e0000000-0041-4000-8000-000000001091', 'd0000000-0041-4000-8000-000000000109', 'adult', 12, NULL, 1190000, TRUE),
('e0000000-0041-4000-8000-000000001092', 'd0000000-0041-4000-8000-000000000109', 'child', 8, 11, 830000, TRUE),
-- Tour 2
('e0000000-0041-4000-8000-000000002011', 'd0000000-0041-4000-8000-000000000201', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002012', 'd0000000-0041-4000-8000-000000000201', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002021', 'd0000000-0041-4000-8000-000000000202', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002022', 'd0000000-0041-4000-8000-000000000202', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002031', 'd0000000-0041-4000-8000-000000000203', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002032', 'd0000000-0041-4000-8000-000000000203', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002041', 'd0000000-0041-4000-8000-000000000204', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002042', 'd0000000-0041-4000-8000-000000000204', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002051', 'd0000000-0041-4000-8000-000000000205', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002052', 'd0000000-0041-4000-8000-000000000205', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002061', 'd0000000-0041-4000-8000-000000000206', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002062', 'd0000000-0041-4000-8000-000000000206', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002071', 'd0000000-0041-4000-8000-000000000207', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002072', 'd0000000-0041-4000-8000-000000000207', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002081', 'd0000000-0041-4000-8000-000000000208', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002082', 'd0000000-0041-4000-8000-000000000208', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002091', 'd0000000-0041-4000-8000-000000000209', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002092', 'd0000000-0041-4000-8000-000000000209', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002101', 'd0000000-0041-4000-8000-000000000210', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002102', 'd0000000-0041-4000-8000-000000000210', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002111', 'd0000000-0041-4000-8000-000000000211', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002112', 'd0000000-0041-4000-8000-000000000211', 'child', 4, 11, 320000, TRUE),
('e0000000-0041-4000-8000-000000002121', 'd0000000-0041-4000-8000-000000000212', 'adult', 12, NULL, 450000, TRUE),
('e0000000-0041-4000-8000-000000002122', 'd0000000-0041-4000-8000-000000000212', 'child', 4, 11, 320000, TRUE),
-- Tour 3
('e0000000-0041-4000-8000-000000003011', 'd0000000-0041-4000-8000-000000000301', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003012', 'd0000000-0041-4000-8000-000000000301', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003021', 'd0000000-0041-4000-8000-000000000302', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003022', 'd0000000-0041-4000-8000-000000000302', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003031', 'd0000000-0041-4000-8000-000000000303', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003032', 'd0000000-0041-4000-8000-000000000303', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003041', 'd0000000-0041-4000-8000-000000000304', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003042', 'd0000000-0041-4000-8000-000000000304', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003051', 'd0000000-0041-4000-8000-000000000305', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003052', 'd0000000-0041-4000-8000-000000000305', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003061', 'd0000000-0041-4000-8000-000000000306', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003062', 'd0000000-0041-4000-8000-000000000306', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003071', 'd0000000-0041-4000-8000-000000000307', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003072', 'd0000000-0041-4000-8000-000000000307', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003081', 'd0000000-0041-4000-8000-000000000308', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003082', 'd0000000-0041-4000-8000-000000000308', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003091', 'd0000000-0041-4000-8000-000000000309', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003092', 'd0000000-0041-4000-8000-000000000309', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003101', 'd0000000-0041-4000-8000-000000000310', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003102', 'd0000000-0041-4000-8000-000000000310', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003111', 'd0000000-0041-4000-8000-000000000311', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003112', 'd0000000-0041-4000-8000-000000000311', 'child', 4, 11, 360000, TRUE),
('e0000000-0041-4000-8000-000000003121', 'd0000000-0041-4000-8000-000000000312', 'adult', 12, NULL, 520000, TRUE),
('e0000000-0041-4000-8000-000000003122', 'd0000000-0041-4000-8000-000000000312', 'child', 4, 11, 360000, TRUE),
-- Tour 4
('e0000000-0041-4000-8000-000000004011', 'd0000000-0041-4000-8000-000000000401', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004012', 'd0000000-0041-4000-8000-000000000401', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004021', 'd0000000-0041-4000-8000-000000000402', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004022', 'd0000000-0041-4000-8000-000000000402', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004031', 'd0000000-0041-4000-8000-000000000403', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004032', 'd0000000-0041-4000-8000-000000000403', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004041', 'd0000000-0041-4000-8000-000000000404', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004042', 'd0000000-0041-4000-8000-000000000404', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004051', 'd0000000-0041-4000-8000-000000000405', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004052', 'd0000000-0041-4000-8000-000000000405', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004061', 'd0000000-0041-4000-8000-000000000406', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004062', 'd0000000-0041-4000-8000-000000000406', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004071', 'd0000000-0041-4000-8000-000000000407', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004072', 'd0000000-0041-4000-8000-000000000407', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004081', 'd0000000-0041-4000-8000-000000000408', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004082', 'd0000000-0041-4000-8000-000000000408', 'child', 4, 11, 880000, TRUE),
('e0000000-0041-4000-8000-000000004091', 'd0000000-0041-4000-8000-000000000409', 'adult', 12, NULL, 1250000, TRUE),
('e0000000-0041-4000-8000-000000004092', 'd0000000-0041-4000-8000-000000000409', 'child', 4, 11, 880000, TRUE),
-- Tour 5
('e0000000-0041-4000-8000-000000005011', 'd0000000-0041-4000-8000-000000000501', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005012', 'd0000000-0041-4000-8000-000000000501', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005021', 'd0000000-0041-4000-8000-000000000502', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005022', 'd0000000-0041-4000-8000-000000000502', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005031', 'd0000000-0041-4000-8000-000000000503', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005032', 'd0000000-0041-4000-8000-000000000503', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005041', 'd0000000-0041-4000-8000-000000000504', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005042', 'd0000000-0041-4000-8000-000000000504', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005051', 'd0000000-0041-4000-8000-000000000505', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005052', 'd0000000-0041-4000-8000-000000000505', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005061', 'd0000000-0041-4000-8000-000000000506', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005062', 'd0000000-0041-4000-8000-000000000506', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005071', 'd0000000-0041-4000-8000-000000000507', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005072', 'd0000000-0041-4000-8000-000000000507', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005081', 'd0000000-0041-4000-8000-000000000508', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005082', 'd0000000-0041-4000-8000-000000000508', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005091', 'd0000000-0041-4000-8000-000000000509', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005092', 'd0000000-0041-4000-8000-000000000509', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005101', 'd0000000-0041-4000-8000-000000000510', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005102', 'd0000000-0041-4000-8000-000000000510', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005111', 'd0000000-0041-4000-8000-000000000511', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005112', 'd0000000-0041-4000-8000-000000000511', 'child', 8, 11, 290000, TRUE),
('e0000000-0041-4000-8000-000000005121', 'd0000000-0041-4000-8000-000000000512', 'adult', 12, NULL, 420000, TRUE),
('e0000000-0041-4000-8000-000000005122', 'd0000000-0041-4000-8000-000000000512', 'child', 8, 11, 290000, TRUE),
-- Tour 6
('e0000000-0041-4000-8000-000000006011', 'd0000000-0041-4000-8000-000000000601', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006012', 'd0000000-0041-4000-8000-000000000601', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006021', 'd0000000-0041-4000-8000-000000000602', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006022', 'd0000000-0041-4000-8000-000000000602', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006031', 'd0000000-0041-4000-8000-000000000603', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006032', 'd0000000-0041-4000-8000-000000000603', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006041', 'd0000000-0041-4000-8000-000000000604', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006042', 'd0000000-0041-4000-8000-000000000604', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006051', 'd0000000-0041-4000-8000-000000000605', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006052', 'd0000000-0041-4000-8000-000000000605', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006061', 'd0000000-0041-4000-8000-000000000606', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006062', 'd0000000-0041-4000-8000-000000000606', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006071', 'd0000000-0041-4000-8000-000000000607', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006072', 'd0000000-0041-4000-8000-000000000607', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006081', 'd0000000-0041-4000-8000-000000000608', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006082', 'd0000000-0041-4000-8000-000000000608', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006091', 'd0000000-0041-4000-8000-000000000609', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006092', 'd0000000-0041-4000-8000-000000000609', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006101', 'd0000000-0041-4000-8000-000000000610', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006102', 'd0000000-0041-4000-8000-000000000610', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006111', 'd0000000-0041-4000-8000-000000000611', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006112', 'd0000000-0041-4000-8000-000000000611', 'child', 4, 11, 480000, TRUE),
('e0000000-0041-4000-8000-000000006121', 'd0000000-0041-4000-8000-000000000612', 'adult', 12, NULL, 690000, TRUE),
('e0000000-0041-4000-8000-000000006122', 'd0000000-0041-4000-8000-000000000612', 'child', 4, 11, 480000, TRUE),
-- Tour 7
('e0000000-0041-4000-8000-000000007011', 'd0000000-0041-4000-8000-000000000701', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007012', 'd0000000-0041-4000-8000-000000000701', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007021', 'd0000000-0041-4000-8000-000000000702', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007022', 'd0000000-0041-4000-8000-000000000702', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007031', 'd0000000-0041-4000-8000-000000000703', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007032', 'd0000000-0041-4000-8000-000000000703', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007041', 'd0000000-0041-4000-8000-000000000704', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007042', 'd0000000-0041-4000-8000-000000000704', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007051', 'd0000000-0041-4000-8000-000000000705', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007052', 'd0000000-0041-4000-8000-000000000705', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007061', 'd0000000-0041-4000-8000-000000000706', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007062', 'd0000000-0041-4000-8000-000000000706', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007071', 'd0000000-0041-4000-8000-000000000707', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007072', 'd0000000-0041-4000-8000-000000000707', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007081', 'd0000000-0041-4000-8000-000000000708', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007082', 'd0000000-0041-4000-8000-000000000708', 'child', 4, 11, 950000, TRUE),
('e0000000-0041-4000-8000-000000007091', 'd0000000-0041-4000-8000-000000000709', 'adult', 12, NULL, 950000, TRUE),
('e0000000-0041-4000-8000-000000007092', 'd0000000-0041-4000-8000-000000000709', 'child', 4, 11, 950000, TRUE),
-- Tour 8
('e0000000-0041-4000-8000-000000008011', 'd0000000-0041-4000-8000-000000000801', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008012', 'd0000000-0041-4000-8000-000000000801', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008021', 'd0000000-0041-4000-8000-000000000802', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008022', 'd0000000-0041-4000-8000-000000000802', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008031', 'd0000000-0041-4000-8000-000000000803', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008032', 'd0000000-0041-4000-8000-000000000803', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008041', 'd0000000-0041-4000-8000-000000000804', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008042', 'd0000000-0041-4000-8000-000000000804', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008051', 'd0000000-0041-4000-8000-000000000805', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008052', 'd0000000-0041-4000-8000-000000000805', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008061', 'd0000000-0041-4000-8000-000000000806', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008062', 'd0000000-0041-4000-8000-000000000806', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008071', 'd0000000-0041-4000-8000-000000000807', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008072', 'd0000000-0041-4000-8000-000000000807', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008081', 'd0000000-0041-4000-8000-000000000808', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008082', 'd0000000-0041-4000-8000-000000000808', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008091', 'd0000000-0041-4000-8000-000000000809', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008092', 'd0000000-0041-4000-8000-000000000809', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008101', 'd0000000-0041-4000-8000-000000000810', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008102', 'd0000000-0041-4000-8000-000000000810', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008111', 'd0000000-0041-4000-8000-000000000811', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008112', 'd0000000-0041-4000-8000-000000000811', 'child', 4, 11, 220000, TRUE),
('e0000000-0041-4000-8000-000000008121', 'd0000000-0041-4000-8000-000000000812', 'adult', 12, NULL, 320000, TRUE),
('e0000000-0041-4000-8000-000000008122', 'd0000000-0041-4000-8000-000000000812', 'child', 4, 11, 220000, TRUE),
-- Tour 9
('e0000000-0041-4000-8000-000000009011', 'd0000000-0041-4000-8000-000000000901', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009012', 'd0000000-0041-4000-8000-000000000901', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009021', 'd0000000-0041-4000-8000-000000000902', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009022', 'd0000000-0041-4000-8000-000000000902', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009031', 'd0000000-0041-4000-8000-000000000903', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009032', 'd0000000-0041-4000-8000-000000000903', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009041', 'd0000000-0041-4000-8000-000000000904', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009042', 'd0000000-0041-4000-8000-000000000904', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009051', 'd0000000-0041-4000-8000-000000000905', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009052', 'd0000000-0041-4000-8000-000000000905', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009061', 'd0000000-0041-4000-8000-000000000906', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009062', 'd0000000-0041-4000-8000-000000000906', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009071', 'd0000000-0041-4000-8000-000000000907', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009072', 'd0000000-0041-4000-8000-000000000907', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009081', 'd0000000-0041-4000-8000-000000000908', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009082', 'd0000000-0041-4000-8000-000000000908', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009091', 'd0000000-0041-4000-8000-000000000909', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009092', 'd0000000-0041-4000-8000-000000000909', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009101', 'd0000000-0041-4000-8000-000000000910', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009102', 'd0000000-0041-4000-8000-000000000910', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009111', 'd0000000-0041-4000-8000-000000000911', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009112', 'd0000000-0041-4000-8000-000000000911', 'child', 4, 11, 330000, TRUE),
('e0000000-0041-4000-8000-000000009121', 'd0000000-0041-4000-8000-000000000912', 'adult', 12, NULL, 470000, TRUE),
('e0000000-0041-4000-8000-000000009122', 'd0000000-0041-4000-8000-000000000912', 'child', 4, 11, 330000, TRUE),
-- Tour 10
('e0000000-0041-4000-8000-000000010011', 'd0000000-0041-4000-8000-000000001001', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010012', 'd0000000-0041-4000-8000-000000001001', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010021', 'd0000000-0041-4000-8000-000000001002', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010022', 'd0000000-0041-4000-8000-000000001002', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010031', 'd0000000-0041-4000-8000-000000001003', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010032', 'd0000000-0041-4000-8000-000000001003', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010041', 'd0000000-0041-4000-8000-000000001004', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010042', 'd0000000-0041-4000-8000-000000001004', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010051', 'd0000000-0041-4000-8000-000000001005', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010052', 'd0000000-0041-4000-8000-000000001005', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010061', 'd0000000-0041-4000-8000-000000001006', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010062', 'd0000000-0041-4000-8000-000000001006', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010071', 'd0000000-0041-4000-8000-000000001007', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010072', 'd0000000-0041-4000-8000-000000001007', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010081', 'd0000000-0041-4000-8000-000000001008', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010082', 'd0000000-0041-4000-8000-000000001008', 'child', 4, 11, 460000, TRUE),
('e0000000-0041-4000-8000-000000010091', 'd0000000-0041-4000-8000-000000001009', 'adult', 12, NULL, 650000, TRUE),
('e0000000-0041-4000-8000-000000010092', 'd0000000-0041-4000-8000-000000001009', 'child', 4, 11, 460000, TRUE),
-- Tour 11
('e0000000-0041-4000-8000-000000011011', 'd0000000-0041-4000-8000-000000001101', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011021', 'd0000000-0041-4000-8000-000000001102', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011031', 'd0000000-0041-4000-8000-000000001103', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011041', 'd0000000-0041-4000-8000-000000001104', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011051', 'd0000000-0041-4000-8000-000000001105', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011061', 'd0000000-0041-4000-8000-000000001106', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011071', 'd0000000-0041-4000-8000-000000001107', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011081', 'd0000000-0041-4000-8000-000000001108', 'adult', 16, NULL, 1590000, TRUE),
('e0000000-0041-4000-8000-000000011091', 'd0000000-0041-4000-8000-000000001109', 'adult', 16, NULL, 1590000, TRUE),
-- Tour 12
('e0000000-0041-4000-8000-000000012011', 'd0000000-0041-4000-8000-000000001201', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012012', 'd0000000-0041-4000-8000-000000001201', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012021', 'd0000000-0041-4000-8000-000000001202', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012022', 'd0000000-0041-4000-8000-000000001202', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012031', 'd0000000-0041-4000-8000-000000001203', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012032', 'd0000000-0041-4000-8000-000000001203', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012041', 'd0000000-0041-4000-8000-000000001204', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012042', 'd0000000-0041-4000-8000-000000001204', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012051', 'd0000000-0041-4000-8000-000000001205', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012052', 'd0000000-0041-4000-8000-000000001205', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012061', 'd0000000-0041-4000-8000-000000001206', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012062', 'd0000000-0041-4000-8000-000000001206', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012071', 'd0000000-0041-4000-8000-000000001207', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012072', 'd0000000-0041-4000-8000-000000001207', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012081', 'd0000000-0041-4000-8000-000000001208', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012082', 'd0000000-0041-4000-8000-000000001208', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012091', 'd0000000-0041-4000-8000-000000001209', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012092', 'd0000000-0041-4000-8000-000000001209', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012101', 'd0000000-0041-4000-8000-000000001210', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012102', 'd0000000-0041-4000-8000-000000001210', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012111', 'd0000000-0041-4000-8000-000000001211', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012112', 'd0000000-0041-4000-8000-000000001211', 'child', 4, 11, 250000, TRUE),
('e0000000-0041-4000-8000-000000012121', 'd0000000-0041-4000-8000-000000001212', 'adult', 12, NULL, 350000, TRUE),
('e0000000-0041-4000-8000-000000012122', 'd0000000-0041-4000-8000-000000001212', 'child', 4, 11, 250000, TRUE),
-- Tour 13
('e0000000-0041-4000-8000-000000013011', 'd0000000-0041-4000-8000-000000001301', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013021', 'd0000000-0041-4000-8000-000000001302', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013031', 'd0000000-0041-4000-8000-000000001303', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013041', 'd0000000-0041-4000-8000-000000001304', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013051', 'd0000000-0041-4000-8000-000000001305', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013061', 'd0000000-0041-4000-8000-000000001306', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013071', 'd0000000-0041-4000-8000-000000001307', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013081', 'd0000000-0041-4000-8000-000000001308', 'adult', 12, NULL, 1020000, TRUE),
('e0000000-0041-4000-8000-000000013091', 'd0000000-0041-4000-8000-000000001309', 'adult', 12, NULL, 1020000, TRUE),
-- Tour 14
('e0000000-0041-4000-8000-000000014011', 'd0000000-0041-4000-8000-000000001401', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014012', 'd0000000-0041-4000-8000-000000001401', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014021', 'd0000000-0041-4000-8000-000000001402', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014022', 'd0000000-0041-4000-8000-000000001402', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014031', 'd0000000-0041-4000-8000-000000001403', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014032', 'd0000000-0041-4000-8000-000000001403', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014041', 'd0000000-0041-4000-8000-000000001404', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014042', 'd0000000-0041-4000-8000-000000001404', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014051', 'd0000000-0041-4000-8000-000000001405', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014052', 'd0000000-0041-4000-8000-000000001405', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014061', 'd0000000-0041-4000-8000-000000001406', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014062', 'd0000000-0041-4000-8000-000000001406', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014071', 'd0000000-0041-4000-8000-000000001407', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014072', 'd0000000-0041-4000-8000-000000001407', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014081', 'd0000000-0041-4000-8000-000000001408', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014082', 'd0000000-0041-4000-8000-000000001408', 'child', 4, 11, 520000, TRUE),
('e0000000-0041-4000-8000-000000014091', 'd0000000-0041-4000-8000-000000001409', 'adult', 12, NULL, 740000, TRUE),
('e0000000-0041-4000-8000-000000014092', 'd0000000-0041-4000-8000-000000001409', 'child', 4, 11, 520000, TRUE),
-- Tour 15
('e0000000-0041-4000-8000-000000015011', 'd0000000-0041-4000-8000-000000001501', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015012', 'd0000000-0041-4000-8000-000000001501', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015021', 'd0000000-0041-4000-8000-000000001502', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015022', 'd0000000-0041-4000-8000-000000001502', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015031', 'd0000000-0041-4000-8000-000000001503', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015032', 'd0000000-0041-4000-8000-000000001503', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015041', 'd0000000-0041-4000-8000-000000001504', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015042', 'd0000000-0041-4000-8000-000000001504', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015051', 'd0000000-0041-4000-8000-000000001505', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015052', 'd0000000-0041-4000-8000-000000001505', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015061', 'd0000000-0041-4000-8000-000000001506', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015062', 'd0000000-0041-4000-8000-000000001506', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015071', 'd0000000-0041-4000-8000-000000001507', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015072', 'd0000000-0041-4000-8000-000000001507', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015081', 'd0000000-0041-4000-8000-000000001508', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015082', 'd0000000-0041-4000-8000-000000001508', 'child', 8, 11, 410000, TRUE),
('e0000000-0041-4000-8000-000000015091', 'd0000000-0041-4000-8000-000000001509', 'adult', 12, NULL, 590000, TRUE),
('e0000000-0041-4000-8000-000000015092', 'd0000000-0041-4000-8000-000000001509', 'child', 8, 11, 410000, TRUE),
-- Tour 16
('e0000000-0041-4000-8000-000000016011', 'd0000000-0041-4000-8000-000000001601', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016012', 'd0000000-0041-4000-8000-000000001601', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016021', 'd0000000-0041-4000-8000-000000001602', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016022', 'd0000000-0041-4000-8000-000000001602', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016031', 'd0000000-0041-4000-8000-000000001603', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016032', 'd0000000-0041-4000-8000-000000001603', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016041', 'd0000000-0041-4000-8000-000000001604', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016042', 'd0000000-0041-4000-8000-000000001604', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016051', 'd0000000-0041-4000-8000-000000001605', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016052', 'd0000000-0041-4000-8000-000000001605', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016061', 'd0000000-0041-4000-8000-000000001606', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016062', 'd0000000-0041-4000-8000-000000001606', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016071', 'd0000000-0041-4000-8000-000000001607', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016072', 'd0000000-0041-4000-8000-000000001607', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016081', 'd0000000-0041-4000-8000-000000001608', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016082', 'd0000000-0041-4000-8000-000000001608', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016091', 'd0000000-0041-4000-8000-000000001609', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016092', 'd0000000-0041-4000-8000-000000001609', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016101', 'd0000000-0041-4000-8000-000000001610', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016102', 'd0000000-0041-4000-8000-000000001610', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016111', 'd0000000-0041-4000-8000-000000001611', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016112', 'd0000000-0041-4000-8000-000000001611', 'child', 4, 11, 270000, TRUE),
('e0000000-0041-4000-8000-000000016121', 'd0000000-0041-4000-8000-000000001612', 'adult', 12, NULL, 390000, TRUE),
('e0000000-0041-4000-8000-000000016122', 'd0000000-0041-4000-8000-000000001612', 'child', 4, 11, 270000, TRUE),
-- Tour 17
('e0000000-0041-4000-8000-000000017011', 'd0000000-0041-4000-8000-000000001701', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017012', 'd0000000-0041-4000-8000-000000001701', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017021', 'd0000000-0041-4000-8000-000000001702', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017022', 'd0000000-0041-4000-8000-000000001702', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017031', 'd0000000-0041-4000-8000-000000001703', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017032', 'd0000000-0041-4000-8000-000000001703', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017041', 'd0000000-0041-4000-8000-000000001704', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017042', 'd0000000-0041-4000-8000-000000001704', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017051', 'd0000000-0041-4000-8000-000000001705', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017052', 'd0000000-0041-4000-8000-000000001705', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017061', 'd0000000-0041-4000-8000-000000001706', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017062', 'd0000000-0041-4000-8000-000000001706', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017071', 'd0000000-0041-4000-8000-000000001707', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017072', 'd0000000-0041-4000-8000-000000001707', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017081', 'd0000000-0041-4000-8000-000000001708', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017082', 'd0000000-0041-4000-8000-000000001708', 'child', 6, 11, 1040000, TRUE),
('e0000000-0041-4000-8000-000000017091', 'd0000000-0041-4000-8000-000000001709', 'adult', 12, NULL, 1490000, TRUE),
('e0000000-0041-4000-8000-000000017092', 'd0000000-0041-4000-8000-000000001709', 'child', 6, 11, 1040000, TRUE),
-- Tour 18
('e0000000-0041-4000-8000-000000018011', 'd0000000-0041-4000-8000-000000001801', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018012', 'd0000000-0041-4000-8000-000000001801', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018021', 'd0000000-0041-4000-8000-000000001802', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018022', 'd0000000-0041-4000-8000-000000001802', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018031', 'd0000000-0041-4000-8000-000000001803', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018032', 'd0000000-0041-4000-8000-000000001803', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018041', 'd0000000-0041-4000-8000-000000001804', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018042', 'd0000000-0041-4000-8000-000000001804', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018051', 'd0000000-0041-4000-8000-000000001805', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018052', 'd0000000-0041-4000-8000-000000001805', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018061', 'd0000000-0041-4000-8000-000000001806', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018062', 'd0000000-0041-4000-8000-000000001806', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018071', 'd0000000-0041-4000-8000-000000001807', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018072', 'd0000000-0041-4000-8000-000000001807', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018081', 'd0000000-0041-4000-8000-000000001808', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018082', 'd0000000-0041-4000-8000-000000001808', 'child', 4, 11, 550000, TRUE),
('e0000000-0041-4000-8000-000000018091', 'd0000000-0041-4000-8000-000000001809', 'adult', 12, NULL, 790000, TRUE),
('e0000000-0041-4000-8000-000000018092', 'd0000000-0041-4000-8000-000000001809', 'child', 4, 11, 550000, TRUE),
-- Tour 19
('e0000000-0041-4000-8000-000000019011', 'd0000000-0041-4000-8000-000000001901', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019012', 'd0000000-0041-4000-8000-000000001901', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019021', 'd0000000-0041-4000-8000-000000001902', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019022', 'd0000000-0041-4000-8000-000000001902', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019031', 'd0000000-0041-4000-8000-000000001903', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019032', 'd0000000-0041-4000-8000-000000001903', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019041', 'd0000000-0041-4000-8000-000000001904', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019042', 'd0000000-0041-4000-8000-000000001904', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019051', 'd0000000-0041-4000-8000-000000001905', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019052', 'd0000000-0041-4000-8000-000000001905', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019061', 'd0000000-0041-4000-8000-000000001906', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019062', 'd0000000-0041-4000-8000-000000001906', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019071', 'd0000000-0041-4000-8000-000000001907', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019072', 'd0000000-0041-4000-8000-000000001907', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019081', 'd0000000-0041-4000-8000-000000001908', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019082', 'd0000000-0041-4000-8000-000000001908', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019091', 'd0000000-0041-4000-8000-000000001909', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019092', 'd0000000-0041-4000-8000-000000001909', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019101', 'd0000000-0041-4000-8000-000000001910', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019102', 'd0000000-0041-4000-8000-000000001910', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019111', 'd0000000-0041-4000-8000-000000001911', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019112', 'd0000000-0041-4000-8000-000000001911', 'child', 4, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000019121', 'd0000000-0041-4000-8000-000000001912', 'adult', 12, NULL, 550000, TRUE),
('e0000000-0041-4000-8000-000000019122', 'd0000000-0041-4000-8000-000000001912', 'child', 4, 11, 390000, TRUE),
-- Tour 20
('e0000000-0041-4000-8000-000000020011', 'd0000000-0041-4000-8000-000000002001', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020012', 'd0000000-0041-4000-8000-000000002001', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020021', 'd0000000-0041-4000-8000-000000002002', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020022', 'd0000000-0041-4000-8000-000000002002', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020031', 'd0000000-0041-4000-8000-000000002003', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020032', 'd0000000-0041-4000-8000-000000002003', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020041', 'd0000000-0041-4000-8000-000000002004', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020042', 'd0000000-0041-4000-8000-000000002004', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020051', 'd0000000-0041-4000-8000-000000002005', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020052', 'd0000000-0041-4000-8000-000000002005', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020061', 'd0000000-0041-4000-8000-000000002006', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020062', 'd0000000-0041-4000-8000-000000002006', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020071', 'd0000000-0041-4000-8000-000000002007', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020072', 'd0000000-0041-4000-8000-000000002007', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020081', 'd0000000-0041-4000-8000-000000002008', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020082', 'd0000000-0041-4000-8000-000000002008', 'child', 6, 11, 390000, TRUE),
('e0000000-0041-4000-8000-000000020091', 'd0000000-0041-4000-8000-000000002009', 'adult', 12, NULL, 560000, TRUE),
('e0000000-0041-4000-8000-000000020092', 'd0000000-0041-4000-8000-000000002009', 'child', 6, 11, 390000, TRUE);

-- ---------------------------------------------------------------------
-- 9. tour_itinerary_items (LỊCH_TRÌNH_TOUR) - FR-03: start_time = giờ khởi hành + thời lượng các
--    chặng trước; NULL = không ghi giờ (tour 6 có 2 giờ khởi hành; trả khách về khách sạn).
-- ---------------------------------------------------------------------
INSERT INTO tour_itinerary_items (id, tour_id, start_time, description, sort_order) VALUES
-- Tour 1 (lịch 08:00)
('c4000000-0041-4000-8000-000000000101', 'c0000000-0041-4000-8000-000000000001', '08:00:00',
    'Đón khách tại khách sạn ở trung tâm thị trấn Sa Pa', 1),
('c4000000-0041-4000-8000-000000000102', 'c0000000-0041-4000-8000-000000000001', '08:30:00',
    'Bắt đầu đi bộ xuống thung lũng Mường Hoa. Đường mòn đi giữa ruộng bậc thang, có điểm dừng chụp ảnh toàn cảnh thung lũng.', 2),
('c4000000-0041-4000-8000-000000000103', 'c0000000-0041-4000-8000-000000000001', '10:30:00',
    'Bản Lao Chải của người H''Mông. Ghé một nhà làm vải lanh, nghe kể về mùa cấy và mùa gặt trên ruộng bậc thang.', 3),
('c4000000-0041-4000-8000-000000000104', 'c0000000-0041-4000-8000-000000000001', '12:00:00',
    'Ăn trưa tại nhà một gia đình người Giáy', 4),
('c4000000-0041-4000-8000-000000000105', 'c0000000-0041-4000-8000-000000000001', '13:30:00',
    'Đi bộ sang bản Tả Van, qua cầu treo bắc qua suối Mường Hoa', 5),
('c4000000-0041-4000-8000-000000000106', 'c0000000-0041-4000-8000-000000000001', NULL,
    'Xe đưa nhóm về trả khách tại khách sạn', 6),
-- Tour 2 (lịch 14:30)
('c4000000-0041-4000-8000-000000000201', 'c0000000-0041-4000-8000-000000000002', '14:30:00',
    'Gặp nhau trước nhà thờ đá Sa Pa', 1),
('c4000000-0041-4000-8000-000000000202', 'c0000000-0041-4000-8000-000000000002', '14:45:00',
    'Đi bộ xuống bản Cát Cát theo con dốc lát đá, ngắm thung lũng lúc chiều', 2),
('c4000000-0041-4000-8000-000000000203', 'c0000000-0041-4000-8000-000000000002', '15:30:00',
    'Xem dệt vải lanh và nhuộm chàm. Người trong bản chỉ cách vẽ sáp ong lên vải trước khi nhuộm.', 3),
('c4000000-0041-4000-8000-000000000204', 'c0000000-0041-4000-8000-000000000002', '16:30:00',
    'Thác nước cuối bản, uống trà gừng nóng', 4),
('c4000000-0041-4000-8000-000000000205', 'c0000000-0041-4000-8000-000000000002', '17:30:00',
    'Kết thúc tại nhà thờ đá Sa Pa', 5),
-- Tour 3 (lịch 18:30)
('c4000000-0041-4000-8000-000000000301', 'c0000000-0041-4000-8000-000000000003', '18:30:00',
    'Gặp nhau ở bờ hồ Sa Pa', 1),
('c4000000-0041-4000-8000-000000000302', 'c0000000-0041-4000-8000-000000000003', '18:45:00',
    'Lẩu cá hồi trong một quán gia đình. Người dẫn kể chuyện nuôi cá hồi bằng nước suối lạnh ở vùng cao.', 2),
('c4000000-0041-4000-8000-000000000303', 'c0000000-0041-4000-8000-000000000003', '20:00:00',
    'Dạo chợ đêm, thử trứng nướng, khoai nướng và thịt xiên', 3),
('c4000000-0041-4000-8000-000000000304', 'c0000000-0041-4000-8000-000000000003', '20:40:00',
    'Một chén rượu ngô hoặc trà nóng (khách dưới 18 tuổi dùng trà)', 4),
('c4000000-0041-4000-8000-000000000305', 'c0000000-0041-4000-8000-000000000003', '21:00:00',
    'Kết thúc tại chợ đêm Sa Pa', 5),
-- Tour 4 (lịch 08:00)
('c4000000-0041-4000-8000-000000000401', 'c0000000-0041-4000-8000-000000000004', '08:00:00',
    'Đón khách tại khách sạn ở thành phố Ninh Bình hoặc khu Tam Cốc', 1),
('c4000000-0041-4000-8000-000000000402', 'c0000000-0041-4000-8000-000000000004', '08:45:00',
    'Ngồi thuyền ở Tràng An. Thuyền đi qua các hang xuyên thủy, dừng ở hai ngôi đền nhỏ ven núi.', 2),
('c4000000-0041-4000-8000-000000000403', 'c0000000-0041-4000-8000-000000000004', '11:30:00',
    'Ăn trưa cơm cháy, dê núi và rau rừng', 3),
('c4000000-0041-4000-8000-000000000404', 'c0000000-0041-4000-8000-000000000004', '13:00:00',
    'Leo khoảng 500 bậc đá lên đỉnh Hang Múa, ngắm cánh đồng và dòng sông bên dưới', 4),
('c4000000-0041-4000-8000-000000000405', 'c0000000-0041-4000-8000-000000000004', '15:00:00',
    'Nghỉ uống nước ở chân núi', 5),
('c4000000-0041-4000-8000-000000000406', 'c0000000-0041-4000-8000-000000000004', NULL,
    'Trả khách về khách sạn', 6),
-- Tour 5 (lịch 15:00)
('c4000000-0041-4000-8000-000000000501', 'c0000000-0041-4000-8000-000000000005', '15:00:00',
    'Gặp nhau ở bến thuyền Tam Cốc, nhận xe đạp và mũ bảo hiểm', 1),
('c4000000-0041-4000-8000-000000000502', 'c0000000-0041-4000-8000-000000000005', '15:20:00',
    'Đạp xe qua cánh đồng lúa dưới chân núi đá vôi', 2),
('c4000000-0041-4000-8000-000000000503', 'c0000000-0041-4000-8000-000000000005', '16:00:00',
    'Ghé một nhà nấu rượu trong làng', 3),
('c4000000-0041-4000-8000-000000000504', 'c0000000-0041-4000-8000-000000000005', '16:45:00',
    'Ngôi chùa nhỏ dưới chân núi', 4),
('c4000000-0041-4000-8000-000000000505', 'c0000000-0041-4000-8000-000000000005', '17:30:00',
    'Ngắm hoàng hôn trên bờ ruộng', 5),
('c4000000-0041-4000-8000-000000000506', 'c0000000-0041-4000-8000-000000000005', '18:00:00',
    'Trả xe tại bến thuyền Tam Cốc', 6),
-- Tour 6 (lịch 06:00 / 14:30)
('c4000000-0041-4000-8000-000000000601', 'c0000000-0041-4000-8000-000000000006', NULL,
    'Gặp nhau tại bến thuyền, người dẫn phát ống nhòm', 1),
('c4000000-0041-4000-8000-000000000602', 'c0000000-0041-4000-8000-000000000006', NULL,
    'Lên thuyền nan, mỗi thuyền 2 khách và một người chèo', 2),
('c4000000-0041-4000-8000-000000000603', 'c0000000-0041-4000-8000-000000000006', NULL,
    'Ngắm chim và tìm voọc mông trắng trên vách núi', 3),
('c4000000-0041-4000-8000-000000000604', 'c0000000-0041-4000-8000-000000000006', NULL,
    'Dừng ở một hang nhỏ ven đầm', 4),
('c4000000-0041-4000-8000-000000000605', 'c0000000-0041-4000-8000-000000000006', NULL,
    'Trà nóng và bánh gạo trên thuyền', 5),
('c4000000-0041-4000-8000-000000000606', 'c0000000-0041-4000-8000-000000000006', NULL,
    'Về lại bến thuyền', 6),
-- Tour 7 (lịch 08:00)
('c4000000-0041-4000-8000-000000000701', 'c0000000-0041-4000-8000-000000000007', '08:00:00',
    'Đón khách tại khách sạn ở trung tâm thành phố Huế', 1),
('c4000000-0041-4000-8000-000000000702', 'c0000000-0041-4000-8000-000000000007', '08:20:00',
    'Đại Nội: Ngọ Môn, điện Thái Hòa, Tử Cấm Thành. Người dẫn kể về đời sống trong cung thời Nguyễn.', 2),
('c4000000-0041-4000-8000-000000000703', 'c0000000-0041-4000-8000-000000000007', '11:30:00',
    'Ăn trưa món Huế gần cửa Thượng Tứ', 3),
('c4000000-0041-4000-8000-000000000704', 'c0000000-0041-4000-8000-000000000007', '13:00:00',
    'Lăng Tự Đức: hồ sen, nhà thủy tạ và khu lăng mộ giữa rừng thông', 4),
('c4000000-0041-4000-8000-000000000705', 'c0000000-0041-4000-8000-000000000007', '14:30:00',
    'Lăng Khải Định trên sườn đồi, nổi tiếng với các bức khảm sành sứ', 5),
('c4000000-0041-4000-8000-000000000706', 'c0000000-0041-4000-8000-000000000007', NULL,
    'Trả khách về khách sạn', 6),
-- Tour 8 (lịch 19:00)
('c4000000-0041-4000-8000-000000000801', 'c0000000-0041-4000-8000-000000000008', '19:00:00',
    'Gặp nhau tại bến thuyền Tòa Khâm', 1),
('c4000000-0041-4000-8000-000000000802', 'c0000000-0041-4000-8000-000000000008', '19:10:00',
    'Thuyền chạy chậm về phía cầu Trường Tiền', 2),
('c4000000-0041-4000-8000-000000000803', 'c0000000-0041-4000-8000-000000000008', '19:30:00',
    'Nghe ca Huế cùng đàn tranh, đàn nguyệt và sáo. Người dẫn giải thích lời ca.', 3),
('c4000000-0041-4000-8000-000000000804', 'c0000000-0041-4000-8000-000000000008', '20:30:00',
    'Thả hoa đăng xuống sông Hương', 4),
('c4000000-0041-4000-8000-000000000805', 'c0000000-0041-4000-8000-000000000008', '21:00:00',
    'Về lại bến thuyền Tòa Khâm', 5),
-- Tour 9 (lịch 15:30)
('c4000000-0041-4000-8000-000000000901', 'c0000000-0041-4000-8000-000000000009', '15:30:00',
    'Gặp nhau tại cổng chính chợ Đông Ba', 1),
('c4000000-0041-4000-8000-000000000902', 'c0000000-0041-4000-8000-000000000009', '15:45:00',
    'Bún bò trong chợ Đông Ba', 2),
('c4000000-0041-4000-8000-000000000903', 'c0000000-0041-4000-8000-000000000009', '16:30:00',
    'Ngồi xích lô qua các con phố quanh kinh thành', 3),
('c4000000-0041-4000-8000-000000000904', 'c0000000-0041-4000-8000-000000000009', '17:00:00',
    'Bánh bèo, bánh nậm, bánh lọc trong một quán gia đình. Người dẫn kể cách người Huế ăn theo mùa.', 4),
('c4000000-0041-4000-8000-000000000905', 'c0000000-0041-4000-8000-000000000009', '17:45:00',
    'Bánh khoái và chè Huế trong con hẻm gần sông', 5),
('c4000000-0041-4000-8000-000000000906', 'c0000000-0041-4000-8000-000000000009', '18:30:00',
    'Kết thúc tại khu vực cầu Trường Tiền', 6),
-- Tour 10 (lịch 06:00)
('c4000000-0041-4000-8000-000000001001', 'c0000000-0041-4000-8000-000000000010', '06:00:00',
    'Gặp nhau ở bờ hồ Xuân Hương', 1),
('c4000000-0041-4000-8000-000000001002', 'c0000000-0041-4000-8000-000000000010', '06:15:00',
    'Chợ sáng: rau, hoa và dâu tây từ các vườn quanh thành phố', 2),
('c4000000-0041-4000-8000-000000001003', 'c0000000-0041-4000-8000-000000000010', '07:00:00',
    'Bữa sáng bánh căn và sữa đậu nành nóng', 3),
('c4000000-0041-4000-8000-000000001004', 'c0000000-0041-4000-8000-000000000010', '07:45:00',
    'Vườn rau trên đồi. Người trồng kể chuyện làm nông ở cao nguyên.', 4),
('c4000000-0041-4000-8000-000000001005', 'c0000000-0041-4000-8000-000000000010', '09:00:00',
    'Cà phê ở quán gỗ nhìn xuống thung lũng', 5),
('c4000000-0041-4000-8000-000000001006', 'c0000000-0041-4000-8000-000000000010', '10:00:00',
    'Về lại bờ hồ Xuân Hương', 6),
-- Tour 11 (lịch 08:00)
('c4000000-0041-4000-8000-000000001101', 'c0000000-0041-4000-8000-000000000011', '08:00:00',
    'Đón khách tại khách sạn ở trung tâm Đà Lạt', 1),
('c4000000-0041-4000-8000-000000001102', 'c0000000-0041-4000-8000-000000000011', '08:45:00',
    'Học kỹ thuật đu dây trên vách đá khô cùng hướng dẫn viên', 2),
('c4000000-0041-4000-8000-000000001103', 'c0000000-0041-4000-8000-000000000011', '10:00:00',
    'Đu dây xuống các tầng thác cao từ 10 đến 25 m', 3),
('c4000000-0041-4000-8000-000000001104', 'c0000000-0041-4000-8000-000000000011', '12:00:00',
    'Ăn trưa dã ngoại bên suối', 4),
('c4000000-0041-4000-8000-000000001105', 'c0000000-0041-4000-8000-000000000011', '13:00:00',
    'Trượt máng đá và nhảy xuống hồ suối (không bắt buộc)', 5),
('c4000000-0041-4000-8000-000000001106', 'c0000000-0041-4000-8000-000000000011', NULL,
    'Trả khách về khách sạn', 6),
-- Tour 12 (lịch 19:00)
('c4000000-0041-4000-8000-000000001201', 'c0000000-0041-4000-8000-000000000012', '19:00:00',
    'Gặp nhau ở bậc thang lên chợ đêm Đà Lạt', 1),
('c4000000-0041-4000-8000-000000001202', 'c0000000-0041-4000-8000-000000000012', '19:15:00',
    'Bánh tráng nướng và xiên nướng', 2),
('c4000000-0041-4000-8000-000000001203', 'c0000000-0041-4000-8000-000000000012', '19:45:00',
    'Bánh ướt lòng gà trong một quán nhỏ', 3),
('c4000000-0041-4000-8000-000000001204', 'c0000000-0041-4000-8000-000000000012', '20:30:00',
    'Ngắm đèn bên hồ Xuân Hương từ dốc phố', 4),
('c4000000-0041-4000-8000-000000001205', 'c0000000-0041-4000-8000-000000000012', '21:00:00',
    'Sữa đậu nành nóng hoặc chè', 5),
('c4000000-0041-4000-8000-000000001206', 'c0000000-0041-4000-8000-000000000012', '21:30:00',
    'Kết thúc tại chợ đêm Đà Lạt', 6),
-- Tour 13 (lịch 08:30)
('c4000000-0041-4000-8000-000000001301', 'c0000000-0041-4000-8000-000000000013', '08:30:00',
    'Gặp nhau tại quảng trường Lâm Viên, nhận mũ bảo hiểm và áo mưa', 1),
('c4000000-0041-4000-8000-000000001302', 'c0000000-0041-4000-8000-000000000013', '09:00:00',
    'Làng hoa trồng trong nhà kính', 2),
('c4000000-0041-4000-8000-000000001303', 'c0000000-0041-4000-8000-000000000013', '10:30:00',
    'Đồi thông và trại nuôi tằm dệt lụa', 3),
('c4000000-0041-4000-8000-000000001304', 'c0000000-0041-4000-8000-000000000013', '12:00:00',
    'Ăn trưa cơm nhà ở quán ven đường', 4),
('c4000000-0041-4000-8000-000000001305', 'c0000000-0041-4000-8000-000000000013', '13:30:00',
    'Vườn cà phê arabica và thác nước nhỏ', 5),
('c4000000-0041-4000-8000-000000001306', 'c0000000-0041-4000-8000-000000000013', '15:30:00',
    'Về lại quảng trường Lâm Viên', 6),
-- Tour 14 (lịch 05:30)
('c4000000-0041-4000-8000-000000001401', 'c0000000-0041-4000-8000-000000000014', '05:30:00',
    'Lên ghe tại bến Ninh Kiều', 1),
('c4000000-0041-4000-8000-000000001402', 'c0000000-0041-4000-8000-000000000014', '06:00:00',
    'Chợ nổi Cái Răng: ghe buôn treo hàng trên cây bẹo để báo món bán', 2),
('c4000000-0041-4000-8000-000000001403', 'c0000000-0041-4000-8000-000000000014', '06:45:00',
    'Ăn sáng hủ tiếu ngay trên ghe', 3),
('c4000000-0041-4000-8000-000000001404', 'c0000000-0041-4000-8000-000000000014', '07:45:00',
    'Lò làm hủ tiếu ven sông', 4),
('c4000000-0041-4000-8000-000000001405', 'c0000000-0041-4000-8000-000000000014', '08:45:00',
    'Đi xuồng nhỏ vào kênh rạch, dừng ở một vườn trái cây', 5),
('c4000000-0041-4000-8000-000000001406', 'c0000000-0041-4000-8000-000000000014', '10:30:00',
    'Về lại bến Ninh Kiều', 6),
-- Tour 15 (lịch 08:00)
('c4000000-0041-4000-8000-000000001501', 'c0000000-0041-4000-8000-000000000015', '08:00:00',
    'Gặp nhau ở chợ Phong Điền, nhận xe đạp và mũ bảo hiểm', 1),
('c4000000-0041-4000-8000-000000001502', 'c0000000-0041-4000-8000-000000000015', '08:20:00',
    'Đạp xe ven kênh dưới tán dừa', 2),
('c4000000-0041-4000-8000-000000001503', 'c0000000-0041-4000-8000-000000000015', '09:15:00',
    'Vườn trái cây theo mùa, ăn trái cây ngay tại vườn', 3),
('c4000000-0041-4000-8000-000000001504', 'c0000000-0041-4000-8000-000000000015', '10:00:00',
    'Xem làm bánh tráng và qua cầu khỉ', 4),
('c4000000-0041-4000-8000-000000001505', 'c0000000-0041-4000-8000-000000000015', '10:45:00',
    'Ăn trưa nhẹ tại nhà vườn: cá lóc nướng và rau vườn', 5),
('c4000000-0041-4000-8000-000000001506', 'c0000000-0041-4000-8000-000000000015', '12:00:00',
    'Trả xe tại chợ Phong Điền', 6),
-- Tour 16 (lịch 18:00)
('c4000000-0041-4000-8000-000000001601', 'c0000000-0041-4000-8000-000000000016', '18:00:00',
    'Gặp nhau ở phố đi bộ Hai Bà Trưng', 1),
('c4000000-0041-4000-8000-000000001602', 'c0000000-0041-4000-8000-000000000016', '18:15:00',
    'Bánh xèo miền Tây cuốn rau vườn', 2),
('c4000000-0041-4000-8000-000000001603', 'c0000000-0041-4000-8000-000000000016', '19:00:00',
    'Ốc vỉa hè', 3),
('c4000000-0041-4000-8000-000000001604', 'c0000000-0041-4000-8000-000000000016', '19:45:00',
    'Lẩu mắm trong một quán nhỏ. Người dẫn kể về nghề ghe trên sông Hậu.', 4),
('c4000000-0041-4000-8000-000000001605', 'c0000000-0041-4000-8000-000000000016', '20:30:00',
    'Chè bưởi bên bờ sông', 5),
('c4000000-0041-4000-8000-000000001606', 'c0000000-0041-4000-8000-000000000016', '21:00:00',
    'Kết thúc tại bến Ninh Kiều', 6),
-- Tour 17 (lịch 08:00)
('c4000000-0041-4000-8000-000000001701', 'c0000000-0041-4000-8000-000000000017', '08:00:00',
    'Đón khách tại khách sạn ở Dương Đông hoặc Bãi Trường', 1),
('c4000000-0041-4000-8000-000000001702', 'c0000000-0041-4000-8000-000000000017', '09:00:00',
    'Lên tàu tại cảng An Thới', 2),
('c4000000-0041-4000-8000-000000001703', 'c0000000-0041-4000-8000-000000000017', '10:00:00',
    'Điểm san hô thứ nhất: lặn ống thở hoặc ngắm san hô từ tàu', 3),
('c4000000-0041-4000-8000-000000001704', 'c0000000-0041-4000-8000-000000000017', '11:30:00',
    'Điểm san hô thứ hai, câu cá bằng cần tay', 4),
('c4000000-0041-4000-8000-000000001705', 'c0000000-0041-4000-8000-000000000017', '12:30:00',
    'Ăn trưa hải sản nấu trên tàu', 5),
('c4000000-0041-4000-8000-000000001706', 'c0000000-0041-4000-8000-000000000017', '13:30:00',
    'Tắm biển và nghỉ trên một đảo nhỏ', 6),
('c4000000-0041-4000-8000-000000001707', 'c0000000-0041-4000-8000-000000000017', NULL,
    'Trả khách về khách sạn', 7),
-- Tour 18 (lịch 17:00)
('c4000000-0041-4000-8000-000000001801', 'c0000000-0041-4000-8000-000000000018', '17:00:00',
    'Đón khách tại khách sạn ở khu vực Bãi Trường', 1),
('c4000000-0041-4000-8000-000000001802', 'c0000000-0041-4000-8000-000000000018', '17:30:00',
    'Tàu rời bến, chạy ra vùng nước lặng ven bờ tây', 2),
('c4000000-0041-4000-8000-000000001803', 'c0000000-0041-4000-8000-000000000018', '18:00:00',
    'Ngắm hoàng hôn trên biển', 3),
('c4000000-0041-4000-8000-000000001804', 'c0000000-0041-4000-8000-000000000018', '19:00:00',
    'Câu mực dưới ánh đèn, người dẫn chỉ cách dùng cần tay', 4),
('c4000000-0041-4000-8000-000000001805', 'c0000000-0041-4000-8000-000000000018', '20:00:00',
    'Mực nướng và cháo hải sản trên tàu', 5),
('c4000000-0041-4000-8000-000000001806', 'c0000000-0041-4000-8000-000000000018', NULL,
    'Trả khách về khách sạn', 6),
-- Tour 19 (lịch 14:00)
('c4000000-0041-4000-8000-000000001901', 'c0000000-0041-4000-8000-000000000019', '14:00:00',
    'Gặp nhau ở cổng chợ Dương Đông', 1),
('c4000000-0041-4000-8000-000000001902', 'c0000000-0041-4000-8000-000000000019', '14:30:00',
    'Vườn tiêu của gia đình: cách trồng, phơi và phân loại tiêu', 2),
('c4000000-0041-4000-8000-000000001903', 'c0000000-0041-4000-8000-000000000019', '15:30:00',
    'Nhà thùng ủ nước mắm. Nghe giải thích về cá cơm, muối và thời gian ủ.', 3),
('c4000000-0041-4000-8000-000000001904', 'c0000000-0041-4000-8000-000000000019', '16:30:00',
    'Chợ Dương Đông: bánh, hải sản khô và trái cây', 4),
('c4000000-0041-4000-8000-000000001905', 'c0000000-0041-4000-8000-000000000019', '17:30:00',
    'Kết thúc tại cổng chợ Dương Đông', 5),
-- Tour 20 (lịch 14:00)
('c4000000-0041-4000-8000-000000002001', 'c0000000-0041-4000-8000-000000000020', '14:00:00',
    'Gặp nhau ở đầu làng hương Thủy Xuân', 1),
('c4000000-0041-4000-8000-000000002002', 'c0000000-0041-4000-8000-000000000020', '14:15:00',
    'Xưởng làm nhang: nguyên liệu, cách se và nhuộm màu nhang', 2),
('c4000000-0041-4000-8000-000000002003', 'c0000000-0041-4000-8000-000000000020', '15:15:00',
    'Chằm nón lá cùng nghệ nhân, mỗi khách mang về một chiếc nón bài thơ', 3),
('c4000000-0041-4000-8000-000000002004', 'c0000000-0041-4000-8000-000000000020', '16:30:00',
    'Trà và bánh Huế trong một nhà vườn', 4),
('c4000000-0041-4000-8000-000000002005', 'c0000000-0041-4000-8000-000000000020', '17:30:00',
    'Kết thúc tại đầu làng hương Thủy Xuân', 5);

-- ---------------------------------------------------------------------
-- 10. tour_inclusions (DỊCH_VỤ_BAO_GỒM): is_included TRUE = đã gồm trong giá, FALSE = không bao
--     gồm; sort_order 1, 2, ... trong từng nhóm.
-- ---------------------------------------------------------------------
INSERT INTO tour_inclusions (id, tour_id, item_text, is_included, sort_order) VALUES
-- Tour 1: 4 mục bao gồm, 3 mục không bao gồm
('c5000000-0041-4000-8000-000000000101', 'c0000000-0041-4000-8000-000000000001', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000000102', 'c0000000-0041-4000-8000-000000000001', 'Bữa trưa và nước uống', TRUE, 2),
('c5000000-0041-4000-8000-000000000103', 'c0000000-0041-4000-8000-000000000001', 'Xe đưa về thị trấn cuối ngày', TRUE, 3),
('c5000000-0041-4000-8000-000000000104', 'c0000000-0041-4000-8000-000000000001', 'Vé vào các bản', TRUE, 4),
('c5000000-0041-4000-8000-000000000105', 'c0000000-0041-4000-8000-000000000001', 'Thuê áo mưa, gậy đi bộ', FALSE, 1),
('c5000000-0041-4000-8000-000000000106', 'c0000000-0041-4000-8000-000000000001', 'Đồ uống gọi thêm', FALSE, 2),
('c5000000-0041-4000-8000-000000000107', 'c0000000-0041-4000-8000-000000000001', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 3),
-- Tour 2: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000000201', 'c0000000-0041-4000-8000-000000000002', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000000202', 'c0000000-0041-4000-8000-000000000002', 'Vé vào bản Cát Cát', TRUE, 2),
('c5000000-0041-4000-8000-000000000203', 'c0000000-0041-4000-8000-000000000002', '1 ly trà gừng', TRUE, 3),
('c5000000-0041-4000-8000-000000000204', 'c0000000-0041-4000-8000-000000000002', 'Taxi về lại trung tâm', TRUE, 4),
('c5000000-0041-4000-8000-000000000205', 'c0000000-0041-4000-8000-000000000002', 'Đồ thủ công mua tại bản', FALSE, 1),
('c5000000-0041-4000-8000-000000000206', 'c0000000-0041-4000-8000-000000000002', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 3: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000000301', 'c0000000-0041-4000-8000-000000000003', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000000302', 'c0000000-0041-4000-8000-000000000003', 'Lẩu cá hồi (1 phần cho 2 khách)', TRUE, 2),
('c5000000-0041-4000-8000-000000000303', 'c0000000-0041-4000-8000-000000000003', '4 món nướng ở chợ đêm', TRUE, 3),
('c5000000-0041-4000-8000-000000000304', 'c0000000-0041-4000-8000-000000000003', '1 đồ uống', TRUE, 4),
('c5000000-0041-4000-8000-000000000305', 'c0000000-0041-4000-8000-000000000003', 'Đồ uống gọi thêm', FALSE, 1),
('c5000000-0041-4000-8000-000000000306', 'c0000000-0041-4000-8000-000000000003', 'Đặc sản mua mang về', FALSE, 2),
-- Tour 4: 5 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000000401', 'c0000000-0041-4000-8000-000000000004', 'Xe đưa đón tại khách sạn', TRUE, 1),
('c5000000-0041-4000-8000-000000000402', 'c0000000-0041-4000-8000-000000000004', 'Vé thuyền Tràng An', TRUE, 2),
('c5000000-0041-4000-8000-000000000403', 'c0000000-0041-4000-8000-000000000004', 'Vé tham quan Hang Múa', TRUE, 3),
('c5000000-0041-4000-8000-000000000404', 'c0000000-0041-4000-8000-000000000004', 'Bữa trưa', TRUE, 4),
('c5000000-0041-4000-8000-000000000405', 'c0000000-0041-4000-8000-000000000004', 'Hướng dẫn viên', TRUE, 5),
('c5000000-0041-4000-8000-000000000406', 'c0000000-0041-4000-8000-000000000004', 'Đồ uống gọi thêm trong bữa trưa', FALSE, 1),
('c5000000-0041-4000-8000-000000000407', 'c0000000-0041-4000-8000-000000000004', 'Tiền tip cho người chèo thuyền và hướng dẫn viên (tùy ý)', FALSE, 2),
-- Tour 5: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000000501', 'c0000000-0041-4000-8000-000000000005', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000000502', 'c0000000-0041-4000-8000-000000000005', 'Xe đạp và mũ bảo hiểm', TRUE, 2),
('c5000000-0041-4000-8000-000000000503', 'c0000000-0041-4000-8000-000000000005', 'Nước suối và trái cây', TRUE, 3),
('c5000000-0041-4000-8000-000000000504', 'c0000000-0041-4000-8000-000000000005', 'Vé thuyền Tam Cốc (không có trong tour)', FALSE, 1),
('c5000000-0041-4000-8000-000000000505', 'c0000000-0041-4000-8000-000000000005', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 6: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000000601', 'c0000000-0041-4000-8000-000000000006', 'Người dẫn', TRUE, 1),
('c5000000-0041-4000-8000-000000000602', 'c0000000-0041-4000-8000-000000000006', 'Vé vào khu bảo tồn và vé thuyền', TRUE, 2),
('c5000000-0041-4000-8000-000000000603', 'c0000000-0041-4000-8000-000000000006', 'Ống nhòm dùng chung', TRUE, 3),
('c5000000-0041-4000-8000-000000000604', 'c0000000-0041-4000-8000-000000000006', 'Trà và bánh gạo', TRUE, 4),
('c5000000-0041-4000-8000-000000000605', 'c0000000-0041-4000-8000-000000000006', 'Xe đến bến thuyền', FALSE, 1),
('c5000000-0041-4000-8000-000000000606', 'c0000000-0041-4000-8000-000000000006', 'Tiền tip cho người chèo thuyền (tùy ý)', FALSE, 2),
-- Tour 7: 4 mục bao gồm, 3 mục không bao gồm
('c5000000-0041-4000-8000-000000000701', 'c0000000-0041-4000-8000-000000000007', 'Hướng dẫn viên', TRUE, 1),
('c5000000-0041-4000-8000-000000000702', 'c0000000-0041-4000-8000-000000000007', 'Xe máy hoặc ô tô theo gói đã chọn', TRUE, 2),
('c5000000-0041-4000-8000-000000000703', 'c0000000-0041-4000-8000-000000000007', 'Vé vào Đại Nội và 2 lăng', TRUE, 3),
('c5000000-0041-4000-8000-000000000704', 'c0000000-0041-4000-8000-000000000007', 'Bữa trưa và nước uống', TRUE, 4),
('c5000000-0041-4000-8000-000000000705', 'c0000000-0041-4000-8000-000000000007', 'Đồ uống gọi thêm', FALSE, 1),
('c5000000-0041-4000-8000-000000000706', 'c0000000-0041-4000-8000-000000000007', 'Chi phí cá nhân', FALSE, 2),
('c5000000-0041-4000-8000-000000000707', 'c0000000-0041-4000-8000-000000000007', 'Tiền tip cho hướng dẫn viên (tùy ý)', FALSE, 3),
-- Tour 8: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000000801', 'c0000000-0041-4000-8000-000000000008', 'Vé thuyền', TRUE, 1),
('c5000000-0041-4000-8000-000000000802', 'c0000000-0041-4000-8000-000000000008', 'Chương trình ca Huế khoảng 1 giờ', TRUE, 2),
('c5000000-0041-4000-8000-000000000803', 'c0000000-0041-4000-8000-000000000008', 'Trà và chè hạt sen', TRUE, 3),
('c5000000-0041-4000-8000-000000000804', 'c0000000-0041-4000-8000-000000000008', '1 hoa đăng mỗi khách', TRUE, 4),
('c5000000-0041-4000-8000-000000000805', 'c0000000-0041-4000-8000-000000000008', 'Xe đến bến thuyền', FALSE, 1),
('c5000000-0041-4000-8000-000000000806', 'c0000000-0041-4000-8000-000000000008', 'Tiền tip cho nghệ nhân (tùy ý)', FALSE, 2),
-- Tour 9: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000000901', 'c0000000-0041-4000-8000-000000000009', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000000902', 'c0000000-0041-4000-8000-000000000009', '6 món ăn và 1 phần chè', TRUE, 2),
('c5000000-0041-4000-8000-000000000903', 'c0000000-0041-4000-8000-000000000009', 'Xích lô 30 phút', TRUE, 3),
('c5000000-0041-4000-8000-000000000904', 'c0000000-0041-4000-8000-000000000009', 'Đồ uống gọi thêm', FALSE, 1),
('c5000000-0041-4000-8000-000000000905', 'c0000000-0041-4000-8000-000000000009', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 10: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001001', 'c0000000-0041-4000-8000-000000000010', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000001002', 'c0000000-0041-4000-8000-000000000010', 'Xe 7 chỗ', TRUE, 2),
('c5000000-0041-4000-8000-000000001003', 'c0000000-0041-4000-8000-000000000010', 'Bữa sáng và 1 đồ uống', TRUE, 3),
('c5000000-0041-4000-8000-000000001004', 'c0000000-0041-4000-8000-000000000010', 'Rau, hoa mua mang về', FALSE, 1),
('c5000000-0041-4000-8000-000000001005', 'c0000000-0041-4000-8000-000000000010', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 11: 5 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001101', 'c0000000-0041-4000-8000-000000000011', 'Xe đưa đón', TRUE, 1),
('c5000000-0041-4000-8000-000000001102', 'c0000000-0041-4000-8000-000000000011', 'Hướng dẫn viên và thiết bị an toàn', TRUE, 2),
('c5000000-0041-4000-8000-000000001103', 'c0000000-0041-4000-8000-000000000011', 'Bảo hiểm du lịch trong ngày', TRUE, 3),
('c5000000-0041-4000-8000-000000001104', 'c0000000-0041-4000-8000-000000000011', 'Bữa trưa và nước uống', TRUE, 4),
('c5000000-0041-4000-8000-000000001105', 'c0000000-0041-4000-8000-000000000011', 'Vé vào khu thác', TRUE, 5),
('c5000000-0041-4000-8000-000000001106', 'c0000000-0041-4000-8000-000000000011', 'Ảnh, video quay bằng máy quay hành động', FALSE, 1),
('c5000000-0041-4000-8000-000000001107', 'c0000000-0041-4000-8000-000000000011', 'Tiền tip cho hướng dẫn viên (tùy ý)', FALSE, 2),
-- Tour 12: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001201', 'c0000000-0041-4000-8000-000000000012', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000001202', 'c0000000-0041-4000-8000-000000000012', '6 món ăn vặt', TRUE, 2),
('c5000000-0041-4000-8000-000000001203', 'c0000000-0041-4000-8000-000000000012', '1 ly sữa đậu nành hoặc chè', TRUE, 3),
('c5000000-0041-4000-8000-000000001204', 'c0000000-0041-4000-8000-000000000012', 'Đồ uống gọi thêm', FALSE, 1),
('c5000000-0041-4000-8000-000000001205', 'c0000000-0041-4000-8000-000000000012', 'Đồ mua mang về', FALSE, 2),
-- Tour 13: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001301', 'c0000000-0041-4000-8000-000000000013', 'Xe máy, xăng và người lái', TRUE, 1),
('c5000000-0041-4000-8000-000000001302', 'c0000000-0041-4000-8000-000000000013', 'Mũ bảo hiểm và áo mưa', TRUE, 2),
('c5000000-0041-4000-8000-000000001303', 'c0000000-0041-4000-8000-000000000013', 'Bữa trưa và nước uống', TRUE, 3),
('c5000000-0041-4000-8000-000000001304', 'c0000000-0041-4000-8000-000000000013', 'Vé tham quan các điểm dừng', TRUE, 4),
('c5000000-0041-4000-8000-000000001305', 'c0000000-0041-4000-8000-000000000013', 'Cà phê, đặc sản mua mang về', FALSE, 1),
('c5000000-0041-4000-8000-000000001306', 'c0000000-0041-4000-8000-000000000013', 'Tiền tip cho người lái (tùy ý)', FALSE, 2),
-- Tour 14: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001401', 'c0000000-0041-4000-8000-000000000014', 'Hướng dẫn viên', TRUE, 1),
('c5000000-0041-4000-8000-000000001402', 'c0000000-0041-4000-8000-000000000014', 'Ghe máy và xuồng chèo', TRUE, 2),
('c5000000-0041-4000-8000-000000001403', 'c0000000-0041-4000-8000-000000000014', 'Áo phao', TRUE, 3),
('c5000000-0041-4000-8000-000000001404', 'c0000000-0041-4000-8000-000000000014', 'Bữa sáng, cà phê và trái cây', TRUE, 4),
('c5000000-0041-4000-8000-000000001405', 'c0000000-0041-4000-8000-000000000014', 'Trái cây mua thêm ở chợ nổi', FALSE, 1),
('c5000000-0041-4000-8000-000000001406', 'c0000000-0041-4000-8000-000000000014', 'Tiền tip cho hướng dẫn viên (tùy ý)', FALSE, 2),
-- Tour 15: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001501', 'c0000000-0041-4000-8000-000000000015', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000001502', 'c0000000-0041-4000-8000-000000000015', 'Xe đạp và mũ bảo hiểm', TRUE, 2),
('c5000000-0041-4000-8000-000000001503', 'c0000000-0041-4000-8000-000000000015', 'Bữa trưa nhẹ và trái cây', TRUE, 3),
('c5000000-0041-4000-8000-000000001504', 'c0000000-0041-4000-8000-000000000015', 'Xe từ trung tâm Cần Thơ đến Phong Điền', FALSE, 1),
('c5000000-0041-4000-8000-000000001505', 'c0000000-0041-4000-8000-000000000015', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 16: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001601', 'c0000000-0041-4000-8000-000000000016', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000001602', 'c0000000-0041-4000-8000-000000000016', '5 món ăn và 1 phần chè', TRUE, 2),
('c5000000-0041-4000-8000-000000001603', 'c0000000-0041-4000-8000-000000000016', 'Nước uống', TRUE, 3),
('c5000000-0041-4000-8000-000000001604', 'c0000000-0041-4000-8000-000000000016', 'Bia, đồ uống gọi thêm', FALSE, 1),
('c5000000-0041-4000-8000-000000001605', 'c0000000-0041-4000-8000-000000000016', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 17: 5 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001701', 'c0000000-0041-4000-8000-000000000017', 'Xe đưa đón', TRUE, 1),
('c5000000-0041-4000-8000-000000001702', 'c0000000-0041-4000-8000-000000000017', 'Tàu gỗ hoặc ca nô theo gói đã chọn', TRUE, 2),
('c5000000-0041-4000-8000-000000001703', 'c0000000-0041-4000-8000-000000000017', 'Áo phao, kính và ống thở', TRUE, 3),
('c5000000-0041-4000-8000-000000001704', 'c0000000-0041-4000-8000-000000000017', 'Bữa trưa hải sản', TRUE, 4),
('c5000000-0041-4000-8000-000000001705', 'c0000000-0041-4000-8000-000000000017', 'Phí tham quan đảo', TRUE, 5),
('c5000000-0041-4000-8000-000000001706', 'c0000000-0041-4000-8000-000000000017', 'Đồ uống có cồn', FALSE, 1),
('c5000000-0041-4000-8000-000000001707', 'c0000000-0041-4000-8000-000000000017', 'Tiền tip cho hướng dẫn viên và thủy thủ (tùy ý)', FALSE, 2),
-- Tour 18: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001801', 'c0000000-0041-4000-8000-000000000018', 'Xe đưa đón', TRUE, 1),
('c5000000-0041-4000-8000-000000001802', 'c0000000-0041-4000-8000-000000000018', 'Tàu, cần câu và mồi', TRUE, 2),
('c5000000-0041-4000-8000-000000001803', 'c0000000-0041-4000-8000-000000000018', 'Áo phao', TRUE, 3),
('c5000000-0041-4000-8000-000000001804', 'c0000000-0041-4000-8000-000000000018', 'Cháo hải sản và nước uống', TRUE, 4),
('c5000000-0041-4000-8000-000000001805', 'c0000000-0041-4000-8000-000000000018', 'Bia, đồ uống có cồn', FALSE, 1),
('c5000000-0041-4000-8000-000000001806', 'c0000000-0041-4000-8000-000000000018', 'Tiền tip cho thủy thủ (tùy ý)', FALSE, 2),
-- Tour 19: 3 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000001901', 'c0000000-0041-4000-8000-000000000019', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000001902', 'c0000000-0041-4000-8000-000000000019', 'Xe 16 chỗ', TRUE, 2),
('c5000000-0041-4000-8000-000000001903', 'c0000000-0041-4000-8000-000000000019', 'Trà tiêu, trái cây và 3 món ăn vặt', TRUE, 3),
('c5000000-0041-4000-8000-000000001904', 'c0000000-0041-4000-8000-000000000019', 'Tiêu, nước mắm mua mang về', FALSE, 1),
('c5000000-0041-4000-8000-000000001905', 'c0000000-0041-4000-8000-000000000019', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2),
-- Tour 20: 4 mục bao gồm, 2 mục không bao gồm
('c5000000-0041-4000-8000-000000002001', 'c0000000-0041-4000-8000-000000000020', 'Người dẫn địa phương', TRUE, 1),
('c5000000-0041-4000-8000-000000002002', 'c0000000-0041-4000-8000-000000000020', 'Xe 7 chỗ giữa các điểm', TRUE, 2),
('c5000000-0041-4000-8000-000000002003', 'c0000000-0041-4000-8000-000000000020', '1 nón bài thơ mang về', TRUE, 3),
('c5000000-0041-4000-8000-000000002004', 'c0000000-0041-4000-8000-000000000020', 'Trà và bánh', TRUE, 4),
('c5000000-0041-4000-8000-000000002005', 'c0000000-0041-4000-8000-000000000020', 'Nhang và đồ thủ công mua thêm', FALSE, 1),
('c5000000-0041-4000-8000-000000002006', 'c0000000-0041-4000-8000-000000000020', 'Tiền tip cho người dẫn (tùy ý)', FALSE, 2);

-- ---------------------------------------------------------------------
-- 11. tour_extras (PHỤ_THU / HOẠT_ĐỘNG_TÙY_CHỌN) - FR-04, FR-10: giá tách riêng, không cộng vào
--     giá tour. Tour 9, 12, 16, 20 không có dòng nào.
-- ---------------------------------------------------------------------
INSERT INTO tour_extras (id, tour_id, kind, name, price_vnd, price_unit, conditions, sort_order) VALUES
-- Tour 1
('c1000000-0041-4000-8000-000000000101', 'c0000000-0041-4000-8000-000000000001', 'optional', 'Thuê gậy đi bộ',
    30000, 'người', NULL, 1),
('c1000000-0041-4000-8000-000000000102', 'c0000000-0041-4000-8000-000000000001', 'surcharge', 'Phụ thu ngày lễ, Tết',
    150000, 'người', 'Áp dụng các ngày nghỉ lễ, Tết theo quy định.', 1),
-- Tour 2
('c1000000-0041-4000-8000-000000000201', 'c0000000-0041-4000-8000-000000000002', 'optional', 'Thuê trang phục H''Mông để chụp ảnh',
    80000, 'người', 'Trả trực tiếp tại bản.', 1),
-- Tour 3
('c1000000-0041-4000-8000-000000000301', 'c0000000-0041-4000-8000-000000000003', 'optional', 'Thêm phần cá hồi',
    120000, 'phần', NULL, 1),
-- Tour 4
('c1000000-0041-4000-8000-000000000401', 'c0000000-0041-4000-8000-000000000004', 'surcharge', 'Phụ thu đón ngoài khu trung tâm',
    100000, 'nhóm', 'Khách sạn cách trung tâm thành phố Ninh Bình hơn 10 km.', 1),
('c1000000-0041-4000-8000-000000000402', 'c0000000-0041-4000-8000-000000000004', 'optional', 'Thuê xe đạp đi quanh Tam Cốc sau tour',
    50000, 'xe', NULL, 1),
-- Tour 5
('c1000000-0041-4000-8000-000000000501', 'c0000000-0041-4000-8000-000000000005', 'optional', 'Đổi sang xe đạp điện',
    60000, 'xe', 'Số lượng có hạn, báo khi đặt tour.', 1),
-- Tour 6
('c1000000-0041-4000-8000-000000000601', 'c0000000-0041-4000-8000-000000000006', 'surcharge', 'Phụ thu ngồi riêng một thuyền',
    150000, 'người', 'Khi khách muốn ngồi một mình một thuyền.', 1),
-- Tour 7
('c1000000-0041-4000-8000-000000000701', 'c0000000-0041-4000-8000-000000000007', 'optional', 'Thêm lăng Minh Mạng',
    150000, 'người', 'Tour kéo dài thêm khoảng 1 giờ.', 1),
-- Tour 8
('c1000000-0041-4000-8000-000000000801', 'c0000000-0041-4000-8000-000000000008', 'surcharge', 'Phụ thu thuê riêng cả thuyền',
    1500000, 'thuyền', 'Tối đa 20 khách, đặt trước ít nhất 48 giờ.', 1),
-- Tour 10
('c1000000-0041-4000-8000-000000001001', 'c0000000-0041-4000-8000-000000000010', 'optional', 'Hái dâu tây tại vườn',
    80000, 'người', 'Theo mùa, thường từ tháng 11 đến tháng 4.', 1),
-- Tour 11
('c1000000-0041-4000-8000-000000001101', 'c0000000-0041-4000-8000-000000000011', 'optional', 'Ảnh, video quay bằng máy quay hành động',
    300000, 'nhóm', 'Gửi qua đường link trong 2 ngày.', 1),
-- Tour 13
('c1000000-0041-4000-8000-000000001301', 'c0000000-0041-4000-8000-000000000013', 'optional', 'Học rang xay cà phê tại vườn (thêm 1 giờ)',
    150000, 'người', NULL, 1),
-- Tour 14
('c1000000-0041-4000-8000-000000001401', 'c0000000-0041-4000-8000-000000000014', 'surcharge', 'Phụ thu đi ghe riêng, không ghép khách',
    900000, 'ghe', 'Tối đa 6 khách một ghe riêng.', 1),
('c1000000-0041-4000-8000-000000001402', 'c0000000-0041-4000-8000-000000000014', 'optional', 'Đón tại khách sạn trong quận Ninh Kiều',
    50000, 'người', NULL, 1),
-- Tour 15
('c1000000-0041-4000-8000-000000001501', 'c0000000-0041-4000-8000-000000000015', 'optional', 'Xe đưa đón từ trung tâm Cần Thơ',
    120000, 'người', 'Đón tại khách sạn trong quận Ninh Kiều.', 1),
-- Tour 17
('c1000000-0041-4000-8000-000000001701', 'c0000000-0041-4000-8000-000000000017', 'surcharge', 'Phụ thu đón ở phía bắc đảo',
    150000, 'người', 'Khách sạn ngoài khu Dương Đông và Bãi Trường.', 1),
('c1000000-0041-4000-8000-000000001702', 'c0000000-0041-4000-8000-000000000017', 'optional', 'Thuê kính lặn có độ cận',
    50000, 'người', 'Báo độ cận khi đặt tour.', 1),
-- Tour 18
('c1000000-0041-4000-8000-000000001801', 'c0000000-0041-4000-8000-000000000018', 'surcharge', 'Phụ thu đón ngoài khu vực Bãi Trường',
    100000, 'người', NULL, 1),
-- Tour 19
('c1000000-0041-4000-8000-000000001901', 'c0000000-0041-4000-8000-000000000019', 'optional', 'Đóng gói nước mắm để mang lên máy bay',
    30000, 'chai', NULL, 1);

-- ---------------------------------------------------------------------
-- 12. tour_images (ẢNH_TOUR) - FR-01, FR-02: 1 ảnh minh họa mỗi tour, sort_order 1 = ảnh bìa
--     (trang danh sách, chi tiết, tour đã lưu, so sánh, đơn đặt). url tương đối từ
--     src/public/assets/. Mỗi file chỉ thuộc 1 tour; id = số tour.
-- ---------------------------------------------------------------------
INSERT INTO tour_images (id, tour_id, url, alt_text, sort_order) VALUES
-- Tour 1 (Sa Pa)
('80000000-0041-4000-8000-000000000001', 'c0000000-0041-4000-8000-000000000001',
    'img/tours/sapa-1.jpg', 'Ruộng bậc thang xanh và đường mòn ở Tả Van, thung lũng Mường Hoa, Sa Pa', 1),
-- Tour 2 (Sa Pa)
('80000000-0041-4000-8000-000000000002', 'c0000000-0041-4000-8000-000000000002',
    'img/tours/sapa-2.jpg', 'Nhà gỗ, thác nước và dòng suối ở bản Cát Cát, Sa Pa', 1),
-- Tour 3 (Sa Pa)
('80000000-0041-4000-8000-000000000003', 'c0000000-0041-4000-8000-000000000003',
    'img/tours/sapa-3.jpg', 'Nhà thờ đá Sa Pa lúc chạng vạng, đèn đường đã lên', 1),
-- Tour 4 (Ninh Bình)
('80000000-0041-4000-8000-000000000004', 'c0000000-0041-4000-8000-000000000004',
    'img/tours/ninhbinh-1.jpg', 'Thuyền chèo trên sông giữa núi đá vôi ở Tràng An, Ninh Bình', 1),
-- Tour 5 (Ninh Bình)
('80000000-0041-4000-8000-000000000005', 'c0000000-0041-4000-8000-000000000005',
    'img/tours/ninhbinh-2.jpg', 'Du khách đạp xe giữa đồng lúa và núi đá vôi ở Tam Cốc, Ninh Bình', 1),
-- Tour 6 (Ninh Bình)
('80000000-0041-4000-8000-000000000006', 'c0000000-0041-4000-8000-000000000006',
    'img/tours/ninhbinh-3.jpg', 'Thuyền nan chở khách trên đầm Vân Long giữa núi đá vôi, Ninh Bình', 1),
-- Tour 7 (Huế)
('80000000-0041-4000-8000-000000000007', 'c0000000-0041-4000-8000-000000000007',
    'img/tours/hue-1.jpg', 'Cổng Ngọ Môn, lối vào chính của Hoàng thành Huế', 1),
-- Tour 8 (Huế)
('80000000-0041-4000-8000-000000000008', 'c0000000-0041-4000-8000-000000000008',
    'img/tours/hue-2.jpg', 'Thuyền rồng chở du khách trên sông Hương ở Huế', 1),
-- Tour 9 (Huế)
('80000000-0041-4000-8000-000000000009', 'c0000000-0041-4000-8000-000000000009',
    'img/tours/hue-3.jpg', 'Tô bún bò Huế với thịt bò, chả và đĩa rau sống', 1),
-- Tour 10 (Đà Lạt)
('80000000-0041-4000-8000-000000000010', 'c0000000-0041-4000-8000-000000000010',
    'img/tours/dalat-1.jpg', 'Hồ Xuân Hương ở Đà Lạt trong sương sớm', 1),
-- Tour 11 (Đà Lạt)
('80000000-0041-4000-8000-000000000011', 'c0000000-0041-4000-8000-000000000011',
    'img/tours/dalat-2.jpg', 'Thác Datanla đổ qua những phiến đá ở ngoại ô Đà Lạt', 1),
-- Tour 12 (Đà Lạt)
('80000000-0041-4000-8000-000000000012', 'c0000000-0041-4000-8000-000000000012',
    'img/tours/dalat-3.jpg', 'Khu chợ Đà Lạt và các hàng quán sáng đèn về đêm', 1),
-- Tour 13 (Đà Lạt)
('80000000-0041-4000-8000-000000000013', 'c0000000-0041-4000-8000-000000000013',
    'img/tours/dalat-4.jpg', 'Con đường uốn quanh đồi thông ở Đà Lạt', 1),
-- Tour 14 (Cần Thơ)
('80000000-0041-4000-8000-000000000014', 'c0000000-0041-4000-8000-000000000014',
    'img/tours/cantho-1.jpg', 'Ghe hàng chở đầy rau củ trên chợ nổi Cái Răng, Cần Thơ, trong nắng sớm', 1),
-- Tour 15 (Cần Thơ)
('80000000-0041-4000-8000-000000000015', 'c0000000-0041-4000-8000-000000000015',
    'img/tours/cantho-2.jpg', 'Con đường đất rợp bóng dừa nước ven kênh ở miệt vườn Phong Điền, Cần Thơ', 1),
-- Tour 16 (Cần Thơ)
('80000000-0041-4000-8000-000000000016', 'c0000000-0041-4000-8000-000000000016',
    'img/tours/cantho-3.jpg', 'Bến Ninh Kiều lung linh ánh đèn về đêm bên sông Cần Thơ', 1),
-- Tour 17 (Phú Quốc)
('80000000-0041-4000-8000-000000000017', 'c0000000-0041-4000-8000-000000000017',
    'img/tours/phuquoc-1.jpg', 'Bãi cát nhỏ dưới rặng dừa và làn nước trong xanh lộ rạn san hô ở quần đảo An Thới, Phú Quốc', 1),
-- Tour 18 (Phú Quốc)
('80000000-0041-4000-8000-000000000018', 'c0000000-0041-4000-8000-000000000018',
    'img/tours/phuquoc-2.jpg', 'Thuyền gỗ đánh cá neo trên biển Phú Quốc lúc hoàng hôn', 1),
-- Tour 19 (Phú Quốc)
('80000000-0041-4000-8000-000000000019', 'c0000000-0041-4000-8000-000000000019',
    'img/tours/phuquoc-3.jpg', 'Dãy thùng gỗ ủ nước mắm trong nhà thùng ở Phú Quốc', 1),
-- Tour 20 (Huế)
('80000000-0041-4000-8000-000000000020', 'c0000000-0041-4000-8000-000000000020',
    'img/tours/hue-4.jpg', 'Những bó hương nhiều màu xòe ra phơi ở làng hương Thủy Xuân, Huế', 1);

COMMIT;
