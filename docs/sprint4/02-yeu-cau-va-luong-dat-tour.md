# Yêu cầu và luồng đặt tour MVP

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 4 – M4 Nghiệm thu bản tích hợp và Booking MVP |
| WBS | M4 mục 2 – Chốt yêu cầu và luồng đặt tour MVP |
| Người phụ trách | Lê Trung Phong |
| Căn cứ | User Flow đặt tour `docs/diagram/user-flow-dat-tour_localtour.drawio.png` (phần ① và ②, phần ③ ở trang quản trị); BPMN đặt tour dự kiến `docs/diagram/bpmn-dat-tour-du-kien_localtour.drawio.png`; wireframe `docs/diagram/wireframe-4-dat-tour_localtour.png`; bảng FR (FR-08, FR-09, FR-11, FR-14); [Sprint 3 – 03 Route và quy ước lỗi](../sprint3/03-route-va-quy-uoc-loi.md), mục 6 |
| Tài liệu liên quan | [01 – Rà soát M3 và tồn đọng](01-ra-soat-m3-va-ton-dong.md), [03 – Cấu trúc dữ liệu Booking](03-cau-truc-du-lieu-booking.md), `src/README.md` (Bước 8), `src/database/README.md` |
| Trạng thái | **Đã chốt.** |

## 1. Phạm vi M4

Đặt tour MVP là khách hàng **gửi yêu cầu đặt tour** cho một lịch khởi hành và chờ LocalTour xác nhận. Yêu cầu chưa giữ chỗ và chưa thu tiền.

| FR | Nội dung | M4 làm |
| --- | --- | --- |
| FR-08 | Tạo yêu cầu đặt tour | Chọn lịch và số khách, nhập thông tin, xem lại, gửi. Đơn mới ở trạng thái “Chờ xác nhận”. |
| FR-09 | Thông tin khách và yêu cầu đặc biệt | Người liên hệ (họ tên, email, số điện thoại), họ tên từng khách, yêu cầu đặc biệt (không bắt buộc). |
| FR-11 | Mã đặt chỗ và trạng thái | Mã đơn `LTxxxxxx`; trang “Đơn của tôi” xem danh sách và chi tiết đơn của tài khoản đang đăng nhập. |
| FR-14 | Ngày khởi hành và sức chứa | Chỉ đặt lịch còn nhận khách; số khách không vượt số chỗ còn lại và nhóm tối đa của tour. Quản trị viên xác nhận chỗ thì trừ chỗ, hủy đơn đang giữ chỗ thì trả lại chỗ. |

Chưa làm trong M4:

- Thanh toán VNPay / VietQR (FR-17, route B3–B5): M5. Ở trạng thái “Chờ thanh toán”, trang đơn chỉ báo bước tiếp theo.
- Tự hủy đơn quá hạn giữ chỗ 24 giờ: M5, đi cùng thanh toán.
- Khách tự đổi ngày, đổi số người hoặc hủy đơn (FR-12): phát triển sau. Khách liên hệ LocalTour, quản trị viên xử lý ở trang quản trị.
- Phụ thu và hoạt động tùy chọn (`tour_extras`), mã giảm giá: không có trong MVP. Tổng tiền chỉ gồm tiền vé.
- Gửi email xác nhận: chưa làm. Khách theo dõi đơn ở “Đơn của tôi”.

## 2. Luồng đặt tour

Luồng đi từ Tour List → Tour Detail → trang đặt tour → “Đơn của tôi”, dùng dữ liệu thật trong database.

1. **Danh sách tour** (`/tours`): khách tìm và chọn một tour.
2. **Chi tiết tour** (`/tours/{id}`): thẻ đặt tour cho chọn ngày tham gia và số khách theo loại vé, hiện tạm tính tiền vé.
   - Tài khoản khách hàng: bấm **Đặt tour** → `/tours/{id}/book?schedule_id=…&tickets[<mã vé>]=<số khách>`.
   - Chế độ khách (chưa đăng nhập): nút **Đăng nhập để đặt tour**. Link đăng nhập mang theo lịch và số khách đang chọn trong `next`; đăng nhập hoặc đăng ký xong thì vào thẳng trang đặt tour với lựa chọn đó.
