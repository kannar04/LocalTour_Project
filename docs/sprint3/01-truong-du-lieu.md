# Danh mục trường dữ liệu – Tour List và Tour Detail

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 3 – Technical Design, Coding & QA |
| WBS | 3.1.1 – Rà soát yêu cầu Tour List/Detail; chốt trường dữ liệu |
| Người phụ trách | Lê Trung Phong |
| Thời gian theo kế hoạch | 22/10/2026 (0,5 giờ công) |
| Căn cứ | SRS v0.1 ngày 14/10/2026 (yêu cầu đã thống nhất ở Sprint 2), wireframe UIEx1 (Bảng tin) và UIEx2 (Chi tiết tour), ERD sơ bộ trang 01 "Lõi đặt tour" và trang 02 "Khám phá & vận hành", bảng FR/NFR (Bài tập nhóm tuần 2), lược đồ gộp 17 bảng (Phong chốt ngày 22/10/2026), Kế hoạch Sprint 3 |
| Tài liệu liên quan | [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md), [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md) |
| Tiêu chí nghiệm thu | Danh mục field Tour List/Detail được đối chiếu với yêu cầu Sprint 2, có ghi quyết định những gì thuộc/không thuộc Sprint 3. |

## 1. Mục đích và cách đọc

Tài liệu chốt các trường dữ liệu mà hai màn hình của Increment v0.1 hiển thị, nguồn của từng trường và yêu cầu SRS mà trường đó đáp ứng. Đây là hợp đồng dữ liệu chung giữa database (Thức), backend (Phong, Thức) và giao diện (Khôi). QA (Hải, Thành) dùng tài liệu này để viết test case và kiểm tra tính nhất quán SRS – UI – DB – routes.

- **Nguồn**: `bảng.cột` trong database `db_localtour` (đúng tên cột trong `01_schema.sql`), hoặc *tính toán* khi giá trị do stored procedure, PHP hay JavaScript tạo ra và không lưu trong bảng.
- **Khóa JSON**: tên trường trong phản hồi `GET /api/tours` (danh sách). Trang chi tiết dùng tên cột của procedure tương ứng.
- **SRS**: mã yêu cầu trong SRS v0.1. Đối chiếu theo mã của bảng FR (Bài tập nhóm tuần 2) nằm ở [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md), mục 12; hai bộ mã đánh số khác nhau.
- Mọi trường hiển thị đều lấy từ database qua stored procedure, kể cả ảnh (bảng `tour_images`); giao diện không chứa dữ liệu tour viết cứng.
- Dữ liệu thiếu (`NULL` hoặc rỗng) hiện **"Chưa cập nhật"**, không suy diễn và không lấy từ tour khác. Ngoại lệ: chưa có đánh giá hiện "Chưa có đánh giá", không có lịch đặt được hiện "Chưa có lịch khởi hành sắp tới".
- **Khách hàng** là tác nhân sử dụng website nhưng không đồng nghĩa với một tài khoản trong bảng `users`. MVP dùng luồng khách không đăng nhập (guest checkout): thông tin liên hệ lưu trực tiếp trong `bookings`, thông tin người tham gia lưu trong `passengers`; khách nhận mã đặt chỗ và tra cứu bằng mã đó kèm email hoặc số điện thoại đã nhập.
- Việc không có tài khoản khách **không loại bỏ đặt tour hoặc thanh toán**. Theo bảng FR tuần 2, sau khi nhân viên xác nhận chỗ và tổng tiền, khách mở đúng booking bằng mã đặt chỗ + email/số điện thoại rồi thanh toán qua VNPay sandbox hoặc VietQR. `payments.booking_id` gắn giao dịch với booking, nên không cần `customer_id`. Các màn hình và route cho luồng này thuộc các increment sau Sprint 3; Sprint 3 hiện chỉ triển khai Tour List và Tour Detail.

## 2. Tour List – màn hình Bảng tin (UIEx1)

Route `GET /tours`. Khung trang render từ server, danh sách tour tải bằng AJAX từ `GET /api/tours` (procedure `LTP_sp_tour_list`). Chỉ tour đã duyệt của nhà cung cấp đã duyệt, tài khoản đang hoạt động được trả về (BR-01, xem [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md), mục 7).

### 2.1. Trường trên thẻ tour

