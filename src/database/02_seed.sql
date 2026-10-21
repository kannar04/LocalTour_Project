-- =====================================================================
-- LocalTour v0.1 - 02_seed.sql
-- Mục đích  : Nạp dữ liệu mẫu để kiểm thử trang danh sách và chi tiết tour.
-- Phụ trách : Nguyễn Minh Thức (NMT) - WBS 3.2.2
-- Dữ liệu   : TẤT CẢ dữ liệu (đơn vị tổ chức, tour, giá, lịch, đánh giá) là
--             dữ liệu MINH HỌA, không phải thông tin thật của bất kỳ đơn vị nào.
--             Số điện thoại / email dùng tên miền .example (không tồn tại).
-- Chạy sau  : 01_schema.sql (bảng phải đang trống). ID được ghi rõ để dữ liệu
--             giống nhau trên mọi máy; tour_id 1 = "Hà Nội qua những món ăn phố cổ".
-- Ngày tháng: Lịch khởi hành, ngày tạo tour và ngày đánh giá tính tương đối
--             theo CURDATE()/NOW() lúc import, nên luôn có lịch "sắp tới".
--
-- Ca kiểm thử có sẵn trong dữ liệu:
--   * 9 tour published (id 1-9) + 1 tour hidden (id 10, không bao giờ được hiển thị).
--   * Tour 9: không có đánh giá và không có lịch sắp tới (chỉ có 1 lịch đã hủy).
--   * Tour 1: 1 lịch đã qua (schedule 1) và 1 lịch 'full' (schedule 2) -> bị lọc.
--   * Tour 2: 1 lịch status 'open' nhưng đã hết chỗ (schedule 7) -> bị lọc.
--   * Tour 4: 1 lịch 'cancelled' (schedule 15) -> bị lọc.
--   * Tour 3: lịch trình không cố định giờ (start_time NULL), 2 lịch cùng ngày khác giờ.
--   * Tour 9: meeting_note và transport_note NULL; đơn vị tổ chức chưa xác minh.
--
-- Ảnh: mỗi điểm đến dùng chung một bộ 3 ảnh SVG (giao diện tạo trong public/):
--   hanoi-1..3, danang-1..3, hoian-1..3, hcm-1..3 -> assets/img/tours/<slug>-<n>.svg
--   Tour cùng điểm đến dùng lại bộ ảnh với thứ tự và chú thích khác nhau.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Điểm đến, danh mục
-- ---------------------------------------------------------------------
INSERT INTO destinations (destination_id, name, slug, sort_order) VALUES
(1, 'Hà Nội',          'ha-noi',         1),
(2, 'Đà Nẵng',         'da-nang',        2),
(3, 'Hội An',          'hoi-an',         3),
(4, 'TP. Hồ Chí Minh', 'tp-ho-chi-minh', 4);

INSERT INTO categories (category_id, name, slug) VALUES
(1, 'Tour ẩm thực',           'tour-am-thuc'),
(2, 'Tour văn hóa – lịch sử', 'tour-van-hoa-lich-su'),
(3, 'Tour thiên nhiên',       'tour-thien-nhien'),
(4, 'Tour đêm',               'tour-dem');

-- ---------------------------------------------------------------------
-- Đơn vị tổ chức (minh họa; không ghi số điện thoại để tránh trùng số thật)
-- ---------------------------------------------------------------------
INSERT INTO providers (provider_id, name, description, phone, email, is_verified, is_active, created_at) VALUES
(1, 'Hà Nội Local',
    'Nhóm hướng dẫn viên sinh ra và lớn lên ở phố cổ, chuyên tour đi bộ ẩm thực cho nhóm nhỏ.',
    NULL, 'hanoilocal@localtour.example', 1, 1, NOW() - INTERVAL 400 DAY),
(2, 'Phố Cổ Stories',
    'Kể chuyện phố cổ qua từng con ngõ, quán quen và những người giữ nghề lâu năm.',
    NULL, 'phocostories@localtour.example', 1, 1, NOW() - INTERVAL 380 DAY),
(3, 'Sơn Trà Xanh',
    'Đội ngũ yêu thiên nhiên ở Đà Nẵng, tổ chức tour nhóm nhỏ và hạn chế tối đa đồ nhựa dùng một lần.',
    NULL, 'sontraxanh@localtour.example', 1, 1, NOW() - INTERVAL 300 DAY),
(4, 'Đêm Sông Hàn',
    'Nhóm người trẻ Đà Nẵng dẫn khách khám phá thành phố về đêm, từ bờ sông đến chợ đêm.',
    NULL, 'demsonghan@localtour.example', 0, 1, NOW() - INTERVAL 200 DAY),
(5, 'Phố Hội Chậm',
    'Người Hội An dẫn khách đi chậm, ở lâu hơn và trò chuyện nhiều hơn với người dân địa phương.',
    NULL, 'phohoicham@localtour.example', 1, 1, NOW() - INTERVAL 360 DAY),
(6, 'Sài Gòn Về Đêm',
    'Đội tài xế kiêm hướng dẫn viên chạy xe máy an toàn, rành từng con hẻm Sài Gòn.',
    NULL, 'saigonvedem@localtour.example', 1, 1, NOW() - INTERVAL 250 DAY),
