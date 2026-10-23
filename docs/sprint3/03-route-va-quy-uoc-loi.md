# Route, hợp đồng API và quy ước lỗi

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 3 – Technical Design, Coding & QA |
| WBS | 3.1.3 – Chốt route/controller/model và quy ước lỗi |
| Căn cứ | `src/database/01_schema.sql`, `src/README.md`, wireframe UIEx1–UIEx4 và [01 – Danh mục trường dữ liệu](01-truong-du-lieu.md) |
| Trạng thái | **Đã chốt.** Cập nhật 23/10/2026: thêm route tài khoản khách hàng (đăng ký, đăng nhập, đăng xuất) và chế độ khách. |

## 1. Phạm vi Sprint 3

Sprint 3 làm các route ở mục 2: danh sách tour, chi tiết tour và tài khoản khách hàng. Cấu trúc router, controller, model xem `src/README.md`; danh sách stored procedure xem `src/database/README.md`.

- **Chế độ khách** (chưa đăng nhập): xem danh sách và chi tiết tour, không đặt tour.
- **Đã đăng nhập** (tài khoản `customer`): xem như chế độ khách, header hiện chữ cái đầu và tên tài khoản, kèm nút Đăng xuất. Nút “Đặt tour” vẫn bị tắt, nhãn “Sắp có”.

Chưa làm trong Sprint 3:

- Đặt tour, tra cứu đơn, thanh toán và callback VNPay (route B1–B5 ở mục 6 là hợp đồng cho Sprint sau).
- Thích, bình luận, chia sẻ, Lưu tour, So sánh (nút bị tắt, nhãn “Sắp có”).
- Sắp xếp `newest` và lọc theo ngày `date`.

## 2. Route

### 2.1. Tour List và Tour Detail

| # | Phương thức | Đường dẫn | Đầu vào | Đầu ra |
| --- | --- | --- | --- | --- |
| R1 | GET | `/` và `/tours` | `q`, `destination_id`, `category_id`, `sort` | HTML danh sách tour; danh sách tải bằng AJAX từ R2. |
| R2 | GET | `/api/tours` | Các tham số ở mục 3 | JSON `{ tours, total }` (mục 5.1). 400 khi `q` quá 100 ký tự hoặc `destination_id`/`category_id` sai UUID. |
| R3 | GET | `/api/destinations` | Không có | JSON `{ destinations: [{ destination_id, name, slug, tour_count }] }` từ bảng `destinations`. |
| R4 | GET | `/api/categories` | Không có | JSON `{ categories: [{ category_id, name, slug, tour_count }] }` từ bảng `categories`. |
| R5 | GET | `/tours/{uuid}` | UUID tour | HTML chi tiết tour; trang 404 khi UUID sai, không tìm thấy hoặc tour không công khai. |
| R6 | GET | `/api/tours/{uuid}` | UUID tour | JSON chi tiết (mục 5.2); 400 UUID sai, 404 không tìm thấy. |

R3 và R4 chỉ trả điểm đến/loại hình đang có ít nhất một tour công khai. Router chấp nhận dấu `/` cuối đường dẫn; `HEAD` được xử lý như `GET`.

### 2.2. Tài khoản khách hàng

| # | Phương thức | Đường dẫn | Đầu vào | Đầu ra |
| --- | --- | --- | --- | --- |
| A1 | GET | `/login` | `next` (không bắt buộc) | HTML form đăng nhập. Đã đăng nhập → chuyển về `next` hoặc `/tours`. |
| A2 | POST | `/login` | `email`, `password`, `next`, `_csrf` | Đúng → 303 về `next` hoặc `/tours`. Bỏ trống → form hiện lại, 422 `Vui lòng nhập email và mật khẩu.` Sai → form hiện lại, 401 `Email hoặc mật khẩu không đúng.` |
| A3 | GET | `/register` | `next` (không bắt buộc) | HTML form đăng ký. Đã đăng nhập → chuyển về `next` hoặc `/tours`. |
| A4 | POST | `/register` | `name`, `email`, `phone` (không bắt buộc), `password`, `password_confirm`, `next`, `_csrf` | Đúng → tạo tài khoản, đăng nhập luôn, 303 về `next` hoặc `/tours`. Dữ liệu sai → form hiện lại, 422. Email đã dùng → 409 `Email này đã được dùng.` |
| A5 | POST | `/logout` | `_csrf` | Xóa phiên, 303 về `/tours`. Sai `_csrf` → không xóa phiên, vẫn 303 về `/tours`. |

