# Kế hoạch, checklist và biên bản UAT Sprint 6

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 6 – Chuẩn bị demo, hướng dẫn và nghiệm thu UAT (13/11 – 19/11/2026) |
| WBS | 6.5 – Thực hiện UAT; 6.6 – Sửa lỗi chặn UAT; 6.7 – Tổng hợp nghiệm thu demo |
| Người phụ trách | Hồ Duy Hải, Đỗ Sơn Thành (QA / Documentation); chạy ca: nhóm PCG; sửa lỗi: Lê Trung Phong, Nguyễn Tuấn Khôi, Nguyễn Minh Thức |
| Căn cứ | Product Backlog (USECASEPLAN): US-01 → US-29 và tiêu chí nghiệm thu; yêu cầu thay đổi CR2 (FR-26 → FR-30; điều chỉnh FR-08, FR-11, FR-17, FR-25); Báo cáo tổng hợp Sprint 5 (mục 3, 8.1); Test Plan và RTM Sprint 5 (mức độ lỗi, defect log) |
| Tài liệu liên quan | [01 – Kế hoạch Sprint 6](01-ke-hoach-sprint6.md), [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md); file `GuiNhomPCG_DiaChi_TaiKhoan.txt` (địa chỉ trang demo, tài khoản QTV, thẻ thử VNPay sandbox) |
| Bộ ca UAT | UAT-01 → UAT-54 (50 Must, 3 Should, 1 Could), phủ 29/29 User Story |
| Trạng thái | Bản nháp; đã cập nhật theo CR2 (UAT-09 → UAT-37 viết lại theo đặt tour giữ chỗ ngay, thêm UAT-38 → UAT-54). Đã chạy thử đủ 54 ca trên bản tích hợp ngày 13/11/2026 và sửa câu chữ 6 ca cho khớp màn hình (UAT-03, 06, 28, 31, 37, 42). Từ 14/11/2026 UAT chạy trên trang demo https://localtour.alwaysdata.net, nhóm PCG không cài đặt. Nhóm rà soát và chốt trước khi nhóm PCG chạy UAT ngày 16/11/2026. |

## 1. Mục tiêu và phạm vi

Mục tiêu: người dùng (vai khách hàng, quản trị viên và đơn vị tổ chức) xác nhận bản demo đáp ứng tiêu chí nghiệm thu của 29 User Story (US-01 → US-24 và 5 story của CR2: US-25 → US-29), trên trang demo https://localtour.alwaysdata.net (bản demo 6.3); có biên bản để quyết định Go / No-go ngày 19/11.

UAT khác System Test Sprint 5: thao tác như người dùng thật theo [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), không dùng DevTools, không sửa database bằng tay.

Ngoài phạm vi (không ghi “Không đạt” cho các mục này):

| Mục | Lý do |
| --- | --- |
| IPN của VNPay | Kết quả thanh toán VNPay kiểm tra lúc khách quay về LocalTour từ cổng VNPay (Return URL); luồng IPN đã thử ở Sprint 4. |
| Hoàn tiền tự động | LocalTour chuyển khoản lại thủ công ngoài hệ thống. UAT chỉ kiểm tra việc ghi khoản hoàn và ghi “Đã hoàn tiền” (UAT-53). |
| Chuyển khoản chi trả thật cho đơn vị tổ chức | Hệ thống không tự chuyển tiền. UAT dùng mã giao dịch thử, không chuyển tiền thật (UAT-54). |
| Đơn “Chờ xác nhận” trong dữ liệu mẫu | Tạo theo quy trình cũ. Đơn mới không qua bước xác nhận chỗ nên các đơn này không dùng trong ca UAT. |
| Đổi số người, đổi gói khi đổi ngày | Đổi ngày giữ nguyên số khách, gói và tổng tiền. |
| Phần thêm của trang so sánh (tổng cho N người, “Chỉ xem điểm khác nhau”, “Chọn tour này”, lưu theo tài khoản) | Giữ ở Product Backlog. |
| Khách gửi đánh giá tour (FR-16), nhãn “Thông tin chưa được xác minh” (NFR-07) | Giữ ở Product Backlog. |
| Ngày đi, Bộ lọc, Thích, Bình luận, Chia sẻ, Lưu tour | Nút đang tắt, nhãn “Sắp có”. |

## 2. Thành phần tham gia

| Vai trò | Người | Việc |
| --- | --- | --- |
| Điều phối, ghi kết quả | Hồ Duy Hải, Đỗ Sơn Thành | Chạy ca theo thứ tự, ghi kết quả và minh chứng, ghi defect log, lập biên bản. |
| Người dùng vai khách hàng | ……… (nhóm PCG) | Thao tác các bước của KH-A, KH-B. |
| Người dùng vai quản trị viên | ……… (nhóm PCG) | Thao tác các bước của QTV. |
| Người dùng vai đơn vị tổ chức | ……… (nhóm PCG) | Thao tác các bước của ĐV-A, ĐV-B. |
| Hỗ trợ kỹ thuật, sửa lỗi chặn (6.6) | Lê Trung Phong, Nguyễn Tuấn Khôi, Nguyễn Minh Thức | Xem lỗi, sửa, cập nhật trang demo; không thao tác thay người dùng. |
| Quyết định Go / No-go | Cả nhóm; PM Lê Trung Phong ký | Theo mục 4. |

## 3. Môi trường và dữ liệu

| Mục | Nội dung |
| --- | --- |
| Trang demo | https://localtour.alwaysdata.net, mở bằng trình duyệt; địa chỉ và tài khoản QTV trong file `GuiNhomPCG_DiaChi_TaiKhoan.txt` nhóm LocalTour gửi kèm. Máy của nhóm PCG chỉ cần trình duyệt và Internet, không cài gì; ghi tên máy và trình duyệt vào biên bản. |
| Bản demo | Bản 6.3 trên trang demo (hoặc bản cập nhật sau 6.6); nhóm LocalTour ghi mã commit vào biên bản. |
| Dữ liệu | Nhóm LocalTour cài mới dữ liệu mẫu trên trang demo trước buổi UAT; từ đó tới hết UAT không ai khác thao tác trên trang. Chạy hết 54 ca trong ngày. Không cài lại giữa buổi: các ca sau dùng tiếp tài khoản, đơn và khoản hoàn tiền của các ca trước (UAT-53 dùng khoản của UAT-16, UAT-28). |
| Tài khoản | QTV: nhóm LocalTour tạo trước buổi UAT, email và mật khẩu trong file `GuiNhomPCG_DiaChi_TaiKhoan.txt`. KH-A, KH-B: đăng ký ở `/register` (email `…@localtour.test`) trong UAT-07. ĐV-A, ĐV-B: QTV thêm ở trang “Đơn vị tổ chức” và cấp mật khẩu trong UAT-38 (email `…@localtour.test`). Không ghi mật khẩu vào tài liệu. |
| Thanh toán | Trang demo đã có sẵn khóa VNPay sandbox và VietQR; nhóm PCG không cần khóa nào. VietQR: tài khoản nhận là tài khoản thử nghiệm, không chuyển tiền thật, khách bấm “Tôi đã chuyển khoản”, QTV đối chiếu. VNPay: thẻ thử của VNPay sandbox, ghi trong file `GuiNhomPCG_DiaChi_TaiKhoan.txt`. Hoàn tiền và chi trả: không chuyển tiền thật, nhập mã giao dịch thử. |
| Tác vụ tự động | Trang demo có tác vụ chạy 5 phút một lần: hủy đơn quá hạn giữ chỗ, tự hoàn thành đơn của lịch đã kết thúc, lập khoản chi trả. Các trang “Đơn của tôi”, “Đơn đặt tour”, “Đối chiếu thanh toán”, “Chi trả đơn vị tổ chức” cũng chạy các bước này khi mở. |
| Thông số vận hành | Giá trị mặc định: phí dịch vụ 10 %, giữ chỗ 30 phút, ngừng nhận đặt 60 phút trước giờ khởi hành, ngừng nhận VietQR 24 giờ trước giờ khởi hành. Chỉ đổi trong UAT-48, UAT-51, UAT-52 và đặt lại như ca ghi. |
| Trình duyệt | Chrome bản mới, desktop. Ba phiên, mỗi phiên một tài khoản: cửa sổ thường cho khách, cửa sổ ẩn danh cho QTV, một trình duyệt thứ hai cho đơn vị tổ chức (UAT-17 dùng trình duyệt thứ hai cho KH-B). |
| Minh chứng | Thư mục `MinhChung_UAT_Sprint6/`, ảnh đặt tên `UAT-xx_mo-ta.png`. Che email, mã QR và số tài khoản (kể cả tài khoản nhận tiền của đơn vị tổ chức); không chụp trang “Chuyển khoản VietQR”. |

Tour dùng trong ca: tour 1 “Hà Nội qua những món ăn phố cổ” (không chia gói; giá vé theo lịch, phụ thu “Phụ thu đi riêng, không ghép khách” 500.000đ / nhóm, tùy chọn “Thêm phần chè cuối tour” 35.000đ / người); tour 3 “Phố cổ theo cách của bạn” (3 gói, tối đa 4 khách); 2 tour ở tab “Chờ duyệt” của trang quản trị; tour T do ĐV-A tạo ở UAT-40 (dùng ở UAT-41 → UAT-47, UAT-51 → UAT-54).

