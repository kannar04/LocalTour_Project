# Database LocalTour (`db_localtour`)

Phụ trách: **Nguyễn Minh Thức (NMT)** · WBS 3.2.2 · Sprint 3 (v0.1)

Thư mục này chứa toàn bộ script tạo database cho trang danh sách tour và trang chi tiết tour: bảng, khóa ngoại, chỉ mục, dữ liệu mẫu và stored procedure. Lược đồ gồm **17 bảng**, gộp từ hai trang ERD sơ bộ của nhóm và bảng yêu cầu FR (Phong chốt ngày 22/10/2026): 13 bảng của trang 01 "Lõi đặt tour" (có sửa), 3 bảng của trang 02 "Khám phá & vận hành" và bảng mới `tour_extras`. Khách hàng không có tài khoản, nên `users` chỉ có nhân viên và nhà cung cấp. Mọi khóa chính là `id CHAR(36)` chứa UUID. Mọi script chạy được trên **MariaDB 10.4 (XAMPP)** và **MySQL 8**, bảng mã `utf8mb4` / `utf8mb4_unicode_ci`. Mô tả chi tiết từng bảng xem [02 – Lược đồ dữ liệu](../../docs/sprint3/02-luoc-do-du-lieu.md).

> Toàn bộ dữ liệu trong `02_seed.sql` (tài khoản, nhà cung cấp, tour, giá, phụ thu, lịch, đơn đặt, thanh toán, đánh giá) là **dữ liệu minh họa**, không phải thông tin thật. Email dùng `@localtour.test`, số điện thoại là số giả, mã giao dịch có chữ `DEMO`.

## Các file

| File | Nội dung | Phụ trách | WBS |
|---|---|---|---|
| `01_schema.sql` | Xóa bảng (17 bảng hiện tại, 7 bảng đã bỏ của ERD trang 02 và 5 bảng của lược đồ cũ) rồi tạo lại 17 bảng: `users`, `providers`, `tours`, `tour_images`, `itinerary_stops`, `tour_extras`, `schedules`, `ticket_types`, `cancellation_policies`, `bookings`, `booking_lines`, `passengers`, `payments`, `payment_events`, `refunds`, `reviews`, `admin_logs`. Đầu file ghi lý do bỏ 7 bảng. Không có `CREATE DATABASE` / `USE`. | Thức | 3.1.2 |
| `02_seed.sql` | Dữ liệu mẫu: 9 tài khoản (1 quản trị viên, 1 nhân viên hỗ trợ, 7 nhà cung cấp), 7 nhà cung cấp, 10 tour (9 hiển thị + 1 chờ duyệt) cùng lịch, vé, chính sách hủy, ảnh, lịch trình, phụ thu / tùy chọn, đơn đặt, thanh toán và đánh giá. `admin_logs` để trống. | Thức | 3.2.2 |
| `03_procedures_LTP.sql` | Procedure cho trang danh sách tour. | Phong | 3.2.3 |
| `04_procedures_NMT.sql` | Procedure cho trang chi tiết: thông tin tour (kể cả phương tiện, hướng dẫn viên, điểm trả, không bao gồm, giấy tờ, ăn uống, voucher, đổi lịch), lịch khởi hành, vé, ảnh. | Thức | 3.2.4 |
| `05_procedures_NTK.sql` | Procedure cho nội dung trang chi tiết: lịch trình, phụ thu / hoạt động tùy chọn, đánh giá, chính sách hủy. | Khôi | 3.2.6 |

**Thứ tự import:** `01` → `02` → `03` → `04` → `05`.

**Chạy lại được:** `01_schema.sql` xóa và tạo lại bảng, kể cả 7 bảng đã bỏ (`notifications`, `tour_posts`, `post_comments`, `post_interactions`, `favorite_tours`, `comparisons`, `comparison_tours`) và các bảng của lược đồ cũ (`destinations`, `categories`, `tour_itinerary_items`, `tour_inclusions`, `tour_schedules`), nên database dùng chung không còn bảng thừa. Các file procedure dùng `DROP PROCEDURE IF EXISTS`, kể cả cho procedure cũ đã bỏ. Import lại sẽ **xóa hết dữ liệu cũ** trong `db_localtour` và nạp lại dữ liệu mẫu. Không ảnh hưởng database khác.

