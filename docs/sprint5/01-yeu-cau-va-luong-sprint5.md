# Yêu cầu và luồng Sprint 5

| Mục | Nội dung |
| --- | --- |
| Sprint | Sprint 5 – So sánh tour, đổi/hủy và kiểm thử hệ thống (06/11 – 12/11/2026) |
| WBS | US04-S5-01 → US04-S5-03, US14-S5-01 → US14-S5-03, US06-S5-01, US07-S5-01 |
| Người phụ trách | Nguyễn Tuấn Khôi |
| Căn cứ | Gantt chart QLDA_LocalTour (Sprint 5); bảng FR (FR-07 gói lựa chọn, FR-12 đổi/hủy, FR-13 quản trị tour, FR-15 so sánh); Báo cáo Sprint 4 mục 3 và 8.1 (việc chuyển sang Sprint 5); wireframe `docs/diagram/wireframe-3-so-sanh-tour_localtour.png` |
| Tài liệu liên quan | [02 – Cấu trúc dữ liệu Sprint 5](02-cau-truc-du-lieu-sprint5.md), [03 – Test Plan và RTM](03-test-plan-rtm.md), `src/README.md` (Bước 11), `src/database/README.md` |
| Trạng thái | **Đã chốt.** |

## 1. Phạm vi Sprint 5

| WBS | Nội dung | Người làm | Ngày |
| --- | --- | --- | --- |
| US04-S5-01 | Giao diện so sánh 2–3 tour: chọn / bỏ tour, tối đa 3 tour (FR-15). | Khôi | 06/11 |
| US04-S5-02 | Chuẩn hóa dữ liệu so sánh: giá theo đơn vị, lịch trình, chính sách; ô thiếu ghi “Chưa cập nhật”. | Thức | 06–07/11 |
| US04-S5-03 | Tích hợp và kiểm tra so sánh: dữ liệu thật, chặn quá 3 tour, dữ liệu thiếu / khác đơn vị. | Khôi, Phong | 08–09/11 |
| US14-S5-01 | Form yêu cầu đổi ngày / hủy tour theo chính sách của đúng tour, thông báo lỗi (FR-12). | Khôi | 06–07/11 |
| US14-S5-02 | Lưu yêu cầu: kiểm tra quyền, chính sách, trạng thái; lưu yêu cầu và lịch sử; chưa tự động hoàn tiền. | Phong | 07–08/11 |
| US14-S5-03 | Xử lý yêu cầu thủ công ở trang quản trị, có trạng thái và lịch sử. | Phong, Khôi | 09–10/11 |
| US06-S5-01 | Hoàn thiện phần Booking còn tồn: gói lựa chọn (FR-07). | Phong, Khôi | 06–07/11 |
| US07-S5-01 | Hoàn thiện quản trị tour còn tồn (FR-13): ảnh, lịch trình, dịch vụ, chính sách hủy trên giao diện; xóa tour, xóa đơn vị tổ chức. | Thức, Khôi | 08–09/11 |

Kiểm thử Sprint 5 (Test Plan / RTM và dữ liệu kiểm thử 06–07/11, E2E 08–09/11, kiểm tra phân quyền và dữ liệu nhập 08–09/11, sửa lỗi Critical / High 10–11/11, retest 11–12/11, System Test Exit 12/11) ghi ở [03 – Test Plan và RTM](03-test-plan-rtm.md).

Chưa làm:

- Tự động hoàn tiền: hệ thống chỉ ghi khoản hoàn `requested`, LocalTour chuyển khoản lại thủ công.
- Đổi số người hoặc đổi gói của đơn: yêu cầu đổi ngày giữ nguyên số khách, gói và tổng tiền.
- Email thông báo: khách xem kết quả ở trang đơn và trang “Đổi ngày / hủy tour”.
- Lưu danh sách so sánh theo tài khoản: danh sách đang lưu ở trình duyệt; bảng `comparisons`, `comparison_tours` chưa dùng.
- Gửi đánh giá tour (FR-16) và nhãn “Thông tin chưa được xác minh” (NFR-07): vẫn ở backlog.
- Thích, Bình luận, Chia sẻ, Lưu tour: vẫn tắt, nhãn “Sắp có”.

## 2. So sánh tour (US04, FR-15)