Quy ước khi đặt đơn:

- Nếu ca không ghi khác, chọn lịch còn ít nhất 2 ngày tới giờ khởi hành (chuyển khoản VietQR chỉ nhận khi còn từ 24 giờ).
- A1 đặt một lịch của tour 1; các đơn khác của tour 1 chọn lịch khác, để số chỗ của lịch A1 chỉ đổi theo A1 (UAT-10, UAT-25).
- Đơn chưa thanh toán tự hủy sau 30 phút. Các ca dùng chung một đơn “Chờ thanh toán” chạy liền nhau trong hạn: UAT-10 → UAT-14 (A1, A2), UAT-20 và UAT-22 (B3). Lỡ quá hạn thì đặt đơn mới và ghi ở Ghi chú.

Đơn tạo trong lúc chạy (ghi mã đơn thật vào cột Ghi chú):

| Đơn | Tài khoản | Tạo ở | Dùng tiếp ở |
| --- | --- | --- | --- |
| A1 | KH-A | UAT-10 (tour 1, 2 người lớn; không thanh toán) | UAT-12, 13, 14, 25 |
| A2 | KH-A | UAT-11 (tour 3, có gói; không thanh toán) | UAT-12, 25 |
| B1 | KH-B | UAT-15 | UAT-15 |
| B2 | KH-B | UAT-16 (thanh toán VietQR rồi bị hủy) | UAT-16, 53 |
| A3 | KH-A | UAT-17 (lịch sức chứa 2) | UAT-17 |
| A4 | KH-A | UAT-18 (tour 1, 2 người lớn, VietQR) | UAT-19, 24, 27, 29, 30, 37 |
| B3 | KH-B | UAT-20 | UAT-20, 22, 24 |
| A5 | KH-A | UAT-21 (tour 3, có gói, VNPay) | UAT-28, 37, 53 |
| B4 | KH-B | UAT-23 | UAT-23 |
| A6 | KH-A | UAT-26 (VietQR, không đối chiếu) | UAT-26, 37 |
| B5 | KH-B | UAT-34 (tour thêm ở UAT-32) | UAT-34 |
| B6 | KH-B | UAT-36 | UAT-36 |
| A7 | KH-A | UAT-46 (tour T, VietQR) | UAT-45, 46, 47 |
| B7 | KH-B | UAT-48 | UAT-48 |
| B8 | KH-B | UAT-50 | UAT-50 |
| A8, B9 | KH-A, KH-B | UAT-51 (lịch kết thúc sớm của tour T) | UAT-51, 53, 54 |

## 4. Tiêu chí vào / ra và quy tắc Go / No-go

| Tiêu chí vào (trước khi chạy 16/11) |
| --- |
| 1. Nhóm LocalTour đã cài bản demo 6.3 và dữ liệu mẫu mới lên trang demo; bước kiểm tra cài đặt không có lỗi. |
| 2. Máy UAT mở được trang demo; `/tours` hiện 9 tour; QTV đăng nhập được `/admin/login` bằng tài khoản trong file `GuiNhomPCG_DiaChi_TaiKhoan.txt`. |
| 3. Trang thanh toán có “Thanh toán qua VNPay” và “Lấy mã VietQR” (không ghi “đang tạm ngưng”); tác vụ tự động của trang demo đang chạy; trang “Thông số vận hành” ở giá trị mặc định (10 % / 30 phút / 60 phút / 24 giờ). |
| 4. Nhóm đã quyết định Go ở System Test Exit Sprint 5. |

| Tiêu chí ra (chốt 19/11) |
| --- |
| 1. Đã chạy hết 54 ca; ca chưa chạy có lý do ở cột Ghi chú. |
| 2. 50/50 ca Must Đạt. |
| 3. Không còn lỗi Critical / High mở. |
| 4. Lỗi Medium / Low còn mở có người phụ trách và hướng xử lý (sửa ở Sprint 7 hoặc chấp nhận). |
| 5. Biên bản mục 8 và bảng tổng hợp mục 9 có chữ ký. |

Quy tắc quyết định:

| Quyết định | Khi nào |
| --- | --- |
| Go | Đạt cả 5 tiêu chí ra. |
| Go có điều kiện | Đạt tiêu chí 2, 3, 5; còn ca Should / Could không đạt hoặc ca chưa chạy vì môi trường (mạng, cổng VNPay), có ngày chạy lại trong Sprint 7. |
| No-go | Còn ca Must không đạt hoặc lỗi Critical / High mở sau 6.6. Sửa, cập nhật trang demo, chạy lại ca liên quan; chốt lại trong Sprint 7. |

Mức độ lỗi (giữ như Sprint 5):

| Mức | Định nghĩa | Xử lý |
| --- | --- | --- |
| Critical | Sai / mất dữ liệu đơn, chỗ hoặc tiền; lộ đơn của khách khác; đơn vị tổ chức xem được tour, đơn hoặc khoản chi trả của đơn vị khác; khách hàng dùng được chức năng quản trị; lỗi PHP / trang trắng chặn cả một story. | Sửa 17/11 (6.6); còn mở → No-go |
| High | Chức năng chính của một story sai hoặc không làm được, không có cách khác. | Sửa 17/11 (6.6); còn mở → No-go |
| Medium | Chạy nhưng sai ở trường hợp phụ, thông báo sai / thiếu; có cách làm khác. | Sửa nếu kịp, không thì chuyển Sprint 7 |
| Low | Câu chữ, căn lề, giao diện nhỏ; không ảnh hưởng nghiệp vụ. | Ghi nhận, chuyển Sprint 7 nếu chưa sửa |

Defect log dùng cột như Sprint 5 (Mã lỗi, Ca UAT, Tiêu đề, Mức độ / Loại, Bước tái hiện, Kết quả mong đợi / thực tế, Minh chứng, Người xử lý / Commit sửa, Ngày phát hiện / Ngày chạy lại, Trạng thái); mã lỗi nối tiếp DEF-13: DEF-14, DEF-15…

## 5. Lịch UAT

| Ngày | Việc | Người |
| --- | --- | --- |
| Trước 16/11 | Cài mới dữ liệu mẫu trên trang demo, tạo tài khoản QTV, gửi nhóm PCG file 03, 04 và `GuiNhomPCG_DiaChi_TaiKhoan.txt`. | Nguyễn Tuấn Khôi |
| 16/11, sáng | Nhóm PCG mở trang demo theo file `GuiNhomPCG_DiaChi_TaiKhoan.txt`, kiểm tra tiêu chí vào. | Nhóm PCG |
| 16/11, sáng | Chạy UAT-01 → UAT-37 (UAT-25, UAT-26 chạy sau khi đơn hết thời gian giữ chỗ 30 phút, trong lúc đó chạy tiếp các ca khác); báo ngay lỗi chặn. | Nhóm PCG; Hải, Thành điều phối |
| 16/11, chiều | Chạy UAT-38 → UAT-54 (UAT-45 chạy cuối, sau UAT-54; UAT-52 chạy trong lúc chờ lịch của UAT-51 kết thúc). | Nhóm PCG; Hải, Thành điều phối |
| 16/11, cuối buổi | Điền kết quả vào biên bản UAT (mục 8); nhóm PCG ký phần người dùng. | Nhóm PCG; Hải, Thành |
| 17/11 | Sửa lỗi Critical / High (6.6), cập nhật trang demo. | Phong, Thức, Khôi (người làm chức năng có lỗi) |
| 18/11 | Chạy lại ca liên quan trên trang demo đã cập nhật (và ca chưa chạy ngày 16/11); ghi lỗi đã sửa vào biên bản; ký biên bản. | Hải, Thành chạy lại; cả nhóm ký |
| 19/11 | Tổng hợp nghiệm thu demo (mục 9), quyết định Go / No-go. | Hải, Thành lập; cả nhóm quyết định |

## 6. Checklist UAT

Cột Kết quả ghi **Đạt** hoặc **Không đạt**. Ca không chạy được vì môi trường: để trống Kết quả, ghi lý do ở Ghi chú. Không đạt: ghi mã lỗi DEF-xx ở Ghi chú.

