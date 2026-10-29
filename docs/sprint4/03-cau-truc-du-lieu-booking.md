# Cấu trúc dữ liệu Booking

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 4 – M4 Nghiệm thu bản tích hợp và Booking MVP |
| WBS | M4 mục 3 – Thiết kế cấu trúc dữ liệu Booking |
| Người phụ trách | Nguyễn Minh Thức |
| Căn cứ | Lược đồ 27 bảng của Sprint 3 ([02 – Lược đồ dữ liệu](../sprint3/02-luoc-do-du-lieu.md), mục 4.4, 4.5); ERD `docs/diagram/localtour-erd.drawio`; [02 – Yêu cầu và luồng đặt tour](02-yeu-cau-va-luong-dat-tour.md) |
| Script | `src/database/08_migration_booking_NMT.sql` (migration và dữ liệu kiểm thử); procedure: `09_procedures_NMT_booking.sql`, `10_procedures_LTP_booking.sql`, `11_procedures_NTK_booking.sql`, giữ chỗ trong `07_procedures_NTK_admin.sql`; file gộp `src/database/db_localtour.sql` (01 → 11) |
| Tiêu chí nghiệm thu | Migration chạy không lỗi trên database đã có dữ liệu Sprint 3, chạy lại được; Booking liên kết đúng User / Tour / Schedule; có dữ liệu để thử đặt được, không đủ chỗ và giá đổi. |
| Trạng thái | **Đã chốt.** |
| Cập nhật 29/10 | Theo kế hoạch Sprint 4 chính thức (30/10 – 05/11): thanh toán, tự hủy đơn quá hạn, phụ thu / tùy chọn, voucher và CRUD nền tảng (đơn vị tổ chức, tour, lịch) chuyển từ M5 / backlog vào Sprint 4. Các mục thay đổi ghi “Sprint 4” kèm mã WBS của kế hoạch. |

## 1. Tổng quan

M4 dùng lại các bảng đặt chỗ đã có trong lược đồ Sprint 3, không thêm bảng mới (vẫn 27 bảng). Migration 08 chỉ thêm hai cột và hai khóa duy nhất. Sprint 4 thêm migration 12 với 2 bảng (tổng 29 bảng), xem mục 7.

```text
users (customer) 1 ── n bookings n ── 1 schedules n ── 1 tours 1 ── n cancellation_policies
                          │                 │
                          │                 └── 1 ── n ticket_types
                          ├── 1 ── n booking_lines n ── 1 ticket_types
                          └── 1 ── n passengers
```

| Bảng | Vai trò trong đặt tour |
| --- | --- |
| `users` | Tài khoản đặt đơn. Chỉ `role = 'customer'`, `status = 'active'` tạo được đơn. |
| `tours` | Tour được đặt. `max_group_size` giới hạn số khách một đơn; tour phải đang hiển thị công khai. |
| `schedules` | Lịch khởi hành. `remaining` là số chỗ còn lại, `capacity` là sức chứa; chỉ lịch `open`, chưa khởi hành mới đặt được. |
| `ticket_types` | Loại vé và giá theo lịch (`adult`, `child`…). Chỉ vé `active` được chọn. |
| `cancellation_policies` | Chính sách hủy của tour theo phiên bản; đơn lưu phiên bản lúc đặt. |
| `bookings` | Đơn đặt tour: mã đơn, người liên hệ, trạng thái, tổng tiền, phiên bản chính sách, hạn giữ chỗ. |
| `booking_lines` | Mỗi loại vé trong đơn một dòng: số lượng, giá chụp lúc đặt, thành tiền. |
| `passengers` | Mỗi khách một dòng: họ tên, nhóm tuổi theo loại vé, yêu cầu đặc biệt. |
| `admin_logs` | Nhật ký mỗi lần quản trị viên đổi trạng thái đơn (đã có từ Sprint 3). |

`bookings` không lưu `tour_id`: tour lấy qua `schedules.tour_id`, tránh hai cột có thể lệch nhau.

## 2. Migration 08

| # | Thay đổi | Lý do |
| --- | --- | --- |
| 1 | `bookings.request_token VARCHAR(64) NULL`, sau cột `code` | Mã của một lần mở trang đặt tour (32 ký tự hex). Đơn tạo trước M4 để `NULL`. |
| 2 | `UNIQUE KEY uq_bookings_user_request (user_id, request_token)` | Cùng tài khoản gửi lại cùng mã chỉ tạo một đơn, kể cả khi hai yêu cầu tới cùng lúc. `NULL` không vi phạm khóa nên đơn cũ không ảnh hưởng. |
| 3 | `UNIQUE KEY uq_booking_lines_ticket (booking_id, ticket_type_id)` | Mỗi loại vé chỉ một dòng trong một đơn; tổng `quantity` của đơn luôn bằng số khách. |
| 4 | `passengers.sort_order INT NOT NULL DEFAULT 0`, sau cột `special_request` | Thứ tự khách trên form (1, 2, …), để trang đơn và trang quản trị hiện đúng thứ tự đã nhập. Khách của đơn cũ là 0, sắp tiếp theo `id`. |
| 5 | Lịch kiểm thử 40 và vé 401, 402 (mục 5) | Thử “không đủ chỗ” và “đặt vừa đủ chỗ”. |

