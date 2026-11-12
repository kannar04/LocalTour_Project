# Kế hoạch tích hợp dịch vụ bên thứ ba cho LocalTour

## 1. Cách hiểu và mục tiêu

Trong kế hoạch này, **service** là dịch vụ/API bên thứ ba được LocalTour sử dụng. Không tạo thêm một tầng kiến trúc `Service` chung và không tách ứng dụng thành microservice. Chỉ viết adapter/gateway/client nhỏ khi cần để controller không chứa trực tiếp logic ký request, gọi HTTP hoặc xử lý lỗi của nhà cung cấp.

Coding agent phải tự audit source hiện tại trước khi sửa, giữ phần đã làm đúng, tối ưu phần chưa an toàn hoặc trùng lặp và chỉ triển khai phần còn thiếu. Không được dựa riêng vào README vì source và tài liệu có thể lệch nhau.

Mục tiêu:

1. Giữ ổn định các phương thức thanh toán hiện tại.
2. Hoàn thiện đăng nhập bằng Google **chỉ cho Customer**.
3. Tận dụng và mở rộng các tích hợp có sẵn thay vì tạo chức năng trùng.
4. Bổ sung dịch vụ mới có giá trị trực tiếp với trải nghiệm đặt tour.
5. Mọi dịch vụ bên ngoài đều có thể tắt bằng `.env`; khi tắt hoặc lỗi, chức năng cốt lõi vẫn chạy.
6. Không commit API key, secret, access token hoặc dữ liệu thật.

## 2. Kiểm kê source hiện tại bắt buộc

Trước khi triển khai, đối chiếu route, controller, model, database, view, config, `.env.example`, test và tài liệu rồi lập ma trận nội bộ: **đã đúng / cần tối ưu / sai yêu cầu / còn thiếu**.

Source hiện tại đã có dấu vết của:

| Nhóm | Tích hợp hiện có | Việc phải audit |
| --- | --- | --- |
| Thanh toán | VNPay, VietQR, MoMo | Chữ ký, Return URL, IPN/webhook, idempotency, timeout, trạng thái chưa rõ kết quả, đối chiếu Admin và regression booking/refund/payout |
| Đăng nhập xã hội | Google và Facebook OAuth | Phạm vi role, `state`, redirect URI, email verified, liên kết tài khoản, khóa tài khoản, lỗi callback và việc lộ nút ở sai portal |
| Email | SMTP và email xác nhận booking | Chống gửi trùng, log, timeout, retry, template, cấu hình và các sự kiện còn thiếu |
| Chống bot | Google reCAPTCHA | Form nào đang dùng, fail-open/fail-closed theo môi trường, timeout và thông báo lỗi |
| Bản đồ | Leaflet, OpenStreetMap, Overpass | Cache, fallback, timeout, attribution và tránh gọi API quá mức |

Không triển khai lại từ đầu các phần trên nếu chúng đang hoạt động đúng.

## 3. Phạm vi ưu tiên

### P0 — Hoàn thiện và bảo vệ tích hợp hiện có

#### 3.1. Thanh toán

- Giữ VNPay, VietQR và MoMo; chưa thêm cổng thanh toán thứ tư.
- Xác minh chữ ký trước khi tin mọi dữ liệu Return URL/IPN.
- Không chỉ dựa vào Return URL phía trình duyệt để xác nhận tiền.
- Callback/IPN gọi lặp phải cho cùng một kết quả và không tạo trùng payment, voucher, email, ledger hoặc payout.
- So khớp mã đơn, mã giao dịch, số tiền và trạng thái trước khi ghi nhận.
- Secret chỉ đọc từ `.env`; log phải che dữ liệu nhạy cảm.
- Chuẩn hóa timeout, lỗi mạng, response không phải JSON và cơ chế Admin xử lý giao dịch chưa rõ kết quả.
- Thêm test cho callback hợp lệ, sai chữ ký, sai số tiền, callback lặp, đơn hết hạn và thanh toán đến sau khi đơn bị hủy.

#### 3.2. Google OAuth — chỉ Customer

Google login là hạng mục bắt buộc nhưng source đã có triển khai ban đầu, vì vậy agent phải audit và hoàn thiện thay vì viết một luồng thứ hai.

Route dự kiến:

```text
GET /auth/google?next=...
GET /auth/google/callback?code=...&state=...
```

Quy tắc:

- Chỉ hiển thị nút Google ở `/login` và `/register` của khách hàng.
- Không hiển thị và không chấp nhận Google login tại `/admin/login`, `/host/login` hoặc bất kỳ route nâng quyền nào.
- Tài khoản tạo mới luôn có `users.role = customer`, `status = active`; không nhận role từ Google hoặc request client.
- Chỉ dùng email Google đã xác minh. Dùng `sub` làm định danh ổn định của tài khoản Google, không dùng email làm provider user ID.
- Nếu email chưa tồn tại: tạo Customer và liên kết Google.
- Nếu email đã thuộc Customer đang hoạt động: liên kết/đăng nhập an toàn theo quy tắc hiện có.
- Nếu email thuộc Admin hoặc Provider: từ chối bằng thông báo chung, tuyệt đối không đổi role và không liên kết.
- Nếu Customer bị khóa: từ chối đăng nhập.
- Dùng `state` ngẫu nhiên một lần, có hạn ngắn, gắn với session và `next`; callback sai/thiếu/hết hạn phải bị từ chối.
- Redirect URI phải khớp chính xác cấu hình Google. Production chỉ dùng HTTPS; localhost được phép cho phát triển.
- Chỉ xin scope tối thiểu `openid email profile`.
- Không lưu access token/refresh token vì ứng dụng chỉ cần xác thực danh tính. Không xin offline access.
- Sau callback thành công: regenerate session ID, xoay CSRF token và redirect sang đường dẫn `next` đã kiểm tra an toàn.
- Không đưa mã authorization hoặc token vào log, URL sau khi xử lý hay thông báo lỗi.
- Nút Google tự ẩn khi thiếu cấu hình; đăng nhập email/mật khẩu vẫn hoạt động.

Cấu hình:

```dotenv
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=
```

Test bắt buộc:

- Customer mới đăng nhập Google thành công.
- Customer cùng email đăng nhập/liên kết đúng và không tạo user trùng.
- Callback lặp không tạo liên kết trùng.
- Email chưa verified, thiếu email, sai `state`, sai/thiếu `code`, user hủy consent và lỗi mạng đều được xử lý.
- Email của Admin/Provider không đăng nhập được qua Google.
- Customer locked không đăng nhập được.
- Admin/Host không có nút hoặc route Google riêng.
- `next` ngoài domain không tạo open redirect.

Facebook OAuth hiện có không phải yêu cầu của đợt này. Không mở rộng Facebook; có thể giữ ở trạng thái tắt bằng cấu hình nếu việc giữ lại không làm tăng bề mặt lỗi. Nếu UI sản phẩm chỉ chốt Google, ẩn nút Facebook và ghi rõ quyết định trong tài liệu.

### P1 — Tận dụng dịch vụ đang có

#### 3.3. Email giao dịch qua SMTP

Không tạo hệ thống email mới; mở rộng `SmtpMailer`, `BookingMail`, `email_logs` và pattern chống gửi trùng hiện có.

Các sự kiện ưu tiên:

1. Booking đã thanh toán/được xác nhận.
2. Booking bị hủy hoặc yêu cầu thay đổi được xử lý.
3. Nhắc lịch trước giờ khởi hành, ví dụ 24 giờ.
4. Xác nhận payout cho Host nếu phần Host đã hoàn thiện.

Yêu cầu:

- Mỗi sự kiện có `kind`/idempotency key rõ ràng; callback lặp không gửi email lặp.
- Gửi email không được làm hỏng transaction thanh toán hoặc booking.
- Có log `pending/sent/failed/skipped`, thời điểm, số lần thử và lỗi đã làm sạch.
- Với email nhắc lịch, dùng script CLI/cron hiện có hoặc tạo script chạy định kỳ nhỏ; không gửi trong request xem trang.
- Template dùng tiếng Việt, responsive tối thiểu, có bản text/plain và không nhúng bí mật.
- Có chế độ tắt khi thiếu `MAIL_HOST`; bản demo vẫn chạy.

### P1 — Dịch vụ mới nên thêm

#### 3.4. Dự báo thời tiết cho lịch tour bằng Open-Meteo

Đây là dịch vụ mới được ưu tiên vì source đã có tọa độ tour và bản đồ, dữ liệu thời tiết giúp khách quyết định lịch đi.

Tài liệu chính thức: <https://open-meteo.com/en/docs>

Phạm vi UI:

- Hiển thị dự báo ngắn tại chi tiết tour hoặc cạnh lịch khởi hành khi ngày đi nằm trong khoảng forecast mà API hỗ trợ.
- Chỉ hiện các dữ liệu cần thiết: trạng thái thời tiết, nhiệt độ thấp/cao, xác suất mưa và gió nếu hữu ích.
- Ghi rõ đây là dự báo tham khảo và thời điểm cập nhật.
- Ngày quá xa chưa có dự báo thì không gọi API và hiển thị thông báo nhẹ, không giả dữ liệu.

Thiết kế kỹ thuật:

- Dùng latitude/longitude đã lưu cho tour; không gọi thêm geocoding khi đã có tọa độ.
- Gọi từ server bằng HTTP client hiện có, không để browser gọi trực tiếp.
- Cache theo tọa độ làm tròn + ngày + timezone, TTL khoảng 30–60 phút; cho phép dùng cache cũ khi API tạm lỗi.
- Timeout ngắn, giới hạn số lần thử; lỗi thời tiết không làm lỗi trang tour hoặc booking.
- Chuẩn hóa timezone `Asia/Ho_Chi_Minh`, đơn vị °C, km/h và dữ liệu ngày.
- Thêm attribution/ghi nguồn theo điều khoản của nhà cung cấp.
- Endpoint và TTL cấu hình được; không hard-code secret. Open-Meteo không yêu cầu key cho trường hợp sử dụng phù hợp, nhưng vẫn phải kiểm tra điều khoản/licence trước production.

Cấu hình dự kiến:

```dotenv
WEATHER_ENABLED=false
WEATHER_BASE_URL=https://api.open-meteo.com/v1/forecast
WEATHER_CACHE_MINUTES=60
```

Test:

- Map weather code đúng nhãn/icon tiếng Việt.
- Tọa độ hoặc ngày sai không gọi API.
- Cache hit không gọi lại.
- Timeout/API lỗi dùng cache cũ hoặc ẩn widget an toàn.
- Không ảnh hưởng thời gian tải trang quá mức và không chặn đặt tour.

### P2 — Tùy điều kiện triển khai

#### 3.5. Cloudinary cho ảnh tour

Chỉ thêm khi môi trường deploy không có ổ đĩa bền vững hoặc cần CDN/resize ảnh. Nếu demo/local server đang lưu file ổn định thì giữ local upload để tránh tăng phạm vi.

Tài liệu chính thức: <https://cloudinary.com/documentation/php_image_and_video_upload>

Nếu triển khai:

- Upload có chữ ký từ server; không bao giờ đưa API secret xuống browser.
- Kiểm tra MIME, kích thước, dung lượng và quyền sở hữu tour trước khi upload.
- Lưu `provider`, `public_id`, `secure_url`, kích thước và metadata cần thiết; không chỉ lưu URL để còn xóa/đổi ảnh an toàn.
- Có adapter lưu trữ với hai cấu hình `local` và `cloudinary`; không làm local mode ngừng chạy.
- Chỉ xóa asset cloud sau khi database commit thành công hoặc có job dọn orphan an toàn.
- Dùng transformation cho thumbnail/card/detail thay vì tải ảnh gốc quá lớn.

Cấu hình dự kiến:

```dotenv
MEDIA_DRIVER=local
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
```

#### 3.6. Web Push bằng Firebase Cloud Messaging

Chỉ triển khai sau khi có domain HTTPS ổn định và nhu cầu thông báo realtime rõ ràng. FCM Web cần service worker và HTTPS: <https://firebase.google.com/docs/cloud-messaging/web/get-started>

Use case phù hợp:

- Customer: thanh toán thành công, booking thay đổi/hủy, nhắc lịch.
- Host: tour được duyệt/từ chối, có booking mới, payout được xác nhận.
- Admin: payment cần đối chiếu hoặc sự kiện vận hành quan trọng.

Nếu triển khai:

- Xin quyền notification sau hành động có ngữ cảnh, không hỏi ngay khi mở trang.
- Token gắn với user/device, có revoke, last_seen và cleanup token lỗi.
- Kiểm tra ownership/recipient ở server; không để client chọn tùy ý user nhận.
- Notification chỉ là kênh bổ sung, không thay email hoặc trạng thái trong hệ thống.
- Localhost/không HTTPS phải degradation an toàn.

## 4. Những dịch vụ chưa nên thêm

