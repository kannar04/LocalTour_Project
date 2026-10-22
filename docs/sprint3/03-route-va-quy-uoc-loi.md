# Route, controller, model và quy ước lỗi

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 3 – Technical Design, Coding & QA |
| WBS | 3.1.3 – Chốt route/controller/model và quy ước lỗi |
| Người phụ trách | Lê Trung Phong |
| Thời gian theo kế hoạch | 22–23/10/2026 (1,0 giờ công) |
| Mã nguồn liên quan | `src/routes/web.php`, `src/core/Router.php`, `src/core/Controller.php`, `src/public/index.php`, `src/app/controllers/`, `src/app/models/` |
| Tài liệu liên quan | [01 – Danh mục trường dữ liệu](01-truong-du-lieu.md), [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md), [src/README.md](../../src/README.md) |
| Tiêu chí nghiệm thu | Danh sách route và mô tả input/output, quy ước ID hợp lệ/không hợp lệ được tài liệu hóa. |

## 1. Danh sách route

Sprint 3 chỉ có route `GET` (yêu cầu `HEAD` được xử lý như `GET`). Đường dẫn trong bảng tính từ gốc ứng dụng: khi chạy bằng PHP built-in server gốc là `/`; khi chạy trong `htdocs` của XAMPP gốc là `/LocalTour_Project/src/public`. Dấu `/` ở cuối đường dẫn được chấp nhận (`/tours/{uuid}/` tương đương `/tours/{uuid}`).

Mã tour là UUID (xem mục 3). Trong tài liệu, `{uuid}` của tour 1 trong dữ liệu mẫu là `c0000000-0000-4000-8000-000000000001`.

| # | Phương thức | Đường dẫn | Controller@action | Đầu vào | Đầu ra |
| --- | --- | --- | --- | --- | --- |
| R1 | GET | `/` và `/tours` | `TourListController@index` | `q` (tùy chọn): điền sẵn ô tìm kiếm.<br>`destination` (tùy chọn): tên điểm đến, điền sẵn bộ lọc. | HTML 200, khung trang `tours/index`. Danh sách tour không render sẵn mà tải bằng AJAX từ R2. |
| R2 | GET | `/api/tours?q=&destination=&sort=` | `TourListController@apiIndex` | `q`, `destination`, `sort` (mục 2) | JSON 200 `{ tours, total }`; 400 khi tham số sai; 503/500 khi lỗi. |
| R3 | GET | `/api/destinations` | `TourListController@apiDestinations` | Không có | JSON 200 `{ destinations }`; 503/500 khi lỗi. |
| R4 | GET | `/tours/{uuid}` | `TourDetailController@show` | `uuid` trên đường dẫn (mục 3) | HTML 200 `tours/show`; HTML 404 `tours/not-found` khi UUID sai hoặc không tồn tại; trang lỗi 503/500. |
| R5 | GET | `/api/tours/{uuid}` | `TourDetailController@apiShow` | `uuid` trên đường dẫn (mục 3) | JSON 200 `{ tour, schedules, tickets, itinerary, extras, reviews, policy, gallery }`; 400 khi UUID sai; 404 khi không tồn tại; 503/500 khi lỗi. |
| — | Mọi phương thức | Đường dẫn không khớp route nào | `Router` (not found) | — | HTML 404 `errors/404.php`; đường dẫn bắt đầu bằng `/api/` trả JSON 404. |

Ghi chú:

- Trang danh sách (R1) không gọi database. Nếu database mất kết nối, trang vẫn mở được và hiển thị trạng thái lỗi khi AJAX gọi R2 thất bại.
- Liên kết từ danh sách sang chi tiết dùng trường `url` do server tạo trong R2, nên luôn đúng gốc ứng dụng dù chạy bằng Apache hay built-in server.
- Ảnh và file tĩnh trong `public/assets/` do Apache hoặc `public/router.php` trả trực tiếp, không qua router của ứng dụng.

## 2. Tham số của trang và API danh sách

| Tham số | Route | Giá trị hợp lệ | Xử lý khi không hợp lệ |
| --- | --- | --- | --- |
| `q` | R2 | Chuỗi đã bỏ khoảng trắng hai đầu, tối đa 100 ký tự. Rỗng hoặc không gửi = không lọc. Tìm kiểu "có chứa" trên tên tour, mô tả, điểm đến và tên nhà tổ chức, không phân biệt chữ hoa/thường. | Dài hơn 100 ký tự → 400 `Từ khóa tìm kiếm tối đa 100 ký tự.` |
| `q` | R1 | Như trên. | Chuỗi quá dài được cắt còn 100 ký tự khi điền sẵn vào ô tìm kiếm. |
| `destination` | R2 | Tên điểm đến (ví dụ `Hà Nội`), đã bỏ khoảng trắng hai đầu, tối đa 100 ký tự. Rỗng hoặc không gửi = mọi điểm đến. So khớp nguyên tên với `tours.destination`, không phân biệt chữ hoa/thường và dấu thanh (`ha noi` khớp "Hà Nội", nhưng `d` khác `đ`). | Dài hơn 100 ký tự → 400 `Điểm đến không hợp lệ.` Tên không có trong dữ liệu → 200 với danh sách rỗng. |
| `destination` | R1 | Như trên. | Chuỗi quá dài được cắt còn 100 ký tự. Tên không có trong danh sách điểm đến vẫn được giữ trong ô chọn với số tour là 0. |
| `sort` | R2 | `recommended` (mặc định), `upcoming`, `price_asc`, `price_desc`. | Rỗng hoặc giá trị lạ (kể cả `newest` của bản cũ) không báo lỗi, được xử lý như `recommended`. |

Tham số gửi dạng mảng (ví dụ `?q[]=a`) được xem là rỗng.