(7, 'Chợ Lớn Kể Chuyện',
    'Đơn vị mới tham gia LocalTour, chuyên tour đi bộ tìm hiểu văn hóa người Hoa ở quận 5.',
    NULL, 'cholonkechuyen@localtour.example', 0, 1, NOW() - INTERVAL 10 DAY);

-- ---------------------------------------------------------------------
-- Tour
--   created_at khác nhau để tab "Mới nhất" có thứ tự rõ ràng:
--   mới -> cũ (chỉ tour published): 9, 8, 5, 3, 7, 4, 2, 1, 6.
--   Tour 10 (hidden) có điểm 5,0 với 3 đánh giá: nếu bị lộ sẽ đứng đầu "Dành cho bạn".
-- ---------------------------------------------------------------------
INSERT INTO tours (tour_id, provider_id, destination_id, category_id, title, summary, description,
                   duration_hours, max_group_size, languages, price_per_person, price_note,
                   meeting_point, meeting_note, transport_note, cancellation_policy, status, created_at) VALUES
-- Hà Nội --------------------------------------------------------------
(1, 1, 1, 1,
    'Hà Nội qua những món ăn phố cổ',
    'Đi bộ cùng người địa phương, khám phá món ngon và câu chuyện phố cổ.',
    'Tour đi bộ 4 giờ cùng người dẫn địa phương. Ghé các quán nhỏ, thưởng thức món ăn và tìm hiểu cuộc sống thường ngày tại Hà Nội. Lộ trình đi qua những con phố nhỏ quanh hồ Hoàn Kiếm, mỗi điểm dừng là một món ăn và một câu chuyện về con phố đó.',
    4.0, 8, 'Tiếng Việt / Anh', 650000, 'Giá minh họa • VND • Đã gồm thuế, phí',
    'Nhà hát Múa rối Thăng Long',
    'Phía phố Đinh Tiên Hoàng, cạnh hồ Hoàn Kiếm. Có mặt trước 10 phút, người dẫn cầm cờ nhỏ màu xanh.',
    'Tour đi bộ, tổng quãng đường khoảng 3 km. Không có xe đưa đón, nên mang giày thoải mái.',
    'Hủy miễn phí trước giờ khởi hành 24 giờ.',
    'published', NOW() - INTERVAL 120 DAY),
(2, 2, 1, 1,
    'Ẩm thực Hà Nội & cà phê trứng',
    'Một góc nhìn khác về phố cổ, với nhóm nhỏ và thời gian thư thả.',
    'Bắt đầu từ chợ Đồng Xuân, nhóm đi qua các phố quanh chợ để thử bánh cuốn nóng và những món ăn vặt quen thuộc của người Hà Nội. Tour kết thúc ở một quán cà phê trứng trên tầng cao nhìn ra phố. Nhịp đi chậm, phù hợp với người lần đầu đến Hà Nội.',
    3.0, 6, 'Tiếng Việt / Anh', 720000, 'Giá minh họa • VND • Đã gồm đồ ăn và 1 đồ uống',
    'Chợ Đồng Xuân (cổng chính)',
    'Đứng chờ dưới biển tên chợ, phía phố Đồng Xuân.',
    'Đi bộ khoảng 2 km. Có thể gửi xe máy ở bãi xe cạnh chợ.',
    'Hủy miễn phí trước giờ khởi hành 24 giờ.',
    'published', NOW() - INTERVAL 95 DAY),
(3, 2, 1, 2,
    'Phố cổ theo cách của bạn',
    'Tour riêng cho nhóm nhỏ: bạn chọn chủ đề, người dẫn thiết kế lộ trình quanh phố cổ.',
    'Trước ngày đi, người dẫn liên hệ để hỏi sở thích của nhóm: kiến trúc nhà ống, phố nghề, đền chùa hay những góc chụp ảnh. Lộ trình được sắp xếp riêng trong khoảng 4 giờ, đi bộ kết hợp một đoạn xích lô ngắn. Phù hợp với gia đình hoặc nhóm bạn muốn tìm hiểu phố cổ sâu hơn.',
    4.0, 4, 'Tiếng Việt / Anh / Pháp', 900000, 'Giá minh họa • VND • Tour riêng, giá tính theo người',
    'Đền Bạch Mã, phố Hàng Buồm',
    'Có thể đổi điểm gặp sang khách sạn trong phố cổ khi xác nhận lịch.',
    'Đi bộ là chính, có khoảng 20 phút đi xích lô.',
    'Hủy miễn phí trước giờ khởi hành 48 giờ.',
    'published', NOW() - INTERVAL 40 DAY),
-- Đà Nẵng -------------------------------------------------------------
(4, 3, 2, 3,
    'Bình minh trên bán đảo Sơn Trà',
    'Đón bình minh trên bán đảo Sơn Trà, đi bộ đường rừng nhẹ và tìm voọc chà vá chân nâu.',
    'Xe đón nhóm ở trung tâm thành phố lúc 5 giờ sáng để kịp ngắm mặt trời mọc trên đỉnh Bàn Cờ. Sau đó cả nhóm đi bộ một cung đường rừng ngắn, nghe người dẫn giới thiệu hệ sinh thái của bán đảo và quan sát voọc chà vá chân nâu nếu may mắn. Tour kết thúc bằng bữa sáng mì Quảng gần chân núi.',
    5.0, 10, 'Tiếng Việt / Anh / Hàn', 550000, 'Giá minh họa • VND • Đã gồm xe đưa đón và bữa sáng',
    'Đón tại khách sạn ở trung tâm Đà Nẵng',
    'Xe đón từ 04:45 đến 05:00, người dẫn gọi điện trước 15 phút.',
    'Xe 16 chỗ đưa đón hai chiều. Đoạn đi bộ khoảng 2 km, độ khó dễ.',
    'Hủy miễn phí trước giờ khởi hành 24 giờ. Tour được dời lịch nếu trời mưa lớn.',
    'published', NOW() - INTERVAL 75 DAY),