| Mã | Trường | Khóa JSON | Nguồn | SRS | Vị trí trên giao diện |
| --- | --- | --- | --- | --- | --- |
| L01 | Mã tour, liên kết chi tiết | `tour_id`, `url` | `tours.id` (UUID); `url` do PHP tạo bằng `url('/tours/{uuid}')` | FR-06, FR-07 | Không hiển thị. Bấm vào bất kỳ đâu trên thẻ, tiêu đề hoặc nút "Xem chi tiết" đều mở `url`. |
| L02 | Tên tour | `title` | `tours.title` | FR-06 (tên tour) | Tiêu đề thẻ. |
| L03 | Mô tả ngắn | `excerpt` | *Tính toán*: đoạn đầu của `tours.description`, tối đa 180 ký tự, dài hơn thì cắt và thêm "…" | FR-06 | Đoạn dưới tiêu đề. |
| L04 | Nhà tổ chức | `provider_name` | `providers.business_name` | FR-07 (thông tin nhà cung cấp) | Đầu thẻ, cạnh ô chữ cái đầu: tên nhà tổ chức và nhãn "Người tổ chức". |
| L05 | Điểm đến | `destination` | `tours.destination` (tên điểm đến dạng chữ) | FR-06 (địa điểm) | Dòng phụ dưới tên nhà tổ chức và nhãn ở góc ảnh. |
| L06 | Ảnh bìa | `cover_image_url`, `cover_caption` | `tour_images.url`, `alt_text` của ảnh có `sort_order` nhỏ nhất của chính tour (cột `cover_image_url`, `cover_alt_text` của procedure); chú thích là `alt_text`, thiếu thì tên tour | FR-06 (hình ảnh) | Khung ảnh giữa thẻ. Tour chưa có ảnh → ô xám "Chưa cập nhật ảnh"; ảnh tải lỗi → "Không tải được ảnh". |
| L07 | Điểm đánh giá | `rating_avg`, `rating_text` | *Tính toán*: trung bình `reviews.rating` của đánh giá `approved`, làm tròn 1 chữ số | FR-06 (đánh giá nếu có) | Hàng thông tin nhanh dưới ảnh: "4,8/5 (4 đánh giá)". `null` → "Chưa có đánh giá". |
| L08 | Số đánh giá | `review_count` | *Tính toán*: số đánh giá `approved` của tour | FR-06 | Cùng mục với điểm đánh giá. |
| L09 | Thời lượng | `duration_minutes`, `duration_text` | `tours.duration_minutes` | FR-06 (thời lượng) | Hàng thông tin nhanh: "4 giờ", "3 giờ 30 phút". |
| L10 | Nơi khởi hành | `departure_text` (kèm `pickup_mode`, `pickup_text`, `meeting_point`) | `tours.pickup_mode`, `tours.meeting_point`; lược đồ không có cột nơi khởi hành riêng | FR-07 (điểm đón) | Hàng thông tin nhanh: "Nơi khởi hành: {điểm hẹn}", "Nơi khởi hành: Đón tại khách sạn" hoặc "Nơi khởi hành: Chưa cập nhật". |
| L11 | Giá tham khảo | `from_price_vnd`, `price_text` | *Tính toán*: giá vé người lớn (`ticket_types.price_vnd`, `name = 'adult'`) đang bán thấp nhất trong các lịch còn đặt được; không có vé người lớn đang bán thì `null` (không lấy giá vé trẻ em) | FR-06 (giá tham khảo), FR-08 | "Từ 650.000đ / người lớn", cạnh nút "Xem chi tiết". `null` → "Giá: Chưa cập nhật". |
| L12 | Lần khởi hành gần nhất | `next_starts_at`, `next_departure_text` | *Tính toán*: `schedules.starts_at` sớm nhất của lịch còn đặt được (`open`, sau thời điểm hiện tại, `remaining > 0`, có vé đang bán) | FR-06 (tình trạng tour nếu có dữ liệu), FR-09 | Hàng thông tin nhanh: "Khởi hành 24/10/2026 · 17:00". `null` → "Chưa có lịch khởi hành sắp tới". |
| L13 | Nhóm tối đa | `max_group_size` | `tours.max_group_size` | FR-07 | Có trong JSON nhưng thẻ không hiển thị (wireframe không có); hiển thị ở trang chi tiết (D09). |
| L14 | Ngôn ngữ | `languages_text` | `tours.language_codes` (ví dụ `vi,en` → "Tiếng Việt / Anh") | FR-07 | Như L13; hiển thị ở trang chi tiết (D10). |

Lược đồ mới không có loại hình tour (bảng `categories` cũ đã bỏ), không có cột "đã xác minh" của nhà cung cấp và không có ngày tạo tour, nên thẻ không còn dòng loại hình và tab "Mới nhất" được thay bằng "Sắp khởi hành". Mọi nhà cung cấp xuất hiện trên thẻ đều đã được LocalTour duyệt (điều kiện công khai). Cuối mỗi thẻ chỉ còn nút "Thêm vào so sánh" bị khóa, nhãn "Sắp có". Các nút cần tài khoản khách (Thích, Bình luận, Chia sẻ, Lưu) và tab "Đang theo dõi" đã bỏ, xem mục 6.2.

### 2.2. Tìm kiếm, lọc và sắp xếp

| Mã | Điều khiển | Tham số | Nguồn dữ liệu | SRS | Vị trí trên giao diện |
| --- | --- | --- | --- | --- | --- |
| C01 | Ô tìm kiếm | `q` | Tìm "có chứa" trong `tours.title`, `tours.description`, `tours.destination`, `providers.business_name`; tối đa 100 ký tự | FR-04 | Header: "Tìm điểm đến, tour hoặc người dẫn...". Kết quả cập nhật sau khi ngừng gõ khoảng 0,4 giây hoặc khi nhấn Enter, không tải lại trang. |
| C02 | Lọc điểm đến | `destination` (tên điểm đến) | `GET /api/destinations` (`LTP_sp_destination_list`): `name`, `tour_count`, lấy từ các giá trị khác nhau của `tours.destination` | FR-05 (địa điểm) | Ô chọn "Điểm đến" trên hàng lọc (mặc định "Tất cả", mỗi lựa chọn kèm số tour, ví dụ "Hà Nội (3)") và danh sách "Điểm đến" ở thanh bên. Điểm đến nhiều tour đứng trước. |
| C03 | Sắp xếp | `sort` | `recommended`, `upcoming`, `price_asc`, `price_desc` trong `LTP_sp_tour_list` | FR-05 (sắp xếp) | Tab "Nổi bật", "Sắp khởi hành"; ô chọn "Giá" (Thấp đến cao / Cao đến thấp). |
| C04 | Số kết quả | `total` | *Tính toán*: số tour trả về | FR-04 (đầu ra) | Dòng phía trên danh sách: "9 tour", kèm từ khóa và điểm đến đang lọc. Cuối danh sách: "Bạn đã xem hết 9 tour phù hợp." |