Ý nghĩa các kiểu sắp xếp (thực hiện trong `LTP_sp_tour_list`):

| `sort` | Nhãn trên giao diện | Thứ tự |
| --- | --- | --- |
| `recommended` | Tab "Nổi bật" | Tour có đánh giá xếp trước; điểm đánh giá trung bình giảm dần, rồi số đánh giá giảm dần. Tour chưa có đánh giá xếp cuối. Chưa cá nhân hóa theo người dùng. |
| `upcoming` | Tab "Sắp khởi hành" | `next_starts_at` (lần khởi hành gần nhất còn đặt được) tăng dần; tour không có lịch đặt được xếp cuối. |
| `price_asc` | Ô chọn "Giá": "Thấp đến cao" | `from_price_vnd` tăng dần; tour chưa có giá xếp cuối, sau dòng ngăn cách (mục 6.1). |
| `price_desc` | Ô chọn "Giá": "Cao đến thấp" | `from_price_vnd` giảm dần; tour chưa có giá xếp cuối, sau dòng ngăn cách (mục 6.1). |

Mọi kiểu sắp xếp dùng chung bước phân định cuối: tên tour tăng dần, rồi `tour_id`. Từ khóa được tìm đúng nghĩa đen: ký tự `%` và `_` do người dùng nhập không được hiểu là ký tự đại diện của `LIKE`.

## 3. Quy ước ID hợp lệ

Mã tour là UUID dạng chữ, đúng cột `tours.id CHAR(36)`:

- Khớp biểu thức chính quy `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`, không phân biệt chữ hoa/thường: 36 ký tự, gồm 32 ký tự hệ 16 và 4 dấu gạch ngang ở đúng vị trí 8-4-4-4-12.
- UUID hợp lệ được đổi về chữ thường trước khi gửi xuống database.

Quy tắc được cài đặt một lần trong `Core\Controller::parseUuid()` và dùng chung cho mọi controller. UUID không hợp lệ bị từ chối ngay ở controller, không được gửi xuống database. Điểm đến không dùng mã mà dùng tên (mục 2).

| Giá trị `{uuid}` | Hợp lệ | `/tours/{uuid}` (HTML) | `/api/tours/{uuid}` (JSON) | Giải thích |
| --- | --- | --- | --- | --- |
| `c0000000-0000-4000-8000-000000000001` | Có | 200 trang chi tiết | 200 | Tour 1 tồn tại và đang công khai. |
| `C0000000-0000-4000-8000-000000000001` | Có | 200 | 200 | Chữ hoa được chấp nhận và đổi về chữ thường; `url` trong JSON luôn là chữ thường. |
| `c0000000-0000-4000-8000-000000009999` | Có | 404 "Không tìm thấy tour" | 404 `Không tìm thấy tour.` | Đúng định dạng nhưng không có trong database. |
| `00000000-0000-0000-0000-000000000000` | Có | 404 | 404 | Quy tắc chỉ kiểm tra dạng 8-4-4-4-12, không kiểm tra phiên bản UUID. |
| `c0000000-0000-4000-8000-000000000010` (tour 10, chờ duyệt) | Có | 404 | 404 | Tour chưa duyệt, nhà cung cấp chưa duyệt hoặc tài khoản bị khóa được xử lý như không tồn tại. |
| `1`, `9999` | Không | 404 | 400 `Mã tour không hợp lệ.` | ID số nguyên của lược đồ cũ không còn dùng. |
| `abc` | Không | 404 | 400 | Không phải UUID. |
| `c0000000000040008000000000000001` | Không | 404 | 400 | Thiếu dấu gạch ngang. |
| `c0000000-0000-4000-8000-00000000001` | Không | 404 | 400 | Thiếu một ký tự ở nhóm cuối. |
| `g0000000-0000-4000-8000-000000000001` | Không | 404 | 400 | Có ký tự ngoài hệ 16. |
| `{c0000000-0000-4000-8000-000000000001}`, `%20c0000000-…` | Không | 404 | 400 | Có ký tự thừa (ngoặc, khoảng trắng). |

Lý do trang HTML trả 404 cho cả UUID sai định dạng: với người dùng, cả hai trường hợp đều là "không có tour ở địa chỉ này", nên chỉ cần một thông báo. API tách 400 và 404 để lập trình viên và QA phân biệt lỗi do đầu vào với lỗi do dữ liệu.

Đường dẫn có thêm đoạn phía sau UUID (ví dụ `/tours/{uuid}/abc`) không khớp route nào và nhận trang 404 chung `errors/404.php`.

## 4. Hợp đồng phản hồi JSON

Mọi endpoint dưới `/api/` trả cùng một cấu trúc:

```json
{ "success": true, "message": "", "data": {} }
```

| Khóa | Kiểu | Quy ước |
| --- | --- | --- |
| `success` | boolean | `true` khi HTTP 200, `false` với mọi mã lỗi. |
| `message` | string | Câu tiếng Việt có thể hiển thị thẳng cho người dùng. Rỗng khi thành công có dữ liệu. |
| `data` | object hoặc `null` | Dữ liệu khi thành công; luôn `null` khi lỗi. |

Header: `Content-Type: application/json; charset=utf-8` và `Cache-Control: no-store`. Tiếng Việt và dấu `/` được giữ nguyên, không mã hóa thành `\uXXXX` hay `\/`. Phía trình duyệt kiểm tra mã HTTP hoặc `success`, hiển thị `message` và không bao giờ in nguyên văn nội dung phản hồi lỗi ra giao diện.

Các ví dụ dưới đây lấy từ dữ liệu mẫu minh họa (`02_seed.sql`), giả sử import ngày 20/10/2026, với gốc ứng dụng `/` (PHP built-in server). Khi chạy trong `htdocs`, các khóa `url`, `cover_image_url` và `url` của ảnh có thêm tiền tố `/LocalTour_Project/src/public`. Đường dẫn ảnh có thêm `?v=…` (thời điểm sửa file) để trình duyệt không dùng bản cũ. Chuỗi tiếng Việt trong URL được trình duyệt tự mã hóa.

