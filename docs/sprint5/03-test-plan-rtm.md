# Test Plan và RTM Sprint 5

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 5 – So sánh tour, đổi/hủy và kiểm thử hệ thống (06/11 – 12/11/2026) |
| WBS | Test Plan / RTM; Chuẩn bị dữ liệu kiểm thử; Thực thi test nghiệp vụ E2E; Retest và hồi quy; System Test Exit |
| Người phụ trách | Hồ Duy Hải, Đỗ Sơn Thành (QA / Documentation) |
| Căn cứ | Gantt chart QLDA_LocalTour (Sprint 5); Product Backlog (US04, US06, US07, US14); [Sprint 4 – Rà soát và tồn đọng](../sprint4/R%C3%A0%20so%C3%A1t%20k%E1%BA%BFt%20qu%E1%BA%A3%20M3%20v%C3%A0%20t%E1%BB%93n%20%C4%91%E1%BB%8Dng.docx), mục 3; Kết quả kiểm thử và defect log Sprint 4; [src/README.md](../../src/README.md) (Route, Bước 5, 7–11); [src/database/README.md](../../src/database/README.md) (Dữ liệu mẫu và ca kiểm thử) |
| Tài liệu liên quan | [01 – Yêu cầu và luồng Sprint 5](01-yeu-cau-va-luong-sprint5.md), [02 – Cấu trúc dữ liệu Sprint 5](02-cau-truc-du-lieu-sprint5.md) |
| Bộ test case | TC-LT-74 → TC-LT-118 (45 ca: 40 Must, 5 Should), đánh số tiếp theo TC-LT-35…73 của Sprint 4 |
| Trạng thái | Bản nháp; nhóm rà soát và chốt ngày 07/11/2026 (trước khi chạy test 08/11). |

## 1. Mục tiêu và phạm vi

Mục tiêu: xác nhận bốn story Sprint 5 chạy đúng trên bản tích hợp theo đúng câu chữ, mã HTTP và dữ liệu của ứng dụng; không làm hỏng luồng đặt tour, thanh toán, voucher của Sprint 4; có đủ bằng chứng để quyết định Go / No-go ngày 12/11.

Trong phạm vi:

| Story | FR | Nội dung kiểm thử |
| --- | --- | --- |
| US04 – So sánh tour | FR-15 | Chọn / bỏ tour, tối đa 3 (lưu ở trình duyệt); bảng so sánh cùng đơn vị; ô thiếu ghi “Chưa cập nhật”; chặn quá 3 tour, tour ẩn, mã sai; trang `/compare` và `/api/compare`. |
| US06-S5-01 – Gói tour | FR-07 | Khách chọn gói khi đặt tour, giá theo gói; quản trị viên thêm / sửa / ngừng bán gói; đơn cũ giữ tên và giá gói. |
| US14 – Đổi ngày / hủy tour | FR-12 | Form theo chính sách hủy đã lưu cùng đơn; kiểm tra quyền, trạng thái, yêu cầu đang chờ; quản trị viên xử lý thủ công (CR1 đã bỏ vai trò nhân viên hỗ trợ); lịch sử và trạng thái yêu cầu. |
| US07-S5-01 – Hoàn thiện quản trị tour | FR-13 | Ảnh, lịch trình, dịch vụ, chính sách hủy (phiên bản mới); xóa tour / ngừng hiển thị / hiển thị lại; xóa đơn vị tổ chức chưa có tour. |
| Hồi quy Sprint 4 | FR-08, FR-09, FR-11, FR-14, FR-17, FR-24 | Đặt tour không có gói (tour 1), xác nhận chỗ, thanh toán VietQR / VNPay sandbox, voucher, CRUD đơn vị / tour / lịch. |

Ngoài phạm vi (không ghi Fail cho các mục này):

| Mục | Lý do |
| --- | --- |
| Tự động hoàn tiền | Đồng ý hủy chỉ ghi khoản hoàn `requested`; LocalTour chuyển khoản lại thủ công. |
| Email thông báo | Hệ thống chưa gửi email; khách xem kết quả ở trang đơn và trang “Đổi ngày / hủy tour”. |
| Đổi số người, đổi gói khi đổi ngày | Yêu cầu đổi ngày giữ nguyên số khách, gói và tổng tiền. |
| FR-16 gửi đánh giá tour | Backlog (Sprint 4, mục 3). |
| NFR-07 nhãn “Thông tin chưa được xác minh” trên trang khách | Backlog. |
| Thích, Bình luận, Chia sẻ, Lưu tour | Vẫn tắt, nhãn “Sắp có”. |

Đối chiếu Product Backlog và carryover từ Sprint 4:

| Việc ở Sprint 4 | Phân loại Sprint 4 | Sprint 5 |
| --- | --- | --- |
| So sánh 2–3 tour (FR-15) | Backlog, nút “Sắp có” | US04-S5-01 → 03, TC-LT-74–79 |
| Gói lựa chọn (FR-07) | Backlog (đã chốt thiết kế) | US06-S5-01, TC-LT-80–85 |
| Khách tự đổi / hủy đơn (FR-12) | Phát triển sau | US14-S5-01 → 03, TC-LT-86–97 |
| Ảnh, lịch trình, dịch vụ, chính sách hủy nhập bằng SQL (FR-13) | Sprint 4 làm một phần | US07-S5-01, TC-LT-98–108 |
| Kết quả kiểm thử Sprint 4 | 42/42 Pass; DEF-10, DEF-11 đã đóng | Không có lỗi tồn; hồi quy TC-LT-115–118 |

## 2. Môi trường