### 6.1. Xem, tìm và so sánh tour (chưa đăng nhập)

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-01 | US-01 | Xem danh sách tour | 1. Mở `/tours`. 2. Xem từng thẻ tour. | Trang “Bảng tin du lịch” ghi “9 tour”. Mỗi thẻ có tên tour, điểm đến, “Nơi khởi hành”, giá. Trường thiếu ghi “Chưa cập nhật”, không lấy dữ liệu của tour khác. | | |
| UAT-02 | US-02 | Xem chi tiết tour | 1. Bấm “Xem chi tiết” ở tour 1. 2. Xem các mục. 3. Bấm “Quay lại danh sách”. | Có Thông tin tour, Lịch trình, Lịch khởi hành, Dịch vụ (tách đã bao gồm / không bao gồm), Chính sách của đúng tour 1; nội dung khớp trang quản trị của tour. Bước 3 về bảng tin. | | |
| UAT-03 | US-03 | Tìm kiếm và lọc | 1. Gõ tên một điểm đến vào ô tìm, bấm “Tìm”. 2. Xóa chữ ở ô tìm, bấm “Tìm”; rồi chọn một “Điểm đến:” và một “Loại hình:”. 3. Tìm một chuỗi không có tour. 4. Bấm “Xóa bộ lọc”. | Bước 1–2 chỉ hiện tour đúng điều kiện, số tour ở đầu danh sách khớp số thẻ (từ khóa và hai bộ lọc áp dụng cùng lúc). Bước 3: “Không có tour phù hợp”. Bước 4: trở lại 9 tour. | | |
| UAT-04 | US-03 | Sắp xếp theo giá | 1. Ô “Giá” chọn “Thấp đến cao”. 2. Chọn “Cao đến thấp”. | Giá tăng dần / giảm dần đúng; mọi giá cùng đơn vị VND. | | |
| UAT-05 | US-04 | So sánh 2–3 tour | 1. Bấm “Thêm vào so sánh” ở 1 tour, mở “So sánh tour” ở menu trái. 2. Thêm 2 tour nữa. 3. Thêm tour thứ 4. 4. Bấm “So sánh tour”. 5. Bấm “Bỏ” ở một tour, tải lại trang. | Bước 1: “Cần ít nhất 2 tour để so sánh”. Bước 2: khung ghi “3/3 tour”. Bước 3 bị chặn: “Chỉ so sánh tối đa 3 tour. Bỏ bớt một tour trước khi thêm tour khác.” Bước 4: các tour đặt cạnh nhau theo 4 nhóm (Giá và lịch, Thông tin tour, Lịch trình và dịch vụ, Chính sách), ô thiếu ghi “Chưa cập nhật”. Bước 5: còn 2 tour, vẫn giữ sau khi tải lại. | | |
| UAT-06 | US-15 | Xem đánh giá | 1. Mở mục “Đánh giá” của một tour có đánh giá. 2. Mở mục này ở một tour chưa có đánh giá (nếu có). | Bước 1: dưới tên tour ghi “x/5 (N đánh giá)”; mục “Đánh giá” ghi điểm trung bình “x”, “N đánh giá · Sắp xếp: Mới nhất” và các nhận xét đã duyệt (mỗi nhận xét ghi “n/5 · Tham gia ngày …”). Bước 2: “Chưa có đánh giá”. | | Could |

### 6.2. Tài khoản và đặt tour

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-07 | US-16 | Đăng ký tài khoản | 1. “Đăng ký”, tạo KH-A. 2. Đăng xuất, đăng ký lại cùng email. 3. Đăng ký với mật khẩu 7 ký tự hoặc hai ô mật khẩu khác nhau. 4. Tạo KH-B. | Bước 1, 4: tạo được tài khoản, đầu trang có tên và “Đơn của tôi”. Bước 2: “Email này đã được dùng.” Bước 3: báo lỗi ở ô mật khẩu, không tạo tài khoản. | | |
| UAT-08 | US-16 | Đăng nhập, quay lại tour đang chọn, đăng xuất | 1. Đăng nhập KH-A sai mật khẩu. 2. Đăng nhập email chưa đăng ký. 3. Chưa đăng nhập, ở tour 1 chọn một ngày và 2 người lớn, bấm “Đăng nhập để đặt tour”, đăng nhập KH-A. 4. Đăng xuất. | Bước 1, 2 cùng báo “Email hoặc mật khẩu không đúng.” Bước 3 vào thẳng “Hoàn tất thông tin đặt tour” của tour 1 với đúng ngày và số khách đã chọn. Bước 4: đầu trang lại có “Đăng nhập”, “Đăng ký”. | | |
| UAT-09 | US-05 | Giá minh bạch, tách phụ thu | 1. KH-A mở tour 1, chọn một lịch, 2 người lớn + 1 trẻ em. 2. “Đặt tour”, tích “Thêm phần chè cuối tour”. 3. “Xem lại & xác nhận”, không bấm “Đặt tour và thanh toán”. | Bước 1: giá theo loại vé, ghi VND; “Tạm tính tiền vé” = tổng tiền vé, ghi chưa gồm phụ thu. Bước 2–3: dòng vé và dòng tùy chọn tách riêng; chè tính 35.000đ × 3 khách; “Tổng tiền” = vé + tùy chọn (lịch giá 650.000đ / 460.000đ: 1.760.000đ + 105.000đ = 1.865.000đ). | | |
| UAT-10 | US-06 | Đặt tour, giữ chỗ ngay (tour không chia gói) | 1. KH-A mở tour 1, ghi số chỗ còn của lịch định đặt; đặt 2 người lớn; bỏ trống họ tên khách 2, không tích điều kiện; bấm “Xem lại & xác nhận”. 2. Nhập đủ, tích điều kiện, “Xem lại & xác nhận”, “Đặt tour và thanh toán”. 3. Không thanh toán; mở “Đơn của tôi”, mở đơn. 4. Mở lại trang tour 1. | Bước 1 bị chặn: “Vui lòng nhập họ tên khách 2.”, “Vui lòng đồng ý điều kiện đặt tour và chính sách hủy.” Bước 2: không chờ quản trị viên xác nhận; mở trang “Thanh toán đơn LTxxxxxx” (đơn A1) với “Đã giữ chỗ cho đơn LTxxxxxx”, hạn giữ chỗ = lúc đặt + 30 phút. Bước 3: A1 có trong danh sách, trạng thái “Chờ thanh toán”, có “Số tiền cần thanh toán” và “Thanh toán ngay”. Bước 4: số chỗ còn của lịch giảm 2. | | Ghi mã A1 và giờ đặt |
| UAT-11 | US-06 | Đặt tour có gói | 1. KH-A mở tour 3, chọn gói “Đền chùa và tín ngưỡng”, 2 người lớn. 2. “Đặt tour”, nhập thông tin, “Đặt tour và thanh toán” (đơn A2); không thanh toán. 3. QTV mở A2 ở “Đơn đặt tour”. | Bước 1: “Tạm tính tiền vé” 1.900.000đ. Bước 2: trang thanh toán ghi “Cần thanh toán” 1.900.000đ; trang đơn ghi đúng tên gói, trạng thái “Chờ thanh toán”. Bước 3: QTV thấy cùng gói và giá. | | Ghi mã A2 |

### 6.3. Đơn đặt tour (quản trị viên)

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-12 | US-22 | Xem danh sách và chi tiết đơn | 1. QTV đăng nhập, “Đơn đặt tour”, tab “Chờ thanh toán”. 2. Tìm theo mã A1. 3. Bấm “Xem”. | A1, A2 có trong tab. Chi tiết A1 khớp dữ liệu khách nhập (tour, lịch, vé, danh sách khách, tổng tiền); đầu trang ghi “Hạn thanh toán”; “Chỗ của lịch” ghi đơn này đang giữ 2 chỗ; có “Lịch sử xử lý”. | | |
| UAT-13 | US-23, US-09 | Không còn bước xác nhận chỗ; chưa thanh toán thì chưa xác nhận được | 1. QTV mở A1, xem “Trạng thái mới” ở “Cập nhật trạng thái”. 2. Chọn “Xác nhận đã thanh toán (chuyển “Đã xác nhận”)”, bấm “Cập nhật trạng thái”. 3. KH-A mở A1. | Bước 1: chỉ có “Xác nhận đã thanh toán (chuyển “Đã xác nhận”)” và “Hủy đơn”; không có lựa chọn xác nhận chỗ, không có ô “Tổng giá chốt (VND)”. Bước 2 bị chặn: “Đơn chưa có thanh toán thành công hoặc khoản chuyển khoản VietQR chờ đối chiếu, chưa xác nhận được.” Bước 3: A1 vẫn “Chờ thanh toán”, hạn không đổi, có “Thanh toán ngay”. | | |
| UAT-14 | US-09 | Đơn giữ giá lúc đặt | 1. QTV mở tour 1, “Lịch khởi hành và giá vé”, “Sửa” lịch của A1, tăng “Giá vé người lớn (đ)” thêm 50.000đ, “Lưu thay đổi”. 2. QTV và KH-A mở A1. 3. Khách mở tour 1, chọn lịch đó, 1 người lớn. 4. QTV đổi lại giá cũ. | Bước 1: “Đã lưu lịch khởi hành.” Bước 2: đơn giá vé, “Tổng tiền” và “Số tiền cần thanh toán” của A1 không đổi. Bước 3: “Tạm tính tiền vé” theo giá mới. Bước 4: lưu được, trang tour trở lại giá cũ. | | |
| UAT-15 | US-24, US-09 | Hủy đơn chờ thanh toán | 1. KH-B đặt một tour (đơn B1), không thanh toán. 2. QTV mở B1, ghi “Chỗ của lịch”; chọn “Hủy đơn”, để trống “Lý do / ghi chú”, “Cập nhật trạng thái”. 3. Nhập lý do, cập nhật. 4. KH-B mở B1. | Bước 2: “Từ chối hoặc hủy đơn cần nhập lý do.”, đơn không đổi. Bước 3: “Đã cập nhật trạng thái đơn.”; B1 “Đã hủy”; số chỗ còn của lịch cộng lại đúng số khách; lịch sử ghi lý do, người làm, thời điểm. Bước 4: khách thấy “Đã hủy” và “Lý do: …”, không còn “Thanh toán ngay”. | | |
| UAT-16 | US-24 | Hủy đơn đã thanh toán | 1. KH-B đặt một tour (đơn B2), “Lấy mã VietQR”, “Tôi đã chuyển khoản”; QTV bấm “Đã nhận tiền”. 2. QTV mở B2, ghi “Chỗ của lịch”; chọn “Hủy đơn”, nhập lý do, cập nhật. 3. QTV mở “Chi trả đơn vị tổ chức”, mục “Hoàn tiền cho khách”. 4. KH-B mở B2. | Bước 1: B2 “Đã xác nhận”. Bước 2: B2 “Đã hủy”, số chỗ còn của lịch cộng lại đúng số khách; trang đơn báo có khoản cần hoàn tiền cho khách; mục “Cập nhật trạng thái” ghi đơn đã ở trạng thái cuối, không cập nhật được nữa. Bước 3: có dòng của B2, số tiền hoàn = số tiền khách đã trả (để lại, ghi “Đã hoàn tiền” ở UAT-53). Bước 4: khách thấy “Đã hủy” và lý do. | | Ghi mã B2 |
| UAT-17 | US-08 | Không đặt vượt sức chứa | 1. QTV thêm cho tour 1 một lịch mới, “Sức chứa (chỗ)” = 2. 2. KH-B (trình duyệt thứ hai) chọn lịch này, 2 người lớn, nhập thông tin tới “Xem lại đơn đặt tour”, chưa bấm đặt. 3. KH-A đặt lịch này 2 người lớn, “Đặt tour và thanh toán” (đơn A3). 4. KH-B bấm “Đặt tour và thanh toán”. 5. QTV mở “Lịch khởi hành và giá vé” của tour 1; khách mở trang tour 1. | Bước 2: không chọn được quá 2 khách cho lịch này. Bước 3: A3 “Chờ thanh toán”. Bước 4 bị chặn: “Lịch này vừa hết chỗ. Vui lòng chọn ngày khác.”, KH-B không có đơn mới. Bước 5: lịch “Còn nhận” 0, trạng thái “Hết chỗ”; lịch không còn trong ô “Ngày tham gia”. | | |

