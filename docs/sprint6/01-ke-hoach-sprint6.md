# Kế hoạch Sprint 6

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 6 – Chuẩn bị demo, hướng dẫn và nghiệm thu UAT (13/11 – 19/11/2026) |
| Milestone | Milestone 3 – Nghiệm thu, bàn giao và kết thúc dự án (Sprint 6–7, 13/11 – 26/11/2026) |
| WBS | 6.1 → 6.7 (Gantt); 6.8 → 6.11 (đợt bổ sung CR2 ban đầu); 6.12 → 6.18 (đợt cập nhật mở rộng CR2) |
| Người tham gia | Lê Trung Phong (PM), Nguyễn Tuấn Khôi, Nguyễn Minh Thức (phát triển); Hồ Duy Hải, Đỗ Sơn Thành (QA / Documentation); nhóm PCG (người dùng chạy UAT) |
| Căn cứ | Gantt chart QLDA_LocalTour (Sprint 6); CR2 với đợt bổ sung ban đầu ngày 13/11/2026 và đợt cập nhật mở rộng ngày 15/11/2026; Báo cáo tổng hợp Sprint 5 (mục 1, 3, 8.1, 8.2); Product Backlog (USECASEPLAN, 24 User Story ban đầu, US-25 → US-39 bổ sung theo CR2); `src/README.md` |
| Tài liệu liên quan | [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md), [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), [04 – Kế hoạch và checklist UAT](04-uat-checklist.md), [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md) |
| Trạng thái | Bản kế hoạch đã cập nhật theo hai đợt của CR2. Task 6.4 đã hoàn thành theo xác nhận của Project Manager. UAT chính thức được lên lịch cho nhóm PCG; repository chưa có kết quả từng ca hoặc biên bản xác nhận hoàn tất. |

## 1. Mục tiêu Sprint 6

Sprint Goal: “Có bản demo cài được trên máy khác theo Installation Guide, có User Guide cho các tác vụ đặt tour và quản trị cốt lõi; chạy UAT theo checklist, sửa lỗi chặn và chốt nghiệm thu demo ngày 19/11.”

Đợt bổ sung CR2 ban đầu gồm tài khoản đơn vị tổ chức (FR-26 → FR-28), đặt tour không chờ quản trị viên xác nhận chỗ (điều chỉnh FR-08, FR-11, FR-17, FR-25), phí dịch vụ, chi trả cho đơn vị tổ chức và thông số vận hành (FR-29, FR-30). Phần này làm ở 6.8 → 6.11 và phải xong trước khi đóng gói demo (6.3). Sau đó mã nguồn chỉ thay đổi khi có lỗi chặn UAT (6.6) hoặc lỗi cài đặt phát hiện ở 6.4.

Đợt cập nhật mở rộng CR2 ngày 15/11/2026 hoàn thiện các nút còn nhãn “Sắp có” trên trang khách (lọc theo ngày đi và bộ lọc nâng cao, điều chỉnh FR-06; thích, lưu, chia sẻ tour và trang “Tour đã lưu”, FR-31 → FR-33; bình luận, FR-34; trang Trợ giúp và Điều khoản sử dụng, FR-36; nút Menu trên máy tính), cùng với đánh giá sao sau chuyến đi (FR-16) và trang tài khoản cá nhân (FR-35). Đây là phần tiếp theo của cùng CR2, thực hiện ở 6.12 → 6.18 và cập nhật lên trang demo trước buổi UAT dự kiến ngày 16/11.

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

Giữ ở Product Backlog, không làm trong Sprint 6: hoàn tiền tự động; đổi số người, đổi gói khi đổi ngày; phần thêm của trang so sánh (tổng cho N người, “Chỉ xem điểm khác nhau”, “Chọn tour này”, lưu danh sách theo tài khoản); nhãn “Thông tin chưa được xác minh” trên trang khách (NFR-07). Khách gửi đánh giá tour (FR-16) và Thích, Bình luận, Chia sẻ, Lưu tour chuyển vào Sprint 6 theo CR2 (6.12 → 6.17).

## 3. Công việc

