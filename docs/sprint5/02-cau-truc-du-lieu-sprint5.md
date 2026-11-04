# Cấu trúc dữ liệu Sprint 5

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 5 – So sánh tour, đổi/hủy và kiểm thử hệ thống (06/11 – 12/11/2026) |
| WBS | US04-S5-02, US06-S5-01, US14-S5-02, US14-S5-03, US07-S5-01 |
| Người phụ trách | Nguyễn Minh Thức |
| Căn cứ | Lược đồ 29 bảng sau Sprint 4 ([Sprint 4 – 03 Cấu trúc dữ liệu Booking](../sprint4/03-cau-truc-du-lieu-booking.md), mục 7); ERD `docs/diagram/localtour-erd.drawio`; [01 – Yêu cầu và luồng Sprint 5](01-yeu-cau-va-luong-sprint5.md) |
| Script | Migration `src/database/16_migration_sprint5_LTP.sql`; procedure mới `17_procedures_NMT_compare.sql`, `18_procedures_LTP_package.sql`, `19_procedures_LTP_change.sql`, `20_procedures_LTP_change_admin.sql`, `21_procedures_NMT_tour_content.sql` (16, 18, 19, 20 của Lê Trung Phong; 17, 21 của Nguyễn Minh Thức); sửa `01`, `03`, `04`, `07`, `10`, `11`; file gộp `src/database/db_localtour.sql` (01 → 21) |
| Tiêu chí nghiệm thu | Migration 16 chạy không lỗi trên database đã có dữ liệu Sprint 4, không mất dữ liệu, chạy lại được; import mới có 31 bảng / 92 procedure; đơn cũ giữ tên gói và phiên bản chính sách hủy lúc đặt. |
| Trạng thái | **Đã chốt.** |

## 1. Tổng quan

Sprint 5 thêm 2 bảng, 2 cột và 1 giá trị trạng thái tour; không xóa bảng hay cột nào. So sánh tour (US04-S5-02) không thêm bảng, chỉ đọc các bảng đã có.

```text
tours 1 ── n tour_packages 0..1 ── n bookings n ── 1 schedules
                                       │
                                       └── 1 ── n booking_change_requests n ── 0..1 schedules (lịch muốn đổi sang)
                                                      ├── n ── 1 users (khách gửi, user_id)
                                                      └── n ── 0..1 users (quản trị viên xử lý, handled_by)
```

| Thay đổi | Nội dung | Dùng cho |
| --- | --- | --- |
| Bảng `tour_packages` | Gói của tour (theo phương tiện hoặc tuyến điểm), giá người lớn / trẻ em riêng, ngừng bán thay vì xóa. | US06-S5-01 |
| Bảng `booking_change_requests` | Yêu cầu đổi ngày / hủy tour của khách, chính sách chụp lúc gửi và kết quả xử lý. | US14-S5-02, US14-S5-03 |
| `bookings.package_id`, `package_name` | Gói khách chọn khi đặt, tên gói chụp lại. | US06-S5-01 |
| `tours.approval_status` thêm `'archived'` | Ngừng hiển thị tour đã có đơn. | US07-S5-01 |
| Số lượng | 29 → 31 bảng; 66 → 92 procedure (thêm 26: file 17 có 1, 18 có 3, 19 có 4, 20 có 3, 21 có 15). | — |

## 2. Migration 16

`16_migration_sprint5_LTP.sql` chạy sau 01 → 15.

