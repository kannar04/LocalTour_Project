# Danh mục trường dữ liệu – Tour List và Tour Detail

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 3 – Technical Design, Coding & QA |
| WBS | 3.1.1 – Rà soát yêu cầu Tour List/Detail; chốt trường dữ liệu |
| Người phụ trách | Lê Trung Phong |
| Thời gian theo kế hoạch | 22/10/2026 (0,5 giờ công) |
| Căn cứ | SRS v0.1 ngày 14/10/2026 (yêu cầu đã thống nhất ở Sprint 2), wireframe UIEx1 (Bảng tin) và UIEx2 (Chi tiết tour), Kế hoạch Sprint 3 |
| Tài liệu liên quan | [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md), [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md) |
| Tiêu chí nghiệm thu | Danh mục field Tour List/Detail được đối chiếu với yêu cầu Sprint 2, có ghi quyết định những gì thuộc/không thuộc Sprint 3. |

## 1. Mục đích và cách đọc

Tài liệu chốt các trường dữ liệu mà hai màn hình của Increment v0.1 hiển thị, nguồn của từng trường và yêu cầu SRS mà trường đó đáp ứng. Đây là hợp đồng dữ liệu chung giữa database (Thức), backend (Phong, Thức) và giao diện (Khôi). QA (Hải, Thành) dùng tài liệu này để viết test case và kiểm tra tính nhất quán SRS – UI – DB – routes.

- **Nguồn**: `bảng.cột` trong database `db_localtour`, hoặc *tính toán* khi giá trị do stored procedure, PHP hay JavaScript tạo ra và không lưu trong bảng.
- **Khóa JSON**: tên trường trong phản hồi `GET /api/tours` (danh sách). Trang chi tiết dùng tên cột của procedure tương ứng.
- **SRS**: mã yêu cầu trong SRS v0.1.
- Mọi trường hiển thị đều lấy từ database qua stored procedure; giao diện không chứa dữ liệu tour viết cứng.

## 2. Tour List – màn hình Bảng tin (UIEx1)

Route `GET /tours`. Khung trang render từ server, danh sách tour tải bằng AJAX từ `GET /api/tours` (procedure `LTP_sp_tour_list`). Chỉ tour `published` của nhà cung cấp đang hoạt động được trả về (BR-01).

### 2.1. Trường trên thẻ tour