| WBS | Công việc | Đầu ra | Người làm | Ngày | Definition of Done |
| --- | --- | --- | --- | --- | --- |
| 6.1 | Installation Guide: hướng dẫn cấu hình và chạy chương trình (gồm I03, I05) | [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md) | Hải, Thành | 13–14/11 | Người chưa cài LocalTour làm theo được từ máy chưa có dự án tới trang `/tours` hiện 29 tour và đăng nhập được trang quản trị. Có: phiên bản XAMPP / PHP cần dùng, tạo database, file `.env`, tạo tài khoản quản trị, bước kiểm tra cài đặt, giới hạn IPN khi chạy ở máy cục bộ (I03), cài lịch tự hủy đơn (I05), chép ảnh tải lên (I12), bảng lỗi thường gặp. Không chứa khóa hay số tài khoản thật. |
| 6.2 | User Guide đặt tour: hướng dẫn người dùng các tác vụ cốt lõi | [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md) | Hải, Thành | 13–14/11 | Đủ tác vụ của khách hàng (xem, tìm, so sánh, đặt tour, thanh toán, theo dõi đơn, voucher, đổi ngày / hủy), quản trị viên (đơn đặt tour, đối chiếu thanh toán, tour và duyệt tour, đơn vị tổ chức, đổi / hủy, chi trả, thông số vận hành, thống kê) và đơn vị tổ chức (đăng nhập, tạo tour và gửi duyệt, lịch khởi hành, xem đơn đặt tour, tài khoản nhận tiền, khoản chi trả). Tên nút và nhãn khớp giao diện bản demo. Ảnh chỉ dùng dữ liệu thử, không có thông tin tài khoản nhận tiền. |
| 6.3 | Đóng gói demo: bản chạy, cấu hình và dữ liệu an toàn (gồm I12) | Gói demo; script `src/scripts/install_database.php`, `src/scripts/create_admin.php`, `src/scripts/check_install.php` | Phong, Thức, Khôi | 14–15/11 | Gói có mã nguồn ở một commit đã ghi lại, database mẫu, thư mục ảnh tải lên (`src/public/assets/uploads/tours/`), script cài đặt và `register_expire_task.bat`. Gói không có `.env`, khóa VNPay, số tài khoản nhận tiền, log hay dữ liệu thật. Cài lại trên máy của nhóm theo 02 thành công. |
| 6.4 | Thử cài trên máy khác: kiểm tra cài đặt và lỗi môi trường — **Hoàn thành theo xác nhận của Project Manager** | [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md) | Phong, Thức, Khôi | 15–16/11 | Đã thực hiện cài từ gói 6.3 trên máy Windows khác theo 02. Không bổ sung hồi tố tên máy, phiên bản Windows/XAMPP/PHP, người thử hoặc chữ ký khi repository chưa có dữ liệu đó. Bản UAT được cài trên trang demo; nhóm PCG chỉ dùng trình duyệt. |
| 6.5 | Thực hiện UAT: kiểm tra nghiệm thu theo checklist, ghi biên bản | [04 – Kế hoạch và checklist UAT](04-uat-checklist.md) (mục 6, 8) | Nhóm PCG chạy ca; Hải, Thành điều phối | 16/11 | Chạy hết ca UAT-01 → UAT-64 trong ngày 16/11 trên trang demo; mỗi ca có kết quả và minh chứng; lỗi ghi vào defect log có mức độ; biên bản UAT có chữ ký. |
| 6.6 | Sửa lỗi chặn UAT: sửa lỗi kỹ thuật theo phản hồi | Commit sửa lỗi, trang demo cập nhật | Phong, Thức, Khôi | 17–18/11 | Lỗi Critical / High từ UAT được sửa ngày 17/11, gắn mã commit; ca liên quan chạy lại Đạt trên trang demo đã cập nhật ngày 18/11. Lỗi Medium / Low có hướng xử lý (sửa hoặc chuyển Sprint 7). |
| 6.7 | Tổng hợp nghiệm thu demo: đối chiếu kết quả, chốt điểm còn thiếu | [04 – Kế hoạch và checklist UAT](04-uat-checklist.md) (mục 9) | Hải, Thành | 19/11 | Bảng tổng hợp theo User Story đã điền; lỗi còn mở và điểm còn thiếu có người phụ trách; quyết định Go / No-go có chữ ký; danh sách chuyển Sprint 7. |
| 6.8 | Tài khoản và khu đơn vị tổ chức (CR2: FR-26, FR-27, FR-28) | Khu `/host`: đăng nhập, tour của tôi, gửi duyệt, bản sửa của tour đã duyệt, lịch khởi hành, đơn đặt tour; trang “Đơn vị tổ chức” cấp mật khẩu; file `27`, `31`, `32` trong `src/database/` | Phong, Thức, Khôi | 13–16/11 | Quản trị viên cấp mật khẩu thì đơn vị đăng nhập được ở `/host/login`; đơn vị không tự đăng ký. Tour mới của đơn vị ở “Nháp”, gửi duyệt thì bị khóa tới khi quản trị viên phê duyệt hoặc từ chối kèm lý do; tour bị từ chối sửa và gửi lại được; tour đã duyệt sửa qua bản sửa, khách vẫn thấy nội dung cũ tới khi bản sửa được duyệt. Đơn vị chỉ mở được tour và đơn đặt tour của chính mình (của đơn vị khác → 404), đơn đặt tour chỉ xem. |
| 6.9 | Đặt tour không chờ xác nhận chỗ (CR2: FR-08, FR-11, FR-17, FR-25) | Trang đặt tour, trang thanh toán, “Đơn của tôi”, trang đơn đặt tour của quản trị viên; file `28`, `29` | Phong, Thức, Khôi | 13–16/11 | Đơn hợp lệ được giữ chỗ ngay và ở “Chờ thanh toán”; quá thời gian giữ chỗ (mặc định 30 phút) chưa thanh toán thì đơn tự hủy và trả chỗ. Ngừng nhận đặt trước giờ khởi hành 60 phút; còn dưới 24 giờ tới giờ khởi hành thì không nhận chuyển khoản VietQR. Đơn đã xác nhận tự chuyển “Đã hoàn thành” khi lịch khởi hành kết thúc. |
| 6.10 | Phí dịch vụ, chi trả cho đơn vị tổ chức và thông số vận hành (CR2: FR-29, FR-30) | Trang “Chi trả đơn vị tổ chức”, “Thông số vận hành” của quản trị viên; “Doanh thu & chi trả”, “Tài khoản nhận tiền” của đơn vị; file `28`, `30`, `31` | Phong, Thức, Khôi | 13–16/11 | Mỗi lịch khởi hành đã kết thúc có một khoản chi trả: thực nhận = tiền thực thu − phí dịch vụ (tỷ lệ lưu theo từng đơn lúc đặt). Quản trị viên chỉ ghi “Đã chi trả” được khi tài khoản nhận tiền của đơn vị đã xác minh và có mã giao dịch; đơn vị đổi tài khoản thì phải xác minh lại. Khoản hoàn tiền phải được ghi “Đã hoàn tiền” trước khi lịch được lập khoản chi trả. Quản trị viên chỉnh được bốn thông số vận hành. |
| 6.11 | Cập nhật tài liệu theo CR2 | SRS v1.1; sơ đồ Use Case, BPMN đặt tour và phê duyệt tour; ERD, wireframe; Product Backlog; [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), [04 – Kế hoạch và checklist UAT](04-uat-checklist.md) | Hải, Thành (tài liệu); Thức (ERD, wireframe) | 13–16/11 | SRS có FR-26 → FR-30 và các yêu cầu, quy tắc, Use Case đã điều chỉnh theo CR2; sơ đồ khớp với luồng đã triển khai; ERD có các bảng và cột mới; 03 và 04 có phần của đơn vị tổ chức, chi trả và luồng đặt tour mới. |
| 6.12 | Lọc tour theo ngày đi và bộ lọc nâng cao (CR2: FR-06) | Trang “Bảng tin” (`/tours`): ô “Ngày đi”, bảng “Bộ lọc”; file `03` (`LTP_sp_tour_list`); dữ liệu mẫu `41` | Phong, Thức | 15–16/11 | Chọn ngày đi thì chỉ còn tour có lịch nhận đặt trong ngày đó; lọc được theo khoảng giá, thời lượng, ngôn ngữ hướng dẫn, đón tại khách sạn và kết hợp với tìm kiếm, điểm đến, loại hình, sắp xếp; giá tối thiểu lớn hơn giá tối đa thì báo lỗi; bộ lọc giữ trên địa chỉ trang khi tải lại và khi bấm quay lại; “Xóa bộ lọc” đưa về danh sách đầy đủ; nút “Bộ lọc” hiện số bộ lọc đang chọn; dữ liệu mẫu `41` thêm 20 tour, trang “Bảng tin” có 29 tour ở 10 điểm đến. |
| 6.13 | Thích, lưu, chia sẻ tour và trang “Tour đã lưu” (CR2: FR-31, FR-32, FR-33) | Nút Thích, Lưu tour, Chia sẻ trên thẻ tour và trang chi tiết tour; trang “Tour đã lưu” (`/tour-da-luu`); file `34` | Thức | 15–16/11 | Khách hàng thích / bỏ thích, lưu / bỏ lưu được, số lượt thích cập nhật ngay; khách vãng lai bấm Thích hoặc Lưu tour thì được đưa tới trang đăng nhập rồi quay lại; tài khoản quản trị viên, đơn vị tổ chức không thích, lưu được; chỉ thích, lưu được tour đang hiển thị công khai; trang “Tour đã lưu” chỉ có tour của chính tài khoản và bỏ lưu được ngay trên trang, tour không còn hiển thị hiện mờ và chỉ còn nút “Bỏ lưu”; Chia sẻ mở bảng chia sẻ của thiết bị hoặc sao chép liên kết, không cần đăng nhập. |
| 6.14 | Bình luận và kiểm duyệt bình luận (CR2: FR-34) | Mục “Bình luận” ở trang chi tiết tour; trang “Bình luận” của quản trị viên (`/admin/comments`); file `35` | Thức | 15–16/11 | Mọi người đọc được bình luận; chỉ khách hàng viết được, 1–1000 ký tự, quá 5 bình luận trong 10 phút thì bị chặn; người viết xóa được bình luận của mình, không xóa được của người khác; quản trị viên ẩn kèm lý do và hiện lại được; bình luận bị ẩn biến mất khỏi trang tour và số bình luận giảm theo. |
| 6.15 | Đánh giá sao sau chuyến đi và duyệt đánh giá (CR2: FR-16) | Mục “Đánh giá tour” ở chi tiết đơn trong “Đơn của tôi”; trang “Duyệt đánh giá” của quản trị viên (`/admin/reviews`); file `33`, `36`; dữ liệu mẫu `38` | Khôi | 15–16/11 | Chỉ đơn “Đã hoàn thành” của chính khách mới đánh giá được, mỗi đơn một đánh giá (1–5 sao, nhận xét 10–1000 ký tự); đánh giá ở “Chờ duyệt” tới khi quản trị viên bấm “Duyệt” hoặc “Từ chối”; “Từ chối” và “Gỡ đánh giá” (với đánh giá đã duyệt) bắt buộc lý do, đưa đánh giá về “Không được duyệt”; khách thấy lý do, sửa và gửi lại thì đánh giá về “Chờ duyệt”; đánh giá “Đã duyệt” hiện ở trang tour, được tính vào điểm và số đánh giá, trang đơn hiện “Đã đăng” và khách không sửa được nữa. |
| 6.16 | Trang tài khoản cá nhân và ảnh đại diện (CR2: FR-35) | Trang “Tài khoản” (`/tai-khoan`); file `37`, `06`, `39` | Phong | 15–16/11 | Khách tải ảnh JPG / PNG / WebP tối đa 2 MB, cạnh 64–4096 px thì ảnh mới hiện ở trang tài khoản, ở đầu trang, cạnh bình luận và đánh giá; tệp sai loại (kể cả SVG), quá 2 MB hoặc ngoài 64–4096 px bị từ chối; đổi hoặc xóa ảnh thì tệp cũ bị xóa, xóa ảnh thì trở lại chữ cái đầu của tên; sửa được họ tên (2–100 ký tự), số điện thoại (không bắt buộc, 8–20 ký tự gồm chữ số, khoảng trắng, có thể bắt đầu bằng +); số CCCD (đúng 12 chữ số), ngày sinh (từ năm 1900, không ở tương lai, đủ 10 tuổi), giới tính (Nam, Nữ, Khác hoặc không nêu) và địa chỉ (tối đa 255 ký tự) không bắt buộc, ô nào sai thì báo lỗi dưới ô đó và không lưu gì; số CCCD chỉ chủ tài khoản xem được; đổi mật khẩu phải nhập đúng mật khẩu hiện tại (nếu tài khoản đã có mật khẩu), mật khẩu mới tối thiểu 8 ký tự, đổi xong đăng nhập lại bằng mật khẩu mới được; khách vãng lai mở `/tai-khoan` thì được đưa tới trang đăng nhập. |
| 6.17 | Trang Trợ giúp, Điều khoản sử dụng, nút Menu và thanh điều hướng (CR2: FR-36) | Trang “Trợ giúp” (`/tro-giup`), “Điều khoản sử dụng” (`/dieu-khoan`); nút “Menu” trên máy tính; ảnh đại diện ở đầu trang; thanh điều hướng có “Tour đã lưu”, “Tài khoản”, “Trợ giúp”, “Điều khoản” | Khôi | 15–16/11 | Hai trang mở được khi chưa đăng nhập, nội dung khớp quy tắc giữ chỗ, hạn đặt, thanh toán, hủy / hoàn tiền và nội dung người dùng trong SRS v1.2; nút “Menu” thu gọn / mở thanh điều hướng và giữ trạng thái khi tải lại; trang khách không còn nút mang nhãn “Sắp có”. |
| 6.18 | Cập nhật tài liệu theo CR2 | SRS v1.2; sơ đồ Use Case, phân rã chức năng, user flow; ERD, wireframe; Product Backlog (US-30 → US-39); [03 – Hướng dẫn sử dụng](03-huong-dan-su-dung.md), [04 – Kế hoạch và checklist UAT](04-uat-checklist.md); `src/README.md`, `src/database/README.md` | Hải, Thành (tài liệu); Thức (ERD, wireframe) | 15–16/11 | SRS có FR-31 → FR-36, FR-16 thuộc MVP và các quy tắc, Use Case mới theo CR2; sơ đồ Use Case có UC-08 → UC-10; ERD có bảng `tour_likes`, `tour_comments` và các cột mới; 03 có phần lọc tour, thích, lưu, chia sẻ, bình luận, đánh giá, tài khoản và phần quản trị viên duyệt đánh giá, bình luận; 04 bỏ dòng “Sắp có” và có ca cho các chức năng CR2. |