| Mục | Nội dung |
| --- | --- |
| Máy chủ | XAMPP 8.2 (PHP 8.2, MariaDB 10.4); chạy bằng Apache hoặc PHP built-in server theo Bước 4 của `src/README.md`; `.env` để `APP_DEBUG=false`. |
| Mã nguồn | Bản tích hợp Sprint 5; ghi mã commit đã chạy vào biên bản. |
| Database | Database thử trên máy mình (Cách B): import mới `src/database/db_localtour.sql` trước mỗi buổi chạy (lịch mẫu tính theo ngày import). **Không dùng database chung của nhóm**: các ca xóa tour, xóa đơn vị và nâng quyền quản trị làm đổi dữ liệu. |
| Tài khoản | KH-A, KH-B (khách hàng) và QTV (quản trị viên): tài khoản tự đăng ký, không ghi email/mật khẩu vào tài liệu. QTV: đăng ký ở `/register` rồi `UPDATE users SET role='admin'` trên database thử theo Bước 7 của `src/README.md`. |
| Trình duyệt | Chrome bản mới nhất: chạy đủ bộ ca. Edge: lượt rút gọn TC-LT-74, 76, 81, 89, 93, 118. Ghi số phiên bản vào biên bản. |
| Màn hình | Desktop 1366 px (mặc định); 390 px bằng DevTools (Toggle device toolbar) cho TC-LT-118. |
| Thanh toán | Đơn đã thanh toán: VietQR, QTV chọn “Đã nhận tiền” ở “Đối chiếu thanh toán”. VNPay sandbox (thẻ thử NCB) chỉ dùng khi cần thêm một đơn đã thanh toán. Khóa VNPay và tài khoản nhận VietQR chỉ nằm trong `.env`, không ghi vào tài liệu, che trong ảnh. Chưa cấu hình VietQR thì các ca cần đơn đã thanh toán ghi Blocked, không sửa database bằng tay. |
| Công cụ | DevTools (F12): bỏ thuộc tính `maxlength`, xóa ô ẩn `_csrf`, đổi cỡ màn hình, gọi API. |
| Minh chứng | Thư mục `MinhChung_KiemThu_Sprint5/`, ảnh đặt tên `TC-LT-xx_mo-ta.png`; email làm mờ, mã QR và số tài khoản che. |

## 3. Lịch kiểm thử

| Ngày | Công việc (Gantt) | Người | Đầu ra |
| --- | --- | --- | --- |
| 06–07/11 | Test Plan / RTM: chốt phạm vi Sprint 5, đối chiếu Product Backlog và carryover từ Sprint 4, lập RTM và độ bao phủ kiểm thử | Hải + Thành | Mục 1, 7, 8 |
| 06–07/11 | Chuẩn bị dữ liệu kiểm thử: tạo case thường / biên / lỗi | Hải + Thành | Mục 6: database thử, 3 tài khoản, file ảnh, giá trị biên |
| 08–09/11 | Thực thi test nghiệp vụ E2E: ghi từng test case, actual result và defect kèm minh chứng | Hải + Thành | Kết quả TC-LT-74–108, defect log |
| 08–09/11 | Kiểm tra kỹ thuật phân quyền / input: validation, quyền truy cập, lỗi UI | Phong + Thức + Khôi | Kết quả TC-LT-79, 109–114 (và các bước DevTools trong ca khác) |
| 10–11/11 | Sửa lỗi Critical / High, gắn commit | Phong, Thức, Khôi (người làm chức năng có lỗi) | Mã commit ở cột “Commit sửa” |
| 11–12/11 | Retest và hồi quy | Hải + Thành ghi kết quả | Ca Fail chạy lại, TC-LT-115–118 |
| 12/11 | System Test Exit: đối chiếu Test Plan / RTM và Defect Log; tổng hợp Pass / Fail / Blocked, lỗi còn mở, carryover sang Sprint 6, quyết định Go / No-go có bằng chứng | Hải + Thành lập, cả nhóm quyết định | Mục 9 |

## 4. Tiêu chí vào / ra

| Tiêu chí vào (trước khi chạy 08/11) |
| --- |
| 1. Bản tích hợp có đủ US04, US06-S5-01, US07-S5-01, US14; ghi mã commit chạy thử. |
| 2. Import mới `db_localtour.sql` không lỗi: 31 bảng, 92 procedure; 4 câu kiểm tra ở mục “Cách 1” của `src/database/README.md` đúng. |
| 3. Bảng ở Bước 5 của `src/README.md` đúng hết (9 tour, tour 10 → “Không tìm thấy tour”, API). |
| 4. Có KH-A, KH-B, QTV, file ảnh mẫu (mục 6.3); `.env` có cấu hình VietQR (và VNPay sandbox nếu dùng). |
| 5. Test Plan / RTM này đã chốt (07/11). |

| Tiêu chí ra (System Test Exit 12/11) |
| --- |
| 1. Cả 40 ca Must đã chạy, có trạng thái Pass / Fail / Blocked và minh chứng; ca Should chưa chạy ghi lý do. |
| 2. Không còn lỗi Critical / High ở trạng thái Mở, Đang sửa hoặc Chờ retest. |
| 3. Mọi lỗi đã sửa có commit và đã retest; TC-LT-115–118 (hồi quy) Pass. |
| 4. Lỗi Medium / Low còn mở được ghi vào carryover Sprint 6. |
| 5. Có bảng tổng hợp mục 9 và quyết định Go / No-go có người ký. |

## 5. Mức độ lỗi và defect log

| Mức | Định nghĩa | Xử lý |
| --- | --- | --- |
| Critical (Nghiêm trọng) | Sai / mất dữ liệu đơn, chỗ hoặc tiền hoàn; lộ đơn của khách khác; khách hàng dùng được chức năng quản trị; lỗi PHP / trang trắng chặn cả một story. | Sửa 10–11/11; còn mở → No-go |
| High (Cao) | Chức năng chính của một WBS sai hoặc không làm được, không có cách khác; bỏ qua kiểm tra chính sách, trạng thái hoặc CSRF. | Sửa 10–11/11; còn mở → No-go |
| Medium (Trung bình) | Chức năng chạy nhưng sai ở trường hợp phụ, thông báo sai / thiếu; có cách làm khác. | Sửa nếu kịp, không thì carryover |
| Low (Thấp) | Câu chữ, căn lề, giao diện nhỏ; không ảnh hưởng nghiệp vụ. | Ghi nhận, carryover nếu chưa sửa |

Cột của defect log (mã lỗi nối tiếp DEF-11 của Sprint 4):

| Cột | Cách ghi |
| --- | --- |
| Mã lỗi | DEF-12, DEF-13… |
| Test case | TC-LT-xx, hoặc “Không gắn với một ca” |
| Tiêu đề | Một câu: ở đâu, sai gì |
| Mức độ / Loại | Mức ở bảng trên; Loại: Chức năng / Giao diện / Phân quyền – bảo mật / Dữ liệu / Tài liệu |
| Bước tái hiện | Các bước đánh số, kèm mã tour, mã đơn (không ghi email, mật khẩu) |
| Kết quả mong đợi / thực tế | Chép đúng câu chữ trên màn hình và mã HTTP nếu có |
| Minh chứng | Đường dẫn ảnh trong `MinhChung_KiemThu_Sprint5/` |
| Người xử lý / Commit sửa | Người làm chức năng; mã commit (bắt buộc với Critical / High) |
| Ngày phát hiện / Ngày retest | dd/mm/2026 |
| Trạng thái | Mở → Đang sửa → Chờ retest → Đã đóng (hoặc Mở lại) |

