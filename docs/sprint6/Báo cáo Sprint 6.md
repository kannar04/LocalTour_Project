# BÁO CÁO TẠM THỜI KẾT QUẢ SPRINT 6 VÀ KẾ HOẠCH SPRINT 7

**Dự án:** LocalTour  
**Sprint 6:** 13/11/2026 – 19/11/2026  
**Thời điểm cập nhật:** 18/11/2026

## 1. Kết quả Sprint 6

Mục tiêu Sprint 6 là hoàn thiện bản demo, tài liệu hướng dẫn, kiểm tra khả năng cài đặt và thực hiện UAT.

Đến ngày 18/11/2026, nhóm đã hoàn thiện bản demo, Installation Guide, User Guide và các chức năng bổ sung. Hệ thống đã được kiểm thử nội bộ. Phần UAT và nghiệm thu chính thức chưa hoàn thành do chưa nhận đủ kết quả UAT từ nhóm PCG.

| Hạng mục | Kết quả | Trạng thái |
|---|---|---|
| Installation Guide | Đã hoàn thiện hướng dẫn cài đặt và cấu hình | Hoàn thành |
| User Guide | Đã hoàn thiện hướng dẫn cho khách hàng, quản trị viên và đơn vị tổ chức | Hoàn thành |
| Đóng gói demo | Đã chuẩn bị mã nguồn, database mẫu và công cụ hỗ trợ cài đặt | Hoàn thành |
| Thử cài đặt (Task 6.4) | Đã thử cài đặt trên máy Windows khác theo xác nhận của Project Manager; repository không bổ sung hồi tố thông số máy | Hoàn thành |
| Chức năng bổ sung theo CR2 | Đã triển khai và cập nhật tài liệu liên quan | Hoàn thành |
| UAT chính thức | Đã bàn giao bản demo và checklist cho nhóm PCG | Chờ kết quả |
| Sửa lỗi từ UAT | Chưa có defect log chính thức để xử lý | Chưa hoàn thành |
| Nghiệm thu demo | Chưa đủ kết quả UAT để tổng hợp nghiệm thu | Chưa hoàn thành |

## 2. Chức năng bổ sung theo CR2

Toàn bộ yêu cầu thay đổi trong Sprint 6 được gọi chung là **CR2**. Mã WBS chi tiết 6.8–6.18 vẫn được giữ trong Kế hoạch Sprint 6 để đối chiếu.

Nhóm chức năng bổ sung gồm:

- Tài khoản và khu làm việc của đơn vị tổ chức.
- Đơn vị tổ chức quản lý tour, lịch khởi hành, sức chứa, giá vé và xem đơn đặt tour của mình.
- Đặt tour giữ chỗ ngay, không cần chờ quản trị viên xác nhận chỗ.
- Phí dịch vụ, doanh thu, chi trả và thông số vận hành.
- Lọc tour theo ngày đi và bộ lọc nâng cao.
- Thích, lưu, chia sẻ tour và trang “Tour đã lưu”.
- Bình luận và quản trị bình luận.
- Đánh giá tour sau chuyến đi và duyệt đánh giá.
- Trang tài khoản cá nhân và ảnh đại diện.
- Trang Trợ giúp, Điều khoản sử dụng, Menu và thanh điều hướng.
- Cập nhật SRS, Product Backlog, sơ đồ, User Guide và checklist UAT.

Product Backlog sau khi cập nhật có 39 User Story, từ US-01 đến US-39.

## 3. Kết quả kiểm thử nội bộ

Checklist UAT hiện có 64 ca, gồm 61 ca Must và 3 ca Should, phủ 39/39 User Story.

- Ngày 13/11: chạy thử 54 ca trên bản tích hợp.
- Ngày 15/11: chạy thử đủ 64 ca sau khi hoàn thành toàn bộ phạm vi CR2.
- Database hiện có 40 bảng và 184 stored procedure.

Kết quả kiểm thử nội bộ chỉ dùng để kiểm tra trước UAT, không thay thế kết quả nghiệm thu chính thức của người dùng.

## 4. Công việc chưa hoàn thành

| Công việc | Tình trạng | Hướng xử lý |
|---|---|---|
| 6.5 – Thực hiện UAT | Chưa nhận đủ kết quả từng ca | Thực hiện đầu Sprint 7 |
| 6.6 – Sửa lỗi chặn UAT | Chưa có defect log chính thức | Xử lý sau khi nhận kết quả UAT |
| 6.7 – Tổng hợp nghiệm thu | Chưa đủ dữ liệu để kết luận | Hoàn thành sau UAT và retest |

