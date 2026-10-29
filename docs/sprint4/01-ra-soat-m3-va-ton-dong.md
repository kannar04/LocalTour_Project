# Rà soát kết quả M3 và tồn đọng

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 4 – M4 Nghiệm thu bản tích hợp và Booking MVP |
| WBS | M4 mục 1 – Rà soát kết quả nghiệm thu M3 và xử lý tồn đọng |
| Người phụ trách | Lê Trung Phong |
| Căn cứ | Báo cáo Sprint 3 (mục 2, 8, 9); Kết quả kiểm thử và defect log Sprint 3 (WBS 3.3.3); Retest và báo cáo kiểm thử (WBS 3.3.4); Checklist QC (WBS 3.3.2); Câu hỏi sau Sprint 3 (nhóm đã trả lời); tài liệu [Sprint 3](../sprint3/) |
| Tài liệu liên quan | [02 – Yêu cầu và luồng đặt tour](02-yeu-cau-va-luong-dat-tour.md), [03 – Cấu trúc dữ liệu Booking](03-cau-truc-du-lieu-booking.md) |
| Trạng thái | **Đã chốt.** |

## 1. Kết quả M3 đã hoàn thành

Theo báo cáo Sprint 3, cả 18 task của Sprint 3 đã hoàn thành và Sprint Goal đạt. Các phần dưới đây là **Done**, M4 không tạo lại task cho chúng; chỉ sửa khi có defect đã xác nhận (mục 2) hoặc khi luồng đặt tour cần nối vào (mục 4).

| Phần | Yêu cầu | Kết quả M3 |
| --- | --- | --- |
| Danh sách và chi tiết tour | FR-01 → FR-05 | Đọc từ MySQL; chi tiết mở theo ID; trang “Không tìm thấy tour” khi ID sai hoặc tour chưa duyệt; thiếu trường ghi “Chưa cập nhật”; trạng thái đang tải, rỗng, lỗi. |
| Tìm kiếm, lọc, sắp xếp | FR-06 | Tìm theo tên / điểm đến, lọc điểm đến và loại hình, sắp xếp theo giá. |
| Lịch, giá vé, đánh giá | FR-07, FR-10, FR-16 (xem đánh giá) | Thẻ chọn lịch, giá từng loại vé, tạm tính tiền vé; hiện đánh giá đã duyệt. |
| Tài khoản khách hàng | FR-18 | Đăng ký, đăng nhập, đăng xuất, chế độ khách; quay lại trang đang xem sau khi đăng nhập. |
| Trang quản trị (CR1) | FR-19 → FR-25, NFR-09 | Đăng nhập riêng, tổng quan và thống kê, duyệt tour, xử lý yêu cầu đặt tour, nhật ký `admin_logs`. |
| Cơ sở dữ liệu | – | Lược đồ 27 bảng, dữ liệu mẫu, stored procedure theo người phụ trách. |
| Tài liệu kỹ thuật | – | Sprint 3: 01 Danh mục trường dữ liệu, 02 Lược đồ dữ liệu, 03 Route và quy ước lỗi; sơ đồ trong `docs/diagram`. |
| Kiểm thử | – | 43 test case, defect log, retest, demo theo kịch bản 10 bước. |

## 2. Kết quả kiểm thử và defect của M3

Số liệu lấy từ tài liệu kiểm thử Sprint 3 (WBS 3.3.3, 3.3.4).

| Mục | Kết quả |
| --- | --- |
| Lần chạy 1 | 43 ca: 39 Pass, 4 Fail (TC-LT-04, TC-LT-22, TC-LT-24, TC-LT-28), 0 Blocked. |
| Defect | 9 lỗi DEF-01 → DEF-09: 2 Trung bình, 7 Thấp; 3 chức năng, 3 giao diện, 3 tài liệu. Không có lỗi Nghiêm trọng hoặc Cao. |
| Sửa lỗi và retest | Cả 9 lỗi đã sửa và **Đã đóng**; chạy lại 43 ca: 43 Pass, không ca nào từ Pass chuyển sang Fail. |
| Demo | 10/10 bước đạt. |

Kết luận: M3 không còn defect mở, M4 không có lỗi M3 nào phải sửa. Lần chạy nghiệm thu chính thức của M3 được ghi ở biên bản riêng; nếu lần đó phát sinh lỗi mới thì ghi tiếp từ DEF-10 vào defect log, xác nhận rồi mới sửa ở M4 mục 11 (không tự giả định lỗi).

## 3. Phân loại công việc tồn

Nguồn: bảng “Việc chuyển sang Sprint sau” của báo cáo Sprint 3 và các mục “Chưa khớp” / “Chưa có thiết kế để đối chiếu” của checklist QC.