(5, 4, 2, 4,
    'Đà Nẵng về đêm: cầu Rồng và chợ đêm',
    'Dạo bờ sông Hàn, ngắm cầu Rồng lên đèn và ăn tối ở chợ đêm cùng người địa phương.',
    'Tour bắt đầu khi thành phố lên đèn, đi bộ dọc bờ sông Hàn và dừng lại ở những góc ngắm cầu Rồng đẹp nhất. Sau đó nhóm ghé chợ đêm thử bánh tráng cuốn thịt heo, ốc hút và chè. Vào tối thứ Bảy và Chủ nhật, nhóm xem cầu Rồng phun lửa, phun nước lúc 21:00.',
    3.5, 12, 'Tiếng Việt / Anh', 480000, 'Giá minh họa • VND • Đã gồm ăn tối nhẹ',
    'Đầu cầu Rồng, phía đường Bạch Đằng',
    'Có mặt trước 10 phút, người dẫn cầm bảng tên LocalTour.',
    'Đi bộ khoảng 3 km, có một đoạn đi taxi ngắn sang chợ đêm (đã gồm trong giá).',
    'Hủy miễn phí trước giờ khởi hành 12 giờ.',
    'published', NOW() - INTERVAL 30 DAY),
-- Hội An --------------------------------------------------------------
(6, 5, 3, 2,
    'Hội An: phố cổ, đèn lồng và hoa đăng',
    'Đi chậm qua phố cổ Hội An lúc chiều tối, nghe chuyện hội quán và thả hoa đăng trên sông Hoài.',
    'Người dẫn đưa nhóm qua chùa Cầu, một ngôi nhà cổ và hội quán Phúc Kiến, kể về thương cảng Hội An xưa. Khi phố lên đèn, cả nhóm học làm một chiếc đèn lồng nhỏ và thả hoa đăng trên sông Hoài. Nhịp đi chậm, có nhiều thời gian chụp ảnh.',
    3.0, 10, 'Tiếng Việt / Anh', 590000, 'Giá minh họa • VND • Đã gồm vé tham quan phố cổ',
    'Chùa Cầu, đầu phố Trần Phú',
    'Gặp ở đầu chùa Cầu phía đường Nguyễn Thị Minh Khai.',
    'Đi bộ trong khu phố cổ, khoảng 2 km. Buổi tối phố cổ không cho xe máy đi vào.',
    'Hủy miễn phí trước giờ khởi hành 24 giờ.',
    'published', NOW() - INTERVAL 150 DAY),
(7, 5, 3, 1,
    'Làng rau Trà Quế: đạp xe và học nấu ăn',
    'Đạp xe qua đồng lúa ra làng rau Trà Quế, làm vườn cùng nông dân và tự nấu bữa trưa kiểu Hội An.',
    'Từ trung tâm Hội An, nhóm đạp xe khoảng 4 km ra làng rau Trà Quế. Bạn được nông dân hướng dẫn xới đất, gánh nước tưới rau và tìm hiểu cách bón rau bằng rong sông. Phần cuối là lớp nấu ăn nhỏ: tự làm bánh xèo, gỏi cuốn và cùng ăn trưa trong vườn.',
    4.5, 8, 'Tiếng Việt / Anh', 750000, 'Giá minh họa • VND • Đã gồm xe đạp và bữa trưa',
    'Bãi xe đạp cạnh chợ Hội An',
    'Nhận xe đạp và nón lá tại điểm hẹn trước giờ đi 10 phút.',
    'Đạp xe khoảng 8 km cả đi và về, đường bằng phẳng. Có xe điện hỗ trợ khi trời nắng gắt.',
    'Hủy miễn phí trước giờ khởi hành 24 giờ.',
    'published', NOW() - INTERVAL 60 DAY),
-- TP. Hồ Chí Minh -----------------------------------------------------
(8, 6, 4, 4,
    'Sài Gòn về đêm trên xe máy',
    'Ngồi sau xe máy cùng người dẫn, đi qua các quận trung tâm và ăn tối như người Sài Gòn.',
    'Mỗi khách ngồi sau một tài xế kiêm người dẫn có kinh nghiệm. Nhóm đi qua quận 1, quận 4 và quận 5, ghé quán ốc, xe chè và một quán cà phê nhạc sống. Tour có mũ bảo hiểm đạt chuẩn, áo mưa và bảo hiểm du lịch cho từng khách.',
    4.0, 6, 'Tiếng Việt / Anh', 850000, 'Giá minh họa • VND • Đã gồm ăn tối và bảo hiểm',
    'Đón tại khách sạn ở quận 1 hoặc quận 3',
    'Tài xế đón đúng giờ hẹn, vui lòng báo số phòng khi xác nhận lịch.',
    'Xe máy, mỗi khách một tài xế. Có mũ bảo hiểm và áo mưa.',
    'Hủy miễn phí trước giờ khởi hành 24 giờ.',
    'published', NOW() - INTERVAL 21 DAY),