## File gộp `db_localtour.sql`

Để import một lần bằng phpMyAdmin, nhóm dùng **một file gộp** `src/database/db_localtour.sql`. File này:

- **được sinh tự động** từ 5 file trên, theo đúng thứ tự, có thêm 4 dòng đầu:
  ```sql
  -- File sinh tự động từ src/database/01..05, không sửa tay.
  CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  USE db_localtour;
  SET NAMES utf8mb4;
  ```
- **có trong Git**, để cả nhóm dùng cùng một bản. Muốn sửa dữ liệu hay procedure thì sửa file `01`–`05`, sinh lại file gộp rồi commit cùng lúc; không sửa tay file gộp.

Tự sinh file gộp (Git Bash, đứng ở thư mục gốc repo):

```bash
{ printf '%s\n' '-- File sinh tự động từ src/database/01..05, không sửa tay.' \
    'CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' \
    'USE db_localtour;' 'SET NAMES utf8mb4;'; cat src/database/0[1-5]_*.sql; } > src/database/db_localtour.sql
```

## Cách 1: Import bằng phpMyAdmin

1. Bật **Apache** và **MySQL** trong XAMPP Control Panel, mở <http://localhost/phpmyadmin>.
2. Bấm vào tên server ở góc trên bên trái (**không cần** chọn hay tạo database trước; file gộp tự tạo `db_localtour`).
3. Chọn tab **Import (Nhập)** → **Choose File** → chọn `src/database/db_localtour.sql`.
4. Giữ **Character set of the file: utf-8**, **Format: SQL**, các tùy chọn khác để mặc định → bấm **Import / Go**.
5. Kiểm tra: bấm `db_localtour` ở cột trái, mở tab **SQL** rồi chạy lần lượt 4 câu dưới đây (mỗi lần dán một câu, bấm **Go**, so với số ghi ở cuối dòng).

   ```sql
   SELECT COUNT(*) AS so_bang FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'db_localtour';                                       -- 17
   SELECT COUNT(*) AS so_procedure FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = 'db_localtour' AND ROUTINE_TYPE = 'PROCEDURE';      -- 10
   CALL LTP_sp_tour_list(NULL, NULL, NULL);                                    -- 9 dòng, tour 3 đứng đầu
   CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000001');        -- 2 dòng, dòng đầu kind = surcharge
   ```

   Đúng cả 4 kết quả là import thành công. Số bảng khác 17: tab **Structure** liệt kê tên bảng để so với danh sách ở mục "Các file". Số procedure khác 10: tab **Routines** phải có đúng 10 tên ở mục "Stored procedure và người phụ trách". Lỗi `PROCEDURE … does not exist` nghĩa là file `03`–`05` chưa được import: sinh lại file gộp rồi import lại.

## Cách 2: Import bằng mysql CLI

Luôn thêm `--default-character-set=utf8mb4`, nếu không tiếng Việt có thể bị lỗi thành `?`. Với XAMPP, `mysql` nằm ở `C:\xampp\mysql\bin\mysql.exe`.

File gộp, dùng Git Bash hoặc cmd (đứng ở thư mục gốc repo):

```bash
mysql -uroot --default-character-set=utf8mb4 < src/database/db_localtour.sql
```

File gộp, dùng PowerShell (đứng ở thư mục gốc repo; PowerShell không hỗ trợ dấu `<`):

```powershell
& C:\xampp\mysql\bin\mysql.exe -uroot --default-character-set=utf8mb4 -e "source src/database/db_localtour.sql"
```

Từng file, không cần file gộp (Git Bash, đứng trong `src/database`):

```bash
mysql -uroot --default-character-set=utf8mb4 -e "CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
for f in 01_schema.sql 02_seed.sql 03_procedures_LTP.sql 04_procedures_NMT.sql 05_procedures_NTK.sql; do
  mysql -uroot --default-character-set=utf8mb4 db_localtour < "$f" || break
done
```