Tab "Nổi bật" không cá nhân hóa (khách không có tài khoản): tour có đánh giá xếp trước, theo điểm đánh giá rồi số đánh giá, tour chưa có đánh giá xếp cuối. Tab "Sắp khởi hành" xếp theo lần khởi hành gần nhất, tour chưa có lịch xếp cuối. Khi sắp theo giá, tour chưa có giá không xếp lẫn với tour có giá: chúng nằm cuối, sau dòng "Các tour dưới đây chưa cập nhật giá nên không được xếp theo giá." Bộ điều kiện đang chọn được giữ trên thanh địa chỉ (`?q=…&destination=Hà Nội&sort=…`) để có thể tải lại hoặc gửi đường dẫn. Quy tắc tham số và thông báo lỗi xem [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md), mục 2.

### 2.3. Trạng thái màn hình

| Trạng thái | Điều kiện | Hiển thị | SRS |
| --- | --- | --- | --- |
| Đang tải | Đang chờ `/api/tours` | Thẻ khung xám (`#tour-loading`), dòng số kết quả "Đang tải tour…" | NFR-06 |
| Rỗng | `total = 0` | "Không có tour phù hợp" (`#tour-empty`). Có từ khóa hoặc điểm đến: "Thử từ khóa khác hoặc chọn điểm đến khác nhé." và nút "Xóa bộ lọc". Không có điều kiện lọc: "Hiện chưa có tour nào đang mở. Vui lòng quay lại sau." | FR-04 (thông báo không tìm thấy kết quả) |
| Lỗi | HTTP 400, 503, 500, mất mạng hoặc quá 15 giây không phản hồi | "Không tải được danh sách tour" (`#tour-error`), thông báo `message` từ server (mặc định "Máy chủ đang bận hoặc mất kết nối. Vui lòng thử lại sau ít phút."; quá thời gian: "Máy chủ phản hồi quá lâu. Vui lòng thử lại.") và nút "Thử lại" | NFR-16 |

## 3. Tour Detail – màn hình Chi tiết tour (UIEx2)

Route `GET /tours/{uuid}`, render từ server. Cùng dữ liệu có ở `GET /api/tours/{uuid}`. Thanh mục neo dưới thư viện ảnh gồm: Thông tin tour, Lịch trình, Lịch khởi hành, Dịch vụ, Chính sách (tiêu đề mục "Điều kiện & chính sách"), Đánh giá. Mỗi nội dung quan trọng có tiêu đề riêng (NFR-01 của bảng FR).