## 6. Dữ liệu kiểm thử

Nguồn: `src/database/README.md`, mục “Dữ liệu mẫu và ca kiểm thử”. Mã tour N = `c0000000-0000-4000-8000-00000000000N` (tour 10 = `…000000000010`). Trong mục 7, `{tour N}` là mã tour N, `{mã Đn}` là mã đơn `LTxxxxxx` của đơn Đn ở mục 6.2.

### 6.1. Tour, đơn vị và mã có sẵn

| Dữ liệu | Đặc điểm | Dùng ở |
| --- | --- | --- |
| Tour 1 “Hà Nội qua những món ăn phố cổ” | Không có gói; 4 lịch đặt được; chính sách 24 giờ, sau mốc không hoàn; còn đơn mẫu chờ xác nhận (LT518204) và đã xác nhận (LT574913) | 76, 78, 86, 106, 115 |
| Tour 2 “Ẩm thực Hà Nội & cà phê trứng” | Không có gói; chính sách 24 giờ, sau mốc không hoàn | Đ2 |
| Tour 3 “Phố cổ theo cách của bạn” | 3 gói `f5000000-0000-4000-8000-000000000001`…`003`: “Kiến trúc và phố nghề” 900.000đ, “Đền chùa và tín ngưỡng” 950.000đ, “Góc ảnh phố cổ” 1.200.000đ, chỉ vé người lớn; nhóm tối đa 4 khách; chính sách 48 giờ, sau mốc hoàn 50% | 76, 80–85, 87 |
| Tour 7 “Làng rau Trà Quế: đạp xe và học nấu ăn” | Đang hiển thị; chính sách phiên bản 1: 24 giờ, sau mốc hoàn 50% | 98, 101, 102 |
| Tour 8 “Sài Gòn về đêm trên xe máy” | Chỉ có đơn đã hoàn thành → xóa thành “Ngừng hiển thị”. Không đặt đơn mới cho tour này. | 105 |
| Tour 9 “Chợ Lớn: hẻm nhỏ, hội quán và món Hoa” | Không có giá, lịch mở, loại hình, ảnh, lịch trình, dịch vụ; 7 trường thông tin để trống | 77 |
| Tour 10 “Đạp xe quanh Hồ Tây lúc bình minh” | Chờ duyệt (ẩn): 404, bị bỏ khỏi so sánh | 78, 118 |
| Tour 12 “Làm đèn lồng cùng nghệ nhân phố Hội” | Bị từ chối, chưa có đơn, chưa có ảnh → xóa hẳn | 100, 103, 104 |
| Đơn vị “Hà Nội Local” (`b0000000-0000-4000-8000-000000000001`) | Có 2 tour (tour 1, tour 10) → không xóa được | 108 |
| Mã không tồn tại / sai dạng | `c0000000-0000-4000-8000-000000009999`, `abc`, `not-a-uuid`, `LT000000` | 78, 113 |

### 6.2. Đơn tạo trong lúc chạy (tài khoản KH-A)

| Đơn | Cách tạo | Trạng thái cần | Dùng ở |
| --- | --- | --- | --- |
| Đ1 | Tour 1, 1 người lớn, lịch còn chỗ | Chờ xác nhận | 86, 90, 94, 109, 111 |
| Đ2 | Tour 2, 2 người lớn, lịch khởi hành sau ít nhất 2 ngày; QTV “Xác nhận chỗ và giá” → KH-A “Thanh toán ngay” → VietQR → “Tôi đã chuyển khoản” → QTV “Đã nhận tiền” | Đã xác nhận, đã thanh toán | 87, 89, 92, 93 |
| Đ3 | TC-LT-81: tour 3, gói “Đền chùa và tín ngưỡng”, 2 người lớn | Chờ xác nhận | 87, 88, 95 |
| Đ4 | Tour 4, 1 người lớn; QTV xác nhận chỗ → KH-A VietQR “Tôi đã chuyển khoản”; QTV chưa đối chiếu | Chờ thanh toán, khoản “Chờ đối chiếu” | 96, 97 |
| Đ5 | TC-LT-84: tour 3, “Gói thử QA”, 1 người lớn | Chờ xác nhận | 84, 85 |
| Đ6 | TC-LT-102: tour 7, 1 người lớn, đặt trước khi đổi chính sách | Chờ xác nhận | 102 |

### 6.3. Giá trị thường / biên / lỗi và file mẫu

| Dữ liệu | Thường | Biên | Lỗi |
| --- | --- | --- | --- |
| Số tour so sánh | 2–3 | Đủ 3, thêm tour thứ 4 | 1 tour; 4 mã trên URL; mã `abc`; tour 10 |
| Lý do đổi / hủy | Câu ngắn | 500 ký tự | Trống; 501 ký tự |
| Ghi chú của QTV | Câu ngắn | 500 ký tự | Trống; 501 ký tự |
| Số tiền hoàn | Để trống (= số dự kiến) | 0đ; đúng bằng số đã trả | Số đã trả + 1.000đ |
| Tên gói | “Gói thử QA” | 100 ký tự | Trống; 101 ký tự; trùng “Kiến trúc và phố nghề” |
| Giá gói | 1.000.000 | 1; 100.000.000 | Trống; 0; 100.000.001 |
| Chính sách hủy | 72 giờ, 30% | Giờ 0 / 720 / để trống; 0% / 100%; nội dung 2000 ký tự | Giờ 721; 101%; nội dung trống / 2001 ký tự |
| Lịch trình / dịch vụ | 08:30 + nội dung | Không ghi giờ; nội dung 255 ký tự, tên dịch vụ 150 ký tự | Nội dung trống; 256 / 151 ký tự; giờ `25:00`; thứ tự 1000 |
| Ảnh | `anh-hop-le.png` hoặc `.jpg`: ảnh thật dưới 2 MB; đường dẫn `https://…` | Ảnh thứ 12 của một tour | `khong-phai-anh.png`: file văn bản đổi đuôi .png; `anh-qua-lon.jpg`: ảnh thật khoảng 3 MB (trên 2 MB, dưới giới hạn tải lên 40 MB của PHP trong XAMPP); đường dẫn `http://…`; ảnh thứ 13 |

