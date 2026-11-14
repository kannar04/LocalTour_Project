# LocalTour – Mã nguồn ứng dụng

Thư mục `src/` chứa LocalTour Increment v0.4: trang danh sách tour, trang chi tiết tour, tài khoản khách hàng (đăng ký, đăng nhập, đăng xuất), trang quản trị (duyệt tour, xử lý yêu cầu đặt tour, thống kê) của Sprint 3; luồng đặt tour MVP (M4: chọn lịch và số khách, nhập danh sách khách, gửi yêu cầu đặt tour, trang "Đơn của tôi"); và Sprint 4: chọn phụ thu / hoạt động tùy chọn khi đặt, chốt giá, thanh toán VNPay (sandbox) và chuyển khoản VietQR, đối chiếu chuyển khoản, voucher, tự hủy đơn quá hạn, lịch sử đơn, quản lý đơn vị tổ chức, thêm / sửa tour và lịch khởi hành; Sprint 5: so sánh 2–3 tour, gói tour, yêu cầu đổi ngày / hủy tour và xử lý thủ công của quản trị viên, quản lý gói, ảnh, lịch trình, dịch vụ, chính sách hủy và xóa tour. Từ file database `28`–`30`: đặt ngay (đơn mới giữ chỗ luôn ở "Chờ thanh toán", không chờ quản trị viên xác nhận chỗ), thông số vận hành, phí dịch vụ LocalTour và chi trả cho đơn vị tổ chức. File `31`, `32`: quy tắc khu đơn vị tổ chức (tour nháp, gửi duyệt, bản sửa của tour đã duyệt, xác minh tài khoản nhận tiền). Ứng dụng đọc và ghi dữ liệu MySQL qua stored procedure. Toàn bộ dữ liệu tour, giá, tài khoản và đánh giá là dữ liệu minh họa.

Tài liệu thiết kế đi kèm:

- [01 – Danh mục trường dữ liệu](../docs/sprint3/01-truong-du-lieu.md)
- [02 – Lược đồ dữ liệu](../docs/sprint3/02-luoc-do-du-lieu.md)
- [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md)
- Sprint 4: [01 – Rà soát M3 và tồn đọng](../docs/sprint4/R%C3%A0%20so%C3%A1t%20k%E1%BA%BFt%20qu%E1%BA%A3%20M3%20v%C3%A0%20t%E1%BB%93n%20%C4%91%E1%BB%8Dng.docx), [02 – Yêu cầu và luồng đặt tour](../docs/sprint4/02-yeu-cau-va-luong-dat-tour.md), [03 – Cấu trúc dữ liệu Booking](../docs/sprint4/03-cau-truc-du-lieu-booking.md)
- Sprint 5: [01 – Yêu cầu và luồng Sprint 5](../docs/sprint5/01-yeu-cau-va-luong-sprint5.md), [02 – Cấu trúc dữ liệu Sprint 5](../docs/sprint5/02-cau-truc-du-lieu-sprint5.md), [Test Plan và RTM Sprint 5](../docs/sprint5/Test%20Plan%20v%C3%A0%20RTM%20Sprint%205.docx)

## Công nghệ

| Thành phần | Công nghệ |
| --- | --- |
| Máy chủ | PHP 8.2 thuần, hướng đối tượng, mô hình MVC tự xây; không dùng framework hay Composer. |
| Cơ sở dữ liệu | MySQL (MariaDB 10.4 trong XAMPP 8.2), kết nối bằng PDO; ứng dụng chỉ gọi stored procedure. |
| Tài khoản | PHP session, `password_hash()` / `password_verify()`, mã CSRF cho mọi form POST. |
| Giao diện | HTML5, CSS3, Bootstrap 4.6.2, jQuery 3.7.1, font Be Vietnam Pro (tải từ CDN jsDelivr và Google Fonts). |
| Trao đổi dữ liệu | AJAX (`$.getJSON`/`$.ajax`), JSON UTF-8 dạng `{ success, message, data }`. |
| Môi trường | XAMPP 8.2 (Apache, PHP, MySQL, phpMyAdmin), Git/GitHub. |

## Cấu trúc thư mục

```text
src/
├── .env.example                  # Mẫu cấu hình; sao chép thành .env
├── .htaccess                     # Chặn truy cập mọi thứ ngoài public/ khi chạy bằng Apache
├── README.md
├── app/
│   ├── controllers/
│   │   ├── TourListController.php
│   │   ├── TourDetailController.php
│   │   ├── AuthController.php    # Đăng ký, đăng nhập, đăng xuất
│   │   ├── AdminController.php   # Lớp cha trang quản trị: chặn khách và tài khoản không phải quản trị viên
│   │   ├── AdminAuthController.php
│   │   ├── AdminDashboardController.php
│   │   ├── AdminTourController.php
│   │   ├── AdminBookingController.php
│   │   ├── AdminPaymentController.php    # Hàng đợi đối chiếu VietQR, quyết định đã nhận tiền / không khớp
│   │   ├── AdminProviderController.php   # Đơn vị tổ chức
│   │   ├── AdminTourFormController.php   # Thêm / sửa thông tin tour
│   │   ├── AdminScheduleController.php   # Lịch khởi hành, sức chứa, giá vé
│   │   ├── ScheduleController.php        # Kiểm tra lịch và số chỗ (API)
│   │   ├── BookingController.php         # Trang đặt tour, lưu yêu cầu đặt tour
│   │   ├── CustomerBookingController.php # Đơn của tôi
│   │   ├── PaymentController.php         # Chọn phương thức, bắt đầu VNPay / VietQR, báo đã chuyển khoản
│   │   ├── VnpayController.php           # Return URL và IPN của VNPay
│   │   ├── VoucherController.php         # Voucher tham gia tour
│   │   ├── CompareController.php         # So sánh 2–3 tour (trang và API)
│   │   ├── ChangeRequestController.php   # Khách gửi yêu cầu đổi ngày / hủy tour
│   │   ├── AdminChangeRequestController.php # Quản trị viên xử lý yêu cầu đổi ngày / hủy
│   │   ├── AdminPackageController.php    # Gói tour
│   │   ├── AdminTourContentController.php   # Ảnh, lịch trình, dịch vụ, chính sách hủy, xóa tour
│   │   ├── AdminPayoutController.php     # Chi trả đơn vị tổ chức, xác minh tài khoản nhận tiền, ghi "Đã hoàn tiền"
│   │   ├── AdminSettingController.php    # Thông số vận hành (phí dịch vụ, giữ chỗ, hạn nhận đặt, hạn VietQR)
│   │   ├── HostAuthController.php        # Đăng nhập, đăng xuất khu đơn vị tổ chức (/host)
│   │   ├── HostTourController.php        # Tour của tôi, gửi duyệt, ngừng hiển thị, bản sửa của tour đã duyệt
│   │   ├── HostTourFormController.php    # Đơn vị thêm / sửa thông tin tour (lớp con của AdminTourFormController)
│   │   ├── HostScheduleController.php    # Đơn vị quản lý lịch khởi hành, giá vé (lớp con của AdminScheduleController)
│   │   ├── HostTourContentController.php # Đơn vị quản lý ảnh, lịch trình, dịch vụ, chính sách hủy
│   │   ├── HostBookingController.php     # Đơn vị xem đơn đặt tour của tour mình (chỉ xem)
│   │   └── HostPayoutController.php      # Đơn vị xem khoản chi trả, khai tài khoản nhận tiền
│   ├── models/
│   │   ├── TourListModel.php
│   │   ├── TourDetailModel.php
│   │   ├── TourContentModel.php
│   │   ├── UserModel.php         # Tài khoản khách hàng
│   │   ├── AdminStatsModel.php
│   │   ├── AdminTourModel.php
│   │   ├── AdminBookingModel.php
│   │   ├── AdminPaymentModel.php
│   │   ├── AdminProviderModel.php
│   │   ├── AdminTourFormModel.php
│   │   ├── AdminScheduleModel.php
│   │   ├── BookingAvailabilityModel.php
│   │   ├── BookingModel.php
│   │   ├── BookingHistoryModel.php
│   │   ├── CustomerBookingModel.php
│   │   ├── PaymentModel.php
│   │   ├── PaymentResultModel.php    # Kết quả VNPay, tự hủy đơn quá hạn
│   │   ├── CompareModel.php          # Dựng bảng so sánh, ô thiếu = "Chưa cập nhật"
│   │   ├── TourPackageModel.php
│   │   ├── ChangeRequestModel.php
│   │   ├── AdminChangeRequestModel.php
│   │   ├── AdminPackageModel.php
│   │   ├── AdminTourContentModel.php
│   │   ├── HostModel.php             # Đơn vị của tài khoản đang đăng nhập, tour và đơn đặt tour của đơn vị
│   │   ├── TourRevisionModel.php     # Gửi duyệt, ngừng hiển thị, bản sửa của tour đã duyệt
│   │   ├── PayoutModel.php           # Việc sau tour, khoản chi trả, tài khoản nhận tiền, hoàn tiền
│   │   └── SettingModel.php          # Thông số vận hành
│   ├── services/                 # VnpayGateway.php (tạo URL, kiểm tra chữ ký), VietQr.php (ảnh mã QR)
│   └── views/
│       ├── admin/                # login.php, dashboard.php, tours/ (có content.php, partials/revision_compare.php), bookings/, payments/,
│       │                         # providers/, schedules/, packages/, change-requests/, payouts/, settings/, partials/nav.php
│       ├── auth/                 # login.php, register.php
│       ├── bookings/             # create.php (đặt tour), index.php, show.php (đơn của tôi), message.php, change.php (đổi ngày / hủy)
│       ├── errors/               # 403.php, 404.php, 500.php
│       ├── host/                 # login.php, tours/ (index.php, show.php), bookings/ (index.php, show.php),
│       │                         # payouts/ (index.php, show.php, bank.php); form tour, lịch, nội dung dùng chung view của admin/
│       ├── layouts/              # main.php
│       ├── payments/             # checkout.php (chọn phương thức), transfer.php (VietQR)
│       ├── partials/             # header.php (nút tài khoản, Đơn của tôi), sidebar.php, footer.php
│       ├── tours/                # index.php, show.php, compare.php, not-found.php
│       └── vouchers/             # show.php (in được)
├── config/                       # app.php, database.php, payment.php (đọc giá trị từ .env)
├── core/                         # bootstrap.php, Router.php, Controller.php, Database.php,
│                                 # DatabaseException.php, Env.php, helpers.php,
│                                 # Auth.php (phiên đăng nhập và mã CSRF)
├── database/
│   ├── 01_schema.sql
│   ├── 02_seed.sql
│   ├── 03_procedures_LTP.sql
│   ├── 04_procedures_NMT.sql
│   ├── 05_procedures_NTK.sql
│   ├── 06_procedures_NTK_account.sql
│   ├── 07_procedures_NTK_admin.sql
│   ├── 08_migration_booking_NMT.sql
│   ├── 09_procedures_NMT_booking.sql
│   ├── 10_procedures_LTP_booking.sql
│   ├── 11_procedures_NTK_booking.sql
│   ├── 12_migration_sprint4_NMT.sql
│   ├── 13_procedures_NMT_catalog.sql
│   ├── 14_procedures_NMT_payment.sql
│   ├── 15_procedures_LTP_payment.sql
│   ├── 16_migration_sprint5_LTP.sql
│   ├── 17_procedures_NMT_compare.sql
│   ├── 18_procedures_LTP_package.sql
│   ├── 19_procedures_LTP_change.sql
│   ├── 20_procedures_LTP_change_admin.sql
│   ├── 21_procedures_NMT_tour_content.sql
│   ├── 22_payment_momo_NTK.sql
│   ├── 23_map_places_NTK.sql
│   ├── 24_social_login_NTK.sql
│   ├── 25_email_NTK.sql
│   ├── 26_procedures_NTK_setup.sql
│   ├── 27_procedures_NTK_host.sql
│   ├── 28_migration_economy_NTK.sql
│   ├── 29_procedures_NTK_instant_booking.sql
│   ├── 30_procedures_NTK_payout.sql
│   ├── 31_migration_host_rules_NTK.sql
│   ├── 32_procedures_NTK_tour_revision.sql
│   ├── db_localtour.sql          # File gộp 01–32, sinh tự động
│   └── README.md
├── public/                       # Thư mục web duy nhất trình duyệt truy cập được
│   ├── .htaccess                 # Chuyển mọi đường dẫn về index.php (Apache)
│   ├── index.php                 # Front controller
│   ├── router.php                # Router cho PHP built-in server
│   └── assets/
│       ├── css/                  # base.css, tour-list.css, tour-detail.css, auth.css, admin.css, booking.css, compare.css
│       ├── js/                   # app.js, tour-list.js, tour-detail.js, booking.js, compare.js, change-request.js
│       ├── img/                  # Ảnh SVG minh họa; bảng tour_images lưu đường dẫn tới các file này
│       └── uploads/              # Ảnh tour quản trị viên tải lên (uploads/tours/), không đưa lên Git
├── routes/
│   └── web.php                   # Khai báo route
├── scripts/
│   ├── check_install.php         # Kiểm tra cài đặt: PHP, .env, database, thư mục ghi được (Sprint 6)
│   ├── create_admin.php          # Tạo / đặt lại mật khẩu tài khoản quản trị viên (Sprint 6)
│   ├── expire_holds.php          # Tự hủy đơn quá hạn thanh toán, tự hoàn thành đơn của lịch đã kết thúc, lập khoản chi trả (chạy bằng Task Scheduler)
│   ├── install_database.bat      # Bấm đúp để chạy install_database.php
│   ├── install_database.php      # Cài database: import mọi file database/NN_*.sql theo thứ tự (Sprint 6)
│   ├── register_expire_task.bat  # Đăng ký Task Scheduler chạy expire_holds.php mỗi 15 phút
│   └── setup_common.php          # Phần dùng chung của ba script cài đặt
└── storage/
    └── logs/                     # app.log sinh khi chạy, không đưa lên Git
```