### 4.1. Danh sách tour – có kết quả (200)

`GET /api/tours?q=món ăn&destination=Hà Nội&sort=recommended`

```json
{
  "success": true,
  "message": "",
  "data": {
    "tours": [
      {
        "tour_id": "c0000000-0000-4000-8000-000000000001",
        "title": "Hà Nội qua những món ăn phố cổ",
        "excerpt": "Đi bộ cùng người địa phương, khám phá món ngon và câu chuyện phố cổ.",
        "url": "/tours/c0000000-0000-4000-8000-000000000001",
        "destination": "Hà Nội",
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
        "cover_image_url": "/assets/img/tours/hanoi-1.svg?v=1760000000",
        "cover_caption": "Dãy nhà ống phố cổ Hà Nội lúc chiều tối",
        "rating_avg": 4.8,
        "rating_text": "4,8",
        "review_count": 4,
        "next_starts_at": "2026-10-24 17:00:00",
        "next_departure_text": "24/10/2026 · 17:00"
      }
    ],
    "total": 1
  }
}
```

Mỗi tour có cả giá trị gốc (để tính toán, sắp xếp) và chuỗi đã định dạng kết thúc bằng `_text` (để hiển thị thẳng). `tour_id` là chuỗi UUID. `departure_text` là nơi khởi hành: tên điểm hẹn, "Đón tại khách sạn" hoặc "Chưa cập nhật". Các trường có thể `null`: `from_price_vnd` và `price_text` (không có lịch đặt được), `cover_image_url` (tour chưa có ảnh trong `tour_images`; khi đó `cover_caption` là tên tour), `rating_avg` và `rating_text` (chưa có đánh giá đã duyệt), `next_starts_at` và `next_departure_text` (không còn lịch khởi hành sắp tới), `meeting_point`.

### 4.2. Danh sách tour – không có kết quả (200)

`GET /api/tours?q=lặn biển`

```json
{
  "success": true,
  "message": "Không có tour phù hợp.",
  "data": { "tours": [], "total": 0 }
}
```

Danh sách rỗng không phải lỗi: HTTP vẫn là 200, `success` là `true`. Giao diện dựa vào `total = 0` để hiện trạng thái rỗng.

### 4.3. Danh sách điểm đến (200)

`GET /api/destinations`

```json
{
  "success": true,
  "message": "",
  "data": {
    "destinations": [
      { "name": "Hà Nội", "tour_count": 3 },
      { "name": "Đà Nẵng", "tour_count": 2 }
    ]
  }
}
```

Điểm đến được lấy từ các giá trị khác nhau của `tours.destination` trong số tour công khai, nên chỉ điểm đến có ít nhất một tour công khai mới xuất hiện. Thứ tự: `tour_count` giảm dần, rồi theo tên. Giá trị `name` được gửi lại nguyên văn trong tham số `destination` của R2.

### 4.4. Chi tiết tour (200)

`GET /api/tours/c0000000-0000-4000-8000-000000000001` (rút gọn)