| Mã | Trường | Khóa JSON | Nguồn | SRS | Vị trí trên giao diện |
| --- | --- | --- | --- | --- | --- |
| L01 | Mã tour, liên kết chi tiết | `tour_id`, `url` | `tours.tour_id`; `url` do PHP tạo bằng `url('/tours/{id}')` | FR-06, FR-07 | Không hiển thị. Bấm vào bất kỳ đâu trên thẻ, tiêu đề hoặc nút "Xem chi tiết" đều mở `url`. |
| L02 | Tên tour | `title` | `tours.title` | FR-06 (tên tour) | Tiêu đề thẻ. |
| L03 | Mô tả ngắn | `summary` | `tours.summary` | FR-06 | Đoạn dưới tiêu đề. |
| L04 | Nhà tổ chức | `provider_name` | `providers.name` | FR-07 (thông tin nhà cung cấp) | Đầu thẻ, cạnh ô chữ cái đầu: tên nhà tổ chức và nhãn "Người tổ chức". |
| L05 | Đã xác minh | `provider_verified` | `providers.is_verified` | FR-07 | Dấu tick cạnh tên nhà tổ chức. |
| L06 | Điểm đến | `destination_id`, `destination_name` | `tours.destination_id`, `destinations.name` | FR-06 (địa điểm) | Dòng phụ dưới tên nhà tổ chức ("{loại hình} · {điểm đến}") và nhãn ở góc ảnh. |
| L07 | Loại hình | `category_name` | `categories.name` | FR-05 (loại hình) | Dòng phụ dưới tên nhà tổ chức, đứng trước điểm đến. |
| L08 | Ảnh đại diện | `cover_image_url`, `cover_caption` | *Tính toán*: `tour_images.image_path` và `caption` của ảnh có `sort_order` nhỏ nhất; PHP đổi đường dẫn thành URL; thiếu chú thích thì dùng tên tour | FR-06 (hình ảnh) | Khung ảnh giữa thẻ. Không có ảnh hoặc ảnh tải lỗi → ô xám có biểu tượng ảnh và chú thích. |
| L09 | Điểm đánh giá | `rating_avg`, `rating_text` | *Tính toán*: trung bình `reviews.rating`, làm tròn 1 chữ số | FR-06 (đánh giá nếu có) | Hàng thông tin nhanh dưới ảnh: "4,8/5 (4 đánh giá)". `null` → "Chưa có đánh giá". |
| L10 | Số đánh giá | `review_count` | *Tính toán*: số dòng `reviews` của tour | FR-06 | Cùng mục với điểm đánh giá. |
| L11 | Thời lượng | `duration_hours`, `duration_text` | `tours.duration_hours` | FR-06 (thời lượng) | Hàng thông tin nhanh: "4 giờ". |
| L12 | Điểm gặp | `meeting_point` | `tours.meeting_point` | FR-07 (điểm đón) | Hàng thông tin nhanh: "Gặp tại …". |
| L13 | Giá tham khảo | `price_per_person`, `price_text` | `tours.price_per_person` (VND) | FR-06 (giá tham khảo), FR-08 | "Từ 650.000đ / người", cạnh nút "Xem chi tiết". |
| L14 | Ngày khởi hành gần nhất | `next_departure_date`, `next_departure_text` | *Tính toán*: ngày sớm nhất trong `tour_schedules` có `status = 'open'`, `departure_date ≥ CURDATE()` và còn chỗ | FR-06 (tình trạng tour nếu có dữ liệu), FR-09 | Hàng thông tin nhanh: "Khởi hành 24/10/2026". `null` → "Chưa có lịch khởi hành". |
| L15 | Nhóm tối đa | `max_group_size` | `tours.max_group_size` | FR-07 | Có trong JSON nhưng thẻ không hiển thị (wireframe không có); hiển thị ở trang chi tiết (D09). |
| L16 | Ngôn ngữ | `languages` | `tours.languages` | FR-07 | Như L15; hiển thị ở trang chi tiết (D10). |

`created_at` của tour chỉ dùng trong procedure để sắp xếp "Mới nhất", không trả về JSON. Hàng nút tương tác cuối mỗi thẻ (Thích, Bình luận, Chia sẻ, Lưu, Thêm vào so sánh) không gắn với trường dữ liệu nào và đều bị khóa, xem mục 6.2.

### 2.2. Tìm kiếm, lọc và sắp xếp

| Mã | Điều khiển | Tham số | Nguồn dữ liệu | SRS | Vị trí trên giao diện |
| --- | --- | --- | --- | --- | --- |
| C01 | Ô tìm kiếm | `q` | Tìm "có chứa" trong `tours.title`, `tours.summary`, `destinations.name`, `providers.name`; tối đa 100 ký tự | FR-04 | Header: "Tìm điểm đến, tour hoặc người dẫn...". Kết quả cập nhật sau khi ngừng gõ khoảng 0,4 giây hoặc khi nhấn Enter, không tải lại trang. |
| C02 | Lọc điểm đến | `destination` | `GET /api/destinations` (`LTP_sp_destination_list`): `destination_id`, `name`, `slug`, `tour_count` | FR-05 (địa điểm) | Ô chọn "Điểm đến" trên hàng lọc (mặc định "Tất cả điểm đến", mỗi lựa chọn kèm số tour, ví dụ "Hà Nội (3)") và danh sách "Điểm đến" ở thanh bên. |
| C03 | Sắp xếp | `sort` | `recommended`, `newest`, `price_asc`, `price_desc` trong `LTP_sp_tour_list` | FR-05 (sắp xếp) | Tab "Dành cho bạn", "Mới nhất"; ô chọn "Giá" (Thấp đến cao / Cao đến thấp). |
| C04 | Số kết quả | `total` | *Tính toán*: số tour trả về | FR-04 (đầu ra) | Dòng phía trên danh sách: "9 tour", kèm từ khóa và điểm đến đang lọc. Cuối danh sách: "Bạn đã xem hết 9 tour phù hợp." |

