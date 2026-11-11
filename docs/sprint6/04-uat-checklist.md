# Kế hoạch, checklist và biên bản UAT Sprint 6

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 6 – Chuẩn bị demo, hướng dẫn và nghiệm thu UAT (13/11 – 19/11/2026) |
| WBS | 6.5 – Thực hiện UAT; 6.6 – Sửa lỗi chặn UAT; 6.7 – Tổng hợp nghiệm thu demo |
| Người phụ trách | Hồ Duy Hải, Đỗ Sơn Thành (QA / Documentation); sửa lỗi: Lê Trung Phong, Nguyễn Tuấn Khôi, Nguyễn Minh Thức |
| Căn cứ | Product Backlog (USECASEPLAN): US-01 → US-24 và tiêu chí nghiệm thu; Báo cáo tổng hợp Sprint 5 (mục 3, 8.1); Test Plan và RTM Sprint 5 (mức độ lỗi, defect log) |
| Tài liệu liên quan | [01 – Kế hoạch Sprint 6](01-ke-hoach-sprint6.md), [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md), [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md) |
| Bộ ca UAT | UAT-01 → UAT-37 (33 Must, 3 Should, 1 Could), phủ 24/24 User Story |
| Trạng thái | Bản nháp; nhóm rà soát và chốt trước khi chạy UAT ngày 17/11/2026. |

## 1. Mục tiêu và phạm vi

Mục tiêu: người dùng (vai khách hàng và quản trị viên) xác nhận bản demo đáp ứng tiêu chí nghiệm thu của 24 User Story, trên máy cài từ gói demo 6.3 theo Installation Guide; có biên bản để quyết định Go / No-go ngày 19/11.

UAT khác System Test Sprint 5: thao tác như người dùng thật theo [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), không dùng DevTools, không sửa database bằng tay.

Ngoài phạm vi (không ghi “Không đạt” cho các mục này):

| Mục | Lý do |
| --- | --- |
| IPN của VNPay khi chạy ở máy cục bộ | VNPay không gọi được `localhost` (I03); kết quả ghi qua Return URL, luồng IPN đã thử ở Sprint 4. |
| Hoàn tiền tự động | Đồng ý hủy chỉ ghi khoản hoàn; LocalTour chuyển khoản lại thủ công. |
| Đổi số người, đổi gói khi đổi ngày | Đổi ngày giữ nguyên số khách, gói và tổng tiền. |
| Phần thêm của trang so sánh (tổng cho N người, “Chỉ xem điểm khác nhau”, “Chọn tour này”, lưu theo tài khoản) | Giữ ở Product Backlog. |
| Khách gửi đánh giá tour (FR-16), nhãn “Thông tin chưa được xác minh” (NFR-07) | Giữ ở Product Backlog. |
| Ngày đi, Bộ lọc, Thích, Bình luận, Chia sẻ, Lưu tour | Nút đang tắt, nhãn “Sắp có”. |

## 2. Thành phần tham gia

| Vai trò | Người | Việc |
| --- | --- | --- |
| Điều phối, ghi kết quả | Hồ Duy Hải, Đỗ Sơn Thành | Chạy ca theo thứ tự, ghi kết quả và minh chứng, ghi defect log, lập biên bản. |
| Người dùng vai khách hàng | ……… (nhóm cử) | Thao tác các bước của KH-A, KH-B. |
| Người dùng vai quản trị viên | ……… (nhóm cử) | Thao tác các bước của QTV. |
| Hỗ trợ kỹ thuật, sửa lỗi chặn (6.6) | Lê Trung Phong, Nguyễn Tuấn Khôi, Nguyễn Minh Thức | Xem lỗi, sửa, cập nhật gói demo; không thao tác thay người dùng. |
| Quyết định Go / No-go | Cả nhóm; PM Lê Trung Phong ký | Theo mục 4. |

## 3. Môi trường và dữ liệu

| Mục | Nội dung |
| --- | --- |
| Máy | Máy đã cài ở 6.4 ([05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md)); ghi tên máy, Windows, XAMPP, PHP vào biên bản. |
| Gói demo | Gói 6.3 (hoặc gói cập nhật sau 6.6); ghi mã commit vào biên bản. |
| Database | Cài mới theo 02 sáng 17/11. Không cài lại giữa hai ngày: UAT-25, UAT-26 cần đơn tạo từ 17/11. Không dùng database chung của nhóm. |
| Tài khoản | QTV: tạo bằng `create_admin.php` theo 02. KH-A, KH-B: đăng ký ở `/register` (email `…@localtour.test`) trong UAT-07. Không ghi mật khẩu vào tài liệu. |
| Thanh toán | Khóa VNPay sandbox và VietQR đã điền trong `.env` của máy UAT. VietQR: không chuyển tiền thật, khách bấm “Tôi đã chuyển khoản”, QTV đối chiếu. VNPay: thẻ thử của VNPay sandbox. |
| Lịch tự hủy | Đã chạy `src/scripts/register_expire_task.bat`. |
| Trình duyệt | Chrome bản mới, desktop. Hai cửa sổ: một cửa sổ thường cho khách, một cửa sổ ẩn danh cho QTV. |
| Minh chứng | Thư mục `MinhChung_UAT_Sprint6/`, ảnh đặt tên `UAT-xx_mo-ta.png`. Che email, mã QR và số tài khoản; không chụp trang “Chuyển khoản VietQR”. |

