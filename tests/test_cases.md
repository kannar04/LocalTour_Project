# Ca kiểm thử sơ bộ

Các ca dưới đây cần được cập nhật theo yêu cầu và giao diện đã thống nhất. Tất cả đang ở trạng thái **Not Run**.

| Mã | Chức năng / Tình huống | Điều kiện ban đầu | Bước thực hiện | Kết quả mong đợi |
| --- | --- | --- | --- | --- |
| TC-01 | Xem danh sách tour | Có dữ liệu tour mẫu | Mở trang danh sách tour | Hiển thị các tour với thông tin cơ bản đúng dữ liệu. |
| TC-02 | Xem chi tiết tour | Có tour mẫu | Chọn một tour trong danh sách | Hiển thị đúng địa điểm, giá, thời lượng, lịch trình và dịch vụ đi kèm. |
| TC-03 | Tìm kiếm có kết quả | Có tour phù hợp từ khóa | Nhập từ khóa và thực hiện tìm kiếm | Hiển thị kết quả phù hợp theo quy tắc tìm kiếm đã thống nhất. |
| TC-04 | Tìm kiếm không có kết quả | Không có tour phù hợp từ khóa | Tìm kiếm bằng từ khóa không khớp dữ liệu | Hiển thị thông báo không có kết quả; có thể thay đổi điều kiện tìm kiếm. |
| TC-05 | Lọc tour | Có tour khác địa điểm, giá và thời lượng | Áp dụng từng bộ lọc, sau đó kết hợp các bộ lọc | Kết quả đáp ứng các điều kiện đã chọn. |
| TC-06 | Xóa bộ lọc | Đang áp dụng bộ lọc | Xóa các điều kiện lọc | Danh sách trở về kết quả tương ứng khi không áp dụng bộ lọc. |
| TC-07 | Sắp xếp theo giá | Có tour với giá khác nhau | Chọn giá tăng dần, sau đó giảm dần | Thứ tự tour đúng với lựa chọn sắp xếp. |
| TC-08 | So sánh tour | Có ít nhất hai tour | Chọn các tour và mở phần so sánh | Thông tin đúng tour, trình bày cùng tiêu chí để so sánh. |
| TC-09 | Xem đánh giá | Có tour có đánh giá và tour chưa có đánh giá | Mở chi tiết từng tour | Hiển thị đúng đánh giá hiện có; thông báo phù hợp khi chưa có đánh giá. |
| TC-10 | Đặt tour hợp lệ | Có tour có thể đặt và dữ liệu mẫu hợp lệ | Điền các trường bắt buộc và gửi form đặt tour | Tạo booking, lưu đúng tour và thông tin đã nhập; hiển thị xác nhận. |
| TC-11 | Đặt tour thiếu thông tin | Có form đặt tour | Bỏ trống trường bắt buộc và gửi form | Hiển thị lỗi rõ ràng; không tạo booking không hợp lệ. |
| TC-12 | Đặt tour với dữ liệu sai | Có quy tắc xác thực đã thống nhất | Nhập dữ liệu sai định dạng hoặc số lượng khách không hợp lệ | Từ chối dữ liệu sai ở phía máy chủ và hiển thị thông báo phù hợp. |
| TC-13 | Thêm và sửa tour | Có quyền quản lý tour | Thêm tour hợp lệ, sau đó sửa thông tin | Dữ liệu được lưu đúng và thông tin cập nhật xuất hiện khi xem tour. |
| TC-14 | Truy cập quản trị không có quyền | Có chức năng phân quyền | Truy cập trang hoặc gửi yêu cầu quản lý tour bằng người dùng không có quyền | Từ chối truy cập và không thay đổi dữ liệu tour. |
| TC-15 | Giao diện trên màn hình nhỏ | MVP chạy được | Mở danh sách, chi tiết, so sánh và form đặt tour trên màn hình điện thoại | Nội dung đọc được, các nút thao tác được và form sử dụng được. |
| TC-16 | Lỗi kết nối khi đặt tour | Có thể mô phỏng lỗi kết nối | Gửi form trong lúc kết nối/dịch vụ gặp lỗi | Không thông báo đặt tour thành công khi chưa xác nhận lưu; hiển thị lỗi phù hợp. |

## Ghi nhận một lần thực hiện

| Trường | Nội dung cần ghi |
| --- | --- |
| Mã ca kiểm thử | TC-xx |
| Phiên bản / Commit | Phiên bản sản phẩm được kiểm thử |
| Môi trường | Trình duyệt, kích thước màn hình, môi trường ứng dụng |
| Người thực hiện / Ngày | Tên người kiểm thử và ngày thực hiện |
| Kết quả thực tế | Mô tả hành vi quan sát được |
| Trạng thái | Not Run / Pass / Fail / Blocked |
| Minh chứng / Lỗi | Đường dẫn ảnh, báo cáo lỗi hoặc ghi chú |