| Việc | Yêu cầu | Tình trạng sau M3 | Phân loại | Xử lý ở M4 |
| --- | --- | --- | --- | --- |
| Gửi yêu cầu đặt tour: chọn lịch, số khách, thông tin khách, kiểm tra chỗ | FR-08, FR-09, FR-14 | Chưa làm, nút “Đặt tour” tắt. QC: “Chưa có thiết kế để đối chiếu”. | **M4** | Mục 2–9: thiết kế ở [02](02-yeu-cau-va-luong-dat-tour.md), [03](03-cau-truc-du-lieu-booking.md); route B1 `POST /api/bookings`. |
| Giữ / nhả chỗ khi xác nhận, hủy | FR-14 | QC “Chưa khớp – Cao”: xác nhận và hủy không kiểm tra, không cập nhật `schedules.remaining`. | **M4** | Xác nhận chỗ trừ chỗ và báo khi không đủ; hủy đơn đang giữ chỗ trả lại chỗ ([03](03-cau-truc-du-lieu-booking.md), mục 3). |
| Hết hạn giữ chỗ 24 giờ | FR-14, FR-17 | Chưa làm. | M5 | Làm cùng thanh toán. |
| “Đơn của tôi” | FR-11, FR-18 | Chưa làm. QC: “Chưa có thiết kế để đối chiếu” (route B2). | **M4** | Mục 7, 8: trang `/bookings`, `/bookings/{mã đơn}` thay cho route B2 `POST /api/bookings/lookup` ([02](02-yeu-cau-va-luong-dat-tour.md), mục 5). |
| Thanh toán VNPay sandbox, chuyển khoản VietQR | FR-17 | Chưa làm (B3–B5). | M5 | Trang đơn ở “Chờ thanh toán” chỉ báo bước tiếp theo. |
| Thêm / sửa tour và đơn vị tổ chức | FR-13, FR-24 | QC “Chưa khớp – Trung bình”: chỉ duyệt / từ chối được. | Backlog | Không thuộc M4. Tour vẫn nhập bằng SQL. |
| Cập nhật nội dung tour, nguồn và ngày xác minh | NFR-07, NFR-08 | QC “Chưa khớp – Trung bình”: chỉ xem được. | Backlog | Không thuộc M4, làm cùng FR-13. |
| Cấu hình lịch khởi hành và sức chứa trên trang quản trị | FR-14 | Chưa có màn hình; lịch nhập bằng SQL. | Backlog | Không thuộc M4. |
| So sánh 2–3 tour | FR-15 | Chưa làm, nút “So sánh” tắt. | Backlog | Giữ nhãn “Sắp có”. |
| Gửi đánh giá tour | FR-16 | Đã hiện đánh giá đã duyệt; chưa gửi được. | Backlog | Giữ nguyên. |
| Khách tự đổi / hủy đơn | FR-12 | Phát triển sau; quản trị viên hủy được kèm lý do. | Phát triển sau | Trang đơn hướng dẫn khách liên hệ LocalTour. |
| Thích, Bình luận, Chia sẻ, Lưu tour | – | Tắt, nhãn “Sắp có”. | Backlog | Giữ nguyên. |
| Giao diện desktop / 360 px, mục tiêu tải 3 giây, Chrome / Edge | NFR-01 → NFR-03, NFR-10 | QC: chưa ghi môi trường đo và ma trận trình duyệt. | **M4** (QA) | Kiểm tra trang đặt tour và “Đơn của tôi” ở 360 px và desktop trong M4 mục 9, 10; ghi môi trường đo vào checklist. |
| Tài liệu Sprint 2 còn lại: hình WBS, wireframe “Đơn của tôi” và trang quản lý yêu cầu, tên vai trò “Quản trị viên” | – | Chưa cập nhật. | Tài liệu | Nhóm phân tích cập nhật; trang đặt tour M4 theo wireframe 4 đã có. |

Quyết định nhóm theo checklist QC:

| Quyết định | Kết quả |
| --- | --- |
| Thời điểm giữ / nhả chỗ (FR-14) | **Đã chốt ở M4:** đơn mới chưa giữ chỗ; quản trị viên xác nhận chỗ thì giữ, hủy đơn đang giữ thì trả; hết hạn ở M5. |
| Gói lựa chọn (FR-07) | **Đã chốt thiết kế** (câu hỏi sau Sprint 3, mục 4, bảng dưới). Chưa làm ở M4: tour mẫu chưa có gói, M4 đặt theo loại vé của lịch. Backlog. |
| Vai trò `support`, `provider` trong `users.role` | **Đã chốt ở CR1 (25/10):** hệ thống không có tác nhân Nhân viên hỗ trợ khách hàng và Đơn vị tổ chức; Quản trị viên làm mọi việc vận hành (sơ đồ use case cập nhật theo CR1). Lược đồ còn hai giá trị này và các tài khoản mẫu tương ứng nhưng không trang nào dùng: đăng nhập khách hàng chỉ nhận `customer`, đăng nhập quản trị chỉ nhận `admin`. Dọn lược đồ ở backlog. |