| Mã | Khu vực | Trường hiển thị | Nguồn | Procedure | SRS |
| --- | --- | --- | --- | --- | --- |
| D01 | Breadcrumb | "Bảng tin › {điểm đến} › {tên tour}"; điểm đến dẫn tới `/tours?destination={tên điểm đến}` | `tours.destination`, `tours.title` | `NMT_sp_tour_detail` | FR-07 (địa điểm) |
| D02 | Tiêu đề | Tên tour (H1) | `tours.title` | `NMT_sp_tour_detail` | FR-07 (tên tour) |
| D03 | Dòng meta | "4,8/5 (4 đánh giá)" hoặc "Chưa có đánh giá" | *Tính toán*: `rating_avg`, `review_count` (chỉ đánh giá `approved`) | `NMT_sp_tour_detail` | FR-07 (đánh giá) |
| D04 | Dòng meta | Điểm đến | `tours.destination` | `NMT_sp_tour_detail` | FR-07 (địa điểm) |
| D05 | Dòng meta | "Tổ chức bởi {nhà tổ chức}" | `providers.business_name` | `NMT_sp_tour_detail` | FR-07 (thông tin nhà cung cấp) |
| D06 | Thư viện ảnh | Tối đa 3 ảnh đầu của tour theo `sort_order`, chú thích là `alt_text` (thiếu thì tên tour); bố cục đổi theo số ảnh. Không có ảnh → ô xám "Chưa cập nhật ảnh" | `tour_images.url`, `alt_text`, `sort_order` của chính tour | `NMT_sp_tour_image_list` | FR-07 (hình ảnh) |
| D07 | Thông tin tour | Mô tả đầy đủ, đoạn đầu làm câu dẫn; trống → "Mô tả tour: Chưa cập nhật" | `tours.description` | `NMT_sp_tour_detail` | FR-07 |
| D08 | Thông tin tour | "Thời lượng": "4 giờ" | `tours.duration_minutes` | `NMT_sp_tour_detail` | FR-07 (thời lượng) |
| D09 | Thông tin tour | "Số khách tối đa": "8 khách" | `tours.max_group_size` | `NMT_sp_tour_detail` | FR-07 |
| D10 | Thông tin tour | "Ngôn ngữ hướng dẫn": "Tiếng Việt / Anh" | `tours.language_codes` | `NMT_sp_tour_detail` | FR-07 |
| D11 | Lịch khởi hành | Bảng các lịch còn đặt được: ngày, giờ bắt đầu – kết thúc, số chỗ còn / tổng chỗ, giá từ; không có lịch → "Chưa có lịch khởi hành sắp tới." | `schedules.starts_at`, `ends_at`, `remaining`, `capacity`; *tính toán* `from_price_vnd` của từng lịch | `NMT_sp_tour_schedule_list` | FR-07 (thời gian khởi hành), FR-09 |
| D12 | Dịch vụ | "Đã bao gồm": mỗi dòng của cột là một mục | `tours.included_summary` | `NMT_sp_tour_detail` | FR-07, FR-08 (dịch vụ bao gồm) |
| D13 | Thông tin tour | "Nơi khởi hành / điểm đón": tên điểm hẹn, "Đón tại khách sạn" (kèm "Khu vực đón: …" nếu có) hoặc "Chưa cập nhật" | `tours.pickup_mode`, `tours.meeting_point` | `NMT_sp_tour_detail` | FR-07 (điểm đón/trả) |
| D14 | Điều kiện & chính sách | "Điều kiện đón khách": "Gặp tại {điểm hẹn}" hoặc "Đón tại khách sạn" | `tours.pickup_mode`, `tours.meeting_point` | `NMT_sp_tour_detail` | FR-07 |
| D15 | Đánh giá của khách | Điểm trung bình, sao và số đánh giá | *Tính toán*: `rating_avg`, `review_count` | `NMT_sp_tour_detail` | FR-07 (đánh giá) |
| D16 | Đánh giá của khách | Tối đa 5 đánh giá đã duyệt, chuyến đi gần nhất trước: tên, điểm, ngày tham gia tour, nhận xét ("5/5 · Tham gia ngày {ngày đi tour}"). Có hơn 5 đánh giá → "Đang hiển thị 5 đánh giá mới nhất trên tổng số N." Không có → "Chưa có đánh giá" | `bookings.contact_name` của đơn được đánh giá (khách không có tài khoản), `reviews.rating`, `reviews.content`; *tính toán* `tour_date` = `schedules.starts_at` của đơn đặt gắn với đánh giá | `NTK_sp_tour_review_list` | FR-07 (đánh giá của khách hàng) |
| D17 | Hộp nhà tổ chức | Tên, nhãn "Đã được LocalTour duyệt" và "Đối tác của LocalTour từ {ngày duyệt}" | `providers.business_name`, `providers.approved_at`; nhãn đúng với mọi tour công khai vì nhà cung cấp phải `approved` | `NMT_sp_tour_detail` | FR-07 (thông tin nhà cung cấp) |
| D18 | Thẻ giá | "Từ 650.000đ / người lớn"; không có lịch → "Giá: Chưa cập nhật" | *Tính toán*: `from_price_vnd` (như L11) | `NMT_sp_tour_detail` | FR-08 (giá mỗi người) |
| D19 | Thẻ giá | Ô chọn lịch, mỗi lựa chọn gồm ngày, giờ bắt đầu và số chỗ còn; không có lịch → "Chưa có lịch khởi hành sắp tới. Vui lòng quay lại sau." và khóa các ô bên dưới | `schedules.id`, `starts_at`, `remaining` | `NMT_sp_tour_schedule_list` | FR-07 (thời gian khởi hành), FR-09 |
| D20 | Thẻ giá | Các dòng vé của lịch đã chọn: tên loại vé ("Người lớn", "Trẻ em"), độ tuổi ("4–11 tuổi", "Từ 12 tuổi"), giá, nút tăng/giảm số lượng | `ticket_types.name`, `min_age`, `max_age`, `price_vnd` (chỉ vé `active`) | `NMT_sp_tour_ticket_list` | FR-08 (giá theo loại khách) |
| D21 | Thẻ giá | Tổng số khách của mọi dòng vé tối đa bằng min(nhóm tối đa, số chỗ còn của lịch đã chọn), kèm gợi ý giới hạn | `tours.max_group_size`, `schedules.remaining` | `NMT_sp_tour_detail`, `NMT_sp_tour_schedule_list` | FR-09 (tình trạng chỗ) |
| D22 | Thẻ giá | "Tạm tính tiền vé" = tổng (số lượng × giá vé) của các dòng vé, kèm ghi chú "Chưa gồm phụ thu và hoạt động tùy chọn"; không có lịch → "Chưa thể tính" | *Tính toán* trong trình duyệt từ `price_vnd` | — | FR-08 (tổng tiền dự kiến theo số khách) |
| D23 | Điều kiện & chính sách | "Hủy & hoàn tiền": hủy miễn phí trước N giờ (nếu có), tỷ lệ hoàn tiền, điều khoản; ghi chú "Chính sách hủy phiên bản N · minh họa · Kiểm tra trước khi đặt". Không có → "Chưa cập nhật" | `cancellation_policies.free_before_hours`, `refund_percent`, `terms`, `version` của phiên bản lớn nhất | `NTK_sp_tour_cancellation_policy` | FR-16, FR-07 |
| D24 | Thẻ giá | Nút "Quay lại danh sách" | `url('/tours')` | — | Tiêu chí 3.2.6 |
| D25 | Lịch trình | Các điểm theo `stop_order`: số thứ tự, tên, thời gian (chỉ khi có), mô tả (chỉ khi có). Không có điểm nào → "Chưa cập nhật" | `itinerary_stops.stop_order`, `title`, `duration_minutes`, `description` | `NTK_sp_tour_itinerary_list` | FR-07 (lịch trình chi tiết) |
| D26 | Điều kiện & chính sách | "Độ tuổi": mỗi loại vé một dòng, ví dụ "Người lớn: Từ 12 tuổi", "Trẻ em: 4–11 tuổi" (bỏ trùng giữa các lịch); không có vé → "Chưa cập nhật" | `ticket_types.name`, `min_age`, `max_age` | `NMT_sp_tour_ticket_list` | FR-07 |
| D27 | Thông tin tour | "Điểm trả", "Phương tiện", "Hướng dẫn viên"; `NULL` → "Chưa cập nhật" | `tours.dropoff_point`, `transport`, `guide_info` | `NMT_sp_tour_detail` | FR-07 (điểm đón/trả, phương tiện) |
| D28 | Dịch vụ | "Không bao gồm": mỗi dòng của cột là một mục; `NULL` → "Chưa cập nhật" | `tours.excluded_summary` | `NMT_sp_tour_detail` | FR-08 (dịch vụ không bao gồm) |
| D29 | Điều kiện & chính sách | "Giấy tờ", "Ăn uống", "Voucher", "Đổi lịch"; `NULL` → "Chưa cập nhật" | `tours.document_terms`, `meal_terms`, `voucher_terms`, `reschedule_terms` | `NMT_sp_tour_detail` | FR-16 |
| D30 | Dịch vụ | "Phụ thu / hoạt động tùy chọn": hai nhóm "Phụ thu" rồi "Hoạt động tùy chọn". Mỗi dòng có tên, giá ("100.000đ / xe"; không có đơn vị → "120.000đ · đơn vị chưa cập nhật"; `price_vnd` `NULL` → "Giá: Chưa cập nhật") và điều kiện (chỉ khi có). Ghi chú "Tính riêng, không cộng vào giá tour và phần tạm tính." Tour không có dòng nào → "Chưa cập nhật"; một nhóm trống → nhóm đó hiện "Chưa cập nhật" | `tour_extras.kind`, `name`, `price_vnd`, `price_unit`, `conditions`, `sort_order` | `NTK_sp_tour_extra_list` | FR-08 (phụ phí đã biết) |