Tiền tố tên procedure cho biết người phụ trách: `LTP_` – Lê Trung Phong, `NMT_` – Nguyễn Minh Thức, `NTK_` – Nguyễn Tuấn Khôi. Danh sách procedure xem [database/README.md](database/README.md).

## Route

| Phương thức | Đường dẫn | Xử lý | Ghi chú |
| --- | --- | --- | --- |
| GET | `/`, `/tours` | `TourListController@index` | Tham số: `q`, `destination_id`, `category_id`, `sort`. |
| GET | `/api/tours` | `TourListController@apiIndex` | JSON `{ tours, total }`; 400 nếu `q` quá 100 ký tự hoặc `destination_id` / `category_id` sai UUID. |
| GET | `/api/destinations` | `TourListController@apiDestinations` | JSON `{ destinations }`. |
| GET | `/api/categories` | `TourListController@apiCategories` | JSON `{ categories }`. |
| GET | `/tours/{id}` | `TourDetailController@show` | Trang 404 nếu không tìm thấy hoặc tour không công khai. |
| GET | `/api/tours/{id}` | `TourDetailController@apiShow` | 400 nếu UUID sai, 404 nếu không tìm thấy. |
| GET | `/login` | `AuthController@showLogin` | `?next=` là đường dẫn trong ứng dụng để quay lại sau khi đăng nhập. |
| POST | `/login` | `AuthController@login` | `email`, `password`, `next`, `_csrf`. |
| GET | `/register` | `AuthController@showRegister` | `?next=` như trên. |
| POST | `/register` | `AuthController@register` | `name`, `email`, `phone` (không bắt buộc), `password`, `password_confirm`, `next`, `_csrf`. |
| POST | `/logout` | `AuthController@logout` | `_csrf`; xong chuyển về `/tours`. |
| GET | `/admin/login` | `AdminAuthController@showLogin` | Đăng nhập quản trị; `?next=` chỉ nhận đường dẫn `/admin…`. |
| POST | `/admin/login` | `AdminAuthController@login` | `email`, `password`, `next`, `_csrf`; chỉ tài khoản `admin` đang `active`. |
| POST | `/admin/logout` | `AdminAuthController@logout` | `_csrf`; xong chuyển về `/admin/login`. |
| GET | `/admin` | `AdminDashboardController@index` | Tổng quan và thống kê; tham số `period` (`day`, `month`, `year`), `from`, `to` (`YYYY-MM-DD`). |
| GET | `/admin/revenue` | `AdminDashboardController@revenuePayments` | Các khoản thanh toán thành công của một kỳ doanh thu; `from`, `to` (`YYYY-MM-DD`). Mở bằng cách bấm vào kỳ trong bảng doanh thu ở `/admin`. |
| GET | `/admin/tours` | `AdminTourController@index` | `status`: `pending` (mặc định), `approved`, `rejected`, `archived` (ngừng hiển thị), `all`. |
| GET | `/admin/tours/{id}` | `AdminTourController@show` | 404 nếu UUID sai hoặc không tìm thấy. |
| POST | `/admin/tours/{id}/approve` | `AdminTourController@approve` | `_csrf`; 409 nếu tour không còn chờ duyệt. |
| POST | `/admin/tours/{id}/reject` | `AdminTourController@reject` | `note` (bắt buộc, tối đa 255 ký tự), `_csrf`. |
| GET | `/admin/bookings` | `AdminBookingController@index` | `status` (trống = tất cả), `q` (mã, tên, email, số điện thoại; tối đa 100 ký tự). |
| GET | `/admin/bookings/{id}` | `AdminBookingController@show` | 404 nếu UUID sai hoặc không tìm thấy. |
| POST | `/admin/bookings/{id}/status` | `AdminBookingController@updateStatus` | `status`, `note` (bắt buộc khi từ chối hoặc hủy, hoặc khi đổi tổng giá), `total_vnd` (tổng giá chốt khi xác nhận chỗ đơn cũ "Chờ xác nhận", trống = giữ nguyên), `_csrf`; 409 nếu không chuyển được trạng thái hoặc lịch không còn đủ chỗ. |
| GET | `/admin/payments` | `AdminPaymentController@index` | Hàng đợi chuyển khoản VietQR chờ đối chiếu và khoản VNPay chưa rõ kết quả. |
| POST | `/admin/payments/{id}/decide` | `AdminPaymentController@decide` | `decision` (`confirm` / `reject`), `note` (bắt buộc khi không khớp), `_csrf`; xong về trang yêu cầu `#payments`. |
| POST | `/admin/payments/{id}/vnpay` | `AdminPaymentController@vnpayDecide` | Ghi kết quả khoản VNPay chưa rõ kết quả: `decision` (`confirm` / `reject`), `txn_no` (mã giao dịch VNPay, bắt buộc khi `confirm`), `note` (bắt buộc khi `reject`), `_csrf`; xong về trang yêu cầu `#payments`. |
| GET, POST | `/admin/providers`, `/admin/providers/new`, `/admin/providers/{id}/edit` | `AdminProviderController` | Danh sách, thêm, sửa đơn vị tổ chức; 422 lỗi theo ô, 409 email đã dùng. |
| POST | `/admin/providers/{id}/delete` | `AdminProviderController@delete` | `confirm=1`, `_csrf`; chỉ xóa được đơn vị chưa có tour (409 khi còn tour). |
| GET, POST | `/admin/tours/new`, `/admin/tours/{id}/edit` | `AdminTourFormController` | Thêm tour (luôn chờ duyệt), sửa thông tin và trạng thái xác minh. |
| GET, POST | `/admin/tours/{id}/schedules`, `/admin/schedules/{id}/edit` | `AdminScheduleController` | Lịch khởi hành, sức chứa, giá vé người lớn / trẻ em; 409 khi sức chứa thấp hơn số chỗ đang giữ hoặc hủy lịch còn đơn. |
| GET | `/tours/{id}/book` | `BookingController@create` | Trang "Hoàn tất thông tin đặt tour"; `schedule_id`, `tickets[<mã vé>]`, `package_id` (tour có gói) – lịch, số khách và gói chọn ở trang chi tiết. Chưa đăng nhập → `/login?next=…`; tài khoản không phải khách hàng → 403. |
| GET | `/api/schedules/{id}/availability` | `ScheduleController@apiAvailability` | `people` (1–50). JSON `{ remaining, max_group_size, bookable, enough, tickets, … }`; 400 UUID sai, 404 không tìm thấy, 422 `people` sai. |
| POST | `/api/bookings` | `BookingController@store` | Form đặt tour + `_csrf`, `request_token`; 201 đã tạo đơn "Chờ thanh toán" và giữ chỗ (`data.url` là trang thanh toán của đơn), 200 gửi trùng, 401, 403, 409 (lịch, chỗ, giá hoặc gói đã đổi), 422 (lỗi theo từng ô). |
| GET | `/bookings` | `CustomerBookingController@index` | "Đơn của tôi" của tài khoản đang đăng nhập. |
| GET | `/bookings/{code}` | `CustomerBookingController@show` | Chi tiết đơn (`LTxxxxxx`); 404 khi mã sai hoặc đơn của tài khoản khác; `?new=1` hiện thông báo vừa giữ chỗ; `?pay=` hiện kết quả thanh toán. |
| GET | `/bookings/{code}/pay` | `PaymentController@checkout` | Chọn VNPay hoặc VietQR; chỉ đơn "Chờ thanh toán" còn hạn. Khách được chuyển tới đây ngay sau khi đặt (`?new=1` hiện thông báo đã giữ chỗ); VietQR không hiện nút khi còn dưới 24 giờ tới giờ khởi hành. |
| POST | `/bookings/{code}/pay/vnpay` | `PaymentController@startVnpay` | `_csrf`; 303 sang cổng VNPay sandbox. |
| POST | `/bookings/{code}/pay/vietqr` | `PaymentController@startVietqr` | `_csrf`; 303 sang trang chuyển khoản. |
| GET | `/bookings/{code}/pay/vietqr` | `PaymentController@transfer` | Mã VietQR, số tiền, nội dung chuyển khoản. |
| POST | `/bookings/{code}/pay/vietqr/submit` | `PaymentController@submitTransfer` | `payment_id`, `_csrf`; khoản chuyển sang "Chờ đối chiếu". |
| GET | `/payments/vnpay/return` | `VnpayController@result` | Return URL: kiểm tra chữ ký, ghi kết quả, chuyển về trang đơn. |
| GET | `/payments/vnpay/ipn` | `VnpayController@ipn` | IPN: JSON `{ RspCode, Message }` theo quy ước VNPay. |
| GET | `/bookings/{code}/voucher` | `VoucherController@show` | Voucher của đơn đã thanh toán; đơn chưa có voucher thì về trang đơn. |
| GET | `/compare` | `CompareController@index` | `ids`: mã tour cách nhau bởi dấu phẩy, tối đa 3 (thừa thì lấy 3 tour đầu, tour ẩn / mã sai bị bỏ kèm thông báo); dưới 2 tour thì hiện hướng dẫn chọn tour. |
| GET | `/api/compare` | `CompareController@apiIndex` | `ids` như trên. JSON `{ tours, rows, skipped }`; 422 khi dưới 2 hoặc quá 3 tour. |
| GET | `/bookings/{code}/change` | `ChangeRequestController@create` | Trang "Đổi ngày / hủy tour" của đơn: chính sách hủy, tiền đã trả, số tiền dự kiến hoàn, lịch đổi sang được, các yêu cầu đã gửi; 404 khi đơn của tài khoản khác. |
| POST | `/bookings/{code}/change` | `ChangeRequestController@store` | `type` (`cancel` / `change_date`), `schedule_id` (khi đổi ngày), `reason` (bắt buộc, tối đa 500 ký tự), `_csrf`; 422 lỗi theo ô, 409 khi đơn không đổi / hủy được hoặc đang có yêu cầu chờ xử lý. |
| GET | `/admin/change-requests` | `AdminChangeRequestController@index` | `status`: `pending` (mặc định), `approved`, `rejected`, `all`. |
| GET | `/admin/change-requests/{id}` | `AdminChangeRequestController@show` | Chi tiết yêu cầu, chính sách áp dụng, form xử lý; 404 nếu UUID sai hoặc không tìm thấy. |
| POST | `/admin/change-requests/{id}/decide` | `AdminChangeRequestController@decide` | `decision` (`approved` / `rejected`), `note` (bắt buộc), `refund` (số tiền hoàn khi đồng ý hủy, trống = số dự kiến), `_csrf`; 409 khi đã xử lý, còn chuyển khoản chờ đối chiếu hoặc lịch mới hết chỗ. |
| GET, POST | `/admin/tours/{id}/packages` | `AdminPackageController` | Danh sách, thêm, sửa, ngừng bán gói (`?edit=<mã gói>` mở form sửa); 422 lỗi theo ô, 409 trùng tên gói. |
| GET | `/admin/tours/{id}/content` | `AdminTourContentController@index` | Ảnh, lịch trình, dịch vụ, chính sách hủy và xóa tour; `?edit_item=<mã mục>` mở form sửa mục lịch trình. |
| POST | `/admin/tours/{id}/content/images`, `…/images/{imageId}/delete`, `…/images/{imageId}/cover` | `AdminTourContentController` | Thêm ảnh (`image_file` JPG / PNG / WebP tối đa 2 MB, hoặc `image_url` https), xóa ảnh, chọn ảnh bìa; tối đa 12 ảnh. |
| POST | `/admin/tours/{id}/content/itinerary`, `…/itinerary/{itemId}/delete` | `AdminTourContentController` | Thêm / sửa (`item_id`) và xóa mục lịch trình. |
| POST | `/admin/tours/{id}/content/inclusions`, `…/inclusions/{inclusionId}/delete` | `AdminTourContentController` | Thêm, xóa dịch vụ bao gồm / không bao gồm. |
| POST | `/admin/tours/{id}/content/policy` | `AdminTourContentController@addPolicy` | Lưu chính sách hủy = thêm phiên bản mới; `policy_hours` (trống = không có mốc hủy miễn phí), `policy_percent`, `policy_terms` (bắt buộc). |
| POST | `/admin/tours/{id}/delete`, `/admin/tours/{id}/restore` | `AdminTourContentController` | Xóa tour (`confirm=1`): chưa có đơn thì xóa hẳn, đã có đơn thì ngừng hiển thị, còn đơn đang xử lý → 409. Khôi phục tour ngừng hiển thị về "Chờ duyệt". |
| GET | `/admin/payouts` | `AdminPayoutController@index` | "Chi trả đơn vị tổ chức": khoản chi trả theo `status` (mặc định khoản chờ chi trả), lịch đã kết thúc còn chờ lập khoản và các khoản hoàn tiền chờ ghi nhận. |
| GET | `/admin/payouts/{id}` | `AdminPayoutController@show` | Chi tiết khoản chi trả: từng đơn, tiền thực thu, phí dịch vụ, thực nhận, tài khoản nhận tiền của đơn vị. |
| POST | `/admin/payouts/{id}/bank/verify` | `AdminPayoutController@verifyBank` | `bank_name`, `account_no`, `account_name` (tài khoản đang hiện trên trang), `_csrf`; đánh dấu tài khoản nhận tiền đã xác minh. |
| POST | `/admin/payouts/{id}/pay` | `AdminPayoutController@pay` | `reference` (mã giao dịch chuyển khoản, bắt buộc), `note`, `account_no`, `_csrf`; 422 thiếu mã giao dịch, 409 khi khoản đã chi trả, đơn vị chưa khai đủ tài khoản, tài khoản vừa đổi hoặc chưa xác minh. |
| POST | `/admin/refunds/{id}/complete` | `AdminPayoutController@completeRefund` | `reference`, `_csrf`; ghi "Đã hoàn tiền" cho khoản hoàn đã chuyển khoản lại cho khách. |
| GET, POST | `/admin/settings` | `AdminSettingController` | "Thông số vận hành": % phí dịch vụ, số phút giữ chỗ, hạn nhận đặt trước giờ khởi hành, hạn nhận chuyển khoản VietQR; 422 lỗi theo ô. |
| GET, POST | `/host/login` | `HostAuthController` | Đăng nhập khu đơn vị tổ chức: `email`, `password`, `next` (chỉ nhận đường dẫn `/host…`), `_csrf`; chỉ tài khoản `provider` đang `active` của đơn vị đang hợp tác. Đơn vị không tự đăng ký: quản trị viên cấp mật khẩu ở trang "Đơn vị tổ chức". |
| POST | `/host/logout` | `HostAuthController@logout` | `_csrf`; xong chuyển về `/host/login`. |
| GET | `/host`, `/host/tours` | `HostTourController@index` | "Tour của tôi": chỉ tour của đơn vị đang đăng nhập. |
| GET | `/host/tours/{id}` | `HostTourController@show` | Tổng quan một tour của đơn vị: trạng thái duyệt, lý do bị từ chối, phần còn thiếu; 404 khi tour của đơn vị khác. |
| GET, POST | `/host/tours/new`, `/host/tours/{id}/edit` | `HostTourFormController` | Thêm tour (bắt đầu ở "Nháp"), sửa thông tin tour đang "Nháp" hoặc "Bị từ chối". |
| POST | `/host/tours/{id}/submit` | `HostTourController@submit` | `_csrf`; gửi duyệt: tour sang "Chờ duyệt" và bị khóa tới khi quản trị viên xử lý. |
| POST | `/host/tours/{id}/revision`, `/host/tours/{id}/revision/discard` | `HostTourController` | `_csrf`; tạo hoặc hủy bản sửa của tour đã duyệt (mỗi tour tối đa một bản sửa đang mở). |
| POST | `/host/tours/{id}/archive` | `HostTourController@archive` | `_csrf`; ngừng hiển thị tour đã duyệt khi tour không còn đơn đang xử lý. |
| GET, POST | `/host/tours/{id}/schedules`, `/host/schedules/{id}/edit` | `HostScheduleController` | Lịch khởi hành, sức chứa, giá vé của tour mình; không cần duyệt. |
| GET, POST | `/host/tours/{id}/content`, `…/content/images`, `…/content/itinerary`, `…/content/inclusions`, `…/content/policy` | `HostTourContentController` | Ảnh, lịch trình, dịch vụ, chính sách hủy của tour mình, như các route `/admin/tours/{id}/content…`. |
| GET | `/host/bookings`, `/host/bookings/{id}` | `HostBookingController` | Đơn đặt tour của các tour mình, chỉ xem; lọc `status`, `tour`. |
| GET | `/host/payouts`, `/host/payouts/{id}` | `HostPayoutController` | "Doanh thu & chi trả": khoản chi trả của chính đơn vị. |
| GET, POST | `/host/bank` | `HostPayoutController` | "Tài khoản nhận tiền": `bank_name`, `bank_account_no`, `bank_account_name`, `_csrf`; đổi tài khoản thì phải được xác minh lại. |
| GET | `/ban-do` | `TourMapController@index` | Bản đồ các tour (Leaflet 1.9.4, nền OpenStreetMap). Chưa chạy `23_map_places_NTK.sql` thì "đang tạm ngưng". |
| GET | `/api/tours/{id}/places` | `TourMapController@apiPlaces` | JSON quán ăn, bar, giải trí, quán nước trong 1,5 km quanh điểm khởi hành (Overpass API gọi từ máy chủ, lưu đệm 7 ngày ở `map_place_cache`); lỗi thì dùng bản lưu cũ hoặc báo "Chưa tải được địa điểm, thử lại sau.". |
| GET, POST | `/admin/tours/{id}/location` | `AdminTourLocationController` | Đặt / xóa tọa độ điểm khởi hành của tour (bấm trên bản đồ hoặc nhập số). |
| GET | `/auth/google`, `/auth/google/callback` | `SocialAuthController` | Đăng nhập / đăng ký khách hàng bằng Google (OAuth 2.0); tự liên kết với tài khoản khách hàng đang hoạt động cùng email. Nút chỉ hiện khi đã điền khóa. |