1. Thẻ tour ở bảng tin (`/tours`) và trang chi tiết tour có nút **Thêm vào so sánh**; bấm lại (nhãn “Đã thêm vào so sánh”) để bỏ. Không cần đăng nhập.
2. Bảng tin có khung “Tour đang so sánh” (3 ô, nút bỏ từng tour, **So sánh tour**, “Xóa danh sách”); màn hình nhỏ có thanh “N/3 tour đang so sánh” ở dưới. Menu bên có mục “So sánh tour”.
3. Đủ 2 tour thì **So sánh tour** mở `/compare?ids=<mã 1>,<mã 2>,<mã 3>`; chưa đủ thì báo “Chọn ít nhất 2 tour để so sánh.”
4. Trang `/compare` đặt mỗi tour một cột: ảnh, tên, điểm đến · loại hình, đơn vị tổ chức, nút **Xem chi tiết** và **Bỏ**; còn chỗ thì có cột “Thêm tour” về bảng tin. Màn hình nhỏ cuộn ngang bảng.
5. Mở `/compare` không kèm mã mà trình duyệt đã có danh sách → chuyển sang danh sách đó. Có mã → trình duyệt lưu lại danh sách server trả về (tour bị ẩn đã bỏ).

| Nhóm | Dòng so sánh (`CompareModel::rows()`) |
| --- | --- |
| Giá và lịch | Giá người lớn, Giá trẻ em, Gói tour, Lịch gần nhất |
| Thông tin tour | Thời lượng, Quy mô nhóm, Ngôn ngữ, Điểm khởi hành, Điểm kết thúc, Phương tiện, Hướng dẫn viên, Ăn uống, Đánh giá |
| Lịch trình và dịch vụ | Lịch trình, Bao gồm, Không bao gồm, Phụ thu / tùy chọn |
| Chính sách | Hủy tour, Đổi lịch |

| # | Quy tắc |
| --- | --- |
| 1 | Tối đa 3 tour, ít nhất 2 tour mới hiện bảng. Thêm tour thứ 4 bị chặn: “Chỉ so sánh tối đa 3 tour. Bỏ bớt một tour trước khi thêm tour khác.” |
| 2 | Danh sách lưu ở trình duyệt (`localStorage`, khóa `localtour.compare`: mã, tên, ảnh). Trình duyệt chặn `localStorage` thì chỉ giữ trong trang đang mở. Tab khác đổi danh sách thì nút và khung tự cập nhật. |
| 3 | Server kiểm tra lại danh sách: chỉ đọc 400 ký tự đầu của `ids`; mã sai dạng, trùng, tour không có hoặc không công khai bị bỏ, trang báo “N tour không còn hiển thị hoặc không hợp lệ nên đã được bỏ khỏi so sánh.” |
| 4 | Quá 3 mã: trang lấy 3 tour đầu và báo “Chỉ so sánh tối đa 3 tour. Trang đang hiển thị 3 tour đầu tiên bạn chọn.”; `/api/compare` trả 422. Dưới 2 tour: trang hiện “Cần ít nhất 2 tour để so sánh” (0 tour: “Chưa chọn tour để so sánh”) và nút “Chọn tour ở bảng tin”. |
| 5 | Cùng đơn vị: giá theo mỗi người lớn / trẻ em, thời lượng theo giờ phút, quy mô theo số khách, chính sách hủy theo số giờ trước khởi hành và phần trăm hoàn. Giá là giá thấp nhất của các lịch còn nhận đặt; tour có gói lấy gói rẻ nhất, từ 2 gói trở lên ghi “Từ …”. |
| 6 | Ô thiếu dữ liệu ghi “Chưa cập nhật” (chữ nhạt), không tự suy diễn. Có giá người lớn nhưng không bán vé trẻ em ghi “Không bán vé trẻ em”; tour không chia gói ghi “Một gói chung”; không có phụ thu ghi “Không có”; chưa có lịch ghi “Chưa có lịch mở bán”; chưa có đánh giá ghi “Chưa có đánh giá”. |
| 7 | Dữ liệu đọc từ database qua `NMT_sp_tour_compare`, mỗi tour một dòng theo đúng thứ tự khách chọn; chính sách hủy là phiên bản mới nhất của tour. |

Khác wireframe 3: chưa có ô chọn ngày và số khách để tính “Tổng cho N người”, nút “Chỉ xem điểm khác nhau” và “Chọn tour này”; khách đặt tour từ nút **Xem chi tiết**. Hủy miễn phí ghi theo số giờ trước khởi hành, không ghi ngày giờ cụ thể vì bảng không gắn với một lịch.

## 3. Gói tour (US06-S5-01, FR-07)

