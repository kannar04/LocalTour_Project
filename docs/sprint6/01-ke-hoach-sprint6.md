# Kế hoạch Sprint 6

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 6 – Chuẩn bị demo, hướng dẫn và nghiệm thu UAT (13/11 – 19/11/2026) |
| Milestone | Milestone 3 – Nghiệm thu, bàn giao và kết thúc dự án (Sprint 6–7, 13/11 – 26/11/2026) |
| WBS | 6.1 → 6.7 (Gantt); 6.8 → 6.11 (bổ sung theo CR2) |
| Người tham gia | Lê Trung Phong (PM), Nguyễn Tuấn Khôi, Nguyễn Minh Thức (phát triển); Hồ Duy Hải, Đỗ Sơn Thành (QA / Documentation); nhóm PCG (người dùng chạy UAT) |
| Căn cứ | Gantt chart QLDA_LocalTour (Sprint 6); Yêu cầu thay đổi CR2 (12/11/2026); Báo cáo tổng hợp Sprint 5 (mục 1, 3, 8.1, 8.2); Product Backlog (USECASEPLAN, 24 User Story và US-25 → US-29 bổ sung theo CR2); `src/README.md` |
| Tài liệu liên quan | [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md), [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), [04 – Kế hoạch và checklist UAT](04-uat-checklist.md), [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md) |
| Trạng thái | Bản nháp; nhóm rà soát và chốt ngày 13/11/2026. UAT do nhóm PCG chạy ngày 16/11/2026 (mục 3). |

## 1. Mục tiêu Sprint 6

Sprint Goal: “Có bản demo cài được trên máy khác theo Installation Guide, có User Guide cho các tác vụ đặt tour và quản trị cốt lõi; chạy UAT theo checklist, sửa lỗi chặn và chốt nghiệm thu demo ngày 19/11.”

Ngoài các việc theo Gantt, Sprint 6 nhận yêu cầu thay đổi CR2: tài khoản đơn vị tổ chức (FR-26 → FR-28), đặt tour không chờ quản trị viên xác nhận chỗ (điều chỉnh FR-08, FR-11, FR-17, FR-25), phí dịch vụ, chi trả cho đơn vị tổ chức và thông số vận hành (FR-29, FR-30). Phần này làm ở 6.8 → 6.11 và phải xong trước khi đóng gói demo (6.3). Sau đó mã nguồn chỉ thay đổi khi có lỗi chặn UAT (6.6) hoặc lỗi cài đặt phát hiện ở 6.4.

## 2. Đầu vào từ Sprint 5

Theo Báo cáo tổng hợp Sprint 5:

| Mục | Kết quả cuối Sprint 5 |
| --- | --- |
| Product Backlog | 24/24 User Story hoàn thành. |
| Task | 16/16 task hoàn thành. |
| Kiểm thử hệ thống | E2E ngày 10/11/2026: 45/45 ca, 43 Pass, 2 Fail (DEF-12, DEF-13, mức Thấp). Sửa ngày 10/11, retest Pass ngày 11/11; hồi quy TC-LT-115–118 4/4, lượt Edge 6/6, demo D1–D10 10/10. |
| System Test Exit | 0 lỗi mở; QA đề xuất Go, chờ nhóm ký. |
| Staging (5.14) | Hướng dẫn cài đặt trong `src/README.md`, cấu hình mẫu `src/.env.example`, database mẫu `src/database/db_localtour.sql` (31 bảng, 92 procedure). |

Việc chuyển sang Sprint 6 (Bảng 8.1 của báo cáo):

| Việc | Yêu cầu | Task Sprint 6 |
| --- | --- | --- |
| Ghi giới hạn IPN khi chạy ở máy cục bộ và cách thử bằng URL có chữ ký | US-10 (I03) | 6.1 |
| Cài lịch tự hủy đơn quá hạn trên máy demo (`src/scripts/register_expire_task.bat`) | US-13 (I05) | 6.1, 6.3 |
| Chép ảnh tour đã tải lên cùng database khi đóng gói | US-07 (I12) | 6.3, 6.4 |