Mọi trang `/admin…` (trừ `/admin/login`): chưa đăng nhập thì chuyển tới `/admin/login`, đăng nhập bằng tài khoản không phải quản trị viên thì nhận trang 403. Mọi trang `/host…` (trừ `/host/login`): chưa đăng nhập thì chuyển tới `/host/login`; đơn vị chỉ mở được tour, đơn đặt tour và khoản chi trả của chính mình.

Đầu vào, đầu ra và mã lỗi chi tiết xem [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md); các route đặt tour xem [02 – Yêu cầu và luồng đặt tour](../docs/sprint4/02-yeu-cau-va-luong-dat-tour.md); các route Sprint 5 xem [01 – Yêu cầu và luồng Sprint 5](../docs/sprint5/01-yeu-cau-va-luong-sprint5.md).

## Chế độ khách và tài khoản

| | Chế độ khách (chưa đăng nhập) | Đã đăng nhập |
| --- | --- | --- |
| Xem danh sách, chi tiết tour | Có | Có |
| Header | Liên kết "Đăng nhập" và nút "Đăng ký" | "Đơn của tôi", chữ cái đầu, tên tài khoản và nút "Đăng xuất" |
| Thẻ đặt tour ở trang chi tiết | Liên kết "Đăng nhập để đặt tour" (đăng nhập xong vào thẳng trang đặt tour với lịch và số khách đã chọn) và ghi chú "Bạn đang xem với tư cách khách. Đăng nhập để đặt tour." | Nút "Đặt tour" mở trang "Hoàn tất thông tin đặt tour" |
| Đặt tour, "Đơn của tôi" | Chuyển tới trang đăng nhập | Có |
| So sánh tour (tối đa 3, lưu ở trình duyệt) | Có | Có |
| Đổi ngày / hủy tour | Chuyển tới trang đăng nhập | Có, với đơn của mình |
| Thích, Bình luận, Chia sẻ, Lưu tour | Bị tắt, nhãn "Sắp có" | Bị tắt, nhãn "Sắp có" |