Tồn từ Sprint 4: chưa có bảng gói, tour mẫu chưa có gói, đơn đặt theo loại vé của lịch. Sprint 5 thêm bảng `tour_packages` và cột `bookings.package_id`, `bookings.package_name`.

| # | Quy tắc |
| --- | --- |
| 1 | Gói phân theo phương tiện hoặc tuyến điểm; có tên, mô tả, giá người lớn và giá trẻ em riêng (trống = gói không bán vé trẻ em). Lịch khởi hành, lịch trình và phụ thu dùng chung với tour; điểm khác ghi trong mô tả gói. |
| 2 | Giá gói lưu trong `tour_packages`, áp dụng cho mọi lịch của tour; không thêm cột `ticket_types.package_id` như bản thiết kế ở [Sprint 4 – 01](../sprint4/01-ra-soat-m3-va-ton-dong.md), mục 3. |
| 3 | Tour có ít nhất một gói đang bán thì khách phải chọn một gói: trang chi tiết có mục “Gói tour”, thẻ đặt tour có ô chọn gói và tạm tính theo gói; link đặt tour mang `package_id`. Mã gói sai hoặc không có thì trang đặt tour chọn gói đầu tiên. |
| 4 | Server tính lại giá theo gói: vé trẻ em lấy giá trẻ em của gói, vé khác lấy giá người lớn. Gói vừa ngừng bán hoặc không thuộc tour, tour vừa có / hết gói, gói không bán vé trẻ em → 409 `package_changed` “Gói tour vừa thay đổi (gói ngừng bán, tour đổi danh sách gói hoặc gói không bán vé trẻ em). Vui lòng tải lại trang để chọn lại.”, không tạo đơn. `package_id` sai dạng → 422 “Trang đặt tour đã cũ, vui lòng tải lại trang.” |
| 5 | Mã và tên gói chụp vào đơn, giá chụp vào `booking_lines`; trang đơn của khách và trang quản trị ghi tên gói. Sửa tên / giá gói sau đó không đổi đơn cũ. |
| 6 | Giá “Từ” của tour có gói = giá người lớn thấp nhất của các gói đang bán (vẫn cần lịch đặt được). |
| 7 | Quản trị viên (chi tiết tour → “Gói tour”): thêm, sửa, ngừng bán / bán lại. Tên 1–100 ký tự, không trùng trong tour (409 “Tour đã có gói cùng tên.”); mô tả tối đa 500 ký tự; giá 1–100.000.000đ (“Giá phải lớn hơn 0đ và không quá 100.000.000đ.”); thứ tự 0–999. Gói không xóa được, chỉ bỏ chọn “Đang bán”. Mỗi lần lưu ghi `admin_logs` (`package_create`, `package_update`). |

Dữ liệu mẫu: tour 3 “Phố cổ theo cách của bạn” có 3 gói “Kiến trúc và phố nghề” 900.000đ, “Đền chùa và tín ngưỡng” 950.000đ, “Góc ảnh phố cổ” 1.200.000đ, đều không bán vé trẻ em. Chọn “Đền chùa và tín ngưỡng”, 2 người lớn → tạm tính 1.900.000đ. Các tour khác không có gói, đặt như Sprint 4.

## 4. Đổi ngày / hủy tour (US14, FR-12)

### 4.1. Luồng khách hàng

1. “Đơn của tôi” → mở đơn. Đơn gửi được yêu cầu có thẻ **Đổi ngày / hủy tour**; đơn đang có yêu cầu chờ thì thẻ báo “Bạn đã gửi yêu cầu … LocalTour đang xử lý; đơn giữ nguyên cho tới khi có kết quả.” và nút **Xem yêu cầu**.
2. Trang `/bookings/{mã đơn}/change`: chọn **Hủy tour** (ghi số dự kiến hoàn, hoặc “Đơn chưa thanh toán nên không có tiền hoàn.”) hoặc **Đổi sang ngày khác** (ô “Ngày muốn đổi sang” chỉ hiện khi chọn đổi ngày và chỉ liệt kê lịch còn đủ chỗ cho số khách của đơn và có đủ loại vé của đơn); nhập **Lý do** (bắt buộc, đếm ký tự /500). Cột phải: chính sách hủy của đơn (phiên bản lúc đặt), mốc hủy miễn phí, đang trong / đã qua thời gian hủy miễn phí, tiền đã thanh toán, “Dự kiến hoàn nếu hủy bây giờ”.
3. **Gửi yêu cầu**: server kiểm tra lại, lưu yêu cầu “Chờ xử lý”, ghi lịch sử đơn (`booking_events` `cancel_requested` / `change_requested`), quay lại trang với “Đã gửi yêu cầu. …”. Gửi yêu cầu chưa đổi đơn và chưa trả chỗ.
4. Mục “Yêu cầu đã gửi” liệt kê mọi yêu cầu của đơn, mới nhất trước: loại, trạng thái, lúc gửi / lúc xử lý, lý do, số dự kiến hoàn hoặc số tiền hoàn, phản hồi của LocalTour.