```json
{
  "success": true,
  "message": "",
  "data": {
    "tour": {
      "tour_id": "c0000000-0000-4000-8000-000000000001",
      "provider_id": "b0000000-0000-4000-8000-000000000001",
      "title": "Hà Nội qua những món ăn phố cổ",
      "description": "Đi bộ cùng người địa phương, khám phá món ngon và câu chuyện phố cổ.\n\nTour đi bộ 4 giờ cùng người dẫn địa phương. …",
      "destination": "Hà Nội",
      "duration_minutes": 240,
      "max_group_size": 8,
      "language_codes": "vi,en",
      "pickup_mode": "meeting_point",
      "meeting_point": "Nhà hát Múa rối Thăng Long",
      "included_summary": "Người dẫn địa phương\n5 món ăn\n1 đồ uống",
      "provider_name": "Hà Nội Local",
      "provider_approved_at": "2025-09-17 09:00:00",
      "rating_avg": "4.8",
      "review_count": 4,
      "from_price_vnd": 650000,
      "next_starts_at": "2026-10-24 17:00:00",
      "transport": "Đi bộ (khoảng 3 km)",
      "guide_info": "Người dẫn địa phương nói tiếng Việt và tiếng Anh",
      "dropoff_point": "Khu vực hồ Hoàn Kiếm",
      "excluded_summary": "Đồ uống gọi thêm ngoài 1 đồ uống của tour\nTiền tip cho người dẫn (tùy ý)\nChi phí đi lại đến điểm hẹn",
      "document_terms": "Không yêu cầu giấy tờ tùy thân.",
      "meal_terms": "Gồm 5 món ăn và 1 đồ uống. Báo trước khi đặt nếu ăn chay hoặc dị ứng thực phẩm.",
      "voucher_terms": "Xuất trình mã đặt chỗ (bản điện tử) cho người dẫn tại điểm hẹn.",
      "reschedule_terms": "Đổi sang lịch khác miễn phí nếu báo trước ít nhất 24 giờ và lịch mới còn chỗ.",
      "url": "/tours/c0000000-0000-4000-8000-000000000001",
      "price_text": "650.000đ",
      "duration_text": "4 giờ",
      "languages_text": "Tiếng Việt / Anh",
      "pickup_text": "Gặp tại Nhà hát Múa rối Thăng Long",
      "departure_text": "Nhà hát Múa rối Thăng Long",
      "rating_text": "4,8"
    },
    "schedules": [
      { "schedule_id": "d0000000-0000-4000-8000-000000000003", "starts_at": "2026-10-24 17:00:00", "ends_at": "2026-10-24 21:00:00", "capacity": 8, "remaining": 6, "from_price_vnd": 650000 }
    ],
    "tickets": [
      { "ticket_type_id": "e0000000-0000-4000-8000-000000000031", "schedule_id": "d0000000-0000-4000-8000-000000000003", "name": "adult", "min_age": 12, "max_age": null, "price_vnd": 650000 },
      { "ticket_type_id": "e0000000-0000-4000-8000-000000000032", "schedule_id": "d0000000-0000-4000-8000-000000000003", "name": "child", "min_age": 4, "max_age": 11, "price_vnd": 460000 }
    ],
    "itinerary": [
      { "stop_id": "90000000-0000-4000-8000-000000000002", "stop_order": 1, "title": "Gặp nhau tại Nhà hát Múa rối Thăng Long", "description": "Người dẫn giới thiệu lộ trình và phát nước uống cho cả nhóm.", "duration_minutes": 15 },
      { "stop_id": "90000000-0000-4000-8000-000000000004", "stop_order": 2, "title": "Đi bộ và thử món ăn quanh phố cổ", "description": "Mỗi điểm dừng là một món ăn và một câu chuyện về con phố đó.", "duration_minutes": 75 }
    ],
    "extras": [
      { "extra_id": "c1000000-0000-4000-8000-000000000002", "kind": "surcharge", "name": "Phụ thu đi riêng, không ghép khách", "price_vnd": 500000, "price_unit": "nhóm", "conditions": "Áp dụng khi nhóm muốn đi riêng; tối đa 8 khách.", "sort_order": 1 },
      { "extra_id": "c1000000-0000-4000-8000-000000000001", "kind": "optional", "name": "Thêm phần chè cuối tour", "price_vnd": 35000, "price_unit": "người", "conditions": null, "sort_order": 1 }
    ],
    "reviews": [
      { "review_id": "70000000-0000-4000-8000-000000000004", "reviewer_name": "Minh Anh", "rating": 5, "content": "Nhóm nhỏ, đồ ăn đa dạng. Đi bộ khá nhiều, nên mang giày thoải mái.", "tour_date": "2026-10-16 17:00:00" }
    ],
    "policy": { "policy_id": "f0000000-0000-4000-8000-000000000011", "free_before_hours": 24, "refund_percent": 0, "terms": "Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ. Hủy sau mốc này không được hoàn tiền.", "version": 1 },
    "gallery": [
      { "url": "/assets/img/tours/hanoi-1.svg?v=1760000000", "caption": "Dãy nhà ống phố cổ Hà Nội lúc chiều tối" }
    ]
  }
}
```

Khác với `/api/tours`, các mảng trong `/api/tours/{uuid}` giữ nguyên kiểu dữ liệu MySQL trả về: số nguyên là số, cột `DECIMAL` (`rating_avg`) là chuỗi, ngày giờ là chuỗi `YYYY-MM-DD HH:MM:SS`, UUID là chuỗi. Server bổ sung `url`, `price_text`, `duration_text`, `languages_text`, `pickup_text`, `departure_text`, `rating_text` trong `tour`.

- `tour`: 8 trường từ `transport` đến `reschedule_terms` có thể `null` → giao diện hiện "Chưa cập nhật". `excluded_summary` mỗi dòng một mục, giống `included_summary`.
- `schedules`: chỉ lịch còn đặt được, sắp theo `starts_at`; `from_price_vnd` là giá thấp nhất của lịch đó.
- `tickets`: vé đang bán của các lịch trong `schedules`; giao diện lọc theo `schedule_id` của lịch đang chọn.
- `itinerary`: các điểm lịch trình của tour theo `stop_order`; `description`, `duration_minutes` có thể `null`. Mảng rỗng → giao diện hiện "Chưa cập nhật".
- `extras`: phụ thu (`surcharge`) trước, rồi hoạt động tùy chọn (`optional`), mỗi loại theo `sort_order`. `price_vnd`, `price_unit`, `conditions` có thể `null`. Giá tách riêng, không cộng vào `from_price_vnd` hay phần tạm tính. Mảng rỗng → "Chưa cập nhật".
- `gallery`: ảnh của chính tour trong `tour_images`, theo `sort_order`. Mỗi phần tử `{ url, caption }`: `url` đã sẵn sàng để dùng (đường dẫn tương đối được đổi qua `asset()`, link `http(s)://` giữ nguyên), `caption` là `alt_text`, rỗng thì là tên tour. Mảng rỗng → ô xám "Chưa cập nhật ảnh".
- `reviews`: tối đa 5 đánh giá đã duyệt, chuyến đi gần nhất trước; `reviewer_name` là tên liên hệ của đơn đặt (khách không có tài khoản).
- `policy`: phiên bản chính sách hủy lớn nhất; `null` nếu tour chưa có chính sách.
- Cột trạng thái (`approval_status`, `status`, `active`, `moderation_status`) không được trả về.

### 4.5. Phản hồi lỗi

Khi lỗi, `success` là `false` và `data` là `null`.

```json
{ "success": false, "message": "Mã tour không hợp lệ.", "data": null }
```

| Tình huống | Ví dụ | HTTP | `message` |
| --- | --- | --- | --- |
| Mã tour sai định dạng | `GET /api/tours/1`, `GET /api/tours/abc` | 400 | `Mã tour không hợp lệ.` |
| Điểm đến quá dài | `destination` hơn 100 ký tự | 400 | `Điểm đến không hợp lệ.` |
| Từ khóa quá dài | `q` hơn 100 ký tự | 400 | `Từ khóa tìm kiếm tối đa 100 ký tự.` |
| Tour không tồn tại hoặc không công khai | `GET /api/tours/c0000000-0000-4000-8000-000000009999` | 404 | `Không tìm thấy tour.` |
| Endpoint không tồn tại | `GET /api/tour` | 404 | `Không tìm thấy đường dẫn API.` |
| Không kết nối được database | MySQL tắt, sai `.env`, mất VPN | 503 | `Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau.` |
| Lỗi máy chủ khác | Thiếu procedure, lỗi SQL, lỗi PHP | 500 | `Hệ thống đang gặp sự cố. Vui lòng thử lại sau.` |