### 6.4. Thanh toán và voucher

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-18 | US-11 | Chuyển khoản VietQR | 1. KH-A đặt tour 1, 2 người lớn (đơn A4); ở trang thanh toán bấm “Lấy mã VietQR”. 2. Không chuyển tiền thật; bấm “Tôi đã chuyển khoản”. | Bước 1: có mã QR, số tiền = tổng tiền của đơn, nội dung là mã thanh toán của A4 (`LTxxxxxxP1`). Bước 2: “Đã ghi nhận bạn báo chuyển khoản…”; khoản “Chờ đối chiếu”; A4 có trong “Đối chiếu thanh toán” của QTV. | | Ghi mã A4. Không chụp trang chuyển khoản |
| UAT-19 | US-12, US-23 | Đối chiếu VietQR: đã nhận tiền | 1. QTV “Đối chiếu thanh toán”, bấm “Đối chiếu” ở A4. 2. Bấm “Đã nhận tiền”. 3. KH-A mở A4. | Bước 2: “Đã xác nhận nhận tiền. Đơn còn chờ thanh toán thì chuyển “Đã xác nhận” và khách nhận được voucher; …”; lịch sử ghi người làm và thời điểm. Bước 3: A4 “Đã xác nhận”, khoản “Thành công”, có “Mã voucher”. | | |
| UAT-20 | US-12 | Đối chiếu VietQR: không khớp | 1. KH-B đặt một tour (đơn B3); ghi hạn thanh toán. 2. KH-B “Lấy mã VietQR”, “Tôi đã chuyển khoản”. 3. QTV bấm “Không khớp” không nhập lý do, rồi nhập lý do và bấm lại. 4. KH-B mở B3. | Bước 3: thiếu lý do báo “Không khớp” / “Không có giao dịch” cần nhập lý do; có lý do: “Đã báo chuyển khoản không khớp. Đơn còn hạn giữ chỗ thì khách thanh toán lại được; đã quá hạn thì đơn tự hủy và trả lại chỗ.” Bước 4: B3 “Chờ thanh toán”, hạn không đổi, chưa có voucher, thanh toán lại được. | | Ghi mã B3 |
| UAT-21 | US-10 | Thanh toán VNPay sandbox | 1. KH-A đặt tour 3 có gói (đơn A5); ở trang thanh toán bấm “Thanh toán qua VNPay”. 2. Thanh toán bằng thẻ thử ở cổng VNPay sandbox. | Số thẻ chỉ nhập ở cổng VNPay, không nhập ở LocalTour. Về trang A5 với “Thanh toán VNPay thành công. Đơn đã được xác nhận và voucher đã sẵn sàng.”; A5 “Đã xác nhận” ngay, không cần QTV; khoản “Thành công” đúng tổng tiền của đơn; có mã voucher. | | Ghi mã A5. Cần Internet |
| UAT-22 | US-10 | Hủy giao dịch ở cổng VNPay | 1. KH-B mở B3 (còn hạn giữ chỗ), “Thanh toán ngay”, “Thanh toán qua VNPay”. 2. Bấm hủy giao dịch ở cổng VNPay. | Về trang B3 với thông báo đã hủy giao dịch ở VNPay; B3 vẫn “Chờ thanh toán”, hạn không đổi; thanh toán lại được. | | Cần Internet. Chạy trong hạn của B3 |
| UAT-23 | US-12 | Giao dịch VNPay chưa rõ kết quả | 1. KH-B đặt một tour (đơn B4), “Thanh toán qua VNPay”, đóng tab cổng VNPay (không thanh toán, không hủy). 2. Sau 15 phút (chạy UAT-24 trong lúc chờ), QTV mở “Đối chiếu thanh toán”. 3. “Đối chiếu”, nhập ghi chú, bấm “Không có giao dịch”. | Bước 2: khoản của B4 ở “Giao dịch VNPay chưa rõ kết quả”. Bước 3: “Đã ghi “Không có giao dịch VNPay”. Đơn còn hạn giữ chỗ thì khách thanh toán lại được.”; B4 vẫn “Chờ thanh toán” tới hết hạn giữ chỗ. | | Ghi mã B4. Cần Internet |
| UAT-24 | US-10, US-12 | Voucher | 1. KH-A mở A4, “Xem và in voucher”, “In voucher”. 2. KH-B mở `/bookings/<mã B3>/voucher`. | Bước 1: voucher có mã voucher, mã đơn, tour, ngày, giờ, điểm gặp, đơn vị tổ chức, danh sách khách, số tiền đã thanh toán; in được. Bước 2: không có voucher, quay về trang đơn B3. | | |
| UAT-25 | US-13 | Tự hủy đơn quá hạn giữ chỗ | 1. Khi A1, A2 (đặt ở UAT-10, UAT-11, chưa thanh toán) đã quá hạn 30 phút, KH-A mở “Đơn của tôi”, mở A1 và A2. 2. QTV mở A1. 3. Khách mở trang tour 1, xem số chỗ còn của lịch của A1. | Bước 1: A1, A2 “Đã hủy” mà không ai bấm hủy; “Lịch sử đơn” ghi “Quá hạn thanh toán, đơn tự hủy” – “Hệ thống”; không còn “Thanh toán ngay”. Bước 2: “Chỗ của lịch” không còn ghi đơn này đang giữ chỗ; đơn ở trạng thái cuối. Bước 3: số chỗ còn trở lại bằng số đã ghi ở bước 1 của UAT-10. | | |
| UAT-26 | US-13 | Đơn chờ đối chiếu không bị tự hủy | 1. KH-A đặt một tour (đơn A6), “Lấy mã VietQR”, “Tôi đã chuyển khoản”; ghi hạn giữ chỗ; QTV chưa đối chiếu. 2. Sau hạn giữ chỗ của A6 (chạy UAT-27 → UAT-29 trong lúc chờ), KH-A mở A6; QTV mở “Đối chiếu thanh toán”. | A6 vẫn “Chờ thanh toán”, khoản “Chờ đối chiếu”, chỗ vẫn được giữ; A6 vẫn có trong “Chuyển khoản VietQR chờ đối chiếu”. | | Ghi mã A6 |