Giữ ở Product Backlog, không làm trong Sprint 6: hoàn tiền tự động; đổi số người, đổi gói khi đổi ngày; phần thêm của trang so sánh (tổng cho N người, “Chỉ xem điểm khác nhau”, “Chọn tour này”, lưu danh sách theo tài khoản); khách gửi đánh giá tour (FR-16); nhãn “Thông tin chưa được xác minh” trên trang khách (NFR-07); Thích, Bình luận, Chia sẻ, Lưu tour.

## 3. Công việc

| WBS | Công việc | Đầu ra | Người làm | Ngày | Definition of Done |
| --- | --- | --- | --- | --- | --- |
| 6.1 | Installation Guide: hướng dẫn cấu hình và chạy chương trình (gồm I03, I05) | [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md) | Hải, Thành | 13–14/11 | Người chưa cài LocalTour làm theo được từ máy chưa có dự án tới trang `/tours` hiện 9 tour và đăng nhập được trang quản trị. Có: phiên bản XAMPP / PHP cần dùng, tạo database, file `.env`, tạo tài khoản quản trị, bước kiểm tra cài đặt, giới hạn IPN khi chạy ở máy cục bộ (I03), cài lịch tự hủy đơn (I05), chép ảnh tải lên (I12), bảng lỗi thường gặp. Không chứa khóa hay số tài khoản thật. |
| 6.2 | User Guide đặt tour: hướng dẫn người dùng các tác vụ cốt lõi | [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md) | Hải, Thành | 13–14/11 | Đủ tác vụ của khách hàng (xem, tìm, so sánh, đặt tour, thanh toán, theo dõi đơn, voucher, đổi ngày / hủy), quản trị viên (đơn đặt tour, đối chiếu thanh toán, tour và duyệt tour, đơn vị tổ chức, đổi / hủy, chi trả, thông số vận hành, thống kê) và đơn vị tổ chức (đăng nhập, tạo tour và gửi duyệt, lịch khởi hành, xem đơn đặt tour, tài khoản nhận tiền, khoản chi trả). Tên nút và nhãn khớp giao diện bản demo. Ảnh chỉ dùng dữ liệu thử, không có thông tin tài khoản nhận tiền. |
| 6.3 | Đóng gói demo: bản chạy, cấu hình và dữ liệu an toàn (gồm I12) | Gói demo; script `src/scripts/install_database.php`, `src/scripts/create_admin.php`, `src/scripts/check_install.php` | Phong, Thức, Khôi | 14–15/11 | Gói có mã nguồn ở một commit đã ghi lại, database mẫu, thư mục ảnh tải lên (`src/public/assets/uploads/tours/`), script cài đặt và `register_expire_task.bat`. Gói không có `.env`, khóa VNPay, số tài khoản nhận tiền, log hay dữ liệu thật. Cài lại trên máy của nhóm theo 02 thành công. |
| 6.4 | Thử cài trên máy khác: kiểm tra cài đặt và lỗi môi trường | [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md) | Phong, Thức, Khôi | 15–16/11 | Cài từ gói 6.3 trên ít nhất một máy chưa từng chạy LocalTour, chỉ theo 02 (15/11). Máy UAT do nhóm PCG tự cài tại máy của nhóm theo 02 (sáng 16/11), khóa thanh toán nhóm gửi riêng. Biên bản ghi máy, phiên bản Windows / XAMPP / PHP, các bước, lỗi gặp và cách sửa. Lỗi do hướng dẫn thì sửa 02; lỗi do mã nguồn thì sửa và cập nhật gói. Máy này dùng được cho UAT. |
| 6.5 | Thực hiện UAT: kiểm tra nghiệm thu theo checklist, ghi biên bản | [04 – Kế hoạch và checklist UAT](04-uat-checklist.md) (mục 6, 8) | Nhóm PCG chạy ca; Hải, Thành điều phối | 16/11 | Chạy hết ca UAT-01 → UAT-54 trong ngày 16/11 trên máy cài ở 6.4; mỗi ca có kết quả và minh chứng; lỗi ghi vào defect log có mức độ; biên bản UAT có chữ ký. |
| 6.6 | Sửa lỗi chặn UAT: sửa lỗi kỹ thuật theo phản hồi | Commit sửa lỗi, gói demo cập nhật | Phong, Thức, Khôi | 17–18/11 | Lỗi Critical / High từ UAT được sửa ngày 17/11, gắn mã commit; ca liên quan chạy lại Đạt trên gói đã cập nhật ngày 18/11. Lỗi Medium / Low có hướng xử lý (sửa hoặc chuyển Sprint 7). |
| 6.7 | Tổng hợp nghiệm thu demo: đối chiếu kết quả, chốt điểm còn thiếu | [04 – Kế hoạch và checklist UAT](04-uat-checklist.md) (mục 9) | Hải, Thành | 19/11 | Bảng tổng hợp theo User Story đã điền; lỗi còn mở và điểm còn thiếu có người phụ trách; quyết định Go / No-go có chữ ký; danh sách chuyển Sprint 7. |
| 6.8 | Tài khoản và khu đơn vị tổ chức (CR2: FR-26, FR-27, FR-28) | Khu `/host`: đăng nhập, tour của tôi, gửi duyệt, bản sửa của tour đã duyệt, lịch khởi hành, đơn đặt tour; trang “Đơn vị tổ chức” cấp mật khẩu; file `27`, `31`, `32` trong `src/database/` | Phong, Thức, Khôi | 13–16/11 | Quản trị viên cấp mật khẩu thì đơn vị đăng nhập được ở `/host/login`; đơn vị không tự đăng ký. Tour mới của đơn vị ở “Nháp”, gửi duyệt thì bị khóa tới khi quản trị viên phê duyệt hoặc từ chối kèm lý do; tour bị từ chối sửa và gửi lại được; tour đã duyệt sửa qua bản sửa, khách vẫn thấy nội dung cũ tới khi bản sửa được duyệt. Đơn vị chỉ mở được tour và đơn đặt tour của chính mình (của đơn vị khác → 404), đơn đặt tour chỉ xem. |
| 6.9 | Đặt tour không chờ xác nhận chỗ (CR2: FR-08, FR-11, FR-17, FR-25) | Trang đặt tour, trang thanh toán, “Đơn của tôi”, trang đơn đặt tour của quản trị viên; file `28`, `29` | Phong, Thức, Khôi | 13–16/11 | Đơn hợp lệ được giữ chỗ ngay và ở “Chờ thanh toán”; quá thời gian giữ chỗ (mặc định 30 phút) chưa thanh toán thì đơn tự hủy và trả chỗ. Ngừng nhận đặt trước giờ khởi hành 60 phút; còn dưới 24 giờ tới giờ khởi hành thì không nhận chuyển khoản VietQR. Đơn đã xác nhận tự chuyển “Đã hoàn thành” khi lịch khởi hành kết thúc. |
| 6.10 | Phí dịch vụ, chi trả cho đơn vị tổ chức và thông số vận hành (CR2: FR-29, FR-30) | Trang “Chi trả đơn vị tổ chức”, “Thông số vận hành” của quản trị viên; “Doanh thu & chi trả”, “Tài khoản nhận tiền” của đơn vị; file `28`, `30`, `31` | Phong, Thức, Khôi | 13–16/11 | Mỗi lịch khởi hành đã kết thúc có một khoản chi trả: thực nhận = tiền thực thu − phí dịch vụ (tỷ lệ lưu theo từng đơn lúc đặt). Quản trị viên chỉ ghi “Đã chi trả” được khi tài khoản nhận tiền của đơn vị đã xác minh và có mã giao dịch; đơn vị đổi tài khoản thì phải xác minh lại. Khoản hoàn tiền phải được ghi “Đã hoàn tiền” trước khi lịch được lập khoản chi trả. Quản trị viên chỉnh được bốn thông số vận hành. |
| 6.11 | Cập nhật tài liệu theo CR2 | SRS v1.1; sơ đồ Use Case, BPMN đặt tour và phê duyệt tour; ERD, wireframe; Product Backlog; [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), [04 – Kế hoạch và checklist UAT](04-uat-checklist.md) | Hải, Thành (tài liệu); Thức (ERD, wireframe) | 13–16/11 | SRS có FR-26 → FR-30 và các yêu cầu, quy tắc, Use Case đã điều chỉnh theo CR2; sơ đồ khớp với luồng đã triển khai; ERD có các bảng và cột mới; 03 và 04 có phần của đơn vị tổ chức, chi trả và luồng đặt tour mới. |

