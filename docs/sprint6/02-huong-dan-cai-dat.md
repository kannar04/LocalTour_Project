# Hướng dẫn cài đặt LocalTour

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 6 – Hướng dẫn cài đặt, đóng gói demo và thử cài trên máy khác (13/11 – 19/11/2026) |
| WBS | 6.1 Installation Guide; dùng các script cài đặt của 6.3 Đóng gói demo (`src/scripts`) |
| Người phụ trách | Hồ Duy Hải, Đỗ Sơn Thành |
| Phạm vi | Cài LocalTour trên một máy Windows có XAMPP để chạy demo: lấy mã nguồn, tạo `.env`, cài database, tạo tài khoản quản trị, kiểm tra cài đặt, chạy web bằng Apache hoặc PHP built-in server, lịch tự hủy đơn quá hạn. |
| Tài liệu liên quan | [05 – Biên bản thử cài đặt](05-bien-ban-thu-cai-dat.md), [src/README.md](../../src/README.md) (Route, Bước 5–11: các ca tự kiểm tra sau khi cài), [src/database/README.md](../../src/database/README.md) (danh sách file SQL, dữ liệu mẫu) |
| Cách đọc | Lệnh trong khung `bat` gõ ở **Command Prompt** (cmd), không phải PowerShell. Đường dẫn trong hướng dẫn là đường dẫn mặc định của XAMPP (`C:\xampp`); máy cài XAMPP ở chỗ khác thì đổi theo. |

## 1. Tóm tắt các lệnh

Dành cho người đã quen XAMPP, sau khi đã lấy mã nguồn (mục 3) và Start MySQL (mục 4). Mỗi lệnh được giải thích ở các mục sau.

```bat
C:\xampp\php\php.exe -v
cd /d C:\xampp\htdocs\LocalTour_Project\src
copy .env.example .env
scripts\install_database.bat
C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test --generate
C:\xampp\php\php.exe scripts\check_install.php
C:\xampp\php\php.exe -S 127.0.0.1:8080 -t public public/router.php
```

Sau đó mở `http://127.0.0.1:8080` (hoặc `http://localhost/LocalTour_Project/src/public/` nếu chạy bằng Apache của XAMPP).

## 2. Yêu cầu

| Thành phần | Yêu cầu |
| --- | --- |
| Hệ điều hành | Windows 10 hoặc 11. |
| XAMPP | XAMPP 8.2 cho Windows: PHP **8.2** trở lên, Apache, MySQL (MariaDB), phpMyAdmin. Bản cài mặc định của XAMPP 8.2.12 đã bật đủ extension cần dùng (`pdo_mysql`, `mbstring`, `curl`, `openssl`, `json`, `fileinfo`). |
| Cổng | `3306` cho MySQL; `80` cho Apache hoặc `8080` cho PHP built-in server (chọn một trong hai cách chạy ở mục 8). |
| Internet | Cần khi mở web: Bootstrap, jQuery và font tải từ CDN. |
| Git | Không bắt buộc: có thể tải mã nguồn dạng ZIP (mục 3). |

Kiểm tra phiên bản PHP của XAMPP:

```bat
C:\xampp\php\php.exe -v
```

Dòng đầu phải là PHP 8.2 trở lên, ví dụ:

```text
PHP 8.2.12 (cli) (built: Oct 24 2023 21:15:15) (ZTS Visual C++ 2019 x64)
```

## 3. Lấy mã nguồn

Repository: <https://github.com/kannar04/LocalTour_Project>. Nên đặt mã nguồn ở `C:\xampp\htdocs\LocalTour_Project` để chạy được cả hai cách ở mục 8 (Apache chỉ phục vụ thư mục trong `C:\xampp\htdocs`; PHP built-in server chạy được ở thư mục bất kỳ, kể cả đường dẫn có dấu cách).

**Cách A – Tải ZIP.**

1. Mở trang repository, chọn đúng nhánh nhóm chốt để demo (hỏi nhóm trưởng), bấm **Code** → **Download ZIP**.
2. File ZIP chứa một thư mục tên `LocalTour_Project-<tên nhánh>`. Giải nén, chuyển thư mục này vào `C:\xampp\htdocs` và đổi tên thành `LocalTour_Project`.
3. Kiểm tra: thư mục `C:\xampp\htdocs\LocalTour_Project` phải chứa trực tiếp `src` và `docs`, và có file `C:\xampp\htdocs\LocalTour_Project\src\.env.example`. Nếu thấy thêm một lớp thư mục trùng tên (do công cụ giải nén tự tạo), chuyển thư mục bên trong ra ngoài.