## 5. Mã trạng thái HTTP và thông báo cho người dùng

| Mã | Khi nào | API (`message`) | Trang HTML |
| --- | --- | --- | --- |
| 200 | Thành công, kể cả danh sách rỗng. | `""` hoặc `Không có tour phù hợp.` | Trang bình thường. |
| 400 | Tham số sai định dạng. | Xem bảng 4.5. | Không dùng. Trang chi tiết với UUID sai trả 404; tham số sai của trang danh sách bị bỏ qua hoặc cắt ngắn. |
| 404 | UUID đúng định dạng nhưng không có tour công khai; UUID sai định dạng (chỉ trang HTML); đường dẫn không có route. | `Không tìm thấy tour.` hoặc `Không tìm thấy đường dẫn API.` | Tour: trang "Không tìm thấy tour" trong layout chính. Đường dẫn lạ: trang "Không tìm thấy trang". |
| 503 | `Core\DatabaseException`: không mở được kết nối MySQL (thời gian chờ tối đa 5 giây). | `Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau.` | Trang lỗi "Tạm thời không tải được dữ liệu". |
| 500 | Mọi lỗi khác chưa được xử lý, kể cả cảnh báo/notice của PHP (được chuyển thành exception). | `Hệ thống đang gặp sự cố. Vui lòng thử lại sau.` | Trang lỗi "Đã có lỗi xảy ra". |

## 6. Hành vi của trang HTML theo từng trường hợp

### 6.1. Trang danh sách (`/tours`)

Trang trả HTML 200 ngay, sau đó JavaScript gọi `/api/destinations` (điền bộ lọc và thanh bên) và `/api/tours`. Mỗi lần đổi từ khóa, điểm đến hoặc tab sắp xếp, trang gọi lại `/api/tours` và cập nhật URL bằng `history.replaceState`, không tải lại trang.

| Trạng thái | Điều kiện | Giao diện |
| --- | --- | --- |
| Đang tải | Đang chờ phản hồi `/api/tours`. | Khối `#tour-loading`: 2 thẻ khung xám; dòng số kết quả "Đang tải tour…". |
| Có dữ liệu | HTTP 200, `total > 0`. | Dòng số kết quả và các thẻ tour trong `#tour-feed`, cuối danh sách "Bạn đã xem hết N tour phù hợp.". Nhấn vào thẻ hoặc nút "Xem chi tiết" mở `/tours/{uuid}`. |
| Rỗng | HTTP 200, `total = 0`. | Khối `#tour-empty`: "Không có tour phù hợp". Khi đang lọc: "Thử từ khóa khác hoặc chọn điểm đến khác nhé." và nút "Xóa bộ lọc"; khi không lọc: "Hiện chưa có tour nào đang mở. Vui lòng quay lại sau." và ẩn nút. |
| Lỗi | HTTP 400, 503, 500, mất mạng hoặc quá 15 giây không phản hồi. | Khối `#tour-error`: "Không tải được danh sách tour", nội dung `message` của API (không nhận được JSON thì dùng "Máy chủ đang bận hoặc mất kết nối. Vui lòng thử lại sau ít phút."; quá thời gian thì "Máy chủ phản hồi quá lâu. Vui lòng thử lại.") và nút "Thử lại". |

Tại mỗi thời điểm chỉ hiện một trong bốn trạng thái.

Khi sắp theo giá (`price_asc`, `price_desc`) và danh sách có tour chưa có giá, một dòng ngăn cách được chèn ngay trước tour chưa có giá đầu tiên: "Các tour dưới đây chưa cập nhật giá nên không được xếp theo giá." Hai kiểu sắp xếp còn lại không có dòng này. Thẻ của tour chưa có giá hiện "Giá: Chưa cập nhật".

### 6.2. Trang chi tiết (`/tours/{uuid}`)

| Trường hợp | HTTP | Giao diện |
| --- | --- | --- |
| UUID hợp lệ, tour công khai | 200 | Trang chi tiết đầy đủ, có nút "Quay lại danh sách". |
| Tour không có lịch khởi hành đặt được | 200 | Giá hiện "Giá: Chưa cập nhật"; tab "Lịch khởi hành" và ô chọn lịch hiện "Chưa có lịch khởi hành sắp tới" kèm lời nhắc "Vui lòng quay lại sau."; các dòng vé bị khóa, dòng "Tạm tính tiền vé" hiện "Chưa thể tính". |
| Tour chưa có đánh giá đã duyệt | 200 | Dòng tóm tắt "Chưa có đánh giá"; mục Đánh giá hiện trạng thái rỗng. |
| Tour thiếu ảnh, lịch trình, phụ thu / tùy chọn hoặc một số thông tin | 200 | Thư viện ảnh là ô xám "Chưa cập nhật ảnh"; mục Lịch trình, Phụ thu / hoạt động tùy chọn và các trường thiếu dữ liệu hiện "Chưa cập nhật" (xem mục 6.4). |
| Chức năng chưa làm | 200 | Nút "Đặt tour" và "Thêm vào so sánh" bị khóa, có nhãn "Sắp có". Không có nút Lưu tour, Chia sẻ, Nhắn tin. |
| UUID sai định dạng, không tồn tại hoặc tour không công khai | 404 | View `tours/not-found` trong layout chính: nhãn "Lỗi 404", tiêu đề "Không tìm thấy tour", "Tour bạn tìm không tồn tại hoặc đã ngừng hiển thị." và nút "Quay lại danh sách tour". UUID sai định dạng không cần gọi database nên trang này vẫn hiện được khi database mất kết nối. |
| Mất kết nối database | 503 | `errors/500.php`: "Tạm thời không tải được dữ liệu", thông báo 503 ở mục 5, nút "Thử lại" và "Về bảng tin du lịch". |
| Lỗi khác | 500 | `errors/500.php`: "Đã có lỗi xảy ra", thông báo 500 ở mục 5 và hai nút như trên. |