A1–A5 trả HTML hoặc chuyển hướng, không trả JSON. Form đăng nhập / đăng ký thiếu hoặc sai `_csrf` → form hiện lại, 403 `Phiên làm việc đã hết hạn, vui lòng thử lại.` Quy tắc chi tiết ở mục 7.1 và 7.2.

## 3. Tham số danh sách

| Tham số | Giá trị hợp lệ | Quy tắc |
| --- | --- | --- |
| `q` | Chuỗi tối đa 100 ký tự | Tìm trên tên, mô tả, điểm đến, loại hình và nhà tổ chức. Chuỗi rỗng = không lọc. Quá 100 ký tự → 400. |
| `destination_id` | UUID của `destinations.id` | UUID sai → 400; UUID đúng nhưng không có → danh sách rỗng. |
| `category_id` | UUID của `categories.id` | UUID sai → 400; UUID đúng nhưng không có → danh sách rỗng. |
| `sort` | `recommended`, `upcoming`, `price_asc`, `price_desc` | Thiếu hoặc giá trị lạ → `recommended`. |

Không làm trong Sprint 3: lọc `date` (tham số bị bỏ qua) và `sort=newest` (coi là `recommended`).

Ý nghĩa sắp xếp:

- `recommended` (mặc định, tab “Nổi bật”): tour có đánh giá đã duyệt trước, `rating_avg` giảm dần, rồi `review_count` giảm dần.
- `upcoming`: lịch đặt được gần nhất trong `schedules`; tour chưa có lịch xếp cuối.
- `price_asc` / `price_desc`: giá vé `adult` thấp nhất của lịch đặt được; tour chưa có giá xếp cuối.
- Cùng thứ hạng thì theo tên tour, rồi `tour_id`.

## 4. Quy ước UUID

Mọi khóa chính và khóa ngoại nghiệp vụ dùng UUID dạng chữ `CHAR(36)`:

```text
^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$
```

- Chấp nhận chữ hoa/chữ thường và chuẩn hóa về chữ thường.
- UUID sai định dạng bị từ chối trước khi gọi database.
- Trang HTML chi tiết trả 404 cho UUID sai hoặc tour không công khai.
- API trả 400 cho UUID sai định dạng, 404 cho UUID hợp lệ nhưng không tìm thấy.

## 5. Hợp đồng JSON chung

```json
{
  "success": true,
  "message": "",
  "data": {}
}
```

| Khóa | Kiểu | Quy ước |
| --- | --- | --- |
| `success` | boolean | `true` với yêu cầu thành công; `false` khi lỗi. |
| `message` | string | Thông báo tiếng Việt có thể hiển thị cho người dùng. |
| `data` | object hoặc `null` | `null` khi lỗi. |

Header JSON: `Content-Type: application/json; charset=utf-8` và `Cache-Control: no-store` cho mọi phản hồi JSON. Không trả stack trace, DSN, câu SQL hoặc thông tin bí mật.

### 5.1. Tour List

Một phần tử của `data.tours`:

```json
{
  "tour_id": "c0000000-0000-4000-8000-000000000001",
  "title": "Hà Nội qua những món ăn phố cổ",
  "excerpt": "Đi bộ cùng người địa phương...",
  "url": "/tours/c0000000-0000-4000-8000-000000000001",
  "destination_id": "...",
  "destination_name": "Hà Nội",
  "category_id": "...",
  "category_name": "Ẩm thực",
  "provider_name": "Hà Nội Local",
  "duration_minutes": 240,
  "duration_text": "4 giờ",
  "max_group_size": 8,
  "languages_text": "Tiếng Việt / Anh",
  "pickup_mode": "meeting_point",
  "pickup_text": "Gặp tại Nhà hát Múa rối Thăng Long",
  "departure_text": "Nhà hát Múa rối Thăng Long",
  "meeting_point": "Nhà hát Múa rối Thăng Long",
  "from_price_vnd": 650000,
  "price_text": "650.000đ",
  "cover_image_url": "/assets/img/tours/hanoi-1.svg",
  "cover_caption": "...",
  "rating_avg": 4.8,
  "rating_text": "4,8",
  "review_count": 4,
  "next_starts_at": "2026-10-24 17:00:00",
  "next_departure_text": "24/10/2026 · 17:00"
}
```

- Tour chưa có đánh giá đã duyệt: `rating_avg`, `rating_text` là `null`, `review_count` là `0`.
- Giá, lịch, ảnh bìa hoặc loại hình chưa có: khóa tương ứng là `null`, giao diện hiện “Chưa cập nhật”.
- Danh sách rỗng: `tours` là `[]`, `total` là `0`, `message` là `Không có tour phù hợp.`

### 5.2. Tour Detail

`GET /api/tours/{uuid}` trả:

```json
{
  "success": true,
  "message": "",
  "data": {
    "tour": {},
    "gallery": [],
    "schedules": [],
    "tickets": [],
    "itinerary": [
      { "item_id": "...", "start_time": "08:00:00", "time_text": "08:00", "description": "..." }
    ],
    "inclusions": { "included": ["..."], "excluded": ["..."] },
    "extras": [],
    "reviews": [],
    "policy": null
  }
}
```

Nguồn dữ liệu:

| Thành phần | Bảng nguồn |
| --- | --- |
| `tour` | `tours`, `providers`, `destinations`, `categories`. Có `destination_id`, `destination_name`, `category_id`, `category_name`; không có `included_summary`, `excluded_summary`. |
| `gallery` | `tour_images` |
| `schedules` | `schedules` |
| `tickets` | `ticket_types` |
| `itinerary` | `tour_itinerary_items`, theo `sort_order`; mục không ghi giờ có `start_time` là `null` |
| `inclusions` | `tour_inclusions`: `is_included = 1` vào `included`, `0` vào `excluded` |
| `extras` | `tour_extras` |
| `reviews` | `reviews` đã duyệt, tối đa 5; `reviewer_name` là `users.name` của chủ đơn (`bookings.user_id`) |
| `policy` | `cancellation_policies`, phiên bản lớn nhất của tour |

## 6. Flow đặt tour và thanh toán

### 6.1. Route cho Sprint sau

| # | Phương thức | Đường dẫn | Mục đích |
| --- | --- | --- | --- |
| B1 | POST | `/api/bookings` | Tạo yêu cầu đặt tour ở trạng thái `pending`. |
| B2 | POST | `/api/bookings/lookup` | Tra cứu đơn theo `code`; chỉ trả đơn của tài khoản đang đăng nhập. |
| B3 | POST | `/api/bookings/{code}/payments` | Tạo thanh toán khi booking đang `awaiting_payment` và chưa quá hạn. |
| B4 | POST | `/api/payments/vnpay/ipn` | Nhận và xác minh IPN VNPay; chống xử lý trùng bằng `payment_events.provider_event_id`. |
| B5 | POST | `/api/payments/{uuid}/vietqr-submitted` | Khách báo đã chuyển khoản; chuyển sang `awaiting_reconciliation`. |

B1–B5 chưa làm trong Sprint 3. B1, B2, B3, B5 cần đăng nhập tài khoản `customer`: chưa đăng nhập → 401 `Vui lòng đăng nhập.` B4 do máy chủ VNPay gọi nên không dùng phiên và `_csrf`; xác minh bằng chữ ký.