Điều kiện gửi: tài khoản khách hàng đang hoạt động và là chủ đơn; đơn “Chờ xác nhận”, “Chờ thanh toán” hoặc “Đã xác nhận”; chưa tới giờ khởi hành; đơn chưa có yêu cầu chờ xử lý (khóa dòng đơn khi kiểm tra). Đổi ngày: lịch mới cùng tour, đang mở bán, chưa khởi hành, khác lịch hiện tại, còn đủ chỗ cho số khách của đơn và có loại vé đang bán cùng tên với vé của đơn (người lớn / trẻ em). Chưa đăng nhập → `/login?next=<trang đang mở>`.

### 4.2. Luồng quản trị viên

Gantt ghi “nhân viên” xử lý; theo CR1 hệ thống không còn vai trò nhân viên hỗ trợ (ISS-07, 04/11) nên quản trị viên xử lý.

1. Menu **Đổi ngày / hủy tour** → `/admin/change-requests`: lọc “Chờ xử lý” (mặc định), “Đã đồng ý”, “Đã từ chối”, “Tất cả”; yêu cầu chờ xử lý lên trước (gửi sớm trước), tối đa 200 dòng.
2. Chi tiết yêu cầu: lý do của khách, khách hàng, người liên hệ, tour, gói, ngày đang đặt, số khách, tổng tiền, trạng thái đơn; chính sách hủy chụp lúc gửi và số dự kiến hoàn; lịch muốn đổi sang; các yêu cầu khác của đơn.
3. Form **Xử lý**: Đồng ý / Từ chối; **Số tiền hoàn** (chỉ khi đồng ý hủy; trống = số dự kiến, không vượt tiền đã trả hiện tại; nhập tay từ 0đ đến tiền đã trả); **Ghi chú gửi khách** (bắt buộc, tối đa 500 ký tự). Mỗi yêu cầu chỉ xử lý một lần.
4. Đồng ý hủy bị chặn khi đơn còn chuyển khoản VietQR chờ đối chiếu: đối chiếu ở “Đối chiếu thanh toán” trước.

Kết quả ghi vào `admin_logs` của đơn (`cancel_approved`, `cancel_rejected`, `change_approved`, `change_rejected`, `refund_requested`), hiện trong lịch sử đơn ở trang khách và trang quản trị. Đơn bị đóng theo đường khác khi yêu cầu còn chờ (quá hạn giữ chỗ, quản trị viên hủy ở “Yêu cầu đặt tour”) thì yêu cầu vẫn “Chờ xử lý” và chỉ từ chối được.

### 4.3. Số tiền dự kiến hoàn

- Tiền đã trả = tổng các khoản thanh toán `paid` của đơn; đơn chưa thanh toán hoàn 0đ.
- Chính sách = phiên bản lưu cùng đơn (`bookings.policy_version`), không phải phiên bản mới nhất của tour.
- Mốc hủy miễn phí = giờ khởi hành − `free_before_hours`. Gửi trước mốc → hoàn 100% tiền đã trả; sau mốc → hoàn `refund_percent` %; không có mốc (`free_before_hours` trống) → luôn hoàn `refund_percent` %; đơn không có chính sách → 0đ, LocalTour xem xét từng trường hợp. Làm tròn xuống tới đồng.
- Lúc gửi, yêu cầu chụp lại phiên bản chính sách, số giờ, phần trăm, có trong mốc miễn phí hay không, tiền đã trả và số dự kiến hoàn; quản trị viên xử lý muộn vẫn dùng số đã chụp.
- Ví dụ: đơn 1.440.000đ đã thanh toán, chính sách “Hủy miễn phí trước giờ khởi hành 24 giờ. Sau thời điểm này không hoàn tiền.”: gửi trước mốc → dự kiến 1.440.000đ; gửi sau mốc → 0đ.
- Đồng ý hủy chỉ ghi khoản hoàn (`refunds`, trạng thái `requested`); LocalTour chuyển khoản lại thủ công, hệ thống không gọi hoàn tiền VNPay.