Trang đăng nhập và đăng ký có liên kết "Tiếp tục với tư cách khách" về trang trong `next` (mặc định `/tours`). Đã đăng nhập mà mở `/login` hoặc `/register` thì cũng được chuyển về trang đó. Chỉ tài khoản `customer` đang `active` đăng nhập được ở đây và đặt được tour; quản trị viên đăng nhập ở `/admin/login` (Bước 7), mở trang đặt tour thì nhận thông báo "Tài khoản này không đặt tour được".

## Cài đặt trên máy mới

Hướng dẫn cài đặt để chạy demo, dùng các script cài database, tạo tài khoản quản trị và kiểm tra cài đặt trong `src/scripts`, xem [Sprint 6 – Hướng dẫn cài đặt](../docs/sprint6/02-huong-dan-cai-dat.md). Các bước dưới đây là cách làm thủ công và các ca tự kiểm tra.

### Yêu cầu

- XAMPP 8.2 cho Windows (PHP 8.2, Apache, MySQL/MariaDB, phpMyAdmin).
- Git hoặc GitHub Desktop.
- Kết nối Internet (Bootstrap, jQuery và font tải từ CDN).
- Radmin VPN, nếu dùng database chung của nhóm.

### Bước 1. Lấy mã nguồn

Nếu định chạy bằng Apache của XAMPP, clone repository vào `C:\xampp\htdocs`:

```bat
cd C:\xampp\htdocs
git clone https://github.com/kannar04/LocalTour_Project.git
```

Nếu chạy bằng PHP built-in server, có thể clone vào thư mục bất kỳ.

### Bước 2. Chuẩn bị database

Chọn một trong hai cách.

**Cách A – Dùng database chung của nhóm.** Database `db_localtour` dùng chung do Phong host trên MySQL của máy Phong, truy cập qua Radmin VPN.

1. Tham gia mạng Radmin VPN của nhóm (hỏi Phong tên mạng và mật khẩu mạng).
2. Hỏi Phong địa chỉ IP của máy host trong mạng VPN và một tài khoản MySQL dành cho ứng dụng.
3. Điền các thông tin này vào `.env` ở bước 3. Không ghi chúng vào bất kỳ file nào được commit, không gửi vào nhóm chat chung.

**Cách B – Import database trên máy mình.**

1. Mở XAMPP Control Panel, bấm Start cho **MySQL**.
2. Dùng file `src/database/db_localtour.sql` trong repo. File này được gộp từ `src/database/01_schema.sql` đến `32_procedures_NTK_tour_revision.sql`.
3. Mở `http://localhost/phpmyadmin`, chọn tab **Import**, chọn file `db_localtour.sql`, giữ **Character set of the file** là `utf-8`, bấm **Import** (hoặc **Go**). File tự tạo database `db_localtour` với `utf8mb4_unicode_ci`.

Cách nhanh hơn, không cần phpMyAdmin: sau khi tạo `.env` (Bước 3), đứng ở thư mục `src` chạy `scripts\install_database.bat`. Script import mọi file `NN_*.sql` theo thứ tự vào database ghi trong `.env` và đếm lại bảng / procedure; database đã có dữ liệu thì dừng, trừ khi thêm `--fresh`.

Nếu không có file gộp: tạo database `db_localtour` với collation `utf8mb4_unicode_ci`, chọn database đó, rồi import lần lượt `01_schema.sql`, `02_seed.sql`, `03_procedures_LTP.sql`, `04_procedures_NMT.sql`, `05_procedures_NTK.sql`, `06_procedures_NTK_account.sql`, `07_procedures_NTK_admin.sql`, `08_migration_booking_NMT.sql`, `09_procedures_NMT_booking.sql`, `10_procedures_LTP_booking.sql`, `11_procedures_NTK_booking.sql`, `12_migration_sprint4_NMT.sql`, `13_procedures_NMT_catalog.sql`, `14_procedures_NMT_payment.sql`, `15_procedures_LTP_payment.sql`, `16_migration_sprint5_LTP.sql`, `17_procedures_NMT_compare.sql`, `18_procedures_LTP_package.sql`, `19_procedures_LTP_change.sql`, `20_procedures_LTP_change_admin.sql`, `21_procedures_NMT_tour_content.sql`, `22_payment_momo_NTK.sql`, `23_map_places_NTK.sql`, `24_social_login_NTK.sql`, `25_email_NTK.sql`, `26_procedures_NTK_setup.sql`, `27_procedures_NTK_host.sql`, `28_migration_economy_NTK.sql`, `29_procedures_NTK_instant_booking.sql`, `30_procedures_NTK_payout.sql`, `31_migration_host_rules_NTK.sql`, `32_procedures_NTK_tour_revision.sql`.

Import lại bất cứ lúc nào để đưa dữ liệu về trạng thái ban đầu: `01_schema.sql` xóa và tạo lại 27 bảng, đồng thời xóa 2 bảng đã bỏ (`post_comments`, `post_interactions`) và 10 bảng do các file sau thêm; `12_migration_sprint4_NMT.sql` thêm 2 bảng Sprint 4, `16_migration_sprint5_LTP.sql` thêm 2 bảng Sprint 5, `23`, `24`, `25` mỗi file thêm 1 bảng, `28_migration_economy_NTK.sql` thêm 3 bảng `settings`, `host_payouts`, `host_payout_items` (27 + 2 + 2 + 3 + 3 = tổng 37 bảng). Tài khoản đã đăng ký thử cũng bị xóa. Ngày khởi hành mẫu được tính theo ngày import, vì vậy nên import lại trước mỗi buổi kiểm thử hoặc demo. Chi tiết xem [02 – Lược đồ dữ liệu](../docs/sprint3/02-luoc-do-du-lieu.md) và `src/database/README.md`.

### Bước 3. Tạo file `.env`

Trong thư mục `src/`, sao chép `.env.example` thành `.env`:

```bat
cd src
copy .env.example .env
```

(PowerShell: `Copy-Item .env.example .env`.) Sau đó mở `.env` và điền:

| Khóa | Giá trị |
| --- | --- |
| `APP_ENV` | `local` |
| `APP_DEBUG` | Giữ `false`. Chỉ bật `true` tạm thời trên máy cá nhân khi cần xem chi tiết lỗi. |
| `APP_URL` | Để trống. Ứng dụng tự tính đường dẫn gốc theo cách đang chạy. |
| `DB_HOST` | Cách A: IP máy host trong VPN. Cách B: `127.0.0.1`. |
| `DB_PORT` | `3306` (hoặc cổng Phong cung cấp). |
| `DB_DATABASE` | `db_localtour` |
| `DB_USERNAME` | Cách A: tài khoản Phong cấp. Cách B: `root`. |
| `DB_PASSWORD` | Cách A: mật khẩu Phong cấp. Cách B: để trống (mặc định của XAMPP). |
| `PAYMENT_BANK_ID`, `PAYMENT_BANK_NAME`, `PAYMENT_ACCOUNT_NO`, `PAYMENT_ACCOUNT_NAME` | Tài khoản nhận chuyển khoản VietQR (mã ngân hàng theo VietQR, ví dụ `VCB`). Để trống thì VietQR hiện "đang tạm ngưng". |
| `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET` | Mã website và khóa bí mật VNPay sandbox. Để trống thì VNPay hiện "đang tạm ngưng". |
| `VNPAY_PAY_URL` | Giữ mặc định (cổng sandbox). |
| `VNPAY_RETURN_URL` | Để trống: ứng dụng tự tính theo địa chỉ đang mở. |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` | OAuth client loại Web application ở Google Cloud. Để trống thì ẩn nút Google. Redirect để trống thì tự tính; phải khai báo đúng địa chỉ `…/auth/google/callback` ở Google (chỉ nhận `localhost`, không nhận địa chỉ IP). |
| `RECAPTCHA_SITE_KEY`, `RECAPTCHA_SECRET_KEY` | reCAPTCHA v2 (ô "Tôi không phải người máy") ở `/login`, `/register`, `/admin/login`. Để trống thì không có captcha. |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_ENCRYPTION`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | SMTP gửi email "Đặt tour thành công" khi đơn chuyển "Đã xác nhận" (mỗi đơn một lần, nhật ký ở `email_logs`). Gmail: `smtp.gmail.com`, `587`, `tls`, mật khẩu ứng dụng 16 ký tự. Để trống `MAIL_HOST` thì không gửi. Thử: `php src/scripts/mail_check.php` (đăng nhập SMTP), `php src/scripts/mail_check.php email@cua-ban` (gửi thử). |

