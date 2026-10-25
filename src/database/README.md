# Database LocalTour (`db_localtour`)

Phụ trách: **Nguyễn Minh Thức (NMT)** · WBS 3.2.2 · Sprint 3 (v0.1)

Thư mục này chứa toàn bộ script tạo database cho trang danh sách tour, trang chi tiết tour, tài khoản khách hàng và trang quản trị: bảng, khóa ngoại, chỉ mục, dữ liệu mẫu và stored procedure. Lược đồ gồm **27 bảng** (danh sách ở mục "Các file", lý do giữ / bỏ bảng ghi ở đầu `01_schema.sql`). Khách hàng có tài khoản (`users.role = 'customer'`): chưa đăng nhập (chế độ khách) chỉ xem tour; muốn đặt tour phải đăng nhập, mỗi đơn đặt thuộc một tài khoản (`bookings.user_id`). Mọi khóa chính là `id CHAR(36)` chứa UUID. Mọi script chạy được trên **MariaDB 10.4 (XAMPP)** và **MySQL 8**, bảng mã `utf8mb4` / `utf8mb4_unicode_ci`. Mô tả chi tiết từng bảng xem [02 – Lược đồ dữ liệu](../../docs/sprint3/02-luoc-do-du-lieu.md).

> Toàn bộ dữ liệu trong `02_seed.sql` (tài khoản, nhà cung cấp, tour, giá, phụ thu, lịch, đơn đặt, thanh toán, đánh giá) là **dữ liệu minh họa**, không phải thông tin thật. Email dùng `@localtour.test`, số điện thoại là số giả dạng `0000000xxx`, mã giao dịch có chữ `DEMO`. Mọi tài khoản mẫu có `password_hash = NULL` nên **không đăng nhập được**.

## Các file

| File | Nội dung | Phụ trách | WBS |
|---|---|---|---|
| `01_schema.sql` | Xóa rồi tạo lại 27 bảng (2 bảng đã bỏ `post_comments`, `post_interactions` chỉ bị xóa). Tài khoản: `users`, `providers`. Danh mục: `destinations`, `categories`. Tour và nội dung: `tours`, `tour_images`, `tour_itinerary_items`, `tour_inclusions`, `tour_extras`, `itinerary_stops`, `tour_schedules`. Lịch, vé, chính sách: `schedules`, `ticket_types`, `cancellation_policies`. Đặt chỗ: `bookings`, `booking_lines`, `passengers`. Giao dịch: `payments`, `payment_events`, `refunds`. Đánh giá: `reviews`. Khám phá: `tour_posts`, `favorite_tours`, `notifications`, `comparisons`, `comparison_tours`. Nhật ký: `admin_logs`. Không có `CREATE DATABASE` / `USE`. | Thức | 3.1.2 |
| `02_seed.sql` | Dữ liệu mẫu: 49 tài khoản (1 quản trị viên, 1 nhân viên hỗ trợ, 7 nhà cung cấp, 40 khách hàng, trong đó 1 bị khóa), 7 nhà cung cấp, 5 điểm đến, 6 loại hình, 12 tour (9 hiển thị, 2 chờ duyệt, 1 bị từ chối) cùng lịch, vé, chính sách hủy, ảnh, lịch trình, dịch vụ bao gồm / không bao gồm, phụ thu / tùy chọn, đơn đặt, thanh toán, đánh giá và lịch sử xử lý của quản trị viên. Các bảng chưa dùng để trống (mục "Dữ liệu mẫu"). | Thức | 3.2.2 |
| `03_procedures_LTP.sql` | Procedure cho trang danh sách tour: danh sách, điểm đến, loại hình. Trang duyệt tour của quản trị viên: danh sách, chi tiết, phê duyệt / từ chối. | Phong | 3.2.3, CR1 |
| `04_procedures_NMT.sql` | Procedure cho trang chi tiết: thông tin tour (kể cả điểm đến, loại hình, phương tiện, hướng dẫn viên, điểm trả, giấy tờ, ăn uống, voucher, đổi lịch), lịch khởi hành, vé, ảnh. Thống kê của trang quản trị: tổng quan, yêu cầu theo trạng thái, yêu cầu theo thời gian, doanh thu. | Thức | 3.2.4, CR1 |
| `05_procedures_NTK.sql` | Procedure cho nội dung trang chi tiết: lịch trình, dịch vụ bao gồm / không bao gồm, phụ thu / hoạt động tùy chọn, đánh giá, chính sách hủy. | Khôi | 3.2.6 |
| `06_procedures_NTK_account.sql` | Procedure cho tài khoản khách hàng: đăng ký, tìm tài khoản theo email khi đăng nhập. | Khôi | 3.2.8 |
| `07_procedures_NTK_admin.sql` | Procedure cho trang yêu cầu đặt tour của quản trị viên: danh sách, chi tiết, dòng vé, cập nhật trạng thái, lịch sử xử lý. | Khôi | CR1 |
| `db_localtour.sql` | File gộp `01`–`07` để import một lần (mục dưới). | — | — |

