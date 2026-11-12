# Prompt triển khai toàn bộ hệ thống Host cho LocalTour

Bạn là coding agent chịu trách nhiệm triển khai hoàn chỉnh hệ thống Host/Provider cho dự án LocalTour trong **một lượt làm việc liên tục**.

## Quyền tự chủ và cách làm việc

- Bạn được phép đọc, tạo và chỉnh sửa toàn bộ mã nguồn, migration, stored procedure, route, controller, model, view, CSS/JS, test và tài liệu cần thiết trong repository này để hoàn thành mục tiêu.
- Triển khai liên tục tất cả các giai đoạn bên dưới. **Không dừng lại để xin duyệt từng giai đoạn, từng file, migration, schema, giao diện hoặc quyết định kỹ thuật thông thường.**
- Trước khi sửa, phải tự audit source hiện tại theo từng mục của kế hoạch và phân loại nội bộ thành: **đã làm đúng**, **đã có nhưng cần sửa/tối ưu**, **đang làm sai yêu cầu**, **chưa làm**. Không được chỉ dựa vào mô tả trong tài liệu; phải đối chiếu route, controller, model, view, CSS/JS, schema, stored procedure và test thực tế.
- Không làm lại mù quáng những phần đã hoạt động đúng. Tái sử dụng và chuẩn hóa code hiện có, sửa phần lệch yêu cầu, tối ưu phần trùng lặp hoặc khó bảo trì, rồi tiếp tục triển khai các phần còn thiếu theo dependency.
- Khi tài liệu và source mâu thuẫn, lấy yêu cầu nghiệp vụ trong file này làm chuẩn, đồng thời kiểm tra regression để không phá các luồng Admin/Customer đang hoạt động.
- Tự chọn giải pháp tương thích với kiến trúc PHP 8.2 MVC thuần và MySQL/MariaDB hiện tại, sau đó thực hiện ngay.
- Tự chạy các kiểm tra khả dụng trong môi trường, sửa lỗi phát hiện được và tiếp tục cho đến khi toàn bộ tiêu chí nghiệm thu đạt hoặc gặp blocker khách quan không thể giải quyết trong repository.
- Nếu một chi tiết nhỏ chưa được quy định, tự chọn phương án an toàn, nhất quán với code hiện có và ghi lại quyết định trong tài liệu bàn giao; không hỏi lại.
- Giữ nguyên các thay đổi có sẵn của người dùng. Không reset, checkout, xóa hoặc ghi đè thay đổi ngoài phạm vi.
- Không dùng thao tác phá hủy dữ liệu thật. Migration phải chạy lại an toàn khi hợp lý và không làm mất dữ liệu hiện có.
- Không commit, push, deploy production, gửi email thật hoặc thực hiện giao dịch ngân hàng thật. Các tích hợp bên ngoài chỉ được dùng ở sandbox/mock theo cấu hình dự án.
- Mọi chức năng tài chính phải dùng số nguyên VND, transaction và khóa dòng phù hợp; không dùng số thực để tính tiền.
- Cuối lượt, cung cấp báo cáo ngắn gồm: phần đã làm, migration cần chạy theo thứ tự, cách chạy/test, tài khoản hoặc dữ liệu mẫu, kiểm tra đã thực hiện, hạn chế còn lại.

## Bối cảnh dự án

- Backend: PHP 8.2 thuần, MVC tự xây, không Composer/framework.
- Database: MySQL/MariaDB, ứng dụng truy cập dữ liệu qua stored procedure.
- Xác thực: PHP session, `password_hash`/`password_verify`, CSRF cho POST.
- Frontend: HTML, CSS, Bootstrap 4.6.2, jQuery.
- `users.role` đã có `admin`, `provider`, `customer`.
- `providers` liên kết 1-1 với `users`; trong code và database tiếp tục dùng tên **provider**, trên giao diện gọi là **Host/Đơn vị tổ chức**.
- Mỗi `tour` đã có `provider_id`.
- Provider hiện do Admin tạo với `password_hash = NULL` và chưa được đăng nhập.
- Khách chỉ thấy tour khi tour được duyệt, provider được duyệt và tài khoản provider hoạt động.
- Thanh toán khách hàng hiện đi qua tài khoản/cấu hình của nền tảng bằng VNPay hoặc VietQR; Admin đối chiếu VietQR.