Trang `errors/404.php` và `errors/500.php` không dùng layout chính và không gọi database, để vẫn hiển thị được khi chính các phần đó gặp lỗi.

### 6.3. Không lộ lỗi PHP cho người dùng

- `src/core/bootstrap.php` tắt `display_errors` khi `APP_DEBUG=false` và chuyển mọi cảnh báo/notice thành exception.
- `src/public/index.php` bắt mọi exception chưa xử lý, ghi log và trả trang lỗi hoặc JSON theo mục 5. Người dùng chỉ thấy thông báo tiếng Việt, không thấy đường dẫn file, câu SQL hay thông tin kết nối.
- Log ghi vào `src/storage/logs/app.log`: thời điểm, loại exception, thông điệp, file và dòng, stack trace, kèm lỗi gốc (ví dụ lỗi PDO bên trong lỗi kết nối). File log đã nằm trong `.gitignore`.
- `APP_DEBUG=true` chỉ dùng trên máy cá nhân khi cần xem chi tiết lỗi ngay trên trang 500. Bản build giao cho QA và buổi demo luôn để `false`.
- Log có thể chứa tên máy chủ hoặc tên database. Khi đính kèm log vào defect, chỉ trích các dòng liên quan.

### 6.4. Ca kiểm thử theo bảng FR

Các ca dưới đây dùng dữ liệu mẫu minh họa (`02_seed.sql`). Kết quả được mô tả theo quy tắc, không ghi số cụ thể, vì ngày giờ của dữ liệu mẫu tính theo lúc import.

| # | Ca kiểm thử | Cách làm | Kết quả mong đợi |
| --- | --- | --- | --- |
| TC-01 | Lịch trình đúng thứ tự (FR-03) | Mở chi tiết một tour có lịch trình, ví dụ tour 1. | Các điểm hiện theo `stop_order` 1, 2, 3…, dù dữ liệu mẫu chèn các dòng không theo thứ tự. Thứ tự trên trang, trong `itinerary` của `/api/tours/{uuid}` và khi `CALL NTK_sp_tour_itinerary_list` giống nhau. |
| TC-02 | Điểm lịch trình thiếu dữ liệu (FR-03) | Tìm điểm có `description` hoặc `duration_minutes` là `NULL`. | Điểm đó không hiện dòng mô tả hoặc thời gian (không có "0 phút", không có dòng trống); các điểm khác vẫn hiện đủ. |
| TC-03 | Trường thiếu hiện "Chưa cập nhật" (FR-02, FR-04, FR-05) | Mở chi tiết tour 3, 5, 7 và 9. | Tour 3: Điểm trả, Voucher. Tour 5: Không bao gồm. Tour 7: Hướng dẫn viên, Đổi lịch. Tour 9: Điểm trả, Phương tiện, Hướng dẫn viên, Không bao gồm, Giấy tờ, Ăn uống, Voucher, Đổi lịch và Phụ thu / hoạt động tùy chọn. Đúng các dòng đó hiện "Chưa cập nhật"; các dòng khác của cùng tour có nội dung. Không giá trị nào được lấy từ tour khác hay tự suy ra. |
| TC-04 | Nơi khởi hành (FR-01) | Xem thẻ tour ở danh sách. | Tour `hotel_pickup` hiện "Đón tại khách sạn"; tour khác hiện tên điểm hẹn; tour không ghi điểm hẹn hiện "Chưa cập nhật". |
| TC-05 | Tour không có ảnh (FR-01, FR-02) | Tour 9 (`c0000000-0000-4000-8000-000000000009`); tour 2 cũng không có ảnh nhưng có lịch trình. | Thẻ ở danh sách là ô xám "Chưa cập nhật ảnh", `cover_image_url = null`, `cover_caption` là tên tour. Trang chi tiết: thư viện ảnh ô xám, mục Lịch trình "Chưa cập nhật"; `/api/tours/{uuid}` có `gallery: []` và `itinerary: []`. Không hiện ảnh của tour khác cùng điểm đến. |
| TC-06 | Không dùng chung ảnh (FR-02) | So sánh `gallery` của các tour công khai. | Không đường dẫn ảnh nào xuất hiện ở hai tour. Tour không có ảnh riêng hiện "Chưa cập nhật ảnh". |
| TC-07 | Dòng ngăn cách khi sắp theo giá (FR-06) | Ở `/tours`, chọn Giá "Thấp đến cao", rồi "Cao đến thấp". Lặp lại khi lọc từng điểm đến. | Tour có giá xếp đúng chiều giá. Ngay trước tour 9 có dòng "Các tour dưới đây chưa cập nhật giá nên không được xếp theo giá." Tab "Nổi bật", "Sắp khởi hành" và kết quả lọc mà mọi tour đều có giá thì không có dòng này. |
| TC-08 | Giá có đơn vị (FR-10) | Xem giá trên thẻ và thẻ giá ở trang chi tiết. | Tour có lịch: "Từ … / người lớn". Tour 9: "Giá: Chưa cập nhật". |
| TC-09 | Ảnh, lịch trình, phụ thu của tour ẩn không bị lộ (BR-01) | Tour 10 (`c0000000-0000-4000-8000-000000000010`, chờ duyệt, có ảnh, lịch trình và 2 phụ thu / tùy chọn trong dữ liệu mẫu). | `CALL NMT_sp_tour_image_list(...)`, `CALL NTK_sp_tour_itinerary_list(...)` và `CALL NTK_sp_tour_extra_list(...)` với UUID tour 10 trả 0 dòng; `/api/tours/{uuid tour 10}` trả 404. Ảnh, tên điểm lịch trình và "Thuê xe đạp đôi" của tour 10 không xuất hiện ở tour nào trong `/api/tours` hay trang chi tiết. |
| TC-10 | Phụ thu / tùy chọn đúng nhóm và thứ tự (FR-04) | Mở chi tiết tour 1, 3, 4, 5. | Có ghi chú "Tính riêng, không cộng vào giá tour và phần tạm tính."; nhóm "Phụ thu" trước "Hoạt động tùy chọn". Tour 1: "Phụ thu đi riêng, không ghép khách" đứng trong nhóm Phụ thu dù được chèn sau tùy chọn. Tour 3: "Phụ thu người dẫn nói tiếng Pháp", rồi "Thêm 30 phút xích lô", "Chụp ảnh cùng nhiếp ảnh gia". Tour 4 chỉ có phụ thu ("Phụ thu đón ngoài khu trung tâm" trước "Phụ thu ngày lễ"), nhóm tùy chọn hiện "Chưa cập nhật"; tour 5 ngược lại. Thứ tự trên trang, trong `extras` của API và khi `CALL NTK_sp_tour_extra_list` giống nhau. |
| TC-11 | Phụ thu / tùy chọn thiếu giá hoặc điều kiện (FR-04, FR-10) | Tour 4 "Phụ thu ngày lễ", tour 8 "Thêm điểm dừng ở quán bar trên cao"; tour 2 và 9 không có dòng nào. | Giá `NULL` → "Giá: Chưa cập nhật" (không hiện "0đ"); có giá và đơn vị → dạng "500.000đ / nhóm"; thiếu điều kiện → không có dòng điều kiện. Tour 2, 9: cả mục hiện "Chưa cập nhật". |
| TC-12 | Phụ thu / tùy chọn có giá nhưng thiếu đơn vị (FR-10) | Tour 6, dòng "Thuê áo dài chụp ảnh" (`price_unit` là `NULL`). | Giá hiện "120.000đ · đơn vị chưa cập nhật"; không bị hiểu nhầm là giá theo người hay theo nhóm. |
| TC-13 | "Tạm tính tiền vé" không gồm phụ thu (FR-10) | Tour 1: chọn lịch và số vé ở thẻ giá; so với giá trên thẻ ở danh sách. | Dòng tổng có nhãn "Tạm tính tiền vé" và ghi chú "Chưa gồm phụ thu và hoạt động tùy chọn". Số tiền chỉ là số lượng × giá vé; giá "Từ" vẫn 650.000đ; không khoản phụ thu hay tùy chọn nào được cộng. |
| TC-14 | Không có chức năng cần tài khoản (bảng FR: khách không cần tài khoản) | Xem header, thanh bên, tab, thẻ tour ở `/tours` và trang chi tiết. | Không có nút Thông báo, ảnh đại diện, mục Tour đã lưu, Đặt chỗ của tôi, Cộng đồng, Tin nhắn, tab Đang theo dõi, hàng Thích/Bình luận/Chia sẻ/Lưu, nút Lưu tour, Chia sẻ, Nhắn tin. "So sánh tour" / "Thêm vào so sánh" vẫn còn nhưng bị khóa, có nhãn "Sắp có" (FR-15). |