| # | Thay đổi | Lý do |
| --- | --- | --- |
| 1 | Bảng `tour_packages`: `id`, `tour_id`, `name VARCHAR(100)`, `description VARCHAR(500) NULL`, `adult_price_vnd`, `child_price_vnd NULL`, `active` (mặc định `TRUE`), `sort_order`, `created_at`, `updated_at`; `UNIQUE (tour_id, name)`, chỉ mục `(tour_id, active, sort_order)`, khóa ngoại `tour_id` → `tours`. | `child_price_vnd` NULL = gói không bán vé trẻ em. Gói không xóa, chỉ ngừng bán (`active = FALSE`) để đơn cũ vẫn trỏ được tới gói. |
| 2 | `bookings.package_id CHAR(36) NULL` (sau `schedule_id`), `bookings.package_name VARCHAR(100) NULL`; chỉ mục `idx_bookings_package`, khóa ngoại `fk_bookings_package` → `tour_packages`. | NULL = tour không có gói; mọi đơn tạo trước Sprint 5 để NULL. Tên gói chụp lúc đặt, đổi tên gói sau không đổi đơn cũ. |
| 3 | Bảng `booking_change_requests` (bảng dưới). | Lưu yêu cầu đổi ngày / hủy và kết quả xử lý thủ công của quản trị viên. |
| 4 | `tours.approval_status ENUM('draft','pending','approved','rejected','archived')`. | Tour đã có đơn không xóa hẳn được thì ngừng hiển thị, đơn cũ giữ nguyên. |
| 5 | 3 gói mẫu của tour 3 (mục 9). | Thử chọn gói khi đặt tour. |

| Nhóm cột của `booking_change_requests` | Cột | Ý nghĩa |
| --- | --- | --- |
| Yêu cầu | `booking_id`, `user_id`, `type` (`cancel` / `change_date`), `requested_schedule_id` (lịch mới, chỉ với `change_date`), `reason VARCHAR(500)`, `created_at` | Khách gửi; lý do bắt buộc. |
| Trạng thái | `status` `pending` → `approved` / `rejected`; `booking_status` (trạng thái đơn lúc gửi) | Mỗi đơn chỉ một yêu cầu `pending` tại một thời điểm (procedure kiểm tra khi đã khóa dòng đơn). |
| Chụp chính sách | `policy_version`, `free_before_hours`, `refund_percent`, `in_free_window`, `paid_vnd`, `estimated_refund_vnd` | Chính sách theo phiên bản đã lưu cùng đơn, tiền đã trả và số tiền dự kiến hoàn lúc gửi. |
| Kết quả | `refund_vnd` (số quản trị viên chốt khi đồng ý hủy), `result_note VARCHAR(500)`, `handled_by` → `users`, `handled_at` | Ghi khi quản trị viên đồng ý / từ chối. |

Khóa ngoại `booking_id` → `bookings`, `user_id` và `handled_by` → `users`, `requested_schedule_id` → `schedules`, đều `ON DELETE RESTRICT`. Chỉ mục `(booking_id, created_at)`, `(status, created_at)`, `user_id`, `requested_schedule_id`, `handled_by`.

- Không xóa bảng, không xóa hay sửa dữ liệu đang có.
- Chạy lại được: bảng tạo bằng `CREATE TABLE IF NOT EXISTS`; `ALTER TABLE bookings` nằm trong procedure tạm `LTP_sp_migrate_sprint5`, bỏ qua lỗi “đã có” (1060 cột trùng, 1061 khóa trùng), khóa ngoại được kiểm tra trong `information_schema` trước khi thêm; procedure tạm bị xóa ngay sau khi chạy. `MODIFY` của `tours.approval_status` giữ nguyên giá trị đang có. Gói mẫu chỉ chèn khi tour 3 có và mã gói chưa có.
- ERD `docs/diagram/localtour-erd.drawio` hiện vẽ lược đồ 29 bảng của Sprint 4; 2 bảng và 2 cột ở trên chưa có trên ERD.

## 3. Gói tour: giá lưu ở gói

[Sprint 4 – 01 Rà soát kết quả M3 và tồn đọng](../sprint4/01-ra-soat-m3-va-ton-dong.md), mục 3, dòng “4. Gói lựa chọn (FR-07)”, dự kiến thêm bảng `tour_packages` và cột `ticket_types.package_id`. Khi làm, nhóm giữ bảng `tour_packages` nhưng **không thêm** `ticket_types.package_id`: giá người lớn / trẻ em lưu ngay trên dòng gói.

