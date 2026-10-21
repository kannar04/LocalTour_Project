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

Sprint 3 chỉ có route `GET` (yêu cầu `HEAD` được xử lý như `GET`). Đường dẫn trong bảng tính từ gốc ứng dụng: khi chạy bằng PHP built-in server gốc là `/`; khi chạy trong `htdocs` của XAMPP gốc là `/LocalTour_Project/src/public`. Dấu `/` ở cuối đường dẫn được chấp nhận (`/tours/1/` tương đương `/tours/1`).

| # | Phương thức | Đường dẫn | Controller@action | Đầu vào | Đầu ra |
| --- | --- | --- | --- | --- | --- |
| R1 | GET | `/` và `/tours` | `TourListController@index` | `q` (tùy chọn): điền sẵn ô tìm kiếm.<br>`destination` (tùy chọn): điền sẵn bộ lọc điểm đến. | HTML 200, khung trang `tours/index`. Danh sách tour không render sẵn mà tải bằng AJAX từ R2. |
| R2 | GET | `/api/tours?q=&destination=&sort=` | `TourListController@apiIndex` | `q`, `destination`, `sort` (mục 2) | JSON 200 `{ tours, total }`; 400 khi tham số sai; 503/500 khi lỗi. |
| R3 | GET | `/api/destinations` | `TourListController@apiDestinations` | Không có | JSON 200 `{ destinations }`; 503/500 khi lỗi. |
| R4 | GET | `/tours/{id}` | `TourDetailController@show` | `id` trên đường dẫn (mục 3) | HTML 200 `tours/show`; HTML 404 `tours/not-found` khi ID sai hoặc không tồn tại; trang lỗi 503/500. |
| R5 | GET | `/api/tours/{id}` | `TourDetailController@apiShow` | `id` trên đường dẫn (mục 3) | JSON 200 `{ tour, schedules, itinerary, images, inclusions, reviews }`; 400 khi ID sai; 404 khi không tồn tại; 503/500 khi lỗi. |
| — | Mọi phương thức | Đường dẫn không khớp route nào | `Router` (not found) | — | HTML 404 `errors/404.php`; đường dẫn bắt đầu bằng `/api/` trả JSON 404. |

Ghi chú:

- Trang danh sách (R1) không gọi database. Nếu database mất kết nối, trang vẫn mở được và hiển thị trạng thái lỗi khi AJAX gọi R2 thất bại.
- Liên kết từ danh sách sang chi tiết dùng trường `url` do server tạo trong R2, nên luôn đúng gốc ứng dụng dù chạy bằng Apache hay built-in server.
- Ảnh và file tĩnh trong `public/assets/` do Apache hoặc `public/router.php` trả trực tiếp, không qua router của ứng dụng.

## 2. Tham số của trang và API danh sách

| Tham số | Route | Giá trị hợp lệ | Xử lý khi không hợp lệ |
| --- | --- | --- | --- |
| `q` | R2 | Chuỗi đã bỏ khoảng trắng hai đầu, tối đa 100 ký tự. Rỗng hoặc không gửi = không lọc. Tìm kiểu "có chứa" trên tên tour, mô tả ngắn, tên điểm đến và tên nhà tổ chức, không phân biệt chữ hoa/thường. | Dài hơn 100 ký tự → 400 `Từ khóa tìm kiếm tối đa 100 ký tự.` |
| `q` | R1 | Như trên. | Chuỗi quá dài được cắt còn 100 ký tự khi điền sẵn vào ô tìm kiếm. |
| `destination` | R2 | Rỗng hoặc không gửi = mọi điểm đến. Nếu có giá trị, phải là ID hợp lệ theo mục 3. | Sai định dạng (`0`, `-1`, `abc`, `1.5`…) → 400 `Điểm đến không hợp lệ.` ID đúng định dạng nhưng không tồn tại → 200 với danh sách rỗng. |
| `destination` | R1 | Như trên. | Giá trị sai bị bỏ qua; trang mở với bộ lọc "Tất cả điểm đến". |
| `sort` | R2 | `recommended` (mặc định), `newest`, `price_asc`, `price_desc`. | Rỗng hoặc giá trị lạ không báo lỗi, được xử lý như `recommended`. |

Tham số gửi dạng mảng (ví dụ `?q[]=a`) được xem là rỗng.