- ERD `docs/diagram/localtour-erd.drawio`, trang “03 Booking & Payments”, đã thêm hai cột và hai khóa này.
- Không xóa bảng, không xóa hay sửa dữ liệu đang có.
- Chạy lại được: `ALTER TABLE` nằm trong procedure tạm `NMT_sp_migrate_booking_m4`, bỏ qua lỗi “đã có” (1060 cột trùng, 1061 khóa trùng); dữ liệu kiểm thử chỉ chèn khi chưa có. Procedure tạm bị xóa ngay sau khi chạy.
- File 07, 10 và 11 dùng cột của 08 (`request_token`, `sort_order`), nên luôn import đủ 01 → 11 theo thứ tự.

## 3. Quy tắc giữ chỗ

Theo User Flow và BPMN đặt tour: yêu cầu mới chưa giữ chỗ, quản trị viên xác nhận mới giữ.

| Thời điểm | Procedure | Thay đổi `schedules` |
| --- | --- | --- |
| Khách gửi yêu cầu (đơn `pending`) | `LTP_sp_booking_create` | Không đổi. Khóa dòng lịch (`FOR UPDATE`) và kiểm tra `remaining` ≥ số khách. |
| Quản trị viên xác nhận chỗ (`pending` → `awaiting_payment`) | `NTK_sp_admin_booking_set_status` | `remaining` trừ số khách của đơn; về 0 thì `status` `open` → `full`. Lịch không còn `open` / `full` hoặc đã khởi hành → `schedule_closed`; không đủ chỗ → `no_seats`; cả hai không đổi gì. |
| Quản trị viên hủy đơn đang giữ chỗ (`awaiting_payment` / `confirmed` → `cancelled`) | `NTK_sp_admin_booking_set_status` | `remaining` cộng lại số khách, không vượt `capacity`; lịch `full` mở lại `open`. |
| Từ chối / hủy đơn `pending`, hoàn thành đơn | `NTK_sp_admin_booking_set_status` | Không đổi. |
| Quá hạn giữ chỗ 24 giờ mà chưa thanh toán (Sprint 4) | `LTP_sp_booking_expire_holds` | Đơn → `cancelled`, `remaining` cộng lại như khi hủy; khoản `pending` → `failed`. Bỏ qua đơn có khoản VietQR chờ đối chiếu. |

Số khách của đơn = tổng `booking_lines.quantity`. Mục này thay câu “Procedure không đổi `schedules.remaining` (giữ chỗ thuộc luồng đặt tour)” ở [Sprint 3 – 02](../sprint3/02-luoc-do-du-lieu.md), mục 7.3, và ý nghĩa cột `remaining` ở mục 4.4 (“Sprint 3 chỉ có trong dữ liệu mẫu; Sprint sau giảm khi có đơn đặt”): từ M4, `remaining` giảm khi quản trị viên xác nhận chỗ.

## 4. Ghi một đơn (`LTP_sp_booking_create`)

Một transaction, hoặc ghi đủ, hoặc không ghi gì.

| Bảng | Giá trị ghi |
| --- | --- |
| `bookings` | `id` = `UUID()`; `user_id` từ phiên; `code` = `LT` + 6 chữ số ngẫu nhiên chưa dùng; `request_token`; `contact_name`, `contact_phone` đã bỏ khoảng trắng đầu cuối, `contact_email` chữ thường; `status` = `pending`; `total_vnd` = tổng tiền vé tính ở database; `policy_version` = phiên bản lớn nhất của tour (0 = tour chưa có chính sách); `hold_expires_at` = `NULL`; `created_at` = `NOW()`. |
| `booking_lines` | Mỗi loại vé một dòng: `quantity` = số khách chọn vé đó, `unit_price_vnd` = `ticket_types.price_vnd` lúc đặt, `line_total_vnd = quantity × unit_price_vnd`. |
| `passengers` | Mỗi khách một dòng, `sort_order` = thứ tự trên form (1, 2, …); `age_group` theo tên loại vé (`child` → `child`, `infant` → `infant`, còn lại `adult`); `special_request` lưu ở khách đầu tiên, các khách khác `NULL`. |