Lý do: giá của gói áp dụng cho mọi lịch của tour. Nếu gắn gói vào `ticket_types`, mỗi lịch phải có một bộ vé cho từng gói, số dòng phải nhập là số gói × số lịch × số loại vé (tour 3: 3 gói × 3 lịch × 1 loại vé = 9 dòng `ticket_types` thay vì 3 dòng `tour_packages`), và mỗi lần thêm lịch hay đổi giá gói phải sửa nhiều dòng.

Cách `LTP_sp_booking_create` (file 10) dùng gói:

- Tour có ít nhất một gói `active` thì phải gửi đúng một gói đang bán của tour; tour không có gói thì không được gửi gói. Sai một trong hai → `package_changed`, không ghi gì.
- Dòng vé (`booking_lines.ticket_type_id`) vẫn trỏ vào loại vé `adult` / `child` của lịch; loại vé phải còn `active` ở lịch đó (không thì `tickets_changed`).
- `unit_price_vnd` lấy từ gói: vé `child` dùng `child_price_vnd`, vé khác dùng `adult_price_vnd`. Gói không có giá trẻ em mà khách chọn vé trẻ em → `package_changed`. `ticket_types.price_vnd` của lịch chỉ dùng cho tour không có gói (như Sprint 4).
- `package_id`, `package_name` (ở `bookings`) và `unit_price_vnd` (ở `booking_lines`) chụp lúc đặt; sửa tên, giá hay ngừng bán gói sau đó không đổi đơn cũ. Dòng `booking_events` `created` ghi thêm tên gói.

## 4. Đổi ngày / hủy tour

| Bước | Procedure | Dữ liệu ghi |
| --- | --- | --- |
| Khách xem chính sách, số dự kiến hoàn, lịch đổi được | `LTP_sp_change_quote`, `LTP_sp_change_schedule_options` | Không ghi. |
| Khách gửi yêu cầu | `LTP_sp_change_request_create` | 1 dòng `booking_change_requests` `pending` (chụp chính sách, tiền đã trả, số dự kiến hoàn); 1 dòng `booking_events` (`actor = 'customer'`, `cancel_requested` / `change_requested`). Đơn chưa đổi. |
| Quản trị viên từ chối | `LTP_sp_admin_change_request_decide` (`'rejected'`) | Yêu cầu `rejected` kèm `result_note`, `handled_by`, `handled_at`; `admin_logs` `cancel_rejected` / `change_rejected`. Đơn giữ nguyên. |
| Quản trị viên đồng ý hủy | `LTP_sp_admin_change_request_decide` (`'approved'`) | Đơn `cancelled`, `hold_expires_at = NULL`; đơn `awaiting_payment` / `confirmed` được trả chỗ (không vượt `capacity`, lịch `full` mở lại `open`); khoản `pending` / `processing` → `failed`; yêu cầu `approved` kèm `refund_vnd`; `admin_logs` `cancel_approved`. `refund_vnd` > 0 thì thêm 1 dòng `refunds` `requested` và `admin_logs` `refund_requested`. |
| Quản trị viên đồng ý đổi ngày | `LTP_sp_admin_change_request_decide` (`'approved'`) | `bookings.schedule_id` = lịch mới; mỗi dòng vé chuyển sang loại vé đang bán cùng tên của lịch mới, `unit_price_vnd` và `total_vnd` giữ nguyên; đơn đang giữ chỗ thì trả chỗ lịch cũ, trừ chỗ lịch mới (về 0 thì `full`); yêu cầu `approved`; `admin_logs` `change_approved`. |