Thứ tự: 6.8 → 6.10 xong trước khi đóng gói 6.3; 6.11 song song với 6.1, 6.2; 6.4 dùng gói 6.3 và 02; 6.5 chạy trên trang demo; 6.6 chạy 17–18/11 theo lỗi báo từ 6.5. 6.12 → 6.17 (CR2) xong và được cập nhật lên trang demo trước buổi UAT ngày 16/11; 6.18 song song với 6.12 → 6.17.

User Story bổ sung theo CR2 (thêm vào Product Backlog – USECASEPLAN, tiếp sau US-29):

| Backlog ID | User Story | Priority | Requirement ID | Task |
| --- | --- | --- | --- | --- |
| US-30 | Là khách hàng, tôi muốn lọc tour theo ngày đi, khoảng giá, thời lượng, ngôn ngữ hướng dẫn và đón tại khách sạn để nhanh chóng tìm được tour hợp lịch và ngân sách. | Must | FR-06 | 6.12 |
| US-31 | Là khách hàng, tôi muốn thích tour để bày tỏ quan tâm và xem tour nào được nhiều người thích. | Must | FR-31 | 6.13 |
| US-32 | Là khách hàng, tôi muốn lưu tour và xem lại các tour đã lưu ở một trang riêng để quyết định sau. | Must | FR-32 | 6.13 |
| US-33 | Là khách, tôi muốn chia sẻ liên kết tour cho bạn đồng hành mà không cần đăng nhập. | Must | FR-33 | 6.13 |
| US-34 | Là khách hàng, tôi muốn bình luận trên trang tour để hỏi hoặc chia sẻ thông tin với người khác. | Must | FR-34 | 6.14 |
| US-35 | Là quản trị viên, tôi muốn ẩn bình luận vi phạm kèm lý do và hiện lại khi cần để giữ nội dung trang tour phù hợp. | Must | FR-34, NFR-09 | 6.14 |
| US-36 | Là khách hàng, tôi muốn chấm sao và viết nhận xét cho tour sau khi đơn của tôi đã hoàn thành để giúp người khác chọn tour. | Must | FR-16 | 6.15 |
| US-37 | Là quản trị viên, tôi muốn duyệt, từ chối hoặc gỡ đánh giá để chỉ công khai đánh giá hợp lệ. | Must | FR-16, NFR-09 | 6.15 |
| US-38 | Là khách hàng, tôi muốn cập nhật ảnh đại diện, họ tên, số điện thoại, số CCCD, ngày sinh, giới tính, địa chỉ và mật khẩu ở trang tài khoản. | Must | FR-35, NFR-04, NFR-05 | 6.16 |
| US-39 | Là khách, tôi muốn đọc trang Trợ giúp và Điều khoản sử dụng để hiểu cách đặt tour, thanh toán, hủy và quy định nội dung. | Must | FR-36, NFR-01 | 6.17 |

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
| Mã nguồn và database của CR2: lọc tour nâng cao, thích, lưu, chia sẻ, bình luận, đánh giá, tài khoản, Trợ giúp, Điều khoản (file `33` → `39`, `41` và thay đổi ở file `01`, `03`, `05`, `06`, `21` trong `src/database/`) | 6.12 → 6.17 | Phong, Thức, Khôi |
| SRS v1.2, sơ đồ Use Case, ERD, wireframe, Product Backlog (US-30 → US-39) đã cập nhật theo CR2 | 6.18 | Hải, Thành, Thức |