## 7. Ánh xạ stored procedure – model – controller

Ứng dụng chỉ truy cập dữ liệu qua `Core\Database::call()`, hàm này thực thi `CALL <procedure>(?, …)` bằng PDO với tham số ràng buộc. PHP không chứa câu `SELECT`, `INSERT`, `UPDATE` hay `DELETE`.

Tên procedure theo mẫu `<TIỀN TỐ>_sp_<tên_chữ_thường>`, tiền tố là người phụ trách:

| Tiền tố | Người phụ trách | File SQL |
| --- | --- | --- |
| `LTP_` | Lê Trung Phong | `src/database/03_procedures_LTP.sql` |
| `NMT_` | Nguyễn Minh Thức | `src/database/04_procedures_NMT.sql` |
| `NTK_` | Nguyễn Tuấn Khôi | `src/database/05_procedures_NTK.sql` |

`Database::call()` từ chối tên không khớp mẫu `^(NTK|LTP|NMT)_sp_[a-z0-9_]+$` (lỗi 500), nên tên procedure không thể bị ghép từ dữ liệu người dùng.

| Procedure | Tham số | Cột trả về | Model | Controller@action |
| --- | --- | --- | --- | --- |
| `LTP_sp_tour_list` | `p_keyword VARCHAR(100)` (`NULL` khi rỗng), `p_destination VARCHAR(100)` (`NULL` = tất cả), `p_sort VARCHAR(20)` | `tour_id`, `title`, `description`, `destination`, `provider_name`, `duration_minutes`, `max_group_size`, `language_codes`, `pickup_mode`, `meeting_point`, `from_price_vnd`, `rating_avg`, `review_count`, `next_starts_at`, `cover_image_url`, `cover_alt_text` | `TourListModel::search()` | `TourListController@apiIndex` |
| `LTP_sp_destination_list` | Không có | `destination`, `tour_count` | `TourListModel::destinations()` | `TourListController@apiDestinations` |
| `NMT_sp_tour_detail` | `p_tour_id CHAR(36)` | 0 hoặc 1 dòng: `tour_id`, `provider_id`, `title`, `description`, `destination`, `duration_minutes`, `max_group_size`, `language_codes`, `pickup_mode`, `meeting_point`, `included_summary`, `provider_name`, `provider_approved_at`, `rating_avg`, `review_count`, `from_price_vnd`, `next_starts_at`, `transport`, `guide_info`, `dropoff_point`, `excluded_summary`, `document_terms`, `meal_terms`, `voucher_terms`, `reschedule_terms` | `TourDetailModel::find()` | `TourDetailController@show`, `@apiShow` |
| `NMT_sp_tour_schedule_list` | `p_tour_id CHAR(36)` | `schedule_id`, `starts_at`, `ends_at`, `capacity`, `remaining`, `from_price_vnd` | `TourDetailModel::schedules()` | `TourDetailController@show`, `@apiShow` |
| `NMT_sp_tour_ticket_list` | `p_tour_id CHAR(36)` | `ticket_type_id`, `schedule_id`, `name`, `min_age`, `max_age`, `price_vnd` | `TourDetailModel::tickets()` | `TourDetailController@show`, `@apiShow` |
| `NMT_sp_tour_image_list` | `p_tour_id CHAR(36)` | `image_id`, `url`, `alt_text`, `sort_order` | `TourDetailModel::images()` | `TourDetailController@show`, `@apiShow` |
| `NTK_sp_tour_itinerary_list` | `p_tour_id CHAR(36)` | `stop_id`, `stop_order`, `title`, `description`, `duration_minutes` | `TourContentModel::itinerary()` | `TourDetailController@show`, `@apiShow` |
| `NTK_sp_tour_extra_list` | `p_tour_id CHAR(36)` | `extra_id`, `kind`, `name`, `price_vnd`, `price_unit`, `conditions`, `sort_order` (phụ thu trước) | `TourContentModel::extras()` | `TourDetailController@show`, `@apiShow` |
| `NTK_sp_tour_review_list` | `p_tour_id CHAR(36)`, `p_limit TINYINT UNSIGNED` (ứng dụng truyền 5) | `review_id`, `reviewer_name` (`bookings.contact_name`), `rating`, `content`, `tour_date` | `TourContentModel::reviews()` | `TourDetailController@show`, `@apiShow` |
| `NTK_sp_tour_cancellation_policy` | `p_tour_id CHAR(36)` | 0 hoặc 1 dòng: `policy_id`, `free_before_hours`, `refund_percent`, `terms`, `version` | `TourContentModel::cancellationPolicy()` | `TourDetailController@show`, `@apiShow` |