- Gửi được khi đơn của chính tài khoản đang `pending` / `awaiting_payment` / `confirmed`, chưa tới giờ khởi hành và chưa có yêu cầu `pending` (dòng đơn khóa `FOR UPDATE`). Lịch mới: cùng tour, `open`, chưa khởi hành, khác lịch hiện tại, `remaining` ≥ số khách của đơn.
- Số dự kiến hoàn (chỉ với `cancel`) = `FLOOR(paid_vnd × phần trăm / 100)`: trước mốc `starts_at − free_before_hours` là 100%, sau mốc là `refund_percent`; `free_before_hours` NULL thì luôn `refund_percent`. `paid_vnd` = tổng khoản `payments` `paid` của đơn; đơn chưa thanh toán hoặc không có chính sách (phiên bản 0) → 0đ.
- Đồng ý hủy: `p_refund_vnd` NULL thì lấy số dự kiến hoàn (không vượt tiền đã trả hiện tại); số nhập tay phải từ 0 tới tiền đã trả. Còn khoản `awaiting_reconciliation` → `payment_in_review`, không đổi gì.
- Đồng ý đổi ngày: lịch mới đã đóng / đã khởi hành → `schedule_unavailable`, không đủ chỗ → `no_seats`, thiếu loại vé đang bán cùng tên → `tickets_missing`. Mỗi yêu cầu xử lý một lần (`already_handled`); đơn đã kết thúc → `booking_closed`.
- `refunds` nối với `payments` qua `payment_id` (bảng không có `booking_id`): dòng hoàn trỏ vào khoản `paid` lớn nhất của đơn. Chưa tự động hoàn tiền; quản trị viên hoàn tay.
- Lịch sử đơn của khách và của quản trị viên (`LTP_sp_customer_booking_history`, `LTP_sp_booking_history`, file 15) gộp `booking_events` và `admin_logs`, nên hiện cả các hành động trên.

## 5. So sánh tour (`NMT_sp_tour_compare`)

`p_tour_ids` là các mã tour cách nhau bởi dấu phẩy (tối đa 200 ký tự, khoảng trắng bị bỏ), theo thứ tự khách chọn. Chỉ trả tour công khai (tour và nhà cung cấp `approved`, tài khoản nhà cung cấp `active`); tour không có hoặc đang ẩn bị bỏ qua. Mỗi tour một dòng theo thứ tự gửi, tối đa 3 dòng; ứng dụng chặn 2 – 3 tour trước khi gọi.

| Nhóm | Cột | Cách tính |
| --- | --- | --- |
| Đầu cột | `tour_id`, `title`, `provider_name`, `destination_name`, `category_name`, `cover_image_url`, `cover_alt_text` | Ảnh bìa = ảnh có `sort_order` nhỏ nhất. |
| Thông tin tour | `duration_minutes`, `max_group_size`, `language_codes`, `pickup_mode`, `meeting_point`, `dropoff_point`, `transport`, `guide_info`, `meal_terms`, `reschedule_terms` | Lấy từ `tours`; thời lượng theo phút, quy mô theo số khách. |
| Giá và lịch | `from_price_vnd`, `child_from_price_vnd`, `package_count`, `package_names`, `next_starts_at`, `schedule_count` | Giá / người: tour có gói đang bán thì giá thấp nhất của các gói (giá trẻ em chỉ khi lịch có vé trẻ em), không thì vé `active` thấp nhất của các lịch đặt được. Không có lịch đặt được → giá NULL. |
| Chính sách, đánh giá | `policy_version`, `free_before_hours`, `refund_percent`, `rating_avg`, `review_count` | Phiên bản chính sách mới nhất; chỉ đánh giá `approved`. |
| Danh sách | `included_items`, `excluded_items`, `itinerary_items`, `extras_items` | `GROUP_CONCAT` theo `sort_order`, ngăn bởi xuống dòng. |

- Ô thiếu dữ liệu trả NULL, procedure không tự điền. `CompareModel` đổi NULL / chuỗi rỗng thành “Chưa cập nhật”; một số ô có câu riêng: không có lịch → “Chưa có lịch mở bán”, chưa có đánh giá → “Chưa có đánh giá”, có giá người lớn nhưng không có giá trẻ em → “Không bán vé trẻ em”, không có phụ thu → “Không có”, tour không chia gói → “Một gói chung”.
- Tour khách chọn lưu ở `localStorage` của trình duyệt (`src/public/assets/js/compare.js`), không ghi database. Bảng `comparisons`, `comparison_tours` (có từ Sprint 3) vẫn để trống, không procedure nào thêm dòng.