## 5. Môi trường demo và UAT

| Mục | Nội dung |
| --- | --- |
| Trang demo (UAT) | https://localtour.alwaysdata.net (PHP 8.2, MariaDB 11.8); nhóm PCG chỉ cần trình duyệt và Internet. |
| Máy demo của nhóm | Windows, XAMPP 8.2 (PHP 8.2, MariaDB 10.4); máy đã cài ở 6.4. |
| Mã nguồn | Bản demo 6.3 (hoặc bản cập nhật sau 6.6); ghi mã commit vào biên bản. |
| Database | Database riêng của trang demo, cài mới dữ liệu mẫu trước buổi UAT; từ đó tới hết UAT không ai khác thao tác trên trang. Bản CR2 nâng cấp database này tại chỗ (chỉ chạy `33`, `03`, `05`, `06`, `21`, `34` → `37`, `38`, `39`, `41`), không cài lại. Máy demo của nhóm: database riêng, cài mới theo 02 trước buổi demo. Lịch khởi hành mẫu tính theo ngày import, khoảng 30 ngày sau sẽ thành lịch đã qua. Không dùng database chung của nhóm qua Radmin VPN: UAT làm đổi dữ liệu (xác nhận, hủy, xóa). |
| Tài khoản | Quản trị viên tạo bằng `create_admin.php` trên máy chủ trang demo; email và mật khẩu gửi nhóm PCG trong file `GuiNhomPCG_DiaChi_TaiKhoan.txt`. Khách hàng tự đăng ký ở `/register` bằng email thật của người kiểm thử. Đơn vị tổ chức đăng nhập ở `/host/login` sau khi quản trị viên cấp mật khẩu ở trang “Đơn vị tổ chức”. Tài khoản mẫu trong database không có mật khẩu nên không đăng nhập được. Không ghi mật khẩu vào tài liệu. |
| Thanh toán | VNPay sandbox và VietQR, khóa điền vào `.env` của máy demo (lấy trong nhóm, không gửi vào nhóm chat chung). Trang demo: khóa điền trong `.env` trên máy chủ, VietQR dùng một tài khoản thử nghiệm (không phải tài khoản thật); nhóm PCG không nhận khóa. Thiếu khóa thì nút hiện “VNPay đang tạm ngưng” / “VietQR đang tạm ngưng”. Môi trường thử, không chuyển tiền thật. |
| Tự hủy đơn quá hạn, việc sau tour | Trang demo: tác vụ định kỳ của máy chủ chạy `src/scripts/expire_holds.php` 5 phút một lần. Máy demo của nhóm: chạy `src/scripts/register_expire_task.bat` khi cài (Task Scheduler, 15 phút một lần). Mỗi lần chạy: hủy đơn quá thời gian giữ chỗ, chuyển đơn của lịch đã kết thúc sang “Đã hoàn thành” và lập khoản chi trả. |
| Ảnh tải lên | Chép `src/public/assets/uploads/` (ảnh tour trong `tours/`, ảnh đại diện trong `avatars/` – CR2) cùng database; ảnh tour thiếu file hiện ảnh thay thế. |
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
| Lịch mẫu thành lịch đã qua | Không còn lịch để đặt tour | Cài mới dữ liệu mẫu trên trang demo trước UAT (bản CR2 nâng cấp database tại chỗ, không cài lại) và cài lại trước buổi demo Sprint 7. | 6.5 |
| Lộ khóa VNPay hoặc số tài khoản nhận tiền | Lộ thông tin của nhóm | `.env` không vào gói và Git; khóa chỉ nằm trên máy chủ trang demo, nhóm PCG không nhận khóa; VietQR của trang demo dùng tài khoản thử nghiệm; ảnh minh chứng che mã QR và số tài khoản; không chụp trang “Chuyển khoản VietQR”. | 6.2, 6.3, 6.5 |
| Không có Internet ở nơi demo | Mất giao diện (CDN) và VNPay | Kiểm tra mạng trước buổi demo, chuẩn bị mạng dự phòng (điện thoại phát Wi-Fi). | 6.4, 6.5 |
| Chỉ có ngày 17/11 để sửa lỗi chặn, 18/11 để chạy lại | Lỗi phát hiện muộn không kịp sửa trước 19/11 | Ngày 16/11 chạy trước các ca Must của luồng chính (đặt tour → thanh toán → voucher) và báo lỗi chặn ngay trong ngày; lỗi không chặn ghi cho Sprint 7. | 6.5, 6.6 |
| CR2 đưa lên trang demo sát ngày UAT (15–16/11) | Lỗi mới ở luồng đặt tour, thanh toán đã ổn định | Chạy lại các ca UAT của luồng chính và các ca CR2 trên bản tích hợp trước khi cập nhật trang demo; database trang demo được nâng cấp tại chỗ, chỉ chạy các file mới và file đã sửa (`33`, `03`, `05`, `06`, `21`, `34` → `37`, `38`, `39`, `41`), giữ nguyên dữ liệu và tài khoản quản trị đã chuẩn bị cho UAT; lỗi phát hiện trong UAT xử lý ở 6.6. | 6.12 → 6.17, 6.5 |
| 64 ca UAT chạy trong một ngày | Không kịp chạy hết ca ngày 16/11 | Bắt đầu từ sáng; chạy các ca khác trong lúc chờ đơn hết giữ chỗ (UAT-25, UAT-26) và chờ lịch của UAT-51 kết thúc (UAT-52) theo mục 5 của 04; ca chưa chạy ghi lý do, chạy ngày 18/11. | 6.5 |

## 7. Sprint 7 nhận từ Sprint 6

- Gói demo đã thử cài trên máy khác, kèm mã commit (6.3, 6.4, 6.6).
- Installation Guide và User Guide đã sửa theo kết quả thử cài và UAT (6.1, 6.2).
- Biên bản UAT, defect log và bảng tổng hợp nghiệm thu demo với quyết định Go / No-go (6.5, 6.7).
- Danh sách lỗi còn mở và điểm còn thiếu, có người phụ trách và hướng xử lý.
- Các mục giữ ở Product Backlog (mục 2) không đổi.