### 6.5. Đổi ngày / hủy tour

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-27 | US-14 | Đổi ngày, được đồng ý | 1. KH-A mở A4, “Đổi ngày / hủy tour”, chọn “Đổi sang ngày khác”, chọn ngày, nhập lý do, “Gửi yêu cầu”. 2. Mở lại trang và thử gửi thêm một yêu cầu. 3. QTV “Đổi ngày / hủy tour”, “Xử lý”, chọn “Đồng ý đổi ngày”, nhập ghi chú, “Lưu kết quả”. 4. KH-A mở A4. | Bước 1: chỉ liệt kê lịch còn đủ chỗ cho 2 khách; yêu cầu “Chờ xử lý”, đơn chưa đổi. Bước 2: không gửi được (đơn đang có yêu cầu chờ xử lý). Bước 3: “Đã đồng ý yêu cầu và cập nhật đơn.” Bước 4: A4 ở lịch mới, giữ số khách và tổng tiền; yêu cầu “Đã đồng ý” kèm “Phản hồi của LocalTour”; lịch sử đơn ghi lại. | | Should |
| UAT-28 | US-14 | Hủy tour, được đồng ý | 1. KH-A mở A5, “Đổi ngày / hủy tour”, chọn “Hủy tour”, xem số tiền dự kiến hoàn, nhập lý do, gửi. 2. QTV “Xử lý”, chọn “Đồng ý hủy tour”, nhập “Số tiền hoàn (đ)” và ghi chú, “Lưu kết quả”. 3. KH-A mở A5. | Bước 1: số tiền dự kiến hoàn đúng chính sách hủy lưu cùng đơn. Bước 2: A5 “Đã hủy”, chỗ được trả lại lịch, ghi khoản hoàn; khoản hoàn có ở mục “Hoàn tiền cho khách” của “Chi trả đơn vị tổ chức” (chuyển khoản lại thủ công, không hoàn qua VNPay; ghi “Đã hoàn tiền” ở UAT-53). Bước 3: trang đơn A5 ghi “Trạng thái: Đã hủy” và “Đơn đã bị hủy. Lý do: …” (ghi chú của QTV); “Lịch sử đơn” có dòng “Đồng ý hủy tour” – “LocalTour” kèm ghi chú và dòng “Tạo yêu cầu hoàn tiền” ghi số tiền hoàn. | | Should |
| UAT-29 | US-14 | Từ chối yêu cầu | 1. KH-A mở A4, gửi yêu cầu “Hủy tour” kèm lý do. 2. QTV chọn “Từ chối, giữ nguyên đơn”, để trống ghi chú, lưu. 3. Nhập ghi chú, lưu. 4. KH-A mở A4. | Bước 2: không lưu được (ghi chú bắt buộc). Bước 3: “Đã từ chối yêu cầu. Đơn giữ nguyên.” Bước 4: yêu cầu “Đã từ chối” kèm phản hồi; A4 vẫn “Đã xác nhận”; gửi được yêu cầu mới. | | Should |

### 6.6. Phân quyền, quản trị tour và thống kê

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-30 | US-16, US-22 | Phân quyền | 1. KH-B mở `/bookings/<mã A4>`. 2. KH-A mở `/admin`. 3. Chưa đăng nhập, mở `/admin`. 4. QTV mở trang chi tiết tour 1. | Bước 1: “Không tìm thấy đơn” (không lộ đơn của KH-A). Bước 2: “Bạn không có quyền truy cập trang này.” Bước 3: chuyển tới “Đăng nhập quản trị”. Bước 4: “Tài khoản quản trị không đặt tour được. Đăng nhập bằng tài khoản khách hàng để đặt tour.”, không có nút “Đặt tour”. | | |
| UAT-31 | US-07 | Quản lý đơn vị tổ chức | 1. QTV “Đơn vị tổ chức”, “Thêm đơn vị” (Đang hợp tác). 2. “Sửa” số điện thoại, “Lưu thay đổi”. 3. Ở trang “Sửa” của đơn vị vừa thêm, tích “Tôi hiểu đơn vị sẽ bị xóa hẳn.”, “Xóa đơn vị”. 4. Mở trang “Sửa” của một đơn vị đang có tour, xem mục “Xóa đơn vị”. | Bước 1–3: “Đã thêm đơn vị tổ chức.”, “Đã lưu thông tin đơn vị tổ chức.”, “Đã xóa đơn vị tổ chức.”; đơn vị khác không đổi. Bước 4: mục “Xóa đơn vị” không có ô tích và nút xóa, chỉ ghi “Đơn vị còn N tour nên không xóa được (đơn cũ cần giữ thông tin đơn vị). Muốn ẩn mọi tour của đơn vị khỏi trang khách, chọn “Ngừng hợp tác” rồi lưu.” | | |
| UAT-32 | US-07, US-21 | Thêm tour tới khi khách thấy | 1. “Duyệt tour”, “Thêm tour” với một đơn vị đang hợp tác. 2. Thêm 1 lịch khởi hành và giá vé, 1 ảnh, 2 mục lịch trình, 2 dịch vụ (1 đã bao gồm, 1 không bao gồm), 1 phiên bản chính sách hủy. 3. Mở `/tours`. 4. “Phê duyệt tour”, mở lại `/tours` và trang tour. | Bước 1: “Đã thêm tour. Tour đang ở trạng thái Chờ duyệt…”. Bước 3: tour mới chưa có trên bảng tin. Bước 4: “Đã phê duyệt tour.”; tour hiện trên bảng tin, trang chi tiết đúng nội dung đã nhập; tour khác không đổi. | | |
| UAT-33 | US-21 | Từ chối tour chờ duyệt | 1. Tab “Chờ duyệt”, mở một tour, bấm “Từ chối tour” khi để trống lý do. 2. Nhập “Lý do từ chối (bắt buộc)”, “Từ chối tour”. 3. Mở đường dẫn tour đó ở trang khách. | Bước 1: không lưu được. Bước 2: “Đã từ chối tour và lưu lý do.”; tour ở tab “Bị từ chối”, “Lịch sử xử lý” ghi người làm, thời điểm, lý do. Bước 3: “Không tìm thấy tour”. | | |
| UAT-34 | US-07 | Xóa tour, ngừng hiển thị, hiển thị lại | 1. Ở trang “Ảnh, lịch trình, dịch vụ, chính sách” của tour 1, tab “Xóa tour”, tích xác nhận, bấm “Xóa tour”. 2. KH-B đặt tour mới ở UAT-32 (đơn B5), QTV hủy đơn kèm lý do; QTV xóa tour đó. 3. Ở tab “Hiển thị lại”, bấm “Chuyển về Chờ duyệt”, rồi “Phê duyệt tour”. 4. Thêm một tour khác (chưa có đơn) rồi xóa. | Bước 1 bị chặn: tour còn đơn đang xử lý. Bước 2: tour chuyển “Ngừng hiển thị”, không còn trên bảng tin, đơn cũ vẫn xem được. Bước 3: tour về “Chờ duyệt”, duyệt xong hiện lại. Bước 4: “Đã xóa tour.”, tour không còn ở tab “Tất cả”. | | |
| UAT-35 | US-17, US-18 | Thống kê tài khoản và tour | 1. QTV “Tổng quan”, ghi ô “Tài khoản khách hàng” và “Tour”. 2. Đăng ký thêm một khách hàng, tải lại. 3. So ô “Tour” với số tour ở các tab của “Duyệt tour”. | Bước 2: “Tài khoản khách hàng” tăng 1. Bước 3: số chờ duyệt / đã duyệt / bị từ chối khớp các tab; tour chưa duyệt không có trên bảng tin. Khách hàng không xem được trang này (UAT-30). | | |
| UAT-36 | US-19 | Thống kê đơn theo trạng thái và thời gian | 1. Ghi bảng “Đơn đặt tour theo trạng thái”. 2. So với số đơn ở từng tab của “Đơn đặt tour”. 3. “Thống kê”: Theo ngày, “Từ ngày” = “Đến ngày” = hôm nay, “Xem thống kê”; ghi số đơn. 4. KH-B đặt thêm một đơn (B6); QTV xem lại bước 1 và 3. 5. Chọn khoảng ngày đã qua, không gồm hôm nay. | Bước 2: số theo trạng thái khớp từng tab. Bước 4: “Chờ thanh toán” và “Số đơn đặt tour theo ngày tạo” của hôm nay cùng tăng 1. Bước 5: không tính các đơn tạo hôm nay. | | |
| UAT-37 | US-20 | Doanh thu theo ngày / tháng / năm | 1. “Thống kê”: Theo tháng, “Xem thống kê”. 2. Bấm kỳ “Tháng 11/2026”. 3. Nhập cùng “Từ ngày” và “Đến ngày” (ví dụ từ ngày 1 của tháng đến hôm nay), bấm “Xem thống kê” lần lượt với Theo ngày, Theo tháng, Theo năm. | Bước 1: “Doanh thu theo ngày thanh toán” có Lượt thanh toán, Doanh thu gộp, Hoàn tiền, Doanh thu thuần = gộp − hoàn. Bước 2: “Khoản thanh toán theo kỳ” liệt kê từng khoản, tổng khớp số của kỳ; có khoản của A4, A5; không có khoản chưa đối chiếu (A6). Bước 3: với cùng khoảng ngày, dòng “Tổng” của ba cách xem khớp nhau. (Để trống ngày thì mỗi cách xem lấy một khoảng khác nhau: 30 ngày / 12 tháng / toàn bộ, nên tổng có thể khác nhau.) | | |