-- Tour 9: tour mới, CHƯA có đánh giá và CHƯA có lịch khởi hành sắp tới.
(9, 7, 4, 2,
    'Chợ Lớn: hẻm nhỏ, hội quán và món Hoa',
    'Khám phá Chợ Lớn qua các hội quán, tiệm thuốc bắc lâu đời và món ăn của người Hoa.',
    'Tour đi bộ qua các con hẻm ở quận 5, ghé chùa Bà Thiên Hậu và vài hội quán, nghe chuyện về cộng đồng người Hoa ở Sài Gòn. Nhóm dừng chân ở một tiệm thuốc bắc và kết thúc bằng bữa ăn nhẹ với sủi cảo, há cảo. Lịch khởi hành đang được cập nhật.',
    3.5, 10, 'Tiếng Việt / Anh / Trung', 520000, 'Giá minh họa • VND',
    'Chùa Bà Thiên Hậu, đường Nguyễn Trãi, quận 5',
    NULL,
    NULL,
    'Hủy miễn phí trước giờ khởi hành 24 giờ.',
    'published', NOW() - INTERVAL 3 DAY),
-- Tour 10: ĐANG ẨN (status = 'hidden'). Không procedure nào được trả về tour này.
(10, 1, 1, 3,
    'Đạp xe quanh Hồ Tây lúc bình minh',
    'Đạp xe một vòng Hồ Tây buổi sớm, ghé chùa Trấn Quốc và ăn sáng bún ốc.',
    'Nhóm nhận xe đạp ở đường Thanh Niên, đạp một vòng Hồ Tây khi mặt trời mọc, ghé chùa Trấn Quốc trước giờ đông khách và kết thúc bằng bát bún ốc nóng. Tour đang tạm ẩn để cập nhật lộ trình.',
    2.5, 8, 'Tiếng Việt / Anh', 400000, 'Giá minh họa • VND • Đã gồm xe đạp',
    'Đầu đường Thanh Niên, phía Hồ Tây',
    'Người dẫn chờ cạnh điểm cho thuê xe đạp.',
    'Đạp xe khoảng 15 km quanh hồ, đường bằng phẳng.',
    'Hủy miễn phí trước giờ khởi hành 24 giờ.',
    'hidden', NOW() - INTERVAL 200 DAY);

-- ---------------------------------------------------------------------
-- Ảnh tour (3 ảnh / tour, sort_order 1 = ảnh bìa)
-- ---------------------------------------------------------------------
INSERT INTO tour_images (image_id, tour_id, image_path, caption, sort_order) VALUES
(1,  1,  'assets/img/tours/hanoi-1.svg',  'Phố cổ Hà Nội lúc lên đèn', 1),
(2,  1,  'assets/img/tours/hanoi-2.svg',  'Người dẫn giới thiệu quán quen trong ngõ nhỏ', 2),
(3,  1,  'assets/img/tours/hanoi-3.svg',  'Bún chả và nem rán', 3),
(4,  2,  'assets/img/tours/hanoi-2.svg',  'Hàng ăn vặt quanh chợ Đồng Xuân', 1),
(5,  2,  'assets/img/tours/hanoi-3.svg',  'Bánh cuốn nóng trong quán gia đình', 2),
(6,  2,  'assets/img/tours/hanoi-1.svg',  'Cà phê trứng nhìn ra phố', 3),
(7,  3,  'assets/img/tours/hanoi-3.svg',  'Nhà ống cổ trong phố cổ', 1),
(8,  3,  'assets/img/tours/hanoi-1.svg',  'Xích lô quanh hồ Hoàn Kiếm', 2),
(9,  3,  'assets/img/tours/hanoi-2.svg',  'Góc phố nghề truyền thống', 3),
(10, 4,  'assets/img/tours/danang-1.svg', 'Bình minh trên đỉnh Bàn Cờ', 1),
(11, 4,  'assets/img/tours/danang-2.svg', 'Đường rừng trên bán đảo Sơn Trà', 2),
(12, 4,  'assets/img/tours/danang-3.svg', 'Mì Quảng buổi sáng', 3),
(13, 5,  'assets/img/tours/danang-3.svg', 'Cầu Rồng lên đèn bên sông Hàn', 1),
(14, 5,  'assets/img/tours/danang-1.svg', 'Bờ sông Hàn về đêm', 2),
(15, 5,  'assets/img/tours/danang-2.svg', 'Món ngon ở chợ đêm', 3),
(16, 6,  'assets/img/tours/hoian-1.svg',  'Phố cổ Hội An lúc lên đèn', 1),
(17, 6,  'assets/img/tours/hoian-2.svg',  'Lớp làm đèn lồng', 2),
(18, 6,  'assets/img/tours/hoian-3.svg',  'Thả hoa đăng trên sông Hoài', 3),
(19, 7,  'assets/img/tours/hoian-2.svg',  'Luống rau ở làng Trà Quế', 1),
(20, 7,  'assets/img/tours/hoian-3.svg',  'Đạp xe qua cánh đồng', 2),
(21, 7,  'assets/img/tours/hoian-1.svg',  'Bánh xèo tự tay làm', 3),
(22, 8,  'assets/img/tours/hcm-1.svg',    'Sài Gòn về đêm từ yên sau xe máy', 1),
(23, 8,  'assets/img/tours/hcm-2.svg',    'Quán ốc ở quận 4', 2),
(24, 8,  'assets/img/tours/hcm-3.svg',    'Cà phê nhạc sống', 3),
(25, 9,  'assets/img/tours/hcm-3.svg',    'Chùa Bà Thiên Hậu, quận 5', 1),
(26, 9,  'assets/img/tours/hcm-1.svg',    'Một con hẻm nhỏ ở Chợ Lớn', 2),
(27, 9,  'assets/img/tours/hcm-2.svg',    'Sủi cảo và há cảo', 3),
(28, 10, 'assets/img/tours/hanoi-2.svg',  'Đường ven Hồ Tây buổi sớm', 1),
(29, 10, 'assets/img/tours/hanoi-1.svg',  'Chùa Trấn Quốc', 2),
(30, 10, 'assets/img/tours/hanoi-3.svg',  'Bún ốc buổi sáng', 3);