Thứ tự: 6.8 → 6.10 xong trước khi đóng gói 6.3; 6.11 song song với 6.1, 6.2; 6.4 dùng gói 6.3 và 02; 6.5 dùng máy đã cài ở 6.4; 6.6 chạy 17–18/11 theo lỗi báo từ 6.5.

## 4. Sản phẩm bàn giao

| Sản phẩm | Task | Phụ trách |
| --- | --- | --- |
| [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md) | 6.1 | Hải, Thành |
| [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md) và ảnh trong `images/` | 6.2 | Hải, Thành |
| Gói demo và script `install_database.php`, `create_admin.php`, `check_install.php` (thư mục `src/scripts/`) | 6.3 | Phong, Thức, Khôi |
| [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md) | 6.4 | Phong, Thức, Khôi |
| [04 – Kế hoạch, checklist và biên bản UAT](04-uat-checklist.md), defect log, thư mục minh chứng `MinhChung_UAT_Sprint6/` | 6.5 | Hải, Thành; nhóm PCG chạy ca |
| Commit sửa lỗi chặn UAT, gói demo cập nhật | 6.6 | Phong, Thức, Khôi |
| Bảng tổng hợp nghiệm thu demo (mục 9 của 04) | 6.7 | Hải, Thành |
| Mã nguồn và database của CR2: khu đơn vị tổ chức, đặt tour không chờ xác nhận chỗ, chi trả, thông số vận hành (file `27` → `32` trong `src/database/`) | 6.8, 6.9, 6.10 | Phong, Thức, Khôi |
| SRS v1.1, sơ đồ Use Case và BPMN, ERD, wireframe, Product Backlog đã cập nhật theo CR2 | 6.11 | Hải, Thành, Thức |