Tour dùng trong ca: tour 1 “Hà Nội qua những món ăn phố cổ” (không chia gói; giá vé theo lịch, phụ thu “Phụ thu đi riêng, không ghép khách” 500.000đ / nhóm, tùy chọn “Thêm phần chè cuối tour” 35.000đ / người); tour 3 “Phố cổ theo cách của bạn” (3 gói, tối đa 4 khách); 2 tour ở tab “Chờ duyệt” của trang quản trị.

Đơn tạo trong lúc chạy (ghi mã đơn thật vào cột Ghi chú):

| Đơn | Tài khoản | Tạo ở | Dùng tiếp ở |
| --- | --- | --- | --- |
| A1 | KH-A | UAT-10 (tour 1, 2 người lớn) | UAT-13, 18, 19, 24, 27, 29 |
| A2 | KH-A | UAT-11 (tour 3, có gói) | UAT-14, 21, 28 |
| A3, B3 | KH-A, KH-B | UAT-17 (lịch sức chứa 2) | UAT-17 |
| A4 | KH-A | UAT-26 (ngày 17/11) | UAT-26 |
| B1 | KH-B | UAT-15 | UAT-15 |
| B2 | KH-B | UAT-16 | UAT-16 |
| B4 | KH-B | UAT-20 (ngày 17/11) | UAT-20, 22, 23, 24, 25 |
| B5 | KH-B | UAT-34 (tour thêm ở UAT-32) | UAT-34 |
| B6 | KH-B | UAT-36 | UAT-36 |

## 4. Tiêu chí vào / ra và quy tắc Go / No-go

| Tiêu chí vào (trước khi chạy 17/11) |
| --- |
| 1. Gói demo cài được trên máy UAT chỉ theo 02; biên bản 05 không còn lỗi chặn. |
| 2. Bước kiểm tra cài đặt của 02 đạt; `/tours` hiện 9 tour; QTV đăng nhập được `/admin/login`. |
| 3. Khóa VNPay sandbox, VietQR đã điền; lịch tự hủy đã cài. |
| 4. Nhóm đã quyết định Go ở System Test Exit Sprint 5. |

| Tiêu chí ra (chốt 19/11) |
| --- |
| 1. Đã chạy hết 37 ca; ca chưa chạy có lý do ở cột Ghi chú. |
| 2. 33/33 ca Must Đạt. |
| 3. Không còn lỗi Critical / High mở. |
| 4. Lỗi Medium / Low còn mở có người phụ trách và hướng xử lý (sửa ở Sprint 7 hoặc chấp nhận). |
| 5. Biên bản mục 8 và bảng tổng hợp mục 9 có chữ ký. |

Quy tắc quyết định:

| Quyết định | Khi nào |
| --- | --- |
| Go | Đạt cả 5 tiêu chí ra. |
| Go có điều kiện | Đạt tiêu chí 2, 3, 5; còn ca Should / Could không đạt hoặc ca chưa chạy vì môi trường (mạng, cổng VNPay), có ngày chạy lại trong Sprint 7. |
| No-go | Còn ca Must không đạt hoặc lỗi Critical / High mở sau 6.6. Sửa, cập nhật gói, chạy lại ca liên quan; chốt lại trong Sprint 7. |

Mức độ lỗi (giữ như Sprint 5):

| Mức | Định nghĩa | Xử lý |
| --- | --- | --- |
| Critical | Sai / mất dữ liệu đơn, chỗ hoặc tiền; lộ đơn của khách khác; khách hàng dùng được chức năng quản trị; lỗi PHP / trang trắng chặn cả một story. | Sửa 18/11 (6.6); còn mở → No-go |
| High | Chức năng chính của một story sai hoặc không làm được, không có cách khác. | Sửa 18/11 (6.6); còn mở → No-go |
| Medium | Chạy nhưng sai ở trường hợp phụ, thông báo sai / thiếu; có cách làm khác. | Sửa nếu kịp, không thì chuyển Sprint 7 |
| Low | Câu chữ, căn lề, giao diện nhỏ; không ảnh hưởng nghiệp vụ. | Ghi nhận, chuyển Sprint 7 nếu chưa sửa |

Defect log dùng cột như Sprint 5 (Mã lỗi, Ca UAT, Tiêu đề, Mức độ / Loại, Bước tái hiện, Kết quả mong đợi / thực tế, Minh chứng, Người xử lý / Commit sửa, Ngày phát hiện / Ngày chạy lại, Trạng thái); mã lỗi nối tiếp DEF-13: DEF-14, DEF-15…

## 5. Lịch UAT

| Ngày | Việc | Người |
| --- | --- | --- |
| 17/11 | Kiểm tra tiêu chí vào; chạy UAT-01 → UAT-24 và bước 1 của UAT-25, UAT-26 (đơn để kiểm tra tự hủy); báo ngay lỗi chặn. | Hải, Thành, người dùng đại diện |
| 18/11 | Chạy UAT-25, UAT-26 sau hạn thanh toán; UAT-27 → UAT-37. | Hải, Thành, người dùng đại diện |
| 18/11 | Sửa lỗi Critical / High (6.6), cập nhật gói, chạy lại ca liên quan. | Phong, Thức, Khôi (người làm chức năng có lỗi); Hải, Thành chạy lại |
| 18/11 | Ký biên bản UAT (mục 8). | Cả nhóm |
| 19/11 | Tổng hợp nghiệm thu demo (mục 9), quyết định Go / No-go. | Hải, Thành lập; cả nhóm quyết định |