-- ---------------------------------------------------------------------
-- Lịch trình (4-5 mục / tour)
-- ---------------------------------------------------------------------
INSERT INTO tour_itinerary_items (item_id, tour_id, start_time, description, sort_order) VALUES
-- Tour 1 (17:00 - 21:00, giống wireframe)
(1,  1, '17:00:00', 'Gặp tại Nhà hát Múa rối Thăng Long', 1),
(2,  1, '17:15:00', 'Đi bộ và thử món ăn tại phố cổ', 2),
(3,  1, '18:30:00', 'Bún chả và nem rán trong một con ngõ nhỏ', 3),
(4,  1, '19:30:00', 'Cà phê trứng và câu chuyện địa phương', 4),
(5,  1, '21:00:00', 'Kết thúc tại khu vực hồ Hoàn Kiếm', 5),
-- Tour 2
(6,  2, '15:00:00', 'Gặp nhau tại cổng chính chợ Đồng Xuân', 1),
(7,  2, '15:20:00', 'Dạo chợ, thử ô mai và các món ăn vặt', 2),
(8,  2, '16:15:00', 'Bánh cuốn nóng trong một quán gia đình', 3),
(9,  2, '17:15:00', 'Cà phê trứng trên tầng cao nhìn ra phố, kết thúc lúc 18:00', 4),
-- Tour 3: tour riêng, giờ linh hoạt nên start_time để NULL
(10, 3, NULL, 'Gặp người dẫn tại đền Bạch Mã, thống nhất lộ trình', 1),
(11, 3, NULL, 'Tham quan một ngôi nhà cổ, tìm hiểu kiến trúc nhà ống', 2),
(12, 3, NULL, 'Ghé một phố nghề truyền thống theo lựa chọn của nhóm', 3),
(13, 3, NULL, 'Đi xích lô một vòng quanh hồ Hoàn Kiếm', 4),
(14, 3, NULL, 'Kết thúc ở quán trà, trò chuyện và gợi ý chỗ ăn tối', 5),
-- Tour 4
(15, 4, '05:00:00', 'Xe đón tại khách sạn ở trung tâm', 1),
(16, 4, '05:30:00', 'Ngắm bình minh trên đỉnh Bàn Cờ', 2),
(17, 4, '06:30:00', 'Đi bộ đường rừng, quan sát voọc chà vá chân nâu', 3),
(18, 4, '08:30:00', 'Ăn sáng mì Quảng gần chân núi', 4),
(19, 4, '10:00:00', 'Xe đưa về khách sạn', 5),
-- Tour 5
(20, 5, '18:30:00', 'Gặp nhau ở đầu cầu Rồng, phía đường Bạch Đằng', 1),
(21, 5, '18:45:00', 'Dạo bờ sông Hàn, ngắm cầu Rồng lên đèn', 2),
(22, 5, '19:45:00', 'Ăn tối nhẹ ở chợ đêm', 3),
(23, 5, '21:00:00', 'Xem cầu Rồng phun lửa, phun nước (tối thứ Bảy, Chủ nhật)', 4),
(24, 5, '22:00:00', 'Kết thúc tour tại chợ đêm', 5),
-- Tour 6
(25, 6, '16:30:00', 'Gặp nhau tại chùa Cầu', 1),
(26, 6, '16:45:00', 'Tham quan nhà cổ và hội quán Phúc Kiến', 2),
(27, 6, '17:45:00', 'Học làm đèn lồng cùng nghệ nhân', 3),
(28, 6, '18:45:00', 'Thả hoa đăng trên sông Hoài', 4),
(29, 6, '19:30:00', 'Kết thúc tour ở chợ đêm Nguyễn Hoàng', 5),
-- Tour 7
(30, 7, '08:00:00', 'Nhận xe đạp, đạp xe ra làng rau Trà Quế', 1),
(31, 7, '08:30:00', 'Làm vườn cùng nông dân trong làng', 2),
(32, 7, '09:45:00', 'Lớp nấu ăn: bánh xèo và gỏi cuốn', 3),
(33, 7, '11:30:00', 'Ăn trưa trong vườn', 4),
(34, 7, '12:30:00', 'Đạp xe về trung tâm Hội An', 5),
-- Tour 8
(35, 8, '18:00:00', 'Đón khách tại khách sạn', 1),
(36, 8, '18:30:00', 'Ăn ốc ở quận 4', 2),
(37, 8, '19:30:00', 'Dạo Chợ Lớn và ăn chè', 3),
(38, 8, '20:30:00', 'Cà phê nhạc sống', 4),
(39, 8, '22:00:00', 'Đưa khách về khách sạn', 5),
-- Tour 9
(40, 9, '08:30:00', 'Gặp nhau tại chùa Bà Thiên Hậu', 1),
(41, 9, '09:15:00', 'Đi bộ qua các con hẻm và hội quán người Hoa', 2),
(42, 9, '10:30:00', 'Ghé một tiệm thuốc bắc lâu đời, nghe chuyện nghề', 3),
(43, 9, '11:15:00', 'Ăn nhẹ sủi cảo, há cảo và kết thúc tour', 4),
-- Tour 10 (hidden)
(44, 10, '05:30:00', 'Nhận xe đạp ở đầu đường Thanh Niên', 1),
(45, 10, '05:45:00', 'Đạp xe quanh Hồ Tây, ngắm bình minh', 2),
(46, 10, '06:45:00', 'Ghé chùa Trấn Quốc', 3),
(47, 10, '07:30:00', 'Ăn sáng bún ốc và kết thúc tour', 4);