3. **Trang “Hoàn tất thông tin đặt tour”** (`/tours/{id}/book`), theo wireframe 4:
   - Bên trái: thông tin người liên hệ (điền sẵn họ tên, email của tài khoản), thông tin chuyến đi (ngày tham gia, số khách theo loại vé), họ tên từng khách, điểm gặp, yêu cầu đặc biệt, ô đồng ý điều kiện đặt tour và chính sách hủy.
   - Bên phải: tour đã chọn, ngày giờ, tiền vé từng loại, tổng tiền, chính sách hủy, ghi chú “Chưa thu tiền ở bước này”.
   - Lịch chọn ở trang chi tiết vừa hết chỗ hoặc không còn nhận khách → trang chọn lịch đầu tiên còn đặt được và báo “Lịch bạn chọn đã hết chỗ hoặc không còn nhận khách. Vui lòng chọn ngày khác.”
4. **Xem lại & xác nhận**: trình duyệt kiểm tra form, rồi hỏi chỗ trống (`GET /api/schedules/{id}/availability`).
   - Lịch không còn nhận đặt hoặc không đủ chỗ → báo lỗi ở ô ngày hoặc ô số khách, ở lại form.
   - Giá vé vừa đổi → cập nhật giá và tổng tiền mới, khách bấm xem lại lần nữa.
   - Đủ chỗ, giá không đổi → hiện bước xem lại: tour, ngày giờ, danh sách khách, người liên hệ, tổng tiền.
5. **Gửi yêu cầu đặt tour** (`POST /api/bookings`): server kiểm tra lại mọi thứ trong một transaction rồi tạo đơn.
   - Thành công → chuyển tới trang đơn `/bookings/{mã đơn}?new=1`, báo “Đã gửi yêu cầu đặt tour”.
   - Lỗi → quay về form, giữ nguyên thông tin đã nhập, báo lỗi ở đúng ô (mục 6).
   - Mất kết nối hoặc lỗi máy chủ → ở lại bước xem lại để bấm gửi lại; gửi lại không tạo đơn thứ hai (mục 3, quy tắc 9).
6. **Đơn của tôi** (`/bookings`): danh sách đơn của tài khoản, mới đặt trước; mở một đơn để xem trạng thái, tour, ngày giờ, vé, danh sách khách, người liên hệ, yêu cầu đặc biệt, chính sách hủy của đơn và lý do nếu bị từ chối / hủy.
7. **Quản trị viên** (`/admin/bookings`, đã có từ Sprint 3, FR-25): xác nhận chỗ và giá (đơn chuyển “Chờ thanh toán”, giữ chỗ 24 giờ), từ chối hoặc hủy kèm lý do.

Chỉ tài khoản `customer` đặt được tour. Tài khoản quản trị viên mở trang đặt tour hoặc “Đơn của tôi” nhận trang 403.

## 3. Quy tắc nghiệp vụ

| # | Quy tắc |
| --- | --- |
| 1 | Phải đăng nhập tài khoản khách hàng đang hoạt động. `bookings.user_id` lấy từ phiên, không nhận từ form. |
| 2 | Lịch đặt được: tour đang hiển thị công khai, lịch `open`, chưa tới giờ khởi hành, còn chỗ và có ít nhất một loại vé đang bán. |
| 3 | Số khách từ 1 đến min(`tours.max_group_size`, `schedules.remaining`); một đơn tối đa 50 khách. Ô số khách ở trang không cho chọn vượt mức này. |
| 4 | Mỗi khách một dòng họ tên (bắt buộc, tối đa 100 ký tự) và đúng một loại vé đang bán của lịch đó. |
| 5 | Người liên hệ: họ tên bắt buộc, tối đa 100 ký tự; email bắt buộc, hợp lệ, tối đa 150 ký tự, lưu chữ thường; số điện thoại bắt buộc, 8–20 ký tự, chỉ gồm số và khoảng trắng, có thể bắt đầu bằng `+`. |
| 6 | Yêu cầu đặc biệt không bắt buộc, tối đa 500 ký tự. |
| 7 | Phải tick “Tôi đã đọc điều kiện đặt tour và chính sách hủy”. |
| 8 | Giá do server tính lại từ `ticket_types.price_vnd`, không lấy giá từ form. Tổng tiền khác số tiền khách đã thấy (`expected_total`) → không tạo đơn, báo tổng mới để khách xem lại. |
| 9 | Mỗi lần mở trang đặt tour có một `request_token` mới. Cùng tài khoản gửi lại cùng mã (bấm hai lần, mạng chập chờn) chỉ tạo một đơn; lần sau trả lại mã đơn đã tạo. |
| 10 | Đơn mới là `pending` (Chờ xác nhận): chưa trừ `remaining`, chưa thu tiền. Lúc tạo đơn chỉ kiểm tra còn đủ chỗ. |
| 11 | Giá từng loại vé chụp vào `booking_lines.unit_price_vnd`; `bookings.policy_version` = phiên bản chính sách hủy mới nhất của tour lúc đặt. Sau này tour đổi giá hay đổi chính sách thì đơn cũ vẫn giữ giá và chính sách lúc đặt. |
| 12 | Khách chỉ xem được đơn của chính mình. Mã đơn của người khác hoặc không có → trang 404 “Không tìm thấy đơn”, không cho biết mã đó có tồn tại hay không. Không tra cứu đơn theo email hay số điện thoại. |

