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
| TC-17 | Mở trang quản trị khi chưa đăng nhập | Chưa đăng nhập | Mở `/admin` | Chuyển tới trang “Đăng nhập quản trị” (`/admin/login`); đăng nhập quản trị xong quay lại `/admin`. |
| TC-18 | Tài khoản khách hàng mở trang quản trị | Đã đăng nhập bằng tài khoản khách hàng ở `/login` | Mở `/admin`, `/admin/tours` và `/admin/bookings` | Trang 403 “Bạn không có quyền truy cập trang này.”; không thấy dữ liệu quản trị. |
| TC-19 | Số liệu trang Tổng quan | Vừa import lại database; đã đăng nhập quản trị | Mở `/admin`; chọn “Theo năm”, để trống ngày, bấm “Xem thống kê” | 40 tài khoản khách hàng (39 đang hoạt động · 1 bị khóa); 12 tour (2 chờ duyệt · 9 đã duyệt · 1 bị từ chối); 3 yêu cầu chờ xác nhận trên tổng 39. Theo trạng thái: Chờ xác nhận 3, Chờ thanh toán 2, Đã xác nhận 2, Đã hoàn thành 29, Từ chối 1, Đã hủy 2. Doanh thu tổng: 32 lượt, 39.780.000đ, hoàn tiền −1.300.000đ, thuần 38.480.000đ. |
| TC-20 | Phê duyệt tour | Đã đăng nhập quản trị; tour “Một buổi chiều trong Đại Nội Huế” đang chờ duyệt | Mở `/admin/tours`, mở tour đó, bấm “Phê duyệt tour”; sau đó mở `/tours` | Báo “Đã phê duyệt tour.”; tour “Đã duyệt”, “Đang hiển thị cho khách”. Trang `/tours` có 10 tour và bộ lọc điểm đến có Huế. |
| TC-21 | Từ chối không nhập lý do | Đã đăng nhập quản trị; có tour chờ duyệt và yêu cầu chờ xác nhận | Ở tour chờ duyệt, nhập lý do chỉ có khoảng trắng rồi bấm “Từ chối tour”; ở yêu cầu chờ xác nhận, chọn “Từ chối yêu cầu”, để trống lý do rồi bấm “Cập nhật trạng thái” | Báo “Vui lòng nhập lý do từ chối.” và “Từ chối hoặc hủy yêu cầu cần nhập lý do.”; trạng thái tour và yêu cầu không đổi. |
| TC-22 | Xác nhận chỗ và giá | Đã đăng nhập quản trị; có yêu cầu “Chờ xác nhận” | Mở `/admin/bookings`, tab “Chờ xác nhận”, mở một yêu cầu, chọn “Xác nhận chỗ và giá”, bấm “Cập nhật trạng thái” | Báo “Đã cập nhật trạng thái yêu cầu.”; trạng thái “Chờ thanh toán”, có “Hạn thanh toán” sau 24 giờ; tab “Chờ xác nhận” bớt một yêu cầu. |
| TC-23 | Xác nhận đã thanh toán | Đã đăng nhập quản trị; yêu cầu ở TC-22 chưa có thanh toán; có yêu cầu “Chờ thanh toán” với chuyển khoản VietQR “Chờ đối chiếu” | Ở yêu cầu của TC-22, chọn “Xác nhận đã thanh toán” và cập nhật; làm lại với yêu cầu có chuyển khoản VietQR | Lần đầu báo “Yêu cầu chưa có thanh toán thành công hoặc khoản chuyển khoản VietQR chờ đối chiếu, chưa xác nhận được.”, trạng thái không đổi. Lần sau: trạng thái “Đã xác nhận”, thanh toán “Thành công”, có thời điểm thanh toán. |
| TC-24 | Đánh dấu tour đã diễn ra | Đã đăng nhập quản trị; có yêu cầu “Đã xác nhận” chưa tới giờ khởi hành và yêu cầu “Đã xác nhận” đã qua giờ khởi hành | Ở từng yêu cầu, chọn “Tour đã diễn ra” và cập nhật | Yêu cầu chưa khởi hành báo “Tour chưa tới giờ khởi hành, chưa đánh dấu hoàn thành được.”, trạng thái không đổi. Yêu cầu đã khởi hành chuyển “Đã hoàn thành” và không còn form cập nhật. |
| TC-25 | Ghi lịch sử xử lý | Đã chạy TC-20 → TC-24 | Mở chi tiết tour và chi tiết các yêu cầu vừa xử lý, xem mục “Lịch sử xử lý” | Mỗi thao tác thành công có thêm một dòng: thời điểm, người xử lý, trạng thái cũ → trạng thái mới và lý do (nếu có). Các lần báo lỗi ở TC-21, TC-23, TC-24 không thêm dòng nào. |

TC-17 → TC-25 kiểm thử trang quản trị (CR1). Trước khi chạy: import lại `db_localtour.sql` và tạo tài khoản quản trị viên thử theo `src/README.md`, bước 7. Bản ghi mẫu dùng cho từng ca xem [02 – Lược đồ dữ liệu](../docs/sprint3/02-luoc-do-du-lieu.md), mục 8.3.

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