Tab "Dành cho bạn" chưa cá nhân hóa (Sprint 3 chưa có tài khoản): tour được sắp theo điểm đánh giá, rồi số đánh giá, tour chưa có đánh giá xếp cuối. Bộ điều kiện đang chọn được giữ trên thanh địa chỉ (`?q=…&destination=…&sort=…`) để có thể tải lại hoặc gửi đường dẫn. Quy tắc tham số và thông báo lỗi xem [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md), mục 2.

### 2.3. Trạng thái màn hình

| Trạng thái | Điều kiện | Hiển thị | SRS |
| --- | --- | --- | --- |
| Đang tải | Đang chờ `/api/tours` | Thẻ khung xám (`#tour-loading`), dòng số kết quả "Đang tải tour…" | NFR-06 |
| Rỗng | `total = 0` | "Không có tour phù hợp" (`#tour-empty`). Có từ khóa hoặc điểm đến: "Thử từ khóa khác hoặc chọn điểm đến khác nhé." và nút "Xóa bộ lọc". Không có điều kiện lọc: "Hiện chưa có tour nào đang mở. Vui lòng quay lại sau." | FR-04 (thông báo không tìm thấy kết quả) |
| Lỗi | HTTP 400, 503, 500, mất mạng hoặc quá 15 giây không phản hồi | "Không tải được danh sách tour" (`#tour-error`), thông báo `message` từ server (mặc định "Máy chủ đang bận hoặc mất kết nối. Vui lòng thử lại sau ít phút."; quá thời gian: "Máy chủ phản hồi quá lâu. Vui lòng thử lại.") và nút "Thử lại" | NFR-16 |

## 3. Tour Detail – màn hình Chi tiết tour (UIEx2)

Route `GET /tours/{id}`, render từ server. Cùng dữ liệu có ở `GET /api/tours/{id}`. Thanh mục neo dưới thư viện ảnh gồm: Tổng quan, Lịch trình, Bao gồm, Điểm đón, Đánh giá.