Ý nghĩa các kiểu sắp xếp (thực hiện trong `LTP_sp_tour_list`):

| `sort` | Nhãn trên giao diện | Thứ tự |
| --- | --- | --- |
| `recommended` | Tab "Dành cho bạn" | Điểm đánh giá trung bình giảm dần, rồi số đánh giá giảm dần, rồi `tour_id` tăng dần; tour chưa có đánh giá xếp cuối. Chưa cá nhân hóa theo người dùng. |
| `newest` | Tab "Mới nhất" | `created_at` giảm dần, rồi `tour_id` giảm dần. |
| `price_asc` | Ô chọn "Giá": "Thấp đến cao" | `price_per_person` tăng dần; cùng giá thì `tour_id` tăng dần. |
| `price_desc` | Ô chọn "Giá": "Cao đến thấp" | `price_per_person` giảm dần; cùng giá thì `tour_id` tăng dần. |

Từ khóa được tìm đúng nghĩa đen: ký tự `%` và `_` do người dùng nhập không được hiểu là ký tự đại diện của `LIKE`.

## 3. Quy ước ID hợp lệ

ID tour (và ID điểm đến trong tham số `destination`) là số nguyên dương nằm trong miền `INT UNSIGNED` của MySQL:

- Khớp biểu thức chính quy `^[1-9][0-9]{0,9}$`: chỉ gồm chữ số, không bắt đầu bằng `0`, tối đa 10 chữ số.
- Và có giá trị không vượt quá `4294967295`.

Quy tắc được cài đặt một lần trong `Core\Controller::parseId()` và dùng chung cho mọi controller. ID không hợp lệ bị từ chối ngay ở controller, không được gửi xuống database.

| Giá trị `{id}` | Hợp lệ | `/tours/{id}` (HTML) | `/api/tours/{id}` (JSON) | Giải thích |
| --- | --- | --- | --- | --- |
| `1` | Có | 200 trang chi tiết | 200 | Tour tồn tại và đang công khai. |
| `9999` | Có | 404 "Không tìm thấy tour" | 404 `Không tìm thấy tour.` | Đúng định dạng nhưng không có trong database. |
| `4294967295` | Có | 404 | 404 | Giá trị lớn nhất cho phép; không có tour nào mang ID này. |
| `10` (tour đang ẩn trong dữ liệu mẫu) | Có | 404 | 404 | Tour `hidden` hoặc thuộc nhà cung cấp ngừng hoạt động được xử lý như không tồn tại. |
| `0` | Không | 404 | 400 `Mã tour không hợp lệ.` | Không phải số dương. |
| `-1` | Không | 404 | 400 | Có dấu trừ. |
| `abc` | Không | 404 | 400 | Không phải số. |
| `1.5` | Không | 404 | 400 | Số thập phân. |
| `01` | Không | 404 | 400 | Bắt đầu bằng `0`; mỗi tour chỉ có một URL. |
| `+1`, `1e3`, `%201` | Không | 404 | 400 | Có ký tự ngoài chữ số. |
| `4294967296` | Không | 404 | 400 | Vượt giới hạn `INT UNSIGNED`. |
| `99999999999` | Không | 404 | 400 | 11 chữ số. |

Lý do trang HTML trả 404 cho cả ID sai định dạng: với người dùng, cả hai trường hợp đều là "không có tour ở địa chỉ này", nên chỉ cần một thông báo. API tách 400 và 404 để lập trình viên và QA phân biệt lỗi do đầu vào với lỗi do dữ liệu.

Đường dẫn có thêm đoạn phía sau ID (ví dụ `/tours/1/abc`) không khớp route nào và nhận trang 404 chung `errors/404.php`.

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

Các ví dụ dưới đây lấy từ dữ liệu mẫu (`02_seed.sql`), giả sử import ngày 20/10/2026, với gốc ứng dụng `/` (PHP built-in server). Khi chạy trong `htdocs`, các khóa `url`, `cover_image_url`, `image_url` có thêm tiền tố `/LocalTour_Project/src/public`. Chuỗi tiếng Việt trong URL được trình duyệt tự mã hóa.

### 4.1. Danh sách tour – có kết quả (200)

`GET /api/tours?q=món ăn&destination=1&sort=recommended`