### 4.4. Trạng thái yêu cầu

| Trạng thái | Nhãn | Ảnh hưởng tới đơn |
| --- | --- | --- |
| `pending` | Chờ xử lý | Giữ nguyên. Mỗi đơn chỉ có một yêu cầu `pending`. |
| `rejected` | Đã từ chối | Giữ nguyên. |
| `approved` (hủy) | Đã đồng ý | Đơn “Đã hủy”; đơn đang giữ chỗ (“Chờ thanh toán”, “Đã xác nhận”) trả lại chỗ, lịch đầy mở lại; khoản thanh toán chưa xong (`pending`, `processing`) chuyển `failed`; số tiền hoàn > 0 thì ghi `refunds` `requested`. |
| `approved` (đổi ngày) | Đã đồng ý | Đơn sang lịch mới, giữ trạng thái, số khách, gói và tổng tiền; dòng vé đổi sang loại vé đang bán cùng tên của lịch mới; đơn đang giữ chỗ thì trả chỗ lịch cũ, trừ chỗ lịch mới. |

### 4.5. Kết quả và thông báo

Khách gửi yêu cầu (`ChangeRequestController@store`):

| Kết quả | HTTP | Thông báo |
| --- | --- | --- |
| Đã lưu | 303 | Về trang đổi / hủy: “Đã gửi yêu cầu. LocalTour sẽ xử lý và cập nhật kết quả trên trang này. Tiền hoàn (nếu có) được LocalTour chuyển lại thủ công.” |
| Thiếu loại, ngày hoặc lý do | 422 | “Vui lòng chọn hủy tour hoặc đổi ngày.” / “Vui lòng chọn ngày muốn đổi sang.” / “Vui lòng nhập lý do.” / “Lý do tối đa 500 ký tự.” |
| Đơn đã đóng (`status`, `not_allowed`) | 409 | “Đơn đã đóng (bị từ chối, đã hủy hoặc đã hoàn thành) nên không đổi ngày hay hủy được nữa.” |
| `departed` | 409 | “Tour đã khởi hành nên không đổi ngày hay hủy được nữa.” |
| `pending_exists` | 409 | “Đơn đang có một yêu cầu chờ LocalTour xử lý. Vui lòng chờ kết quả trước khi gửi yêu cầu mới.” |
| `schedule_unavailable` | 409 | “Lịch này không còn nhận khách, vui lòng chọn ngày khác.” |
| `no_seats` | 409 | “Lịch này không còn đủ chỗ cho N khách, vui lòng chọn ngày khác.” |
| Thiếu / sai `_csrf` | 403 | “Phiên làm việc đã hết hạn, vui lòng thử lại.” |
| Mã đơn sai, không có hoặc của tài khoản khác | 404 | “Không tìm thấy đơn” |

Quản trị viên xử lý (`AdminChangeRequestController@decide`):

| Kết quả | HTTP | Thông báo |
| --- | --- | --- |
| Đã xử lý | 303 | “Đã đồng ý yêu cầu và cập nhật đơn.” / “Đã từ chối yêu cầu. Đơn giữ nguyên.” |
| Dữ liệu sai | 422 | “Vui lòng chọn đồng ý hoặc từ chối.” / “Vui lòng nhập ghi chú gửi khách (lý do đồng ý / từ chối).” / “Số tiền hoàn từ 0đ đến số khách đã thanh toán (…).” |
| `already_handled` | 409 | “Yêu cầu này đã được xử lý trước đó.” |
| `booking_closed` | 409 | “Đơn đã đóng (bị từ chối, đã hủy hoặc đã hoàn thành) nên chỉ có thể từ chối yêu cầu.” |
| `payment_in_review` | 409 | “Đơn còn khoản chuyển khoản chờ đối chiếu. Hãy đối chiếu ở trang "Đối chiếu thanh toán" trước khi đồng ý hủy.” |
| `schedule_unavailable` | 409 | “Lịch khách muốn đổi sang không còn nhận khách (đã hủy, đã đầy hoặc đã khởi hành). Hãy từ chối và báo khách chọn ngày khác.” |
| `no_seats` | 409 | “Lịch khách muốn đổi sang không còn đủ chỗ cho N khách.” |
| `tickets_missing` | 409 | “Lịch khách muốn đổi sang không bán đủ các loại vé của đơn (ví dụ vé trẻ em). Hãy thêm giá vé cho lịch đó hoặc từ chối yêu cầu.” |