**Cách B – Dùng Git.**

```bat
cd /d C:\xampp\htdocs
git clone https://github.com/kannar04/LocalTour_Project.git
cd LocalTour_Project
git checkout <nhánh nhóm chốt để demo>
```

## 4. Bật MySQL

Mở **XAMPP Control Panel**, bấm **Start** ở dòng **MySQL**. (Bấm Start ở dòng **Apache** nếu chạy web bằng Apache hoặc dùng phpMyAdmin.)

Kiểm tra MySQL đang nghe cổng 3306:

```bat
netstat -ano | findstr :3306
```

Kết quả có dòng `LISTENING`, ví dụ:

```text
  TCP    0.0.0.0:3306           0.0.0.0:0              LISTENING       34048
```

Không có dòng nào, hoặc MySQL không Start được: xem mục 12.

## 5. Tạo file `.env`

Mở Command Prompt, chuyển vào thư mục `src` rồi tạo `.env` từ file mẫu:

```bat
cd /d C:\xampp\htdocs\LocalTour_Project\src
copy .env.example .env
```

Kết quả: `1 file(s) copied.` Đường dẫn có dấu cách thì đặt trong ngoặc kép, ví dụ `cd /d "D:\Do an\LocalTour_Project\src"`. **Mọi lệnh ở các mục sau đều gõ khi đang đứng ở thư mục `src` này.**

Mở `.env` bằng Notepad. Với MySQL của XAMPP trên chính máy này, giữ nguyên các giá trị mặc định:

| Khóa | Giá trị |
| --- | --- |
| `APP_ENV` | `local` |
| `APP_DEBUG` | `false` (chỉ bật `true` tạm thời khi cần xem chi tiết lỗi trên máy cá nhân). |
| `APP_URL` | Để trống: ứng dụng tự tính đường dẫn theo cách chạy. |
| `DB_HOST`, `DB_PORT` | `127.0.0.1`, `3306` |
| `DB_DATABASE` | `db_localtour`. Đổi **trước** khi cài database (mục 6) nếu máy đã có `db_localtour` với dữ liệu muốn giữ lại, ví dụ `db_localtour_demo` (chỉ dùng chữ không dấu, số và dấu gạch dưới). |
| `DB_USERNAME`, `DB_PASSWORD` | `root` và để trống (mặc định của XAMPP). |
| Các khóa còn lại | Tùy chọn, có thể để trống (mục 10). |

`.env` chứa thông tin kết nối thật: không commit, không gửi vào nhóm chat chung, không sửa `.env.example` thành giá trị thật.

## 6. Cài database

**Cách 1 – Script cài database (khuyến nghị).**

```bat
scripts\install_database.bat
```

Có thể bấm đúp file `src\scripts\install_database.bat` trong File Explorer; cửa sổ dừng lại ở cuối để đọc kết quả. Script tạo database ghi trong `DB_DATABASE` với bảng mã `utf8mb4_unicode_ci`, import lần lượt mọi file `src\database\NN_*.sql`, rồi so tên bảng / procedure trong database với các file. Kết quả đúng (rút gọn):

```text
LocalTour – cài database
OK        mysql: C:\xampp\mysql\bin\mysql.exe
OK        Kết nối MySQL 127.0.0.1:3306 (tài khoản root, 10.4.32-MariaDB)
OK        Tạo database db_localtour (utf8mb4_unicode_ci)
          Import 26 file từ …\LocalTour_Project\src\database:
OK        01_schema.sql (0,5 giây)
…
OK        Database db_localtour: 34 bảng, 112 procedure (đủ như các file 01_schema.sql → 26_procedures_NTK_setup.sql).
```

Số file, số bảng và số procedure thay đổi theo phiên bản mã nguồn; điều cần thấy là dòng `OK` cuối có chữ “đủ như các file”.

- Database đã có bảng / procedure (ví dụ `db_localtour` import ở sprint trước): script dừng với `LỖI Database … đã có … không cài đè.` để không xóa nhầm dữ liệu. Muốn xóa hết và cài lại thì chạy:

  ```bat
  scripts\install_database.bat --fresh
  ```

  Script hỏi `Gõ tên database (db_localtour) rồi Enter để xóa và cài lại, Enter để thoát:`. Gõ đúng tên database rồi Enter. Mọi dữ liệu trong database đó (tài khoản đã đăng ký, đơn đặt thử, danh sách ảnh tour đã tải lên) bị xóa.