Dưới 992px, thẻ giá nằm sau nội dung và một thanh cố định cuối màn hình hiện giá "Từ …" cùng nút "Chọn lịch" để cuộn tới thẻ giá.

UUID sai định dạng, không tồn tại hoặc tour không công khai hiển thị trạng thái "Không tìm thấy tour" (HTTP 404): nhãn "Lỗi 404", câu "Tour bạn tìm không tồn tại hoặc đã ngừng hiển thị." và nút "Quay lại danh sách tour". Trạng thái này không đọc trường nào của tour.

Cột có trong database nhưng không hiển thị ở Sprint 3: `users.email`, `password_hash`, `name`, `phone`, `role` (tài khoản nhân viên và nhà cung cấp; khách không có tài khoản); `providers.contact_phone` (không được procedure trả về); `tours.approval_status`, `providers.approval_status`, `users.status`, `schedules.status`, `ticket_types.active`, `reviews.moderation_status` (chỉ dùng để lọc); `tour_images.sort_order`, `itinerary_stops.stop_order`, `tour_extras.sort_order` (chỉ dùng để sắp thứ tự; số thứ tự lịch trình trên trang đếm từ 1); `tours.source_url`, `verified_at`, `verification_status` (NFR-07, không được procedure trả về, dành cho trang quản trị sau này). Toàn bộ bảng `booking_lines`, `passengers`, `payments`, `payment_events`, `refunds`, `admin_logs` không hiển thị; `bookings` chỉ được đọc để lấy tên người đánh giá (`contact_name`) và ngày tham gia tour.

## 4. Quy ước định dạng hiển thị

| Dữ liệu | Lưu trong database | Hiển thị | Hàm PHP (`core/helpers.php`) |
| --- | --- | --- | --- |
| Giá | `BIGINT` (VND), ví dụ `650000` | `650.000đ` | `format_vnd()` |
| Điểm đánh giá | Tính ra `DECIMAL(2,1)`, ví dụ `4.8` | `4,8` | `format_rating()` |
| Thời lượng | `INT` phút, ví dụ `240`, `210`, `45` | `4 giờ`, `3 giờ 30 phút`, `45 phút` | `format_duration()` |
| Ngày | `DATETIME`, ví dụ `2026-10-24 17:00:00` | `24/10/2026` | `format_date()` |
| Giờ | `DATETIME` (hoặc `TIME`) | `17:00` | `format_time()` |
| Ngôn ngữ | `VARCHAR`, ví dụ `vi,en` | `Tiếng Việt / Anh` | `format_languages()` |
| Điểm đón | `ENUM` `meeting_point` / `hotel_pickup` | "Gặp tại điểm hẹn" / "Đón tại khách sạn"; trên thẻ: "Gặp tại {điểm hẹn}" | `pickup_label()`, `pickup_text()` |
| Loại vé | `VARCHAR`, ví dụ `adult`, `child` | `Người lớn`, `Trẻ em` | `ticket_label()` |
| Độ tuổi của vé | `INT` `min_age`, `max_age` (có thể `NULL`) | `4–11 tuổi`, `Từ 12 tuổi`, `Đến 3 tuổi` | `age_range_text()` |
| Nơi khởi hành | `pickup_mode`, `meeting_point` | Tên điểm hẹn / "Đón tại khách sạn" / "Chưa cập nhật" | `departure_text()` |
| Ảnh | `tour_images.url`: đường dẫn tương đối trong `public/assets/` (ví dụ `img/tours/hanoi-1.svg`) hoặc link `http(s)://` | URL dùng được ngay (đường dẫn tương đối đi qua `asset()`) | `image_src()` |
| Giá phụ thu / tùy chọn | `tour_extras.price_vnd` `BIGINT` (có thể `NULL`), `price_unit` | `100.000đ / xe`; không có đơn vị: `120.000đ · đơn vị chưa cập nhật`; `NULL`: "Giá: Chưa cập nhật" | `format_vnd()` |
| Danh sách nhiều dòng | `TEXT`, mỗi mục một dòng (`included_summary`, `excluded_summary`, các cột điều kiện) | Mỗi dòng một mục | `text_lines()` |
| Giá trị thiếu | `NULL` hoặc chuỗi rỗng | "Chưa cập nhật" | `or_missing()` |