Câu hỏi sau Sprint 3 nhóm đã trả lời. Cả bốn mục thuộc backlog, M4 không đổi code:

| Mục | Quyết định | Ghi chú |
| --- | --- | --- |
| 1. Đánh giá tour (FR-16) | Chỉ nhận đánh giá của khách có đơn đã hoàn thành (`bookings.status = 'completed'`), gửi trên hệ thống, không lấy nguồn ngoài. Quản trị viên duyệt trước khi hiện; từ chối nội dung quảng cáo, xúc phạm hoặc lộ thông tin cá nhân; mỗi lần duyệt ghi `admin_logs` (NFR-09). | Câu 1.2 (khách không có tài khoản gửi đánh giá bằng mã đặt chỗ) không áp dụng: từ Sprint 3 mỗi đơn thuộc một tài khoản (`bookings.user_id` bắt buộc), khách gửi đánh giá từ “Đơn của tôi”. Câu 1.3 ghi “nhân viên hỗ trợ”; theo CR1, người duyệt là Quản trị viên. |
| 2. Tên người đánh giá (NFR-04) | Hiện dạng rút gọn gồm tên gọi và chữ cái đầu của họ (“Nguyễn Văn An” → “An N.”); không hiện email, số điện thoại. MVP không cho khách tự nhập tên hiển thị. | Áp dụng khi làm FR-16. |
| 3. Xác minh nguồn tour (NFR-07) | Tour chưa xác minh vẫn hiện, kèm nhãn “Thông tin chưa được xác minh” cạnh giá và trong phần Thông tin tour. Quản trị viên chuyển tour sang “Đã xác minh” trên trang quản trị tour (FR-13), mỗi lần đổi ghi `admin_logs`. Dùng ba cột có sẵn `source_url`, `verified_at`, `verification_status` của `tours`, không thêm bảng. | Làm cùng FR-13 (bảng phân loại ở trên). Mọi tour mẫu đang ở trạng thái chưa xác minh. |
| 4. Gói lựa chọn (FR-07) | Gói phân theo phương tiện hoặc tuyến điểm. Mỗi gói có tên, mô tả và giá vé riêng; lịch khởi hành và lịch trình chính dùng chung, điểm khác ghi trong mô tả gói. Thêm bảng `tour_packages` và cột `ticket_types.package_id` (để trống khi tour không có gói). | Câu 4.1 có nhắc lịch trình riêng cho từng gói; theo câu 4.2 và 4.3, lịch trình dùng chung. ERD vẽ thêm khi tạo bảng. |

## 4. Phần M3 thay đổi do luồng đặt tour

Các thay đổi dưới đây là phần nối vào luồng đặt tour, không phải sửa lỗi M3:

| Phần M3 | Thay đổi ở M4 |
| --- | --- |
| Thẻ đặt tour ở trang chi tiết | Nút “Đặt tour” bật cho tài khoản khách hàng; chế độ khách thấy “Đăng nhập để đặt tour”, đăng nhập xong vào thẳng trang đặt tour với lịch và số khách đã chọn. |
| Header | Tài khoản khách hàng có thêm nút “Đơn của tôi”. |
| Trang quản trị – yêu cầu đặt tour | Xác nhận chỗ trừ số chỗ và báo khi không đủ chỗ hoặc lịch đã đóng; hủy đơn đang giữ chỗ trả lại chỗ; trang chi tiết hiện danh sách khách và yêu cầu đặc biệt. |

Test case M3 cần cập nhật kết quả mong đợi khi lập checklist QA M4 (M4 mục 10):

| Test case | Lý do |
| --- | --- |
| TC-LT-25 | Bước 3: liên kết “Đăng nhập để đặt tour” nay trỏ tới trang đặt tour kèm lịch và số khách đang chọn (`/login?next=/tours/{id}/book?schedule_id=…&tickets[…]=…`), không còn trỏ về trang chi tiết tour. |
| TC-LT-33 | Bước 1: như TC-LT-25. Bước 2: đăng nhập xong vào trang “Hoàn tất thông tin đặt tour” của tour 1 với lựa chọn cũ; không còn nút “Đặt tour” tắt, nhãn “Sắp có”. |
| TC-22 (trang quản trị) | Xác nhận chỗ nay trừ số chỗ của lịch: thêm bước kiểm tra số chỗ còn lại giảm đúng số khách. Dùng yêu cầu LT518204 (lịch còn đủ chỗ); LT527716 nay báo không đủ chỗ, dùng để thử trường hợp đó. |
| TC-10, TC-11, TC-12, TC-16 (bộ test case ban đầu) | Trước đây Blocked vì chưa có đặt tour; M4 viết lại thành test case đặt tour. |