- Cài vào database khác mà không sửa `.env`: `scripts\install_database.bat --database=ten_khac` (thêm `--fresh` nếu database đó đã có dữ liệu). Script nhắc sửa `DB_DATABASE` nếu muốn web dùng database này.

**Cách 2 – Import file gộp bằng phpMyAdmin.** Cần Start cả Apache và MySQL.

1. Mở `http://localhost/phpmyadmin`, chọn tab **Import**, chọn file `src\database\db_localtour.sql`, giữ **Character set of the file** là `utf-8`, bấm **Import**.
2. File này tự tạo database tên `db_localtour` (ghi đè nếu đã có), nên `DB_DATABASE` trong `.env` phải là `db_localtour`.
3. Chạy kiểm tra cài đặt (mục 7). Nếu báo `Database chưa cài đủ các file NN_*.sql (cài từ bản cũ, hoặc file gộp cũ)`, file gộp chưa được sinh lại sau khi có file SQL mới: dùng Cách 1 với `--fresh`.

## 7. Tạo tài khoản quản trị và kiểm tra cài đặt

Tài khoản trong dữ liệu mẫu không có mật khẩu nên không đăng nhập được. Đặt mật khẩu cho tài khoản quản trị viên mẫu:

```bat
C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test --generate
```

```text
LocalTour – tài khoản quản trị
OK        Database db_localtour: admin@localtour.test là quản trị viên, sẽ đặt mật khẩu mới.
OK        Đã đặt mật khẩu mới cho admin@localtour.test (Quản trị viên LocalTour).
          Mật khẩu (chỉ hiện lần này, ghi lại ngay; không lưu vào file, không gửi vào nhóm chat):
          <mật khẩu 16 ký tự>
          Đăng nhập ở trang /admin/login của ứng dụng, ví dụ http://127.0.0.1:8080/admin/login
```

Bỏ `--generate` để tự gõ mật khẩu (gõ hai lần, mỗi ký tự hiện thành dấu `*`). Dùng email chưa có trong database thì script tạo tài khoản quản trị mới; email của khách hàng thì script dừng, không nâng quyền. Mỗi lần cài lại database phải chạy lại lệnh này.

Kiểm tra toàn bộ cài đặt:

```bat
C:\xampp\php\php.exe scripts\check_install.php
```

Mỗi dòng là `OK`, `CẢNH BÁO` hoặc `LỖI`; dòng `CẢNH BÁO` / `LỖI` ghi kèm cách sửa. Kết quả trên một máy cài đủ (rút gọn):

```text
OK        PHP 8.2.12 (C:\xampp\php\php.exe)
OK        Extension PHP: pdo_mysql, mbstring, curl, openssl, json, fileinfo
OK        Có file src\.env
OK        APP_DEBUG=false
OK        APP_URL để trống: đường dẫn tự tính theo cách chạy (khuyến nghị)
CẢNH BÁO  VNPay sandbox chưa có VNPAY_TMN_CODE / VNPAY_HASH_SECRET (tùy chọn): trang thanh toán hiện "VNPay đang tạm ngưng".
CẢNH BÁO  VietQR chưa có PAYMENT_BANK_ID / PAYMENT_ACCOUNT_NO hợp lệ (tùy chọn): trang thanh toán hiện "VietQR đang tạm ngưng".
OK        Kết nối database db_localtour tại 127.0.0.1:3306 (tài khoản root), 10.4.32-MariaDB
OK        Bảng mã database: utf8mb4_unicode_ci
OK        Đủ 34 bảng của 26 file 01_schema.sql → 26_procedures_NTK_setup.sql
OK        Đủ 112 procedure của 26 file 01_schema.sql → 26_procedures_NTK_setup.sql
OK        1 tài khoản quản trị đăng nhập được
OK        35 lịch khởi hành còn nhận khách
…
OK        Apache: đã bật mod_rewrite
OK        Apache: htdocs cho phép .htaccess (AllowOverride All)
Kết quả: 18 OK, 2 cảnh báo, 0 lỗi.
```

Không còn dòng `LỖI` là đủ để chạy demo. Hai dòng `CẢNH BÁO` về VNPay / VietQR là bình thường khi không dùng thanh toán thử (mục 10). Hai dòng `Apache: …` chỉ có khi mã nguồn nằm trong `htdocs` của XAMPP.

