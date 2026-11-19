# BỘ TEST CASE HỆ THỐNG LOCALTOUR

| Thuộc tính | Giá trị |
|---|---|
| Baseline | SRS v1.2; Product Backlog US-01–US-39; CR1 và CR2 |
| Phạm vi | FR-01–FR-36; NFR-01–NFR-10 |
| UAT tham chiếu | UAT-01–UAT-64 trong `docs/sprint6/04-uat-checklist.md` |
| Trạng thái ban đầu | Not Run; chưa có Evidence/Defect theo từng ca trong repository |

Mỗi ca dưới đây là ca System/Integration Testing. Cột UAT chỉ tạo liên kết truy vết, không đồng nhất kết quả nội bộ với kết quả UAT chính thức.

## 1. Test Case chức năng và User Story

| Test Case ID | Requirement ID | User Story ID | Mục tiêu | Tiền điều kiện | Dữ liệu kiểm thử | Các bước thực hiện | Kết quả mong đợi | Ưu tiên | Trạng thái | Evidence / Defect ID | UAT Case |
|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-01 | FR-01 | US-01 | Xem danh sách tour công khai | Có tour ở nhiều trạng thái | Tour đã duyệt/chờ duyệt/từ chối | Mở `/tours`; đối chiếu dữ liệu | Chỉ tour công khai hiển thị; thông tin tóm tắt đúng | Must | Not Run | — | UAT-01 |
| TC-02 | FR-02, FR-03, FR-04, FR-05, FR-16 | US-02 | Xem đầy đủ chi tiết tour | Có tour công khai với lịch trình/chính sách/đánh giá | Một tour đủ dữ liệu và một tour thiếu trường tùy chọn | Mở từng tour; kiểm tra các mục | Nội dung đúng tour; thiếu dữ liệu không bị suy diễn; chỉ đánh giá đã duyệt hiển thị | Must | Not Run | — | UAT-02, UAT-06 |
| TC-03 | FR-06 | US-03 | Tìm kiếm, lọc cơ bản và sắp xếp | Có dữ liệu nhiều điểm đến/giá | Từ khóa có/không có kết quả; giá tăng/giảm | Tìm kiếm; lọc; sắp xếp; xóa lọc | Kết quả và URL đúng điều kiện; trạng thái không kết quả rõ ràng | Must | Not Run | — | UAT-03, UAT-04 |
| TC-04 | FR-15 | US-04 | So sánh 2–3 tour | Có ít nhất ba tour công khai | Hai, ba và bốn tour | Chọn tour; mở so sánh; thử vượt giới hạn | So sánh đúng tiêu chí; giới hạn 2–3; không trộn giá khác đơn vị | Must | Not Run | — | UAT-05 |
| TC-05 | FR-04, FR-05, FR-10 | US-05 | Hiển thị giá, phụ thu và chính sách minh bạch | Tour có giá, tùy chọn và chính sách | Số người lớn/trẻ em; phụ thu | Mở chi tiết/đặt tour; thay lựa chọn | Thành phần giá, đơn vị, tổng dự kiến và điều kiện áp dụng đúng | Must | Not Run | — | UAT-09 |
| TC-06 | FR-07, FR-08, FR-09, FR-11, FR-30 | US-06 | Đặt tour và giữ chỗ ngay | Khách đăng nhập; lịch còn chỗ và còn hơn 60 phút | Tour có/không có gói; dữ liệu khách hợp lệ | Chọn lịch/gói; nhập khách; xác nhận đặt | Tạo một đơn `Chờ thanh toán`, giữ chỗ ngay, mã duy nhất, hạn mặc định 30 phút; không chờ Admin xác nhận | Must | Not Run | — | UAT-10, UAT-11, UAT-49 |
| TC-07 | FR-13 | US-07 | Admin quản lý nội dung tour/đơn vị | Admin đăng nhập | Dữ liệu tour hợp lệ và không hợp lệ | Tạo/sửa tour; lưu; mở lại | Dữ liệu hợp lệ lưu đúng; dữ liệu sai bị từ chối phía máy chủ; không ảnh hưởng tour khác | Must | Not Run | — | UAT-31, UAT-32, UAT-34 |
| TC-08 | FR-14 | US-08 | Kiểm soát lịch, sức chứa và đặt vượt chỗ | Lịch có sức chứa xác định | Số khách bằng/vượt chỗ còn | Đặt đồng thời/tuần tự; kiểm tra chỗ | Không vượt sức chứa; số chỗ cập nhật nhất quán | Must | Not Run | — | UAT-17 |
| TC-09 | FR-11, FR-17, FR-25 | US-09 | Chỉ xác nhận đơn khi thanh toán hợp lệ | Có đơn `Chờ thanh toán` | Đơn chưa trả; VNPay hợp lệ; VietQR đã/chưa đối chiếu | Thử xác nhận từng trường hợp | Chưa thanh toán không được xác nhận; thanh toán hợp lệ chuyển `Đã xác nhận` và phát hành voucher | Must | Not Run | — | UAT-13, UAT-14, UAT-15 |
| TC-10 | FR-11, FR-17, FR-18 | US-10 | Xem đơn của tôi và thanh toán VNPay sandbox | Khách có đơn `Chờ thanh toán` còn hạn | Phản hồi VNPay đúng/sai chữ ký hoặc số tiền | Mở đơn; thanh toán; mô phỏng callback | Chỉ giao dịch xác minh hợp lệ thành công; khách chỉ thấy đơn mình | Must | Not Run | — | UAT-21, UAT-22, UAT-24 |
| TC-11 | FR-17, FR-30 | US-11 | Thanh toán VietQR đúng hạn | Có đơn còn ít nhất/ít hơn 24 giờ trước khởi hành | Hai mốc biên thời gian | Mở thanh toán; chọn VietQR; gửi thông tin | Chỉ cho VietQR khi đủ giới hạn; trạng thái chờ đối chiếu không tự xác nhận | Must | Not Run | — | UAT-18, UAT-50 |
| TC-12 | FR-17, FR-25 | US-12 | Đối chiếu VietQR và VNPay chưa rõ kết quả | Admin và các giao dịch mẫu | Đủ/thiếu/sai tiền; callback trùng | Đối chiếu từng giao dịch; gọi lại callback | Kết quả idempotent; chỉ đủ điều kiện mới thành công; có lịch sử xử lý | Must | Not Run | — | UAT-19, UAT-20, UAT-23, UAT-24 |
| TC-13 | FR-08, FR-11, FR-30 | US-13 | Tự hủy đơn quá hạn và nhả chỗ | Có đơn chưa thanh toán | Hạn giữ chỗ 30 phút; giao dịch chờ đối chiếu | Chạy xử lý hết hạn trước/sau mốc | Đơn quá hạn hợp lệ bị hủy và nhả chỗ; giao dịch chờ đối chiếu không bị hủy sai | Must | Not Run | — | UAT-25, UAT-26, UAT-48 |
| TC-14 | FR-12, FR-25 | US-14 | Gửi và xử lý yêu cầu đổi ngày/hủy | Khách có đơn đủ điều kiện | Lý do rỗng/hợp lệ; ngày hợp lệ | Khách gửi yêu cầu; Admin xử lý | Áp đúng chính sách của tour; lưu trạng thái/lý do; hủy đã trả tiền tạo yêu cầu hoàn tiền | Should | Not Run | — | UAT-27, UAT-28, UAT-29 |
| TC-15 | FR-16 | US-15 | Xem điểm và đánh giá đã duyệt | Tour có đánh giá ở ba trạng thái | Pending/approved/rejected | Mở trang tour; đối chiếu điểm/số lượng | Chỉ approved hiển thị và được tính; tour chưa có hiển thị đúng | Must | Not Run | — | UAT-06 |
| TC-16 | FR-18 | US-16 | Đăng ký, đăng nhập, đăng xuất | Email mới và tài khoản có sẵn | Dữ liệu hợp lệ/sai; mật khẩu biên | Đăng ký; đăng nhập; đăng xuất; thử CSRF sai | Tài khoản hợp lệ hoạt động; mật khẩu băm; lỗi rõ; phiên và CSRF được kiểm tra | Must | Not Run | — | UAT-07, UAT-08, UAT-30 |
| TC-17 | FR-19 | US-17 | Thống kê tài khoản khách | Admin đăng nhập; dữ liệu xác định | Tài khoản active/locked | Mở Tổng quan; đối chiếu truy vấn | Tổng và phân nhóm đúng; không trộn tài khoản Admin/đơn vị | Must | Not Run | — | UAT-35 |
| TC-18 | FR-20 | US-18 | Thống kê tour | Admin đăng nhập | Tour pending/approved/rejected | Mở Tổng quan; đối chiếu dữ liệu | Tổng và từng trạng thái đúng quy tắc | Must | Not Run | — | UAT-35 |
| TC-19 | FR-21, FR-22 | US-19 | Thống kê đơn theo trạng thái/thời gian | Admin đăng nhập; đơn ở sáu trạng thái | Khoảng ngày/tháng/năm | Lọc thống kê; đối chiếu ngày tạo | Số liệu theo sáu trạng thái và ngày tạo chính xác | Must | Not Run | — | UAT-36 |
| TC-20 | FR-23 | US-20 | Thống kê doanh thu thuần | Có thanh toán và hoàn tiền | Giao dịch ở nhiều ngày | Lọc ngày/tháng/năm; tính lại | Doanh thu = đã thanh toán − đã hoàn, nhóm theo ngày thanh toán | Must | Not Run | — | UAT-37 |
| TC-21 | FR-24 | US-21 | Duyệt/từ chối tour và bản sửa | Admin; tour/bản sửa chờ duyệt | Lý do rỗng/hợp lệ | Duyệt; từ chối; so sánh bản sửa | Chỉ Admin xử lý; từ chối cần lý do; khách chỉ thấy nội dung đã duyệt | Must | Not Run | — | UAT-32, UAT-33, UAT-41, UAT-42 |
| TC-22 | FR-25 | US-22 | Admin xem/tìm chi tiết đơn | Admin đăng nhập | Mã đơn, trạng thái, khách | Lọc/tìm; mở chi tiết | Danh sách/chi tiết đúng; dữ liệu nhạy cảm chỉ hiện theo phạm vi | Must | Not Run | — | UAT-12, UAT-30 |
| TC-23 | FR-11, FR-25 | US-23 | Quy trình mới không có bước xác nhận chỗ | Có đơn mới `Chờ thanh toán` và đơn cũ `Chờ xác nhận` | Hai loại đơn | Mở chi tiết; thử hành động quản trị | Đơn mới không có bước xác nhận chỗ/giá; thao tác cũ chỉ áp dụng dữ liệu legacy | Must | Not Run | — | UAT-13, UAT-19 |
| TC-24 | FR-25 | US-24 | Admin hủy đơn kèm lý do | Có đơn được phép hủy | Lý do trống/hợp lệ | Chọn hủy; gửi form | Thiếu lý do bị từ chối; thành công ghi lịch sử; đơn đã trả tạo hoàn tiền | Must | Not Run | — | UAT-15, UAT-16 |
| TC-25 | FR-26 | US-25 | Tài khoản đơn vị tổ chức tách biệt | Admin và đơn vị mẫu | Trạng thái active/inactive; mật khẩu | Admin tạo/đổi mật khẩu; đơn vị đăng nhập | Chỉ đơn vị hợp tác/active đăng nhập khu riêng; không vào khu Admin/khách | Must | Not Run | — | UAT-38, UAT-39 |
| TC-26 | FR-27 | US-26 | Đơn vị quản lý tour và vòng duyệt | Đơn vị đăng nhập | Tour nháp/từ chối/đã duyệt | Tạo; sửa; gửi duyệt; tạo bản sửa; ngừng hiển thị | Chuyển trạng thái đúng; không sửa lúc chờ; chỉ thao tác tour mình | Must | Not Run | — | UAT-40–UAT-45, UAT-47 |
| TC-27 | FR-28 | US-27 | Đơn vị chỉ xem đơn thuộc tour mình | Hai đơn vị có tour/đơn riêng | ID đơn của mình/người khác | Mở danh sách; đổi ID trên URL/request | Chỉ xem đúng trường và đúng quyền sở hữu; đơn khác trả không tìm thấy/403; không có thao tác xử lý | Must | Not Run | — | UAT-46, UAT-47 |
| TC-28 | FR-29 | US-28 | Tính phí dịch vụ và chi trả | Ngày khởi hành kết thúc; nghiệp vụ liên quan đã đóng | Tiền thu, hoàn, tỉ lệ phí | Chạy lập chi trả; xác minh tài khoản; ghi trả | Tối đa một khoản/ngày; công thức đúng; chỉ trả khi tài khoản đã xác minh và có mã giao dịch | Must | Not Run | — | UAT-51, UAT-53, UAT-54 |
| TC-29 | FR-30 | US-29 | Quản lý thông số vận hành | Admin đăng nhập | Giá trị biên/hợp lệ/sai | Sửa từng thông số; đặt tour/thanh toán kiểm chứng | Kiểm tra giới hạn; giá trị hợp lệ áp dụng; thiếu/sai dùng mặc định; có người/thời điểm đổi | Must | Not Run | — | UAT-48, UAT-51, UAT-52 |
| TC-30 | FR-06 | US-30 | Lọc nâng cao tour | Có tour khác ngày, giá, thời lượng, ngôn ngữ, điểm đón | Ngày trong 365 ngày; giá 0–100 triệu; tổ hợp lọc | Áp từng/tổ hợp; tải lại; quay lại; xóa lọc | Kết quả đúng; min > max báo lỗi; URL giữ lọc; xóa lọc phục hồi danh sách | Must | Not Run | — | UAT-55 |
| TC-31 | FR-31 | US-31 | Thích/bỏ thích tour | Khách, khách vãng lai, Admin và đơn vị | Tour công khai/ẩn | Thích hai lần; thử các vai trò | Khách hàng toggles idempotent; số đếm đúng; khách vãng lai về đăng nhập; vai trò khác bị chặn phía máy chủ | Must | Not Run | — | UAT-56 |
| TC-32 | FR-32 | US-32 | Lưu tour và danh sách riêng | Hai khách; tour công khai rồi bị ẩn | Tour của từng khách | Lưu; mở `/tour-da-luu`; bỏ lưu; truy cập chéo | Mỗi khách chỉ thấy danh sách mình; tour ẩn hiện mờ/chỉ bỏ lưu; quyền kiểm tra phía máy chủ | Must | Not Run | — | UAT-57 |
| TC-33 | FR-33 | US-33 | Chia sẻ tour | Trình duyệt có/không Web Share | URL tour | Bấm Chia sẻ trong hai môi trường | Mở bảng chia sẻ hoặc sao chép đúng URL; không cần đăng nhập | Must | Not Run | — | UAT-58 |
| TC-34 | FR-34 | US-34 | Khách bình luận/xóa bình luận | Khách đăng nhập; tour công khai | 0, 1, 1000, 1001 ký tự; 6 lần/10 phút | Gửi dữ liệu biên; xóa mình; thử xóa của người khác | Chỉ 1–1000; giới hạn 5/10 phút; chỉ xóa bình luận mình; số đếm đúng | Must | Not Run | — | UAT-59 |
| TC-35 | FR-34 | US-35 | Admin ẩn/hiện bình luận | Có bình luận visible/hidden | Lý do rỗng/hợp lệ | Ẩn; kiểm tra trang tour; hiện lại | Ẩn bắt buộc lý do; bình luận/số đếm công khai cập nhật; có nhật ký; chỉ Admin thao tác | Must | Not Run | — | UAT-60 |
| TC-36 | FR-16 | US-36 | Khách đánh giá đơn hoàn thành | Khách có đơn của mình completed và đơn chưa completed | Sao 1–5; nhận xét 9/10/1000/1001 ký tự | Gửi/sửa/gửi lại; thử đơn khác | Mỗi đơn một đánh giá; chỉ đơn completed của mình; pending/rejected sửa được; approved khóa | Must | Not Run | — | UAT-61 |
| TC-37 | FR-16 | US-37 | Admin duyệt/từ chối/gỡ đánh giá | Admin; đánh giá pending/approved/rejected | Lý do trống/hợp lệ | Duyệt; từ chối; gửi lại; gỡ | Chuyển trạng thái đúng; từ chối/gỡ cần lý do; không duyệt thẳng rejected; điểm công khai cập nhật | Must | Not Run | — | UAT-62 |
| TC-38 | FR-35 | US-38 | Quản lý tài khoản và dữ liệu cá nhân | Khách đăng nhập | Ảnh hợp lệ/sai; dữ liệu biên; mật khẩu | Tải/xóa ảnh; sửa hồ sơ; đổi mật khẩu; thử vai trò khác | Xác thực toàn bộ phía máy chủ; lưu nguyên tử; CCCD chỉ chủ tài khoản thấy; mật khẩu đổi an toàn | Must | Not Run | — | UAT-63 |
| TC-39 | FR-36 | US-39 | Trợ giúp, điều khoản và Menu | Không yêu cầu đăng nhập | Desktop/mobile; cấu hình vận hành | Mở hai trang; ẩn/hiện Menu; duyệt các trang | Nội dung công khai/nhất quán thông số; Menu giữ trạng thái phù hợp; không còn nhãn “Sắp có” | Must | Not Run | — | UAT-64 |