## 7. Danh sách test case

Loại: thường / biên / lỗi / quyền / hồi quy. Ưu tiên: **Must** – bắt buộc chạy trước System Test Exit; **Should** – chạy nếu kịp, không chạy thì ghi lý do. Chạy theo thứ tự ID (các ca sau dùng đơn và dữ liệu của ca trước). Kết quả thực tế, trạng thái và minh chứng ghi vào biên bản kết quả kiểm thử Sprint 5 (cùng dạng Sprint 4).

### 7.1. US04 – So sánh tour (FR-15)

| ID | Story/WBS | Loại | Bước chính | Kết quả mong đợi | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| TC-LT-74 | US04-S5-01 | thường | Chưa đăng nhập, mở `/tours`, bấm “Thêm vào so sánh” ở 3 thẻ tour; bấm lại ở 1 thẻ để bỏ; tải lại trang (F5). | Lần lượt hiện “Đã thêm vào so sánh. Chọn thêm ít nhất 1 tour để so sánh.”, “Đã thêm vào so sánh (2/3 tour).”, “Đã thêm vào so sánh (3/3 tour).”; khung “Tour đang so sánh” đếm 3/3 tour. Bỏ: “Đã bỏ "{tên tour}" khỏi so sánh.”, còn 2/3. Tải lại vẫn giữ 2 tour. | Must |
| TC-LT-75 | US04-S5-01 | biên | Đã chọn 3 tour, bấm “Thêm vào so sánh” ở thẻ thứ 4. | Cảnh báo “Chỉ so sánh tối đa 3 tour. Bỏ bớt một tour trước khi thêm tour khác.”; vẫn 3/3, tour thứ 4 không được thêm. | Must |
| TC-LT-76 | US04-S5-02, 03 | thường | Chọn tour 3 rồi tour 1, bấm “So sánh tour”; xong bấm “Xóa danh sách”. | `/compare?ids=…` đặt 2 tour theo thứ tự chọn, 4 nhóm “Giá và lịch”, “Thông tin tour”, “Lịch trình và dịch vụ”, “Chính sách”. Tour 3: “Từ 900.000đ / người lớn”, “Không bán vé trẻ em”, 3 tên gói, “Tối đa 4 khách”, “Hủy miễn phí trước giờ khởi hành 48 giờ.” + “Sau thời điểm này hoàn 50% tiền tour.”. Tour 1: “650.000đ / người lớn”, “Một gói chung”, “Tối đa 8 khách”. Cả hai “4 giờ”. “Xóa danh sách” → “Đã xóa danh sách so sánh.”. | Must |
| TC-LT-77 | US04-S5-02 | biên | Mở `/compare?ids={tour 1},{tour 9}`. | Cột tour 9: “Giá người lớn”, “Giá trẻ em”, “Lịch trình”, “Bao gồm”, “Không bao gồm”, “Điểm kết thúc”, “Phương tiện”, “Hướng dẫn viên”, “Ăn uống”, “Đổi lịch” ghi “Chưa cập nhật” (chữ nghiêng, màu nhạt); “Lịch gần nhất” ghi “Chưa có lịch mở bán”; “Đánh giá” ghi “Chưa có đánh giá”; loại hình dưới tên tour “Chưa cập nhật”. Không ô trống, không lỗi PHP. | Must |
| TC-LT-78 | US04-S5-03 | lỗi | Mở lần lượt: (1) `/compare?ids={tour 1}`; (2) `/compare?ids={tour 1},{tour 10}`; (3) `/compare?ids=abc,{tour 1},{tour 3}`; (4) `/compare?ids={tour 1},{tour 2},{tour 3},{tour 4}`. | (1) “Cần ít nhất 2 tour để so sánh”, nút “Chọn tour ở bảng tin”. (2) “1 tour không còn hiển thị hoặc không hợp lệ nên đã được bỏ khỏi so sánh.” và “Cần ít nhất 2 tour để so sánh” (tour 10 không lộ). (3) Cùng thông báo bỏ 1 tour, bảng có tour 1 và 3. (4) “Chỉ so sánh tối đa 3 tour. Trang đang hiển thị 3 tour đầu tiên bạn chọn.”, bảng có 3 tour đầu. | Must |
| TC-LT-79 | US04-S5-03 | lỗi | Gọi `/api/compare?ids=` với 1 mã, 4 mã, 2 mã hợp lệ. | 1 mã: HTTP 422 “Chọn ít nhất 2 tour để so sánh.”; 4 mã: 422 “Chỉ so sánh tối đa 3 tour.”; 2 mã: 200, JSON có `tours`, `rows`, `skipped`. | Should |

### 7.2. US06 – Gói tour (FR-07)