## 5. Hoàn thiện quản trị tour (US07-S5-01, FR-13)

Tồn từ Sprint 4: chưa có xóa; ảnh, lịch trình, dịch vụ, chính sách hủy vẫn nhập bằng SQL. Sprint 5 thêm trang “Ảnh, lịch trình, dịch vụ và chính sách” (`/admin/tours/{id}/content`, mở từ chi tiết tour ở trang quản trị) và ô xóa đơn vị tổ chức.

| Phần | Quy tắc |
| --- | --- |
| Ảnh | Tối đa 12 ảnh / tour. Tải file JPG, PNG hoặc WebP tối đa 2 MB (kiểm tra nội dung file thật, lưu tên ngẫu nhiên trong `src/public/assets/uploads/tours/`, không có trong Git) hoặc dán đường dẫn `https://` tối đa 255 ký tự; mô tả ảnh tối đa 255 ký tự. Ảnh bìa là ảnh đứng đầu, “Đặt làm ảnh bìa” đưa ảnh lên đầu. Xóa ảnh thì xóa cả file đã tải lên. |
| Lịch trình | Tối đa 30 mục. Giờ dạng HH:MM, không bắt buộc; nội dung 1–255 ký tự; thứ tự 0–999 (thêm mới mà để trống thì xếp cuối). Thêm, sửa (`?edit_item=`), xóa. |
| Dịch vụ | Bao gồm hoặc không bao gồm; tên 1–150 ký tự; tối đa 40 mục. Thêm, xóa. |
| Chính sách hủy | Lưu = thêm phiên bản mới (`version + 1`), không sửa phiên bản cũ; đơn đã đặt giữ phiên bản lúc đặt. Số giờ hủy miễn phí 0–720 (trống = không có mốc), phần trăm hoàn 0–100, nội dung cho khách bắt buộc, tối đa 2000 ký tự. Giống hệt phiên bản mới nhất → “Không có thay đổi nào.” |
| Xóa tour | Bắt buộc tick xác nhận. Tour chưa có đơn → xóa hẳn cùng dữ liệu con và file ảnh, về danh sách tour với “Đã xóa tour.” Tour đã có đơn và mọi đơn đã đóng → “Ngừng hiển thị” (`archived`): khách mở tour nhận 404, tour không còn ở danh sách và trang so sánh, đơn cũ giữ nguyên. Còn đơn “Chờ xác nhận”, “Chờ thanh toán” hoặc “Đã xác nhận” → 409 “Không xóa được: tour còn N đơn …”, không đổi gì. |
| Hiển thị lại | Tour “Ngừng hiển thị” → “Chờ duyệt”; phê duyệt lại ở “Duyệt tour” thì khách mới thấy. Danh sách tour quản trị có tab “Ngừng hiển thị”. |
| Xóa đơn vị tổ chức | Form sửa đơn vị có ô “Xóa đơn vị” khi đơn vị chưa có tour nào (kể cả tour chờ duyệt / ngừng hiển thị); bắt buộc tick xác nhận. Xóa đơn vị và tài khoản `provider` không đăng nhập đi kèm (tài khoản còn được bảng khác dùng thì chuyển `locked`). Còn tour → 409 “Đơn vị còn N tour nên không xóa được. Chọn “Ngừng hợp tác” để ẩn mọi tour của đơn vị khỏi trang khách.” |

Mỗi thao tác kiểm tra người thao tác là quản trị viên đang hoạt động, chỉ sửa mục thuộc đúng tour (mã mục của tour khác → 404) và ghi `admin_logs` (`target_type` `tour` hoặc `provider`); lịch sử của tour hiện ở “Lịch sử xử lý” trên trang chi tiết tour quản trị.

## 6. Route

