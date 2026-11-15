-- =====================================================================
-- LocalTour v0.7 - 42_map_tours_NTK.sql
-- Mục đích  : Tọa độ điểm khởi hành của 20 tour mẫu của 41_seed_tours_NMT.sql, để các tour này
--             hiện trên bản đồ của file 23 (trang chi tiết tour, bản đồ danh sách tour).
--   1. Vị trí GẦN ĐÚNG ở mức khu vực (3 chữ số thập phân), ghi cố định bên dưới; trang web
--      không gọi dịch vụ tra tọa độ nào. Tour có điểm hẹn dùng vị trí điểm hẹn (meeting_point);
--      tour đón tại khách sạn dùng tâm khu vực đón, như file 23.
--   2. Mọi tọa độ nằm trong khung Việt Nam của file 23 (vĩ độ 8 -> 23,5; kinh độ 102 -> 110).
-- Phụ trách : Nguyễn Tuấn Khôi (NTK)
-- Dữ liệu   : MINH HỌA, cùng quy ước với 41_seed_tours_NMT.sql. Ghi chú trên mỗi lệnh là điểm hẹn
--             hoặc khu vực đón của tour, không phải địa chỉ của đơn vị nào.
-- Tương thích: MariaDB 10.4 (XAMPP) / MySQL 8.
-- Chạy sau  : 01 -> 41 (cần cột tọa độ của file 23 và các tour của file 41). Chạy lại được: mỗi
--             lệnh ghi lại cùng một giá trị. Chạy lại file 41 thì các tour đó mất tọa độ (dòng
--             tour được thêm lại), nên chạy lại file này ngay sau file 41.
-- Số dòng   : 20 lệnh UPDATE trên tours (1 lệnh mỗi tour); không thêm hay xóa dòng nào.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Tọa độ tour mẫu của file 41 (gần đúng, mức khu vực). Ghi chú = điểm hẹn / khu vực đón.
-- ---------------------------------------------------------------------
-- Tour 1 (Sa Pa) - tâm khu vực đón: Khách sạn ở trung tâm thị trấn Sa Pa
UPDATE tours SET latitude = 22.335, longitude = 103.841
 WHERE id = 'c0000000-0041-4000-8000-000000000001';
-- Tour 2 (Sa Pa) - điểm hẹn: Nhà thờ đá Sa Pa
UPDATE tours SET latitude = 22.336, longitude = 103.844
 WHERE id = 'c0000000-0041-4000-8000-000000000002';
-- Tour 3 (Sa Pa) - điểm hẹn: Bờ hồ Sa Pa, phía đường Xuân Viên
UPDATE tours SET latitude = 22.338, longitude = 103.847
 WHERE id = 'c0000000-0041-4000-8000-000000000003';
-- Tour 4 (Ninh Bình) - tâm khu vực đón: Khách sạn ở thành phố Ninh Bình hoặc khu Tam Cốc
UPDATE tours SET latitude = 20.251, longitude = 105.975
 WHERE id = 'c0000000-0041-4000-8000-000000000004';
-- Tour 5 (Ninh Bình) - điểm hẹn: Bến thuyền Tam Cốc
UPDATE tours SET latitude = 20.216, longitude = 105.938
 WHERE id = 'c0000000-0041-4000-8000-000000000005';
-- Tour 6 (Ninh Bình) - điểm hẹn: Bến thuyền khu bảo tồn Vân Long
UPDATE tours SET latitude = 20.370, longitude = 105.856
 WHERE id = 'c0000000-0041-4000-8000-000000000006';
-- Tour 7 (Huế) - tâm khu vực đón: Khách sạn ở trung tâm thành phố Huế
UPDATE tours SET latitude = 16.464, longitude = 107.590
 WHERE id = 'c0000000-0041-4000-8000-000000000007';
-- Tour 8 (Huế) - điểm hẹn: Bến thuyền Tòa Khâm, đường Lê Lợi
UPDATE tours SET latitude = 16.468, longitude = 107.587
 WHERE id = 'c0000000-0041-4000-8000-000000000008';
-- Tour 9 (Huế) - điểm hẹn: Cổng chính chợ Đông Ba
UPDATE tours SET latitude = 16.473, longitude = 107.589
 WHERE id = 'c0000000-0041-4000-8000-000000000009';
-- Tour 10 (Đà Lạt) - điểm hẹn: Bờ hồ Xuân Hương, phía chợ Đà Lạt
UPDATE tours SET latitude = 11.941, longitude = 108.440
 WHERE id = 'c0000000-0041-4000-8000-000000000010';
-- Tour 11 (Đà Lạt) - tâm khu vực đón: Khách sạn ở trung tâm Đà Lạt
UPDATE tours SET latitude = 11.940, longitude = 108.437
 WHERE id = 'c0000000-0041-4000-8000-000000000011';
-- Tour 12 (Đà Lạt) - điểm hẹn: Bậc thang lên chợ đêm Đà Lạt
UPDATE tours SET latitude = 11.943, longitude = 108.435
 WHERE id = 'c0000000-0041-4000-8000-000000000012';
-- Tour 13 (Đà Lạt) - điểm hẹn: Quảng trường Lâm Viên
UPDATE tours SET latitude = 11.938, longitude = 108.444
 WHERE id = 'c0000000-0041-4000-8000-000000000013';
-- Tour 14 (Cần Thơ) - điểm hẹn: Bến Ninh Kiều
UPDATE tours SET latitude = 10.034, longitude = 105.789
 WHERE id = 'c0000000-0041-4000-8000-000000000014';
-- Tour 15 (Cần Thơ) - điểm hẹn: Chợ Phong Điền
UPDATE tours SET latitude = 10.000, longitude = 105.670
 WHERE id = 'c0000000-0041-4000-8000-000000000015';
-- Tour 16 (Cần Thơ) - điểm hẹn: Phố đi bộ Hai Bà Trưng, gần chợ cổ Cần Thơ
UPDATE tours SET latitude = 10.031, longitude = 105.786
 WHERE id = 'c0000000-0041-4000-8000-000000000016';
-- Tour 17 (Phú Quốc) - tâm khu vực đón: Khách sạn ở Dương Đông và Bãi Trường
UPDATE tours SET latitude = 10.216, longitude = 103.962
 WHERE id = 'c0000000-0041-4000-8000-000000000017';
-- Tour 18 (Phú Quốc) - tâm khu vực đón: Khách sạn ở khu vực Bãi Trường
UPDATE tours SET latitude = 10.170, longitude = 103.970
 WHERE id = 'c0000000-0041-4000-8000-000000000018';
-- Tour 19 (Phú Quốc) - điểm hẹn: Cổng chợ Dương Đông
UPDATE tours SET latitude = 10.219, longitude = 103.958
 WHERE id = 'c0000000-0041-4000-8000-000000000019';
-- Tour 20 (Huế) - điểm hẹn: Đầu làng hương Thủy Xuân
UPDATE tours SET latitude = 16.440, longitude = 107.573
 WHERE id = 'c0000000-0041-4000-8000-000000000020';