```json
{
  "success": true,
  "message": "",
  "data": {
    "tours": [
      {
        "tour_id": 1,
        "title": "Hà Nội qua những món ăn phố cổ",
        "summary": "Đi bộ cùng người địa phương, khám phá món ngon và câu chuyện phố cổ.",
        "url": "/tours/1",
        "destination_id": 1,
        "destination_name": "Hà Nội",
        "category_name": "Tour ẩm thực",
        "provider_name": "Hà Nội Local",
        "provider_verified": true,
        "duration_hours": 4.0,
        "duration_text": "4 giờ",
        "max_group_size": 8,
        "languages": "Tiếng Việt / Anh",
        "price_per_person": 650000,
        "price_text": "650.000đ",
        "meeting_point": "Nhà hát Múa rối Thăng Long",
        "cover_image_url": "/assets/img/tours/hanoi-1.svg",
        "cover_caption": "Phố cổ Hà Nội lúc lên đèn",
        "rating_avg": 4.8,
        "rating_text": "4,8",
        "review_count": 4,
        "next_departure_date": "2026-10-24",
        "next_departure_text": "24/10/2026"
      }
    ],
    "total": 1
  }
}
```

Mỗi tour có cả giá trị gốc (để tính toán, sắp xếp) và chuỗi đã định dạng kết thúc bằng `_text` (để hiển thị thẳng). Các trường có thể `null`: `cover_image_url` (chưa có ảnh), `rating_avg` và `rating_text` (chưa có đánh giá), `next_departure_date` và `next_departure_text` (không còn lịch khởi hành sắp tới).

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
      { "destination_id": 1, "name": "Hà Nội", "slug": "ha-noi", "tour_count": 3 },
      { "destination_id": 2, "name": "Đà Nẵng", "slug": "da-nang", "tour_count": 2 }
    ]
  }
}
```

Điểm đến chưa có tour công khai vẫn có trong danh sách với `tour_count = 0`. Thứ tự theo `sort_order`, rồi theo tên.

### 4.4. Chi tiết tour (200)

`GET /api/tours/1` (rút gọn)

```json
{
  "success": true,
  "message": "",
  "data": {
    "tour": {
      "tour_id": 1,
      "provider_id": 1,
      "destination_id": 1,
      "category_id": 1,
      "title": "Hà Nội qua những món ăn phố cổ",
      "summary": "Đi bộ cùng người địa phương, khám phá món ngon và câu chuyện phố cổ.",
      "description": "Tour đi bộ 4 giờ cùng người dẫn địa phương. Ghé các quán nhỏ, …",
      "duration_hours": "4.0",
      "max_group_size": 8,
      "languages": "Tiếng Việt / Anh",
      "price_per_person": 650000,
      "price_note": "Giá minh họa • VND • Đã gồm thuế, phí",
      "meeting_point": "Nhà hát Múa rối Thăng Long",
      "meeting_note": "Phía phố Đinh Tiên Hoàng, cạnh hồ Hoàn Kiếm. Có mặt trước 10 phút, …",
      "transport_note": "Tour đi bộ, tổng quãng đường khoảng 3 km. Không có xe đưa đón, …",
      "cancellation_policy": "Hủy miễn phí trước giờ khởi hành 24 giờ.",
      "created_at": "2026-06-22 09:00:00",
      "updated_at": "2026-10-20 09:00:00",
      "destination_name": "Hà Nội",
      "category_name": "Tour ẩm thực",
      "provider_name": "Hà Nội Local",
      "provider_description": "Nhóm hướng dẫn viên sinh ra và lớn lên ở phố cổ, chuyên tour đi bộ ẩm thực cho nhóm nhỏ.",
      "provider_verified": 1,
      "rating_avg": "4.8",
      "review_count": 4,
      "url": "/tours/1",
      "price_text": "650.000đ",
      "duration_text": "4 giờ",
      "rating_text": "4,8"
    },
    "schedules": [
      { "schedule_id": 3, "departure_date": "2026-10-24", "start_time": "17:00:00", "seats_left": 6 },
      { "schedule_id": 4, "departure_date": "2026-10-27", "start_time": "17:00:00", "seats_left": 8 }
    ],
    "itinerary": [
      { "start_time": "17:00:00", "description": "Gặp tại Nhà hát Múa rối Thăng Long" },
      { "start_time": "17:15:00", "description": "Đi bộ và thử món ăn tại phố cổ" }
    ],
    "images": [
      { "image_id": 1, "image_path": "assets/img/tours/hanoi-1.svg", "caption": "Phố cổ Hà Nội lúc lên đèn", "image_url": "/assets/img/tours/hanoi-1.svg" }
    ],
    "inclusions": [
      { "item_text": "Người dẫn địa phương", "is_included": 1 },
      { "item_text": "Xe đưa đón", "is_included": 0 }
    ],
    "reviews": [
      { "reviewer_name": "Minh Anh", "rating": 5, "comment": "Nhóm nhỏ, đồ ăn đa dạng. Đi bộ khá nhiều, nên mang giày thoải mái.", "created_at": "2026-10-17 09:00:00" }
    ]
  }
}
```

Khác với `/api/tours`, các mảng trong `/api/tours/{id}` giữ nguyên kiểu dữ liệu MySQL trả về: số nguyên là số (`provider_verified`, `is_included` là `0`/`1`), cột `DECIMAL` (`duration_hours`, `rating_avg`) là chuỗi, ngày giờ là chuỗi. Server bổ sung `url`, `price_text`, `duration_text`, `rating_text` trong `tour` và `image_url` cho từng ảnh. `reviews` chứa tối đa 5 đánh giá mới nhất. Cột `status` của tour không được trả về.

### 4.5. Phản hồi lỗi

Khi lỗi, `success` là `false` và `data` là `null`.

```json
{ "success": false, "message": "Mã tour không hợp lệ.", "data": null }
```

| Tình huống | Ví dụ | HTTP | `message` |
| --- | --- | --- | --- |
| ID tour sai định dạng | `GET /api/tours/abc` | 400 | `Mã tour không hợp lệ.` |
| Điểm đến sai định dạng | `GET /api/tours?destination=abc` | 400 | `Điểm đến không hợp lệ.` |
| Từ khóa quá dài | `q` hơn 100 ký tự | 400 | `Từ khóa tìm kiếm tối đa 100 ký tự.` |
| Tour không tồn tại hoặc đang ẩn | `GET /api/tours/9999` | 404 | `Không tìm thấy tour.` |
| Endpoint không tồn tại | `GET /api/tour` | 404 | `Không tìm thấy đường dẫn API.` |
| Không kết nối được database | MySQL tắt, sai `.env`, mất VPN | 503 | `Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau.` |
| Lỗi máy chủ khác | Thiếu procedure, lỗi SQL, lỗi PHP | 500 | `Hệ thống đang gặp sự cố. Vui lòng thử lại sau.` |

## 5. Mã trạng thái HTTP và thông báo cho người dùng

| Mã | Khi nào | API (`message`) | Trang HTML |
| --- | --- | --- | --- |
| 200 | Thành công, kể cả danh sách rỗng. | `""` hoặc `Không có tour phù hợp.` | Trang bình thường. |
| 400 | Tham số sai định dạng. | Xem bảng 4.5. | Không dùng. Trang chi tiết với ID sai trả 404; tham số sai của trang danh sách bị bỏ qua. |
| 404 | ID đúng định dạng nhưng không có tour công khai; ID sai định dạng (chỉ trang HTML); đường dẫn không có route. | `Không tìm thấy tour.` hoặc `Không tìm thấy đường dẫn API.` | Tour: trang "Không tìm thấy tour" trong layout chính. Đường dẫn lạ: trang "Không tìm thấy trang". |
| 503 | `Core\DatabaseException`: không mở được kết nối MySQL (thời gian chờ tối đa 5 giây). | `Không thể kết nối cơ sở dữ liệu. Vui lòng thử lại sau.` | Trang lỗi "Tạm thời không tải được dữ liệu". |
| 500 | Mọi lỗi khác chưa được xử lý, kể cả cảnh báo/notice của PHP (được chuyển thành exception). | `Hệ thống đang gặp sự cố. Vui lòng thử lại sau.` | Trang lỗi "Đã có lỗi xảy ra". |

## 6. Hành vi của trang HTML theo từng trường hợp

### 6.1. Trang danh sách (`/tours`)

Trang trả HTML 200 ngay, sau đó JavaScript gọi `/api/destinations` (điền bộ lọc và thanh bên) và `/api/tours`. Mỗi lần đổi từ khóa, điểm đến hoặc tab sắp xếp, trang gọi lại `/api/tours` và cập nhật URL bằng `history.replaceState`, không tải lại trang.

| Trạng thái | Điều kiện | Giao diện |
| --- | --- | --- |
| Đang tải | Đang chờ phản hồi `/api/tours`. | Khối `#tour-loading`: 2 thẻ khung xám; dòng số kết quả "Đang tải tour…". |
| Có dữ liệu | HTTP 200, `total > 0`. | Dòng số kết quả và các thẻ tour trong `#tour-feed`, cuối danh sách "Bạn đã xem hết N tour phù hợp.". Nhấn vào thẻ hoặc nút "Xem chi tiết" mở `/tours/{id}`. |
| Rỗng | HTTP 200, `total = 0`. | Khối `#tour-empty`: "Không có tour phù hợp". Khi đang lọc: "Thử từ khóa khác hoặc chọn điểm đến khác nhé." và nút "Xóa bộ lọc"; khi không lọc: "Hiện chưa có tour nào đang mở. Vui lòng quay lại sau." và ẩn nút. |
| Lỗi | HTTP 400, 503, 500, mất mạng hoặc quá 15 giây không phản hồi. | Khối `#tour-error`: "Không tải được danh sách tour", nội dung `message` của API (không nhận được JSON thì dùng "Máy chủ đang bận hoặc mất kết nối. Vui lòng thử lại sau ít phút."; quá thời gian thì "Máy chủ phản hồi quá lâu. Vui lòng thử lại.") và nút "Thử lại". |