## 6. Nội dung tour, xóa tour, xóa đơn vị tổ chức (file 21)

Mọi procedure ghi kiểm tra người thao tác là quản trị viên đang hoạt động (`forbidden`), chỉ sửa mục thuộc đúng tour (mã của tour khác → `not_found`) và ghi một dòng `admin_logs` (`target_type = 'tour'`; xóa đơn vị tổ chức là `'provider'`).

| Phần | Bảng | Giới hạn và quy tắc | `action` |
| --- | --- | --- | --- |
| Ảnh | `tour_images` | Tối đa 12 ảnh / tour (`limit`); `url`, `alt_text` tối đa 255 ký tự. Ảnh bìa = `sort_order` nhỏ nhất; chọn ảnh bìa đặt `sort_order` = nhỏ nhất − 1. Xóa ảnh trả `url` để ứng dụng xóa file. | `image_add`, `image_delete`, `image_cover` |
| Lịch trình | `tour_itinerary_items` | Tối đa 30 mục; mô tả 1 – 255 ký tự; `start_time` NULL = không ghi giờ; thứ tự 0 – 999. | `itinerary_add`, `itinerary_update`, `itinerary_delete` |
| Dịch vụ | `tour_inclusions` | Tối đa 40 mục; nội dung 1 – 150 ký tự; bao gồm / không bao gồm. | `inclusion_add`, `inclusion_delete` |
| Chính sách hủy | `cancellation_policies` | Không sửa phiên bản cũ: lưu = thêm phiên bản `version + 1`; giống hệt phiên bản mới nhất → `unchanged`. `free_before_hours` NULL hoặc 0 – 720, `refund_percent` 0 – 100, điều khoản 1 – 2000 ký tự. Đơn đã đặt giữ `policy_version` lúc đặt. | `policy_add` |

File ảnh: ứng dụng nhận JPG / PNG / WebP tối đa 2 MB (hoặc đường dẫn `https://`), lưu ở `src/public/assets/uploads/tours/` với tên ngẫu nhiên; database chỉ lưu đường dẫn `uploads/tours/<tên file>`. Thư mục `uploads` có trong `.gitignore` (chỉ giữ `.gitkeep`), nên ảnh tải lên chỉ có trên máy chạy web.

Xóa tour (`NMT_sp_admin_tour_delete`) khóa dòng tour và các lịch của tour rồi đếm đơn:

| Tình trạng | `result` | Kết quả |
| --- | --- | --- |
| Còn đơn `pending` / `awaiting_payment` / `confirmed` | `has_bookings` (kèm `active_bookings`) | Không đổi gì. |
| Đã có đơn, các đơn đều đã kết thúc | `archived` | `approval_status = 'archived'`: ẩn khỏi trang khách (chỉ tour `approved` mới công khai); đơn và dữ liệu tour giữ nguyên; `tour_archive`. |
| Chưa có đơn nào | `deleted` | Xóa hẳn tour cùng vé, lịch, ảnh, lịch trình, dịch vụ, phụ thu, chính sách hủy, gói, bài viết, yêu thích, `comparison_tours`; `admin_logs` `tour_delete` giữ lại tên tour. |
| Đã `archived` | `already_archived` | Không đổi gì. |

- Khôi phục (`NMT_sp_admin_tour_restore`): chỉ tour `archived` → `pending` (`tour_restore`), phải duyệt lại ở trang Duyệt tour mới hiển thị; trạng thái khác → `invalid_transition`.
- Xóa đơn vị tổ chức (`NMT_sp_admin_provider_delete`): chỉ khi đơn vị chưa có tour nào, kể cả tour chờ duyệt / ngừng hiển thị (còn tour → `has_tours`, kèm `tour_count`). Xóa dòng `providers` và tài khoản `provider` đi kèm; tài khoản còn được bảng khác tham chiếu thì giữ lại với `status = 'locked'`; ghi `provider_delete`. Muốn ẩn tour của đơn vị còn tour thì chuyển “Ngừng hợp tác” (`rejected`).

## 7. Procedure mới và thay đổi