## 8. Chạy web

**Cách 1 – Apache của XAMPP** (mã nguồn ở `C:\xampp\htdocs\LocalTour_Project`):

1. Trong XAMPP Control Panel, Start **Apache** (và **MySQL**).
2. Mở `http://localhost/LocalTour_Project/src/public/`.

Mở `http://localhost/LocalTour_Project/src/` hoặc `…/src/.env` nhận lỗi 403: đây là hành vi đúng, `src/.htaccess` chặn mọi thứ ngoài `public/`.

**Cách 2 – PHP built-in server** (không cần Apache, mã nguồn ở thư mục bất kỳ):

```bat
cd /d C:\xampp\htdocs\LocalTour_Project\src
C:\xampp\php\php.exe -S 127.0.0.1:8080 -t public public/router.php
```

Màn hình hiện `PHP 8.2.12 Development Server (http://127.0.0.1:8080) started`. Mở `http://127.0.0.1:8080`. Giữ cửa sổ này mở trong lúc dùng web; nhấn `Ctrl+C` để dừng. Cổng 8080 đang bận thì đổi sang số khác, ví dụ `127.0.0.1:8615`, và mở đúng cổng đó.

**Kiểm tra nhanh sau khi chạy** (ghép đường dẫn với gốc ứng dụng ở trên):

| Thử | Kết quả mong đợi |
| --- | --- |
| `/tours` | Trang “Bảng tin du lịch” có 9 tour. |
| `/tours/c0000000-0000-4000-8000-000000000001` | Trang chi tiết “Hà Nội qua những món ăn phố cổ”. |
| `/admin/login`, đăng nhập bằng `admin@localtour.test` và mật khẩu ở mục 7 | Trang “Tổng quan” của quản trị viên. Mật khẩu sai → “Email hoặc mật khẩu không đúng.” |
| `/register` tạo tài khoản khách hàng, đặt tour 1 cho 1 người lớn; quản trị viên mở đơn ở “Yêu cầu đặt tour”, chọn “Xác nhận chỗ và giá”; khách mở “Thanh toán ngay” | Đơn chuyển “Chờ thanh toán”. Khi `.env` chưa có khóa thanh toán thử, trang thanh toán hiện “VNPay đang tạm ngưng” và “VietQR đang tạm ngưng”. |

Các ca kiểm tra chi tiết hơn (đăng nhập, quản trị, đặt tour, thanh toán, so sánh tour, đổi ngày / hủy tour) ở `src/README.md`, Bước 5–11.

## 9. Lịch tự hủy đơn quá hạn thanh toán

Trên máy chạy demo, đăng ký Windows Task Scheduler chạy `expire_holds.php` mỗi 15 phút (cần có `.env`, database đã cài và MySQL đang chạy):

```bat
scripts\register_expire_task.bat
```

```text
2026-11-11 16:41:02 – đã hủy 0 đơn quá hạn thanh toán.
SUCCESS: The scheduled task "LocalTour - Tu huy don qua han" has successfully been created.
Đã đăng ký "LocalTour - Tu huy don qua han": chạy mỗi 15 phút. Gỡ bằng: register_expire_task.bat /delete
```

Kiểm tra task (cột `Status` là `Ready`) và gỡ task sau buổi demo:

```bat
schtasks /Query /TN "LocalTour - Tu huy don qua han"
scripts\register_expire_task.bat /delete
```

Task ghi đường dẫn đầy đủ tới thư mục mã nguồn: chuyển hoặc đổi tên thư mục thì đăng ký lại. Task chỉ chạy khi tài khoản Windows đó đang đăng nhập. PHP không ở `C:\xampp\php`: xem `src/README.md`, Bước 9.

## 10. Khóa tùy chọn trong `.env`

Ngoài các dòng `APP_…` và `DB_…`, mọi khóa khác trong `.env.example` là **tùy chọn** và có thể để trống. Khi để trống, chức năng tương ứng được ẩn hoặc hiện “đang tạm ngưng”; các phần còn lại của web vẫn chạy bình thường. `check_install.php` không báo `LỖI` vì thiếu các khóa này (với VNPay / VietQR chỉ là `CẢNH BÁO … (tùy chọn)`).

Thanh toán thử (sandbox, không chuyển tiền thật):