## 6. Checklist UAT

Cột Kết quả ghi **Đạt** hoặc **Không đạt**. Ca không chạy được vì môi trường: để trống Kết quả, ghi lý do ở Ghi chú. Không đạt: ghi mã lỗi DEF-xx ở Ghi chú.

### 6.1. Xem, tìm và so sánh tour (chưa đăng nhập)

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-01 | US-01 | Xem danh sách tour | 1. Mở `/tours`. 2. Xem từng thẻ tour. | Trang “Bảng tin du lịch” ghi “9 tour”. Mỗi thẻ có tên tour, điểm đến, “Nơi khởi hành”, giá. Trường thiếu ghi “Chưa cập nhật”, không lấy dữ liệu của tour khác. | | |
| UAT-02 | US-02 | Xem chi tiết tour | 1. Bấm “Xem chi tiết” ở tour 1. 2. Xem các mục. 3. Bấm “Quay lại danh sách”. | Có Thông tin tour, Lịch trình, Lịch khởi hành, Dịch vụ (tách đã bao gồm / không bao gồm), Chính sách của đúng tour 1; nội dung khớp trang quản trị của tour. Bước 3 về bảng tin. | | |
| UAT-03 | US-03 | Tìm kiếm và lọc | 1. Gõ tên một điểm đến vào ô tìm, bấm “Tìm”. 2. Chọn một “Điểm đến:” và một “Loại hình:”. 3. Tìm một chuỗi không có tour. 4. Bấm “Xóa bộ lọc”. | Bước 1–2 chỉ hiện tour đúng điều kiện, số tour ở đầu danh sách khớp số thẻ. Bước 3: “Không có tour phù hợp”. Bước 4: trở lại 9 tour. | | |
| UAT-04 | US-03 | Sắp xếp theo giá | 1. Ô “Giá” chọn “Thấp đến cao”. 2. Chọn “Cao đến thấp”. | Giá tăng dần / giảm dần đúng; mọi giá cùng đơn vị VND. | | |
| UAT-05 | US-04 | So sánh 2–3 tour | 1. Bấm “Thêm vào so sánh” ở 1 tour, mở “So sánh tour” ở menu trái. 2. Thêm 2 tour nữa. 3. Thêm tour thứ 4. 4. Bấm “So sánh tour”. 5. Bấm “Bỏ” ở một tour, tải lại trang. | Bước 1: “Cần ít nhất 2 tour để so sánh”. Bước 2: khung ghi “3/3 tour”. Bước 3 bị chặn: “Chỉ so sánh tối đa 3 tour. Bỏ bớt một tour trước khi thêm tour khác.” Bước 4: các tour đặt cạnh nhau theo 4 nhóm (Giá và lịch, Thông tin tour, Lịch trình và dịch vụ, Chính sách), ô thiếu ghi “Chưa cập nhật”. Bước 5: còn 2 tour, vẫn giữ sau khi tải lại. | | |
| UAT-06 | US-15 | Xem đánh giá | 1. Mở mục “Đánh giá” của một tour có đánh giá. 2. Mở mục này ở một tour chưa có đánh giá (nếu có). | Bước 1: điểm “x/5 (N đánh giá)” và nhận xét đã duyệt. Bước 2: “Chưa có đánh giá”. | | Could |

### 6.2. Tài khoản và đặt tour

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-07 | US-16 | Đăng ký tài khoản | 1. “Đăng ký”, tạo KH-A. 2. Đăng xuất, đăng ký lại cùng email. 3. Đăng ký với mật khẩu 7 ký tự hoặc hai ô mật khẩu khác nhau. 4. Tạo KH-B. | Bước 1, 4: tạo được tài khoản, đầu trang có tên và “Đơn của tôi”. Bước 2: “Email này đã được dùng.” Bước 3: báo lỗi ở ô mật khẩu, không tạo tài khoản. | | |
| UAT-08 | US-16 | Đăng nhập, quay lại tour đang chọn, đăng xuất | 1. Đăng nhập KH-A sai mật khẩu. 2. Đăng nhập email chưa đăng ký. 3. Chưa đăng nhập, ở tour 1 chọn một ngày và 2 người lớn, bấm “Đăng nhập để đặt tour”, đăng nhập KH-A. 4. Đăng xuất. | Bước 1, 2 cùng báo “Email hoặc mật khẩu không đúng.” Bước 3 vào thẳng “Hoàn tất thông tin đặt tour” của tour 1 với đúng ngày và số khách đã chọn. Bước 4: đầu trang lại có “Đăng nhập”, “Đăng ký”. | | |
| UAT-09 | US-05 | Giá minh bạch, tách phụ thu | 1. KH-A mở tour 1, chọn một lịch, 2 người lớn + 1 trẻ em. 2. “Đặt tour”, tích “Thêm phần chè cuối tour”. 3. “Xem lại & xác nhận”, không gửi. | Bước 1: giá theo loại vé, ghi VND; “Tạm tính tiền vé” = tổng tiền vé, ghi chưa gồm phụ thu. Bước 2–3: dòng vé và dòng tùy chọn tách riêng; chè tính 35.000đ × 3 khách; “Tổng tiền” = vé + tùy chọn (lịch giá 650.000đ / 460.000đ: 1.760.000đ + 105.000đ = 1.865.000đ). | | |
| UAT-10 | US-06 | Gửi yêu cầu đặt tour (tour không chia gói) | 1. KH-A đặt tour 1, 2 người lớn; bỏ trống họ tên khách 2, không tích điều kiện; bấm “Xem lại & xác nhận”. 2. Nhập đủ, tích điều kiện, “Xem lại & xác nhận”, “Gửi yêu cầu đặt tour”. 3. Mở “Đơn của tôi”. | Bước 1 bị chặn: “Vui lòng nhập họ tên khách 2.”, “Vui lòng đồng ý điều kiện đặt tour và chính sách hủy.” Bước 2: trang “Đơn LTxxxxxx” (đơn A1), “Đã gửi yêu cầu đặt tour”, trạng thái “Chờ xác nhận”. Bước 3: A1 có trong danh sách. | | Ghi mã A1 |
| UAT-11 | US-06 | Đặt tour có gói | 1. KH-A mở tour 3, chọn gói “Đền chùa và tín ngưỡng”, 2 người lớn. 2. Đặt và gửi yêu cầu (đơn A2). | Bước 1: “Tạm tính tiền vé” 1.900.000đ. Bước 2: trang đơn ghi đúng tên gói; QTV thấy cùng gói và giá ở trang yêu cầu. | | Ghi mã A2 |