## 5. Môi trường demo và UAT

| Mục | Nội dung |
| --- | --- |
| Máy | Windows, XAMPP 8.2 (PHP 8.2, MariaDB 10.4); máy đã cài ở 6.4. |
| Mã nguồn | Gói demo 6.3 (hoặc gói cập nhật sau 6.6); ghi mã commit vào biên bản. |
| Database | Database riêng trên máy demo, cài mới theo 02 ngay trước buổi UAT. Lịch khởi hành mẫu tính theo ngày import, khoảng 30 ngày sau sẽ thành lịch đã qua. Không dùng database chung của nhóm qua Radmin VPN: UAT làm đổi dữ liệu (xác nhận, hủy, xóa). |
| Tài khoản | Quản trị viên tạo bằng `create_admin.php` theo 02. Khách hàng tự đăng ký ở `/register` (email `…@localtour.test`). Đơn vị tổ chức đăng nhập ở `/host/login` sau khi quản trị viên cấp mật khẩu ở trang “Đơn vị tổ chức”. Tài khoản mẫu trong database không có mật khẩu nên không đăng nhập được. Không ghi mật khẩu vào tài liệu. |
| Thanh toán | VNPay sandbox và VietQR, khóa điền vào `.env` của máy demo (lấy trong nhóm, không gửi vào nhóm chat chung). Máy UAT của nhóm PCG: nhóm PCG tự cài và tự điền khóa từ file khóa nhóm gửi riêng (VNPay sandbox và một tài khoản VietQR thử nghiệm, không phải tài khoản thật); gói gửi nhóm PCG không có khóa. Thiếu khóa thì nút hiện “VNPay đang tạm ngưng” / “VietQR đang tạm ngưng”. Môi trường thử, không chuyển tiền thật. |
| Tự hủy đơn quá hạn, việc sau tour | Chạy `src/scripts/register_expire_task.bat` khi cài (Task Scheduler, 15 phút một lần): hủy đơn quá thời gian giữ chỗ, chuyển đơn của lịch đã kết thúc sang “Đã hoàn thành” và lập khoản chi trả. |
| Ảnh tour | Chép `src/public/assets/uploads/tours/` cùng database; ảnh thiếu file hiện ảnh thay thế. |
| Mạng | Cần Internet: Bootstrap, jQuery tải từ CDN jsDelivr; cổng VNPay sandbox. |
| Trình duyệt | Chrome bản mới, màn hình desktop. |

## 6. Rủi ro và cách xử lý