### 6.2. Quy tắc nghiệp vụ

1. B1 kiểm tra khách đã đăng nhập, tour/lịch công khai, lịch `open`, chưa khởi hành và đủ `remaining`.
2. `bookings.user_id` lấy từ phiên đăng nhập, không nhận từ dữ liệu gửi lên.
3. Tổng số lượng `booking_lines` phải bằng số hành khách cần khai báo.
4. Giá dòng đơn chụp vào `unit_price_vnd`; `line_total_vnd = quantity × unit_price_vnd`; tổng lưu ở `bookings.total_vnd`.
5. Booking mới là `pending`, chưa đồng nghĩa có chỗ hoặc đã thanh toán.
6. Nhân viên xác nhận chỗ và tổng tiền rồi chuyển sang `awaiting_payment`, đặt `hold_expires_at`.
7. Chỉ booking `awaiting_payment` còn hạn mới được tạo payment.
8. VNPay chỉ thành `paid` sau khi chữ ký, mã booking, số tiền và tính duy nhất sự kiện đều hợp lệ.
9. VietQR chỉ thành `paid` sau khi nhân viên đối chiếu; trước đó là `awaiting_reconciliation`.
10. Payment liên kết qua `booking_id`; tài khoản của đơn đã có ở `bookings.user_id` nên payment không cần thêm cột tài khoản.
11. “Đặt chỗ của tôi” lấy đơn theo `bookings.user_id` của tài khoản đang đăng nhập.

## 7. Tài khoản, lưu tour, so sánh và thông báo

| Chức năng | Nguồn | Quy tắc |
| --- | --- | --- |
| Tài khoản khách | `users.role = 'customer'` | Bắt buộc khi đặt tour. Sprint 3 có đăng ký, đăng nhập, đăng xuất (mục 2.2). |
| Lưu tour | `favorite_tours` | Cần `user_id`; cặp user–tour là duy nhất. Sprint 3: nút bị tắt, nhãn “Sắp có”. |
| So sánh | `comparisons`, `comparison_tours` | Có thể dùng `user_id` hoặc `session_key`; tối đa 3 tour ở service. Sprint 3: nút bị tắt, nhãn “Sắp có”. |
| Thông báo | `notifications` | Chỉ gửi cho tài khoản có `recipient_user_id`. Sprint 3 chưa dùng. |
| Bài đăng tour | `tour_posts` | Chỉ bài `published` mới xuất hiện công khai. Sprint 3 chưa dùng. |
| Thích/bình luận/chia sẻ | Không có bảng | `post_comments`, `post_interactions` đã bỏ. Nút bị tắt, nhãn “Sắp có”; không có route ghi dữ liệu. |

### 7.1. Đăng ký và đăng nhập