| File | Procedure | Đọc / ghi | Ghi chú |
| --- | --- | --- | --- |
| 17 | `NMT_sp_tour_compare(p_tour_ids)` | Đọc | Mục 5. |
| 18 | `LTP_sp_tour_package_list(p_tour_id)` | Đọc | Gói đang bán của tour công khai, theo `sort_order`, giá người lớn, tên. |
| 18 | `LTP_sp_admin_package_list(p_tour_id)` | Đọc | Mọi gói (cả gói ngừng bán), kèm `booking_count`, `active_booking_count`. |
| 18 | `LTP_sp_admin_package_save(p_actor_user_id, p_tour_id, p_package_id, p_name, p_description, p_adult_price_vnd, p_child_price_vnd, p_active, p_sort_order)` | Ghi | `p_package_id` NULL = thêm gói. Giá 1 – 100.000.000đ; trùng tên trong tour → `duplicate`; `admin_logs` `package_create` / `package_update`. |
| 19 | `LTP_sp_change_quote`, `LTP_sp_change_schedule_options`, `LTP_sp_change_request_list` (cùng tham số `p_user_id, p_code`) | Đọc | Chỉ đơn của tài khoản; mã của tài khoản khác → 0 dòng. |
| 19 | `LTP_sp_change_request_create(p_user_id, p_code, p_type, p_schedule_id, p_reason)` | Ghi | `result`: `ok`, `forbidden`, `not_found`, `invalid`, `not_allowed`, `departed`, `pending_exists`, `schedule_unavailable`, `no_seats`. |
| 20 | `LTP_sp_admin_change_request_list(p_status, p_booking_id)`, `LTP_sp_admin_change_request_detail(p_request_id)` | Đọc | Chờ xử lý trước; danh sách tối đa 200 dòng. |
| 20 | `LTP_sp_admin_change_request_decide(p_actor_user_id, p_request_id, p_decision, p_note, p_refund_vnd)` | Ghi | Mục 4; kết quả xử lý bắt buộc, tối đa 500 ký tự. |
| 21 | `NMT_sp_admin_image_…` (4), `NMT_sp_admin_itinerary_…` (3), `NMT_sp_admin_inclusion_…` (3), `NMT_sp_admin_policy_…` (2), `NMT_sp_admin_tour_delete`, `NMT_sp_admin_tour_restore`, `NMT_sp_admin_provider_delete` | Đọc / ghi | Mục 6. |

Sprint 5 sửa 6 file cũ (không thêm procedure):

| File | Procedure | Thay đổi |
| --- | --- | --- |
| 01 | — | Xóa luôn 4 bảng do migration `12`, `16` tạo, để import lại không còn dữ liệu thử cũ (mục 8). |
| 03 | `LTP_sp_tour_list` | Giá “Từ” của tour có gói đang bán = giá người lớn thấp nhất của các gói; vẫn cần lịch đặt được có vé `adult`. |
| 03 | `LTP_sp_admin_tour_list(p_approval_status)` | Nhận thêm giá trị lọc `'archived'`. |
| 04 | `NMT_sp_admin_summary` | Thêm cột `tour_archived`. |
| 07, 11 | `NTK_sp_admin_booking_detail`, `NTK_sp_customer_booking_detail` | Thêm cột `package_name`. |
| 10 | `LTP_sp_booking_create` | Thêm tham số thứ 11 `p_package_id` và `result` `package_changed` (mục 3). |

Danh sách đầy đủ 92 procedure, tham số và câu `CALL` mẫu xem `src/database/README.md`.

## 8. Cách cập nhật database dùng chung

Database `db_localtour` dùng chung do Phong host trên MySQL của máy Phong (`src/README.md`, bước 2, Cách A). Cập nhật trên máy host bằng tài khoản quản trị đã dùng để import (procedure không có `DEFINER` nên nhận tài khoản đó làm definer); tài khoản ứng dụng chỉ có quyền `EXECUTE`. Cập nhật database cùng lúc với code Sprint 5: code mới gọi `LTP_sp_booking_create` với 11 tham số, procedure cũ chỉ nhận 10.