| Khóa | Giá trị |
| --- | --- |
| `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET` | Mã website và khóa bí mật VNPay sandbox, đăng ký tại <https://sandbox.vnpayment.vn/devreg/>. |
| `VNPAY_PAY_URL` | Giữ mặc định (cổng sandbox). |
| `VNPAY_RETURN_URL` | Để trống: ứng dụng tự tính theo địa chỉ đang mở. |
| `PAYMENT_BANK_ID`, `PAYMENT_BANK_NAME`, `PAYMENT_ACCOUNT_NO`, `PAYMENT_ACCOUNT_NAME` | Tài khoản nhận chuyển khoản VietQR (mã ngân hàng theo VietQR, ví dụ `VCB`, `MB`, `TCB`). |

Nhóm dùng chung một bộ khóa sandbox: hỏi riêng trong nhóm, không gửi vào nhóm chat chung, không ghi vào file được commit. Điền xong, tải lại trang thanh toán; `check_install.php` hiện `OK VNPay sandbox: đã có khóa (giá trị không in ra)` và `OK VietQR: đã có tài khoản nhận (giá trị không in ra)`.

## 11. Cài lại trước buổi demo

Ngày khởi hành trong dữ liệu mẫu được tính theo ngày cài database, nên cài lại database trước mỗi buổi demo hoặc kiểm thử:

```bat
scripts\install_database.bat --fresh
C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test --generate
C:\xampp\php\php.exe scripts\check_install.php
```

Cài lại xóa mọi tài khoản và đơn đã tạo thử, nên phải tạo lại mật khẩu quản trị. Database có ảnh tour tải lên ở máy khác thì chép kèm thư mục `src\public\assets\uploads\tours` từ máy đó; ảnh thiếu file hiện ảnh thay thế, `check_install.php` liệt kê các ảnh thiếu.

## 12. Xử lý sự cố

Chạy `C:\xampp\php\php.exe scripts\check_install.php` trước: phần lớn lỗi dưới đây đều có dòng `LỖI` / `CẢNH BÁO` kèm cách sửa.

