# TÀI LIỆU VÀ KẾT QUẢ KIỂM THỬ LOCALTOUR

Thư mục này quản lý kế hoạch, Test Case và kết quả kiểm thử nội bộ. UAT chính thức được quản lý trong tài liệu Sprint 6 và do nhóm PCG thực hiện độc lập.

| Tài liệu | Vai trò |
|---|---|
| [test_plan.md](test_plan.md) | Kế hoạch kiểm thử chính thức, phạm vi US-01–US-39, FR-01–FR-36, NFR-01–NFR-10 |
| [test_cases.md](test_cases.md) | Test Case và ma trận FR/NFR–US–TC–UAT |
| [UAT Checklist](../docs/sprint6/04-uat-checklist.md) | Bộ UAT-01–UAT-64: 61 Must, 3 Should, phủ 39/39 User Story |
| [results/](results/README.md) | Báo cáo lần chạy và Evidence thực tế |

## Trạng thái hiện tại

Tài liệu Sprint 6 ghi nhận nhóm phát triển đã chạy thử nội bộ 54 ca ngày 13/11/2026 và 64 ca ngày 15/11/2026. Repository chưa lưu bảng Pass/Fail theo từng ca hoặc Evidence đầy đủ, vì vậy không được suy diễn 64/64 Pass. UAT chính thức và nghiệm thu chỉ được kết luận từ kết quả do nhóm PCG xác nhận.

Repository chưa có bộ mã kiểm thử tự động. Phương pháp hiện tại là kiểm thử thủ công theo Test Case và checklist UAT.

## Quy tắc trạng thái

| Trạng thái | Cách dùng |
|---|---|
| Pass | Kết quả thực tế khớp toàn bộ kết quả mong đợi và có ghi nhận lần chạy |
| Fail | Có ít nhất một sai lệch; liên kết Defect ID nếu đã được cấp |
| Blocked | Không thể tiếp tục do môi trường, dữ liệu hoặc phụ thuộc; ghi rõ nguyên nhân |
| Not Run | Chưa thực hiện trên phiên bản đang báo cáo |

## Quy tắc lưu Evidence và Defect

- Cấu trúc: `results/<ngày>-<phạm-vi>/TC-xx/` khi có tệp thực tế.
- Tên tệp: `TC-xx_<bước>_<mô-tả-ngắn>.<ext>`; loại bỏ mật khẩu, token, CCCD, email/số điện thoại thật và khóa thanh toán.
- Báo cáo phải ghi đường dẫn tương đối đến Evidence, phiên bản, môi trường, người/ngày thực hiện khi thông tin đó thực sự được ghi nhận.
- Defect ID chỉ dùng mã đã tồn tại trong defect log/công cụ quản lý; liên kết hai chiều Defect ↔ Test Case. Chưa có mã thì để `—`.
- Không tạo ảnh minh chứng giả, không đổi tên ảnh chức năng thành Evidence chạy thử và không tự điền Pass.