- **Google Maps/Places:** trùng với Leaflet + OpenStreetMap + Overpass đang có và có thể phát sinh billing. Chỉ xem xét nếu dữ liệu hiện tại không đáp ứng yêu cầu cụ thể.
- **Cổng thanh toán mới:** VNPay, VietQR, MoMo đã đủ cho phạm vi hiện tại; ưu tiên tính đúng và idempotency.
- **SMS/OTP trả phí:** chưa có use case bắt buộc, tăng chi phí và xử lý dữ liệu cá nhân.
- **Analytics/advertising tracker:** chưa cần cho nghiệp vụ cốt lõi và làm tăng yêu cầu consent/privacy.
- **Chatbot/AI gợi ý tour:** chưa thêm trước khi catalog, search, booking và dữ liệu vận hành ổn định.
- **Google Calendar API:** chưa cần OAuth scope bổ sung. Nếu chỉ cần “Thêm vào lịch”, ưu tiên file `.ics` hoặc URL calendar không cần lưu token Google.

## 5. Quy tắc chung khi tích hợp

- Mọi HTTP call phải có connect timeout, total timeout, kiểm tra status/content-type và xử lý response sai định dạng.
- Không retry mù với thao tác tạo giao dịch; phải có idempotency key và tra cứu trạng thái trước.
- Dịch vụ đọc như weather/places có thể retry giới hạn và dùng cache cũ.
- Controller chỉ điều phối; logic ký/xác minh request đặt trong gateway/client nhỏ hiện có hoặc tương ứng.
- Không gọi dịch vụ bên ngoài bên trong transaction database kéo dài.
- Webhook xác minh chữ ký trên raw payload/query đúng quy tắc nhà cung cấp trước khi parse thành dữ liệu tin cậy.
- Dùng allowlist URL/host cấu hình để tránh SSRF; không nhận endpoint tùy ý từ request người dùng.
- Log correlation ID, loại service, thời gian và kết quả; che secret, token, password, số tài khoản và dữ liệu cá nhân không cần thiết.
- Feature flag/config trống phải tắt tích hợp sạch sẽ, ẩn UI tương ứng và không gây exception.
- Cập nhật `.env.example`, README cài đặt, script kiểm tra cấu hình và hướng dẫn sandbox; không ghi credential thật.
- UI chỉ cần tối thiểu và đồng bộ Admin/Guest/Host hiện tại; tái sử dụng button, alert, form, badge, loading và empty state.

## 6. Thứ tự thực hiện

1. Audit source và chạy baseline syntax/test.
2. Lập ma trận hiện trạng từng integration và xác nhận các thay đổi đang có của người dùng.
3. Sửa lỗi nền tảng/idempotency của payment nếu audit phát hiện.
4. Hoàn thiện Google OAuth Customer-only và test phân quyền.
5. Mở rộng email giao dịch bằng hạ tầng SMTP hiện có.
6. Thêm Open-Meteo với cache/fallback và widget UI tối thiểu.
7. Chạy regression Customer/Admin/Host, payment, booking, email và map.
8. Chỉ làm Cloudinary khi storage local là vấn đề thực tế.
9. Chỉ làm FCM khi có HTTPS và yêu cầu push được xác nhận.
10. Cập nhật tài liệu, cấu hình mẫu và báo cáo phần giữ nguyên/tối ưu/thêm mới.

## 7. Tiêu chí nghiệm thu

- Thanh toán hiện tại không bị regression; callback lặp không tạo side effect trùng.
- Google login chỉ xuất hiện và hoạt động cho Customer.
- Google không thể tạo, liên kết hoặc đăng nhập Admin/Provider.
- OAuth chống CSRF, không open redirect và không lưu token không cần thiết.
- Thiếu credential Google thì UI tự ẩn, login bằng mật khẩu vẫn chạy.
- Email theo sự kiện không gửi trùng và lỗi SMTP không phá nghiệp vụ.
- Weather có cache, fallback và không làm hỏng trang khi API lỗi.
- Tất cả service có cấu hình tắt, timeout và log an toàn.
- `.env.example` và README đủ để người khác cấu hình sandbox mà không cần đọc source.
- Test tự động/kiểm tra thủ công được ghi rõ; không chứa secret hay tài khoản thật.

## 8. Báo cáo bàn giao bắt buộc

Cuối lượt agent phải nêu ngắn gọn:

1. Service nào đã có và được giữ nguyên.
2. Phần nào được sửa/tối ưu.
3. Service nào mới được tích hợp.
4. Migration/config cần chạy hoặc điền.
5. Cách kiểm thử sandbox và các test đã chạy.
6. Hạn chế còn lại, quota/HTTPS/domain cần có và các mục P2 chưa triển khai.