## 4. Trạng thái đơn và số chỗ

| Trạng thái | Nhãn cho khách | Ý nghĩa | Số chỗ của lịch |
| --- | --- | --- | --- |
| `pending` | Chờ xác nhận | Khách vừa gửi yêu cầu, LocalTour đang kiểm tra. | Chưa trừ. |
| `awaiting_payment` | Chờ thanh toán | Quản trị viên đã xác nhận chỗ và giá; giữ chỗ 24 giờ (`hold_expires_at`). | Trừ theo số khách của đơn khi chuyển sang trạng thái này. Lịch về 0 chỗ thì thành `full`. |
| `confirmed` | Đã xác nhận | Đã thanh toán (quản trị viên xác nhận). | Giữ nguyên chỗ đã trừ. |
| `completed` | Đã hoàn thành | Tour đã diễn ra. | Không đổi. |
| `rejected` | Từ chối | Quản trị viên từ chối yêu cầu `pending`, kèm lý do. | Không đổi (chưa trừ). |
| `cancelled` | Đã hủy | Quản trị viên hủy đơn, kèm lý do. | Hủy từ `awaiting_payment` hoặc `confirmed` thì cộng lại chỗ (không vượt `capacity`), lịch `full` mở lại `open`. Hủy từ `pending` không đổi. |

Quản trị viên xác nhận chỗ khi lịch đã đóng hoặc đã khởi hành → báo “Lịch khởi hành đã đóng hoặc đã tới giờ khởi hành, chưa xác nhận chỗ được.”; khi lịch không còn đủ chỗ → báo “Lịch khởi hành không còn đủ chỗ cho yêu cầu này, chưa xác nhận được. Hãy từ chối kèm lý do (vd. đề nghị khách chọn ngày khác).” Cả hai trường hợp không đổi dữ liệu. Bảng chuyển trạng thái đầy đủ xem [Sprint 3 – 02 Lược đồ dữ liệu](../sprint3/02-luoc-do-du-lieu.md), mục 7.3; quy tắc giữ chỗ M4 thay câu “Procedure không đổi `schedules.remaining`” ở mục đó (xem [03 – Cấu trúc dữ liệu Booking](03-cau-truc-du-lieu-booking.md), mục 3).

## 5. Route và hợp đồng API

| # | Phương thức | Đường dẫn | Đầu vào | Đầu ra |
| --- | --- | --- | --- | --- |
| B0 | GET | `/tours/{id}/book` | `schedule_id`, `tickets[<mã vé>]=<số khách>` (không bắt buộc) | HTML trang đặt tour. Chưa đăng nhập → chuyển tới `/login?next=<trang này kèm lựa chọn>`. Không phải tài khoản khách hàng → trang 403. Tour sai UUID hoặc không công khai → trang 404. |
| B1a | GET | `/api/schedules/{id}/availability` | `people` (1–50, mặc định 1) | JSON mục 5.1. 400 UUID sai, 404 không có lịch hoặc tour không công khai, 422 `people` sai. Không cần đăng nhập. |
| B1 | POST | `/api/bookings` | Form mục 5.2 | JSON mục 5.2 và mục 6. |
| B2 | GET | `/bookings` | Không có | HTML “Đơn của tôi”. Chưa đăng nhập → `/login?next=/bookings`. Tài khoản quản trị → trang 403. |
| B2a | GET | `/bookings/{code}` | Mã đơn (`LT` + 6 số, không phân biệt hoa thường), `new=1` sau khi vừa gửi | HTML chi tiết đơn. Chưa đăng nhập → `/login?next=…`. Mã sai dạng, không có hoặc của tài khoản khác → trang 404. |

