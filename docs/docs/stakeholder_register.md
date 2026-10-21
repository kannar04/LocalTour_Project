# Stakeholder Register — LocalTour

## 1. Danh sách các bên liên quan

Nhóm xác định được 6 stakeholder như sau:

| Stakeholder | Vai trò | Nhu cầu / Kỳ vọng | Mức độ ảnh hưởng | Cách phối hợp |
| --- | --- | --- | --- | --- |
| **Người sử dụng dịch vụ** | Khách hàng tìm kiếm và đặt tour | Dễ tìm kiếm, so sánh tour; thông tin minh bạch; đặt tour thuận tiện | Trung bình | Khảo sát, phỏng vấn, thử nghiệm giao diện |
| **Project Manager** | Lập kế hoạch, điều phối và quản lý dự án | Hoàn thành đúng tiến độ, phạm vi và chất lượng | Cao | Họp nhóm định kỳ, theo dõi tiến độ, xử lý rủi ro |
| **Nhóm phát triển phần mềm** | Thiết kế, lập trình và kiểm thử hệ thống | Yêu cầu rõ ràng, nhiệm vụ hợp lý, công nghệ phù hợp | Trung bình | Phân công qua Task Board, quản lý mã nguồn bằng GitHub |
| **Đơn vị cung cấp dịch vụ (thanh toán, bản đồ và server)** | Hỗ trợ xử lý giao dịch thanh toán trực tuyến, cung cấp bản đồ Google Maps và máy chủ lưu trữ website | Tích hợp đúng kỹ thuật, giao dịch an toàn, dữ liệu hợp lệ | Trung bình | Nghiên cứu API, tài liệu tích hợp, kiểm thử sandbox |
| **Giảng viên / Nhóm PCG** | Hướng dẫn, giám sát và đánh giá dự án | Đáp ứng yêu cầu học phần, có sản phẩm hoàn chỉnh, báo cáo đúng hạn | Cao | Báo cáo tiến độ theo mốc, tiếp nhận phản hồi |
| **Đơn vị tổ chức tour du lịch** | Cung cấp và quản lý thông tin tour | Đăng tải tour dễ dàng, quản lý lịch trình, số lượng khách và đơn đặt tour | Cao | Phỏng vấn, xác nhận yêu cầu, thử nghiệm chức năng quản lý tour |

## 2. Các câu hỏi phân tích

### 2.1. Ai có quyền quyết định phạm vi dự án?

Project Manager, đơn vị tổ chức tour du lịch hoặc giảng viên/nhóm PCG.

### 2.2. Ai sử dụng sản phẩm nhưng không trực tiếp trả tiền?

Người sử dụng dịch vụ: Khách du lịch sử dụng website để tìm kiếm, xem thông tin và đặt tour du lịch địa phương nhưng không nhất thiết phải trả phí sử dụng website.

### 2.3. Ai có thể khiến dự án chậm tiến độ?

- **Project Manager:** Có thể đưa ra các thay đổi hoặc điều chỉnh dựa trên tiến độ làm việc của nhóm nhằm nâng cao hiệu quả và năng suất. Những thay đổi này có thể phát sinh công việc và ảnh hưởng đến tiến độ.
- **Nhóm phát triển phần mềm:** Có thể gặp các vấn đề cá nhân hoặc tập thể, xung đột và tranh cãi trong quá trình thực hiện dự án.
- **Giảng viên:** Có thể nhận thấy những thiếu sót hoặc những điểm đi lệch mục đích ban đầu và đưa ra hướng dẫn. Nhóm cần dành thêm thời gian để điều chỉnh theo phản hồi.
- **Nhóm PCG:** Có thể làm chậm tiến độ nếu không hoàn thành nhiệm vụ đúng thời hạn, phối hợp thiếu hiệu quả hoặc thay đổi yêu cầu liên tục, khiến nhóm phát triển phải chờ đợi, điều chỉnh kế hoạch và phát sinh thêm công việc.
- **Người sử dụng dịch vụ:** Có thể chưa hài lòng với sản phẩm hoặc đề xuất thêm yêu cầu ngay cả khi đã hài lòng. Các yêu cầu bổ sung có thể khiến tiến độ tiếp tục kéo dài.
- **Đơn vị cung cấp dịch vụ (thanh toán, bản đồ và server):** API thanh toán, bản đồ hoặc máy chủ gặp sự cố; việc tích hợp khó khăn; tài liệu kỹ thuật không đầy đủ; hoặc quá trình cấp quyền truy cập bị trì hoãn có thể khiến nhóm không hoàn thành và kiểm thử website đúng kế hoạch.

### 2.4. Nếu khách hàng và người dùng có yêu cầu khác nhau, nhóm sẽ xử lý thế nào?

Nhóm sẽ tiếp nhận cả yêu cầu của khách hàng lẫn người dùng, sau đó phân tích và phân loại thành các yêu cầu có thể thực thi hoặc không thể thực thi.

Sau khi hoàn thành việc phân loại, nhóm sẽ thực hiện những yêu cầu có thể thực thi, đồng thời giải thích với người dùng và khách hàng lý do một số yêu cầu khó hoặc không thể thực thi.