| Mã | Khu vực | Trường hiển thị | Nguồn | Procedure | SRS |
| --- | --- | --- | --- | --- | --- |
| D01 | Breadcrumb | "Bảng tin / {điểm đến} / {loại hình}"; điểm đến dẫn tới `/tours?destination={id}` | `destinations.name`, `categories.name`, `tours.destination_id` | `NMT_sp_tour_detail` | FR-07 (địa điểm) |
| D02 | Tiêu đề | Tên tour (H1) | `tours.title` | `NMT_sp_tour_detail` | FR-07 (tên tour) |
| D03 | Dòng meta | "4,8/5 (4 đánh giá)" hoặc "Chưa có đánh giá" | *Tính toán*: `rating_avg`, `review_count` | `NMT_sp_tour_detail` | FR-07 (đánh giá) |
| D04 | Dòng meta | Điểm đến | `destinations.name` | `NMT_sp_tour_detail` | FR-07 (địa điểm) |
| D05 | Dòng meta | "Tổ chức bởi {nhà tổ chức}" kèm dấu xác minh | `providers.name`, `providers.is_verified` | `NMT_sp_tour_detail` | FR-07 (thông tin nhà cung cấp) |
| D06 | Thư viện ảnh | 1 ảnh lớn và 2 ảnh nhỏ (3 ảnh đầu theo `sort_order`) kèm chú thích; thiếu ảnh → ô xám với chú thích mặc định ("Ảnh chính của tour", "Ảnh trải nghiệm", "Ảnh hành trình") | `tour_images.image_path`, `caption`, `sort_order` | `NTK_sp_tour_image_list` | FR-07 (hình ảnh) |
| D07 | Tổng quan | Mô tả ngắn (đoạn mở đầu) và mô tả đầy đủ | `tours.summary`, `tours.description` | `NMT_sp_tour_detail` | FR-07 |
| D08 | Tổng quan | Thời lượng "4 giờ" | `tours.duration_hours` | `NMT_sp_tour_detail` | FR-07 (thời lượng) |
| D09 | Tổng quan | "Nhóm tối đa 8 khách" | `tours.max_group_size` | `NMT_sp_tour_detail` | FR-07 |
| D10 | Tổng quan | Ngôn ngữ "Tiếng Việt / Anh" và loại hình | `tours.languages`, `categories.name` | `NMT_sp_tour_detail` | FR-07, FR-05 (loại hình) |
| D11 | Lịch trình | Giờ và nội dung từng mốc; mốc không có giờ hiện "—"; chưa có mốc → "Lịch trình chi tiết đang được cập nhật." | `tour_itinerary_items.start_time`, `description`, `sort_order` | `NMT_sp_tour_itinerary_list` | FR-07 (lịch trình chi tiết) |
| D12 | Chi phí bao gồm | Hai cột "Đã bao gồm" và "Không gồm" | `tour_inclusions.item_text`, `is_included` | `NTK_sp_tour_inclusion_list` | FR-07, FR-08 (dịch vụ bao gồm/không bao gồm) |
| D13 | Điểm đón | "Điểm hẹn" | `tours.meeting_point` | `NMT_sp_tour_detail` | FR-07 (điểm đón/trả) |
| D14 | Điểm đón | Hướng dẫn tại điểm hẹn (nếu có) | `tours.meeting_note` | `NMT_sp_tour_detail` | FR-07 |
| D15 | Điểm đón | "Di chuyển" (nếu có) | `tours.transport_note` | `NMT_sp_tour_detail` | FR-07 (phương tiện) |
| D16 | Đánh giá của khách | Điểm trung bình, sao và số đánh giá | *Tính toán*: `rating_avg`, `review_count` | `NMT_sp_tour_detail` | FR-07 (đánh giá) |
| D17 | Đánh giá của khách | Tối đa 5 đánh giá mới nhất: tên, điểm, ngày, nhận xét, nhãn "Đã tham gia tour (minh họa)". Có hơn 5 đánh giá → "Đang hiển thị 5 đánh giá mới nhất trên tổng số N." Không có → "Chưa có đánh giá" | `reviews.reviewer_name`, `rating`, `comment`, `created_at` | `NTK_sp_tour_review_list` | FR-07 (đánh giá của khách hàng) |
| D18 | Hộp nhà tổ chức | Tên, nhãn "Đã xác minh", giới thiệu (nếu có) | `providers.name`, `is_verified`, `description` | `NMT_sp_tour_detail` | FR-07 (thông tin nhà cung cấp) |
| D19 | Thẻ giá | "650.000đ / người" | `tours.price_per_person` | `NMT_sp_tour_detail` | FR-08 (giá mỗi người) |
| D20 | Thẻ giá | Ghi chú giá và phụ phí đã biết; trống → "Giá minh họa · VND" | `tours.price_note` | `NMT_sp_tour_detail` | FR-08 (phụ phí đã biết) |
| D21 | Thẻ giá | Ô chọn "Ngày tham gia", mỗi lựa chọn dạng "24/10/2026 · còn 6 chỗ"; không có lịch → "Chưa có lịch khởi hành sắp tới. Vui lòng quay lại sau." và khóa các ô bên dưới | `tour_schedules.schedule_id`, `departure_date`; *tính toán* `seats_left = seats_total − seats_booked` | `NMT_sp_tour_schedule_list` | FR-07 (thời gian khởi hành), FR-09 |
| D22 | Thẻ giá | "Giờ bắt đầu" chỉ đọc, đổi theo ngày đã chọn; lịch chưa có giờ → "—" | `tour_schedules.start_time` | `NMT_sp_tour_schedule_list` | FR-07 (thời gian khởi hành) |
| D23 | Thẻ giá | "Số khách" từ 1 đến min(nhóm tối đa, số chỗ còn của ngày đã chọn), gợi ý "Nhóm tối đa N khách", thêm "· lịch này còn X chỗ" khi số chỗ còn ít hơn nhóm tối đa | `tours.max_group_size`; `seats_left` | `NMT_sp_tour_schedule_list` | FR-09 (tình trạng chỗ) |
| D24 | Thẻ giá | "Tạm tính: 2 khách × 650.000đ = 1.300.000đ"; không có lịch → "Chưa thể tính" | *Tính toán* trong trình duyệt: số khách × `price_per_person` | — | FR-08 (tổng tiền dự kiến theo số khách) |
| D25 | Thẻ giá | Chính sách hủy/đổi, kèm ghi chú "Chính sách minh họa · Kiểm tra trước khi đặt" | `tours.cancellation_policy` | `NMT_sp_tour_detail` | FR-16, FR-07 |
| D26 | Thẻ giá | Nút "Quay lại danh sách" | `url('/tours')` | — | Tiêu chí 3.2.6 |