Danh sách JSON trả sẵn cả giá trị gốc lẫn chuỗi đã định dạng (`price_text`, `rating_text`, `duration_text`, `languages_text`, `pickup_text`, `departure_text`, `next_departure_text`) để JavaScript không phải tự định dạng lại.

## 5. Đối chiếu với SRS v0.1

### 5.1. FR-06 – Xem danh sách tour

| Thông tin SRS yêu cầu | Trường | Mức đáp ứng |
| --- | --- | --- |
| Chỉ hiển thị tour được phép công khai | Tour `approved` của nhà cung cấp `approved`, tài khoản `active` | Đáp ứng |
| Tên tour | L02 | Đáp ứng |
| Địa điểm | L05 | Đáp ứng |
| Giá tham khảo | L11 | Đáp ứng (giá vé người lớn thấp nhất của lịch còn đặt được) |
| Thời lượng | L09 | Đáp ứng |
| Hình ảnh | L06 | Đáp ứng (ảnh bìa của chính tour; tour chưa có ảnh hiện "Chưa cập nhật ảnh") |
| Đánh giá nếu có | L07, L08 | Đáp ứng |
| Tình trạng tour nếu có dữ liệu | L11, L12 | Đáp ứng ở mức lần khởi hành gần nhất còn chỗ |

### 5.2. FR-07 – Xem chi tiết tour

| Thông tin SRS yêu cầu | Trường | Mức đáp ứng |
| --- | --- | --- |
| Tên tour và địa điểm | D01, D02, D04 | Đáp ứng |
| Lịch trình chi tiết | D25, D07 | Đáp ứng: các điểm lịch trình theo đúng thứ tự (bảng `itinerary_stops`) |
| Thời lượng và thời gian khởi hành | D08, D11, D19 | Đáp ứng |
| Điểm đón/trả và phương tiện nếu có | D13, D14, D27 | Đáp ứng: nơi khởi hành / điểm đón, điểm trả, phương tiện; chưa có bản đồ (FR-29) |
| Giá tour và phụ phí | D18, D20, D30 | Đáp ứng: giá theo lịch và loại vé; phụ thu và hoạt động tùy chọn có giá riêng |
| Dịch vụ bao gồm và không bao gồm | D12, D28 | Đáp ứng |
| Hình ảnh hoặc video | D06 | Một phần: ảnh của chính tour, chưa có video |
| Tình trạng chỗ | D11, D19, D21 | Một phần: xem FR-09 |
| Thông tin nhà cung cấp | D05, D17 | Đáp ứng ở mức tên và trạng thái đã duyệt; chưa hiện thông tin liên hệ |
| Đánh giá của khách hàng | D03, D15, D16 | Đáp ứng (chỉ xem đánh giá đã duyệt) |
| Chính sách hủy, đổi và hoàn tiền | D23, D29 | Đáp ứng: hủy và hoàn tiền theo phiên bản mới nhất; đổi lịch, giấy tờ, ăn uống, voucher theo cột của tour |

### 5.3. Các yêu cầu liên quan khác

| Yêu cầu | Nội dung SRS | Mức đáp ứng ở Sprint 3 | Trường / ghi chú |
| --- | --- | --- | --- |
| FR-04 | Tìm tour theo tên, địa điểm hoặc từ khóa liên quan | Đáp ứng mức cơ bản | C01: tìm trên tên tour, mô tả, điểm đến, nhà tổ chức; C04; trạng thái rỗng. |
| FR-05 | Lọc theo địa điểm, ngày đi, giá, loại hình, thời lượng, tiện ích; sắp xếp | Một phần | Có lọc điểm đến (C02) và 4 kiểu sắp xếp (C03). Các bộ lọc còn lại ở mục 6.2. |
| FR-08 | Giá mỗi người; bao gồm/không gồm; phụ phí đã biết; tổng tiền dự kiến; báo chi phí phát sinh trước khi xác nhận | Một phần | D18, D20, D12, D28, D30, D22. Giá theo loại vé (người lớn, trẻ em) của từng lịch; phụ thu, tùy chọn tách riêng. Bước "trước khi xác nhận đặt" thuộc quy trình đặt tour (FR-11), chưa làm. |
| FR-09 | Tình trạng còn chỗ, hết chỗ hoặc không khả dụng theo ngày | Một phần | Chỉ liệt kê lịch còn đặt được kèm số chỗ còn lại (D11, D19), giới hạn số khách theo số chỗ còn (D21), thông báo khi không có lịch. Lịch hết chỗ hoặc bị hủy không hiển thị. |
| FR-16 | Công khai chính sách hủy/đổi trước khi đặt | Đáp ứng mức xem | D23: phiên bản chính sách mới nhất của tour. |
| BR-01 | Chỉ tour đủ điều kiện công khai mới hiển thị | Đáp ứng | Áp dụng trong mọi procedure, kể cả danh sách con. |
| NFR-07, NFR-08 | Dùng được trên máy tính và điện thoại, giao diện đáp ứng | Đáp ứng mức cơ bản | Bootstrap 4.6.2; dưới 992px ẩn cột phải, thanh bên thu gọn và mở bằng nút "Menu" trên header. |
| NFR-16 | Thông báo lỗi dễ hiểu, không lộ thông tin kỹ thuật | Đáp ứng | Xem [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md), mục 5–6. |

## 6. Quyết định phạm vi Sprint 3

### 6.1. Thuộc Sprint 3