| ID | Story/WBS | Loại | Bước chính | Kết quả mong đợi | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| TC-LT-80 | US06-S5-01 | thường | Mở `/tours/{tour 3}`, ở thẻ đặt tour chọn gói “Đền chùa và tín ngưỡng”. | Mục “Gói tour”: “Tour có 3 gói. Chọn gói ở thẻ đặt tour; giá vé tính theo gói đã chọn.”, 3 gói 900.000đ / 950.000đ / 1.200.000đ “/ người lớn”, mỗi gói “Không bán vé trẻ em.”; thẻ đặt tour “Từ 900.000đ / người lớn”, ô “Gói tour” có 3 lựa chọn dạng “Đền chùa và tín ngưỡng · 950.000đ / người lớn”; chọn gói này thì tạm tính theo 950.000đ / người lớn. | Must |
| TC-LT-81 | US06-S5-01 | thường | KH-A: tour 3, gói “Đền chùa và tín ngưỡng”, 2 người lớn → “Đặt tour” → điền thông tin → “Xem lại & xác nhận” → “Gửi yêu cầu đặt tour” (tạo Đ3). | Tạm tính 1.900.000đ; trang đặt tour chọn sẵn đúng gói; bước xem lại có “Gói tour” và “Tổng tiền 1.900.000đ”; trang đơn “Đã gửi yêu cầu đặt tour”, “Chờ xác nhận”, gói “Đền chùa và tín ngưỡng”. | Must |
| TC-LT-82 | US06-S5-01 | thường | QTV: chi tiết tour 3 → “Gói tour” → “Thêm gói”: “Gói thử QA”, giá người lớn 1.000.000, giá trẻ em để trống. | “Đã thêm gói tour.”; bảng có gói mới “Đang bán”; trang khách tour 3 có 4 gói, gói mới ghi “Không bán vé trẻ em.”. | Must |
| TC-LT-83 | US06-S5-01 | lỗi, biên | Thêm gói: để trống tên và giá; tên trùng “Kiến trúc và phố nghề”; giá 0 và 100.000.001. “Sửa gói” Gói thử QA giá 100.000.000 rồi trả về 1.000.000. | Trống: “Chưa lưu được gói: vui lòng kiểm tra lại các ô được đánh dấu.” + “Vui lòng nhập tên gói.”, “Vui lòng nhập giá người lớn.”; trùng: “Tour đã có gói cùng tên.”; 0 và 100.000.001: “Giá phải lớn hơn 0đ và không quá 100.000.000đ.”; 100.000.000 lưu được. Không thêm gói lỗi nào. | Must |
| TC-LT-84 | US06-S5-01 | thường | KH-A đặt Đ5 (Gói thử QA, 1 người lớn). QTV “Sửa gói”: tên “Gói thử QA 2”, giá 1.100.000 → “Lưu gói”; bấm “Lưu gói” lần nữa không đổi gì. | “Đã lưu gói tour.”; lần 2 “Không có thay đổi nào.”; trang khách hiện tên, giá mới; Đ5 vẫn ghi “Gói thử QA”, tổng 1.000.000đ. | Must |
| TC-LT-85 | US06-S5-01 | lỗi | KH-A mở trang đặt tour 3 với “Gói thử QA 2”, đến bước xem lại; QTV bỏ chọn “Đang bán” của gói này, lưu; KH-A bấm “Gửi yêu cầu đặt tour”. | Khách nhận “Gói tour vừa thay đổi (gói ngừng bán, tour đổi danh sách gói hoặc gói không bán vé trẻ em). Vui lòng tải lại trang để chọn lại.”, không có đơn mới. Bảng gói ghi “Ngừng bán”; tải lại tour 3 còn 3 gói; Đ5 vẫn giữ tên gói. | Must |

### 7.3. US14 – Đổi ngày / hủy tour (FR-12)

| ID | Story/WBS | Loại | Bước chính | Kết quả mong đợi | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| TC-LT-86 | US14-S5-01 | thường | KH-A mở Đ1 → “Đổi ngày / hủy tour”. | Trang “Đổi ngày / hủy tour”: “Chính sách hủy của đơn” ghi “Hủy miễn phí trước giờ khởi hành 24 giờ. Sau thời điểm này không hoàn tiền.”; “Hủy tour” ghi “Đơn chưa thanh toán nên không có tiền hoàn.”; “Đổi sang ngày khác” có ô “Chọn ngày” với các lịch khác của tour 1 còn đủ chỗ; ô “Lý do” đếm “0/500 ký tự”; “Chưa có yêu cầu nào cho đơn này.”. | Must |
| TC-LT-87 | US14-S5-01 | thường | Mở trang đổi / hủy của Đ3 (tour 3) và Đ2 (tour 2, đã thanh toán). | Đ3: chính sách tour 3 “Hủy miễn phí trước giờ khởi hành 48 giờ.” / “Sau thời điểm này hoàn 50% tiền tour.”. Đ2: chính sách tour 2 (24 giờ) và “Dự kiến được hoàn {số tiền} theo chính sách hủy.”, số tiền = số đã trả (đang trước mốc 24 giờ). | Must |
| TC-LT-88 | US14-S5-01 | lỗi, biên | Trên Đ3: “Hủy tour”, lý do trống → “Gửi yêu cầu”; “Đổi sang ngày khác” không chọn ngày; dán 501 ký tự (ô chỉ nhận 500); DevTools bỏ `maxlength`, gửi 501 ký tự; cuối cùng gửi “Hủy tour” với đúng 500 ký tự. | Ba lần lỗi: “Chưa gửi được yêu cầu: vui lòng kiểm tra lại các ô được đánh dấu.” với lỗi ô “Vui lòng nhập lý do.” / “Vui lòng chọn ngày muốn đổi sang.” / “Lý do tối đa 500 ký tự.”, không tạo yêu cầu. 500 ký tự: gửi được, “Hủy tour · Chờ xử lý”. | Must |
| TC-LT-89 | US14-S5-02 | thường | KH-A gửi yêu cầu hủy Đ2 với lý do ngắn; mở lại trang đổi / hủy của Đ2. | “Đã gửi yêu cầu. LocalTour sẽ xử lý và cập nhật kết quả trên trang này. Tiền hoàn (nếu có) được LocalTour chuyển lại thủ công.”; “Yêu cầu đã gửi”: “Hủy tour · Chờ xử lý”, lý do, “Dự kiến hoàn: …”; đơn vẫn “Đã xác nhận”. Mở lại: “Không gửi được yêu cầu mới” – “Đơn đang có một yêu cầu chờ LocalTour xử lý. Vui lòng chờ kết quả trước khi gửi yêu cầu mới.”. | Must |
| TC-LT-90 | US14-S5-02 | thường | KH-A gửi yêu cầu cho Đ1: “Đổi sang ngày khác”, chọn một ngày, nhập lý do. | “Đã gửi yêu cầu…”; “Đổi ngày · Chờ xử lý”; Đ1 vẫn ở ngày cũ cho tới khi được đồng ý. | Must |
| TC-LT-91 | US14-S5-03 | thường | QTV mở menu “Đổi ngày / hủy tour”, bấm lần lượt các tab. | Trang “Yêu cầu đổi ngày / hủy tour”; tab “Chờ xử lý” (mặc định) có yêu cầu của Đ1, Đ2, Đ3 với mã đơn, tour, “Hủy tour” kèm “Dự kiến hoàn …” hoặc “Đổi ngày” kèm “Sang {ngày giờ}”, số đã thanh toán; “Đã đồng ý”, “Đã từ chối”, “Tất cả” lọc đúng. | Must |
| TC-LT-92 | US14-S5-03 | lỗi, biên | Mở yêu cầu hủy Đ2, chọn “Đồng ý hủy tour”, “Lưu kết quả” với: (1) ghi chú trống; (2) “Số tiền hoàn (đ)” = số đã trả + 1.000; (3) ghi chú 501 ký tự (bỏ `maxlength`). | “Chưa xử lý được: vui lòng kiểm tra lại các ô được đánh dấu.” kèm (1) “Vui lòng nhập ghi chú gửi khách (lý do đồng ý / từ chối).”, (2) “Số tiền hoàn từ 0đ đến số khách đã thanh toán ({số đã trả}).”, (3) “Ghi chú tối đa 500 ký tự.”; yêu cầu vẫn “Chờ xử lý”, đơn không đổi. | Must |
| TC-LT-93 | US14-S5-03 | thường | Đồng ý hủy Đ2: “Số tiền hoàn” để trống, ghi chú hợp lệ → “Lưu kết quả”. Xem trang yêu cầu đặt tour của Đ2 và trang của KH-A. | “Đã đồng ý yêu cầu và cập nhật đơn.”; Đ2 “Đã hủy”; “Chỗ của lịch” tăng lại 2; lịch sử xử lý có “Đồng ý hủy tour” và “Tạo yêu cầu hoàn tiền” (khoản hoàn chờ chuyển tay, không có giao dịch hoàn tự động). KH-A thấy “Hủy tour · Đã đồng ý”, “Số tiền hoàn: … (LocalTour chuyển lại thủ công)”, “Phản hồi của LocalTour: …”; trang đổi / hủy: “Đơn đã đóng (bị từ chối, đã hủy hoặc đã hoàn thành) nên không đổi ngày hay hủy được nữa.”. | Must |
| TC-LT-94 | US14-S5-03 | thường | Mở yêu cầu đổi ngày của Đ1, chọn “Đồng ý đổi ngày”, ghi chú → “Lưu kết quả”. | “Đã đồng ý yêu cầu và cập nhật đơn.”; Đ1 sang ngày mới, số khách, tổng tiền và trạng thái đơn giữ nguyên; lịch sử có “Đồng ý đổi ngày”; KH-A thấy ngày mới và “Đổi ngày · Đã đồng ý”. | Must |
| TC-LT-95 | US14-S5-03 | thường | Mở yêu cầu hủy của Đ3, chọn “Từ chối, giữ nguyên đơn”, ghi chú → “Lưu kết quả”. | “Đã từ chối yêu cầu. Đơn giữ nguyên.”; Đ3 vẫn “Chờ xác nhận”, vẫn ghi gói; KH-A thấy “Hủy tour · Đã từ chối” và phản hồi; trang đổi / hủy của Đ3 lại cho gửi yêu cầu mới. | Must |
| TC-LT-96 | US14-S5-03 | lỗi | KH-A gửi yêu cầu hủy Đ4 (khoản “Chờ đối chiếu”); QTV chọn “Đồng ý hủy tour”, ghi chú → “Lưu kết quả”. | Báo “Đơn còn khoản chuyển khoản chờ đối chiếu. Hãy đối chiếu ở trang "Đối chiếu thanh toán" trước khi đồng ý hủy.”; đơn và yêu cầu không đổi (xử lý tiếp ở TC-LT-97). | Must |
| TC-LT-97 | US14-S5-03 | lỗi | Mở yêu cầu của Đ4 ở 2 tab; tab 1 “Từ chối, giữ nguyên đơn” → “Lưu kết quả”; tab 2 bấm “Lưu kết quả”. | Tab 1: “Đã từ chối yêu cầu. Đơn giữ nguyên.”; tab 2: “Yêu cầu này đã được xử lý trước đó.”, kết quả tab 1 giữ nguyên. | Should |