Thứ tự kiểm tra và `result` khi không tạo đơn: `forbidden` (không phải khách hàng đang hoạt động) → `invalid` (thiếu thông tin, danh sách khách sai) → `duplicate` (mã yêu cầu đã tạo đơn) → `schedule_unavailable` → `group_limit` → `no_seats` → `tickets_changed` → `price_changed`. `retry` khi trùng mã đơn lúc ghi (rất hiếm). Thông báo cho khách xem [02 – Yêu cầu và luồng đặt tour](02-yeu-cau-va-luong-dat-tour.md), mục 6.

## 5. Dữ liệu kiểm thử

Ngày giờ lịch tính theo ngày import (`NOW()`), nên import lại thì ngày đổi theo.

| Dữ liệu | Nội dung | Dùng để thử |
| --- | --- | --- |
| Lịch 40 (`d0000000-…-000000000040`, migration 08) | Tour 6 (Hội An), 5 ngày sau lúc 16:30, sức chứa 10, còn 1 chỗ; vé 401 người lớn (từ 12 tuổi) 590.000đ, vé 402 trẻ em (4–11 tuổi) 410.000đ | Đặt 2 khách → “Lịch này chỉ còn 1 chỗ”; đặt 1 khách → tạo đơn. |
| Lịch 3 (`…-000000000003`, dữ liệu mẫu) | Tour 1, còn 6 chỗ; người lớn 650.000đ, trẻ em 460.000đ | Đặt thành công nhiều khách, nhiều loại vé. |
| Lịch 7 (`…-000000000007`, dữ liệu mẫu) | Còn 0 chỗ | Kiểm tra chỗ trống trả `bookable: false`. |
| Đơn LT518204 (lịch 3, 2 khách, `pending`) | Lịch còn 6 chỗ | Quản trị viên xác nhận chỗ thành công, lịch 3 còn 4. Hủy đơn đó thì lịch 3 về 6. |
| Đơn LT527716 (lịch 18, 3 khách, `pending`) | Lịch 18 còn 2 chỗ | Xác nhận chỗ → `no_seats`, không đổi gì. |
| Đơn LT533940 (lịch 22, 1 khách, `pending`) | Lịch 22 còn 4 chỗ | Xác nhận chỗ thành công. |

Số `remaining` trong dữ liệu mẫu là số minh họa, không tính lại từ các đơn có sẵn: lịch 3, 18, 22 đã trừ sẵn chỗ của ba đơn chờ xác nhận ở bảng trên, nên xác nhận các đơn này sẽ trừ thêm lần nữa (số chỗ ở bảng trên đã tính điều đó). Kiểm thử giữ chỗ dùng đúng các đơn ở bảng trên hoặc đơn mới đặt qua trang `/tours/{id}/book`, không suy ra số chỗ từ tổng số khách của các đơn mẫu.

Thử “giá đổi”: mở trang đặt tour, sửa `ticket_types.price_vnd` của vé đang chọn trên database kiểm thử, rồi bấm “Xem lại & xác nhận” hoặc “Gửi yêu cầu đặt tour”. Thử xong trả giá về như cũ.

## 6. Procedure mới và thay đổi

| File | Procedure | Đọc / ghi | Mục đích |
| --- | --- | --- | --- |
| 09 | `NMT_sp_schedule_availability(p_schedule_id)` | Đọc | 0–1 dòng: lịch, tour, `capacity`, `remaining`, `status`, `max_group_size`, số loại vé đang bán, `bookable`. Lịch của tour không công khai → 0 dòng. |
| 09 | `NMT_sp_schedule_ticket_list(p_schedule_id)` | Đọc | Loại vé đang bán của lịch, vé đắt trước. |
| 10 | `LTP_sp_booking_create(p_user_id, p_schedule_id, p_request_token, p_contact_name, p_contact_email, p_contact_phone, p_passengers, p_special_request, p_expected_total)` | Ghi | Tạo đơn `pending` (mục 4). `p_passengers` là mảng JSON `[{"ticket_type_id", "full_name"}]`. |
| 11 | `NTK_sp_customer_booking_list(p_user_id)` | Đọc | Tối đa 100 đơn của tài khoản, mới đặt trước. |
| 11 | `NTK_sp_customer_booking_detail(p_user_id, p_code)` | Đọc | Một đơn của tài khoản theo mã: trạng thái, tour, lịch, người liên hệ, chính sách hủy đúng phiên bản lúc đặt, lý do từ chối / hủy mới nhất. |
| 11 | `NTK_sp_customer_booking_line_list(p_user_id, p_code)` | Đọc | Dòng vé của đơn. |
| 11 | `NTK_sp_customer_booking_passenger_list(p_user_id, p_code)` | Đọc | Danh sách khách của đơn, theo `sort_order`. |
| 07 | `NTK_sp_admin_booking_set_status` | Ghi | Thêm giữ chỗ và trả chỗ (mục 3), thêm `result` `no_seats`, `schedule_closed`. |
| 07 | `NTK_sp_admin_booking_passenger_list(p_booking_id)` | Đọc | Danh sách khách (theo `sort_order`) và yêu cầu đặc biệt ở trang chi tiết yêu cầu của quản trị viên. |