| Hạng mục | Yêu cầu | Mức độ |
| --- | --- | --- |
| Danh sách tour đọc từ MySQL, có trạng thái đang tải, rỗng, lỗi | FR-06, NFR-16 | Đầy đủ theo mục 2 |
| Chi tiết tour theo UUID, trạng thái không tìm thấy, nút quay lại danh sách | FR-07 | Đầy đủ theo mục 3, trừ video và bản đồ |
| Tìm kiếm theo từ khóa | FR-04 | Mức nhẹ: một ô tìm kiếm, tìm "có chứa" trên 4 trường |
| Lọc theo điểm đến | FR-05 | Mức nhẹ: một điểm đến mỗi lần, chọn theo tên |
| Sắp xếp: Nổi bật, Sắp khởi hành, Giá tăng/giảm | FR-05 | Đầy đủ cho 4 kiểu; sắp theo giá có dòng ngăn cách trước tour chưa có giá |
| Hiển thị giá minh bạch: giá từ, giá theo loại vé của từng lịch, mục bao gồm, tạm tính theo số vé | FR-08 | Chỉ để xem; tạm tính trong trình duyệt, không gửi đi đâu |
| Ảnh và lịch trình của chính tour; các mục Thông tin tour, Dịch vụ (kèm phụ thu / tùy chọn), Điều kiện & chính sách | FR-07, FR-08, FR-16 | Trường thiếu hiện "Chưa cập nhật" |
| Lịch khởi hành còn đặt được, số chỗ còn và giới hạn số khách | FR-09 | Mức xem thông tin |
| Hiển thị đánh giá đã duyệt | FR-07 | Chỉ xem, tối đa 5 đánh giá |
| Chính sách hủy theo phiên bản mới nhất | FR-16 | Chỉ xem |
| Giao diện đáp ứng desktop và mobile cơ bản | NFR-07, NFR-08 | Theo tiêu chí 3.2.5 |

### 6.2. Không thuộc Sprint 3 – chuyển về Product Backlog

Quy tắc chung cho mọi nút của chức năng chưa làm nhưng có trên wireframe: vẫn hiển thị để giữ bố cục, nhưng ở trạng thái `disabled`, màu nhạt, có `title="Sắp có"` và nhãn "Sắp có" khi đủ chỗ; không dẫn tới trang nào.

