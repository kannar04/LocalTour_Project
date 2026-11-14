# Biên bản thử cài đặt LocalTour trên máy khác

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 6 – Hướng dẫn cài đặt, đóng gói demo và thử cài trên máy khác (13/11 – 19/11/2026) |
| WBS | 6.4 Thử cài trên máy khác |
| Người phụ trách | Lê Trung Phong, Nguyễn Minh Thức, Nguyễn Tuấn Khôi |
| Căn cứ | [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md); các script cài đặt trong `src/scripts` (6.3 Đóng gói demo) |
| Phiên bản mã nguồn thử | Mã commit: ……………… (mã 7 ký tự của commit mới nhất, hiện ở dòng trên cùng danh sách file trên trang GitHub của nhánh demo) · Ngày tải: …/…/2026 |
| Trạng thái | Mẫu trống, điền khi thử cài. |

## 1. Cách điền

1. Mỗi người thử trên một máy chưa từng chạy LocalTour (hoặc dùng `DB_DATABASE` mới, chưa có trên máy), làm **đúng theo** [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md), không dùng bước nào ngoài hướng dẫn. Bước nào phải làm khác hướng dẫn thì ghi vào mục 4.
2. Mục 2: điền thông tin máy trước khi bắt đầu.
3. Mục 3: mỗi bước ghi một trong ba kết quả: **Đạt**; **Không đạt (Lxx)** với `Lxx` là số dòng ở mục 4; **Bỏ qua** kèm lý do (ví dụ máy không dùng Apache).
4. Mục 4: chép nguyên văn thông báo lỗi (dòng `LỖI` / `CẢNH BÁO` của script, lỗi trên trình duyệt, dòng cuối `src\storage\logs\app.log`), ghi nguyên nhân, cách đã xử lý và mục cần sửa trong hướng dẫn.
5. Không ghi mật khẩu, khóa thanh toán, số tài khoản hay địa chỉ IP thật vào biên bản hoặc ảnh chụp. Ảnh chụp màn hình đặt tên `<máy>-<bước>.png`, ví dụ `may2-B09.png`.
6. Thử xong: dừng built-in server (`Ctrl+C`), gỡ task (bước B17), Stop Apache / MySQL nếu máy không dùng tiếp.

## 2. Thông tin máy thử

| Mục | Máy 1 | Máy 2 | Máy 3 |
| --- | --- | --- | --- |
| Người thử | | | |
| Ngày thử | | | |
| Máy (laptop / PC, tên máy) | | | |
| Hệ điều hành (Windows 10 / 11, phiên bản) | | | |
| Phiên bản XAMPP | | | |
| Phiên bản PHP (`php -v`, dòng đầu) | | | |
| MySQL / MariaDB (dòng `Kết nối MySQL …` ở bước B05) | | | |
| Thư mục cài XAMPP | | | |
| Thư mục mã nguồn | | | |
| Cách lấy mã nguồn (ZIP / Git) | | | |
| Cách chạy web (Apache / built-in server, cổng) | | | |
| `DB_DATABASE` | | | |
| Trình duyệt (tên, phiên bản) | | | |
| Máy đã có LocalTour / `db_localtour` từ trước (Có / Không) | | | |

## 3. Các bước thử

Mục trong cột “Hướng dẫn” là số mục của [02 – Hướng dẫn cài đặt](02-huong-dan-cai-dat.md).