### 6.7. Tài khoản và tour của đơn vị tổ chức

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-38 | US-25 | Cấp tài khoản cho đơn vị tổ chức | 1. QTV “Đơn vị tổ chức”, “Thêm đơn vị” (ĐV-A, giữ “Chờ duyệt”). 2. “Sửa” ĐV-A; ở “Tài khoản đăng nhập” nhập mật khẩu 7 ký tự, “Cấp mật khẩu”; rồi nhập mật khẩu hợp lệ, bấm lại. 3. ĐV-A đăng nhập ở `/host/login`. 4. QTV chuyển ĐV-A sang “Đang hợp tác”, “Lưu thay đổi”. 5. ĐV-A đăng nhập lại. 6. QTV thêm ĐV-B (Đang hợp tác) và cấp mật khẩu. | Bước 1: “Đã thêm đơn vị tổ chức.” Bước 2: 7 ký tự báo “Mật khẩu tối thiểu 8 ký tự.”; hợp lệ: “Đã lưu mật khẩu đăng nhập của đơn vị.”, trang không hiện lại mật khẩu. Bước 3: không vào được: “Đơn vị đang chờ quản trị viên LocalTour duyệt. …”. Bước 5: vào trang “Tour của tôi”; menu có Tour của tôi, Thêm tour, Đơn đặt tour, Doanh thu & chi trả, Tài khoản nhận tiền. Bước 6: ĐV-B đăng nhập được. | | |
| UAT-39 | US-25 | Đơn vị không tự đăng ký; tách với tài khoản khác | 1. Mở `/host/login`, xem trang. 2. Đăng nhập ĐV-A sai mật khẩu; đăng nhập bằng email và mật khẩu của KH-A. 3. ĐV-A (đã đăng nhập) mở `/admin`. 4. ĐV-A mở địa chỉ trang tour 1 thêm `/book` ở cuối. 5. Đăng xuất, mở `/host`. 6. QTV “Thêm đơn vị” với email của KH-A. | Bước 1: không có nút đăng ký; trang ghi “Chưa có tài khoản đơn vị? Liên hệ quản trị viên LocalTour để được cấp tài khoản.” Bước 2: cả hai báo “Email hoặc mật khẩu không đúng.” Bước 3: “Bạn không có quyền truy cập trang này.” Bước 4: “Tài khoản này không đặt tour được”. Bước 5: chuyển tới “Đăng nhập đơn vị tổ chức”. Bước 6: “Email này đã được dùng cho một tài khoản khác.” | | |
| UAT-40 | US-26 | Tạo tour “Nháp” và gửi duyệt | 1. ĐV-A “Thêm tour”, nhập thông tin, “Thêm tour” (tour T). 2. Thêm 1 lịch khởi hành cách ít nhất 3 ngày (sức chứa 10, giá vé người lớn 300.000đ), 1 ảnh, 2 mục lịch trình, 2 dịch vụ, 1 phiên bản chính sách hủy. 3. Khách mở `/tours`. 4. ĐV-A bấm “Gửi duyệt”. 5. QTV “Duyệt tour”, tab “Chờ duyệt”. | Bước 1: “Đã thêm tour ở trạng thái "Nháp". …”; trang tour ghi còn thiếu lịch khởi hành, giá vé, chính sách hủy, ảnh. Bước 2: “Nội dung đã nhập” đếm đúng. Bước 3: tour T chưa có trên bảng tin. Bước 4: “Đã gửi duyệt. Tour bị khóa cho tới khi quản trị viên LocalTour xử lý.”; tour “Chờ duyệt”, không còn nút “Sửa thông tin” và “Ảnh, lịch trình, dịch vụ, chính sách”. Bước 5: tour T có trong tab. | | |
| UAT-41 | US-26, US-21 | Từ chối, sửa, gửi lại, phê duyệt | 1. QTV mở tour T, nhập “Lý do từ chối (bắt buộc)”, “Từ chối tour”. 2. ĐV-A mở tour T. 3. ĐV-A “Sửa thông tin”, sửa “Mô tả”, “Lưu thay đổi”; bấm “Gửi duyệt”. 4. QTV “Phê duyệt tour”. 5. Khách mở `/tours`; ĐV-A mở tour T. | Bước 1: “Đã từ chối tour và lưu lý do.” Bước 2: tour “Bị từ chối”, đầu trang ghi “Tour bị từ chối: <lý do>”; “Lịch sử duyệt” có “Quản trị viên từ chối” kèm “Lý do: …”. Bước 3: “Đã lưu thông tin tour.”, tour về “Nháp”; gửi duyệt được, tour “Chờ duyệt”. Bước 4: “Đã phê duyệt tour.” Bước 5: tour T có trên bảng tin với nội dung đã sửa; ĐV-A thấy “Đã duyệt”, “Đang hiển thị cho khách”. | | |
| UAT-42 | US-26, US-21 | Bản sửa của tour đã duyệt | 1. ĐV-A mở tour T, “Tạo bản sửa”. 2. Ở bản sửa: sửa “Mô tả”, thêm 1 mục lịch trình; “Gửi duyệt bản sửa”. 3. Khách mở trang tour T. 4. QTV “Duyệt tour”, tab “Chờ duyệt”, “Xem và duyệt” ở dòng bản sửa. 5. QTV “Phê duyệt bản sửa”. 6. Khách mở lại trang tour T. | Bước 1: “Đã tạo bản sửa. …”. Bước 2: bản sửa “Chờ duyệt”, bị khóa. Bước 3: khách vẫn thấy nội dung cũ. Bước 4: dòng ghi “Bản sửa của tour đã duyệt: <tên tour T>”; mục “So sánh với tour đang hiển thị” chỉ có các phần đã đổi: nhóm “Thông tin tour” (bảng ba cột “Mục”, “Đang hiển thị”, “Bản sửa”, có một dòng “Mô tả”) và nhóm “Lịch trình” (hai bên “Đang hiển thị” và “Bản sửa” đều ghi cả lịch trình; bên “Bản sửa” có thêm mục vừa thêm). Bước 5: “Đã duyệt bản sửa: nội dung mới đã được áp dụng cho tour.” Bước 6: khách thấy nội dung mới; lịch khởi hành, giá vé không đổi; bảng tin vẫn chỉ có một tour T. | | |
| UAT-43 | US-26 | Từ chối bản sửa, hủy bản sửa | 1. ĐV-A mở tour T (đã duyệt), xem các nút. 2. “Tạo bản sửa”, sửa “Mô tả”, “Gửi duyệt bản sửa”. 3. QTV nhập lý do, “Từ chối bản sửa”. 4. ĐV-A mở bản sửa. 5. ĐV-A “Hủy bản sửa”. 6. Khách mở trang tour T. | Bước 1: không có nút “Sửa thông tin”; chỉ sửa nội dung qua “Tạo bản sửa”. Bước 3: “Đã từ chối tour và lưu lý do.” Bước 4: “Bản sửa bị từ chối: <lý do>”. Bước 5: “Đã hủy bản sửa. Tour đang hiển thị giữ nguyên.”; tour T lại có nút “Tạo bản sửa”. Bước 6: nội dung tour T không đổi qua cả ca. | | |
| UAT-44 | US-26 | Lịch khởi hành và giá vé không cần duyệt | 1. ĐV-A mở tour T, “Lịch khởi hành và giá vé”, thêm 1 lịch, “Thêm lịch”. 2. Khách mở trang tour T. 3. ĐV-A “Sửa” lịch vừa thêm, đổi “Giá vé người lớn (đ)”, “Lưu thay đổi”. 4. Khách chọn lịch đó, 1 người lớn. 5. QTV “Duyệt tour”, tab “Chờ duyệt”. | Bước 1: “Đã thêm lịch khởi hành.” Bước 2: lịch mới có ngay trong ô “Ngày tham gia”. Bước 3: “Đã lưu lịch khởi hành.” Bước 4: “Tạm tính tiền vé” theo giá mới. Bước 5: không có dòng nào của tour T chờ duyệt. | | |
| UAT-45 | US-26 | Ngừng hiển thị tour | 1. ĐV-A mở tour T (A7 đang “Đã xác nhận”), bấm “Ngừng hiển thị tour”. 2. QTV hủy A7 kèm lý do (khoản hoàn của A7 ghi “Đã hoàn tiền” như UAT-53). 3. ĐV-A bấm lại “Ngừng hiển thị tour”. 4. Khách mở `/tours` và địa chỉ trang tour T. 5. QTV “Duyệt tour”, tab “Ngừng hiển thị”. | Bước 1 bị chặn: “Tour còn đơn đang chờ xác nhận, chờ thanh toán hoặc đã xác nhận nên chưa ngừng hiển thị được.” Bước 3: “Đã ngừng hiển thị tour. Khách không còn tìm thấy và không đặt được tour.” Bước 4: tour T không còn trên bảng tin; trang tour ghi “Không tìm thấy tour”. Bước 5: tour T ở tab “Ngừng hiển thị”; ĐV-A vẫn xem được đơn cũ của tour. | | Chạy sau UAT-54 |

### 6.8. Đơn đặt tour của đơn vị tổ chức

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-46 | US-27 | Xem đơn đặt tour, chỉ xem | 1. KH-A đặt tour T, 2 người lớn (đơn A7), “Lấy mã VietQR”, “Tôi đã chuyển khoản”; QTV bấm “Đã nhận tiền”. 2. ĐV-A “Đơn đặt tour”; chọn tour T ở ô lọc, “Lọc”. 3. Bấm “Xem” ở A7. | Bước 2: A7 có trong danh sách, “Đã xác nhận”; danh sách chỉ có đơn của tour thuộc ĐV-A. Bước 3: trang “Đơn LTxxxxxx” có “Tour và lịch khởi hành”, vé và phụ thu, “Danh sách khách”, “Khách liên hệ và thanh toán” (Người liên hệ, Số điện thoại, Email, Thanh toán, Mã voucher) khớp đơn của KH-A; trang ghi “Trang này chỉ để xem: cần đổi gì ở đơn, liên hệ quản trị viên LocalTour.”; không có nút đổi trạng thái, hủy đơn hay đối chiếu. | | Ghi mã A7. Che email, số điện thoại trong ảnh |
| UAT-47 | US-27, US-26 | Chỉ thấy tour và đơn của đơn vị mình | 1. ĐV-B đăng nhập, mở “Tour của tôi” và “Đơn đặt tour”. 2. ĐV-B dán địa chỉ trang tour T và trang đơn A7 (chép từ trình duyệt của ĐV-A). 3. KH-A mở `/host`. | Bước 1: “Đơn vị chưa có tour nào. …” và “Chưa có khách nào đặt tour của đơn vị.” Bước 2: cả hai địa chỉ ra trang “Không tìm thấy trang”, không lộ nội dung của ĐV-A. Bước 3: “Bạn không có quyền truy cập trang này.” | | |

