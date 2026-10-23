# Route, hợp đồng API và quy ước lỗi

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 3 – Technical Design, Coding & QA |
| WBS | 3.1.3 – Chốt route/controller/model và quy ước lỗi |
| Căn cứ | `src/database/01_schema.sql`, `src/README.md`, wireframe UIEx1–UIEx4 và [01 – Danh mục trường dữ liệu](01-truong-du-lieu.md) |
| Trạng thái | **Thiết kế để triển khai.** Nhánh `main` hiện chưa có `src/routes/web.php`, controller, model, core router, stored procedure hoặc JavaScript ứng dụng. |

## 1. Ranh giới giữa thiết kế và source hiện tại

Các route trong tài liệu này là hợp đồng mục tiêu cho source sắp triển khai. Không được báo là “đã chạy” chỉ vì route được ghi trong tài liệu.

Hiện tại `main` có:

- Schema 26 bảng tại `src/database/01_schema.sql`.
- ERD tại `docs/diagram/localtour-erd.drawio`.
- Wireframe danh sách, chi tiết, so sánh và đặt tour.

Hiện tại `main` chưa có:

- Router/front controller và cấu hình kết nối database.
- Controller/model/service.
- Procedure, seed và dữ liệu mẫu.
- Endpoint tạo/tra cứu booking, thanh toán hoặc callback VNPay.

## 2. Route mục tiêu cho Tour List và Tour Detail

| # | Phương thức | Đường dẫn | Đầu vào | Đầu ra dự kiến |
| --- | --- | --- | --- | --- |
| R1 | GET | `/` và `/tours` | `q`, `destination_id`, `category_id`, `date`, `sort` | HTML danh sách tour. |
| R2 | GET | `/api/tours` | Các tham số ở mục 3 | JSON `{ tours, total }`. |
| R3 | GET | `/api/destinations` | Không có | JSON `{ destinations }` từ bảng `destinations`. |
| R4 | GET | `/api/categories` | Không có | JSON `{ categories }` từ bảng `categories`. |
| R5 | GET | `/tours/{uuid}` | UUID tour | HTML chi tiết tour. |
| R6 | GET | `/api/tours/{uuid}` | UUID tour | JSON chi tiết; chưa có trường đánh giá cho đến khi schema có nguồn hợp lệ. |

Dấu `/` cuối đường dẫn có thể được chấp nhận nếu router thống nhất quy tắc này. `HEAD` nên xử lý như `GET` hoặc trả đúng header tương ứng.

## 3. Tham số danh sách

| Tham số | Giá trị hợp lệ | Quy tắc |
| --- | --- | --- |
| `q` | Chuỗi tối đa 100 ký tự | Tìm trên tên, mô tả, điểm đến, loại hình và nhà tổ chức. Chuỗi rỗng = không lọc. |
| `destination_id` | UUID của `destinations.id` | UUID sai → 400; UUID đúng nhưng không có → danh sách rỗng. |
| `category_id` | UUID của `categories.id` | UUID sai → 400; UUID đúng nhưng không có → danh sách rỗng. |
| `date` | `YYYY-MM-DD` | Lọc theo `DATE(schedules.starts_at)`; ngày sai định dạng → 400. |
| `sort` | `recommended`, `newest`, `upcoming`, `price_asc`, `price_desc` | Giá trị lạ → 400 hoặc chuẩn hóa về mặc định; phải chọn một quy tắc và kiểm thử nhất quán. |

Ý nghĩa sắp xếp:

- `newest`: `tour_posts.published_at DESC`, chỉ bài đăng `published`.
- `upcoming`: lịch đặt được gần nhất trong `schedules`.
- `price_asc` / `price_desc`: giá vé `adult` thấp nhất của lịch đặt được; tour chưa có giá xếp cuối.
- `recommended`: chưa có công thức trong schema. Không dùng điểm đánh giá vì schema hiện không có `reviews`.

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