### 6.3. Xử lý yêu cầu đặt tour (quản trị viên)

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-12 | US-22 | Xem danh sách và chi tiết yêu cầu | 1. QTV đăng nhập, “Yêu cầu đặt tour”, tab “Chờ xác nhận”. 2. Tìm theo mã A1. 3. Bấm “Xem”. | A1, A2 có trong tab. Chi tiết A1 khớp dữ liệu khách nhập (tour, lịch, vé, danh sách khách, tổng tiền); có “Lịch sử xử lý”. | | |
| UAT-13 | US-23, US-09 | Xác nhận chỗ và giá | 1. Ghi số chỗ còn của lịch của A1. 2. Ở A1 chọn “Xác nhận chỗ và giá (giữ chỗ, chuyển “Chờ thanh toán”, hạn 24 giờ)”, giữ tổng giá, bấm “Cập nhật trạng thái”. 3. KH-A mở A1. | Bước 2: “Đã cập nhật trạng thái yêu cầu.”; A1 “Chờ thanh toán”, hạn thanh toán = lúc xác nhận + 24 giờ; lịch sử ghi người làm và thời điểm; số chỗ còn giảm 2. Bước 3: khách thấy “Chờ thanh toán”, hạn, số tiền cần thanh toán và “Thanh toán ngay”. | | |
| UAT-14 | US-09 | Chốt tổng giá khác giá lúc đặt | 1. Ở A2 chọn “Xác nhận chỗ và giá”, đổi “Tổng giá chốt (VND)”, để trống lý do, cập nhật. 2. Nhập lý do, cập nhật. 3. KH-A mở A2. | Bước 1: “Đổi tổng giá cần ghi lý do (vd. phụ thu đón khách sạn xa).”, đơn không đổi. Bước 2: A2 “Chờ thanh toán” với tổng giá mới. Bước 3: số tiền cần thanh toán = tổng giá mới. | | |
| UAT-15 | US-24, US-09 | Từ chối yêu cầu | 1. KH-B gửi một yêu cầu (đơn B1). 2. QTV chọn “Từ chối yêu cầu”, để trống “Lý do / ghi chú”, cập nhật. 3. Nhập lý do, cập nhật. 4. KH-B mở B1. | Bước 2: “Từ chối hoặc hủy yêu cầu cần nhập lý do.” Bước 3: B1 “Từ chối”; lịch sử ghi lý do, người làm, thời điểm. Bước 4: khách thấy “Từ chối” và “Lý do: …”. | | |
| UAT-16 | US-24 | Hủy yêu cầu đã giữ chỗ | 1. KH-B gửi yêu cầu (B2), QTV xác nhận chỗ; ghi số chỗ còn của lịch. 2. QTV chọn “Hủy yêu cầu”, nhập lý do, cập nhật. 3. KH-B mở B2. | Bước 2: B2 “Đã hủy”, số chỗ còn của lịch cộng lại đúng số khách; B2 không chuyển được sang trạng thái khác. Bước 3: khách thấy “Đã hủy” và lý do. | | |
| UAT-17 | US-08 | Không xác nhận vượt sức chứa | 1. QTV thêm cho tour 1 một lịch mới, “Sức chứa (chỗ)” = 2. 2. KH-A (A3) và KH-B (B3) mỗi người gửi yêu cầu 2 người lớn cho lịch này. 3. QTV xác nhận A3. 4. QTV xác nhận B3. 5. QTV từ chối B3 kèm lý do. | Bước 2: không chọn được quá số chỗ còn của lịch. Bước 3: lịch còn 0 chỗ, trạng thái “Hết chỗ”. Bước 4 bị chặn: “Lịch khởi hành không còn đủ chỗ cho yêu cầu này, chưa xác nhận được. …”. Bước 5: B3 “Từ chối”. | | |