## Mục tiêu nghiệp vụ tổng thể

Xây dựng marketplace có luồng:

```text
Admin tạo và kích hoạt Host
→ Host đăng nhập và quản lý hồ sơ/tài khoản ngân hàng
→ Host tạo đầy đủ tour, gói, nội dung, lịch và giá
→ Host gửi tour cho Admin duyệt
→ Khách đặt tour và trả toàn bộ tiền cho LocalTour/Admin
→ Host xem booking và hành khách thuộc tour của mình
→ Hệ thống tính hoa hồng chung và số tiền phải trả Host
→ Trước ngày khởi hành, Admin chuyển khoản thủ công cho Host
→ Admin ghi nhận giao dịch, Host xem tiền chờ và tiền đã nhận
```

Khách hàng **không được tự đăng ký làm Host**. Không xây chức năng “Đăng ký Host”. Host liên hệ riêng và Admin cấp tài khoản.

Source hiện tại có thể đã tồn tại `/host/register`, form, liên kết sidebar, controller và stored procedure tự đăng ký. Đây là phần **trái yêu cầu**, phải audit và loại bỏ hoặc vô hiệu hóa đầy đủ ở mọi lớp liên quan; không chỉ ẩn nút trên giao diện. Không để route công khai hoặc endpoint cũ tiếp tục tạo tài khoản `provider`.

## Nguyên tắc giao diện và tái sử dụng

- UI Host chỉ cần **tối thiểu, rõ ràng, responsive và dùng được**, không dành thời gian làm hiệu ứng hoặc thiết kế cầu kỳ khi nghiệp vụ, bảo mật và test chưa hoàn chỉnh.
- Đồng bộ Host với giao diện Admin và Guest hiện có về container, grid, typography, màu sắc, button, form, table, alert, badge, modal, trạng thái loading/empty/error và responsive breakpoint.
- Ưu tiên tái sử dụng partial, helper, component, utility class và CSS hiện có. Chỉ thêm CSS riêng cho Host khi thật sự cần; không sao chép nguyên khối `admin.css`, không tạo một design system thứ ba và không thêm framework frontend mới.
- Có thể dùng layout/sidebar Admin làm nền cho khu Host nhưng phải tách đúng menu, quyền và nội dung. Các màn hình dùng chung form tour nên tái sử dụng controller/service/view partial phù hợp thay vì duy trì hai bản logic dễ lệch nhau.
- Tên gọi trên UI phải nhất quán: dùng **Đơn vị tổ chức** hoặc **Host** theo đúng ngữ cảnh; trong code/database vẫn dùng `provider`.
- Mọi trang mới phải có trạng thái rỗng, thông báo lỗi/thành công, focus hợp lý, label cho form và hoạt động được trên mobile ở mức tương đương các trang Admin/Guest hiện tại.
- Sau khi triển khai, tự mở hoặc render các màn hình chính để kiểm tra trực quan; sửa lỗi vỡ layout, text tràn, bảng trên mobile và sự không đồng bộ rõ ràng trước khi bàn giao.

## Quy tắc phân quyền bắt buộc

1. Customer không truy cập được `/host` hoặc `/admin`.
2. Host không truy cập được `/admin`.
3. Admin không bị giới hạn theo provider.
4. Host chỉ được đọc/sửa dữ liệu thuộc provider gắn với `users.id` đang đăng nhập.
5. Không tin `provider_id` gửi từ client. Provider phải được suy ra từ session user ở server/database.
6. Kiểm tra ownership ở cả controller và stored procedure.
7. Object con kiểm tra ownership theo chuỗi quan hệ:

```text
schedule/package/image/itinerary/inclusion/policy → tour → provider → user
booking/passenger → schedule → tour → provider → user
```

8. Host A đổi UUID trên URL/request không được xem hoặc sửa dữ liệu Host B; trả 404 hoặc 403 theo quy ước hiện có và không làm lộ sự tồn tại của tài nguyên.
9. Mọi POST phải có CSRF. Trang Host chứa dữ liệu khách/tài chính phải gửi `Cache-Control: no-store`.
10. Không nới lỏng procedure Admin thành kiểm tra role chung chung. Tạo procedure Host riêng hoặc procedure dùng chung có kiểm tra ownership rõ ràng.

## Giai đoạn 1 — Tài khoản Host và hồ sơ thanh toán

### Tài khoản và kích hoạt

Triển khai:

- `/host/login`, POST login, POST logout.
- Cơ chế Admin tạo Host như hiện tại nhưng có thể sinh liên kết kích hoạt/đặt mật khẩu dùng một lần.
- Bảng token kích hoạt/đặt lại mật khẩu; chỉ lưu hash token, có hạn dùng và `used_at`.
- Vì chưa bắt buộc có email service, giao diện Admin phải cho phép sao chép liên kết kích hoạt để gửi thủ công.
- Host chỉ đăng nhập khi:

```text
users.role = provider
users.status = active
providers.approval_status = approved
password_hash IS NOT NULL
```

- Admin có thể khóa/mở tài khoản, tạo lại liên kết kích hoạt và xem trạng thái kích hoạt.
- Không cho Admin xem mật khẩu thật; không lưu mật khẩu dạng rõ.

### Khu vực Host

Tạo layout/sidebar và các route tối thiểu:

```text
/host
/host/profile
/host/payment-account
/host/notifications
```

Tạo `HostController` làm lớp cha, nạp user và provider hiện tại, chặn sai role và cung cấp `actorId()`/`providerId()`.

### Tài khoản ngân hàng Host

Tạo bảng/hệ thống tương đương `provider_payment_accounts` với:

- provider, bank code/name, account number, account holder, branch nếu cần;
- trạng thái xác minh, người xác minh, thời điểm xác minh;
- timestamps và lịch sử thay đổi;
- một tài khoản nhận tiền hiện hành cho mỗi provider.

Quy tắc:

- Host được sửa thông tin thanh toán của chính mình.
- Khi sửa, trạng thái xác minh trở về chưa xác minh.
- Admin xác minh trước khi payout.
- Danh sách che một phần số tài khoản; trang chi tiết Admin được xem đủ để chuyển khoản.
- Payout phải snapshot thông tin ngân hàng, không phụ thuộc vào thay đổi về sau.
- Ghi audit log khi tạo/sửa/xác minh.

## Giai đoạn 2 — Host tạo và duyệt tour

Tạo đầy đủ:

```text
/host/tours
/host/tours/new
/host/tours/{id}
/host/tours/{id}/edit
/host/tours/{id}/submit
/host/tours/{id}/archive
```

State machine:

```text
draft → pending → approved
              ↘ rejected → draft → pending
approved → archived
```

Quy tắc:

- Host tạo tour ở `draft`, không phải `pending`.
- Host sửa `draft` hoặc `rejected`.
- Khi sửa tour bị từ chối, chuyển về `draft`.
- Host gửi duyệt thì chuyển `pending` và khóa chỉnh sửa trong lúc chờ.
- Chỉ Admin được duyệt/từ chối; từ chối bắt buộc có lý do.
- Host xem được lý do và gửi lại sau khi sửa.
- Host không tự đặt `approved`, đổi `provider_id` hoặc đánh dấu đã xác minh nội dung nếu quyền này thuộc Admin.
- Tour có booking không được xóa vật lý; dùng `archived`.

### Sửa tour đã duyệt

Triển khai revision để tour đang bán không biến mất khi Host sửa:

- Có bảng yêu cầu revision, lưu bản nháp thay đổi và trạng thái.
- Host sửa tour `approved` tạo revision thay vì ghi đè dữ liệu public.
- Tour cũ tiếp tục hiển thị cho khách.
- Admin xem khác biệt cũ/mới, duyệt hoặc từ chối.
- Duyệt thì áp dụng atomically; từ chối giữ nguyên dữ liệu public và lưu lý do.
- Nếu dùng snapshot JSON để giảm độ phức tạp, validate đầy đủ trước khi lưu và trước khi áp dụng.

## Giai đoạn 3 — Nội dung, gói, lịch và giá

Cho Host quản lý đầy đủ các thành phần thuộc tour của mình:

- thông tin cơ bản, điểm đến, loại hình, thời lượng, số khách tối đa;
- điểm đón/trả, phương tiện, hướng dẫn viên;
- ảnh, upload ảnh, ảnh bìa, thứ tự;
- lịch trình;
- dịch vụ bao gồm/không bao gồm;
- phụ thu và dịch vụ tùy chọn;
- chính sách hủy;
- gói tour;
- lịch khởi hành, thời gian kết thúc, sức chứa;
- giá vé người lớn/trẻ em và trạng thái lịch.

Tái sử dụng validation/nghiệp vụ Admin bằng cách tách lớp dùng chung khi hợp lý; không tạo hai bản logic lệch nhau.

Quy tắc dữ liệu:

- Giá booking cũ là snapshot và không đổi khi Host đổi giá.
- Không giảm capacity dưới số chỗ đang giữ/đã xác nhận.
- Không sửa giờ của lịch đã bắt đầu.
- Không hủy lịch còn booking hoạt động nếu chưa xử lý hành khách.
- Không xóa dữ liệu cần cho booking/payout cũ.
- Upload ảnh giới hạn MIME, kích thước, tên file an toàn và chỉ lưu trong thư mục cho phép.

## Giai đoạn 4 — Host quản lý booking và hành khách

Tạo:

```text
/host/bookings
/host/bookings/{id}
/host/tours/{id}/schedules
/host/schedules/{id}
/host/schedules/{id}/customers
```

Host chỉ xem booking của schedule thuộc tour của mình. Hiển thị:

- mã booking, trạng thái booking/thanh toán;
- người liên hệ: tên, email, điện thoại;
- hành khách: tên, nhóm tuổi, yêu cầu đặc biệt;
- tour, gói, lịch khởi hành;
- loại vé, số lượng, phụ thu/dịch vụ;
- tổng số khách và tổng tiền liên quan;
- trạng thái/yêu cầu đổi ngày, hủy, hoàn tiền.

Phân biệt rõ:

```text
booking_count = số đơn
guest_count = SUM(booking_lines.quantity)
```

Host không được xem ghi chú nội bộ Admin, thông tin thanh toán không cần thiết hoặc dữ liệu Host khác. Nếu thêm xuất CSV/in danh sách khách, phải kiểm tra ownership và ghi audit log.

## Giai đoạn 5 — Hoa hồng chung và sổ cái Host

### Cấu hình hoa hồng

Admin có một tỷ lệ hoa hồng chung cho toàn bộ hệ thống, không có mức riêng theo Host/tour.

Triển khai:

- `platform_settings` hoặc cấu trúc tương đương;
- `commission_rate_history`;
- lưu tỷ lệ bằng basis point: `1000 = 10%`, tránh float;
- UI Admin thay đổi tỷ lệ và xem lịch sử;
- audit log cho mỗi lần đổi.

Thay đổi tỷ lệ chỉ áp dụng cho booking mới hoặc theo `effective_at`; không tính lại booking cũ. Snapshot `commission_rate_bps` trên booking hoặc ledger/payout item để lịch sử bất biến.

### Công thức tiền

Nguồn chuẩn là tiền thực thu:

```text
gross_paid_vnd = SUM(payments.amount_vnd WHERE status = 'paid')
refund_reserved_vnd = SUM(refunds.amount_vnd WHERE status IN ('requested','approved','completed'))
eligible_vnd = MAX(0, gross_paid_vnd - refund_reserved_vnd)
commission_vnd = quy tắc làm tròn nhất quán của eligible_vnd * rate_bps / 10000
host_net_vnd = eligible_vnd - commission_vnd
```