B1 giữ đúng hợp đồng đã dự kiến ở Sprint 3 (mục 6.1). B2 dự kiến là `POST /api/bookings/lookup`; M4 thay bằng hai trang B2, B2a vì khách chỉ xem đơn của tài khoản mình, không cần tra cứu theo mã. B1a là route mới để báo sớm hết chỗ hoặc giá đổi trước bước xem lại. Các phản hồi JSON giữ hợp đồng chung `{ success, message, data }`.

### 5.1. Kiểm tra chỗ trống (B1a)

`GET /api/schedules/d0000000-0000-4000-8000-000000000040/availability?people=2`

```json
{
  "success": true,
  "message": "Lịch này chỉ còn 1 chỗ.",
  "data": {
    "schedule_id": "d0000000-0000-4000-8000-000000000040",
    "tour_id": "c0000000-0000-4000-8000-000000000006",
    "starts_at": "2026-10-31 16:30:00",
    "ends_at": "2026-10-31 19:30:00",
    "status": "open",
    "remaining": 1,
    "max_group_size": 10,
    "bookable": true,
    "people": 2,
    "enough": false,
    "tickets": [
      { "id": "e0000000-0000-4000-8000-000000000401", "label": "Người lớn", "ages": "Từ 12 tuổi", "price": 590000 },
      { "id": "e0000000-0000-4000-8000-000000000402", "label": "Trẻ em", "ages": "4–11 tuổi", "price": 410000 }
    ]
  }
}
```

- `bookable`: lịch còn nhận đặt (mục 3, quy tắc 2). `enough`: `bookable` và `people` không vượt `max_group_size` và `remaining`.
- `message` theo thứ tự: “Lịch này không còn nhận đặt. Vui lòng chọn ngày khác.” → “Mỗi nhóm tối đa N khách.” → “Lịch này chỉ còn N chỗ.” → “Lịch còn đủ chỗ cho N khách.”
- `tickets`: loại vé đang bán, vé đắt trước, để trang so giá. Ngày giờ trong ví dụ phụ thuộc ngày import dữ liệu.
- Kết quả chỉ để báo sớm cho khách; B1 kiểm tra lại khi tạo đơn.

### 5.2. Gửi yêu cầu đặt tour (B1)

Form `application/x-www-form-urlencoded`:

| Trường | Ghi chú |
| --- | --- |
| `_csrf` | Mã CSRF của phiên. |
| `schedule_id` | UUID lịch. |
| `request_token` | 32 ký tự hex, trang sinh ra mỗi lần mở. |
| `expected_total` | Tổng tiền (VND) khách thấy ở bước xem lại. |
| `contact_name`, `contact_email`, `contact_phone` | Người liên hệ. |
| `passengers[i][ticket_type_id]`, `passengers[i][full_name]` | Mỗi khách một phần tử, theo thứ tự trên form. |
| `special_request` | Không bắt buộc. |
| `terms` | `1` khi đã tick đồng ý. |

Thành công (201):

```json
{
  "success": true,
  "message": "Đã gửi yêu cầu đặt tour.",
  "data": { "code": "LT518204", "url": "/bookings/LT518204?new=1" }
}
```

Gửi lại cùng `request_token` (200): `success: true`, `message` “Yêu cầu này đã được gửi trước đó.”, `data` có `code` và `url` của đơn đã tạo (không kèm `?new=1`). Mã đơn trong ví dụ là đơn mẫu; mã thật sinh ngẫu nhiên.

## 6. Quy ước lỗi của đặt tour

Lỗi trả `success: false`. Trang giữ nguyên thông tin đã nhập và hiện lỗi ở đúng ô.