- **Đăng ký:** kiểm tra theo tài liệu 01 mục 2.1 (họ tên tối đa 100 ký tự; email hợp lệ, tối đa 150 ký tự, lưu chữ thường; số điện thoại không bắt buộc; mật khẩu tối thiểu 8 ký tự, tối đa 72 byte và nhập lại khớp). Mật khẩu được băm bằng `password_hash(PASSWORD_DEFAULT)` rồi gọi `NTK_sp_customer_register`. Lỗi kiểm tra → 422, form hiện lại với dữ liệu đã nhập (trừ mật khẩu). Email đã dùng → 409. Thành công → đăng nhập luôn.
- **Đăng nhập:** gọi `NTK_sp_user_find_by_email`; chỉ nhận `role = 'customer'`, `status = 'active'`, `password_hash` khác `NULL` và `password_verify` đúng. Bỏ trống email hoặc mật khẩu → 422 `Vui lòng nhập email và mật khẩu.` Các trường hợp sai còn lại đều trả một thông báo chung `Email hoặc mật khẩu không đúng.` (401), không cho biết email có tồn tại hay không. Thành công → đổi session id (`session_regenerate_id`).
- **`next`:** chỉ nhận đường dẫn trong ứng dụng: bắt đầu bằng `/`, không bắt đầu bằng `//`, không có `\`, không có scheme (`http:`, `https:`…). Sai → `/tours`.
- Đã đăng nhập mà mở `/login` hoặc `/register` → chuyển về `next` (hoặc `/tours`).

### 7.2. Phiên và CSRF

- Cookie phiên `httponly`, `SameSite=Lax`, `secure` khi chạy HTTPS; bật `session.use_strict_mode`.
- Session lưu `user_id`, `name`, `email`, `role`; không lưu mật khẩu.
- Mỗi phiên có một mã CSRF; mọi form POST gửi kèm trường `_csrf`. Form đăng nhập / đăng ký thiếu hoặc sai → 403 `Phiên làm việc đã hết hạn, vui lòng thử lại.`
- Đăng xuất chỉ bằng POST có `_csrf` đúng; xóa phiên rồi về `/tours`. Sai `_csrf` → không xóa phiên, vẫn về `/tours`.

## 8. Quy ước lỗi

| HTTP | Khi dùng | `message` gợi ý |
| --- | --- | --- |
| 200 | GET thành công, kể cả danh sách rỗng | `""` hoặc `Không có tour phù hợp.` |
| 201 | Tạo booking/payment thành công (Sprint sau) | `Đã tiếp nhận yêu cầu.` |
| 303 | Đăng nhập, đăng ký, đăng xuất thành công | Chuyển hướng tới `next` hoặc `/tours`. |
| 400 | UUID, tham số hoặc payload sai | Thông báo đúng trường sai. |
| 401 | Route cần đăng nhập nhưng chưa xác thực | `Vui lòng đăng nhập.` Đăng nhập sai: `Email hoặc mật khẩu không đúng.` |
| 403 | Không có quyền, đơn không thuộc tài khoản, hoặc mã CSRF thiếu/sai | `Bạn không có quyền thực hiện thao tác này.` CSRF: `Phiên làm việc đã hết hạn, vui lòng thử lại.` |
| 404 | Tour, booking hoặc payment không tồn tại | `Không tìm thấy dữ liệu yêu cầu.` |
| 409 | Hết chỗ, sai trạng thái, hết hạn, sự kiện trùng hoặc email đăng ký đã dùng | Thông báo theo xung đột cụ thể, ví dụ `Email này đã được dùng.` |
| 422 | Dữ liệu đúng cú pháp nhưng không đạt quy tắc nghiệp vụ (kể cả form đăng ký) | Thông báo tại từng trường. |
| 503 | Không kết nối được database/cổng thanh toán | `Dịch vụ tạm thời không khả dụng. Vui lòng thử lại sau.` |
| 500 | Lỗi máy chủ khác | `Hệ thống đang gặp sự cố. Vui lòng thử lại sau.` |

## 9. Các quyết định đã chốt

1. Lịch trình: `tour_itinerary_items` (có `start_time`); `itinerary_stops` để trống, không dùng.
2. Bao gồm/không bao gồm: `tour_inclusions`; `tours.included_summary`, `excluded_summary` để `NULL`, không dùng.
3. Lịch đặt tour: `schedules`; `tour_schedules` giữ trong schema, để trống, không dùng.
4. Đánh giá: khôi phục `reviews`; mỗi đơn tối đa một đánh giá; tên người đánh giá là `users.name` của chủ đơn.
5. `bookings.user_id` bắt buộc (khóa ngoại tới `users`): đặt tour phải đăng nhập; chế độ khách chỉ xem tour.
6. Thích/bình luận/chia sẻ: không bổ sung schema; nút hiện “Sắp có”.
7. Điểm đến và loại hình lấy từ bảng `destinations`, `categories`, lọc theo id.
8. Không làm trong Sprint 3: `newest`, `date`, Lưu tour, So sánh, đặt tour và thanh toán.