Không tính từ giá tour hiện tại. Dùng `booking_lines`/`booking_extras` để breakdown và đối chiếu; dùng payment thực thu làm nguồn số tiền payout.

### Sổ cái

Tạo `provider_ledger_entries` hoặc mô hình sổ cái tương đương, có ít nhất:

```text
booking_credit
commission_debit
refund_debit
payout_debit
manual_adjustment
```

Trường cần có: provider, booking, schedule, payout, loại entry, số tiền có dấu, trạng thái, `available_at`, mô tả, timestamps và idempotency key/unique constraint phù hợp.

Trạng thái tiền:

```text
pending
on_hold
available
processing
paid/settled
adjusted
```

Yêu cầu:

- Payment chỉ tạo công nợ khi thực sự `paid`.
- Callback/IPN hoặc thao tác đối chiếu lặp không tạo ledger hai lần.
- Yêu cầu hủy/đổi/refund đang chờ phải khóa khoản liên quan khỏi payout.
- Refund làm giảm tiền Host và hoa hồng tương ứng.
- Refund sau payout tạo adjustment âm để trừ payout tiếp theo; không sửa/xóa lịch sử payout cũ.
- Manual adjustment chỉ Admin thực hiện, bắt buộc có lý do và audit log.

## Giai đoạn 6 — Payout thủ công từ Admin sang Host

Khách trả tiền vào tài khoản nền tảng. Admin chuyển tiền thủ công cho Host trước ngày tour.

Tạo cấu hình chung `payout_lead_days`, mặc định `1`. Khoản đủ điều kiện từ:

```text
schedule.starts_at - payout_lead_days
```

Điều kiện đưa vào payout:

- booking `confirmed` (hoặc trạng thái hợp lệ được định nghĩa rõ);
- có payment `paid`;
- schedule/tour không bị hủy;
- không có change request/refund chưa giải quyết;
- tài khoản ngân hàng Host đã xác minh;
- chưa nằm trong payout khác;
- đã tới thời điểm đủ điều kiện.

Tạo bảng/hệ thống tương đương:

### `provider_payouts`

- provider, mã payout;
- gross, commission, refund/adjustment, net;
- trạng thái `draft`, `pending_transfer`, `paid`, `failed`, `cancelled`;
- ngày dự kiến, thông tin ngân hàng snapshot;
- người tạo/xác nhận/chuyển;
- mã giao dịch, thời điểm chuyển, ghi chú, ảnh biên lai nếu có.

### `provider_payout_items`

- payout, booking, schedule;
- gross paid, refund, eligible;
- commission rate snapshot, commission, host net;
- unique/index chống một khoản được trả hai lần.

Route Admin tối thiểu:

```text
/admin/payouts
/admin/payouts/create
/admin/payouts/{id}
/admin/payouts/{id}/confirm
/admin/payouts/{id}/fail
```

Route Host:

```text
/host/revenue
/host/payouts
/host/payouts/{id}
```

Admin phải xem breakdown, tạo đề xuất, nhập mã giao dịch/biên lai và xác nhận đã chuyển. Chỉ khi xác nhận thành công mới ghi payout `paid` và tạo ledger payout debit. Thao tác phải transaction-safe và idempotent.

## Giai đoạn 7 — Dashboard Host và Admin

### Dashboard Host

Hiển thị:

- tiền đang chờ;
- tiền đang on hold;
- tiền đã đủ điều kiện chuyển;
- tiền Admin đang xử lý;
- tổng tiền đã nhận;
- tổng phí nền tảng;
- refund/adjustment;
- số tour/lịch sắp chạy;
- số booking và số khách.

Bảng chi tiết theo tour/lịch:

```text
Tour | Ngày khởi hành | Số đơn | Số khách | Tiền khách trả | Phí | Host nhận | Trạng thái
```

