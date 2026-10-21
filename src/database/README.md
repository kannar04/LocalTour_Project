# Database LocalTour (`db_localtour`)

Phụ trách: **Nguyễn Minh Thức (NMT)** · WBS 3.2.2 · Sprint 3 (v0.1)

Thư mục này chứa toàn bộ script tạo database cho trang danh sách tour và trang chi tiết tour: bảng, khóa ngoại, chỉ mục, dữ liệu mẫu và stored procedure. Mọi script chạy được trên **MariaDB 10.4 (XAMPP)** và **MySQL 8**, bảng mã `utf8mb4` / `utf8mb4_unicode_ci`.

> Toàn bộ dữ liệu trong `02_seed.sql` (đơn vị tổ chức, tour, giá, lịch, đánh giá) là **dữ liệu minh họa**, không phải thông tin thật.

## Các file

| File | Nội dung | Phụ trách | WBS |
|---|---|---|---|
| `01_schema.sql` | Xóa 9 bảng cũ (theo thứ tự ngược khóa ngoại) rồi tạo lại: `destinations`, `categories`, `providers`, `tours`, `tour_images`, `tour_itinerary_items`, `tour_inclusions`, `tour_schedules`, `reviews`. Không có `CREATE DATABASE` / `USE`. | Thức | 3.1.2 |
| `02_seed.sql` | Dữ liệu mẫu: 4 điểm đến, 4 loại tour, 7 đơn vị tổ chức, 10 tour (9 hiển thị + 1 ẩn) cùng ảnh, lịch trình, chi phí, lịch khởi hành, đánh giá. | Thức | 3.2.2 |
| `03_procedures_LTP.sql` | Procedure cho trang danh sách tour. | Phong | 3.2.3 |
| `04_procedures_NMT.sql` | Procedure cho trang chi tiết: thông tin tour, lịch khởi hành, lịch trình. | Thức | 3.2.4 |
| `05_procedures_NTK.sql` | Procedure cho nội dung trang chi tiết: ảnh, chi phí bao gồm, đánh giá. | Khôi | 3.2.6 |

**Thứ tự import:** `01` → `02` → `03` → `04` → `05`.

**Chạy lại được:** `01_schema.sql` xóa và tạo lại bảng, các file procedure dùng `DROP PROCEDURE IF EXISTS`. Import lại sẽ **xóa hết dữ liệu cũ** trong `db_localtour` và nạp lại dữ liệu mẫu. Không ảnh hưởng database khác.

## File gộp `db_localtour.sql`

Để import một lần bằng phpMyAdmin, nhóm dùng **một file gộp** `db_localtour.sql` do nhóm trưởng (Phong) giữ và gửi cho cả nhóm. File này:

- **được sinh tự động** từ 5 file trên, theo đúng thứ tự, có thêm 3 dòng đầu:
  ```sql
  CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  USE db_localtour;
  SET NAMES utf8mb4;
  ```
- **không commit** lên Git (đã có trong `.gitignore`). Muốn sửa dữ liệu hay procedure thì sửa file `01`–`05` rồi sinh lại file gộp, không sửa tay file gộp.

Tự sinh file gộp (Git Bash, đứng ở thư mục gốc repo):

```bash
{ printf '%s\n' 'CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' \
    'USE db_localtour;' 'SET NAMES utf8mb4;'; cat src/database/0[1-5]_*.sql; } > db_localtour.sql
```

## Cách 1: Import bằng phpMyAdmin

1. Bật **Apache** và **MySQL** trong XAMPP Control Panel, mở <http://localhost/phpmyadmin>.
2. Bấm vào tên server ở góc trên bên trái (**không cần** chọn hay tạo database trước; file gộp tự tạo `db_localtour`).
3. Chọn tab **Import (Nhập)** → **Choose File** → chọn `db_localtour.sql`.
4. Giữ **Character set of the file: utf-8**, **Format: SQL**, các tùy chọn khác để mặc định → bấm **Import / Go**.
5. Kiểm tra: database `db_localtour` có 9 bảng, tab **Routines** có 8 procedure. Ở tab **SQL** của `db_localtour`, chạy `CALL LTP_sp_tour_list(NULL, NULL, NULL);` phải ra 9 dòng.

## Cách 2: Import bằng mysql CLI

Luôn thêm `--default-character-set=utf8mb4`, nếu không tiếng Việt có thể bị lỗi thành `?`. Với XAMPP, `mysql` nằm ở `C:\xampp\mysql\bin\mysql.exe`.

File gộp, dùng Git Bash hoặc cmd:

```bash
mysql -uroot --default-character-set=utf8mb4 < db_localtour.sql
```

File gộp, dùng PowerShell (PowerShell không hỗ trợ dấu `<`):

```powershell
& C:\xampp\mysql\bin\mysql.exe -uroot --default-character-set=utf8mb4 -e "source db_localtour.sql"
```

Từng file, không cần file gộp (Git Bash, đứng trong `src/database`):

```bash
mysql -uroot --default-character-set=utf8mb4 -e "CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
for f in 01_schema.sql 02_seed.sql 03_procedures_LTP.sql 04_procedures_NMT.sql 05_procedures_NTK.sql; do
  mysql -uroot --default-character-set=utf8mb4 db_localtour < "$f" || break
done
```

> Trên Windows, đừng gõ tiếng Việt trực tiếp trong `mysql -e "..."`: chữ có dấu bị đổi thành `?` trước khi tới server. Muốn thử `CALL` với từ khóa có dấu thì dùng tab SQL của phpMyAdmin hoặc ghi câu lệnh vào file rồi import.