### 6.4. Thanh toán và voucher

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-18 | US-11 | Chuyển khoản VietQR | 1. KH-A mở A1, “Thanh toán ngay”, “Lấy mã VietQR”. 2. Không chuyển tiền thật; bấm “Tôi đã chuyển khoản”. | Bước 1: có mã QR, số tiền = tổng giá đã chốt, nội dung là mã thanh toán của A1 (`LTxxxxxxP1`). Bước 2: “Đã ghi nhận bạn báo chuyển khoản…”; khoản “Chờ đối chiếu”; A1 có trong “Đối chiếu thanh toán” của QTV. | | Không chụp trang chuyển khoản |
| UAT-19 | US-12 | Đối chiếu VietQR: đã nhận tiền | 1. QTV “Đối chiếu thanh toán”, bấm “Đối chiếu” ở A1. 2. Bấm “Đã nhận tiền”. 3. KH-A mở A1. | Bước 2: “Đã xác nhận nhận tiền: đơn chuyển “Đã xác nhận” và khách nhận được voucher.”; lịch sử ghi người làm và thời điểm. Bước 3: A1 “Đã xác nhận”, khoản “Thành công”, có “Mã voucher”. | | |
| UAT-20 | US-12 | Đối chiếu VietQR: không khớp | 1. Ngày 17/11: KH-B gửi yêu cầu (B4), QTV xác nhận chỗ; ghi hạn thanh toán. 2. KH-B “Lấy mã VietQR”, “Tôi đã chuyển khoản”. 3. QTV bấm “Không khớp” không nhập lý do, rồi nhập lý do và bấm lại. 4. KH-B mở B4. | Bước 3: thiếu lý do báo “Không khớp” / “Không có giao dịch” cần nhập lý do; có lý do: “Đã báo chuyển khoản không khớp. Đơn vẫn chờ thanh toán tới hết hạn giữ chỗ.” Bước 4: B4 “Chờ thanh toán”, hạn không đổi, chưa có voucher, thanh toán lại được. | | Ghi mã B4 |
| UAT-21 | US-10 | Thanh toán VNPay sandbox | 1. KH-A mở A2, “Thanh toán ngay”, “Thanh toán qua VNPay”. 2. Thanh toán bằng thẻ thử ở cổng VNPay sandbox. | Số thẻ chỉ nhập ở cổng VNPay, không nhập ở LocalTour. Về trang A2 với “Thanh toán VNPay thành công. Đơn đã được xác nhận và voucher đã sẵn sàng.”; A2 “Đã xác nhận”, khoản “Thành công” đúng tổng giá đã chốt; có mã voucher. | | Cần Internet |
| UAT-22 | US-10 | Hủy giao dịch ở cổng VNPay | 1. KH-B mở B4, “Thanh toán ngay”, “Thanh toán qua VNPay”. 2. Bấm hủy giao dịch ở cổng VNPay. | Về trang B4 với thông báo đã hủy giao dịch ở VNPay; B4 vẫn “Chờ thanh toán”, hạn không đổi; thanh toán lại được. | | Cần Internet |
| UAT-23 | US-12 | Giao dịch VNPay chưa rõ kết quả | 1. KH-B mở B4, “Thanh toán qua VNPay”, đóng tab cổng VNPay (không thanh toán, không hủy). 2. Sau 15 phút, QTV mở “Đối chiếu thanh toán”. 3. “Đối chiếu”, nhập ghi chú, bấm “Không có giao dịch”. | Bước 2: khoản của B4 ở “Giao dịch VNPay chưa rõ kết quả”. Bước 3: “Đã ghi “Không có giao dịch VNPay”. Đơn còn hạn giữ chỗ thì khách thanh toán lại được.”; B4 vẫn “Chờ thanh toán”. | | Cần Internet |
| UAT-24 | US-10, US-12 | Voucher | 1. KH-A mở A1, “Xem và in voucher”, “In voucher”. 2. KH-B mở `/bookings/<mã B4>/voucher`. | Bước 1: voucher có mã voucher, mã đơn, tour, ngày, giờ, điểm gặp, đơn vị tổ chức, danh sách khách, số tiền đã thanh toán; in được. Bước 2: không có voucher, quay về trang đơn B4. | | |
| UAT-25 | US-13 | Tự hủy đơn quá hạn thanh toán | 1. (17/11) Dùng B4 từ UAT-20, không thanh toán; ghi số chỗ còn của lịch. 2. (18/11, sau hạn của B4) KH-B mở B4; QTV mở lịch của B4. | B4 “Đã hủy”, lịch sử ghi “Hệ thống”; số chỗ còn của lịch cộng lại đúng số khách; không thanh toán được nữa. | | Chạy 18/11 |
| UAT-26 | US-13 | Đơn chờ đối chiếu không bị tự hủy | 1. (17/11) KH-A gửi yêu cầu (A4), QTV xác nhận chỗ; KH-A “Lấy mã VietQR”, “Tôi đã chuyển khoản”; QTV chưa đối chiếu. 2. (18/11, sau hạn của A4) KH-A mở A4; QTV mở “Đối chiếu thanh toán”. | A4 vẫn “Chờ thanh toán”, khoản “Chờ đối chiếu”; A4 vẫn có trong “Chuyển khoản VietQR chờ đối chiếu”. | | Chạy 18/11 |