Tại mỗi thời điểm chỉ hiện một trong bốn trạng thái.

### 6.2. Trang chi tiết (`/tours/{id}`)

| Trường hợp | HTTP | Giao diện |
| --- | --- | --- |
| ID hợp lệ, tour công khai | 200 | Trang chi tiết đầy đủ, có nút "Quay lại danh sách". |
| Tour không có lịch khởi hành sắp tới | 200 | Ô "Ngày tham gia" hiện "Chưa có lịch khởi hành sắp tới" kèm lời nhắc "Vui lòng quay lại sau."; ô số khách và giờ bắt đầu bị khóa, phần tạm tính hiện "Chưa thể tính". |
| Tour chưa có đánh giá | 200 | Dòng tóm tắt "Chưa có đánh giá"; mục Đánh giá hiện trạng thái rỗng. |
| ID sai định dạng, không tồn tại hoặc tour đang ẩn | 404 | View `tours/not-found` trong layout chính: nhãn "Lỗi 404", tiêu đề "Không tìm thấy tour", "Tour bạn tìm không tồn tại hoặc đã ngừng hiển thị." và nút "Quay lại danh sách tour". ID sai định dạng không cần gọi database nên trang này vẫn hiện được khi database mất kết nối. |
| Mất kết nối database | 503 | `errors/500.php`: "Tạm thời không tải được dữ liệu", thông báo 503 ở mục 5, nút "Thử lại" và "Về bảng tin du lịch". |
| Lỗi khác | 500 | `errors/500.php`: "Đã có lỗi xảy ra", thông báo 500 ở mục 5 và hai nút như trên. |