### 7.4. US07 – Hoàn thiện quản trị tour (FR-13)

| ID | Story/WBS | Loại | Bước chính | Kết quả mong đợi | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| TC-LT-98 | US07-S5-01 | thường | QTV: tour 7 → “Ảnh, lịch trình, dịch vụ, chính sách” → tải `anh-hop-le.png` kèm mô tả → “Đặt làm ảnh bìa” → xem `/tours` → đặt lại ảnh bìa cũ → bấm “Xóa” ở ảnh mới. | “Đã thêm ảnh.”, số ảnh “Ảnh (n/12)” tăng 1; “Đã đặt ảnh bìa.”, thẻ tour 7 dùng ảnh mới; “Đã xóa ảnh.”, ảnh mất khỏi trang khách. | Must |
| TC-LT-99 | US07-S5-01 | lỗi | Tải `khong-phai-anh.png`; tải `anh-qua-lon.jpg`; dán đường dẫn `http://…`. | “Chưa lưu được: vui lòng kiểm tra lại các ô được đánh dấu.” kèm “Chỉ nhận ảnh JPG, PNG hoặc WebP.” / “Ảnh tối đa 2 MB.” / “Đường dẫn ảnh phải bắt đầu bằng https:// và tối đa 255 ký tự.”; số ảnh không đổi. | Must |
| TC-LT-100 | US07-S5-01 | biên | Tour 12: thêm ảnh bằng đường dẫn `https://…` tới 12 ảnh, rồi thêm ảnh thứ 13. | Ảnh thứ 12 thêm được (“Ảnh (12/12)”); ảnh thứ 13: “Mỗi tour tối đa 12 ảnh. Xóa bớt ảnh trước khi thêm.”. | Should |
| TC-LT-101 | US07-S5-01 | thường | Tour 7: “Thêm mục” lịch trình 08:30; “Thêm mục” không ghi giờ; “Sửa” một mục → “Lưu mục”; “Xóa” một mục. “Thêm dịch vụ”: 1 mục bao gồm, 1 mục không bao gồm; “Xóa” 1 mục. | “Đã lưu mục lịch trình.”, “Đã xóa mục lịch trình.”, “Đã thêm dịch vụ.”, “Đã xóa dịch vụ.”; trang khách tour 7 hiện đúng thứ tự, mục không giờ không ghi giờ, mục bao gồm đứng trước. | Must |
| TC-LT-102 | US07-S5-01 | thường | KH-A đặt Đ6. QTV nhập chính sách hủy tour 7: 72 giờ, 30%, nội dung mới → “Lưu phiên bản mới”; lưu lại y hệt lần nữa. | “Đã thêm phiên bản chính sách hủy mới. Đơn đã đặt vẫn giữ phiên bản lúc đặt.”; phiên bản 2 “Đang dùng”; trang khách tour 7 hiện chính sách mới; trang đổi / hủy của Đ6 vẫn ghi “Hủy miễn phí trước giờ khởi hành 24 giờ.”, “Sau thời điểm này hoàn 50% tiền tour.”, “Phiên bản 1, áp dụng từ lúc đặt.”. Lần 2: “Không có thay đổi nào.”. | Must |
| TC-LT-103 | US07-S5-01 | biên | Tour 12, chính sách hủy: giờ 721, 101%, nội dung trống; rồi 720 giờ, 100%; rồi giờ để trống, 0%. | Lần 1: “Số giờ từ 0 đến 720. Để trống nếu không có mốc hủy miễn phí.”, “Phần trăm hoàn từ 0 đến 100.”, “Vui lòng nhập nội dung chính sách cho khách.”; 720 / 100 lưu được; giờ trống + 0%: lưu được, hiện “Tour không hoàn tiền khi hủy.”. | Should |
| TC-LT-104 | US07-S5-01 | thường | Tour 12, mục “Xóa tour”: bấm “Xóa tour” khi chưa đánh dấu ô; rồi đánh dấu “Tôi hiểu tour sẽ bị xóa hoặc ngừng hiển thị với khách.” → “Xóa tour”. | Chưa đánh dấu: trình duyệt bắt đánh dấu ô, không xóa. Đánh dấu: về danh sách tour (tab “Tất cả”) với “Đã xóa tour.”; tour 12 không còn. | Must |
| TC-LT-105 | US07-S5-01 | thường | Xóa tour 8; khách mở `/tours/{tour 8}`; QTV “Hiển thị lại” → “Phê duyệt tour”. | “Tour đã có đơn nên được chuyển sang "Ngừng hiển thị" (không xóa để giữ lịch sử đơn).”; tour 8 ở tab “Ngừng hiển thị”; khách nhận “Không tìm thấy tour” (404), `/tours` không có tour 8. “Tour đã chuyển về "Chờ duyệt". Phê duyệt lại để hiển thị cho khách.”; phê duyệt: “Đã phê duyệt tour.”, tour 8 hiện lại. | Must |
| TC-LT-106 | US07-S5-01 | lỗi | Xóa tour 1 (đánh dấu ô xác nhận). | “Không xóa được: tour còn N đơn đang chờ xác nhận, chờ thanh toán hoặc đã xác nhận. Hãy xử lý hoặc hủy các đơn này ở trang "Yêu cầu đặt tour" trước.” (N ≥ 2); tour 1 vẫn hiển thị. | Must |
| TC-LT-107 | US07-S5-01 | thường | “Đơn vị tổ chức” → “Thêm đơn vị” (email giả, không ghi vào tài liệu) → mở sửa → “Xóa đơn vị”, đánh dấu “Tôi hiểu đơn vị sẽ bị xóa hẳn.”. | “Đã thêm đơn vị tổ chức.”; khung “Xóa đơn vị”: “Đơn vị chưa có tour nào. Xóa sẽ xóa hẳn đơn vị và tài khoản không đăng nhập đi kèm; lịch sử thao tác vẫn được giữ.”; xóa: “Đã xóa đơn vị tổ chức.”, đơn vị không còn trong danh sách. | Must |
| TC-LT-108 | US07-S5-01 | lỗi | Mở sửa đơn vị “Hà Nội Local”. | Khung “Xóa đơn vị”: “Đơn vị còn 2 tour nên không xóa được (đơn cũ cần giữ thông tin đơn vị). Muốn ẩn mọi tour của đơn vị khỏi trang khách, chọn “Ngừng hợp tác” rồi lưu.”; không có nút xóa. | Must |