Header JSON: `Content-Type: application/json; charset=utf-8` và `Cache-Control: no-store` cho dữ liệu booking/thanh toán. Không trả stack trace, DSN, câu SQL hoặc thông tin bí mật.

### 5.1. Tour List

Một phần tử danh sách dự kiến:

```json
{
  "tour_id": "c0000000-0000-4000-8000-000000000001",
  "title": "Hà Nội qua những món ăn phố cổ",
  "excerpt": "Đi bộ cùng người địa phương...",
  "destination_id": "...",
  "destination_name": "Hà Nội",
  "category_id": "...",
  "category_name": "Ẩm thực",
  "provider_name": "Hà Nội Local",
  "duration_minutes": 240,
  "max_group_size": 8,
  "languages_text": "Tiếng Việt / Anh",
  "departure_text": "Nhà hát Múa rối Thăng Long",
  "from_price_vnd": 650000,
  "next_starts_at": "2026-10-24 17:00:00",
  "published_at": "2026-10-22 09:00:00",
  "cover_image_url": "/assets/img/tours/hanoi-1.svg"
}
```

Không trả `rating_avg`, `rating_text` hoặc `review_count` cho đến khi schema có bảng/nguồn đánh giá hợp lệ.

### 5.2. Tour Detail

`GET /api/tours/{uuid}` dự kiến trả:

```json
{
  "success": true,
  "message": "",
  "data": {
    "tour": {},
    "gallery": [],
    "itinerary": [],
    "inclusions": [],
    "schedules": [],
    "tickets": [],
    "extras": [],
    "policy": null
  }
}
```

Nguồn dữ liệu:

| Thành phần | Bảng nguồn |
| --- | --- |
| `tour` | `tours`, `providers`, `destinations`, `categories` |
| `gallery` | `tour_images` |
| `itinerary` | Chọn một trong `itinerary_stops` hoặc `tour_itinerary_items` |
| `inclusions` | Ưu tiên `tour_inclusions`; các cột summary chỉ dùng khi có quy tắc tương thích |
| `schedules` | `schedules` |
| `tickets` | `ticket_types` |
| `extras` | `tour_extras` |
| `policy` | `cancellation_policies`, phiên bản lớn nhất của tour |

Không có `reviews` trong phản hồi hiện tại vì schema đã bỏ bảng này.

## 6. Flow đặt tour và thanh toán

### 6.1. Route mục tiêu

| # | Phương thức | Đường dẫn | Mục đích |
| --- | --- | --- | --- |
| B1 | POST | `/api/bookings` | Tạo yêu cầu đặt tour ở trạng thái `pending`. |
| B2 | POST | `/api/bookings/lookup` | Tra cứu bằng `code` + `contact_email` hoặc `contact_phone`. |
| B3 | POST | `/api/bookings/{code}/payments` | Tạo thanh toán khi booking đang `awaiting_payment` và chưa quá hạn. |
| B4 | POST | `/api/payments/vnpay/ipn` | Nhận và xác minh IPN VNPay; chống xử lý trùng bằng `payment_events.provider_event_id`. |
| B5 | POST | `/api/payments/{uuid}/vietqr-submitted` | Khách báo đã chuyển khoản; chuyển sang `awaiting_reconciliation`. |

Các route B1–B5 chưa có trong source `main`; đây là hợp đồng để triển khai sau.

### 6.2. Quy tắc nghiệp vụ