-- ---------------------------------------------------------------------
-- Chi phí bao gồm / không gồm (mỗi tour có ít nhất 1 mục is_included = 0)
-- ---------------------------------------------------------------------
INSERT INTO tour_inclusions (inclusion_id, tour_id, item_text, is_included, sort_order) VALUES
(1,  1, 'Người dẫn địa phương', 1, 1),
(2,  1, '5 món ăn', 1, 2),
(3,  1, '1 đồ uống', 1, 3),
(4,  1, 'Xe đưa đón', 0, 4),
(5,  1, 'Chi tiêu cá nhân', 0, 5),
(6,  2, 'Người dẫn địa phương', 1, 1),
(7,  2, 'Bánh cuốn và 3 món ăn vặt', 1, 2),
(8,  2, '1 ly cà phê trứng', 1, 3),
(9,  2, 'Đồ uống gọi thêm', 0, 4),
(10, 3, 'Người dẫn riêng cho nhóm', 1, 1),
(11, 3, 'Vé vào nhà cổ', 1, 2),
(12, 3, 'Xích lô 20 phút', 1, 3),
(13, 3, 'Ăn uống', 0, 4),
(14, 4, 'Xe đưa đón hai chiều', 1, 1),
(15, 4, 'Bữa sáng mì Quảng', 1, 2),
(16, 4, 'Nước uống', 1, 3),
(17, 4, 'Ống nhòm cho mượn', 1, 4),
(18, 4, 'Tiền tip cho người dẫn', 0, 5),
(19, 5, 'Người dẫn địa phương', 1, 1),
(20, 5, 'Ăn tối nhẹ 3 món', 1, 2),
(21, 5, 'Taxi sang chợ đêm', 1, 3),
(22, 5, 'Đồ uống có cồn', 0, 4),
(23, 6, 'Vé tham quan phố cổ', 1, 1),
(24, 6, 'Đèn lồng tự làm mang về', 1, 2),
(25, 6, 'Hoa đăng', 1, 3),
(26, 6, 'Ăn tối', 0, 4),
(27, 6, 'Thuyền trên sông Hoài', 0, 5),
(28, 7, 'Xe đạp và nón lá', 1, 1),
(29, 7, 'Lớp nấu ăn và bữa trưa', 1, 2),
(30, 7, 'Nước uống', 1, 3),
(31, 7, 'Đón tại khách sạn', 0, 4),
(32, 8, 'Xe máy và tài xế riêng cho mỗi khách', 1, 1),
(33, 8, 'Ăn tối 4 món', 1, 2),
(34, 8, 'Mũ bảo hiểm và áo mưa', 1, 3),
(35, 8, 'Bảo hiểm du lịch', 1, 4),
(36, 8, 'Đồ uống có cồn', 0, 5),
(37, 9, 'Người dẫn địa phương', 1, 1),
(38, 9, 'Phần ăn nhẹ', 1, 2),
(39, 9, 'Chi tiêu cá nhân', 0, 3),
(40, 10, 'Xe đạp và mũ bảo hiểm', 1, 1),
(41, 10, 'Bữa sáng bún ốc', 1, 2),
(42, 10, 'Đồ uống', 0, 3);