Dưới 992px, thẻ giá nằm sau nội dung và một thanh cố định cuối màn hình hiện giá/người cùng nút "Chọn lịch" để cuộn tới thẻ giá.

ID sai định dạng, không tồn tại hoặc tour không công khai hiển thị trạng thái "Không tìm thấy tour" (HTTP 404): nhãn "Lỗi 404", câu "Tour bạn tìm không tồn tại hoặc đã ngừng hiển thị." và nút "Quay lại danh sách tour". Trạng thái này không đọc trường nào của tour.

Cột có trong database nhưng không hiển thị ở Sprint 3: `tours.created_at`, `tours.updated_at`, `providers.phone`, `providers.email` (hai cột liên hệ không được procedure trả về), `providers.is_active` và `tours.status` (chỉ dùng để lọc), `tour_schedules.status`, `seats_total`, `seats_booked` (chỉ dùng để tính `seats_left` và lọc ngày còn chỗ).

## 4. Quy ước định dạng hiển thị

| Dữ liệu | Lưu trong database | Hiển thị | Hàm PHP (`core/helpers.php`) |
| --- | --- | --- | --- |
| Giá | `INT UNSIGNED`, ví dụ `650000` | `650.000đ` | `format_vnd()` |
| Điểm đánh giá | `DECIMAL(2,1)`, ví dụ `4.8` | `4,8` | `format_rating()` |
| Thời lượng | `DECIMAL(4,1)`, ví dụ `4.0`, `1.5` | `4 giờ`, `1,5 giờ` | `format_duration()` |
| Ngày | `DATE`, ví dụ `2026-10-24` | `24/10/2026` | `format_date()` |
| Giờ | `TIME`, ví dụ `17:00:00` | `17:00` | `format_time()` |
| Ảnh | Đường dẫn tương đối trong `public/`, ví dụ `assets/img/tours/hanoi-1.svg` | URL đầy đủ theo gốc ứng dụng; `NULL` → ô xám | `tour_image_url()` |

Danh sách JSON trả sẵn cả giá trị gốc lẫn chuỗi đã định dạng (`price_text`, `rating_text`, `duration_text`, `next_departure_text`) để JavaScript không phải tự định dạng lại.

## 5. Đối chiếu với SRS v0.1

### 5.1. FR-06 – Xem danh sách tour

| Thông tin SRS yêu cầu | Trường | Mức đáp ứng |
| --- | --- | --- |
| Chỉ hiển thị tour được phép công khai | Lọc `status = 'published'` và nhà cung cấp đang hoạt động | Đáp ứng |
| Tên tour | L02 | Đáp ứng |
| Địa điểm | L06 | Đáp ứng |
| Giá tham khảo | L13 | Đáp ứng |
| Thời lượng | L11 | Đáp ứng |
| Hình ảnh | L08 | Đáp ứng (ảnh minh họa) |
| Đánh giá nếu có | L09, L10 | Đáp ứng |
| Tình trạng tour nếu có dữ liệu | L14 | Đáp ứng ở mức ngày khởi hành gần nhất còn chỗ |

### 5.2. FR-07 – Xem chi tiết tour