1. B1 kiểm tra tour/lịch công khai, lịch `open`, chưa khởi hành và đủ `remaining`.
2. Tổng số lượng `booking_lines` phải bằng số hành khách cần khai báo.
3. Giá dòng đơn chụp vào `unit_price_vnd`; `line_total_vnd = quantity × unit_price_vnd`; tổng lưu ở `bookings.total_vnd`.
4. Booking mới là `pending`, chưa đồng nghĩa có chỗ hoặc đã thanh toán.
5. Nhân viên xác nhận chỗ và tổng tiền rồi chuyển sang `awaiting_payment`, đặt `hold_expires_at`.
6. Chỉ booking `awaiting_payment` còn hạn mới được tạo payment.
7. VNPay chỉ thành `paid` sau khi chữ ký, mã booking, số tiền và tính duy nhất sự kiện đều hợp lệ.
8. VietQR chỉ thành `paid` sau khi nhân viên đối chiếu; trước đó là `awaiting_reconciliation`.
9. Payment liên kết qua `booking_id`; khách guest không cần `customer_id`.
10. Nếu muốn hiện “Đặt chỗ của tôi” cho tài khoản customer, schema cần bổ sung liên kết nullable từ booking tới user.

## 7. Tài khoản, lưu tour, so sánh và thông báo

| Chức năng | Nguồn | Quy tắc |
| --- | --- | --- |
| Tài khoản khách | `users.role = 'customer'` | Dùng cho chức năng cá nhân hóa; không bắt buộc khi đặt tour. |
| Lưu tour | `favorite_tours` | Cần `user_id`; cặp user–tour là duy nhất. |
| So sánh | `comparisons`, `comparison_tours` | Có thể dùng `user_id` hoặc `session_key`; phải giới hạn tối đa 3 tour ở service. |
| Thông báo | `notifications` | Chỉ gửi cho tài khoản có `recipient_user_id`. |
| Bài đăng tour | `tour_posts` | Chỉ bài `published` mới xuất hiện công khai. |
| Thích/bình luận/chia sẻ | Chưa có nguồn | Không tạo route ghi dữ liệu cho đến khi schema bổ sung hoặc phạm vi bị loại. |

## 8. Quy ước lỗi

| HTTP | Khi dùng | `message` gợi ý |
| --- | --- | --- |
| 200 | GET thành công, kể cả danh sách rỗng | `""` hoặc `Không có tour phù hợp.` |
| 201 | Tạo booking/payment thành công | `Đã tiếp nhận yêu cầu.` |
| 400 | UUID, ngày, tham số hoặc payload sai | Thông báo đúng trường sai. |
| 401 | Route cần đăng nhập nhưng chưa xác thực | `Vui lòng đăng nhập.` |
| 403 | Không có quyền hoặc booking không khớp thông tin tra cứu | `Bạn không có quyền thực hiện thao tác này.` |
| 404 | Tour, booking hoặc payment không tồn tại | `Không tìm thấy dữ liệu yêu cầu.` |
| 409 | Hết chỗ, sai trạng thái, hết hạn hoặc sự kiện trùng | Thông báo theo xung đột cụ thể. |
| 422 | Dữ liệu đúng cú pháp nhưng không đạt quy tắc nghiệp vụ | Thông báo tại từng trường. |
| 503 | Không kết nối được database/cổng thanh toán | `Dịch vụ tạm thời không khả dụng. Vui lòng thử lại sau.` |
| 500 | Lỗi máy chủ khác | `Hệ thống đang gặp sự cố. Vui lòng thử lại sau.` |

## 9. Các điểm phải xử lý trước khi code route

1. Chốt một bảng lịch trình: `itinerary_stops` hoặc `tour_itinerary_items`.
2. Chốt một nguồn bao gồm/không bao gồm: summary trong `tours` hoặc `tour_inclusions`.
3. Dùng `schedules` làm lịch đặt tour; xác định kế hoạch di trú hoặc bỏ `tour_schedules`.
4. Khôi phục mô hình đánh giá nếu vẫn giữ khu vực đánh giá trên wireframe.
5. Quyết định có liên kết `bookings.user_id` nullable để hỗ trợ lịch sử booking của tài khoản khách hay chỉ tra cứu guest.
6. Bổ sung schema cho thích/bình luận nếu các nút này vẫn thuộc phạm vi.
7. Chỉ sau các quyết định trên mới tạo procedure, model, controller và test API; tài liệu không được dùng để che việc source chưa tồn tại.