| Hạng mục | Yêu cầu | Lý do chưa làm | Thể hiện trên giao diện Sprint 3 |
| --- | --- | --- | --- |
| Lọc theo ngày đi | FR-05 | Cần tìm theo lịch khởi hành và bộ chọn ngày; Sprint 3 ưu tiên luồng danh sách → chi tiết chạy ổn định. | Nút "Ngày đi" bị khóa, nhãn "Sắp có". |
| Bộ lọc nâng cao: khoảng giá, loại hình, thời lượng, tiện ích | FR-05 | Cần thiết kế giao diện bộ lọc nhiều điều kiện; lược đồ chưa có dữ liệu loại hình và tiện ích. | Nút "Bộ lọc" bị khóa. |
| So sánh tour | FR-10 (wireframe UIEx3; bảng FR: FR-15) | Chưa làm ở Sprint 3. Việc so sánh diễn ra trong phiên duyệt web nên lược đồ không có bảng so sánh. | "Thêm vào so sánh" trên thẻ tour và thẻ giá bị khóa; khung "Tour đang so sánh" ghi "Tính năng so sánh sẽ có ở Sprint sau"; mục "So sánh tour" ở thanh bên bị khóa. |
| Đặt tour và xác nhận đặt tour | SRS FR-11, FR-12 (wireframe UIEx4); bảng FR: FR-08, FR-09, FR-11, FR-14 | Là hạng mục MUST của MVP tổng thể nhưng chưa thuộc increment Sprint 3. Khách không cần tài khoản: `bookings` lưu họ tên, email, số điện thoại; `passengers` lưu người tham gia; hệ thống sinh `bookings.code` để tra cứu. Các bảng `bookings`, `booking_lines`, `passengers` đã tạo sẵn. | Nút "Đặt tour" bị khóa; ô chọn lịch và số vé chỉ dùng để xem tạm tính. |
| Thanh toán trực tuyến | SRS FR-13; bảng FR: FR-17 | Là hạng mục MUST của MVP tổng thể nhưng chưa thuộc increment Sprint 3. Sau khi booking được nhân viên xác nhận và chuyển sang `awaiting_payment`, khách tra cứu bằng mã booking + email/số điện thoại rồi thanh toán; `payments.booking_id` liên kết giao dịch với booking mà không cần tài khoản khách. VNPay chỉ dùng sandbox; VietQR do quản trị viên đối chiếu. Các bảng `payments`, `payment_events` đã tạo sẵn. | Không có route hoặc nút thanh toán trong Sprint 3. |
| Tra cứu đơn, hủy đơn, hoàn tiền | SRS FR-14, FR-15, FR-25; bảng FR: FR-11, FR-12, FR-17 | Phụ thuộc chức năng đặt tour. Khách tra cứu đơn bằng mã đơn kèm email hoặc số điện thoại, không cần tài khoản. Đổi/hủy thuộc giai đoạn sau; bảng `refunds` đã tạo sẵn để lưu kết quả hoàn tiền. | Chưa có trang tra cứu đơn. |
| Đăng ký, đăng nhập, hồ sơ khách hàng | SRS FR-01 – FR-03 | Bảng FR tuần 2 xếp **tài khoản khách hàng** vào "Won't Have", không xếp tác nhân khách hàng, đặt tour hay thanh toán vào nhóm này. Nhân viên và nhà cung cấp vẫn có thể dùng tài khoản trong bảng `users`; khách thao tác theo luồng guest checkout. | Không có nút đăng nhập hay ảnh đại diện khách hàng. |
| Gửi đánh giá, kiểm duyệt đánh giá | SRS FR-17, FR-24; bảng FR: FR-16 | Không cần tài khoản khách: có thể xác thực quyền đánh giá bằng booking đã hoàn thành (`reviews.booking_id`). Tuy nhiên Sprint 3 chưa có biểu mẫu gửi và màn hình kiểm duyệt, chỉ hiển thị đánh giá mẫu đã duyệt. | Không có biểu mẫu gửi đánh giá. |
| Chức năng cá nhân hóa cần tài khoản khách: Thông báo, Tour đã lưu / Lưu tour, danh sách "Đặt chỗ của tôi", Cộng đồng, Tin nhắn / Nhắn tin, Đang theo dõi, Thích / Bình luận / Chia sẻ / Lưu | SRS FR-26, FR-28 (bảng FR không có các mục này) | Bảng FR xếp tài khoản khách vào "Won't Have" và không có FR thông báo. Lược đồ gộp đã bỏ 7 bảng của ERD trang 02 phục vụ các chức năng này ([02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md), mục 1.2). Tra cứu một booking bằng mã + thông tin liên hệ là luồng riêng và không cần tài khoản. | Đã gỡ khỏi giao diện, không còn nút bị khóa. Khung "Gợi ý từ cộng đồng" ở trang danh sách cũng đã bỏ. |
| Hỗ trợ khách hàng; Trợ giúp, Điều khoản | FR-27 | Chưa có quy trình hỗ trợ và nội dung điều khoản. | "Trợ giúp", "Điều khoản" bị khóa. |
| Hiển thị thông tin liên hệ nhà cung cấp | FR-07, FR-27 | Database đã có `providers.contact_phone` nhưng chưa hiển thị khi chưa có quy trình hỗ trợ khách hàng. | Hộp nhà tổ chức chỉ có tên và nhãn đã duyệt. |
| Ảnh chụp thật của tour, video tour | FR-07 | `tour_images` hiện chứa ảnh SVG minh họa; lược đồ không có bảng video. | Thư viện tối đa 3 ảnh của chính tour. |
| Gói lựa chọn của tour | Bảng FR: FR-07 | Bảng FR còn CLARIFY thuộc tính nào tạo thành gói; lược đồ chưa có bảng gói ([02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md), mục 12). | Không hiển thị. |
| Nguồn tham khảo, ngày xác minh, trạng thái xác minh | Bảng FR: NFR-07 | Đã có cột `source_url`, `verified_at`, `verification_status`, nhưng chỉ trang quản trị (chưa làm) mới dùng. Dữ liệu mẫu để `NULL` / `unverified`, không gán nguồn hay ngày giả. | Không hiển thị. |
| Bản đồ vị trí, điểm đón | FR-29 | Phụ thuộc dịch vụ bản đồ bên ngoài. | Điểm đón ở dạng văn bản. |
| Hiển thị lịch hết chỗ/bị hủy kèm nhãn; kiểm tra chỗ theo thời gian thực | FR-09 | Số chỗ chỉ thay đổi khi có chức năng đặt tour. | Lịch hết chỗ hoặc bị hủy không xuất hiện. |
| Tính phí hủy theo đơn cụ thể | FR-15, FR-16 | Cần đơn đặt thật và quy trình hủy đơn ở Sprint sau. | Chính sách chỉ hiển thị, không tính tiền hoàn. |
| Phân trang hoặc tải thêm khi cuộn | FR-06 | Dữ liệu mẫu có 9 tour công khai, trả về một lần. | Cuối danh sách hiện "Bạn đã xem hết N tour phù hợp." thay cho dòng "Tiếp tục cuộn để khám phá thêm tour" trên wireframe. |
| Gợi ý cá nhân hóa, gợi ý bằng AI, chatbot | SRS mục 2.2.2 | Ngoài phạm vi phiên bản đầu. | Tab "Nổi bật" chỉ sắp xếp theo đánh giá. |
| Quản lý tour, lịch khởi hành, đơn đặt cho nhà cung cấp | FR-18 – FR-20 | Ngoài phạm vi Sprint 3. | Dữ liệu được nạp bằng script `02_seed.sql`. |
| Chức năng quản trị (Admin), duyệt nhà cung cấp và tour | FR-21 – FR-25, FR-30 | Ngoài phạm vi Sprint 3. | Không có trang quản trị; trạng thái duyệt được đặt sẵn trong dữ liệu mẫu. |
| Ứng dụng di động riêng | SRS mục 7.3 | Ngoài phạm vi phiên bản đầu. | Website đáp ứng trên trình duyệt điện thoại. |

## 7. Đối chiếu tiêu chí nghiệm thu 3.1.1

| Nội dung tiêu chí | Đáp ứng tại |
| --- | --- |
| Có danh mục field Tour List | Mục 2 (L01 – L14, C01 – C04, trạng thái màn hình) |
| Có danh mục field Tour Detail | Mục 3 (D01 – D30, trạng thái không tìm thấy) |
| Danh mục được đối chiếu với yêu cầu Sprint 2 | Cột SRS ở mục 2–3 và bảng đối chiếu ở mục 5 |
| Có ghi quyết định những gì thuộc/không thuộc Sprint 3 | Mục 6.1 và 6.2 |

Khi cần thêm, bớt hoặc đổi tên một trường, người đề xuất cập nhật tài liệu này, [02 – Lược đồ dữ liệu](02-luoc-do-du-lieu.md) và [03 – Route và quy ước lỗi](03-route-va-quy-uoc-loi.md) trong cùng một lần thay đổi, đồng thời báo cho QA để cập nhật test case.