| Rủi ro | Ảnh hưởng | Cách xử lý | Task |
| --- | --- | --- | --- |
| Máy khác thiếu XAMPP hoặc khác phiên bản PHP, chưa bật driver PDO MySQL, cổng 80 / 3306 đã bị chương trình khác dùng | Không cài được, trang lỗi 500 / 503 | 02 ghi rõ phiên bản và bước bật driver; chạy `check_install.php` trước khi mở web; cổng 80 bận thì chạy PHP built-in server ở cổng khác như `src/README.md` Bước 4; lỗi gặp ghi vào 05 và bổ sung bảng lỗi của 02. | 6.1, 6.4 |
| VNPay sandbox không gọi được IPN khi chạy ở `localhost` (I03) | Kết quả chỉ ghi qua Return URL; khách đóng tab trước khi quay về thì khoản không có kết quả | Nhóm đã chấp nhận giới hạn này. 02 ghi rõ; sau 15 phút khoản hiện ở “Giao dịch VNPay chưa rõ kết quả”, quản trị viên đối chiếu tay. Luồng IPN đã thử bằng URL có chữ ký ở Sprint 4. | 6.1 |
| Cổng VNPay sandbox lỗi hoặc mạng yếu lúc demo / UAT | Không thanh toán VNPay được | Dùng VietQR + “Đối chiếu thanh toán” để có đơn đã thanh toán; ca VNPay chạy lại khi mạng ổn, ghi lý do vào Ghi chú. | 6.5 |
| Ảnh tải lên không có trong Git (I12) | Tour hiện ảnh thay thế thay cho ảnh thật | Chép thư mục `uploads/tours/` vào gói (6.3); 6.4 kiểm tra ảnh hiện đúng trên máy mới. | 6.3, 6.4 |
| Chưa cài lịch tự hủy (I05) | Đơn quá hạn chỉ tự hủy, đơn chỉ tự hoàn thành và khoản chi trả chỉ được lập khi có người mở trang | Chạy `register_expire_task.bat` khi cài; 05 ghi đã chạy. | 6.1, 6.3 |
| Lịch mẫu thành lịch đã qua | Không còn lịch để đặt tour | Cài lại database ngay trước UAT và trước buổi demo Sprint 7. | 6.5 |
| Lộ khóa VNPay hoặc số tài khoản nhận tiền | Lộ thông tin của nhóm | `.env` không vào gói và Git; khóa cho nhóm PCG gửi riêng, VietQR của máy UAT dùng tài khoản thử nghiệm; ảnh minh chứng che mã QR và số tài khoản; không chụp trang “Chuyển khoản VietQR”. | 6.2, 6.3, 6.5 |
| Không có Internet ở nơi demo | Mất giao diện (CDN) và VNPay | Kiểm tra mạng trước buổi demo, chuẩn bị mạng dự phòng (điện thoại phát Wi-Fi). | 6.4, 6.5 |
| Chỉ có ngày 17/11 để sửa lỗi chặn, 18/11 để chạy lại | Lỗi phát hiện muộn không kịp sửa trước 19/11 | Ngày 16/11 chạy trước các ca Must của luồng chính (đặt tour → thanh toán → voucher) và báo lỗi chặn ngay trong ngày; lỗi không chặn ghi cho Sprint 7. | 6.5, 6.6 |
| 54 ca UAT chạy trong một ngày | Không kịp chạy hết ca ngày 16/11 | Bắt đầu từ sáng; chạy các ca khác trong lúc chờ đơn hết giữ chỗ (UAT-25, UAT-26) và chờ lịch của UAT-51 kết thúc (UAT-52) theo mục 5 của 04; ca chưa chạy ghi lý do, chạy ngày 18/11. | 6.5 |

## 7. Sprint 7 nhận từ Sprint 6

- Gói demo đã thử cài trên máy khác, kèm mã commit (6.3, 6.4, 6.6).
- Installation Guide và User Guide đã sửa theo kết quả thử cài và UAT (6.1, 6.2).
- Biên bản UAT, defect log và bảng tổng hợp nghiệm thu demo với quyết định Go / No-go (6.5, 6.7).
- Danh sách lỗi còn mở và điểm còn thiếu, có người phụ trách và hướng xử lý.
- Các mục giữ ở Product Backlog (mục 2) không đổi.