Procedure của file 11 chỉ trả đơn thuộc `p_user_id`; mã của tài khoản khác → 0 dòng. Tổng số procedure sau M4: 34; sau Sprint 4: 63 (mục 7). Danh sách đầy đủ và câu `CALL` mẫu xem `src/database/README.md`.

## 7. Bổ sung Sprint 4 (migration 12, procedure 13 – 15)

`12_migration_sprint4_NMT.sql` chạy sau 01 → 11, không xóa bảng hay dữ liệu, chạy lại được (bỏ qua bảng / cột / khóa đã có).

| Thay đổi | Nội dung | Dùng cho |
| --- | --- | --- |
| Bảng `booking_extras` | Phụ thu / tùy chọn khách chọn: chụp tên, loại, đơn vị, đơn giá lúc đặt, `quantity`, `line_total_vnd`; `UNIQUE (booking_id, extra_id)`. | 4.3.2.3 |
| Bảng `booking_events` | Lịch sử đơn do khách, hệ thống hoặc VNPay tạo (`actor`, `action`, trạng thái cũ / mới, ghi chú). Thao tác của quản trị viên vẫn ghi ở `admin_logs`. | 4.3.3.2, NFR-09 |
| `bookings.voucher_code`, `voucher_issued_at`; chỉ mục `(status, hold_expires_at)` | Mã voucher cấp một lần; chỉ mục cho bước tự hủy. | 4.5.4.1, 4.5.4.2 |
| `payments.reference` (UNIQUE), `created_at`, `submitted_at`, `response_code`, `bank_code`, `note` | Mã giao dịch `LTxxxxxxPn`, lúc khách báo chuyển khoản, kết quả VNPay, ghi chú đối chiếu. | 4.5.1 – 4.5.3 |

ERD `docs/diagram/localtour-erd.drawio`, trang “03 Booking & Payments”, đã có hai bảng, các cột và khóa mới ở trên (kèm bản sao `tour_extras` để vẽ khóa ngoại `extra_id`).

Trạng thái khoản thanh toán: `pending` (vừa tạo) → `paid` (VNPay thành công / quản trị viên xác nhận) hoặc `failed` (VNPay thất bại, không khớp, đơn quá hạn); VietQR có thêm `awaiting_reconciliation` (khách đã báo chuyển khoản).

| File | Procedure | Đọc / ghi | Mục đích |
| --- | --- | --- | --- |
| 10 | `LTP_sp_booking_create(…, p_expected_total, p_extras)` | Ghi | Thêm `p_extras` (mảng JSON mã `tour_extras`), ghi `booking_extras`, `booking_events`; `result` thêm `extras_changed`. |
| 07 | `NTK_sp_admin_booking_set_status(…, p_note, p_total_vnd)` | Ghi | Chốt tổng giá khi xác nhận chỗ; xác nhận đã thanh toán thì cấp voucher; `result` thêm `invalid_total`, `total_note_required`. |
| 07, 11 | `NTK_sp_admin_booking_extra_list`, `NTK_sp_admin_booking_payment_list`, `NTK_sp_customer_booking_extra_list` | Đọc | Phụ thu / tùy chọn và các lần thanh toán của đơn. |
| 13 | `NMT_sp_admin_provider_…`, `NMT_sp_admin_tour_…`, `NMT_sp_admin_schedule_…` (15 procedure) | Đọc / ghi | CRUD nền tảng: đơn vị tổ chức, thông tin tour và trạng thái xác minh, lịch khởi hành và giá vé. Mỗi lần ghi một dòng `admin_logs`. |
| 14 | `NMT_sp_payment_list`, `_start`, `_get`, `_transfer_submit`, `NMT_sp_admin_payment_queue`, `_decide` | Đọc / ghi | Thanh toán của khách và đối chiếu VietQR. |
| 15 | `LTP_sp_payment_vnpay_result`, `LTP_sp_booking_expire_holds`, `LTP_sp_voucher_issue`, `LTP_sp_booking_history`, `LTP_sp_customer_booking_history` | Đọc / ghi | Kết quả VNPay, tự hủy, voucher, lịch sử đơn. |

Tham số, `result` và quy tắc chi tiết xem phần đầu từng file và `src/database/README.md`.
