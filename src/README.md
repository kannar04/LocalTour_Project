# LocalTour – Mã nguồn ứng dụng

Thư mục `src/` chứa LocalTour Increment v0.1 của Sprint 3: trang danh sách tour và trang chi tiết tour, đọc dữ liệu từ MySQL qua stored procedure. Toàn bộ dữ liệu tour, giá và đánh giá là dữ liệu minh họa.

Tài liệu thiết kế đi kèm:

- [01 – Danh mục trường dữ liệu](../docs/sprint3/01-truong-du-lieu.md)
- [02 – Lược đồ dữ liệu](../docs/sprint3/02-luoc-do-du-lieu.md)
- [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md)

## Công nghệ

| Thành phần | Công nghệ |
| --- | --- |
| Máy chủ | PHP 8.2 thuần, hướng đối tượng, mô hình MVC tự xây; không dùng framework hay Composer. |
| Cơ sở dữ liệu | MySQL (MariaDB 10.4 trong XAMPP 8.2), kết nối bằng PDO; ứng dụng chỉ gọi stored procedure. |
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
│   │   └── TourDetailController.php
│   ├── models/
│   │   ├── TourListModel.php
│   │   ├── TourDetailModel.php
│   │   └── TourContentModel.php
│   └── views/
│       ├── errors/               # 404.php, 500.php
│       ├── layouts/              # main.php
│       ├── partials/             # header.php, sidebar.php, footer.php
│       └── tours/                # index.php, show.php, not-found.php
├── config/                       # app.php, database.php (đọc giá trị từ .env)
├── core/                         # bootstrap.php, Router.php, Controller.php, Database.php,
│                                 # DatabaseException.php, Env.php, helpers.php
├── database/
│   ├── 01_schema.sql
│   ├── 02_seed.sql
│   ├── 03_procedures_LTP.sql
│   ├── 04_procedures_NMT.sql
│   ├── 05_procedures_NTK.sql
│   └── README.md
├── public/                       # Thư mục web duy nhất trình duyệt truy cập được
│   ├── .htaccess                 # Chuyển mọi đường dẫn về index.php (Apache)
│   ├── index.php                 # Front controller
│   ├── router.php                # Router cho PHP built-in server
│   └── assets/
│       ├── css/                  # base.css, tour-list.css, tour-detail.css
│       ├── js/                   # app.js, tour-list.js, tour-detail.js
│       └── img/                  # Ảnh SVG minh họa
├── routes/
│   └── web.php                   # Khai báo route
└── storage/
    └── logs/                     # app.log sinh khi chạy, không đưa lên Git
```

Tiền tố tên procedure cho biết người phụ trách: `LTP_` – Lê Trung Phong, `NMT_` – Nguyễn Minh Thức, `NTK_` – Nguyễn Tuấn Khôi.

## Cài đặt trên máy mới

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

Nếu chạy bằng PHP built-in server, có thể clone vào thư mục bất kỳ. Khi mã Sprint 3 chưa được hợp nhất vào `main`, chuyển sang nhánh Sprint 3 mà nhóm đang dùng.

### Bước 2. Chuẩn bị database

Chọn một trong hai cách.

**Cách A – Dùng database chung của nhóm.** Database `db_localtour` dùng chung do Phong host trên MySQL của máy Phong, truy cập qua Radmin VPN.

1. Tham gia mạng Radmin VPN của nhóm (hỏi Phong tên mạng và mật khẩu mạng).
2. Hỏi Phong địa chỉ IP của máy host trong mạng VPN và một tài khoản MySQL dành cho ứng dụng.
3. Điền các thông tin này vào `.env` ở bước 3. Không ghi chúng vào bất kỳ file nào được commit, không gửi vào nhóm chat chung.

**Cách B – Import database trên máy mình.**

1. Mở XAMPP Control Panel, bấm Start cho **MySQL**.
2. Lấy file `db_localtour.sql` từ Phong. File này được gộp từ `src/database/01_schema.sql` đến `05_procedures_NTK.sql` và không có trong Git.
3. Mở `http://localhost/phpmyadmin`, chọn tab **Import**, chọn file `db_localtour.sql`, giữ **Character set of the file** là `utf-8`, bấm **Import** (hoặc **Go**). File tự tạo database `db_localtour` với `utf8mb4_unicode_ci`.