| Thông tin SRS yêu cầu | Trường | Mức đáp ứng |
| --- | --- | --- |
| Tên tour và địa điểm | D01, D02, D04 | Đáp ứng |
| Lịch trình chi tiết | D11 | Đáp ứng |
| Thời lượng và thời gian khởi hành | D08, D21, D22 | Đáp ứng |
| Điểm đón/trả và phương tiện nếu có | D13, D14, D15 | Đáp ứng ở dạng văn bản; chưa có bản đồ (FR-29) |
| Giá tour và phụ phí | D19, D20 | Đáp ứng |
| Dịch vụ bao gồm và không bao gồm | D12 | Đáp ứng |
| Hình ảnh hoặc video | D06 | Một phần: có ảnh, chưa có video |
| Tình trạng chỗ | D21, D23 | Một phần: xem FR-09 |
| Thông tin nhà cung cấp | D05, D18 | Đáp ứng ở mức tên, giới thiệu, xác minh; chưa hiện thông tin liên hệ |
| Đánh giá của khách hàng | D03, D16, D17 | Đáp ứng (chỉ xem) |
| Chính sách hủy, đổi và hoàn tiền | D25 | Một phần: văn bản chính sách của từng tour |

### 5.3. Các yêu cầu liên quan khác

| Yêu cầu | Nội dung SRS | Mức đáp ứng ở Sprint 3 | Trường / ghi chú |
| --- | --- | --- | --- |
| FR-04 | Tìm tour theo tên, địa điểm hoặc từ khóa liên quan | Đáp ứng mức cơ bản | C01: tìm trên tên tour, mô tả ngắn, điểm đến, nhà tổ chức; C04; trạng thái rỗng. |
| FR-05 | Lọc theo địa điểm, ngày đi, giá, loại hình, thời lượng, tiện ích; sắp xếp | Một phần | Có lọc điểm đến (C02) và 4 kiểu sắp xếp (C03). Các bộ lọc còn lại ở mục 6.2. |
| FR-08 | Giá mỗi người; bao gồm/không gồm; phụ phí đã biết; tổng tiền dự kiến; báo chi phí phát sinh trước khi xác nhận | Một phần | D19, D20, D12, D24. Bước "trước khi xác nhận đặt" thuộc quy trình đặt tour (FR-11), chưa làm. |
| FR-09 | Tình trạng còn chỗ, hết chỗ hoặc không khả dụng theo ngày | Một phần | Chỉ liệt kê ngày còn chỗ kèm số chỗ còn lại (D21), số khách tối đa theo số chỗ còn lại (D23), thông báo khi không có lịch. Ngày hết chỗ hoặc bị hủy không hiển thị. |
| FR-16 | Công khai chính sách hủy/đổi trước khi đặt | Một phần | D25: một đoạn văn bản cho mỗi tour; chưa có bảng phí hủy theo mốc thời gian. |
| BR-01 | Chỉ tour đủ điều kiện công khai mới hiển thị | Đáp ứng | Áp dụng trong mọi procedure, kể cả danh sách con. |
| NFR-07, NFR-08 | Dùng được trên máy tính và điện thoại, giao diện đáp ứng | Đáp ứng mức cơ bản | Bootstrap 4.6.2; dưới 992px ẩn cột phải, thanh bên thu gọn và mở bằng nút "Menu" trên header. |
| NFR-16 | Thông báo lỗi dễ hiểu, không lộ thông tin kỹ thuật | Đáp ứng | Xem [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md), mục 5–6. |

## 6. Quyết định phạm vi Sprint 3

### 6.1. Thuộc Sprint 3

| Hạng mục | Yêu cầu | Mức độ |
| --- | --- | --- |
| Danh sách tour đọc từ MySQL, có trạng thái đang tải, rỗng, lỗi | FR-06, NFR-16 | Đầy đủ theo mục 2 |
| Chi tiết tour theo ID, trạng thái không tìm thấy, nút quay lại danh sách | FR-07 | Đầy đủ theo mục 3, trừ video và bản đồ |
| Tìm kiếm theo từ khóa | FR-04 | Mức nhẹ: một ô tìm kiếm, tìm "có chứa" trên 4 trường |
| Lọc theo điểm đến | FR-05 | Mức nhẹ: một điểm đến mỗi lần |
| Sắp xếp: Dành cho bạn, Mới nhất, Giá tăng/giảm | FR-05 | Đầy đủ cho 4 kiểu |
| Hiển thị giá minh bạch: giá/người, ghi chú phụ phí, bao gồm/không gồm, tổng dự kiến theo số khách | FR-08 | Chỉ để xem; tổng tiền tính trong trình duyệt, không gửi đi đâu |
| Ngày khởi hành còn chỗ, số chỗ còn và giới hạn số khách | FR-09 | Mức xem thông tin |
| Hiển thị đánh giá có sẵn | FR-07 | Chỉ xem, tối đa 5 đánh giá mới nhất |
| Chính sách hủy/đổi dạng văn bản | FR-16 | Một đoạn văn bản mỗi tour |
| Giao diện đáp ứng desktop và mobile cơ bản | NFR-07, NFR-08 | Theo tiêu chí 3.2.5 |