Trang `errors/404.php` và `errors/500.php` không dùng layout chính và không gọi database, để vẫn hiển thị được khi chính các phần đó gặp lỗi.

### 6.3. Không lộ lỗi PHP cho người dùng

- `src/core/bootstrap.php` tắt `display_errors` khi `APP_DEBUG=false` và chuyển mọi cảnh báo/notice thành exception.
- `src/public/index.php` bắt mọi exception chưa xử lý, ghi log và trả trang lỗi hoặc JSON theo mục 5. Người dùng chỉ thấy thông báo tiếng Việt, không thấy đường dẫn file, câu SQL hay thông tin kết nối.
- Log ghi vào `src/storage/logs/app.log`: thời điểm, loại exception, thông điệp, file và dòng, stack trace, kèm lỗi gốc (ví dụ lỗi PDO bên trong lỗi kết nối). File log đã nằm trong `.gitignore`.
- `APP_DEBUG=true` chỉ dùng trên máy cá nhân khi cần xem chi tiết lỗi ngay trên trang 500. Bản build giao cho QA và buổi demo luôn để `false`.
- Log có thể chứa tên máy chủ hoặc tên database. Khi đính kèm log vào defect, chỉ trích các dòng liên quan.

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
| `LTP_sp_tour_list` | `p_keyword` (`NULL` khi rỗng), `p_destination_id` (`NULL` = tất cả), `p_sort` | `tour_id`, `title`, `summary`, `destination_id`, `destination_name`, `category_name`, `provider_name`, `provider_verified`, `duration_hours`, `max_group_size`, `languages`, `price_per_person`, `meeting_point`, `cover_image`, `cover_caption`, `rating_avg`, `review_count`, `next_departure_date`, `created_at` | `TourListModel::search()` | `TourListController@apiIndex` |
| `LTP_sp_destination_list` | Không có | `destination_id`, `name`, `slug`, `tour_count` | `TourListModel::destinations()` | `TourListController@apiDestinations` |
| `NMT_sp_tour_detail` | `p_tour_id` | 0 hoặc 1 dòng: mọi cột của `tours` trừ `status`, cùng `destination_name`, `category_name`, `provider_name`, `provider_description`, `provider_verified`, `rating_avg`, `review_count` | `TourDetailModel::find()` | `TourDetailController@show`, `@apiShow` |
| `NMT_sp_tour_schedule_list` | `p_tour_id` | `schedule_id`, `departure_date`, `start_time`, `seats_left` | `TourDetailModel::schedules()` | `TourDetailController@show`, `@apiShow` |
| `NMT_sp_tour_itinerary_list` | `p_tour_id` | `start_time`, `description` | `TourDetailModel::itinerary()` | `TourDetailController@show`, `@apiShow` |
| `NTK_sp_tour_image_list` | `p_tour_id` | `image_id`, `image_path`, `caption` | `TourContentModel::images()` | `TourDetailController@show`, `@apiShow` |
| `NTK_sp_tour_inclusion_list` | `p_tour_id` | `item_text`, `is_included` | `TourContentModel::inclusions()` | `TourDetailController@show`, `@apiShow` |
| `NTK_sp_tour_review_list` | `p_tour_id`, `p_limit` (ứng dụng truyền 5) | `reviewer_name`, `rating`, `comment`, `created_at` | `TourContentModel::reviews()` | `TourDetailController@show`, `@apiShow` |