### 7.5. Phân quyền và dữ liệu nhập (Phong + Thức + Khôi)

| ID | Story/WBS | Loại | Bước chính | Kết quả mong đợi | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| TC-LT-109 | US14-S5-02, US07-S5-01 | quyền | Chưa đăng nhập, mở `/bookings/{mã Đ1}/change`, `/admin/change-requests`, `/admin/tours/{tour 3}/packages`. | Trang khách chuyển tới `/login?next=…` (đăng nhập xong về đúng trang); trang quản trị chuyển tới `/admin/login?next=…`. So sánh tour vẫn dùng được khi chưa đăng nhập (TC-LT-74). | Must |
| TC-LT-110 | US14-S5-03, US07-S5-01 | quyền | KH-A mở `/admin/change-requests`, `/admin/tours/{tour 1}/packages`, `/admin/tours/{tour 1}/content`; gửi POST tới một form quản trị (console DevTools). | Trang 403 “Bạn không có quyền truy cập trang này.”; POST cũng 403, dữ liệu không đổi. | Must |
| TC-LT-111 | US14-S5-02 | quyền | KH-B mở `/bookings/{mã Đ1}/change` của KH-A và gửi POST tới cùng đường dẫn. | 404 “Không tìm thấy đơn” – “Mã đơn không đúng hoặc đơn không thuộc tài khoản của bạn.”; không thấy chính sách, số tiền của đơn; không tạo yêu cầu. | Must |
| TC-LT-112 | Tất cả | lỗi | DevTools (Elements) xóa ô ẩn `_csrf` rồi gửi: form đổi / hủy (khách), “Thêm gói”, “Lưu kết quả” (xử lý yêu cầu), “Xóa tour”, “Xóa đơn vị”. | HTTP 403, form báo “Phiên làm việc đã hết hạn, vui lòng thử lại.”; không tạo / đổi / xóa dữ liệu. | Must |
| TC-LT-113 | US14, US07-S5-01 | lỗi | Mở `/admin/tours/abc/content`, `/admin/tours/abc/packages`, `/admin/change-requests/abc`; POST `/admin/providers/not-a-uuid/delete`; mở `/bookings/abc/change`, `/bookings/LT000000/change`. | Quản trị: trang 404 “Không tìm thấy trang”; khách: 404 “Không tìm thấy đơn”; không lỗi PHP. | Must |
| TC-LT-114 | US06-S5-01, US07-S5-01 | lỗi | Bỏ `maxlength` hoặc đổi kiểu ô rồi gửi: tên gói 101 ký tự, mô tả gói 501, mô tả ảnh 256, nội dung lịch trình trống / 256, giờ `25:00`, thứ tự 1000, tên dịch vụ trống / 151, nội dung chính sách 2001. | HTTP 422, lỗi theo ô: “Tên gói tối đa 100 ký tự.”, “Mô tả tối đa 500 ký tự.”, “Mô tả ảnh tối đa 255 ký tự.”, “Vui lòng nhập nội dung mục lịch trình.” / “Nội dung tối đa 255 ký tự.”, “Giờ theo dạng HH:MM, ví dụ 08:30. Để trống nếu mục không ghi giờ.”, “Thứ tự từ 0 đến 999.”, “Vui lòng nhập tên dịch vụ.” / “Tên dịch vụ tối đa 150 ký tự.”, “Nội dung chính sách tối đa 2000 ký tự.”; không lưu. | Must |

