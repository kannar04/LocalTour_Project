# LocalTour – Mã nguồn ứng dụng

Thư mục `src/` chứa LocalTour Increment v0.1 của Sprint 3: trang danh sách tour, trang chi tiết tour và tài khoản khách hàng (đăng ký, đăng nhập, đăng xuất), đọc và ghi dữ liệu MySQL qua stored procedure. Toàn bộ dữ liệu tour, giá, tài khoản và đánh giá là dữ liệu minh họa.

Tài liệu thiết kế đi kèm:

- [01 – Danh mục trường dữ liệu](../docs/sprint3/01-truong-du-lieu.md)
- [02 – Lược đồ dữ liệu](../docs/sprint3/02-luoc-do-du-lieu.md)
- [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md)

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
│   │   └── AuthController.php    # Đăng ký, đăng nhập, đăng xuất
│   ├── models/
│   │   ├── TourListModel.php
│   │   ├── TourDetailModel.php
│   │   ├── TourContentModel.php
│   │   └── UserModel.php         # Tài khoản khách hàng
│   └── views/
│       ├── auth/                 # login.php, register.php
│       ├── errors/               # 404.php, 500.php
│       ├── layouts/              # main.php
│       ├── partials/             # header.php (nút tài khoản), sidebar.php, footer.php
│       └── tours/                # index.php, show.php, not-found.php
├── config/                       # app.php, database.php (đọc giá trị từ .env)
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
│   ├── db_localtour.sql          # File gộp 01–06, sinh tự động
│   └── README.md
├── public/                       # Thư mục web duy nhất trình duyệt truy cập được
│   ├── .htaccess                 # Chuyển mọi đường dẫn về index.php (Apache)
│   ├── index.php                 # Front controller
│   ├── router.php                # Router cho PHP built-in server
│   └── assets/
│       ├── css/                  # base.css, tour-list.css, tour-detail.css, auth.css
│       ├── js/                   # app.js, tour-list.js, tour-detail.js
│       └── img/                  # Ảnh SVG minh họa; bảng tour_images lưu đường dẫn tới các file này
├── routes/
│   └── web.php                   # Khai báo route
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

Đầu vào, đầu ra và mã lỗi chi tiết xem [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md).

## Chế độ khách và tài khoản

| | Chế độ khách (chưa đăng nhập) | Đã đăng nhập |
| --- | --- | --- |
| Xem danh sách, chi tiết tour | Có | Có |
| Header | Liên kết "Đăng nhập" và nút "Đăng ký" | Chữ cái đầu, tên tài khoản và nút "Đăng xuất" |
| Thẻ đặt tour ở trang chi tiết | Liên kết "Đăng nhập để đặt tour" (quay lại đúng tour sau khi đăng nhập) và ghi chú "Bạn đang xem với tư cách khách. Đăng nhập để đặt tour." | Nút "Đặt tour" bị tắt, nhãn "Sắp có" |
| Thích, Bình luận, Chia sẻ, Lưu tour, So sánh | Bị tắt, nhãn "Sắp có" | Bị tắt, nhãn "Sắp có" |

Trang đăng nhập và đăng ký có liên kết "Tiếp tục với tư cách khách" về trang trong `next` (mặc định `/tours`). Đã đăng nhập mà mở `/login` hoặc `/register` thì cũng được chuyển về trang đó. Chỉ tài khoản `customer` đang `active` đăng nhập được ở đây.

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

Nếu chạy bằng PHP built-in server, có thể clone vào thư mục bất kỳ.

### Bước 2. Chuẩn bị database

Chọn một trong hai cách.

**Cách A – Dùng database chung của nhóm.** Database `db_localtour` dùng chung do Phong host trên MySQL của máy Phong, truy cập qua Radmin VPN.

1. Tham gia mạng Radmin VPN của nhóm (hỏi Phong tên mạng và mật khẩu mạng).
2. Hỏi Phong địa chỉ IP của máy host trong mạng VPN và một tài khoản MySQL dành cho ứng dụng.
3. Điền các thông tin này vào `.env` ở bước 3. Không ghi chúng vào bất kỳ file nào được commit, không gửi vào nhóm chat chung.