| Phương thức | Đường dẫn | Controller | Ghi chú |
| --- | --- | --- | --- |
| GET | `/compare` | `CompareController@index` | `ids`: mã tour cách nhau bởi dấu phẩy; không cần đăng nhập (mục 2). |
| GET | `/api/compare` | `CompareController@apiIndex` | JSON `{ tours, rows, skipped }`; 422 khi dưới 2 hoặc quá 3 mã. |
| GET | `/tours/{id}` | `TourDetailController@show` | Thêm mục “Gói tour”, ô chọn gói, nút “Thêm vào so sánh”; `/api/tours/{id}` thêm `packages`. |
| GET | `/tours/{id}/book` | `BookingController@create` | Thêm `package_id`. |
| POST | `/api/bookings` | `BookingController@store` | Thêm `package_id` (trống = tour không chia gói); 409 `package_changed`. |
| GET | `/bookings/{code}/change` | `ChangeRequestController@create` | Trang “Đổi ngày / hủy tour” của đơn. |
| POST | `/bookings/{code}/change` | `ChangeRequestController@store` | `type` (`cancel` / `change_date`), `schedule_id` (khi đổi ngày), `reason`. |
| GET | `/admin/change-requests` | `AdminChangeRequestController@index` | `status`: `pending` (mặc định), `approved`, `rejected`, `all`. |
| GET | `/admin/change-requests/{id}` | `AdminChangeRequestController@show` | Chi tiết và form xử lý. |
| POST | `/admin/change-requests/{id}/decide` | `AdminChangeRequestController@decide` | `decision` (`approved` / `rejected`), `note`, `refund`. |
| GET | `/admin/tours/{id}/packages` | `AdminPackageController@index` | `?edit=<mã gói>` mở form sửa. |
| POST | `/admin/tours/{id}/packages` | `AdminPackageController@save` | `package_id` (trống = gói mới), `name`, `description`, `adult_price`, `child_price`, `active`, `sort_order`. |
| GET | `/admin/tours/{id}/content` | `AdminTourContentController@index` | `?edit_item=<mã mục>` mở form sửa lịch trình. |
| POST | `/admin/tours/{id}/content/images` | `AdminTourContentController@addImage` | `image_file` hoặc `image_url`, `image_alt`. |
| POST | `/admin/tours/{id}/content/images/{imageId}/delete`, `…/images/{imageId}/cover` | `AdminTourContentController@deleteImage`, `@setCover` | Xóa ảnh, đặt ảnh bìa. |
| POST | `/admin/tours/{id}/content/itinerary`, `…/itinerary/{itemId}/delete` | `AdminTourContentController@saveItinerary`, `@deleteItinerary` | `item_id` (trống = thêm), `item_time`, `item_description`, `item_sort`. |
| POST | `/admin/tours/{id}/content/inclusions`, `…/inclusions/{inclusionId}/delete` | `AdminTourContentController@addInclusion`, `@deleteInclusion` | `inclusion_text`, `inclusion_included` (`1` bao gồm, `0` không bao gồm). |
| POST | `/admin/tours/{id}/content/policy` | `AdminTourContentController@addPolicy` | `policy_hours`, `policy_percent`, `policy_terms`. |
| POST | `/admin/tours/{id}/delete`, `/admin/tours/{id}/restore` | `AdminTourContentController@deleteTour`, `@restoreTour` | Xóa tour (`confirm=1`), hiển thị lại. |
| POST | `/admin/providers/{id}/delete` | `AdminProviderController@delete` | `confirm=1`. |
| GET | `/admin/tours?status=archived` | `AdminTourController@index` | Tab “Ngừng hiển thị”. |

Mọi POST có `_csrf`. Trang `/admin…` cần đăng nhập quản trị viên; trang `/bookings/…` cần tài khoản khách hàng.

## 7. Quy ước lỗi

Các trang Sprint 5 là trang HTML có form POST, trừ `/api/compare` và `/api/bookings` trả JSON `{ success, message, data }`. Thành công → 303 về trang của mục đó kèm `?msg=` để hiện thông báo; lỗi → vẽ lại trang với mã HTTP dưới đây, giữ nguyên thông tin đã nhập, báo lỗi ở đúng ô hoặc đầu form.