Có lọc theo thời gian, tour, schedule và trạng thái payout.

### Dashboard Admin

Hiển thị riêng, không gộp mơ hồ:

- tổng tiền khách đã trả;
- tiền đang giữ cho Host;
- tiền on hold do refund/tranh chấp;
- tiền đủ điều kiện chuyển;
- tiền đang xử lý;
- tiền đã chuyển Host;
- hoa hồng ước tính;
- hoa hồng đã ghi nhận;
- tiền đã/đang hoàn khách;
- payout đến hạn/quá hạn.

Định nghĩa:

```text
Hoa hồng ước tính = hoa hồng của tiền thực thu đủ điều kiện, đã trừ phần refund liên quan
Hoa hồng đã ghi nhận = hoa hồng của các payout đã paid, có điều chỉnh khi cần
```

Mỗi tổng số phải có trang/bảng chi tiết cấu thành và khớp với ledger/payout items.

## Giai đoạn 8 — Notification, audit, test và tài liệu

Tận dụng bảng `notifications` hiện có. Tạo thông báo trong website cho:

### Host

- tài khoản được kích hoạt;
- tour được duyệt/từ chối;
- booking đã thanh toán;
- yêu cầu đổi/hủy;
- payout được tạo/đã chuyển/thất bại;
- tài khoản ngân hàng cần xác minh lại.

### Admin

- Host gửi tour/revision;
- Host đổi tài khoản ngân hàng;
- payout đến hạn/quá hạn;
- số dư âm do refund sau payout;
- lịch sắp chạy chưa thanh toán Host.

Audit bắt buộc cho:

- tạo/kích hoạt/khóa Host;
- thay đổi hồ sơ và ngân hàng;
- thao tác tour/revision/schedule;
- xem hoặc xuất danh sách khách nếu có;
- thay đổi hoa hồng;
- ledger adjustment;
- tạo/xác nhận/thất bại payout;
- refund ảnh hưởng payout.

## Kiểm thử bắt buộc

Tạo test tự động nếu hạ tầng cho phép; nếu dự án chưa có runner, thêm script/test plan có thể chạy lặp lại. Bao phủ ít nhất:

### Auth và ownership

- Customer không vào `/host`.
- Host không vào `/admin`.
- Provider pending/rejected/locked không đăng nhập.
- Host A không đọc/sửa tour, schedule, booking, passenger, payout của Host B.
- Host không tự duyệt tour hoặc sửa hoa hồng/payout.

### Tour

- Tạo là draft, submit thành pending.
- Pending bị khóa sửa.
- Reject có lý do, Host sửa và gửi lại.
- Revision không làm thay đổi tour public trước khi Admin duyệt.
- Tour có booking không bị xóa vật lý.

### Booking/customer

- `booking_count` và `guest_count` đúng.
- Host chỉ thấy booking của mình.
- Booking chưa trả không tạo doanh thu Host.

### Commission/ledger

- 10% của 10.000.000 là 1.000.000; Host nhận 9.000.000.
- Đổi 10% thành 15% không đổi booking cũ; booking mới dùng 15%.
- Không có duplicate ledger khi callback/confirm lặp.
- Refund trước payout giảm số dư đúng.
- Refund sau payout tạo adjustment âm.
- Tổng ledger khớp tổng dashboard.

### Payout

- Booking không nằm trong hai payout.
- Không payout vượt available balance.
- Không payout khi bank chưa verified hoặc có refund/change request pending.
- Confirm payout lặp không trừ tiền hai lần.
- Payout snapshot đúng tài khoản ngân hàng.
- Failed payout trả khoản tiền về trạng thái có thể xử lý lại.

### Regression

- Danh sách/chi tiết/so sánh/đặt tour của Customer vẫn hoạt động.
- VNPay/VietQR hiện có vẫn hoạt động.
- Change request/refund cũ vẫn hoạt động.
- Admin hiện tại vẫn quản lý được tour, booking và payment.