## 5. Issue và bug chính

| Mã | Nội dung | Trạng thái |
|---|---|---|
| I14 | Phạm vi Sprint 6 thay đổi do bổ sung CR2 | Đã cập nhật chức năng, backlog và tài liệu |
| I15 | Database cũ không đủ cấu trúc cho chức năng mới | Đã bổ sung công cụ cài đặt lại database |
| I16 | Một số nội dung tài liệu chưa khớp bản chạy | Đã cập nhật |
| I17 | Chưa nhận đủ kết quả UAT chính thức | Chuyển sang Sprint 7 |
| DEF-14 | Một số thông báo dùng sai tên trang | Đã sửa |
| DEF-15 | Nội dung thông báo phân quyền chưa phù hợp | Đã sửa |
| DEF-16 | Thời gian giữa PHP và database trên máy chủ bị lệch | Đã sửa và kiểm tra lại thanh toán |

## 6. Nguyên nhân chênh lệch so với kế hoạch

Phạm vi Sprint 6 tăng do bổ sung CR2 sau kế hoạch ban đầu. Nhóm phải triển khai thêm chức năng, cập nhật database, Product Backlog, SRS, tài liệu hướng dẫn và checklist UAT.

Bộ UAT tăng lên 64 ca và Product Backlog tăng lên 39 User Story. Bản demo và tài liệu đã được chuẩn bị trước UAT, nhưng các task 6.5–6.7 chưa thể đóng vì chưa có kết quả UAT chính thức.

## 7. Hướng phát triển sau MVP

Các nội dung dưới đây chưa thuộc tiêu chí nghiệm thu của những User Story hiện tại:

- Cho phép đơn vị tổ chức tự quản lý gói tour và phụ thu.
- Tổng hợp danh sách khách theo lịch khởi hành và xuất CSV.
- Bổ sung hồ sơ đơn vị, thông báo trong hệ thống và biểu đồ tổng hợp.
- Bổ sung sổ số dư, điều chỉnh sau hoàn tiền và chi trả lập thủ công.

Các nội dung này cần được tạo User Story và Acceptance Criteria riêng nếu triển khai sau MVP.

## 8. Kế hoạch Sprint 7

Sprint 7 diễn ra từ ngày 20/11/2026 đến ngày 26/11/2026. Mục tiêu chính là hoàn tất UAT, nghiệm thu, kiểm tra gói bàn giao và tổng kết dự án.

| Mã | Công việc | Phụ trách | Thời gian dự kiến |
|---|---|---|---|
| 6.5 | Nhận và đối chiếu kết quả UAT | Hải, Thành | 20–21/11 |
| 6.6 | Sửa lỗi từ UAT và chạy lại ca liên quan | Phong, Thức, Khôi | 21–22/11 |
| 6.7 | Tổng hợp nghiệm thu demo | Hải, Thành | 22/11 |
| 7.1 | Đối chiếu kế hoạch và thực tế | Hải, Thành | 20–21/11 |
| 7.2 | Chốt Risk, Issue và Change | Hải, Thành | 20–21/11 |
| 7.3 | Tổng hợp bài học kinh nghiệm | Hải, Thành | 22–23/11 |
| 7.4 | Hoàn thiện báo cáo tổng kết dự án | Hải, Thành | 23–24/11 |
| 7.5 | Kiểm tra tính đầy đủ của gói bàn giao và đối chiếu hướng dẫn cài đặt | Phong, Thức, Khôi | 24–25/11 |
| 7.6 | Chuẩn bị slide và tổng duyệt | Hải, Thành | 25/11 |
| 7.7 | Hoàn thiện hồ sơ và nộp báo cáo | Hải, Thành | 26/11 |

Nếu chưa nhận được kết quả UAT, nhóm giữ I17 ở trạng thái chưa đóng và ghi rõ phần nghiệm thu chưa có xác nhận của người dùng trong báo cáo cuối dự án.

## 9. Kết luận

Sprint 6 đã hoàn thành bản demo, tài liệu, nhóm chức năng bổ sung theo CR2 và Task 6.4 thử cài đặt trên máy Windows khác. Hệ thống được ghi nhận đã chạy thử nội bộ 64 ca nhưng chưa có kết quả từng ca trong repository. UAT và nghiệm thu chính thức vẫn chờ dữ liệu xác nhận từ nhóm PCG.