| Hiện tượng | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| `Could not open input file: scripts\check_install.php`, hoặc `scripts\install_database.bat` báo `The system cannot find the path specified.` | Command Prompt không đứng ở thư mục `src`. | `cd /d C:\xampp\htdocs\LocalTour_Project\src` rồi chạy lại. |
| `install_database.bat` báo `LOI Khong tim thay "C:\xampp\php\php.exe"` | XAMPP không cài ở `C:\xampp`. | Trong cùng cửa sổ, chỉ đường dẫn PHP rồi chạy lại: `set PHP_BIN=D:\xampp\php\php.exe`. Các lệnh khác thì thay `C:\xampp\php\php.exe` bằng đường dẫn đó. Script không tìm thấy `mysql.exe` thì tương tự: `set MYSQL_BIN=D:\xampp\mysql\bin\mysql.exe` (sai đường dẫn: `LỖI MYSQL_BIN = "…" không phải file mysql.exe.`). |
| `LỖI Chưa có file src\.env` | Chưa tạo `.env`. | `copy .env.example .env` (mục 5). |
| MySQL không Start được trong XAMPP; hoặc script / `check_install.php` báo lỗi `2002` / `2003` “MySQL chưa chạy hoặc sai DB_HOST / DB_PORT”; web báo 503 “Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau.” | MySQL chưa chạy, sai `DB_HOST` / `DB_PORT`, hoặc cổng 3306 đã bị một chương trình khác (thường là một MySQL / MariaDB cài riêng) chiếm. | Start MySQL trong XAMPP. Xem chương trình đang giữ cổng: `netstat -ano \| findstr :3306` (cột cuối dòng `LISTENING` là PID), rồi `tasklist /FI "PID eq <PID>"` để biết tên chương trình. Tắt chương trình đó rồi Start lại MySQL của XAMPP; kiểm tra lại `DB_HOST=127.0.0.1`, `DB_PORT=3306`. |
| `1045` “Sai DB_USERNAME / DB_PASSWORD trong .env” | Sai tài khoản MySQL. | XAMPP mặc định: `DB_USERNAME=root`, `DB_PASSWORD=` để trống. |
| `1049` “Chưa có database này”; trang `/tours` hiện “Không tải được danh sách tour”, trang tour báo 503 | `DB_DATABASE` sai tên hoặc chưa cài database. | Sửa `DB_DATABASE` cho đúng database đã cài, hoặc chạy `scripts\install_database.bat`. |
| `1305` `PROCEDURE … does not exist` / “Database chưa cài đủ các file NN_*.sql”; `create_admin.php` báo “Chưa lưu được tài khoản”; trang web lỗi 500 (danh sách tour: “Hệ thống đang gặp sự cố. Vui lòng thử lại sau.”) | Database trống, cài từ bản cũ, hoặc import file gộp `db_localtour.sql` cũ. | `scripts\install_database.bat --fresh`, rồi chạy lại `create_admin.php`. |
| `LỖI Database … đã có … bảng và … procedure, không cài đè.` | Hành vi đúng: script không ghi đè database đang có dữ liệu. | Thêm `--fresh` (xóa hết dữ liệu trong database đó), hoặc đổi `DB_DATABASE` sang tên mới. |
| Tiếng Việt hiển thị sai (`Ã¡`, `?`), tìm kiếm có dấu không ra kết quả, trang chi tiết tour lỗi 500; `storage\logs\app.log` có `COLLATION 'utf8mb4_unicode_ci' is not valid for CHARACTER SET 'latin1'`; `check_install.php` báo “Database dùng bảng mã latin1” | Database tạo tay với bảng mã mặc định (`latin1`), hoặc file SQL được import với bảng mã khác UTF-8. | `scripts\install_database.bat --fresh`: script tạo lại database với `utf8mb4_unicode_ci`. Import bằng phpMyAdmin thì luôn chọn character set `utf-8`. |
| Đăng nhập `/admin/login` báo “Email hoặc mật khẩu không đúng.”; `check_install.php` báo “Chưa có tài khoản quản trị đăng nhập được” | Tài khoản mẫu không có mật khẩu, hoặc database vừa được cài lại. | `C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test --generate` (mục 7). |
| Ảnh tour chỉ hiện ảnh thay thế; `check_install.php` báo `CẢNH BÁO … ảnh tour không có file trên máy này` | Database có ảnh tải lên ở máy khác, file ảnh không có trên máy này. | Chép thư mục `src\public\assets\uploads\tours` từ máy đã tải ảnh lên. |
| Dưới Apache, mọi trang trừ trang chủ báo 404 của Apache; mở được cả `…/src/.env` hoặc `…/src/` | Apache chưa bật `mod_rewrite`, hoặc bỏ qua `.htaccess` (`AllowOverride None`): khi đó `.env` **không được chặn**. `check_install.php` báo `CẢNH BÁO Apache …`. | Trong `C:\xampp\apache\conf\httpd.conf`: bỏ dấu `#` trước `LoadModule rewrite_module modules/mod_rewrite.so`; trong khối `<Directory "C:/xampp/htdocs">` đặt `AllowOverride All`. Stop rồi Start lại Apache. |
| Apache không Start được; `C:\xampp\apache\logs\error.log` có `(OS 10048)Only one usage of each socket address …` và `AH00072: make_sock: could not bind to address` | Cổng 80 (hoặc 443) đã bị chương trình khác chiếm. | `netstat -ano \| findstr :80` và `tasklist /FI "PID eq <PID>"` để tìm chương trình; tắt chương trình đó, hoặc chạy web bằng PHP built-in server (mục 8, Cách 2). |
| PHP built-in server báo `started` nhưng trình duyệt mở ra trang cũ / trang của chương trình khác | Cổng đã bị chiếm (thường là cửa sổ built-in server mở từ trước). Trên Windows, server mới vẫn báo `started` dù cổng đã bị chiếm. | `netstat -ano \| findstr :8080` để xem cổng có đang bị giữ không; đóng cửa sổ cũ (`Ctrl+C`), hoặc chạy với cổng khác. |
| `php -v` ra phiên bản thấp hơn 8.2; `check_install.php` báo “cần PHP 8.2 trở lên (XAMPP 8.2.x)” | XAMPP bản cũ. | Cài XAMPP 8.2 rồi làm lại từ mục 4. |
| `check_install.php` báo `LỖI Thiếu extension PHP: …` | `php.ini` đang tắt extension đó. | Mở file `php.ini` được nêu trong dòng lỗi (XAMPP: `C:\xampp\php\php.ini`), bỏ dấu `;` trước dòng `extension=…`, lưu, rồi khởi động lại Apache hoặc built-in server. |

Các lỗi khi dùng web (CSRF, giá vé đổi, thanh toán, quyền quản trị…) xem bảng “Xử lý sự cố” trong `src/README.md`.