| Bước | Hướng dẫn | Thao tác / lệnh | Kết quả mong đợi | Máy 1 | Máy 2 | Máy 3 |
| --- | --- | --- | --- | --- | --- | --- |
| B01 | 2 | `C:\xampp\php\php.exe -v` | Dòng đầu `PHP 8.2.x` trở lên. | | | |
| B02 | 3 | Lấy mã nguồn (ZIP hoặc Git), đặt ở `C:\xampp\htdocs\LocalTour_Project` | Thư mục chứa trực tiếp `src`, `docs`; có `src\.env.example`. | | | |
| B03 | 4 | Start MySQL; `netstat -ano \| findstr :3306` | MySQL chạy, có dòng `LISTENING` ở cổng 3306. | | | |
| B04 | 5 | `cd /d …\LocalTour_Project\src`; `copy .env.example .env`; sửa `DB_DATABASE` nếu cần | `1 file(s) copied.`; `.env` có đủ dòng `DB_…`. | | | |
| B05 | 6 | `scripts\install_database.bat` | Dòng `OK Database …: … bảng, … procedure (đủ như các file …)`. Ghi lại số bảng / procedure: | | | |
| B06 | 6 | Chạy lại `scripts\install_database.bat` | `LỖI Database … đã có … không cài đè.`, database không đổi. | | | |
| B07 | 6 | `scripts\install_database.bat --fresh`, gõ tên database rồi Enter | Cài lại thành công như B05. | | | |
| B08 | 7 | `C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test --generate` | `OK Đã đặt mật khẩu mới cho admin@localtour.test …`, mật khẩu hiện một lần (không ghi vào biên bản). | | | |
| B09 | 7 | `C:\xampp\php\php.exe scripts\check_install.php` | `Kết quả: … OK, … cảnh báo, 0 lỗi.` Ghi lại dòng kết quả: | | | |
| B10 | 8 | Apache: Start Apache, mở `http://localhost/LocalTour_Project/src/public/` | Trang “Bảng tin du lịch” có 9 tour. | | | |
| B11 | 8 | Apache: mở `http://localhost/LocalTour_Project/src/.env` | Lỗi 403, không hiện nội dung file. | | | |
| B12 | 8 | Built-in server: `C:\xampp\php\php.exe -S 127.0.0.1:8080 -t public public/router.php`, mở `http://127.0.0.1:8080` | Màn hình lệnh báo `… Development Server (http://127.0.0.1:8080) started`; trang “Bảng tin du lịch” có 9 tour. | | | |
| B13 | 8 | Mở `/tours/c0000000-0000-4000-8000-000000000001` | Trang chi tiết “Hà Nội qua những món ăn phố cổ”. | | | |
| B14 | 8 | `/admin/login`: đăng nhập sai mật khẩu, rồi đúng mật khẩu ở B08 | Sai: “Email hoặc mật khẩu không đúng.”; đúng: trang “Tổng quan”. | | | |
| B15 | 8 | `/register` tạo tài khoản khách hàng, đặt tour 1 cho 1 người lớn | Đơn `LTxxxxxx` được giữ chỗ ngay và trang thanh toán của đơn mở ra (“Đã giữ chỗ cho đơn LTxxxxxx”); trong “Đơn của tôi” đơn ở trạng thái “Chờ thanh toán”. | | | |
| B16 | 8 | Xem trang thanh toán của đơn vừa đặt; quản trị viên mở “Đơn đặt tour” | Chưa có khóa thanh toán thử thì trang thanh toán hiện “VNPay đang tạm ngưng”, “VietQR đang tạm ngưng”; đơn có trong danh sách “Đơn đặt tour” của quản trị viên. | | | |
| B17 | 9 | `scripts\register_expire_task.bat`; `schtasks /Query /TN "LocalTour - Tu huy don qua han"`; `scripts\register_expire_task.bat /delete` | `SUCCESS … created`; trạng thái `Ready`; `SUCCESS … deleted`. | | | |
| B18 | 10 | (Tùy chọn) điền khóa thanh toán thử trong `.env`, chạy lại `check_install.php` | Hai dòng `OK VNPay sandbox …`, `OK VietQR …`, giá trị khóa không in ra. | | | |
| B19 | 12 | Thử một lỗi trong bảng “Xử lý sự cố” (ghi rõ lỗi nào) | Hiện tượng và cách xử lý đúng như bảng. | | | |

## 4. Lỗi gặp và cách xử lý

| Số | Máy | Bước | Hiện tượng (thông báo nguyên văn) | Nguyên nhân | Cách xử lý | Đã xử lý (Có / Không) | Cần sửa trong hướng dẫn (mục, nội dung) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| L01 | | | | | | | |
| L02 | | | | | | | |
| L03 | | | | | | | |
| L04 | | | | | | | |
| L05 | | | | | | | |

## 5. Kết luận

| Mục | Máy 1 | Máy 2 | Máy 3 |
| --- | --- | --- | --- |
| Số bước Đạt / Không đạt / Bỏ qua | | | |
| Thời gian cài (từ B02 tới B09, phút) | | | |
| Lỗi chưa xử lý (số dòng mục 4) | | | |
| Kết luận (Cài đặt thành công / Chưa thành công) | | | |

Đề xuất sửa hướng dẫn cài đặt hoặc script:

- …

## 6. Xác nhận

| Vai trò | Họ tên | Ngày | Chữ ký |
| --- | --- | --- | --- |
| Người thử máy 1 | | | |
| Người thử máy 2 | | | |
| Người thử máy 3 | | | |
| Người rà soát hướng dẫn cài đặt | | | |