-- ---------------------------------------------------------------------
-- Lịch khởi hành (ngày tính từ hôm nay; số chỗ còn = seats_total - seats_booked)
-- Bị lọc khỏi "lịch sắp tới": schedule 1 (đã qua), 2 (full), 7 (open nhưng hết chỗ),
-- 15 và 34 (cancelled). Tour 9 không còn lịch nào sắp tới.
-- ---------------------------------------------------------------------
INSERT INTO tour_schedules (schedule_id, tour_id, departure_date, start_time, seats_total, seats_booked, status) VALUES
-- Tour 1: lịch mở gần nhất là hôm nay + 4 ngày, 17:00 (như wireframe)
(1,  1, CURDATE() - INTERVAL 3 DAY,  '17:00:00', 8,  6,  'open'),
(2,  1, CURDATE() + INTERVAL 2 DAY,  '17:00:00', 8,  8,  'full'),
(3,  1, CURDATE() + INTERVAL 4 DAY,  '17:00:00', 8,  2,  'open'),
(4,  1, CURDATE() + INTERVAL 7 DAY,  '17:00:00', 8,  0,  'open'),
(5,  1, CURDATE() + INTERVAL 11 DAY, '17:00:00', 8,  5,  'open'),
(6,  1, CURDATE() + INTERVAL 18 DAY, '17:00:00', 8,  0,  'open'),
-- Tour 2
(7,  2, CURDATE() + INTERVAL 3 DAY,  '15:00:00', 6,  6,  'open'),
(8,  2, CURDATE() + INTERVAL 5 DAY,  '15:00:00', 6,  2,  'open'),
(9,  2, CURDATE() + INTERVAL 10 DAY, '15:00:00', 6,  0,  'open'),
(10, 2, CURDATE() + INTERVAL 17 DAY, '15:00:00', 6,  4,  'open'),
-- Tour 3: hai lịch cùng ngày, khác giờ
(11, 3, CURDATE() + INTERVAL 6 DAY,  '14:00:00', 4,  2,  'open'),
(12, 3, CURDATE() + INTERVAL 6 DAY,  '08:30:00', 4,  0,  'open'),
(13, 3, CURDATE() + INTERVAL 13 DAY, '08:30:00', 4,  1,  'open'),
-- Tour 4
(14, 4, CURDATE() + INTERVAL 2 DAY,  '05:00:00', 10, 7,  'open'),
(15, 4, CURDATE() + INTERVAL 5 DAY,  '05:00:00', 10, 3,  'cancelled'),
(16, 4, CURDATE() + INTERVAL 9 DAY,  '05:00:00', 10, 3,  'open'),
(17, 4, CURDATE() + INTERVAL 23 DAY, '05:00:00', 10, 0,  'open'),
-- Tour 5
(18, 5, CURDATE() + INTERVAL 3 DAY,  '18:30:00', 12, 10, 'open'),
(19, 5, CURDATE() + INTERVAL 8 DAY,  '18:30:00', 12, 4,  'open'),
(20, 5, CURDATE() + INTERVAL 15 DAY, '18:30:00', 12, 0,  'open'),
(21, 5, CURDATE() + INTERVAL 29 DAY, '18:30:00', 12, 0,  'open'),
-- Tour 6
(22, 6, CURDATE() + INTERVAL 2 DAY,  '16:30:00', 10, 6,  'open'),
(23, 6, CURDATE() + INTERVAL 4 DAY,  '16:30:00', 10, 2,  'open'),
(24, 6, CURDATE() + INTERVAL 12 DAY, '16:30:00', 10, 0,  'open'),
-- Tour 7
(25, 7, CURDATE() + INTERVAL 5 DAY,  '08:00:00', 8,  3,  'open'),
(26, 7, CURDATE() + INTERVAL 14 DAY, '08:00:00', 8,  0,  'open'),
(27, 7, CURDATE() + INTERVAL 21 DAY, '08:00:00', 8,  0,  'open'),
(28, 7, CURDATE() + INTERVAL 30 DAY, '08:00:00', 8,  0,  'open'),
-- Tour 8
(29, 8, CURDATE() + INTERVAL 3 DAY,  '18:00:00', 6,  4,  'open'),
(30, 8, CURDATE() + INTERVAL 6 DAY,  '18:00:00', 6,  1,  'open'),
(31, 8, CURDATE() + INTERVAL 10 DAY, '18:00:00', 6,  0,  'open'),
(32, 8, CURDATE() + INTERVAL 20 DAY, '18:00:00', 6,  0,  'open'),
(33, 8, CURDATE() + INTERVAL 27 DAY, '18:00:00', 6,  0,  'open'),
-- Tour 9: chỉ có một lịch đã hủy
(34, 9, CURDATE() + INTERVAL 8 DAY,  '08:30:00', 10, 0,  'cancelled'),
-- Tour 10 (hidden): có lịch mở nhưng không được hiển thị
(35, 10, CURDATE() + INTERVAL 3 DAY,  '05:30:00', 8, 2, 'open'),
(36, 10, CURDATE() + INTERVAL 9 DAY,  '05:30:00', 8, 0, 'open'),
(37, 10, CURDATE() + INTERVAL 16 DAY, '05:30:00', 8, 0, 'open');