### 6.2. Không thuộc Sprint 3 – chuyển về Product Backlog

Quy tắc chung cho mọi nút của chức năng chưa làm nhưng có trên wireframe: vẫn hiển thị để giữ bố cục, nhưng ở trạng thái `disabled`, màu nhạt, có `title="Sắp có"` và nhãn "Sắp có" khi đủ chỗ; không dẫn tới trang nào.

| Hạng mục | Yêu cầu | Lý do chưa làm | Thể hiện trên giao diện Sprint 3 |
| --- | --- | --- | --- |
| Lọc theo ngày đi | FR-05 | Cần tìm theo lịch khởi hành và bộ chọn ngày; Sprint 3 ưu tiên luồng danh sách → chi tiết chạy ổn định. | Nút "Ngày đi" bị khóa, nhãn "Sắp có". |
| Bộ lọc nâng cao: khoảng giá, loại hình, thời lượng, tiện ích | FR-05 | Cần thiết kế giao diện bộ lọc nhiều điều kiện; chưa có dữ liệu tiện ích. Dữ liệu loại hình đã có sẵn trong database. | Nút "Bộ lọc" bị khóa. |
| Tab "Đang theo dõi" | Không có trong SRS (chỉ có trên wireframe) | Cần tài khoản và chức năng theo dõi nhà tổ chức. | Tab bị khóa. |
| So sánh tour | FR-10 (wireframe UIEx3) | SRS xếp ưu tiên Trung bình; cần lưu danh sách tour đang chọn. | "Thêm vào so sánh" trên thẻ tour và thẻ giá bị khóa; khung "Tour đang so sánh" ghi "Tính năng so sánh sẽ có ở Sprint sau"; mục "So sánh tour" ở thanh bên bị khóa. |
| Đặt tour và xác nhận đặt tour | FR-11, FR-12 (wireframe UIEx4) | Kế hoạch Sprint 3 không triển khai hệ thống đặt tour đầy đủ. | Nút "Đặt tour" bị khóa; ô ngày và số khách chỉ dùng để xem tạm tính. |
| Thanh toán trực tuyến | FR-13 | Ngoài phạm vi Sprint 3 theo kế hoạch. | Không có nút thanh toán. |
| Theo dõi đơn, hủy đơn, tra cứu giao dịch | FR-14, FR-15, FR-25 | Phụ thuộc chức năng đặt tour và tài khoản. | Mục "Đặt chỗ của tôi" ở thanh bên bị khóa. |
| Đăng ký, đăng nhập, hồ sơ | FR-01 – FR-03 | Sprint 3 chỉ có trang công khai, chưa cần xác thực. | Không có nút đăng nhập hay ảnh đại diện người dùng. |
| Lưu tour yêu thích | FR-28 | Cần tài khoản để lưu theo người dùng. | "Lưu" trên thẻ tour, "Lưu tour" ở trang chi tiết và mục "Tour đã lưu" ở thanh bên bị khóa. |
| Gửi đánh giá, kiểm duyệt đánh giá | FR-17, FR-24 | Cần tài khoản và quy trình kiểm duyệt; Sprint 3 chỉ hiển thị đánh giá mẫu. | Không có biểu mẫu gửi đánh giá. |
| Thích, Bình luận, Chia sẻ; Cộng đồng; Tin nhắn | Không có trong SRS (chỉ có trên wireframe) | Chưa có yêu cầu được thống nhất; cần tài khoản. | Các nút trên thẻ tour, "Chia sẻ" và "Nhắn tin" ở trang chi tiết, mục "Cộng đồng", "Tin nhắn" ở thanh bên bị khóa; khung "Gợi ý từ cộng đồng" là nội dung tĩnh có ghi chú minh họa. |
| Thông báo | FR-26 | Phụ thuộc sự kiện của đơn đặt. | Nút "Thông báo" ở header bị khóa. |
| Hỗ trợ khách hàng; Trợ giúp, Điều khoản | FR-27 | Chưa có quy trình hỗ trợ và nội dung điều khoản. | "Trợ giúp", "Điều khoản" bị khóa. |
| Hiển thị thông tin liên hệ nhà cung cấp | FR-07, FR-27 | Database đã có cột nhưng chưa hiển thị khi chưa có quy trình hỗ trợ khách hàng. | Hộp nhà tổ chức chỉ có tên, giới thiệu, dấu xác minh. |
| Video tour | FR-07 | Chưa có nguồn video; ảnh minh họa đủ cho v0.1. | Chỉ có thư viện ảnh. |
| Bản đồ vị trí, điểm đón | FR-29 | Phụ thuộc dịch vụ bản đồ bên ngoài. | Điểm đón ở dạng văn bản. |
| Hiển thị ngày hết chỗ/bị hủy kèm nhãn; kiểm tra chỗ theo thời gian thực | FR-09 | Số chỗ chỉ thay đổi khi có chức năng đặt tour. | Ngày hết chỗ hoặc bị hủy không xuất hiện trong ô "Ngày tham gia". |
| Bảng phí hủy và điều kiện hoàn tiền theo mốc thời gian | FR-15, FR-16 | Cần cho quy trình hủy đơn ở Sprint sau. | Chính sách hiển thị dạng một đoạn văn bản. |
| Giá theo từng lịch khởi hành, giá trẻ em hoặc theo nhóm | FR-08, FR-19 | Sprint 3 dùng một mức giá mỗi người cho mọi ngày. | Tạm tính = số khách × giá mỗi người. |
| Phân trang hoặc tải thêm khi cuộn | FR-06 | Dữ liệu mẫu có 9 tour công khai, trả về một lần. | Cuối danh sách hiện "Bạn đã xem hết N tour phù hợp." thay cho dòng "Tiếp tục cuộn để khám phá thêm tour" trên wireframe. |
| Gợi ý cá nhân hóa, gợi ý bằng AI, chatbot | SRS mục 2.2.2 | Ngoài phạm vi phiên bản đầu. | Tab "Dành cho bạn" chỉ sắp xếp theo đánh giá. |
| Quản lý tour, lịch khởi hành, đơn đặt cho nhà cung cấp | FR-18 – FR-20 | Ngoài phạm vi Sprint 3. | Dữ liệu được nạp bằng script `02_seed.sql`. |
| Chức năng quản trị (Admin) | FR-21 – FR-25, FR-30 | Ngoài phạm vi Sprint 3. | Không có trang quản trị. |
| Ứng dụng di động riêng | SRS mục 7.3 | Ngoài phạm vi phiên bản đầu. | Website đáp ứng trên trình duyệt điện thoại. |

## 7. Đối chiếu tiêu chí nghiệm thu 3.1.1

| Nội dung tiêu chí | Đáp ứng tại |
| --- | --- |
| Có danh mục field Tour List | Mục 2 (L01 – L16, C01 – C04, trạng thái màn hình) |
| Có danh mục field Tour Detail | Mục 3 (D01 – D26, trạng thái không tìm thấy) |
| Danh mục được đối chiếu với yêu cầu Sprint 2 | Cột SRS ở mục 2–3 và bảng đối chiếu ở mục 5 |
| Có ghi quyết định những gì thuộc/không thuộc Sprint 3 | Mục 6.1 và 6.2 |

Khi cần thêm, bớt hoặc đổi tên một trường, người đề xuất cập nhật tài liệu này, [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md) và [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md) trong cùng một lần thay đổi, đồng thời báo cho QA để cập nhật test case.