**Thứ tự import:** `01` → `02` → `03` → `04` → `05` → `06` → `07`.

**Chạy lại được:** `01_schema.sql` xóa rồi tạo lại mọi bảng, kể cả 2 bảng đã bỏ (`post_comments`, `post_interactions`), nên database dùng chung không còn bảng thừa. Các file procedure dùng `DROP PROCEDURE IF EXISTS`, kể cả cho procedure cũ đã bỏ. Import lại sẽ **xóa hết dữ liệu cũ** trong `db_localtour`, kể cả tài khoản đã đăng ký thử, rồi nạp lại dữ liệu mẫu. Không ảnh hưởng database khác.

## File gộp `db_localtour.sql`

Để import một lần bằng phpMyAdmin, nhóm dùng **một file gộp** `src/database/db_localtour.sql`. File này:

- **được sinh tự động** từ 7 file trên, theo đúng thứ tự, có thêm 4 dòng đầu:
  ```sql
  -- File sinh tự động từ src/database/01..07, không sửa tay.
  CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  USE db_localtour;
  SET NAMES utf8mb4;
  ```
- **có trong Git**, để cả nhóm dùng cùng một bản. Muốn sửa dữ liệu hay procedure thì sửa file `01`–`07`, sinh lại file gộp rồi commit cùng lúc; không sửa tay file gộp.

Tự sinh file gộp (Git Bash, đứng ở thư mục gốc repo):

```bash
{ printf '%s\n' '-- File sinh tự động từ src/database/01..07, không sửa tay.' \
    'CREATE DATABASE IF NOT EXISTS db_localtour CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' \
    'USE db_localtour;' 'SET NAMES utf8mb4;'; cat src/database/0[1-7]_*.sql; } > src/database/db_localtour.sql
```

## Cách 1: Import bằng phpMyAdmin

1. Bật **Apache** và **MySQL** trong XAMPP Control Panel, mở <http://localhost/phpmyadmin>.
2. Bấm vào tên server ở góc trên bên trái (**không cần** chọn hay tạo database trước; file gộp tự tạo `db_localtour`).
3. Chọn tab **Import (Nhập)** → **Choose File** → chọn `src/database/db_localtour.sql`.
4. Giữ **Character set of the file: utf-8**, **Format: SQL**, các tùy chọn khác để mặc định → bấm **Import / Go**.
5. Kiểm tra: bấm `db_localtour` ở cột trái, mở tab **SQL** rồi chạy lần lượt 4 câu dưới đây (mỗi lần dán một câu, bấm **Go**, so với số ghi ở cuối dòng).

   ```sql
   SELECT COUNT(*) AS so_bang FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'db_localtour';                                       -- 27
   SELECT COUNT(*) AS so_procedure FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = 'db_localtour' AND ROUTINE_TYPE = 'PROCEDURE';      -- 26
   CALL LTP_sp_tour_list(NULL, NULL, NULL, NULL);                              -- 9 dòng, tour 3 đứng đầu
   CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000001');        -- 2 dòng, dòng đầu kind = surcharge
   ```

   Đúng cả 4 kết quả là import thành công. Số bảng khác 27: tab **Structure** liệt kê tên bảng để so với danh sách ở mục "Các file". Số procedure khác 26: tab **Routines** phải có đúng 26 tên ở mục "Stored procedure và người phụ trách". Lỗi `PROCEDURE … does not exist` nghĩa là file `03`–`07` chưa được import: sinh lại file gộp rồi import lại.

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
for f in 01_schema.sql 02_seed.sql 03_procedures_LTP.sql 04_procedures_NMT.sql 05_procedures_NTK.sql 06_procedures_NTK_account.sql 07_procedures_NTK_admin.sql; do
  mysql -uroot --default-character-set=utf8mb4 db_localtour < "$f" || break