-- ---------------------------------------------------------------------
-- Đánh giá (minh họa). Tour 9 không có đánh giá.
-- Điểm TB: tour 3 = 5,0; tour 1, 6 = 4,8; tour 2, 7 = 4,7; tour 4, 8 = 4,5; tour 5 = 4,3.
-- ---------------------------------------------------------------------
INSERT INTO reviews (review_id, tour_id, reviewer_name, rating, comment, created_at) VALUES
-- Tour 1
(1,  1, 'Quốc Huy',    4, 'Món ăn ngon, lịch trình hợp lý. Đoạn cuối hơi vội vì nhóm mình dừng lại chụp ảnh khá lâu.', NOW() - INTERVAL 45 DAY),
(2,  1, 'Lan Phương',  5, 'Dẫn bố mẹ đi cùng, cả nhà đều thích. Cà phê trứng là điểm nhấn của buổi tối.', NOW() - INTERVAL 26 DAY),
(3,  1, 'Thu Trang',   5, 'Anh hướng dẫn kể chuyện phố cổ rất cuốn, quán nào cũng ngon và sạch sẽ.', NOW() - INTERVAL 12 DAY),
(4,  1, 'Minh Anh',    5, 'Nhóm nhỏ, đồ ăn đa dạng. Đi bộ khá nhiều, nên mang giày thoải mái.', NOW() - INTERVAL 3 DAY),
-- Tour 2
(5,  2, 'Hoàng Yến',   4, 'Tour nhẹ nhàng, hợp đi buổi chiều. Mong có thêm vài món mặn.', NOW() - INTERVAL 50 DAY),
(6,  2, 'Đức Thịnh',   5, 'Cà phê trứng ngon đúng như mong đợi, chị hướng dẫn rất dễ thương.', NOW() - INTERVAL 20 DAY),
(7,  2, 'Bảo Ngọc',    5, 'Nhóm chỉ có năm người nên rất thoải mái, được nghe nhiều chuyện về cách người Hà Nội ăn uống.', NOW() - INTERVAL 6 DAY),
-- Tour 3
(8,  3, 'Gia Bảo',     5, 'Đáng tiền vì được đi đúng những chỗ nhóm muốn, không bị kéo vào cửa hàng lưu niệm.', NOW() - INTERVAL 25 DAY),
(9,  3, 'Khánh Linh',  5, 'Người dẫn nắm lịch sử rất chắc, trả lời được hết câu hỏi của bố mình. Sẽ giới thiệu cho bạn bè.', NOW() - INTERVAL 9 DAY),
-- Tour 4
(10, 4, 'Hải Đăng',    4, 'Hôm đó trời nhiều mây nên bình minh không rõ lắm, bù lại đường rừng rất mát.', NOW() - INTERVAL 60 DAY),
(11, 4, 'Thanh Hà',    5, 'Bình minh trên Sơn Trà đẹp hơn mình tưởng. Dậy sớm hoàn toàn xứng đáng.', NOW() - INTERVAL 33 DAY),
(12, 4, 'Văn Long',    4, 'Không gặp được voọc nhưng anh hướng dẫn giải thích rất kỹ về rừng. Mì Quảng buổi sáng ngon.', NOW() - INTERVAL 15 DAY),
(13, 4, 'Ngọc Mai',    5, 'Xe đón đúng giờ, nhóm nhỏ nên đi bộ không bị chen. Có cho mượn ống nhòm, rất chu đáo.', NOW() - INTERVAL 4 DAY),
-- Tour 5
(14, 5, 'Tuấn Kiệt',   4, 'Vui, đồ ăn chợ đêm ngon. Hôm mình đi là thứ Tư nên không xem được cầu Rồng phun lửa.', NOW() - INTERVAL 22 DAY),
(15, 5, 'Mai Chi',     4, 'Lịch trình ổn, nhưng nhóm 12 người hơi đông lúc ngồi ăn.', NOW() - INTERVAL 13 DAY),
(16, 5, 'Phương Thảo', 5, 'Đi tối thứ Bảy, xem cầu Rồng phun lửa xong còn được dẫn đi ăn chè. Rất đáng!', NOW() - INTERVAL 5 DAY),
-- Tour 6
(17, 6, 'Kim Ngân',    4, 'Phố cổ đẹp nhưng buổi tối khá đông, nên đi vào ngày thường.', NOW() - INTERVAL 90 DAY),
(18, 6, 'Trọng Nghĩa', 5, 'Làm đèn lồng vui hơn mình nghĩ, mang về được một chiếc làm kỷ niệm.', NOW() - INTERVAL 54 DAY),
(19, 6, 'Thảo Vy',     5, 'Chị hướng dẫn nói chuyện duyên, kể nhiều chuyện về hội quán mà sách không có.', NOW() - INTERVAL 28 DAY),
(20, 6, 'Nhật Minh',   5, 'Thả hoa đăng trên sông Hoài lúc phố lên đèn là khoảnh khắc đáng nhớ nhất chuyến đi.', NOW() - INTERVAL 8 DAY),
-- Tour 7
(21, 7, 'Diễm My',     4, 'Trời nắng nên đạp xe hơi mệt, may có xe điện hỗ trợ. Bánh xèo tự làm rất ngon.', NOW() - INTERVAL 41 DAY),
(22, 7, 'Hữu Phước',   5, 'Lần đầu thử gánh nước tưới rau, các bác nông dân rất vui tính.', NOW() - INTERVAL 19 DAY),
(23, 7, 'Anh Thư',     5, 'Hợp với gia đình có trẻ nhỏ, bé nhà mình thích nhất phần làm vườn.', NOW() - INTERVAL 7 DAY),
-- Tour 8
(24, 8, 'Thanh Tùng',  4, 'Tài xế chạy cẩn thận, đồ ăn ngon. Đường hơi kẹt lúc 7 giờ tối nên mất thêm thời gian.', NOW() - INTERVAL 14 DAY),
(25, 8, 'Quỳnh Như',   5, 'Ngồi sau xe máy nhìn Sài Gòn về đêm rất khác. Quán ốc quận 4 là chân ái!', NOW() - INTERVAL 2 DAY),
-- Tour 10 (hidden)
(26, 10, 'Bích Ngọc',  5, 'Hồ Tây buổi sáng rất yên, ghé chùa Trấn Quốc lúc chưa đông khách.', NOW() - INTERVAL 180 DAY),
(27, 10, 'Hoài Nam',   5, 'Đạp xe nhẹ nhàng, bún ốc buổi sáng ngon tuyệt.', NOW() - INTERVAL 150 DAY),
(28, 10, 'Thu Hằng',   5, 'Người dẫn nhiệt tình, chụp cho cả nhóm rất nhiều ảnh đẹp.', NOW() - INTERVAL 100 DAY);
