# Cấu trúc dự án — LocalTour

LocalTour được tổ chức thành một dự án chung trong `src/`, bao gồm giao diện, xử lý yêu cầu, nghiệp vụ và dữ liệu. Các thư mục được chia theo trách nhiệm. Đây là cấu trúc ban đầu, chỉ có thư mục và tài liệu; chưa có mã nguồn hoặc framework được chọn.

## Cây thư mục

```text
src/
├── README.md
├── config/
├── routes/
├── controllers/
├── services/
├── models/
├── middlewares/
├── validators/
├── database/
│   ├── migrations/
│   └── seeds/
├── pages/
├── components/
├── layouts/
├── state/
├── assets/
├── public/
├── styles/
└── utils/
```

Các thư mục trống chứa `.gitkeep` để Git lưu được cấu trúc. Có thể xóa file này khi có nội dung thực tế.

## Nơi lưu từng phần

| Thư mục | Nội dung sẽ lưu |
| --- | --- |
| `config/` | Cấu hình ứng dụng, cơ sở dữ liệu và dịch vụ bên ngoài. |
| `routes/` | Khai báo đường dẫn và điểm tiếp nhận yêu cầu của ứng dụng. |
| `controllers/` | Tiếp nhận yêu cầu, gọi nghiệp vụ và trả kết quả. |
| `services/` | Xử lý nghiệp vụ tìm kiếm, so sánh, đặt tour và tích hợp dịch vụ. Phần gọi API từ giao diện cũng được tổ chức tại đây, trong các thư mục con theo trách nhiệm khi cần. |
| `models/` | Mô hình dữ liệu và ánh xạ cơ sở dữ liệu. |
| `middlewares/` | Xử lý xác thực, phân quyền và lỗi trong luồng yêu cầu. |
| `validators/` | Kiểm tra dữ liệu đầu vào; kiểm tra phía máy chủ là bước bắt buộc khi triển khai. |
| `database/migrations/` | Các thay đổi cấu trúc cơ sở dữ liệu có quản lý phiên bản. |
| `database/seeds/` | Dữ liệu mẫu dùng cho phát triển, trình diễn và kiểm thử. |
| `pages/` | Các trang danh sách tour, chi tiết tour, so sánh, đặt tour và quản trị. |
| `components/` | Thành phần giao diện tái sử dụng như thẻ tour, bộ lọc và form. |
| `layouts/` | Bố cục chung, header, footer và vùng nội dung. |
| `state/` | Trạng thái giao diện dùng chung, ví dụ danh sách tour được chọn để so sánh. |
| `assets/` | Ảnh, biểu tượng và font được sử dụng trong mã nguồn giao diện. |
| `public/` | Tài nguyên tĩnh được phục vụ trực tiếp như favicon. |
| `styles/` | Kiểu giao diện, màu sắc, font và bố cục dùng chung. |
| `utils/` | Hàm tiện ích như định dạng giá, ngày và thời lượng. Tách tiện ích chỉ chạy trên máy chủ khi cần. |

## Quy ước tổ chức

- Sử dụng một cấu hình ứng dụng, manifest và quy trình chạy/build chung tại gốc repository khi chọn công nghệ triển khai.
- Đặt nội dung vào thư mục theo trách nhiệm; chỉ thêm thư mục con khi cần tổ chức chức năng cụ thể.
- Mã giao diện không truy cập trực tiếp cơ sở dữ liệu hoặc nhập các phần chỉ chạy trên máy chủ. Việc trao đổi dữ liệu thực hiện qua cơ chế mà framework được chọn hỗ trợ.
- Giữ thông tin kết nối, mật khẩu và khóa bí mật ở phía máy chủ; không lưu giá trị bí mật trong repository hoặc tài nguyên gửi đến trình duyệt.
- Lưu tài liệu tại `docs/`, kế hoạch tại `planning/` và bộ kiểm thử tại `tests/` ở gốc repository. Xem [tests/README.md](../tests/README.md).
- Điều chỉnh cấu trúc theo quy ước framework khi nhóm thống nhất công nghệ.