`.env` chứa thông tin kết nối thật và đã có trong `.gitignore`. Không commit file này và không sửa `.env.example` thành giá trị thật. Thông tin VNPay sandbox và tài khoản nhận VietQR dùng chung bộ của nhóm (đã dùng ở Home2Home); hỏi trong nhóm, không gửi vào nhóm chat chung.

### Bước 4. Chạy ứng dụng

**Cách 1 – Apache của XAMPP** (repository nằm trong `C:\xampp\htdocs\LocalTour_Project`):

1. Start **Apache** trong XAMPP Control Panel.
2. Mở `http://localhost/LocalTour_Project/src/public/`.

`src/.htaccess` chặn truy cập trực tiếp mọi thứ ngoài `public/` (`.env`, `app/`, `config/`, `database/`, `storage/`…), nên mở `http://localhost/LocalTour_Project/src/` sẽ nhận lỗi 403. Đây là hành vi đúng.

**Cách 2 – PHP built-in server** (không cần Apache):

```bat
cd src
C:\xampp\php\php.exe -S 127.0.0.1:8080 -t public public/router.php
```

Mở `http://127.0.0.1:8080`. Giữ cửa sổ dòng lệnh mở trong lúc dùng; nhấn `Ctrl+C` để dừng.

### Bước 5. Tự kiểm tra nhanh

**Database (chỉ với Cách B).** Trong phpMyAdmin, bấm `db_localtour` ở cột trái, mở tab **SQL**, chạy lần lượt từng câu:

```sql
SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'db_localtour';                                  -- 37
SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'db_localtour' AND ROUTINE_TYPE = 'PROCEDURE'; -- 157
```

Ra số khác thì xem mục "Cách 1" của `src/database/README.md` để so tên bảng và procedure. Với Cách A, tài khoản ứng dụng chỉ có quyền gọi procedure nên bỏ qua bước này; các đường dẫn dưới đây đã đủ để kiểm tra.

**Ứng dụng.** Ghép đường dẫn với gốc ứng dụng: `http://127.0.0.1:8080` (built-in server) hoặc `http://localhost/LocalTour_Project/src/public` (Apache).

| Đường dẫn | Kết quả mong đợi |
| --- | --- |
| `/tours` | Trang "Bảng tin du lịch" hiện 9 thẻ tour sau hiệu ứng tải, thẻ đầu là "Phố cổ theo cách của bạn"; bộ lọc điểm đến có 4 điểm đến, bộ lọc "Loại hình" có 5 loại hình. Header có "Đăng nhập" và "Đăng ký". |
| `/tours/c0000000-0000-4000-8000-000000000001` | Trang chi tiết của tour 1 "Hà Nội qua những món ăn phố cổ", có nút "Quay lại danh sách". Mục "Phụ thu / hoạt động tùy chọn" có nhóm "Phụ thu" (1 dòng) trước nhóm "Hoạt động tùy chọn" (1 dòng). Khi chưa đăng nhập, thẻ đặt tour có liên kết "Đăng nhập để đặt tour". |
| `/tours/c0000000-0000-4000-8000-000000009999` | Trang "Không tìm thấy tour" (HTTP 404), không có thông báo lỗi PHP. |
| `/tours/c0000000-0000-4000-8000-000000000010` | Cũng là trang "Không tìm thấy tour": tour 10 đang chờ duyệt nên không được hiển thị. |
| `/api/tours` | JSON có `"success":true`, `data.total` là 9 và `data.tours` gồm 9 tour. |
| `/api/categories` | JSON có `data.categories` gồm 5 loại hình. |
| `/api/tours/c0000000-0000-4000-8000-000000000001` | JSON có `data.tour`, `gallery`, `schedules`, `tickets`, `packages` (rỗng với tour 1), `itinerary`, `inclusions`, `extras`, `reviews`, `policy`. `data.extras` có 2 phần tử, phần tử đầu có `"kind":"surcharge"`. |
| `/login`, `/register` | Form đăng nhập / đăng ký, có liên kết "Tiếp tục với tư cách khách". |

Mã tour là UUID (chuỗi 36 ký tự), không còn là số như bản đầu tiên; `/tours/1` giờ cũng trả trang "Không tìm thấy tour". Nếu mọi dòng trong bảng cho kết quả đúng, môi trường đã sẵn sàng.

### Bước 6. Thử đăng nhập

Tài khoản trong dữ liệu mẫu có `password_hash = NULL` nên **không đăng nhập được**. Muốn thử, tự tạo tài khoản mới:

1. Mở `/register`, nhập họ tên, email tự đặt (nên dùng đuôi `@localtour.test`, không dùng email thật của người khác) và mật khẩu tối thiểu 8 ký tự. Số điện thoại không bắt buộc.
2. Sau khi đăng ký, ứng dụng đăng nhập luôn và chuyển về `/tours`; header hiện tên vừa nhập và nút "Đăng xuất".
3. Bấm "Đăng xuất", rồi vào `/login` đăng nhập lại bằng email và mật khẩu vừa tạo.
4. Kiểm tra thêm: mật khẩu sai → "Email hoặc mật khẩu không đúng."; đăng ký lại bằng email đã có → "Email này đã được dùng."; mở một tour, bấm "Đăng nhập để đặt tour" rồi đăng nhập → quay lại đúng trang tour đó.

Không ghi email hay mật khẩu thử vào tài liệu, file commit hoặc nhóm chat chung. Import lại database sẽ xóa các tài khoản này.

### Bước 7. Thử trang quản trị

Trang quản trị chỉ dành cho tài khoản `admin` đang `active`, đăng nhập ở `/admin/login` (khác trang đăng nhập của khách). Tài khoản quản trị viên mẫu có `password_hash = NULL` nên không đăng nhập được, và ứng dụng không có chức năng tự nâng quyền.

Cách nhanh nhất trên database của mình: đứng ở thư mục `src`, chạy `C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test --generate`. Script đặt mật khẩu cho tài khoản quản trị viên mẫu và in mật khẩu ra một lần (bỏ `--generate` để tự gõ mật khẩu). Hoặc làm thủ công trên database của mình (Cách B):

1. Đăng ký một tài khoản mới ở `/register` như Bước 6, rồi bấm "Đăng xuất".
2. Trong phpMyAdmin, bấm `db_localtour`, mở tab **SQL** và chạy câu dưới đây (thay bằng email vừa đăng ký):

   ```sql
   UPDATE users SET role = 'admin' WHERE email = '<email vừa đăng ký>';
   ```

3. Mở `/admin/login`, đăng nhập bằng email và mật khẩu đó; ứng dụng chuyển tới trang "Tổng quan".

| Đường dẫn | Kết quả mong đợi |
| --- | --- |
| `/admin` | 40 tài khoản khách hàng (39 đang hoạt động, 1 bị khóa), 12 tour (2 chờ duyệt, 9 đã duyệt, 1 bị từ chối), ô "Đơn chờ thanh toán" ghi 2 trên tổng 39 đơn đặt tour; bảng "Đơn đặt tour theo trạng thái" (Chờ xác nhận 3 – đơn mẫu theo quy trình cũ), bảng số đơn theo ngày tạo và doanh thu. Bấm “Tháng 10/2026” trong bảng doanh thu → trang “Khoản thanh toán theo kỳ” có 20 khoản, tổng thuần 24.930.000đ, khớp dòng của kỳ. |
| `/admin/tours` | 2 tour chờ duyệt. Mở "Một buổi chiều trong Đại Nội Huế", bấm "Phê duyệt tour" → "Đã phê duyệt tour."; `/tours` giờ có 10 tour và bộ lọc có Huế. |
| `/admin/bookings` (menu "Đơn đặt tour") | 39 đơn. Đơn đặt mới bắt đầu ở "Chờ thanh toán" và đã giữ chỗ, không cần quản trị viên xác nhận chỗ. Tab "Chờ xác nhận" có 3 đơn mẫu tạo theo quy trình cũ, dùng để thử bước xác nhận chỗ của đơn cũ: mở đơn `LT518204`, chọn "Xác nhận chỗ và giá" rồi bấm "Cập nhật trạng thái" → trạng thái "Chờ thanh toán" (hạn 24 giờ), mục "Lịch sử xử lý" có thêm một dòng, "Chỗ của lịch" giảm 2. Đơn `LT527716` cần 3 chỗ nhưng lịch chỉ còn 2 → báo "Lịch khởi hành không còn đủ chỗ…", trạng thái không đổi. Mở trang này lần đầu sau khi import, đơn mẫu `LT574913` tự chuyển "Đã hoàn thành" vì lịch đã kết thúc (tab "Đã xác nhận" còn 1 đơn, "Đã hoàn thành" 30 đơn). |
| `/admin` khi đăng nhập bằng tài khoản khách hàng | Trang 403 "Bạn không có quyền truy cập trang này." |

Với Cách A, tài khoản ứng dụng chỉ có quyền gọi procedure nên không chạy được câu `UPDATE` ở bước 2. Không ghi email hay mật khẩu của tài khoản quản trị thử vào tài liệu, file commit hoặc nhóm chat chung. Import lại database sẽ xóa tài khoản này.

### Bước 8. Thử đặt tour

Dùng tài khoản khách hàng tự tạo ở Bước 6 (tài khoản quản trị viên không đặt tour được).