## 2. Test Case phi chức năng

| Test Case ID | Requirement ID | User Story ID | Mục tiêu | Tiền điều kiện | Dữ liệu kiểm thử | Các bước thực hiện | Kết quả mong đợi | Ưu tiên | Trạng thái | Evidence / Defect ID | UAT Case |
|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-40 | NFR-01 | US-01–US-06 | Khả dụng và dễ đọc | Bản chạy ổn định | Kịch bản xem/tìm/đặt | Người dùng mục tiêu hoàn thành không hướng dẫn miệng | Tiêu đề/nội dung chính dễ tìm; lỗi có thể hành động | Must | Not Run | — | UAT-01–UAT-11 |
| TC-41 | NFR-02 | US-01–US-39 | Tương thích thiết bị | Chrome/Edge; viewport desktop và 360 px | Các trang chính | Mở danh sách, chi tiết, form, ba khu vực | Không mất nội dung chính, không cuộn ngang toàn trang, nút thao tác được | Must | Not Run | — | UAT-01–UAT-64 |
| TC-42 | NFR-03 | US-01–US-03 | Hiệu năng | Môi trường và dữ liệu được ghi nhận | Danh sách/chi tiết | Xóa cache theo quy ước; đo tải nội dung chính nhiều lần | Mục tiêu ≤3 giây hoặc báo cáo sai lệch kèm môi trường; không tự suy diễn | Must | Not Run | — | UAT-01–UAT-06 |
| TC-43 | NFR-04 | US-06, US-22–US-39 | Phân quyền phía máy chủ và CSRF | Bốn vai trò/ba phiên | URL/ID/tokens hợp lệ và giả | Gọi trực tiếp route, sửa ID, thiếu/sai CSRF | Khách/Admin/đơn vị bị giới hạn đúng quyền và quyền sở hữu; không đổi dữ liệu trái phép | Must | Not Run | — | UAT-07, UAT-30, UAT-38–UAT-64 |
| TC-44 | NFR-05 | US-06, US-10, US-27, US-38 | Bảo vệ dữ liệu cá nhân | Có hồ sơ/đơn/bình luận/đánh giá | CCCD, email, phone, ảnh | Kiểm tra màn hình, lỗi, request trái quyền và tệp ảnh | Chỉ thu thập/hiển thị đúng phạm vi; không lộ CCCD/thẻ/token; ảnh được kiểm tra | Must | Not Run | — | UAT-30, UAT-46, UAT-63 |
| TC-45 | NFR-06 | US-06–US-14, US-26–US-29 | Toàn vẹn dữ liệu | Database có khóa/ràng buộc | ID không tồn tại, request trùng, lỗi transaction | Gửi request sai/trùng; mô phỏng lỗi giữa transaction | Không có bản ghi mồ côi/mã trùng; rollback đầy đủ; sức chứa/tiền nhất quán | Must | Not Run | — | UAT-10–UAT-29, UAT-40–UAT-54 |
| TC-46 | NFR-07 | US-07, US-21, US-26 | Truy vết nguồn tour | Admin/đơn vị có quyền | URL nguồn/ngày xác minh trống/hợp lệ | Tạo/sửa/duyệt tour; kiểm tra metadata | Lưu nguồn và lần xác minh khi có; thiếu thì ghi chưa xác minh, không tạo ngày giả | Must | Not Run | — | UAT-31–UAT-34, UAT-40–UAT-45 |
| TC-47 | NFR-08 | US-07, US-26 | Khả năng bảo trì nội dung | Có hai tour | Tên/lịch trình/điều khoản mới | Sửa qua khu quản lý; mở trang khách | Không cần sửa mã giao diện; chỉ tour mục tiêu thay đổi | Must | Not Run | — | UAT-32–UAT-34, UAT-40–UAT-45 |
| TC-48 | NFR-09 | US-06, US-09, US-12, US-24 | Phục hồi và nhật ký | Có thể mô phỏng lỗi lưu/kết nối | Booking/thanh toán/chuyển trạng thái | Gây lỗi; thử lại; xem lịch sử | Không báo thành công/cấp mã khi chưa commit; thao tác quan trọng có người/thời điểm; retry không nhân đôi | Must | Not Run | — | UAT-10–UAT-26 |
| TC-49 | NFR-10 | US-01–US-39 | Tương thích trình duyệt | Chrome và Edge; bổ sung trình duyệt khác khi có | Luồng chính theo vai trò | Chạy smoke trên từng trình duyệt/viewport | Luồng chính hoạt động nhất quán; sai lệch được ghi thành Defect | Must | Not Run | — | UAT-01–UAT-64 |