Sau đó kiểm tra như bước 5 của Cách 1.

> Trên Windows, đừng gõ tiếng Việt trực tiếp trong `mysql -e "..."`: chữ có dấu bị đổi thành `?` trước khi tới server. Muốn thử `CALL` với từ khóa có dấu thì dùng tab SQL của phpMyAdmin hoặc ghi câu lệnh vào file rồi import.

## Stored procedure và người phụ trách

PHP chỉ gọi dữ liệu qua `Core\Database::call()` (câu `CALL` có tham số), không viết `SELECT` / `INSERT` / `UPDATE` / `DELETE` trong PHP. Tên procedure bắt đầu bằng tiền tố của người phụ trách. Tổng cộng **10 procedure**.

| Tiền tố | Người phụ trách | File | Procedure |
|---|---|---|---|
| `LTP_` | Lê Trung Phong | `03_procedures_LTP.sql` | `LTP_sp_tour_list(p_keyword, p_destination, p_sort)`, `LTP_sp_destination_list()` |
| `NMT_` | Nguyễn Minh Thức | `04_procedures_NMT.sql` | `NMT_sp_tour_detail(p_tour_id)`, `NMT_sp_tour_schedule_list(p_tour_id)`, `NMT_sp_tour_ticket_list(p_tour_id)`, `NMT_sp_tour_image_list(p_tour_id)` |
| `NTK_` | Nguyễn Tuấn Khôi | `05_procedures_NTK.sql` | `NTK_sp_tour_itinerary_list(p_tour_id)`, `NTK_sp_tour_extra_list(p_tour_id)`, `NTK_sp_tour_review_list(p_tour_id, p_limit)`, `NTK_sp_tour_cancellation_policy(p_tour_id)` |

`p_tour_id` là UUID dạng chữ (`CHAR(36)`); `p_keyword`, `p_destination` là `VARCHAR(100)`; `p_sort` là `VARCHAR(20)`. Ba procedure cũ `NMT_sp_tour_itinerary_list`, `NTK_sp_tour_image_list`, `NTK_sp_tour_inclusion_list` đã bỏ (chú ý tiền tố: ảnh là `NMT_`, lịch trình là `NTK_`); mục đã bao gồm và không bao gồm lấy từ `tours.included_summary`, `tours.excluded_summary`.

Quy tắc chung:

- Chỉ trả về tour công khai: tour `approval_status = 'approved'`, nhà cung cấp `approval_status = 'approved'` và tài khoản của nhà cung cấp `status = 'active'`. Tour không công khai hoặc UUID không tồn tại thì **0 dòng** ở mọi procedure (kể cả lịch, vé, ảnh, lịch trình, phụ thu / tùy chọn, đánh giá, chính sách hủy).
- **Lịch đặt được:** `status = 'open'`, `starts_at` sau thời điểm hiện tại, `remaining > 0` và có ít nhất một vé `active`. Chỉ vé `active` của các lịch này được trả về.
- **Giá "Từ" (`from_price_vnd`):** giá vé `adult` đang bán thấp nhất trong các lịch đặt được. Không lấy giá vé trẻ em thay thế: không có lịch đặt được hoặc không có vé `adult` đang bán thì `NULL`. Phụ thu / tùy chọn không bao giờ được cộng vào.
- **Điểm đánh giá:** chỉ tính đánh giá `moderation_status = 'approved'`.
- `LTP_sp_tour_list`: `p_keyword` rỗng/NULL là không lọc, có giá trị thì tìm "có chứa" trong tên tour, mô tả, điểm đến và tên nhà cung cấp. `p_destination` rỗng/NULL là mọi điểm đến, có giá trị thì phải trùng nguyên tên điểm đến. `p_sort` nhận `recommended` (mặc định, tab "Nổi bật"), `upcoming`, `price_asc`, `price_desc`; giá trị khác được coi là `recommended`. Tour chưa có đánh giá (với `recommended`), chưa có lịch (với `upcoming`) hoặc chưa có giá (với hai kiểu giá) luôn xếp cuối; cùng hạng thì theo tên tour.
- `LTP_sp_destination_list`: mỗi giá trị `tours.destination` của tour công khai kèm `tour_count`, nhiều tour trước, cùng số tour thì theo tên.
- Tìm kiếm và lọc điểm đến không phân biệt hoa thường và dấu thanh (`pho co` vẫn tìm ra "phố cổ", `ha noi` khớp "Hà Nội"), nhưng **`d` khác `đ`** (`da nang` không tìm ra "Đà Nẵng"). Ký tự `%` và `_` trong từ khóa được tìm đúng nghĩa đen.
- `NMT_sp_tour_detail`: ngoài thông tin chính còn trả 8 cột `transport`, `guide_info`, `dropoff_point`, `excluded_summary`, `document_terms`, `meal_terms`, `voucher_terms`, `reschedule_terms` (`NULL` = chưa cập nhật). Không trả 3 cột NFR-07 (`source_url`, `verified_at`, `verification_status`).
- `NTK_sp_tour_extra_list`: phụ thu (`surcharge`) trước, rồi hoạt động tùy chọn (`optional`), mỗi loại theo `sort_order` rồi `id`. `price_vnd`, `price_unit`, `conditions` có thể `NULL`.
- `NTK_sp_tour_review_list`: đánh giá đã duyệt, ngày đi tour gần nhất trước; `p_limit` NULL hoặc 0 thì lấy 5. `reviewer_name` là `bookings.contact_name` của đơn được đánh giá.
- `NTK_sp_tour_cancellation_policy`: chỉ trả phiên bản lớn nhất của tour.
- `NMT_sp_tour_image_list`, `NTK_sp_tour_itinerary_list`: chỉ dòng của chính tour, sắp theo `sort_order` / `stop_order` rồi `id`. `LTP_sp_tour_list` trả thêm `cover_image_url`, `cover_alt_text` của ảnh đầu tiên (`NULL` khi tour chưa có ảnh).
- Mọi procedure chỉ đọc (`READS SQL DATA`), không có `DEFINER`.

## Dữ liệu mẫu và ca kiểm thử

UUID được ghi cố định theo mẫu `<tiền tố bảng>-0000-4000-8000-<số 12 chữ số>`, ví dụ tour N = `c0000000-0000-4000-8000-00000000000N` (tour 10 = `…000000000010`), phụ thu / tùy chọn N = `c1000000-0000-4000-8000-00000000000N`. Lịch khởi hành và ngày duyệt được tính **tương đối theo ngày import** (`CURDATE()` / `NOW()`). Sau khoảng 30 ngày không import lại, mọi lịch sẽ thành lịch đã qua. Khi đó chỉ cần import lại để làm mới.

| Tour | Tên | Điểm đến | Giá từ | Đánh giá | Lịch đặt được | Phụ thu / tùy chọn | Thông tin để trống |
|---|---|---|---|---|---|---|---|
| 1 | Hà Nội qua những món ăn phố cổ | Hà Nội | 650.000đ | 4,8 (4) | 4 | 1 / 1 | — |
| 2 | Ẩm thực Hà Nội & cà phê trứng | Hà Nội | 720.000đ | 4,7 (3) | 3 | 0 / 0 | — |
| 3 | Phố cổ theo cách của bạn | Hà Nội | 900.000đ | 5,0 (2) | 3 | 1 / 2 | Điểm trả, Voucher |
| 4 | Bình minh trên bán đảo Sơn Trà | Đà Nẵng | 550.000đ | 4,5 (4) | 3 | 2 / 0 | — |
| 5 | Đà Nẵng về đêm: cầu Rồng và chợ đêm | Đà Nẵng | 480.000đ | 4,3 (3) | 4 | 0 / 1 | Không bao gồm |
| 6 | Hội An: phố cổ, đèn lồng và hoa đăng | Hội An | 590.000đ | 4,8 (4) | 3 | 0 / 2 | — |
| 7 | Làng rau Trà Quế: đạp xe và học nấu ăn | Hội An | 750.000đ | 4,7 (3) | 4 | 0 / 1 | Hướng dẫn viên, Đổi lịch |
| 8 | Sài Gòn về đêm trên xe máy | TP. Hồ Chí Minh | 850.000đ | 4,5 (2) | 5 | 1 / 1 | — |
| 9 | Chợ Lớn: hẻm nhỏ, hội quán và món Hoa | TP. Hồ Chí Minh | chưa có | chưa có | 0 | 0 / 0 | Cả 8 trường |
| 10 | Đạp xe quanh Hồ Tây lúc bình minh (**chờ duyệt**) | Hà Nội | không hiển thị | không hiển thị | không hiển thị | 1 / 1 (ẩn) | — |

