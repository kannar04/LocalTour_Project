# Kế hoạch kiểm thử sơ bộ

## Mục tiêu

Kiểm tra các chức năng chính của MVP LocalTour và khả năng người dùng hoàn thành quy trình tìm kiếm, so sánh và đặt tour cơ bản.

## Phạm vi

- Danh sách và chi tiết tour.
- Tìm kiếm, lọc và sắp xếp tour.
- So sánh thông tin tour.
- Hiển thị đánh giá người dùng.
- Đặt tour và lưu thông tin đặt tour.
- Quản lý thông tin tour và quyền truy cập chức năng quản trị.

Thanh toán trực tuyến thực tế, ứng dụng di động riêng, AI đề xuất tour và GPS thời gian thực nằm ngoài phạm vi MVP.

## Cách thực hiện

- **Kiểm thử chức năng:** Thực hiện các ca trong [test_cases.md](test_cases.md), gồm dữ liệu hợp lệ và không hợp lệ.
- **Kiểm thử tích hợp:** Kiểm tra giao diện, xử lý nghiệp vụ và lưu/truy xuất dữ liệu hoạt động cùng nhau khi được triển khai.
- **Kiểm thử giao diện:** Kiểm tra bố cục, thông báo lỗi và khả năng thao tác trên màn hình máy tính và điện thoại.
- **Kiểm thử với người dùng:** Mời người dùng mục tiêu thử tìm kiếm, so sánh và đặt tour; ghi nhận khó khăn và phản hồi.

## Chuẩn bị

- Có phiên bản MVP chạy được và ghi rõ commit kiểm thử.
- Có dữ liệu mẫu gồm tour khác địa điểm, mức giá và thời lượng; tour có/không có đánh giá.
- Có tài khoản quản trị và tài khoản không có quyền quản trị nếu chức năng phân quyền được triển khai.
- Thống nhất trường bắt buộc của form đặt tour, tiêu chí lọc và quy tắc so sánh trước khi kiểm thử.
- Ghi rõ trình duyệt, kích thước màn hình và môi trường sử dụng.

## Phân công dự kiến

Hồ Duy Hải và Đỗ Sơn Thành phụ trách tổng hợp ca kiểm thử, kết quả và tài liệu. Nhóm phát triển phối hợp xử lý lỗi; Project Manager theo dõi tiến độ kiểm thử.

## Điều kiện hoàn thành

- Các ca kiểm thử chức năng chính đã được thực hiện và có kết quả ghi nhận.
- Các chức năng chính đạt kết quả mong đợi; lỗi chặn quy trình tìm kiếm, so sánh hoặc đặt tour đã được xử lý và kiểm thử lại.
- Phản hồi từ người dùng mục tiêu được ghi nhận.
- Các lỗi còn lại và giới hạn của MVP được nêu rõ trong báo cáo.