### 6.5. Đổi ngày / hủy tour

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-27 | US-14 | Đổi ngày, được đồng ý | 1. KH-A mở A1, “Đổi ngày / hủy tour”, chọn “Đổi sang ngày khác”, chọn ngày, nhập lý do, “Gửi yêu cầu”. 2. Mở lại trang và thử gửi thêm một yêu cầu. 3. QTV “Đổi ngày / hủy tour”, “Xử lý”, chọn “Đồng ý đổi ngày”, nhập ghi chú, “Lưu kết quả”. 4. KH-A mở A1. | Bước 1: chỉ liệt kê lịch còn đủ chỗ cho 2 khách; yêu cầu “Chờ xử lý”, đơn chưa đổi. Bước 2: không gửi được (đơn đang có yêu cầu chờ xử lý). Bước 3: “Đã đồng ý yêu cầu và cập nhật đơn.” Bước 4: A1 ở lịch mới, giữ số khách và tổng tiền; yêu cầu “Đã đồng ý” kèm “Phản hồi của LocalTour”; lịch sử đơn ghi lại. | | Should |
| UAT-28 | US-14 | Hủy tour, được đồng ý | 1. KH-A mở A2, “Đổi ngày / hủy tour”, chọn “Hủy tour”, xem số tiền dự kiến hoàn, nhập lý do, gửi. 2. QTV “Xử lý”, chọn “Đồng ý hủy tour”, nhập “Số tiền hoàn (đ)” và ghi chú, “Lưu kết quả”. 3. KH-A mở A2. | Bước 1: số tiền dự kiến hoàn đúng chính sách hủy lưu cùng đơn. Bước 2: A2 “Đã hủy”, chỗ được trả lại lịch, ghi khoản hoàn (chuyển khoản lại thủ công, không hoàn qua VNPay). Bước 3: khách thấy “Đã đồng ý”, ghi chú và trạng thái “Đã hủy”. | | Should |
| UAT-29 | US-14 | Từ chối yêu cầu | 1. KH-A mở A1, gửi yêu cầu “Hủy tour” kèm lý do. 2. QTV chọn “Từ chối, giữ nguyên đơn”, để trống ghi chú, lưu. 3. Nhập ghi chú, lưu. 4. KH-A mở A1. | Bước 2: không lưu được (ghi chú bắt buộc). Bước 3: “Đã từ chối yêu cầu. Đơn giữ nguyên.” Bước 4: yêu cầu “Đã từ chối” kèm phản hồi; A1 vẫn “Đã xác nhận”; gửi được yêu cầu mới. | | Should |