1. Mở `/tours/c0000000-0000-4000-8000-000000000001`, chọn ngày còn 6 chỗ, đặt 2 người lớn và 1 trẻ em (tạm tính 1.760.000đ), bấm "Đặt tour".
2. Trang "Hoàn tất thông tin đặt tour" giữ đúng lịch và số khách vừa chọn, thông tin liên hệ điền sẵn từ tài khoản, có 3 ô họ tên khách. Mục "Điều kiện đặt tour" ghi: bấm đặt là giữ chỗ ngay, đơn ở trạng thái "Chờ thanh toán", thanh toán trong 30 phút kể từ lúc đặt, nhận đặt tới trước giờ khởi hành 1 giờ, VietQR chỉ nhận khi còn ít nhất 24 giờ tới giờ khởi hành (các số này lấy từ trang "Thông số vận hành"). Nhập số điện thoại, họ tên 3 khách, tích ô đồng ý điều kiện rồi bấm "Xem lại & xác nhận".
3. Bước xem lại hiện đủ ngày, giờ, danh sách khách và tổng tiền. Bấm "Đặt tour và thanh toán" → trang "Thanh toán đơn `LTxxxxxx`" với thông báo "Đã giữ chỗ cho đơn `LTxxxxxx`" và hạn thanh toán. Đơn đã ở trạng thái "Chờ thanh toán" và lịch đã giảm 3 chỗ; không có bước chờ quản trị viên xác nhận chỗ. Đơn có trong "Đơn của tôi" ở header; trang đơn có nút "Thanh toán ngay" để quay lại trang thanh toán.

| Thử thêm | Kết quả mong đợi |
| --- | --- |
| Bấm "Xem lại & xác nhận" khi để trống họ tên khách và chưa tích điều kiện | Báo lỗi ngay dưới từng ô, con trỏ nhảy tới ô lỗi đầu tiên; không gửi gì lên máy chủ. |
| Tour "Hội An: phố cổ, đèn lồng và hoa đăng", lịch chỉ còn 1 chỗ, đặt 2 khách | Nút "+" dừng ở 1 khách, gợi ý "lịch này còn 1 chỗ". |
| Đặt xong, mở lại `/bookings/<mã đơn>` bằng tài khoản khác | Trang "Không tìm thấy đơn" (404). |
| Quản trị viên mở đơn vừa đặt ở `/admin/bookings`, tab "Chờ thanh toán" (Bước 7) | Dòng "Chỗ của lịch" ghi "đơn này đang giữ 3 chỗ"; mục "Cập nhật trạng thái" không có lựa chọn xác nhận chỗ. Chọn "Hủy đơn" kèm lý do → khách thấy "Đã hủy" và lý do, lịch được trả lại chỗ. |
| Đặt xong nhưng không thanh toán, chờ quá hạn giữ chỗ (30 phút) rồi mở lại "Đơn của tôi" | Đơn thành "Đã hủy" với lý do quá hạn giữ chỗ, lịch được trả lại chỗ. |

| Tour 1, tích "Thêm phần chè cuối tour" (35.000đ / người) ở mục phụ thu và hoạt động tùy chọn | Với 3 khách, tạm tính cộng thêm 105.000đ; khoản "Phụ thu đi riêng" (500.000đ / nhóm) chỉ cộng một lần. Bước xem lại và trang đơn có dòng phụ thu / tùy chọn. |

### Bước 9. Thử thanh toán

Cần điền khóa VNPay sandbox và tài khoản VietQR trong `.env` (Bước 3). Đây là môi trường thử nghiệm: không chuyển tiền thật.

1. Đặt một đơn như Bước 8: đơn mới ở "Chờ thanh toán" ngay, không cần quản trị viên làm gì. Hạn thanh toán là 30 phút kể từ lúc đặt và không muộn hơn giờ khởi hành. (Chỉ đơn cũ "Chờ xác nhận" mới cần quản trị viên chọn "Xác nhận chỗ và giá", có thể sửa "Tổng giá chốt" kèm lý do; đơn đó được hạn 24 giờ.)
2. Khách ở trang "Thanh toán đơn `LTxxxxxx`" mở ra ngay sau khi đặt, hoặc mở đơn rồi bấm "Thanh toán ngay". VNPay tự xác nhận đơn; VietQR cần quản trị viên đối chiếu một lần:
   - **VNPay:** bấm "Thanh toán qua VNPay", chuyển sang cổng sandbox; thanh toán bằng thẻ thử nghiệm NCB trong tài liệu VNPay sandbox. VNPay trả về trang đơn với thông báo "Thanh toán VNPay thành công", đơn "Đã xác nhận", có voucher. Chạy ở `localhost` thì VNPay không gọi được IPN; kết quả được ghi qua Return URL.
   - **VietQR:** bấm "Lấy mã VietQR" (chỉ có khi còn ít nhất 24 giờ tới giờ khởi hành; sát giờ hơn trang ghi VietQR không dùng được cho đơn này, dùng VNPay); trang hiện mã QR đúng số tiền và nội dung `LTxxxxxxPn`; bấm "Tôi đã chuyển khoản" → khoản "Chờ đối chiếu". Quản trị viên mở "Đối chiếu thanh toán" ở menu quản trị, chọn "Đã nhận tiền" (đơn "Đã xác nhận", cấp voucher) hoặc "Không khớp" (bắt buộc lý do; khách thanh toán lại được).
3. Đơn đã thanh toán có nút "Xem và in voucher"; trang voucher in được (Ctrl+P chỉ in phần voucher). Mục "Lịch sử đơn" ghi đủ các bước.

| Thử thêm | Kết quả mong đợi |
| --- | --- |
| Hủy giao dịch ở cổng VNPay | Về trang đơn với thông báo "Bạn đã hủy giao dịch ở VNPay. Bạn có thể thanh toán lại trước hạn giữ chỗ.", đơn vẫn "Chờ thanh toán". |
| Đơn "Chờ thanh toán" quá hạn giữ chỗ (không có chuyển khoản chờ đối chiếu) | Lần mở trang tiếp theo đơn thành "Đã hủy" với lý do quá hạn, lịch được trả lại chỗ. |
| VNPay báo thành công sau khi đơn đã tự hủy | Khoản vẫn được ghi "Đã thanh toán"; trang quản trị của đơn có cảnh báo cần hoàn tiền cho khách. |
| Bấm "Thanh toán ngay" → VNPay rồi đóng tab cổng VNPay (không thanh toán, không bấm Hủy), chờ 15 phút | Khoản hiện ở mục "Giao dịch VNPay chưa rõ kết quả" của "Đối chiếu thanh toán". Ở trang yêu cầu, quản trị viên tra mã thanh toán trên cổng VNPay rồi chọn "Có giao dịch thành công" (nhập mã giao dịch VNPay; đơn còn hạn thì "Đã xác nhận" và có voucher, đơn đã hủy thì tạo yêu cầu hoàn tiền) hoặc "Không có giao dịch" (bắt buộc lý do; khách thanh toán lại được). |

**Tự hủy và việc sau tour định kỳ:** `expire_holds.php` hủy đơn quá hạn giữ chỗ, rồi chuyển đơn "Đã xác nhận" của lịch đã kết thúc sang "Đã hoàn thành" và lập khoản chi trả cho đơn vị tổ chức (Bước 12). Ngoài việc chạy mỗi lần mở trang đơn hoặc trang quản trị, cài lịch chạy `expire_holds.php` mỗi 15 phút trên máy chạy demo. Khi đã có `src/.env` và MySQL đang chạy, mở Command Prompt ở thư mục `src\scripts` rồi chạy:

```bat
register_expire_task.bat
```

Script chạy thử `expire_holds.php` một lần (in "đã hủy N đơn quá hạn thanh toán" và "đã tự hoàn thành N đơn, N lịch khởi hành; đã lập N khoản chi trả"; lỗi kết nối database thì dừng, không đăng ký), rồi tạo task "LocalTour - Tu huy don qua han" chạy mỗi 15 phút bằng `php-win.exe` (không hiện cửa sổ). PHP không nằm ở `C:\xampp\php` thì thêm thư mục PHP: `register_expire_task.bat D:\xampp\php`. Gỡ lịch: `register_expire_task.bat /delete`. Task chỉ chạy khi tài khoản Windows đó đang đăng nhập. `expire_holds.php` chỉ chạy được từ dòng lệnh.

### Bước 10. Thử quản lý đơn vị tổ chức, tour và lịch

Đăng nhập quản trị (Bước 7):

| Đường dẫn | Kết quả mong đợi |
| --- | --- |
| `/admin/providers` → "Thêm đơn vị" | Thêm đơn vị mới; email trùng (kể cả khác hoa thường) báo "đã được dùng". Đổi sang "Ngừng hợp tác" thì tour của đơn vị bị ẩn ở trang khách. Đơn vị chưa có tour có ô "Xóa đơn vị"; đơn vị còn tour không xóa được (Sprint 5). |
| `/admin/tours` → "Thêm tour" | Tour mới ở "Chờ duyệt"; chọn "Đã xác minh" mà không có nguồn thì báo lỗi ở ô nguồn. |
| Chi tiết tour → "Lịch khởi hành và giá vé" | Thêm lịch (sức chứa, giá người lớn, giá trẻ em không bắt buộc). Hủy lịch còn đơn đang giữ chỗ → báo lỗi; giảm sức chứa dưới số chỗ đang giữ → báo lỗi. Đổi giá không đổi giá của đơn đã đặt. |

### Bước 11. Thử so sánh tour, gói tour và đổi ngày / hủy tour (Sprint 5)