Nếu không có file gộp: tạo database `db_localtour` với collation `utf8mb4_unicode_ci`, chọn database đó, rồi import lần lượt `01_schema.sql`, `02_seed.sql`, `03_procedures_LTP.sql`, `04_procedures_NMT.sql`, `05_procedures_NTK.sql`.

Import lại bất cứ lúc nào để đưa dữ liệu về trạng thái ban đầu: `01_schema.sql` xóa và tạo lại các bảng. Ngày khởi hành mẫu được tính theo ngày import, vì vậy nên import lại trước mỗi buổi kiểm thử hoặc demo. Chi tiết xem [02 – Lược đồ dữ liệu](../docs/sprint3/02-luoc-do-du-lieu.md) và `src/database/README.md`.

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

`.env` chứa thông tin kết nối thật và đã có trong `.gitignore`. Không commit file này và không sửa `.env.example` thành giá trị thật.

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

Ghép đường dẫn với gốc ứng dụng: `http://127.0.0.1:8080` (built-in server) hoặc `http://localhost/LocalTour_Project/src/public` (Apache).

| Đường dẫn | Kết quả mong đợi |
| --- | --- |
| `/tours` | Trang "Bảng tin du lịch" hiện thẻ tour sau hiệu ứng tải; bộ lọc điểm đến có dữ liệu. |
| `/tours/1` | Trang chi tiết của tour có ID 1, có nút "Quay lại danh sách". |
| `/tours/9999` | Trang "Không tìm thấy tour" (HTTP 404), không có thông báo lỗi PHP. |
| `/api/tours` | JSON có `"success":true` và `data.tours` gồm 9 tour. |
| `/api/tours/1` | JSON có `data.tour`, `schedules`, `itinerary`, `images`, `inclusions`, `reviews`. |

Nếu cả năm đường dẫn cho kết quả đúng, môi trường đã sẵn sàng.

## Khuyến nghị cho máy host database chung (Phong)

**Tài khoản riêng cho ứng dụng, chỉ có quyền `EXECUTE`.** Các procedure được tạo không có `DEFINER`, nên nhận tài khoản đã import (ví dụ `root@localhost`) làm definer và chạy với quyền của tài khoản đó. Tài khoản ứng dụng chỉ cần quyền gọi procedure; nếu thông tin `.env` của một thành viên bị lộ, tài khoản này cũng không đọc trực tiếp hay sửa được bảng.

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
| Trang lỗi 500, log có `PROCEDURE db_localtour.… does not exist` | Chưa import đủ các file procedure. | Import lại `db_localtour.sql`, hoặc import `03`, `04`, `05` theo thứ tự. |
| Mọi tour đều "Chưa có lịch khởi hành sắp tới" | Dữ liệu mẫu đã import từ lâu, các ngày khởi hành đã qua. | Import lại `db_localtour.sql`. |
| Built-in server: trang không có CSS hoặc mọi đường dẫn đều về trang lỗi | Chạy lệnh sai thư mục hoặc thiếu `public/router.php`. | Chạy đúng lệnh ở Bước 4 từ thư mục `src/`. |
| Built-in server không khởi động, báo cổng đang được dùng | Cổng 8080 đã bị chương trình khác chiếm. | Đổi sang cổng khác, ví dụ `127.0.0.1:8081`. |
| Trang không có giao diện Bootstrap, nút không phản hồi | Máy không có Internet nên không tải được CSS/JS từ CDN. | Kiểm tra kết nối mạng rồi tải lại trang. |
| Liên kết hoặc ảnh trỏ sai địa chỉ | `APP_URL` trong `.env` bị điền sai. | Để trống `APP_URL`. |
| Trang lỗi 500 không rõ nguyên nhân | Lỗi PHP hoặc SQL. | Xem dòng cuối của `src/storage/logs/app.log`; nếu cần, bật `APP_DEBUG=true` tạm thời trên máy cá nhân rồi tắt lại. |

## Quy ước khi sửa mã

- Chỉ truy cập dữ liệu qua `Core\Database::call('<TIỀN TỐ>_sp_<tên>', [...])`; không viết `SELECT`, `INSERT`, `UPDATE`, `DELETE` trong PHP.
- Escape mọi giá trị in ra HTML bằng `e()`; trong JavaScript dựng DOM bằng `.text()` hoặc `document.createElement`.
- Thêm route trong `routes/web.php`, cập nhật [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md) trong cùng lần thay đổi.
- Không commit `.env`, mật khẩu, địa chỉ IP thật, file log hay `db_localtour.sql`.