## Stored procedure và người phụ trách

PHP chỉ gọi dữ liệu qua `Core\Database::call()` (câu `CALL` có tham số), không viết `SELECT` / `INSERT` / `UPDATE` / `DELETE` trong PHP. Tên procedure bắt đầu bằng tiền tố của người phụ trách.

| Tiền tố | Người phụ trách | File | Procedure |
|---|---|---|---|
| `LTP_` | Lê Trung Phong | `03_procedures_LTP.sql` | `LTP_sp_tour_list(p_keyword, p_destination_id, p_sort)`, `LTP_sp_destination_list()` |
| `NMT_` | Nguyễn Minh Thức | `04_procedures_NMT.sql` | `NMT_sp_tour_detail(p_tour_id)`, `NMT_sp_tour_schedule_list(p_tour_id)`, `NMT_sp_tour_itinerary_list(p_tour_id)` |
| `NTK_` | Nguyễn Tuấn Khôi | `05_procedures_NTK.sql` | `NTK_sp_tour_image_list(p_tour_id)`, `NTK_sp_tour_inclusion_list(p_tour_id)`, `NTK_sp_tour_review_list(p_tour_id, p_limit)` |

Quy tắc chung:

- Chỉ trả về tour `status = 'published'` của đơn vị `is_active = 1`. Tour ẩn hoặc ID không tồn tại thì **0 dòng** ở mọi procedure (kể cả ảnh, lịch, đánh giá).
- `LTP_sp_tour_list`: `p_keyword` rỗng/NULL là không lọc. `p_destination_id` NULL hoặc 0 là mọi điểm đến. `p_sort` nhận `recommended` (mặc định), `newest`, `price_asc`, `price_desc`; giá trị khác được coi là `recommended`. Với `recommended`, tour chưa có đánh giá luôn xếp cuối.
- Tìm kiếm không phân biệt hoa thường và dấu thanh (`pho co` vẫn tìm ra "phố cổ"), nhưng **`d` khác `đ`** (`da nang` không tìm ra "Đà Nẵng"). Ký tự `%` và `_` trong từ khóa được tìm đúng nghĩa đen.
- `NMT_sp_tour_schedule_list` chỉ trả lịch từ hôm nay trở đi, `status = 'open'` và còn chỗ.
- `NTK_sp_tour_review_list`: `p_limit` NULL hoặc 0 thì lấy 5 đánh giá mới nhất.
- Mọi procedure chỉ đọc (`READS SQL DATA`), không có `DEFINER`.

## Dữ liệu mẫu và ca kiểm thử

Lịch khởi hành, ngày tạo tour và ngày đánh giá được tính **tương đối theo ngày import** (`CURDATE()` / `NOW()`). Sau khoảng 30 ngày không import lại, mọi lịch sẽ thành lịch đã qua. Khi đó chỉ cần import lại để làm mới.

| ID | Tour | Điểm đến | Giá / người | Đánh giá | Lịch sắp tới |
|---|---|---|---|---|---|
| 1 | Hà Nội qua những món ăn phố cổ | Hà Nội | 650.000đ | 4,8 (4) | 4 |
| 2 | Ẩm thực Hà Nội & cà phê trứng | Hà Nội | 720.000đ | 4,7 (3) | 3 |
| 3 | Phố cổ theo cách của bạn | Hà Nội | 900.000đ | 5,0 (2) | 3 |
| 4 | Bình minh trên bán đảo Sơn Trà | Đà Nẵng | 550.000đ | 4,5 (4) | 3 |
| 5 | Đà Nẵng về đêm: cầu Rồng và chợ đêm | Đà Nẵng | 480.000đ | 4,3 (3) | 4 |
| 6 | Hội An: phố cổ, đèn lồng và hoa đăng | Hội An | 590.000đ | 4,8 (4) | 3 |
| 7 | Làng rau Trà Quế: đạp xe và học nấu ăn | Hội An | 750.000đ | 4,7 (3) | 4 |
| 8 | Sài Gòn về đêm trên xe máy | TP. Hồ Chí Minh | 850.000đ | 4,5 (2) | 5 |
| 9 | Chợ Lớn: hẻm nhỏ, hội quán và món Hoa | TP. Hồ Chí Minh | 520.000đ | chưa có | 0 |
| 10 | Đạp xe quanh Hồ Tây lúc bình minh (**ẩn**) | Hà Nội | 400.000đ | không hiển thị | không hiển thị |

Ca kiểm thử có sẵn:

- **Tour ẩn:** ID 10 không bao giờ xuất hiện. `/tours/10` phải trả về "không tìm thấy" (404).
- **Tour không có đánh giá và lịch:** ID 9 dùng để kiểm thử trạng thái "Chưa có đánh giá" và "Chưa có lịch khởi hành sắp tới". Tour này cũng có `meeting_note` và `transport_note` để trống.
- **Lọc lịch:** tour 1 có 1 lịch đã qua và 1 lịch `full`; tour 2 có 1 lịch `open` nhưng hết chỗ; tour 4 có 1 lịch `cancelled`. Cả bốn lịch này đều không được hiển thị.
- **Lịch trình không cố định giờ:** tour 3 có `start_time` NULL ở mọi mục, và có 2 lịch cùng ngày khác giờ.
- **ID không tồn tại:** ví dụ 9999, phải trả về 0 dòng ở mọi procedure.