### 6.6. Phân quyền, quản trị tour và thống kê

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-30 | US-16, US-22 | Phân quyền | 1. KH-B mở `/bookings/<mã A1>`. 2. KH-A mở `/admin`. 3. Chưa đăng nhập, mở `/admin`. 4. QTV mở trang chi tiết tour 1. | Bước 1: “Không tìm thấy đơn” (không lộ đơn của KH-A). Bước 2: “Bạn không có quyền truy cập trang này.” Bước 3: chuyển tới “Đăng nhập quản trị”. Bước 4: “Tài khoản quản trị không đặt tour được. Đăng nhập bằng tài khoản khách hàng để đặt tour.”, không có nút “Đặt tour”. | | |
| UAT-31 | US-07 | Quản lý đơn vị tổ chức | 1. QTV “Đơn vị tổ chức”, “Thêm đơn vị” (Đang hợp tác). 2. “Sửa” số điện thoại, “Lưu thay đổi”. 3. Ở trang “Sửa” của đơn vị vừa thêm, tích “Tôi hiểu đơn vị sẽ bị xóa hẳn.”, “Xóa đơn vị”. 4. Thử xóa một đơn vị đang có tour. | Bước 1–3: “Đã thêm đơn vị tổ chức.”, “Đã lưu thông tin đơn vị tổ chức.”, “Đã xóa đơn vị tổ chức.”; đơn vị khác không đổi. Bước 4 bị chặn: “Đơn vị còn N tour nên không xóa được. …”. | | |
| UAT-32 | US-07, US-21 | Thêm tour tới khi khách thấy | 1. “Duyệt tour”, “Thêm tour” với một đơn vị đang hợp tác. 2. Thêm 1 lịch khởi hành và giá vé, 1 ảnh, 2 mục lịch trình, 2 dịch vụ (1 đã bao gồm, 1 không bao gồm), 1 phiên bản chính sách hủy. 3. Mở `/tours`. 4. “Phê duyệt tour”, mở lại `/tours` và trang tour. | Bước 1: “Đã thêm tour. Tour đang ở trạng thái Chờ duyệt…”. Bước 3: tour mới chưa có trên bảng tin. Bước 4: “Đã phê duyệt tour.”; tour hiện trên bảng tin, trang chi tiết đúng nội dung đã nhập; tour khác không đổi. | | |
| UAT-33 | US-21 | Từ chối tour chờ duyệt | 1. Tab “Chờ duyệt”, mở một tour, bấm “Từ chối tour” khi để trống lý do. 2. Nhập “Lý do từ chối (bắt buộc)”, “Từ chối tour”. 3. Mở đường dẫn tour đó ở trang khách. | Bước 1: không lưu được. Bước 2: “Đã từ chối tour và lưu lý do.”; tour ở tab “Bị từ chối”, “Lịch sử xử lý” ghi người làm, thời điểm, lý do. Bước 3: “Không tìm thấy tour”. | | |
| UAT-34 | US-07 | Xóa tour, ngừng hiển thị, hiển thị lại | 1. Ở trang “Ảnh, lịch trình, dịch vụ, chính sách” của tour 1, tab “Xóa tour”, tích xác nhận, bấm “Xóa tour”. 2. KH-B đặt tour mới ở UAT-32, QTV từ chối đơn; QTV xóa tour đó. 3. Ở tab “Hiển thị lại”, bấm “Chuyển về Chờ duyệt”, rồi “Phê duyệt tour”. 4. Thêm một tour khác (chưa có đơn) rồi xóa. | Bước 1 bị chặn: tour còn đơn đang xử lý. Bước 2: tour chuyển “Ngừng hiển thị”, không còn trên bảng tin, đơn cũ vẫn xem được. Bước 3: tour về “Chờ duyệt”, duyệt xong hiện lại. Bước 4: “Đã xóa tour.”, tour không còn ở tab “Tất cả”. | | |
| UAT-35 | US-17, US-18 | Thống kê tài khoản và tour | 1. QTV “Tổng quan”, ghi ô “Tài khoản khách hàng” và “Tour”. 2. Đăng ký thêm một khách hàng, tải lại. 3. So ô “Tour” với số tour ở các tab của “Duyệt tour”. | Bước 2: “Tài khoản khách hàng” tăng 1. Bước 3: số chờ duyệt / đã duyệt / bị từ chối khớp các tab; tour chưa duyệt không có trên bảng tin. Khách hàng không xem được trang này (UAT-30). | | |
| UAT-36 | US-19 | Thống kê yêu cầu theo trạng thái và thời gian | 1. Ghi bảng “Yêu cầu đặt tour theo trạng thái”. 2. So với số đơn ở từng tab của “Yêu cầu đặt tour”. 3. “Thống kê”: Theo ngày, “Từ ngày” = “Đến ngày” = hôm nay, “Xem thống kê”; ghi số yêu cầu. 4. KH-B gửi thêm một yêu cầu; QTV xem lại bước 1 và 3. 5. Chọn khoảng ngày đã qua, không gồm hôm nay. | Bước 2: số theo trạng thái khớp từng tab. Bước 4: “Chờ xác nhận” và “Số yêu cầu đặt tour theo ngày tạo” của hôm nay cùng tăng 1. Bước 5: không tính các yêu cầu tạo hôm nay. | | |
| UAT-37 | US-20 | Doanh thu theo ngày / tháng / năm | 1. “Thống kê”: Theo tháng, “Xem thống kê”. 2. Bấm kỳ “Tháng 11/2026”. 3. Lặp lại với Theo ngày và Theo năm. | Bước 1: “Doanh thu theo ngày thanh toán” có Lượt thanh toán, Doanh thu gộp, Hoàn tiền, Doanh thu thuần = gộp − hoàn. Bước 2: “Khoản thanh toán theo kỳ” liệt kê từng khoản, tổng khớp số của kỳ; có khoản của A1, A2; không có khoản chưa đối chiếu (A4). Bước 3: tổng các kỳ khớp nhau. | | |

## 7. Đối chiếu User Story → ca UAT

| US | Ưu tiên | Ca UAT | US | Ưu tiên | Ca UAT |
| --- | --- | --- | --- | --- | --- |
| US-01 | Must | UAT-01 | US-13 | Must | UAT-25, 26 |
| US-02 | Must | UAT-02 | US-14 | Should | UAT-27, 28, 29 |
| US-03 | Must | UAT-03, 04 | US-15 | Could | UAT-06 |
| US-04 | Must | UAT-05 | US-16 | Must | UAT-07, 08, 30 |
| US-05 | Must | UAT-09 | US-17 | Must | UAT-35 |
| US-06 | Must | UAT-10, 11 | US-18 | Must | UAT-35 |
| US-07 | Must | UAT-31, 32, 34 | US-19 | Must | UAT-36 |
| US-08 | Must | UAT-17 | US-20 | Must | UAT-37 |
| US-09 | Must | UAT-13, 14, 15 | US-21 | Must | UAT-32, 33 |
| US-10 | Must | UAT-21, 22, 24 | US-22 | Must | UAT-12, 30 |
| US-11 | Must | UAT-18 | US-23 | Must | UAT-13 |
| US-12 | Must | UAT-19, 20, 23, 24 | US-24 | Must | UAT-15, 16 |

## 8. Biên bản nghiệm thu UAT (điền ngày 18/11)

| Mục | Nội dung |
| --- | --- |
| Ngày | …/11/2026, từ …… đến …… |
| Địa điểm / máy | |
| Windows / XAMPP / PHP | |
| Mã commit gói demo | |

Thành phần:

| Họ tên | Vai trò | Có mặt |
| --- | --- | --- |
| Lê Trung Phong | PM, hỗ trợ kỹ thuật | ☐ |
| Nguyễn Tuấn Khôi | Phát triển, hỗ trợ kỹ thuật | ☐ |
| Nguyễn Minh Thức | Phát triển, hỗ trợ kỹ thuật | ☐ |
| Hồ Duy Hải | QA, điều phối UAT | ☐ |
| Đỗ Sơn Thành | QA, điều phối UAT | ☐ |
| ……… | Người dùng vai khách hàng | ☐ |
| ……… | Người dùng vai quản trị viên | ☐ |

Tổng hợp kết quả:

| Nhóm | Số ca | Đạt | Không đạt | Chưa chạy |
| --- | --- | --- | --- | --- |
| Xem, tìm và so sánh tour (UAT-01–06) | 6 | | | |
| Tài khoản và đặt tour (UAT-07–11) | 5 | | | |
| Xử lý yêu cầu đặt tour (UAT-12–17) | 6 | | | |
| Thanh toán và voucher (UAT-18–26) | 9 | | | |
| Đổi ngày / hủy tour (UAT-27–29) | 3 | | | |
| Phân quyền, quản trị tour và thống kê (UAT-30–37) | 8 | | | |
| **Tổng** | **37** | | | |
| Trong đó ca Must | 33 | | | |

Lỗi còn mở:

| Mã lỗi | Ca UAT | Mô tả | Mức độ | Hướng xử lý | Người phụ trách | Hạn |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

| Mục | Nội dung |
| --- | --- |
| Lỗi đã sửa trong 6.6 (mã DEF, commit) | |
| Ý kiến của người dùng | |
| Quyết định | ☐ Go ☐ Go có điều kiện ☐ No-go – lý do / điều kiện: |
| Người ký | PM: Lê Trung Phong ……… · QA: Hồ Duy Hải ……… · Đỗ Sơn Thành ……… · Người dùng: ……… · ……… · Ngày …/11/2026 |

## 9. Tổng hợp nghiệm thu demo (6.7, điền ngày 19/11)

| US | Nội dung | Ưu tiên | Ca UAT | Kết quả (Đạt / Không đạt / Chưa chạy) | Lỗi liên quan | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| US-01 | Danh sách tour | Must | UAT-01 | | | |
| US-02 | Chi tiết tour | Must | UAT-02 | | | |
| US-03 | Tìm, lọc, sắp xếp theo giá | Must | UAT-03, 04 | | | |
| US-04 | So sánh 2–3 tour | Must | UAT-05 | | | |
| US-05 | Giá minh bạch, phụ thu | Must | UAT-09 | | | |
| US-06 | Gửi yêu cầu đặt tour | Must | UAT-10, 11 | | | |
| US-07 | Quản lý tour, nội dung, đơn vị tổ chức | Must | UAT-31, 32, 34 | | | |
| US-08 | Lịch khởi hành và sức chứa | Must | UAT-17 | | | |
| US-09 | Xác nhận / từ chối, chốt tổng giá | Must | UAT-13, 14, 15 | | | |
| US-10 | Đơn của tôi, thanh toán VNPay | Must | UAT-21, 22, 24 | | | |
| US-11 | Chuyển khoản VietQR | Must | UAT-18 | | | |
| US-12 | Đối chiếu VietQR và VNPay chưa rõ kết quả | Must | UAT-19, 20, 23, 24 | | | |
| US-13 | Tự hủy đơn quá hạn | Must | UAT-25, 26 | | | |
| US-14 | Đổi ngày / hủy tour | Should | UAT-27, 28, 29 | | | |
| US-15 | Xem đánh giá | Could | UAT-06 | | | |
| US-16 | Đăng ký, đăng nhập, đăng xuất | Must | UAT-07, 08, 30 | | | |
| US-17 | Thống kê người dùng | Must | UAT-35 | | | |
| US-18 | Thống kê tour | Must | UAT-35 | | | |
| US-19 | Thống kê yêu cầu đặt tour | Must | UAT-36 | | | |
| US-20 | Thống kê doanh thu | Must | UAT-37 | | | |
| US-21 | Duyệt tour | Must | UAT-32, 33 | | | |
| US-22 | Danh sách, chi tiết yêu cầu | Must | UAT-12, 30 | | | |
| US-23 | Xác nhận yêu cầu | Must | UAT-13 | | | |
| US-24 | Từ chối / hủy yêu cầu | Must | UAT-15, 16 | | | |

| Mục | Kết quả |
| --- | --- |
| Gói demo đã nghiệm thu (mã commit) | |
| Installation Guide đã sửa theo 6.4 | ☐ Có ☐ Không cần sửa |
| User Guide đã sửa theo UAT | ☐ Có ☐ Không cần sửa |
| Số US đạt / tổng | __ / 24 |
| Lỗi mở theo mức (Critical / High / Medium / Low) | __ / __ / __ / __ |
| Điểm còn thiếu | |
| Chuyển sang Sprint 7 | |
| Quyết định nghiệm thu demo | ☐ Go ☐ Go có điều kiện ☐ No-go – lý do: |
| Bằng chứng | Biên bản mục 8, defect log, `MinhChung_UAT_Sprint6/`, [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md) |
| Người ký | QA: Hồ Duy Hải ……… · Đỗ Sơn Thành ……… · PM: Lê Trung Phong ……… · Ngày …/11/2026 |