## 3. Tổng hợp truy vết

| Đối tượng | Bao phủ bởi Test Case | Tình trạng |
|---|---|---|
| US-01–US-39 | TC-01–TC-39, mỗi User Story có ít nhất một Test Case | 39/39 được liên kết |
| FR-01–FR-36 | TC-01–TC-39 | 36/36 được liên kết; FR-12 kiểm tra theo phạm vi đổi/hủy hiện có |
| NFR-01–NFR-10 | TC-40–TC-49 | 10/10 được liên kết |
| UAT-01–UAT-64 | Cột `UAT Case` | 64/64 được tham chiếu; giữ nguyên mã UAT |

## 4. Mẫu ghi nhận một lần thực hiện

| Trường | Nội dung bắt buộc |
|---|---|
| Test Case ID | TC-xx |
| Phiên bản/commit | Chỉ ghi giá trị thực tế đã kiểm thử |
| Môi trường | URL/máy, hệ điều hành, trình duyệt/viewport, database |
| Người thực hiện/ngày | Chỉ ghi khi có dữ liệu thực tế |
| Kết quả thực tế | Hành vi quan sát được |
| Trạng thái | Pass / Fail / Blocked / Not Run |
| Evidence / Defect ID | Đường dẫn Evidence thật hoặc mã lỗi đã tồn tại; chưa có để `—` |

Không chuyển trạng thái sang Pass chỉ từ thông tin “đã chạy”. Kết quả System Testing, chạy thử nội bộ, UAT và nghiệm thu chính thức phải được báo cáo tách biệt.