done
```

Sau đó kiểm tra như bước 5 của Cách 1.

> Trên Windows, đừng gõ tiếng Việt trực tiếp trong `mysql -e "..."`: chữ có dấu bị đổi thành `?` trước khi tới server. Muốn thử `CALL` với từ khóa có dấu thì dùng tab SQL của phpMyAdmin hoặc ghi câu lệnh vào file rồi import.

## Stored procedure và người phụ trách

PHP chỉ gọi dữ liệu qua `Core\Database::call()` (câu `CALL` có tham số), không viết `SELECT` / `INSERT` / `UPDATE` / `DELETE` trong PHP. Tên procedure bắt đầu bằng tiền tố của người phụ trách. Tổng cộng **26 procedure**.

| Tiền tố | Người phụ trách | File | Procedure |
|---|---|---|---|
| `LTP_` | Lê Trung Phong | `03_procedures_LTP.sql` | `LTP_sp_tour_list(p_keyword, p_destination_id, p_category_id, p_sort)`, `LTP_sp_destination_list()`, `LTP_sp_category_list()`, `LTP_sp_admin_tour_list(p_approval_status)`, `LTP_sp_admin_tour_detail(p_tour_id)`, `LTP_sp_admin_tour_set_approval(p_tour_id, p_new_status, p_actor_user_id, p_note)` |
| `NMT_` | Nguyễn Minh Thức | `04_procedures_NMT.sql` | `NMT_sp_tour_detail(p_tour_id)`, `NMT_sp_tour_schedule_list(p_tour_id)`, `NMT_sp_tour_ticket_list(p_tour_id)`, `NMT_sp_tour_image_list(p_tour_id)`, `NMT_sp_admin_summary()`, `NMT_sp_admin_booking_status_stats()`, `NMT_sp_admin_booking_time_stats(p_period, p_from, p_to)`, `NMT_sp_admin_revenue_stats(p_period, p_from, p_to)` |
| `NTK_` | Nguyễn Tuấn Khôi | `05_procedures_NTK.sql` | `NTK_sp_tour_itinerary_list(p_tour_id)`, `NTK_sp_tour_inclusion_list(p_tour_id)`, `NTK_sp_tour_extra_list(p_tour_id)`, `NTK_sp_tour_review_list(p_tour_id, p_limit)`, `NTK_sp_tour_cancellation_policy(p_tour_id)` |
| `NTK_` | Nguyễn Tuấn Khôi | `06_procedures_NTK_account.sql` | `NTK_sp_customer_register(p_name, p_email, p_phone, p_password_hash)`, `NTK_sp_user_find_by_email(p_email)` |
| `NTK_` | Nguyễn Tuấn Khôi | `07_procedures_NTK_admin.sql` | `NTK_sp_admin_booking_list(p_status, p_keyword)`, `NTK_sp_admin_booking_detail(p_booking_id)`, `NTK_sp_admin_booking_line_list(p_booking_id)`, `NTK_sp_admin_log_list(p_target_type, p_target_id)`, `NTK_sp_admin_booking_set_status(p_booking_id, p_new_status, p_actor_user_id, p_note)` |

`p_tour_id`, `p_destination_id`, `p_category_id` là UUID dạng chữ (`CHAR(36)`); `p_keyword` là `VARCHAR(100)`; `p_sort` là `VARCHAR(20)`; `p_name` `VARCHAR(100)`, `p_email` `VARCHAR(150)`, `p_phone` `VARCHAR(20)`, `p_password_hash` `VARCHAR(255)`. Trang quản trị: `p_booking_id`, `p_target_id`, `p_actor_user_id` là UUID; `p_approval_status` `VARCHAR(20)`, `p_status` `VARCHAR(30)`, `p_new_status` `VARCHAR(20)` (tour) hoặc `VARCHAR(30)` (yêu cầu đặt tour), `p_note` `VARCHAR(255)`, `p_period` `VARCHAR(10)`, `p_from` / `p_to` `DATE`. Hai procedure cũ `NMT_sp_tour_itinerary_list`, `NTK_sp_tour_image_list` đã bỏ (chú ý tiền tố: ảnh là `NMT_`, lịch trình là `NTK_`).

Quy tắc chung:

- **Trang khách:** chỉ trả về tour công khai: tour `approval_status = 'approved'`, nhà cung cấp `approval_status = 'approved'` và tài khoản của nhà cung cấp `status = 'active'`. Tour không công khai hoặc UUID không tồn tại thì **0 dòng** ở mọi procedure về tour (kể cả lịch, vé, ảnh, lịch trình, dịch vụ, phụ thu / tùy chọn, đánh giá, chính sách hủy).
- **Lịch đặt được:** `status = 'open'`, `starts_at` sau thời điểm hiện tại, `remaining > 0` và có ít nhất một vé `active`. Chỉ vé `active` của các lịch này được trả về.
- **Giá "Từ" (`from_price_vnd`):** giá vé `adult` đang bán thấp nhất trong các lịch đặt được. Không lấy giá vé trẻ em thay thế: không có lịch đặt được hoặc không có vé `adult` đang bán thì `NULL`. Phụ thu / tùy chọn không bao giờ được cộng vào.
- **Điểm đánh giá:** chỉ tính đánh giá `moderation_status = 'approved'`.
- `LTP_sp_tour_list`: `p_keyword` rỗng/NULL là không lọc, có giá trị thì tìm "có chứa" trong tên tour, mô tả, tên điểm đến, tên loại hình và tên nhà cung cấp. `p_destination_id` / `p_category_id` rỗng/NULL là không lọc, có giá trị thì chỉ lấy tour có `tours.destination_id` / `tours.category_id` bằng giá trị đó. `p_sort` nhận `recommended` (mặc định, tab "Nổi bật"), `upcoming`, `price_asc`, `price_desc`; giá trị khác được coi là `recommended`. Tour chưa có đánh giá (với `recommended`), chưa có lịch (với `upcoming`) hoặc chưa có giá (với hai kiểu giá) luôn xếp cuối; cùng hạng thì theo tên tour. Trả thêm `destination_id`, `destination_name` (`destinations.name`, tour chưa gán điểm đến thì dùng `tours.destination`), `category_id`, `category_name` (`NULL` nếu chưa gán) và `cover_image_url`, `cover_alt_text` của ảnh đầu tiên (`NULL` khi tour chưa có ảnh).
- `LTP_sp_destination_list` / `LTP_sp_category_list`: lấy từ bảng `destinations` / `categories`, chỉ dòng có ít nhất một tour công khai, kèm `tour_count`. Điểm đến theo `sort_order` rồi tên; loại hình theo tên.
- Tìm kiếm không phân biệt hoa thường và dấu thanh (`pho co` vẫn tìm ra "phố cổ", `ha noi` khớp "Hà Nội"), nhưng **`d` khác `đ`** (`da nang` không tìm ra "Đà Nẵng"). Ký tự `%` và `_` trong từ khóa được tìm đúng nghĩa đen.
- `NMT_sp_tour_detail`: ngoài thông tin chính còn trả `destination_id`, `destination_name`, `category_id`, `category_name` và 7 cột `transport`, `guide_info`, `dropoff_point`, `document_terms`, `meal_terms`, `voucher_terms`, `reschedule_terms` (`NULL` = chưa cập nhật). Không trả `included_summary`, `excluded_summary` (không dùng) và 3 cột NFR-07 (`source_url`, `verified_at`, `verification_status`).
- `NTK_sp_tour_itinerary_list`: đọc `tour_itinerary_items`; cột `item_id`, `start_time` (`NULL` = mục không ghi giờ), `description`, `sort_order`; theo `sort_order` rồi `id`.
- `NTK_sp_tour_inclusion_list`: đọc `tour_inclusions`; cột `inclusion_id`, `item_text`, `is_included` (1 = bao gồm, 0 = không bao gồm), `sort_order`; mục bao gồm trước, rồi `sort_order`, rồi `id`.
- `NTK_sp_tour_extra_list`: phụ thu (`surcharge`) trước, rồi hoạt động tùy chọn (`optional`), mỗi loại theo `sort_order` rồi `id`. `price_vnd`, `price_unit`, `conditions` có thể `NULL`.
- `NTK_sp_tour_review_list`: đánh giá đã duyệt, ngày đi tour gần nhất trước; `p_limit` NULL hoặc 0 thì lấy 5. `reviewer_name` là `users.name` của tài khoản đã đặt đơn được đánh giá (`bookings.user_id`).
- `NTK_sp_tour_cancellation_policy`: chỉ trả phiên bản lớn nhất của tour.
- `NMT_sp_tour_image_list`: chỉ ảnh của chính tour, theo `sort_order` rồi `id`.
- `NTK_sp_customer_register`: tạo tài khoản `customer`, `active` với UUID mới, email lưu chữ thường; trả 1 dòng `user_id`, `NULL` khi email đã được dùng (kể cả khác chữ hoa / thường). PHP kiểm tra dữ liệu và băm mật khẩu bằng `password_hash()` trước khi gọi; procedure không bao giờ nhận mật khẩu gốc.
- `NTK_sp_user_find_by_email`: 0 hoặc 1 dòng `user_id`, `name`, `email`, `password_hash`, `role`, `status`. PHP tự kiểm tra `role = 'customer'`, `status = 'active'` và `password_verify` trước khi cho đăng nhập.
- **Trang quản trị** (`LTP_sp_admin_…`, `NMT_sp_admin_…`, `NTK_sp_admin_…`): xem mọi tour và mọi yêu cầu đặt tour, kể cả tour chờ duyệt hoặc bị từ chối. PHP chỉ gọi sau khi kiểm tra tài khoản đăng nhập là quản trị viên đang hoạt động; hai procedure ghi dữ liệu kiểm tra lại `p_actor_user_id` và trả `forbidden` nếu không phải.
- `LTP_sp_admin_tour_set_approval`: chỉ `pending` → `approved` hoặc `rejected`; từ chối bắt buộc lý do. Trả 1 dòng `result` (`ok`, `forbidden`, `not_found`, `invalid_transition`, `note_required`) và `approval_status`; ghi `admin_logs` (`tour_approve` / `tour_reject`).
- `NTK_sp_admin_booking_set_status`: `pending` → `awaiting_payment` / `rejected` / `cancelled`; `awaiting_payment` → `confirmed` / `cancelled`; `confirmed` → `completed` / `cancelled`. Từ chối và hủy bắt buộc lý do. Xác nhận đã thanh toán cần khoản thanh toán `paid` hoặc chuyển khoản VietQR `awaiting_reconciliation` (được ghi thành `paid`); hoàn thành chỉ sau giờ khởi hành; chờ thanh toán có hạn 24 giờ (`hold_expires_at`). Trả 1 dòng `result` (thêm `needs_payment`, `not_departed`); ghi `admin_logs` (`booking_status`) gồm trạng thái cũ, trạng thái mới và lý do.
- Thống kê (`NMT_sp_admin_…`): khách hàng là `users.role = 'customer'` (kể cả tài khoản bị khóa); yêu cầu theo thời gian tính theo `bookings.created_at`; doanh thu tính theo `payments.paid_at` của khoản `paid`, trừ tiền hoàn `refunds` `completed`. `p_period` là `day`, `month` hoặc `year`; `p_from`, `p_to` NULL là không giới hạn.
- Không procedure nào có `DEFINER`. Chỉ `NTK_sp_customer_register`, `LTP_sp_admin_tour_set_approval` và `NTK_sp_admin_booking_set_status` ghi dữ liệu (`MODIFIES SQL DATA`); các procedure khác chỉ đọc (`READS SQL DATA`).

## Dữ liệu mẫu và ca kiểm thử

UUID được ghi cố định theo mẫu `<tiền tố bảng>-0000-4000-8000-<số 12 chữ số>`, ví dụ tour N = `c0000000-0000-4000-8000-00000000000N` (tour 10 = `…000000000010`), điểm đến N = `c2000000-…-00000000000N`, loại hình N = `c3000000-…-00000000000N`. Bảng mã tiền tố đầy đủ ở đầu `02_seed.sql`. Lịch khởi hành và ngày duyệt được tính **tương đối theo ngày import** (`CURDATE()` / `NOW()`). Sau khoảng 30 ngày không import lại, mọi lịch sẽ thành lịch đã qua. Khi đó chỉ cần import lại để làm mới.

| Tour | Tên | Điểm đến | Loại hình | Giá từ | Đánh giá | Lịch đặt được | Phụ thu / tùy chọn | Thông tin để trống |
|---|---|---|---|---|---|---|---|---|
| 1 | Hà Nội qua những món ăn phố cổ | Hà Nội | Ẩm thực | 650.000đ | 4,8 (4) | 4 | 1 / 1 | — |
| 2 | Ẩm thực Hà Nội & cà phê trứng | Hà Nội | Ẩm thực | 720.000đ | 4,7 (3) | 3 | 0 / 0 | — |
| 3 | Phố cổ theo cách của bạn | Hà Nội | Văn hóa – lịch sử | 900.000đ | 5,0 (2) | 3 | 1 / 2 | Điểm trả, Voucher |
| 4 | Bình minh trên bán đảo Sơn Trà | Đà Nẵng | Thiên nhiên | 550.000đ | 4,5 (4) | 3 | 2 / 0 | — |
| 5 | Đà Nẵng về đêm: cầu Rồng và chợ đêm | Đà Nẵng | Về đêm | 480.000đ | 4,3 (3) | 4 | 0 / 1 | Không bao gồm |
| 6 | Hội An: phố cổ, đèn lồng và hoa đăng | Hội An | Văn hóa – lịch sử | 590.000đ | 4,8 (4) | 3 | 0 / 2 | — |
| 7 | Làng rau Trà Quế: đạp xe và học nấu ăn | Hội An | Trải nghiệm địa phương | 750.000đ | 4,7 (3) | 4 | 0 / 1 | Hướng dẫn viên, Đổi lịch |
| 8 | Sài Gòn về đêm trên xe máy | TP. Hồ Chí Minh | Về đêm | 850.000đ | 4,5 (2) | 5 | 1 / 1 | — |
| 9 | Chợ Lớn: hẻm nhỏ, hội quán và món Hoa | TP. Hồ Chí Minh | chưa có | chưa có | chưa có | 0 | 0 / 0 | Cả 7 trường, dịch vụ, loại hình |
| 10 | Đạp xe quanh Hồ Tây lúc bình minh (**chờ duyệt**) | Hà Nội | Đạp xe | không hiển thị | không hiển thị | không hiển thị | 1 / 1 (ẩn) | — |
| 11 | Một buổi chiều trong Đại Nội Huế (**chờ duyệt**) | Huế | Văn hóa – lịch sử | không hiển thị | chưa có | 2 (ẩn) | 0 / 0 | — |
| 12 | Làm đèn lồng cùng nghệ nhân phố Hội (**bị từ chối**) | Hội An | Trải nghiệm địa phương | không hiển thị | chưa có | 0 | 0 / 0 | Cả 7 trường |

"Thông tin để trống" là các cột thêm theo bảng FR (phương tiện, hướng dẫn viên, điểm trả, giấy tờ, ăn uống, voucher, đổi lịch) có giá trị `NULL`, và phần "không bao gồm" khi tour không có dòng `tour_inclusions` với `is_included = 0`; giao diện hiện "Chưa cập nhật".

Ca kiểm thử có sẵn:

- **Tài khoản khách hàng:** `users` có 49 dòng: `admin`, `support`, 7 `provider` và 40 `customer` (khách hàng 100 + N là người đặt đơn N, N = 1–39; khách hàng 140 bị khóa). Mọi tài khoản mẫu có `password_hash = NULL`, nên đăng nhập bằng tài khoản mẫu luôn báo "Email hoặc mật khẩu không đúng.". **Muốn thử đăng nhập, tự đăng ký tài khoản mới ở `/register`** (không ghi email, mật khẩu thử vào tài liệu hay commit). Đăng ký bằng email của một tài khoản mẫu bất kỳ, kể cả khác chữ hoa / thường, phải báo "Email này đã được dùng.". Import lại database sẽ xóa các tài khoản đã đăng ký thử.
- **Tour chờ duyệt:** tour 10 (`pending`) không bao giờ xuất hiện, dù có lịch mở và 3 đánh giá 5 sao. `/tours/c0000000-0000-4000-8000-000000000010` phải trả về "không tìm thấy" (404). Tour 11 (`pending`) và tour 12 (`rejected`) cũng vậy.
- **Tour không có đánh giá và lịch:** tour 9 dùng để kiểm thử "Chưa có đánh giá", "Chưa có lịch khởi hành sắp tới" và giá `NULL` → "Giá: Chưa cập nhật" (chỉ có lịch 34 đã hủy). Tour 9 cũng không có ảnh, lịch trình, dịch vụ, phụ thu / tùy chọn và loại hình (`category_id` `NULL` → "Loại hình: Chưa cập nhật").
- **Thông tin để trống:** tour 3, 5, 7, 9 theo cột cuối của bảng trên; các trường khác của cùng tour vẫn có nội dung.
- **Điểm đến:** bộ lọc và thanh bên có 4 điểm đến theo `sort_order` (Hà Nội 3 tour, Đà Nẵng 2, Hội An 2, TP. Hồ Chí Minh 2). Huế chỉ có tour 11 (chờ duyệt) nên bị ẩn; tour 10 chờ duyệt không được đếm.
- **Loại hình:** bộ lọc có 5 loại hình. "Đạp xe" chỉ có tour 10 (chờ duyệt) nên bị ẩn; tour 9 không thuộc loại hình nào.
- **Lọc lịch:** tour 1 có lịch 1 đã qua (`completed`) và lịch 2 `full`; tour 2 có lịch 7 `open` nhưng `remaining = 0`; tour 4 có lịch 15 `cancelled`. Cả bốn lịch này đều không được hiển thị.
- **Giá theo lịch và loại vé:** lịch 6 của tour 1 có giá người lớn 690.000đ (giá "Từ" của tour vẫn là 650.000đ); vé trẻ em của lịch 8 (tour 2) ngừng bán; tour 3 và 8 chỉ bán vé người lớn.
- **Hai lịch cùng ngày khác giờ:** tour 3, ngày import + 6 ngày, 08:30 và 14:00.
- **Đón tại khách sạn:** tour 4 và 8 (`hotel_pickup`); các tour còn lại có điểm hẹn.
- **Chính sách hủy hai phiên bản:** tour 4 có version 1 và 2; chỉ version 2 được trả về.
- **Đánh giá chờ duyệt:** đánh giá 29 (tour 1, 1 sao) không được hiện và không được tính; tour 1 vẫn là 4,8 (4).
- **Tên người đánh giá:** lấy từ `users.name` của chủ đơn (`bookings.user_id`); trong dữ liệu mẫu trùng `contact_name` của đơn.
- **Đơn đã hủy:** đơn 30 (tour 1) có thanh toán `paid` và một khoản hoàn tiền `completed`; không ảnh hưởng màn hình nào.
- **Ảnh tour:** mỗi file SVG chỉ thuộc một tour. Tour 2 và 9 không có ảnh → "Chưa cập nhật ảnh". Tour 4 có 2 ảnh cùng `sort_order` (ảnh bìa là ảnh có id nhỏ hơn); ảnh bìa của tour 6 có id lớn hơn ảnh thứ hai; tour 8 có 3 ảnh chèn lệch thứ tự, 1 ảnh `alt_text` là `NULL` (chú thích là tên tour).
- **Lịch trình:** tour 1–8 có 4–5 mục `tour_itinerary_items` chèn lệch thứ tự để kiểm tra `ORDER BY sort_order`. Tour 3 có mọi `start_time` là `NULL` (chỉ hiện mô tả); mục trả khách về khách sạn của tour 4 và 8 không ghi giờ.
- **Dịch vụ bao gồm / không bao gồm:** tour 1–8 có danh sách bao gồm; tour 5 không có dòng không bao gồm → "Chưa cập nhật". Tour 4 chèn dòng không bao gồm trước và lệch `sort_order`, nhưng mục bao gồm luôn ra trước.
- **Phụ thu / tùy chọn:** được chèn lệch thứ tự (tour 1: tùy chọn chèn trước phụ thu) nhưng phụ thu luôn ra trước. Tour 4 "Phụ thu ngày lễ" và tour 8 tùy chọn quán bar có giá `NULL`; tour 6 "Thuê áo dài chụp ảnh" có giá nhưng không có đơn vị. Tour 4 chỉ có phụ thu, tour 5, 6, 7 chỉ có tùy chọn. Không dòng nào được cộng vào giá "Từ" hay tạm tính tiền vé.
- **Nội dung của tour bị ẩn:** tour 10 có ảnh, lịch trình, dịch vụ và 2 phụ thu / tùy chọn, nhưng các procedure tương ứng phải trả 0 dòng.
- **Bảng để trống:** `itinerary_stops`, `tour_schedules`, `tour_posts`, `favorite_tours`, `notifications`, `comparisons`, `comparison_tours` có 0 dòng; `tours.included_summary`, `excluded_summary` là `NULL`.
- **NFR-07:** mọi tour có `source_url`, `verified_at` là `NULL` và `verification_status = 'unverified'` (dữ liệu minh họa, không gán nguồn hay ngày giả).
- **Trang quản trị** (mục 20 của `02_seed.sql`): tổng quan có 40 khách hàng (39 hoạt động, 1 bị khóa), 12 tour (2 chờ duyệt, 9 đã duyệt, 1 bị từ chối), 39 yêu cầu (3 chờ xác nhận). Yêu cầu theo trạng thái: chờ xác nhận 3 (đơn 31–33), chờ thanh toán 2 (đơn 34, 35 – đơn 35 có chuyển khoản VietQR chờ đối chiếu), đã xác nhận 2 (đơn 36, 37 – lịch của đơn 37 đã khởi hành), đã hoàn thành 29, từ chối 1 (đơn 38), đã hủy 2 (đơn 30, 39). Doanh thu toàn bộ: 32 lượt thanh toán, 39.780.000đ trừ 1.300.000đ hoàn tiền = 38.480.000đ. `admin_logs` có 10 dòng (tour 12 và đơn 34–39); đơn 1–30 chưa có lịch sử. Phê duyệt tour 11 thì trang khách có 10 tour và Huế xuất hiện.
- **UUID không tồn tại:** ví dụ `c0000000-0000-4000-8000-000000009999`, phải trả về 0 dòng ở mọi procedure về tour.

Thứ tự mong đợi của 9 tour ngay sau khi import: `recommended` 3, 1, 6, 2, 7, 4, 8, 5, 9 · `upcoming` 4, 6, 8, 5, 1, 7, 2, 3, 9 · `price_asc` 5, 4, 6, 1, 2, 7, 8, 3, 9 · `price_desc` 3, 8, 7, 2, 1, 6, 4, 5, 9. Căn cứ xem [02 – Lược đồ dữ liệu](../../docs/sprint3/02-luoc-do-du-lieu.md), mục 8.3.

## Câu lệnh thử nhanh

Chạy trong tab **SQL** của `db_localtour` trên phpMyAdmin (có tiếng Việt nên không chạy qua `mysql -e` trên Windows):

```sql
CALL LTP_sp_tour_list(NULL, NULL, NULL, NULL);                                          -- 9 dòng, thứ tự "Nổi bật"
CALL LTP_sp_tour_list(NULL, 'c2000000-0000-4000-8000-000000000001', NULL, 'price_asc'); -- Hà Nội: tour 1, 2, 3
CALL LTP_sp_tour_list(NULL, NULL, 'c3000000-0000-4000-8000-000000000001', NULL);        -- Ẩm thực: tour 1, 2
CALL LTP_sp_destination_list();                                           -- 4 điểm đến, Hà Nội (3) đứng đầu, không có Huế
CALL LTP_sp_category_list();                                              -- 5 loại hình, không có Đạp xe
CALL NMT_sp_tour_detail('c0000000-0000-4000-8000-000000000001');          -- 1 dòng, from_price_vnd = 650000, destination_name = Hà Nội, category_name = Ẩm thực
CALL NMT_sp_tour_detail('c0000000-0000-4000-8000-000000000009');          -- 1 dòng, category_name NULL, 7 cột cuối đều NULL
CALL NMT_sp_tour_schedule_list('c0000000-0000-4000-8000-000000000001');   -- 4 lịch đặt được
CALL NMT_sp_tour_ticket_list('c0000000-0000-4000-8000-000000000001');     -- 8 vé (người lớn + trẻ em của 4 lịch)
CALL NTK_sp_tour_review_list('c0000000-0000-4000-8000-000000000001', 5);  -- 4 đánh giá đã duyệt, reviewer_name = users.name
CALL NTK_sp_tour_cancellation_policy('c0000000-0000-4000-8000-000000000004'); -- version 2
CALL NMT_sp_tour_image_list('c0000000-0000-4000-8000-000000000001');      -- 1 ảnh: img/tours/hanoi-1.svg
CALL NTK_sp_tour_itinerary_list('c0000000-0000-4000-8000-000000000001');  -- 5 mục theo sort_order, mục đầu 17:00
CALL NTK_sp_tour_itinerary_list('c0000000-0000-4000-8000-000000000003');  -- 5 mục, start_time đều NULL
CALL NTK_sp_tour_inclusion_list('c0000000-0000-4000-8000-000000000001');  -- 6 dòng: 3 bao gồm trước, rồi 3 không bao gồm
CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000001');      -- 2 dòng: phụ thu trước, rồi tùy chọn
CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000004');      -- 2 phụ thu: "đón ngoài khu trung tâm", rồi "ngày lễ" (giá NULL)
CALL NTK_sp_user_find_by_email('khong-co@localtour.test');                -- 0 dòng (email chưa đăng ký)
CALL NMT_sp_tour_image_list('c0000000-0000-4000-8000-000000000009');      -- 0 dòng (tour chưa có ảnh)
CALL NMT_sp_tour_detail('c0000000-0000-4000-8000-000000000010');          -- 0 dòng (tour chờ duyệt)
CALL NTK_sp_tour_itinerary_list('c0000000-0000-4000-8000-000000000010');  -- 0 dòng (tour chờ duyệt)
CALL NTK_sp_tour_inclusion_list('c0000000-0000-4000-8000-000000000010');  -- 0 dòng (tour chờ duyệt)
CALL NTK_sp_tour_extra_list('c0000000-0000-4000-8000-000000000010');      -- 0 dòng (tour chờ duyệt)
CALL LTP_sp_admin_tour_list('pending');                                   -- 2 dòng: tour 10, 11
CALL LTP_sp_admin_tour_list(NULL);                                        -- 12 dòng, tour chờ duyệt trước
CALL NMT_sp_admin_summary();                                              -- customer_total 40, tour_pending 2, booking_pending 3
CALL NMT_sp_admin_booking_status_stats();                                 -- 6 dòng: 3, 2, 2, 29, 1, 2
CALL NMT_sp_admin_revenue_stats('year', NULL, NULL);                      -- tổng các dòng: 32 lượt, net_vnd 38480000
CALL NTK_sp_admin_booking_list(NULL, NULL);                               -- 39 dòng, đơn mới nhất trước
CALL NTK_sp_admin_booking_list('pending', NULL);                          -- 3 dòng (đơn 31, 32, 33)
CALL NTK_sp_admin_log_list('tour', 'c0000000-0000-4000-8000-000000000012'); -- 1 dòng: từ chối, có lý do
```

Không thử `NTK_sp_customer_register` bằng câu lệnh tay: procedure cần chuỗi băm do PHP tạo. Thử đăng ký qua trang `/register` của ứng dụng. Phê duyệt tour và cập nhật trạng thái yêu cầu nên thử qua trang `/admin` (cách tạo tài khoản quản trị viên để thử xem [src/README.md](../README.md), bước 7).