| Cách | Làm | Dữ liệu |
| --- | --- | --- |
| A. Import lại | Import `src/database/db_localtour.sql` (phpMyAdmin hoặc `mysql`, xem `src/database/README.md`). | Cả 31 bảng được xóa, tạo lại và nạp dữ liệu mẫu (Sprint 5 thêm vào `01` lệnh xóa 4 bảng do migration `12` và `16` tạo: `booking_extras`, `booking_events`, `tour_packages`, `booking_change_requests`): mất tài khoản đăng ký thử và đơn đã đặt thử; ngày lịch tính lại theo ngày import. |
| B. Giữ dữ liệu | Chạy lần lượt `16` → `17` → `18` → `19` → `20` → `21`, rồi chạy lại `03`, `04`, `07`, `10`, `11`. | Giữ nguyên dữ liệu đang có; thêm 2 bảng, 2 cột, giá trị `'archived'` và 3 gói mẫu của tour 3. Các file procedure chỉ có `DROP PROCEDURE IF EXISTS` / `CREATE PROCEDURE`, không sửa dữ liệu. |

Sau cả hai cách: 31 bảng, 92 procedure (hai câu `SELECT` ở `src/database/README.md`, Cách 1, bước 5); `CALL LTP_sp_tour_package_list('c0000000-0000-4000-8000-000000000003')` trả 3 gói.

## 9. Dữ liệu kiểm thử

Ngày giờ lịch tính theo ngày import (`CURDATE()`), nên import lại thì ngày đổi theo.

| Dữ liệu | Nội dung | Dùng để thử |
| --- | --- | --- |
| Tour 3 “Phố cổ theo cách của bạn” | 3 gói `f5000000-0000-4000-8000-000000000001` – `…003`: “Kiến trúc và phố nghề” 900.000đ, “Đền chùa và tín ngưỡng” 950.000đ, “Góc ảnh phố cổ” 1.200.000đ; không gói nào có giá trẻ em (tour 3 chỉ bán vé người lớn). Lịch 11, 12 (ngày import + 6 ngày, 14:00 và 08:30) và 13 (+ 13 ngày); chính sách hủy miễn phí trước 48 giờ, sau mốc hoàn 50%. | Bắt buộc chọn gói; giá “Từ” vẫn 900.000đ; đổi ngày giữa các lịch; hủy trước / sau mốc 48 giờ. |
| Tour 1 | Không có gói; 4 lịch đặt được, mỗi lịch có vé người lớn và trẻ em; hủy miễn phí trước 24 giờ, sau mốc hoàn 0%. | Đặt như Sprint 4 (`LTP_sp_tour_package_list` → 0 dòng); đổi ngày có vé trẻ em. |
| `booking_change_requests` | 0 dòng sau import mới. | — |

- Đơn mẫu thuộc tài khoản không đăng nhập được (`password_hash = NULL`), nên thử đổi ngày / hủy bằng tài khoản tự đăng ký ở `/register` và đơn mới đặt. Không ghi email, mật khẩu thử vào tài liệu hay commit.
- Muốn số dự kiến hoàn lớn hơn 0: đặt đơn, quản trị viên xác nhận chỗ, thanh toán, rồi gửi yêu cầu hủy.
- So sánh: `CALL NMT_sp_tour_compare('c0000000-0000-4000-8000-000000000001,c0000000-0000-4000-8000-000000000003')` → 2 dòng, tour 1 rồi tour 3; thay tour 3 bằng tour 10 (chờ duyệt) → 1 dòng. Tour 9 thiếu ảnh, lịch, lịch trình, dịch vụ, đánh giá, dùng để thử “Chưa cập nhật”.
- Xóa tour: tour mới thêm chưa có đơn → `deleted`; tour có đơn đều đã kết thúc → `archived`. Xóa đơn vị tổ chức: đơn vị mới thêm chưa có tour → `deleted`; cả 7 đơn vị mẫu đều có tour → `has_tours`.