| HTTP | Khi nào | Cách hiện |
| --- | --- | --- |
| 403 | Thiếu hoặc sai `_csrf`. | Đầu form: “Phiên làm việc đã hết hạn, vui lòng thử lại.” (`/api/bookings`: “Phiên làm việc đã hết hạn, vui lòng tải lại trang và thử lại.”) |
| 403 | Trang `/admin…` mở bằng tài khoản không phải quản trị viên, hoặc procedure trả `forbidden`. | Trang 403. Tài khoản quản trị mở trang đổi / hủy của khách → chuyển về `/bookings` (trang 403 “Tài khoản này không có đơn đặt tour”). |
| 404 | UUID sai dạng hoặc không tìm thấy tour, yêu cầu, gói, ảnh, mục lịch trình, dịch vụ, đơn vị; mã đơn sai dạng, không có hoặc của tài khoản khác. | Trang 404 hoặc lỗi đầu form (vd. “Không tìm thấy ảnh này (có thể đã bị xóa).”). Trang đơn: “Không tìm thấy đơn”, không cho biết mã đơn có tồn tại hay không. |
| 409 | Dữ liệu đúng nhưng trạng thái hiện tại không cho phép: yêu cầu đổi / hủy bị chặn, lịch mới hết chỗ, yêu cầu đã xử lý, trùng tên gói, đủ 12 ảnh / 30 mục lịch trình / 40 dịch vụ, tour còn đơn đang xử lý hoặc đã ngừng hiển thị, đơn vị còn tour, `package_changed`. | Trang đọc lại số liệu mới nhất (yêu cầu, lịch, số chỗ) rồi báo lỗi. |
| 422 | Dữ liệu nhập sai: ô bắt buộc trống, quá độ dài, giá / giờ / phần trăm ngoài khoảng, chưa tick xác nhận xóa; `/api/compare` dưới 2 hoặc quá 3 tour. | Lỗi theo từng ô; API trả `data` `{ "min": 2 }` hoặc `{ "max": 3 }`. |

Chưa đăng nhập: trang của khách chuyển tới `/login?next=<trang đang mở>`, trang quản trị chuyển tới `/admin/login`. Procedure trả kết quả khác `ok` thì không đổi dữ liệu; ảnh vừa tải lên mà không lưu được thì file bị xóa.

## 8. Đối chiếu tiêu chí Gantt

| WBS | Tiêu chí trong Gantt | Đáp ứng |
| --- | --- | --- |
| US04-S5-01 | Chọn / bỏ tour, tối đa 3 | Nút “Thêm vào so sánh”, khung “Tour đang so sánh”, nút “Bỏ”, “Xóa danh sách”; tour thứ 4 bị chặn kèm thông báo (mục 2, quy tắc 1–2). |
| US04-S5-02 | Giá / đơn vị, lịch trình, chính sách; thiếu ghi “Chưa cập nhật” | `NMT_sp_tour_compare` và `CompareModel` đưa về cùng đơn vị theo 4 nhóm dòng; ô thiếu ghi “Chưa cập nhật” (quy tắc 5–6). |
| US04-S5-03 | Dữ liệu thật, chặn quá 3 tour, dữ liệu thiếu / khác đơn vị | Dữ liệu đọc từ database; server chỉ nhận 3 tour (trang lấy 3 tour đầu, API 422) và bỏ tour ẩn / mã sai (quy tắc 3, 4, 7). Ca kiểm thử ở [03](03-test-plan-rtm.md). |
| US14-S5-01 | Form theo chính sách của đúng tour, thông báo lỗi | `/bookings/{code}/change` hiện chính sách lưu cùng đơn và số dự kiến hoàn; lỗi theo ô và lỗi trạng thái (mục 4.1, 4.5). |
| US14-S5-02 | Kiểm tra quyền, chính sách, trạng thái; lưu yêu cầu và lịch sử; chưa tự động hoàn tiền | `LTP_sp_change_request_create`: chủ đơn, trạng thái đơn, chưa khởi hành, một yêu cầu chờ, lịch mới; chụp chính sách và số dự kiến hoàn; ghi `booking_events`. Lưu qua form `POST /bookings/{code}/change`, không có API JSON riêng. Không hoàn tiền tự động (mục 4.3). |
| US14-S5-03 | Xử lý thủ công, có lịch sử / trạng thái | `/admin/change-requests`: lọc theo trạng thái, đồng ý / từ chối kèm ghi chú bắt buộc, mỗi yêu cầu một lần, ghi `admin_logs`; quản trị viên thay “nhân viên” theo CR1 (mục 4.2, 4.4). |
| US06-S5-01 | Phần Booking còn tồn: gói lựa chọn (FR-07) | Bảng `tour_packages`, chọn gói khi đặt, giá theo gói, quản lý gói ở trang quản trị (mục 3). |
| US07-S5-01 | Quản trị tour còn tồn: xóa tour / đơn vị; ảnh, lịch trình, dịch vụ, chính sách trên giao diện | Trang nội dung tour, xóa / ngừng hiển thị / hiển thị lại tour, xóa đơn vị chưa có tour (mục 5). |
| Kiểm thử | Test Plan, RTM, E2E, phân quyền / dữ liệu nhập, sửa lỗi, retest, System Test Exit 12/11 | [03 – Test Plan và RTM](03-test-plan-rtm.md). |