### 6.9. Giới hạn khi đặt tour giữ chỗ ngay

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-48 | US-13, US-29 | Hết hạn giữ chỗ theo thông số | 1. QTV “Thông số vận hành”: “Thời gian giữ chỗ (phút)” = 5, “Lưu thông số”. 2. KH-B đặt tour 1, 1 người lớn (đơn B7), không thanh toán; ghi hạn trên trang thanh toán và số chỗ còn của lịch. 3. Sau hạn, không mở trang nào của LocalTour, chờ thêm 5 phút (tác vụ tự động của trang demo). 4. KH-B mở B7; khách mở trang tour 1. 5. QTV đặt lại 30, lưu. | Bước 1, 5: “Đã lưu thông số vận hành.” Bước 2: hạn giữ chỗ = lúc đặt + 5 phút. Bước 4: B7 “Đã hủy” mà không ai bấm hủy, “Lịch sử đơn” ghi “Quá hạn thanh toán, đơn tự hủy” – “Hệ thống”, giờ của dòng này sớm hơn lúc KH-B mở đơn; số chỗ còn của lịch trở lại như trước khi đặt. | | Ghi mã B7 |
| UAT-49 | US-06 | Ngừng nhận đặt 60 phút trước giờ khởi hành | 1. QTV thêm cho tour 1 một lịch khởi hành sau hiện tại 45 phút; khách mở trang tour 1. 2. QTV thêm một lịch khởi hành sau hiện tại 65 phút; khách mở lại trang tour 1. 3. KH-B chọn lịch 65 phút, nhập thông tin tới “Xem lại đơn đặt tour”; chờ tới khi còn dưới 60 phút tới giờ khởi hành; bấm “Đặt tour và thanh toán”. 4. KH-B mở “Đơn của tôi”. | Bước 1: lịch 45 phút không có trong ô “Ngày tham gia”. Bước 2: lịch 65 phút có trong ô. Bước 3 bị chặn: “Lịch này không còn nhận đặt (đã đóng hoặc quá sát giờ khởi hành). Vui lòng chọn ngày khác.” Bước 4: không có đơn mới. | | |
| UAT-50 | US-11 | Không nhận VietQR khi còn dưới 24 giờ | 1. QTV thêm cho tour 1 một lịch khởi hành sau hiện tại khoảng 3 giờ. 2. KH-B đặt lịch này, 1 người lớn (đơn B8). 3. Xem trang thanh toán. | Bước 2: đặt được, B8 “Chờ thanh toán”. Bước 3: thẻ “Chuyển khoản VietQR” ghi “Không dùng được cho đơn này: còn dưới 24 giờ tới giờ khởi hành nên LocalTour không kịp đối chiếu chuyển khoản.”, không có nút “Lấy mã VietQR”; vẫn có “Thanh toán qua VNPay”. | | Ghi mã B8 (để đơn tự hủy) |

### 6.10. Phí dịch vụ, chi trả, hoàn tiền và thông số vận hành

| Mã | US | Kịch bản | Các bước | Kết quả mong đợi | Kết quả (Đạt/Không đạt) | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| UAT-51 | US-29, US-28 | Thông số có hiệu lực ngay; chuẩn bị lịch kết thúc sớm | 1. QTV “Thông số vận hành”: “Ngừng nhận đặt trước giờ khởi hành (phút)” = 0, “Ngừng nhận chuyển khoản VietQR (giờ)” = 0, “Lưu thông số”. 2. ĐV-A thêm cho tour T một lịch: Khởi hành = hiện tại + 30 phút, Kết thúc = hiện tại + 35 phút, sức chứa 10, giá vé người lớn 300.000đ. 3. KH-A đặt lịch này 2 người lớn (đơn A8), “Lấy mã VietQR”, “Tôi đã chuyển khoản”; KH-B đặt 1 người lớn (đơn B9), làm tương tự. 4. QTV bấm “Đã nhận tiền” cho A8 và B9. 5. QTV mở B9, “Hủy đơn”, nhập lý do, cập nhật. 6. QTV đặt lại 60 và 24, lưu; khách mở trang tour T. | Bước 1, 6: “Đã lưu thông số vận hành.” Bước 3: lịch còn dưới 60 phút vẫn có trong ô “Ngày tham gia” và đặt được; trang thanh toán có “Lấy mã VietQR”; hạn giữ chỗ không muộn hơn giờ khởi hành. Bước 4: A8, B9 “Đã xác nhận”. Bước 5: B9 “Đã hủy”, trang đơn báo có khoản cần hoàn tiền cho khách. Bước 6: lịch này không còn trong ô “Ngày tham gia”. | | Ghi mã A8, B9 và giờ kết thúc của lịch |
| UAT-52 | US-29 | Thông số vận hành: kiểm tra giá trị, lưu, phân quyền | 1. QTV mở “Thông số vận hành”. 2. Nhập “Phí dịch vụ LocalTour (%)” = 101, “Lưu thông số”. 3. Nhập phí = 10, “Thời gian giữ chỗ (phút)” = 4, lưu. 4. Nhập phí = 20, giữ chỗ = 30, lưu; bấm “Lưu thông số” lần nữa. 5. KH-A mở `/admin/settings`. | Bước 1: 4 ô đang là 10 / 30 / 60 / 24. Bước 2: “Nhập số từ 0 đến 100, tối đa 2 chữ số thập phân (ví dụ 10 hoặc 12,5).”, không lưu. Bước 3: “Nhập số nguyên từ 5 đến 1440 phút.”, không lưu. Bước 4: “Đã lưu thông số vận hành.”, dưới ô phí ghi “Sửa lần cuối … bởi …”; lần hai: “Không có thay đổi nào.” Bước 5: “Bạn không có quyền truy cập trang này.” | | Chạy trong lúc chờ lịch của UAT-51 kết thúc. Giữ phí 20 % tới hết UAT-53 |
| UAT-53 | US-28 | Đơn tự hoàn thành; ghi “Đã hoàn tiền”; lập khoản chi trả | 1. Sau giờ kết thúc của lịch ở UAT-51, QTV mở “Chi trả đơn vị tổ chức”. 2. QTV mở A8. 3. Ở “Hoàn tiền cho khách”, dòng B9: để trống mã, bấm “Đã hoàn tiền”; rồi nhập một mã giao dịch thử, bấm lại. Ghi “Đã hoàn tiền” cho các khoản còn lại (B2 từ UAT-16, A5 từ UAT-28). 4. Tải lại trang, tab “Chờ chi trả”. 5. ĐV-A mở “Doanh thu & chi trả”. 6. QTV đặt lại phí = 10, lưu. | Bước 1: lịch nằm ở “Lịch đã kết thúc, chưa lập được khoản chi trả”, cột “Còn dang dở” ghi “1 khoản hoàn tiền chưa chuyển cho khách”; chưa có khoản chi trả của lịch. Bước 2: A8 “Đã hoàn thành” mà không ai bấm, lịch sử ghi “Hệ thống”. Bước 3: để trống báo “Vui lòng nhập mã giao dịch hoàn tiền.”; có mã: “Đã ghi nhận hoàn tiền cho khách.”, dòng không còn trong mục. Bước 4: có một khoản “Chờ chi trả” của lịch, 1 đơn (B9 đã hoàn đủ nên không tính): Tiền thực thu 600.000đ; Phí dịch vụ 60.000đ (10 % lưu lúc đặt, không phải 20 %); Thực nhận 540.000đ; dòng ghi “Chưa khai tài khoản nhận tiền”. Bước 5: ĐV-A thấy cùng khoản, cùng số tiền, “Chờ chi trả”. | | Chưa tới giờ thì chờ |
| UAT-54 | US-28 | Xác minh tài khoản nhận tiền rồi mới ghi nhận đã chi trả | 1. QTV bấm “Chi trả” ở khoản của UAT-53. 2. ĐV-A “Tài khoản nhận tiền”: nhập Ngân hàng, Số tài khoản (số thử), Tên chủ tài khoản, “Lưu tài khoản”. 3. QTV tải lại trang khoản chi trả. 4. QTV bấm “Đã kiểm tra, xác minh tài khoản này”. 5. Để trống “Mã giao dịch chuyển khoản”, bấm “Ghi nhận đã chi trả”; rồi nhập một mã thử, bấm lại. 6. ĐV-A mở “Doanh thu & chi trả”, “Xem” khoản đó. 7. ĐV-A đổi “Số tài khoản”, lưu. 8. ĐV-B dán địa chỉ trang khoản chi trả của ĐV-A. | Bước 1: “Chưa chuyển khoản được: đơn vị chưa khai tài khoản nhận tiền. …”, không có ô nhập mã giao dịch. Bước 2: “Đã lưu tài khoản nhận tiền.”, trang ghi “Chờ LocalTour xác minh: …”. Bước 3: “Xác minh: Chưa xác minh”; “Chưa chuyển khoản được: tài khoản nhận tiền của đơn vị chưa được xác minh. …”. Bước 4: “Đã xác minh tài khoản nhận tiền của đơn vị.”, hiện ô “Mã giao dịch chuyển khoản”. Bước 5: để trống báo “Vui lòng nhập mã giao dịch chuyển khoản.”; có mã: “Đã ghi nhận chuyển khoản. Khoản chi trả chuyển sang “Đã chi trả”.” Bước 6: khoản “Đã chi trả”, có “Chuyển lúc”, “Mã giao dịch”, “Tài khoản nhận”. Bước 7: trang lại ghi “Chờ LocalTour xác minh: …”; khoản đã chi trả giữ tài khoản đã nhận tiền. Bước 8: “Không tìm thấy trang”. | | Che số tài khoản trong ảnh |