## Yêu cầu migration và tương thích

- Tạo migration mới theo thứ tự hiện có, không sửa lịch sử migration đã triển khai nếu không bắt buộc.
- Cập nhật schema tổng hợp/README database để cài mới có cùng kết quả với chạy migration.
- Stored procedure mới phải có `DROP PROCEDURE IF EXISTS`, không có `DEFINER`, dùng collation/quy ước hiện tại.
- Dùng transaction và `SELECT ... FOR UPDATE` ở các luồng thanh toán/payout/refund cạnh tranh.
- Thêm unique constraint/idempotency để chống double ledger/double payout.
- Không xóa payment, refund, booking, payout hoặc ledger lịch sử.
- Seed dữ liệu Host, booking, payment và payout mẫu đủ để demo nhưng không chứa bí mật thật.

## Tiêu chí hoàn thành toàn bộ

Chỉ coi nhiệm vụ hoàn thành khi:

1. Admin tạo/kích hoạt/khóa Host được.
2. Host đăng nhập và quản lý hồ sơ/ngân hàng được.
3. Host tạo toàn bộ tour, nội dung, gói, lịch, giá và gửi duyệt được.
4. Admin duyệt/từ chối tour và revision được.
5. Host chỉ xem đúng booking/hành khách thuộc tour mình.
6. Tiền khách vẫn đi vào nền tảng; payment paid tạo công nợ Host đúng một lần.
7. Hoa hồng chung có lịch sử và snapshot, không làm đổi booking cũ.
8. Refund/change request khóa hoặc điều chỉnh tiền đúng trước/sau payout.
9. Admin tạo và ghi nhận chuyển khoản thủ công; Host xem tiền chờ/đã nhận.
10. Dashboard Host/Admin khớp ledger và có breakdown.
11. Test ownership, idempotency, commission, refund, payout và regression đạt.
12. README/tài liệu nêu rõ cách cài migration, cấu hình, demo và vận hành.

## Quy trình thực thi yêu cầu

1. Đọc cấu trúc repository, README, schema, migration, route, auth, các controller/model/procedure tour-booking-payment-refund hiện có.
2. Kiểm tra trạng thái Git và bảo toàn thay đổi của người dùng.
3. Tìm toàn bộ dấu vết triển khai Host hiện có; lập ma trận nội bộ theo tám giai đoạn với bốn trạng thái: đã đúng / cần tối ưu / sai yêu cầu / còn thiếu.
4. Chạy baseline syntax check và test khả dụng trước khi sửa để phân biệt lỗi có sẵn với regression mới.
5. Ưu tiên sửa các sai lệch nền tảng trước, đặc biệt là tự đăng ký Host, auth, role, ownership, route công khai và rò rỉ dữ liệu.
6. Giữ và tái sử dụng phần đã đúng; refactor phần trùng lặp hoặc khó bảo trì khi việc đó giúp triển khai an toàn các mục tiếp theo, không mở rộng refactor ngoài phạm vi.
7. Triển khai phần còn thiếu theo dependency: auth/ownership → tour → content/schedule → booking visibility → commission/ledger → payout → dashboard → notification/test/docs.
8. Sau mỗi cụm thay đổi, chạy syntax check/test phù hợp và sửa ngay; không bỏ qua lỗi với lý do phần đó đã tồn tại trước nếu lỗi nằm trong phạm vi Host hoặc regression do thay đổi gây ra.
9. Đồng bộ UI Host với component/pattern Admin và Guest, sau đó kiểm tra trực quan desktop/mobile cho các màn hình chính.
10. Chạy kiểm tra tích hợp/regression cuối cùng.
11. Rà lại bảo mật ownership và tính bất biến/idempotency của tài chính.
12. Đối chiếu lại toàn bộ ma trận audit, cập nhật tài liệu theo source thực tế và bàn giao một lần khi đã hoàn thành tối đa có thể; báo cáo rõ phần giữ nguyên, phần tối ưu, phần sửa sai và phần mới triển khai.