| HTTP | Khi nào | `message` | `data` |
| --- | --- | --- | --- |
| 401 | Chưa đăng nhập hoặc phiên đã hết | `Vui lòng đăng nhập để đặt tour.` | `null`; trang hiện link “Đăng nhập lại”. |
| 403 | Không phải tài khoản khách hàng | `Chỉ tài khoản khách hàng mới đặt được tour.` | `null` |
| 403 | Thiếu hoặc sai `_csrf` | `Phiên làm việc đã hết hạn, vui lòng tải lại trang và thử lại.` | `null` |
| 403 | Procedure trả `forbidden` (tài khoản vừa bị khóa) | `Tài khoản của bạn hiện không đặt tour được.` | `null` |
| 422 | Dữ liệu form sai | `Vui lòng kiểm tra lại thông tin đặt tour.` | `{ "errors": { "<ô>": "<lỗi>" } }` |
| 409 | `schedule_unavailable` | `Lịch này không còn nhận đặt. Vui lòng chọn ngày khác.` | `{ "reason" }` |
| 409 | `group_limit` | `Mỗi nhóm tối đa N khách.` | `{ "reason", "max_group_size" }` |
| 409 | `no_seats` | `Lịch này chỉ còn N chỗ. Vui lòng giảm số khách hoặc chọn ngày khác.` (còn 0 chỗ: `Lịch này vừa hết chỗ. Vui lòng chọn ngày khác.`) | `{ "reason", "remaining" }` |
| 409 | `tickets_changed` | `Loại vé của lịch này vừa thay đổi. Vui lòng chọn lại số khách.` | `{ "reason", "tickets" }` |
| 409 | `price_changed` | `Giá vé vừa thay đổi, tổng tiền mới là 1.310.000đ. Vui lòng xem lại trước khi gửi.` (ví dụ) | `{ "reason", "total_vnd", "tickets" }` |
| 409 | `retry` (trùng mã đơn hiếm gặp) | `Chưa gửi được yêu cầu, vui lòng bấm gửi lại.` | `{ "reason" }` |

Khóa lỗi 422 và thông báo:

| Khóa | Thông báo |
| --- | --- |
| `form` | `Trang đặt tour đã cũ, vui lòng tải lại trang.` (`request_token` hoặc `expected_total` sai dạng) |
| `schedule_id` | `Vui lòng chọn ngày tham gia.` |
| `contact_name` | `Vui lòng nhập họ tên người liên hệ.` / `Họ tên tối đa 100 ký tự.` |
| `contact_email` | `Vui lòng nhập email.` / `Email không hợp lệ.` |
| `contact_phone` | `Vui lòng nhập số điện thoại.` / `Số điện thoại không hợp lệ.` |
| `passengers` | `Vui lòng chọn ít nhất 1 khách.` / `Mỗi đơn tối đa 50 khách.` |
| `passengers.i` | `Vui lòng nhập họ tên khách N.` / `Họ tên khách tối đa 100 ký tự.` / `Loại vé của khách N không hợp lệ, vui lòng chọn lại số khách.` |
| `special_request` | `Yêu cầu đặc biệt tối đa 500 ký tự.` |
| `terms` | `Vui lòng đồng ý điều kiện đặt tour và chính sách hủy.` |

Với 409, trang cập nhật lại theo dữ liệu mới: số chỗ còn lại (`no_seats`), giá và loại vé (`price_changed`, `tickets_changed`), rồi khách xem lại và gửi lại. Lỗi 401, 403, 409, 422 không tạo đơn và không đổi dữ liệu.

## 7. Đối chiếu User Flow đặt tour

| Bước trong User Flow | M4 |
| --- | --- |
| ① Chọn ngày khởi hành, số khách → bấm Đặt tour | Thẻ đặt tour ở trang chi tiết (mục 2, bước 2). |
| ① Đã đăng nhập? Chưa → Đăng nhập / Đăng ký, giữ nguyên tour, ngày, số khách | Link đăng nhập mang lựa chọn trong `next`. |
| ② Còn đủ chỗ? Hết → báo, gợi ý ngày khác | Trang đặt tour chọn lịch khác và báo; B1a báo trước bước xem lại. |
| ② Form đặt tour → Dữ liệu hợp lệ? | Kiểm tra ở trình duyệt và ở server (mục 3, mục 6). |
| ② Xem lại & xác nhận → Giá & chỗ còn đúng? | B1a trước bước xem lại; B1 kiểm tra lại trong transaction (`price_changed`, `no_seats`). |
| ② Hệ thống tạo đơn, trạng thái Chờ xác nhận | `LTP_sp_booking_create`, đơn `pending`. |
| ② Lưu đơn thành công? Không → giữ dữ liệu, cho thử lại | Lỗi mạng / máy chủ: ở lại bước xem lại; `request_token` chống tạo trùng. |
| ③ Quản trị viên xác nhận chỗ & tổng giá | Trang quản trị (Sprint 3), M4 thêm trừ và trả chỗ. |
| ④ Thanh toán & kết quả | M5. |