"Thông tin để trống" là các cột thêm theo bảng FR (phương tiện, hướng dẫn viên, điểm trả, không bao gồm, giấy tờ, ăn uống, voucher, đổi lịch) có giá trị `NULL`; giao diện hiện "Chưa cập nhật".

Ca kiểm thử có sẵn:

- **Tour chờ duyệt:** tour 10 (`pending`) không bao giờ xuất hiện, dù có lịch mở và 3 đánh giá 5 sao. `/tours/c0000000-0000-4000-8000-000000000010` phải trả về "không tìm thấy" (404).
- **Tour không có đánh giá và lịch:** tour 9 dùng để kiểm thử "Chưa có đánh giá", "Chưa có lịch khởi hành sắp tới" và giá `NULL` → "Giá: Chưa cập nhật" (chỉ có lịch 34 đã hủy). Tour 9 cũng không có ảnh, lịch trình, phụ thu / tùy chọn.
- **Thông tin để trống:** tour 3, 5, 7, 9 theo cột cuối của bảng trên; các trường khác của cùng tour vẫn có nội dung.
- **Lọc lịch:** tour 1 có lịch 1 đã qua (`completed`) và lịch 2 `full`; tour 2 có lịch 7 `open` nhưng `remaining = 0`; tour 4 có lịch 15 `cancelled`. Cả bốn lịch này đều không được hiển thị.
- **Giá theo lịch và loại vé:** lịch 6 của tour 1 có giá người lớn 690.000đ (giá "Từ" của tour vẫn là 650.000đ); vé trẻ em của lịch 8 (tour 2) ngừng bán; tour 3 và 8 chỉ bán vé người lớn.
- **Hai lịch cùng ngày khác giờ:** tour 3, ngày import + 6 ngày, 08:30 và 14:00.
- **Đón tại khách sạn:** tour 4 và 8 (`hotel_pickup`); các tour còn lại có điểm hẹn.
- **Chính sách hủy hai phiên bản:** tour 4 có version 1 và 2; chỉ version 2 được trả về.
- **Đánh giá chờ duyệt:** đánh giá 29 (tour 1, 1 sao) không được hiện và không được tính; tour 1 vẫn là 4,8 (4).
- **Đơn đã hủy:** đơn 30 (tour 1) có thanh toán `paid` và một khoản hoàn tiền `completed`; không ảnh hưởng màn hình nào.
- **Ảnh tour:** mỗi file SVG chỉ thuộc một tour. Tour 2 và 9 không có ảnh → "Chưa cập nhật ảnh". Tour 4 có 2 ảnh cùng `sort_order` (ảnh bìa là ảnh có id nhỏ hơn); ảnh bìa của tour 6 có id lớn hơn ảnh thứ hai; tour 8 có 3 ảnh chèn lệch thứ tự, 1 ảnh `alt_text` là `NULL` (chú thích là tên tour).
- **Lịch trình:** chặng của tour 1–8 được chèn lệch thứ tự để kiểm tra `ORDER BY stop_order`; một số chặng có `description` hoặc `duration_minutes` là `NULL`.
- **Phụ thu / tùy chọn:** được chèn lệch thứ tự (tour 1: tùy chọn chèn trước phụ thu) nhưng phụ thu luôn ra trước. Tour 4 "Phụ thu ngày lễ" và tour 8 tùy chọn quán bar có giá `NULL`; tour 6 "Thuê áo dài chụp ảnh" có giá nhưng không có đơn vị. Tour 4 chỉ có phụ thu, tour 5, 6, 7 chỉ có tùy chọn. Không dòng nào được cộng vào giá "Từ" hay tạm tính tiền vé.
- **Ảnh, lịch trình, phụ thu của tour bị ẩn:** tour 10 có 1 ảnh, 4 chặng và 2 phụ thu / tùy chọn, nhưng các procedure ảnh, lịch trình và phụ thu phải trả 0 dòng.
- **NFR-07:** mọi tour có `source_url`, `verified_at` là `NULL` và `verification_status = 'unverified'` (dữ liệu minh họa, không gán nguồn hay ngày giả).
- **Không có tài khoản khách:** `users` có 9 dòng (`admin`, `support`, 7 `provider`); `bookings` và `reviews` không nối với `users`, tên người đánh giá lấy từ đơn đặt.
- **UUID không tồn tại:** ví dụ `c0000000-0000-4000-8000-000000009999`, phải trả về 0 dòng ở mọi procedure.

