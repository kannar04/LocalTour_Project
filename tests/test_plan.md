# KẾ HOẠCH KIỂM THỬ HỆ THỐNG LOCALTOUR

| Thuộc tính | Giá trị |
|---|---|
| Phiên bản tài liệu | 1.0 |
| Baseline yêu cầu | SRS v1.2, Product Backlog 39 User Story, CR1 và CR2 |
| Phạm vi mã | US-01–US-39; FR-01–FR-36; NFR-01–NFR-10 |
| UAT tham chiếu | [Checklist UAT Sprint 6](../docs/sprint6/04-uat-checklist.md), UAT-01–UAT-64 |
| Trạng thái | Kế hoạch kiểm thử chính thức; kết quả thực thi được quản lý riêng trong `tests/results/` |

## 1. Mục tiêu kiểm thử

- Verification: xác nhận sản phẩm được xây dựng đúng SRS v1.2, quy tắc nghiệp vụ và Product Backlog.
- Validation: đánh giá sản phẩm có hỗ trợ đúng nhu cầu của Khách vãng lai, Khách hàng, Quản trị viên và Đơn vị tổ chức hay không.
- Phát hiện sai lệch chức năng, phân quyền, dữ liệu, tích hợp thanh toán và trải nghiệm trước UAT chính thức.
- Duy trì truy vết hai chiều giữa FR/NFR, User Story, Test Case và UAT Case.

System Testing, Integration Testing và UAT là ba hoạt động riêng. Nhóm phát triển thực hiện System/Integration Testing; nhóm PCG thực hiện UAT chính thức theo checklist được bàn giao. Kết quả chạy nội bộ không thay thế biên bản UAT hoặc quyết định nghiệm thu.

## 2. Phạm vi kiểm thử

Phạm vi gồm 39 User Story, 36 Functional Requirement và 10 Non-functional Requirement của SRS v1.2.

### 2.1. Khách vãng lai và Khách hàng

- Đăng ký, đăng nhập, đăng xuất; quản lý tài khoản cá nhân.
- Xem danh sách/chi tiết/bản đồ; tìm kiếm, lọc nâng cao, sắp xếp và so sánh tour.
- Đặt tour, giữ chỗ ngay, tính giá, gói tour, sức chứa và thời hạn nhận đặt.
- Thanh toán VNPay sandbox, VietQR; voucher; lịch sử đơn.
- Gửi yêu cầu đổi ngày/hủy theo phạm vi đã triển khai.
- Thích, lưu, chia sẻ, bình luận và đánh giá tour.

### 2.2. Quản trị viên

- Quản lý/phê duyệt tour và bản sửa; tài khoản khách và đơn vị tổ chức.
- Quản lý đơn đặt tour; đối chiếu thanh toán; ghi nhận hoàn tiền và chi trả.
- Quản lý thông số vận hành.
- Kiểm duyệt bình luận và đánh giá.
- Thống kê người dùng, tour, đơn và doanh thu.

### 2.3. Đơn vị tổ chức

- Đăng nhập khu vực riêng; quản lý tour và gửi duyệt/bản sửa.
- Quản lý lịch khởi hành, sức chứa, giá; xem đơn thuộc tour của mình.
- Khai báo tài khoản nhận tiền; theo dõi doanh thu và khoản chi trả.

### 2.4. Phi chức năng

- Phân quyền phía máy chủ, CSRF và bảo vệ dữ liệu cá nhân.
- Toàn vẹn dữ liệu, khả năng truy vết, bảo trì, phục hồi và nhật ký.
- Khả dụng, tương thích thiết bị/trình duyệt và hiệu năng.

Ngoài phạm vi: giao dịch tiền thật, hoàn tiền/chuyển khoản tự động, ứng dụng mobile độc lập và các hạng mục SRS ghi rõ là phát triển sau nhưng chưa được triển khai. Việc kiểm thử yêu cầu đổi/hủy chỉ áp dụng cho hành vi hiện có trong Sprint 6.

## 3. Đối tượng kiểm thử

| Đối tượng | Nội dung |
|---|---|
| Giao diện web | Trang khách, khu quản trị, khu đơn vị tổ chức |
| Nghiệp vụ | Tour, lịch, booking, thanh toán, đổi/hủy, hoàn tiền, chi trả, nội dung người dùng |
| Tích hợp | PHP–MariaDB, VNPay sandbox, VietQR, email/bản đồ khi cấu hình sẵn |
| Dữ liệu | Ràng buộc, quyền sở hữu, trạng thái, lịch sử và tính nhất quán |
| Tài liệu | SRS, Product Backlog, Test Case và UAT Checklist |

## 4. Phương pháp kiểm thử

| Hoạt động | Mục đích | Người thực hiện |
|---|---|---|
| Review/Verification | Đối chiếu đặc tả, quy tắc, giao diện và truy vết | Nhóm dự án |
| System Testing | Kiểm tra luồng đầu-cuối theo vai trò | Nhóm phát triển/kiểm thử |
| Integration Testing | Kiểm tra giao diện–controller–database và cổng thanh toán | Nhóm phát triển/kiểm thử |
| Security/negative testing | Thử truy cập trái quyền, CSRF, dữ liệu sai và lỗi tích hợp | Nhóm phát triển/kiểm thử |
| Regression Testing | Chạy lại ca bị ảnh hưởng sau sửa lỗi | Người xử lý lỗi và người kiểm thử |
| UAT | Validation độc lập theo UAT-01–UAT-64 | Nhóm PCG |