Mọi procedure chỉ trả dữ liệu của tour `published` thuộc nhà cung cấp đang hoạt động, kể cả các procedure danh sách con, nên tour bị ẩn không lộ dữ liệu qua bất kỳ endpoint nào. Điều kiện lọc lịch khởi hành, thứ tự sắp xếp và cách tính các cột tổng hợp được mô tả trong [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md).

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
| Controller | Đọc và kiểm tra tham số, gọi model, chọn view hoặc JSON, chọn mã HTTP, định dạng dữ liệu cho JSON. | Chứa câu SQL; in HTML trực tiếp. |
| Model | Gọi stored procedure qua `Database::call()`, chuẩn hóa tham số (ví dụ `sort` lạ → `recommended`). | Đọc `$_GET`; render giao diện. |
| View | Hiển thị dữ liệu đã nhận; mọi giá trị in ra HTML qua `e()`; dùng `url()`, `asset()` và các hàm `format_*`. | Gọi database; chứa logic nghiệp vụ. |
| JavaScript | Gọi API bằng `$.getJSON`/`$.ajax`, dựng DOM bằng `.text()` hoặc `document.createElement`. | Ghép chuỗi HTML chứa dữ liệu; tự đặt dữ liệu tour cứng trong mã. |

Luồng một yêu cầu:

1. Apache (qua `public/.htaccess`) hoặc built-in server (qua `public/router.php`) chuyển yêu cầu không phải file tĩnh tới `public/index.php`.
2. `core/bootstrap.php` khai báo autoload, đọc `.env`, cấu hình báo lỗi và ghi log.
3. `Router` bỏ phần gốc ứng dụng khỏi URL, so khớp với `routes/web.php` và gọi `Controller@action`.
4. Controller kiểm tra tham số, gọi model; model gọi stored procedure.
5. Controller trả HTML (view trong `layouts/main.php`) hoặc JSON `{ success, message, data }`.
6. Exception chưa xử lý ở bất kỳ bước nào quay về `public/index.php`, được ghi log và chuyển thành phản hồi 503 hoặc 500 theo mục 5.