**Cách B – Import database trên máy mình.**

1. Mở XAMPP Control Panel, bấm Start cho **MySQL**.
2. Dùng file `src/database/db_localtour.sql` trong repo. File này được gộp từ `src/database/01_schema.sql` đến `06_procedures_NTK_account.sql`.
3. Mở `http://localhost/phpmyadmin`, chọn tab **Import**, chọn file `db_localtour.sql`, giữ **Character set of the file** là `utf-8`, bấm **Import** (hoặc **Go**). File tự tạo database `db_localtour` với `utf8mb4_unicode_ci`.

Nếu không có file gộp: tạo database `db_localtour` với collation `utf8mb4_unicode_ci`, chọn database đó, rồi import lần lượt `01_schema.sql`, `02_seed.sql`, `03_procedures_LTP.sql`, `04_procedures_NMT.sql`, `05_procedures_NTK.sql`, `06_procedures_NTK_account.sql`.

Import lại bất cứ lúc nào để đưa dữ liệu về trạng thái ban đầu: `01_schema.sql` xóa và tạo lại 27 bảng, đồng thời xóa 2 bảng đã bỏ (`post_comments`, `post_interactions`). Tài khoản đã đăng ký thử cũng bị xóa. Ngày khởi hành mẫu được tính theo ngày import, vì vậy nên import lại trước mỗi buổi kiểm thử hoặc demo. Chi tiết xem [02 – Lược đồ dữ liệu](../docs/sprint3/02-luoc-do-du-lieu.md) và `src/database/README.md`.

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

**Database (chỉ với Cách B).** Trong phpMyAdmin, bấm `db_localtour` ở cột trái, mở tab **SQL**, chạy lần lượt từng câu:

```sql
SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'db_localtour';                                  -- 27
SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'db_localtour' AND ROUTINE_TYPE = 'PROCEDURE'; -- 14
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
| `/api/tours/c0000000-0000-4000-8000-000000000001` | JSON có `data.tour`, `gallery`, `schedules`, `tickets`, `itinerary`, `inclusions`, `extras`, `reviews`, `policy`. `data.extras` có 2 phần tử, phần tử đầu có `"kind":"surcharge"`. |
| `/login`, `/register` | Form đăng nhập / đăng ký, có liên kết "Tiếp tục với tư cách khách". |

Mã tour là UUID (chuỗi 36 ký tự), không còn là số như bản đầu tiên; `/tours/1` giờ cũng trả trang "Không tìm thấy tour". Nếu mọi dòng trong bảng cho kết quả đúng, môi trường đã sẵn sàng.

### Bước 6. Thử đăng nhập

Tài khoản trong dữ liệu mẫu có `password_hash = NULL` nên **không đăng nhập được**. Muốn thử, tự tạo tài khoản mới:

1. Mở `/register`, nhập họ tên, email tự đặt (nên dùng đuôi `@localtour.test`, không dùng email thật của người khác) và mật khẩu tối thiểu 8 ký tự. Số điện thoại không bắt buộc.
2. Sau khi đăng ký, ứng dụng đăng nhập luôn và chuyển về `/tours`; header hiện tên vừa nhập và nút "Đăng xuất".
3. Bấm "Đăng xuất", rồi vào `/login` đăng nhập lại bằng email và mật khẩu vừa tạo.
4. Kiểm tra thêm: mật khẩu sai → "Email hoặc mật khẩu không đúng."; đăng ký lại bằng email đã có → "Email này đã được dùng."; mở một tour, bấm "Đăng nhập để đặt tour" rồi đăng nhập → quay lại đúng trang tour đó.

Không ghi email hay mật khẩu thử vào tài liệu, file commit hoặc nhóm chat chung. Import lại database sẽ xóa các tài khoản này.

## Bảo mật

- Mật khẩu chỉ được băm bằng `password_hash(PASSWORD_DEFAULT)` và kiểm tra bằng `password_verify()`; database chỉ lưu chuỗi băm. Không lưu, ghi log hay điền lại mật khẩu gốc vào form.
- Đăng nhập sai vì bất kỳ lý do nào cũng chỉ hiện một thông báo chung, không cho biết email có tồn tại hay không.
- Cookie phiên `httponly`, `SameSite=Lax`, `secure` khi chạy HTTPS; bật `session.use_strict_mode` và đổi session id sau khi đăng nhập. Session chỉ lưu `user_id`, `name`, `email`, `role`.
- Mọi form POST có ô ẩn `_csrf` (`csrf_field()`); controller kiểm tra bằng `Auth::verifyCsrf()` trước khi xử lý. Đăng xuất chỉ bằng POST.
- Tham số `next` chỉ nhận đường dẫn trong ứng dụng (`safe_next_path()`), không chuyển hướng ra trang ngoài.
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
| Trang lỗi 500, log có `PROCEDURE db_localtour.… does not exist` | Chưa import đủ các file procedure. | Import lại `db_localtour.sql`, hoặc import `03`, `04`, `05`, `06` theo thứ tự. |
| Trang lỗi 500, log có `Unknown column` hoặc `Table 'db_localtour.…' doesn't exist` | Database vẫn là lược đồ cũ (trước lược đồ 27 bảng), hoặc file gộp được sinh từ bản cũ. | Sinh lại `db_localtour.sql` từ `01`–`06` mới nhất rồi import lại. |
| Mọi tour đều "Chưa có lịch khởi hành sắp tới" | Dữ liệu mẫu đã import từ lâu, các ngày khởi hành đã qua. | Import lại `db_localtour.sql`. |
| Đăng nhập bằng tài khoản mẫu luôn báo "Email hoặc mật khẩu không đúng." | Hành vi đúng: tài khoản mẫu có `password_hash = NULL`. | Đăng ký tài khoản mới ở `/register` (Bước 6). |
| Gửi form báo "Phiên làm việc đã hết hạn, vui lòng thử lại." | Mã CSRF không khớp: phiên đã hết hoặc bị xóa (đăng xuất ở tab khác, import lại, khởi động lại server), hoặc trình duyệt chặn cookie. | Tải lại trang rồi gửi lại form; kiểm tra trình duyệt cho phép cookie của trang. |
| Built-in server: trang không có CSS hoặc mọi đường dẫn đều về trang lỗi | Chạy lệnh sai thư mục hoặc thiếu `public/router.php`. | Chạy đúng lệnh ở Bước 4 từ thư mục `src/`. |
| Built-in server không khởi động, báo cổng đang được dùng | Cổng 8080 đã bị chương trình khác chiếm. | Đổi sang cổng khác, ví dụ `127.0.0.1:8081`. |
| Trang không có giao diện Bootstrap, nút không phản hồi | Máy không có Internet nên không tải được CSS/JS từ CDN. | Kiểm tra kết nối mạng rồi tải lại trang. |
| Liên kết hoặc ảnh trỏ sai địa chỉ | `APP_URL` trong `.env` bị điền sai. | Để trống `APP_URL`. |
| Trang lỗi 500 không rõ nguyên nhân | Lỗi PHP hoặc SQL. | Xem dòng cuối của `src/storage/logs/app.log`; nếu cần, bật `APP_DEBUG=true` tạm thời trên máy cá nhân rồi tắt lại. |

## Quy ước khi sửa mã

- Chỉ truy cập dữ liệu qua `Core\Database::call('<TIỀN TỐ>_sp_<tên>', [...])`; không viết `SELECT`, `INSERT`, `UPDATE`, `DELETE` trong PHP.
- Escape mọi giá trị in ra HTML bằng `e()`; trong JavaScript dựng DOM bằng `.text()` hoặc `document.createElement`.
- Mọi form POST phải có `<?= csrf_field() ?>`; controller kiểm tra `Auth::verifyCsrf()` trước khi xử lý.
- Thêm route trong `routes/web.php`, cập nhật [03 – Route và quy ước lỗi](../docs/sprint3/03-route-va-quy-uoc-loi.md) trong cùng lần thay đổi.
- Không commit `.env`, mật khẩu, địa chỉ IP thật hay file log.
- Sửa `src/database/01`–`06` thì sinh lại `src/database/db_localtour.sql` và commit cùng lúc (cách sinh xem [database/README.md](database/README.md)).