Mọi procedure chỉ trả dữ liệu của tour công khai (tour `approved`, nhà cung cấp `approved`, tài khoản nhà cung cấp `active`), kể cả các procedure danh sách con, nên tour không công khai không lộ dữ liệu qua bất kỳ endpoint nào. Điều kiện lịch còn đặt được, thứ tự sắp xếp và cách tính các cột tổng hợp được mô tả trong [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md). Ảnh tour lấy từ bảng `tour_images` của chính tour; hàm `tour_gallery()` (ảnh dùng chung theo điểm đến) đã bỏ. Phụ thu / tùy chọn lấy từ `tour_extras`, chỉ để hiển thị, không tham gia tính giá.

## 8. Cấu trúc MVC

```text
src/
├── public/            # Thư mục web duy nhất được truy cập từ trình duyệt
│   ├── index.php      # Front controller: nạp bootstrap, chạy router, bắt lỗi
│   ├── router.php     # Router cho PHP built-in server
│   └── assets/        # CSS, JS, ảnh minh họa
├── routes/web.php     # Khai báo route → Controller@action
├── core/              # Router, Controller, Database, Env, helpers, bootstrap
├── config/            # app.php, database.php (đọc giá trị từ .env)
├── app/
│   ├── controllers/   # TourListController, TourDetailController
│   ├── models/        # TourListModel, TourDetailModel, TourContentModel
│   └── views/         # layouts/, partials/, tours/, errors/
├── database/          # 01_schema … 05_procedures_NTK
└── storage/logs/      # app.log (không đưa lên Git)
```

Trách nhiệm từng lớp:

| Lớp | Được làm | Không được làm |
| --- | --- | --- |
| Controller | Đọc và kiểm tra tham số (`parseUuid()`, độ dài chuỗi), gọi model, chọn view hoặc JSON, chọn mã HTTP, định dạng dữ liệu cho JSON. | Chứa câu SQL; in HTML trực tiếp. |
| Model | Gọi stored procedure qua `Database::call()`, chuẩn hóa tham số (ví dụ `sort` lạ → `recommended`, chuỗi rỗng → `NULL`). | Đọc `$_GET`; render giao diện. |
| View | Hiển thị dữ liệu đã nhận; mọi giá trị in ra HTML qua `e()`; dùng `url()`, `asset()` và các hàm `format_*`. | Gọi database; chứa logic nghiệp vụ. |
| JavaScript | Gọi API bằng `$.getJSON`/`$.ajax`, dựng DOM bằng `.text()` hoặc `document.createElement`. | Ghép chuỗi HTML chứa dữ liệu; tự đặt dữ liệu tour cứng trong mã. |

Luồng một yêu cầu:

1. Apache (qua `public/.htaccess`) hoặc built-in server (qua `public/router.php`) chuyển yêu cầu không phải file tĩnh tới `public/index.php`.
2. `core/bootstrap.php` khai báo autoload, đọc `.env`, cấu hình báo lỗi và ghi log.
3. `Router` bỏ phần gốc ứng dụng khỏi URL, so khớp với `routes/web.php` và gọi `Controller@action`.
4. Controller kiểm tra tham số, gọi model; model gọi stored procedure.
5. Controller trả HTML (view trong `layouts/main.php`) hoặc JSON `{ success, message, data }`.
6. Exception chưa xử lý ở bất kỳ bước nào quay về `public/index.php`, được ghi log và chuyển thành phản hồi 503 hoặc 500 theo mục 5.