Thứ tự mong đợi của 9 tour ngay sau khi import: `recommended` 3, 1, 6, 2, 7, 4, 8, 5, 9 · `upcoming` 4, 6, 8, 5, 1, 7, 2, 3, 9 · `price_asc` 5, 4, 6, 1, 2, 7, 8, 3, 9 · `price_desc` 3, 8, 7, 2, 1, 6, 4, 5, 9. Căn cứ xem [02 – Lược đồ dữ liệu](../../docs/sprint3/02-luoc-do-du-lieu.md), mục 8.3.

## Câu lệnh thử nhanh

Chạy trong tab **SQL** của `db_localtour` trên phpMyAdmin (có tiếng Việt nên không chạy qua `mysql -e` trên Windows):

```sql
CALL LTP_sp_tour_list(NULL, NULL, NULL);                                  -- 9 dòng, thứ tự "Nổi bật"
CALL LTP_sp_tour_list(NULL, 'Hà Nội', 'price_asc');                       -- tour 1, 2, 3
CALL LTP_sp_destination_list();                                           -- 4 điểm đến, Hà Nội (3) đứng đầu
CALL NMT_sp_tour_detail('c0000000-0000-4000-8000-000000000001');          -- 1 dòng, from_price_vnd = 650000, có transport … reschedule_terms
CALL NMT_sp_tour_detail('c0000000-0000-4000-8000-000000000009');          -- 1 dòng, 8 cột cuối đều NULL
CALL NMT_sp_tour_schedule_list('c0000000-0000-4000-8000-000000000001');   -- 4 lịch đặt được
CALL NMT_sp_tour_ticket_list('c0000000-0000-4000-8000-000000000001');     -- 8 vé (người lớn + trẻ em của 4 lịch)
CALL NTK_sp_tour_review_list('c0000000-0000-4000-8000-000000000001', 5);  -- 4 đánh giá đã duyệt
CALL NTK_sp_tour_cancellation_policy('c0000000-0000-4000-8000-000000000004'); -- version 2
CALL NMT_sp_tour_image_list('c0000000-0000-4000-8000-000000000001');      -- 1 ảnh: img/tours/hanoi-1.svg
CALL NTK_sp_tour_itinerary_list('c0000000-0000-4000-8000-000000000001');  -- 5 chặng, stop_order 1 → 5
CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000001');      -- 2 dòng: phụ thu trước, rồi tùy chọn
CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000004');      -- 2 phụ thu: "đón ngoài khu trung tâm", rồi "ngày lễ" (giá NULL)
CALL NMT_sp_tour_image_list('c0000000-0000-4000-8000-000000000009');      -- 0 dòng (tour chưa có ảnh)
CALL NMT_sp_tour_detail('c0000000-0000-4000-8000-000000000010');          -- 0 dòng (tour chờ duyệt)
CALL NTK_sp_tour_itinerary_list('c0000000-0000-4000-8000-000000000010');  -- 0 dòng (tour chờ duyệt)
CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000010');      -- 0 dòng (tour chờ duyệt)
```