## 7. Đối chiếu User Story → ca UAT

| US | Ưu tiên | Ca UAT | US | Ưu tiên | Ca UAT |
| --- | --- | --- | --- | --- | --- |
| US-01 | Must | UAT-01 | US-16 | Must | UAT-07, 08, 30 |
| US-02 | Must | UAT-02 | US-17 | Must | UAT-35 |
| US-03 | Must | UAT-03, 04 | US-18 | Must | UAT-35 |
| US-04 | Must | UAT-05 | US-19 | Must | UAT-36 |
| US-05 | Must | UAT-09 | US-20 | Must | UAT-37 |
| US-06 | Must | UAT-10, 11, 49 | US-21 | Must | UAT-32, 33, 41, 42 |
| US-07 | Must | UAT-31, 32, 34 | US-22 | Must | UAT-12, 30 |
| US-08 | Must | UAT-17 | US-23 | Must | UAT-13, 19 |
| US-09 | Must | UAT-13, 14, 15 | US-24 | Must | UAT-15, 16 |
| US-10 | Must | UAT-21, 22, 24 | US-25 | Must | UAT-38, 39 |
| US-11 | Must | UAT-18, 50 | US-26 | Must | UAT-40, 41, 42, 43, 44, 45, 47 |
| US-12 | Must | UAT-19, 20, 23, 24 | US-27 | Must | UAT-46, 47 |
| US-13 | Must | UAT-25, 26, 48 | US-28 | Must | UAT-51, 53, 54 |
| US-14 | Should | UAT-27, 28, 29 | US-29 | Must | UAT-48, 51, 52 |
| US-15 | Could | UAT-06 | | | |

## 8. Biên bản nghiệm thu UAT (điền ngày 16/11; phần sửa lỗi 6.6 điền ngày 18/11)

| Mục | Nội dung |
| --- | --- |
| Ngày | …/11/2026, từ …… đến …… |
| Địa điểm / máy | |
| Trình duyệt (tên, phiên bản) | |
| Mã commit bản demo trên trang demo | |

Thành phần:

| Họ tên | Vai trò | Có mặt |
| --- | --- | --- |
| Lê Trung Phong | PM, hỗ trợ kỹ thuật | ☐ |
| Nguyễn Tuấn Khôi | Phát triển, hỗ trợ kỹ thuật | ☐ |
| Nguyễn Minh Thức | Phát triển, hỗ trợ kỹ thuật | ☐ |
| Hồ Duy Hải | QA, điều phối UAT | ☐ |
| Đỗ Sơn Thành | QA, điều phối UAT | ☐ |
| ……… (nhóm PCG) | Người dùng vai khách hàng | ☐ |
| ……… (nhóm PCG) | Người dùng vai quản trị viên | ☐ |
| ……… (nhóm PCG) | Người dùng vai đơn vị tổ chức | ☐ |

Tổng hợp kết quả:

| Nhóm | Số ca | Đạt | Không đạt | Chưa chạy |
| --- | --- | --- | --- | --- |
| Xem, tìm và so sánh tour (UAT-01–06) | 6 | | | |
| Tài khoản và đặt tour (UAT-07–11) | 5 | | | |
| Đơn đặt tour, quản trị viên (UAT-12–17) | 6 | | | |
| Thanh toán và voucher (UAT-18–26) | 9 | | | |
| Đổi ngày / hủy tour (UAT-27–29) | 3 | | | |
| Phân quyền, quản trị tour và thống kê (UAT-30–37) | 8 | | | |
| Tài khoản và tour của đơn vị tổ chức (UAT-38–45) | 8 | | | |
| Đơn đặt tour của đơn vị tổ chức (UAT-46–47) | 2 | | | |
| Giới hạn khi đặt tour giữ chỗ ngay (UAT-48–50) | 3 | | | |
| Phí dịch vụ, chi trả, hoàn tiền và thông số vận hành (UAT-51–54) | 4 | | | |
| **Tổng** | **54** | | | |
| Trong đó ca Must | 50 | | | |

Lỗi còn mở:

| Mã lỗi | Ca UAT | Mô tả | Mức độ | Hướng xử lý | Người phụ trách | Hạn |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

| Mục | Nội dung |
| --- | --- |
| Lỗi đã sửa trong 6.6 (mã DEF, commit) | |
| Ý kiến của người dùng | |
| Quyết định | ☐ Go ☐ Go có điều kiện ☐ No-go – lý do / điều kiện: |
| Người ký | PM: Lê Trung Phong ……… · QA: Hồ Duy Hải ……… · Đỗ Sơn Thành ……… · Người dùng: ……… · ……… · ……… · Ngày …/11/2026 |

## 9. Tổng hợp nghiệm thu demo (6.7, điền ngày 19/11)

| US | Nội dung | Ưu tiên | Ca UAT | Kết quả (Đạt / Không đạt / Chưa chạy) | Lỗi liên quan | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| US-01 | Danh sách tour | Must | UAT-01 | | | |
| US-02 | Chi tiết tour | Must | UAT-02 | | | |
| US-03 | Tìm, lọc, sắp xếp theo giá | Must | UAT-03, 04 | | | |
| US-04 | So sánh 2–3 tour | Must | UAT-05 | | | |
| US-05 | Giá minh bạch, phụ thu | Must | UAT-09 | | | |
| US-06 | Đặt tour, giữ chỗ ngay | Must | UAT-10, 11, 49 | | | |
| US-07 | Quản lý tour, nội dung, đơn vị tổ chức | Must | UAT-31, 32, 34 | | | |
| US-08 | Lịch khởi hành và sức chứa | Must | UAT-17 | | | |
| US-09 | Xác nhận đơn khi đã thanh toán, giữ giá lúc đặt | Must | UAT-13, 14, 15 | | | |
| US-10 | Đơn của tôi, thanh toán VNPay | Must | UAT-21, 22, 24 | | | |
| US-11 | Chuyển khoản VietQR | Must | UAT-18, 50 | | | |
| US-12 | Đối chiếu VietQR và VNPay chưa rõ kết quả | Must | UAT-19, 20, 23, 24 | | | |
| US-13 | Tự hủy đơn quá hạn giữ chỗ | Must | UAT-25, 26, 48 | | | |
| US-14 | Đổi ngày / hủy tour | Should | UAT-27, 28, 29 | | | |
| US-15 | Xem đánh giá | Could | UAT-06 | | | |
| US-16 | Đăng ký, đăng nhập, đăng xuất | Must | UAT-07, 08, 30 | | | |
| US-17 | Thống kê người dùng | Must | UAT-35 | | | |
| US-18 | Thống kê tour | Must | UAT-35 | | | |
| US-19 | Thống kê đơn đặt tour | Must | UAT-36 | | | |
| US-20 | Thống kê doanh thu | Must | UAT-37 | | | |
| US-21 | Duyệt tour và bản sửa | Must | UAT-32, 33, 41, 42 | | | |
| US-22 | Danh sách, chi tiết đơn đặt tour | Must | UAT-12, 30 | | | |
| US-23 | Xác nhận đơn (không còn bước xác nhận chỗ) | Must | UAT-13, 19 | | | |
| US-24 | Hủy đơn kèm lý do | Must | UAT-15, 16 | | | |
| US-25 | Tài khoản đơn vị tổ chức (FR-26) | Must | UAT-38, 39 | | | |
| US-26 | Đơn vị tổ chức quản lý tour (FR-27) | Must | UAT-40, 41, 42, 43, 44, 45, 47 | | | |
| US-27 | Đơn vị tổ chức xem đơn đặt tour (FR-28) | Must | UAT-46, 47 | | | |
| US-28 | Phí dịch vụ và chi trả cho đơn vị tổ chức (FR-29) | Must | UAT-51, 53, 54 | | | |
| US-29 | Thông số vận hành (FR-30) | Must | UAT-48, 51, 52 | | | |

| Mục | Kết quả |
| --- | --- |
| Bản demo đã nghiệm thu (mã commit) | |
| Installation Guide đã sửa theo 6.4 | ☐ Có ☐ Không cần sửa |
| User Guide đã sửa theo UAT | ☐ Có ☐ Không cần sửa |
| Số US đạt / tổng | __ / 29 |
| Lỗi mở theo mức (Critical / High / Medium / Low) | __ / __ / __ / __ |
| Điểm còn thiếu | |
| Chuyển sang Sprint 7 | |
| Quyết định nghiệm thu demo | ☐ Go ☐ Go có điều kiện ☐ No-go – lý do: |
| Bằng chứng | Biên bản mục 8, defect log, `MinhChung_UAT_Sprint6/` |
| Người ký | QA: Hồ Duy Hải ……… · Đỗ Sơn Thành ……… · PM: Lê Trung Phong ……… · Ngày …/11/2026 |