### 7.6. Hồi quy Sprint 4 (11–12/11)

| ID | Story/WBS | Loại | Bước chính | Kết quả mong đợi | Ưu tiên |
| --- | --- | --- | --- | --- | --- |
| TC-LT-115 | Nhóm “Đặt tour” (TC-LT-35–46) | hồi quy | KH-A đặt tour 1 (không có gói) theo Bước 8 của `src/README.md`: 2 người lớn + 1 trẻ em, tích “Thêm phần chè cuối tour”. QTV mở trang đặt tour 1. | Không có ô chọn gói; tạm tính 1.760.000đ, tùy chọn cộng 105.000đ; đơn “Chờ xác nhận”. QTV: 403 “Tài khoản này không đặt tour được”. | Must |
| TC-LT-116 | Nhóm “Quản trị yêu cầu và Đơn của tôi” (TC-22, TC-LT-47–50) và “Thanh toán và voucher” (TC-LT-51–60) | hồi quy | QTV “Xác nhận chỗ và giá” đơn của TC-LT-115 → KH-A “Thanh toán ngay” → VietQR “Tôi đã chuyển khoản” → QTV “Đã nhận tiền” (VNPay sandbox nếu có khóa). | “Chờ thanh toán”, lịch giảm đúng 3 chỗ; sau đối chiếu “Đã xác nhận”, có “Xem và in voucher”; “Lịch sử đơn” ghi đủ các bước. | Must |
| TC-LT-117 | Nhóm “Quản trị đơn vị, tour và lịch khởi hành” (TC-LT-61–66) | hồi quy | Thêm tour mới, thêm lịch; chuyển một đơn vị sang “Ngừng hợp tác” rồi trả lại. | Tour mới “Chờ duyệt”; lịch mới mở bán; tour của đơn vị ngừng hợp tác bị ẩn ở trang khách, trả lại thì hiện. | Should |
| TC-LT-118 | Sprint 3 và nhóm “Phân quyền, bảo mật, lỗi và giao diện” (TC-LT-67–73) | hồi quy | Chạy bảng Bước 5 của `src/README.md`; ở 390 px mở `/tours`, `/compare?ids={tour 1},{tour 3}`, trang đặt tour, trang đơn, trang “Đổi ngày / hủy tour”. | `/tours` có 9 tour (sau TC-LT-105), tour 10 → 404; ở 390 px không trang nào cuộn ngang, chỉ bảng so sánh cuộn ngang trong khung riêng; thanh so sánh “2/3 tour đang so sánh”. | Must |

## 8. RTM và độ bao phủ

| Story | FR | WBS | Test case | Bao phủ |
| --- | --- | --- | --- | --- |
| US04 | FR-15 | US04-S5-01 UI chọn / bỏ, tối đa 3 | TC-LT-74, 75, 118 | thường, biên, giao diện 390 px |
| US04 | FR-15 | US04-S5-02 chuẩn hóa dữ liệu, thiếu ghi “Chưa cập nhật” | TC-LT-76, 77 | thường, biên |
| US04 | FR-15 | US04-S5-03 tích hợp, chặn > 3, dữ liệu thiếu / khác đơn vị | TC-LT-76, 78, 79 | thường, lỗi, API |
| US14 | FR-12 | US14-S5-01 form theo chính sách của đúng tour, thông báo lỗi | TC-LT-86, 87, 88 | thường, biên, lỗi |
| US14 | FR-12 | US14-S5-02 kiểm tra quyền / chính sách / trạng thái, lưu yêu cầu và lịch sử, chưa tự động hoàn tiền | TC-LT-89, 90, 93, 109, 111, 112 | thường, lỗi, quyền |
| US14 | FR-12 | US14-S5-03 quản trị viên xử lý thủ công, lịch sử / trạng thái | TC-LT-91–97, 110, 112, 113 | thường, biên, lỗi, quyền |
| US06 | FR-07 | US06-S5-01 gói tour khi đặt tour | TC-LT-80–85, 114, 115 | thường, biên, lỗi, hồi quy tour không gói |
| US07 | FR-13 | US07-S5-01 ảnh, lịch trình, dịch vụ, chính sách hủy, xóa / ngừng hiển thị / khôi phục tour, xóa đơn vị | TC-LT-98–108, 110, 112–114 | thường, biên, lỗi, quyền |
| Hồi quy Sprint 4 | FR-08, FR-09, FR-11, FR-14, FR-17, FR-24 | Bộ test case Sprint 4 (TC-LT-35–73) | TC-LT-115–118 | hồi quy |

Độ bao phủ: 8/8 WBS của 4 story có ít nhất một ca thường và một ca lỗi hoặc biên; 4 story có ca phân quyền hoặc CSRF; 45 ca (40 Must, 5 Should).

## 9. Báo cáo System Test Exit (điền ngày 12/11)

| Nhóm | Số ca | Pass | Fail | Blocked | Ghi chú |
| --- | --- | --- | --- | --- | --- |
| US04 – So sánh tour (TC-LT-74–79) | 6 | | | | |
| US06 – Gói tour (TC-LT-80–85) | 6 | | | | |
| US14 – Đổi ngày / hủy tour (TC-LT-86–97) | 12 | | | | |
| US07 – Quản trị tour (TC-LT-98–108) | 11 | | | | |
| Phân quyền và dữ liệu nhập (TC-LT-109–114) | 6 | | | | |
| Hồi quy Sprint 4 (TC-LT-115–118) | 4 | | | | |
| **Tổng** | **45** | | | | |

| Mục | Kết quả |
| --- | --- |
| Mã commit đã kiểm thử | |
| Ca Must chưa chạy / lý do | |
| Lỗi mở theo mức (Critical / High / Medium / Low) | __ / __ / __ / __ |
| Lỗi đã đóng (mã DEF, commit sửa) | |
| Carryover sang Sprint 6 | |
| Quyết định Go / No-go | ☐ Go ☐ No-go – lý do: |
| Bằng chứng | Biên bản kết quả kiểm thử, defect log, `MinhChung_KiemThu_Sprint5/` |
| Người ký | QA: Hồ Duy Hải ……… · Đỗ Sơn Thành ……… · Đại diện nhóm ……… · Ngày …/11/2026 |