Kỹ thuật áp dụng: phân lớp tương đương, giá trị biên, bảng quyết định, chuyển trạng thái, use-case testing và kiểm thử thăm dò có ghi nhận.

## 5. Môi trường kiểm thử

- Bản tích hợp hoặc trang demo được xác định tại thời điểm chạy; phải ghi phiên bản/commit nếu có bằng chứng.
- PHP 8.2 và MariaDB/MySQL theo hướng dẫn cài đặt; database được nạp đúng thứ tự script.
- Chrome và Edge bản được cài tại thời điểm chạy; viewport desktop và khoảng 360 px.
- VNPay dùng sandbox. VietQR chỉ đối chiếu thủ công, không suy diễn kết quả ngân hàng.
- Mỗi lần chạy phải ghi URL/máy chủ, trình duyệt, hệ điều hành và cấu hình dữ liệu thực tế; không điền hồi tố khi không có bằng chứng.

## 6. Dữ liệu kiểm thử

- Dùng dữ liệu mẫu trong `src/database/` và các tài khoản được tạo theo hướng dẫn.
- Có tour công khai/chờ duyệt/bị từ chối, có/không có gói, lịch còn/hết chỗ và các mốc trước/sau hạn.
- Có tài khoản riêng cho Khách hàng, Admin và Đơn vị tổ chức; không dùng chung phiên khi kiểm tra phân quyền.
- Dữ liệu biên: giữ chỗ mặc định 30 phút; ngừng nhận đặt trước khởi hành 60 phút; VietQR tối thiểu 24 giờ trước khởi hành.
- Không ghi mật khẩu, số giấy tờ thật, khóa thanh toán hoặc dữ liệu cá nhân thật vào Evidence.

## 7. Phân công trách nhiệm

| Vai trò | Trách nhiệm |
|---|---|
| Hải, Thành | Duy trì kế hoạch, Test Case, tổng hợp kết quả và điều phối UAT |
| Phong, Thức, Khôi | Chuẩn bị bản chạy/dữ liệu; hỗ trợ tái hiện, sửa lỗi và regression |
| Project Manager | Theo dõi phạm vi, rủi ro, điều kiện vào/ra và quyết định chuyển bước |
| Nhóm PCG | Thực hiện UAT chính thức, ghi kết quả và xác nhận độc lập |

## 8. Điều kiện bắt đầu

- SRS v1.2, Product Backlog và baseline CR2 đã được nhận diện; mọi điểm chưa được phê duyệt phải ghi rõ.
- Bản kiểm thử cài được, database khởi tạo được, các vai trò đăng nhập được.
- Dữ liệu và cấu hình thanh toán sandbox sẵn sàng; đồng hồ ứng dụng/database đồng bộ.
- Test Case có Requirement ID, User Story ID và kết quả mong đợi; môi trường chạy được ghi nhận.

## 9. Điều kiện kết thúc

- Mọi ca trong phạm vi đã được đánh dấu Pass, Fail, Blocked hoặc Not Run kèm lý do; không coi “đã chạy” đồng nghĩa “Pass”.
- Lỗi Critical/High chặn luồng Must đã đóng và regression đạt, hoặc có quyết định chấp nhận rủi ro bằng văn bản.
- Có thống kê bao phủ 39/39 User Story, FR-01–FR-36 và NFR-01–NFR-10.
- Kết quả nội bộ, System Testing và UAT chính thức được báo cáo tách biệt.
- Evidence/Defect liên kết được đến Test Case; không tạo minh chứng hoặc Defect ID giả.

## 10. Quản lý lỗi và hồi quy

Defect phải ghi tối thiểu: ID do công cụ/nhóm cấp, Test Case, phiên bản, môi trường, bước tái hiện, kết quả thực tế/mong đợi, mức độ, người xử lý và trạng thái. Khi sửa lỗi, chạy lại ca lỗi và các ca cùng vùng ảnh hưởng; liên kết kết quả regression với Defect ID. Nếu chưa có Defect ID, để trống thay vì tự đặt mã.

## 11. Quản lý kết quả và Evidence

- Lưu báo cáo trong [`tests/results/`](results/README.md); Evidence thực tế đặt theo quy ước tại README của thư mục đó.
- Trạng thái chuẩn: `Pass`, `Fail`, `Blocked`, `Not Run`.
- Không dùng ảnh không rõ nguồn, không điền Pass hồi tố và không tuyên bố UAT hoàn thành nếu chưa có xác nhận PCG.
- Báo cáo nội bộ ngày 15/11/2026 chỉ xác nhận đã chạy 64 ca; repository chưa có bảng Pass/Fail theo từng ca.

## 12. Ma trận bao phủ cấp cao

| Nhóm | Test Case | UAT |
|---|---|---|
| 39 User Story và FR-01–FR-36 | TC-01–TC-39 | UAT-01–UAT-64 |
| NFR-01–NFR-10 | TC-40–TC-49 | Các UAT liên quan và System/Integration Testing |

Chi tiết truy vết nằm trong [test_cases.md](test_cases.md). Checklist UAT hiện hữu được tái sử dụng; không tạo bộ UAT thứ hai.