| Thử | Kết quả mong đợi |
| --- | --- |
| `/tours`, bấm "Thêm vào so sánh" ở 3 thẻ tour | Khung "Tour đang so sánh" có 3 tour; thêm tour thứ 4 → "Chỉ so sánh tối đa 3 tour…". Bấm "So sánh tour" → `/compare?ids=…` đặt 3 tour cạnh nhau theo nhóm (giá / người, thời lượng, quy mô nhóm, chính sách hủy, lịch trình, dịch vụ…); ô thiếu ghi "Chưa cập nhật". Tải lại trang, các tour đã chọn vẫn còn. |
| `/compare?ids=c0000000-0000-4000-8000-000000000001` | "Cần ít nhất 2 tour để so sánh". |
| `/tours/c0000000-0000-4000-8000-000000000003` | Mục "Gói tour" có 3 gói; thẻ đặt tour có ô chọn gói, giá vé tính theo gói. Chọn "Đền chùa và tín ngưỡng", 2 người lớn → tạm tính 1.900.000đ; trang đơn ghi tên gói. Tour 1 không có gói, đặt như Bước 8. |
| Mở một đơn ở "Đơn của tôi" → "Đổi ngày / hủy tour" | Trang hiện chính sách hủy của đơn, tiền đã trả và số tiền dự kiến hoàn. Gửi yêu cầu hủy (lý do bắt buộc) → yêu cầu "Chờ xử lý"; khi yêu cầu chưa xử lý thì không gửi được yêu cầu thứ hai. Đổi ngày phải chọn lịch mới cùng tour. |
| Quản trị: "Đổi ngày / hủy tour" ở menu | Mở yêu cầu, chọn đồng ý hoặc từ chối và ghi kết quả (bắt buộc). Đồng ý hủy: đơn "Đã hủy", lịch được trả chỗ; đơn đã thanh toán có khoản hoàn "requested" để hoàn tay (chưa tự động hoàn tiền). Đồng ý đổi ngày: đơn chuyển sang lịch mới. Khách thấy kết quả ở trang đơn và trang đổi / hủy. |
| Quản trị: chi tiết tour → "Gói tour" | Thêm / sửa gói (tên, giá người lớn, giá trẻ em không bắt buộc); trùng tên báo lỗi; "Ngừng bán" thì gói không còn ở trang khách, đơn cũ vẫn giữ tên gói. |
| Quản trị: chi tiết tour → "Ảnh, lịch trình, dịch vụ, chính sách" | Tải ảnh JPG / PNG / WebP tối đa 2 MB (file khác hoặc quá lớn báo lỗi), chọn ảnh bìa, xóa ảnh; thêm / sửa / xóa lịch trình và dịch vụ; lưu chính sách hủy tạo phiên bản mới. "Xóa tour": tour chưa có đơn bị xóa hẳn; tour đã có đơn chuyển "Ngừng hiển thị" (khách mở thì 404); còn đơn đang xử lý thì báo lỗi. |

Ảnh tải lên nằm ở `src/public/assets/uploads/tours/` trên máy chạy web, không có trong Git. Khi đóng gói demo hoặc chép database sang máy khác, chép kèm thư mục này; ảnh nào không có file trên máy đang chạy thì trang hiện ảnh thay thế (`img/tour-placeholder.svg`), không hiện ảnh vỡ.

### Bước 12. Thử thông số vận hành và chi trả đơn vị tổ chức

Khách trả đúng giá niêm yết cho LocalTour. Sau khi lịch khởi hành kết thúc, LocalTour giữ phí dịch vụ (mặc định 10 %, chụp vào đơn lúc đặt) trên tiền thực thu của từng đơn và chi trả phần còn lại cho đơn vị tổ chức. Việc chuyển khoản làm ngoài hệ thống; ứng dụng chỉ ghi nhận.

| Trang | Kết quả mong đợi |
| --- | --- |
| Quản trị: "Thông số vận hành" (`/admin/settings`) | Bốn ô: "Phí dịch vụ LocalTour" (%), "Thời gian giữ chỗ" (phút), hạn nhận đặt trước giờ khởi hành (phút), hạn nhận VietQR (giờ); mặc định 10, 30, 60, 24. Bấm "Lưu thông số" → "Đã lưu thông số vận hành."; nhập ngoài khoảng cho phép thì báo lỗi ở ô đó. Thông số mới áp dụng cho đơn đặt sau khi lưu và hiện ở mục "Điều kiện đặt tour" của trang đặt tour (Bước 8); đơn đã có giữ mức phí và hạn giữ chỗ cũ. |
| Quản trị: "Chi trả đơn vị tổ chức" (`/admin/payouts`) | Ngay sau khi import chưa có khoản chi trả nào. Mỗi lịch khởi hành đã kết thúc, có tiền khách đã trả và không còn việc dang dở có một khoản chi trả: tiền thực thu (tiền khách đã trả trừ tiền đã hoàn), phí dịch vụ, thực nhận. Mở khoản "Chờ chi trả", nhập "Mã giao dịch chuyển khoản" rồi bấm "Ghi nhận đã chi trả" → khoản "Đã chi trả"; đơn vị chưa khai tài khoản nhận tiền hoặc tài khoản chưa được xác minh thì chưa ghi nhận được. Xác minh ở mục "Đơn vị nhận tiền" của khoản chi trả: kiểm tra lại với đơn vị rồi bấm "Đã kiểm tra, xác minh tài khoản này"; đơn vị đổi tài khoản thì phải xác minh lại. Mục "Hoàn tiền cho khách" liệt kê khoản hoàn còn phải chuyển lại cho khách (yêu cầu hủy được đồng ý, quản trị viên hủy đơn đã thanh toán, tiền tới sau khi đơn đã đóng): nhập mã giao dịch rồi bấm "Đã hoàn tiền". Mục "Lịch đã kết thúc, chưa lập được khoản chi trả" ghi việc còn dang dở của từng lịch (đơn chưa xong, chuyển khoản chờ đối chiếu, khoản hoàn chưa ghi, yêu cầu đổi ngày / hủy chờ xử lý). |
| Đơn vị tổ chức: "Tài khoản nhận tiền" (`/host/bank`) | Đăng nhập ở `/host/login` bằng tài khoản đơn vị tổ chức. Nhập "Ngân hàng", "Số tài khoản" (6–20 chữ số), "Tên chủ tài khoản", bấm "Lưu tài khoản" → "Đã lưu tài khoản nhận tiền.". Tài khoản mới khai hoặc vừa đổi ở trạng thái "Chờ LocalTour xác minh"; quản trị viên xác minh xong thì khoản chi trả mới được ghi nhận. |
| Đơn vị tổ chức: "Doanh thu & chi trả" (`/host/payouts`) | Chỉ có khoản chi trả của chính đơn vị: tiền thực thu, phí dịch vụ, thực nhận, trạng thái và mã giao dịch khi LocalTour đã chuyển khoản; chỉ đọc. Chưa khai tài khoản nhận tiền thì trang có cảnh báo kèm liên kết "Khai tài khoản nhận tiền". |

Khoản chi trả chỉ được lập cho lịch kết thúc sau mốc bắt đầu (thời điểm `28_migration_economy_NTK.sql` chạy lần đầu, ghi ở hai trang quản trị trên), nên các lịch mẫu đã qua không có khoản chi trả. Đơn "Đã xác nhận" của lịch đã kết thúc tự chuyển "Đã hoàn thành", khoản chi trả được lập khi mở trang đơn, trang quản trị hoặc khi `scripts/expire_holds.php` chạy (task ở Bước 9); không cần bấm gì thêm. Route: `GET /admin/payouts`, `GET /admin/payouts/{id}`, `POST /admin/payouts/{id}/pay`, `POST /admin/payouts/{id}/bank/verify`, `POST /admin/refunds/{id}/complete`, `GET`, `POST /admin/settings`, `GET /host/payouts`, `GET /host/payouts/{id}`, `GET`, `POST /host/bank`.

## Bảo mật

- Mật khẩu chỉ được băm bằng `password_hash(PASSWORD_DEFAULT)` và kiểm tra bằng `password_verify()`; database chỉ lưu chuỗi băm. Không lưu, ghi log hay điền lại mật khẩu gốc vào form.
- Đăng nhập sai vì bất kỳ lý do nào cũng chỉ hiện một thông báo chung, không cho biết email có tồn tại hay không.
- Cookie phiên `httponly`, `SameSite=Lax`, `secure` khi chạy HTTPS; bật `session.use_strict_mode` và đổi session id sau khi đăng nhập. Session chỉ lưu `user_id`, `name`, `email`, `role`.
- Mọi form POST có ô ẩn `_csrf` (`csrf_field()`); controller kiểm tra bằng `Auth::verifyCsrf()` trước khi xử lý. Đăng xuất chỉ bằng POST.
- Tham số `next` chỉ nhận đường dẫn trong ứng dụng (`safe_next_path()`), không chuyển hướng ra trang ngoài.
- Trang `/admin…` chỉ cho tài khoản `admin`; procedure ghi dữ liệu của trang quản trị kiểm tra lại người thao tác là quản trị viên đang hoạt động. Mọi lần phê duyệt tour và đổi trạng thái yêu cầu đặt tour được ghi vào `admin_logs` (người thao tác, thời điểm, trạng thái cũ, trạng thái mới, lý do). Không có route hay procedure nào nâng quyền tài khoản.
- Đặt tour: `user_id` của đơn lấy từ phiên đăng nhập, không nhận từ form. Giá và tổng tiền được tính lại trong `LTP_sp_booking_create` từ giá vé đang bán; số tiền gửi lên chỉ để phát hiện giá đã đổi. Mỗi lần mở form có một `request_token`; gửi lại cùng mã (bấm hai lần, mạng lỗi) không tạo đơn thứ hai. Trang "Đơn của tôi" chỉ trả đơn của chính tài khoản và không cho trình duyệt lưu đệm (`Cache-Control: no-store`).
- Ảnh tour tải lên (Sprint 5): chỉ trang quản trị nhận; kiểm tra kích thước (tối đa 2 MB) và nội dung file thật là JPG / PNG / WebP, lưu tên ngẫu nhiên, không dùng tên file gốc. Ảnh qua đường dẫn chỉ nhận `https://`. Yêu cầu đổi ngày / hủy chỉ gửi được cho đơn của chính tài khoản; quyết định của quản trị viên ghi vào `admin_logs`; số tiền hoàn không vượt tiền đã trả và không tự chuyển tiền.
- Không commit `.env`, mật khẩu, khóa bí mật, địa chỉ IP thật, file log hay tài khoản thử.

## Khuyến nghị cho máy host database chung (Phong)

**Tài khoản riêng cho ứng dụng, chỉ có quyền `EXECUTE`.** Các procedure được tạo không có `DEFINER`, nên nhận tài khoản đã import (ví dụ `root@localhost`) làm definer và chạy với quyền của tài khoản đó. Tài khoản ứng dụng chỉ cần quyền gọi procedure, kể cả khi đăng ký tài khoản khách hàng; nếu thông tin `.env` của một thành viên bị lộ, tài khoản này cũng không đọc trực tiếp hay sửa được bảng.

```sql
CREATE USER 'localtour_app'@'<tiền tố IP của VPN>.%' IDENTIFIED BY '<mật khẩu mạnh>';
GRANT EXECUTE ON db_localtour.* TO 'localtour_app'@'<tiền tố IP của VPN>.%';
```

- Thay hai giá trị trong dấu `< >` bằng giá trị thật trên máy host; không ghi giá trị thật vào repository.
- Import `db_localtour.sql` bằng tài khoản quản trị trên chính máy host và giữ nguyên tài khoản đó, vì procedure cần definer còn tồn tại.
- Thành viên cần xem bảng bằng phpMyAdmin thì dùng Cách B trên máy mình, không cấp thêm quyền cho tài khoản ứng dụng.
- Không mở `root` cho kết nối từ xa.

**Chỉ mở MySQL trên mạng VPN.**

- Tạo luật Inbound trong Windows Defender Firewall cho cổng TCP 3306, phần **Remote IP address** chỉ cho phép dải IP của Radmin VPN; không mở cổng 3306 cho mạng khác.
- Thanh toán: số tiền lấy từ `bookings.total_vnd` trong database, không nhận từ form. Kết quả VNPay (Return URL, IPN) chỉ được ghi khi chữ ký HMAC-SHA512 khớp và số tiền khớp khoản thanh toán; gọi lại cùng giao dịch không ghi lần hai. Khóa VNPay và tài khoản nhận tiền chỉ nằm trong `.env`. Trang thanh toán và voucher không cho trình duyệt lưu đệm.
- Không chuyển tiếp (port forwarding) cổng 3306 trên router.
- Nếu `my.ini` có `bind-address=127.0.0.1`, MySQL chỉ nhận kết nối trong máy. Có thể đặt `bind-address` là IP của card Radmin VPN; khi đó phpMyAdmin trên máy host cũng phải kết nối qua IP này. Cách đơn giản hơn là giữ MySQL lắng nghe mọi địa chỉ và dựa vào luật tường lửa ở trên.

## Xử lý sự cố

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
| --- | --- | --- |
| Trang lỗi 503 hoặc JSON 503 "Không thể kết nối cơ sở dữ liệu", trong `storage/logs/app.log` có `could not find driver` | PHP chưa bật driver PDO MySQL. | Mở `C:\xampp\php\php.ini`, bỏ dấu `;` trước dòng `extension=pdo_mysql`, lưu file rồi khởi động lại Apache hoặc built-in server. |
| 503 "Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau." | Sai thông tin trong `.env`; MySQL chưa chạy; mất kết nối Radmin VPN; tường lửa máy host chặn. | Kiểm tra lại `.env`; với Cách B, Start MySQL trong XAMPP; với Cách A, kiểm tra Radmin VPN đã kết nối và máy Phong đang bật MySQL. |
| Dưới Apache, mọi trang (trừ trang chủ) đều 404 của Apache | `mod_rewrite` bị tắt hoặc `.htaccess` bị bỏ qua. | Trong `C:\xampp\apache\conf\httpd.conf`: bỏ dấu `#` trước `LoadModule rewrite_module modules/mod_rewrite.so`; trong khối `<Directory "C:/xampp/htdocs">` đặt `AllowOverride All`. Khởi động lại Apache. |
| `http://localhost/LocalTour_Project/src/` báo 403 | Hành vi đúng: `src/.htaccess` chặn mọi thứ ngoài `public/`. | Mở `http://localhost/LocalTour_Project/src/public/`. |
| Tiếng Việt hiển thị sai (`Ã¡`, `?`) | File SQL được import với bảng mã khác UTF-8, hoặc database tạo sai collation. | Import lại `db_localtour.sql`, chọn character set `utf-8`; database phải dùng `utf8mb4` và `utf8mb4_unicode_ci`. |
| Trang lỗi 500, log có `PROCEDURE db_localtour.… does not exist` | Chưa import đủ các file procedure. | Import lại `db_localtour.sql`, hoặc import `03` đến `30` theo thứ tự. |
| Trang lỗi 500, log có `Unknown column` (ví dụ `request_token`) hoặc `Table 'db_localtour.…' doesn't exist` | Database vẫn là lược đồ cũ (chưa chạy `08_migration_booking_NMT.sql` / `12_migration_sprint4_NMT.sql` / `16_migration_sprint5_LTP.sql` / `31_migration_host_rules_NTK.sql` / `28_migration_economy_NTK.sql` – thiếu bảng `settings` thì trang danh sách, chi tiết và đặt tour đều lỗi; hoặc trước lược đồ 27 bảng), hoặc file gộp được sinh từ bản cũ. | Sinh lại `db_localtour.sql` từ `01`–`32` mới nhất rồi import lại. Database dùng chung đang có dữ liệu: chạy `28` → `32` rồi chạy lại các file procedure đã đổi (danh sách ở `src/database/README.md`). |
| Tải ảnh tour báo "Chưa lưu được ảnh trên máy chủ" | PHP không tạo / ghi được thư mục `src/public/assets/uploads/tours/`. | Cho tài khoản chạy Apache / PHP quyền ghi vào `src/public/assets/uploads/` (repo có sẵn file `.gitkeep`). |
| Ảnh tour chỉ hiện ô xám có biểu tượng ảnh | Database có ảnh tải lên ở máy khác, file ảnh không có trên máy này. | Chép thư mục `src/public/assets/uploads/tours/` từ máy đã tải ảnh lên. |
| Bấm "Đặt tour và thanh toán" báo "Giá vừa thay đổi", "Lịch này chỉ còn X chỗ", "Lịch này vừa hết chỗ" hoặc "Lịch này không còn nhận đặt" | Hành vi đúng: giá, số chỗ hoặc lịch đã đổi từ lúc mở trang (đơn khác vừa giữ chỗ, giá vé được sửa, hoặc đã qua hạn nhận đặt trước giờ khởi hành). | Xem lại tổng tiền / số khách mới trên form (hoặc chọn ngày khác) rồi bấm "Xem lại & xác nhận" lần nữa. |
| Trang thanh toán ghi VNPay hoặc VietQR "đang tạm ngưng" | Thiếu khóa trong `.env`. | Điền các khóa `VNPAY_…` / `PAYMENT_…` (Bước 3) rồi tải lại trang. |
| Cổng VNPay báo lỗi chữ ký hoặc "Website không tồn tại" | `VNPAY_HASH_SECRET` / `VNPAY_TMN_CODE` sai, thừa khoảng trắng, hoặc lấy nhầm bộ khóa. | Chép lại đúng hai giá trị sandbox vào `.env`. |
| Mọi tour đều "Chưa có lịch khởi hành sắp tới" | Dữ liệu mẫu đã import từ lâu, các ngày khởi hành đã qua. | Import lại `db_localtour.sql`. |
| Đăng nhập bằng tài khoản mẫu luôn báo "Email hoặc mật khẩu không đúng." | Hành vi đúng: tài khoản mẫu có `password_hash = NULL`. | Đăng ký tài khoản mới ở `/register` (Bước 6). |
| Mở `/admin` bị chuyển tới "Đăng nhập quản trị" hoặc nhận trang 403 | Chưa đăng nhập quản trị, hoặc đang đăng nhập bằng tài khoản khách hàng (kể cả tài khoản vừa được đổi `role` mà chưa đăng nhập lại). | Đăng xuất, rồi đăng nhập ở `/admin/login` bằng tài khoản `admin` (Bước 7). |
| Gửi form báo "Phiên làm việc đã hết hạn, vui lòng thử lại." | Mã CSRF không khớp: phiên đã hết hoặc bị xóa (đăng xuất ở tab khác, import lại, khởi động lại server), hoặc trình duyệt chặn cookie. | Tải lại trang rồi gửi lại form; kiểm tra trình duyệt cho phép cookie của trang. |
| Built-in server: trang không có CSS hoặc mọi đường dẫn đều về trang lỗi | Chạy lệnh sai thư mục hoặc thiếu `public/router.php`. | Chạy đúng lệnh ở Bước 4 từ thư mục `src/`. |
| Built-in server báo cổng đang được dùng, hoặc báo "started" nhưng trình duyệt mở ra trang cũ / trang của chương trình khác | Cổng 8080 đã bị chương trình khác chiếm (thường là cửa sổ built-in server mở từ trước). Trên Windows, built-in server có thể vẫn báo "started" khi cổng đã bị chiếm. | Chạy `netstat -ano \| findstr :8080` để xem cổng có đang bị giữ không (cột cuối là PID); đóng cửa sổ cũ, hoặc đổi sang cổng khác, ví dụ `127.0.0.1:8081`. |
| Trang không có giao diện Bootstrap, nút không phản hồi | Máy không có Internet nên không tải được CSS/JS từ CDN. | Kiểm tra kết nối mạng rồi tải lại trang. |
| Bản đồ chỉ có danh sách địa điểm, không có nền bản đồ | Mạng chặn tên miền `openstreetmap.org`. | Bật DNS bảo mật (Secure DNS) trong trình duyệt hoặc đổi mạng. |
| Liên kết hoặc ảnh trỏ sai địa chỉ | `APP_URL` trong `.env` bị điền sai. | Để trống `APP_URL`. |
| Không rõ máy còn thiếu bước cài đặt nào | — | Đứng ở thư mục `src`, chạy `C:\xampp\php\php.exe scripts\check_install.php`: mỗi dòng `LỖI` / `CẢNH BÁO` ghi kèm cách sửa. Bảng xử lý sự cố đầy đủ ở [Sprint 6 – Hướng dẫn cài đặt](../docs/sprint6/02-huong-dan-cai-dat.md). |
| Trang lỗi 500 không rõ nguyên nhân | Lỗi PHP hoặc SQL. | Xem dòng cuối của `src/storage/logs/app.log`; nếu cần, bật `APP_DEBUG=true` tạm thời trên máy cá nhân rồi tắt lại. |

## Quy ước khi sửa mã

- Chỉ truy cập dữ liệu qua `Core\Database::call('<TIỀN TỐ>_sp_<tên>', [...])`; không viết `SELECT`, `INSERT`, `UPDATE`, `DELETE` trong PHP.
- Escape mọi giá trị in ra HTML bằng `e()`; trong JavaScript dựng DOM bằng `.text()` hoặc `document.createElement`.
- Mọi form POST phải có `<?= csrf_field() ?>`; controller kiểm tra `Auth::verifyCsrf()` trước khi xử lý.
- Thêm route trong `routes/web.php`, cập nhật [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md) trong cùng lần thay đổi.
- Không commit `.env`, mật khẩu, địa chỉ IP thật hay file log.
- Sửa `src/database/01`–`32` thì sinh lại `src/database/db_localtour.sql` và commit cùng lúc (cách sinh xem [database/README.md](database/README.md)).
