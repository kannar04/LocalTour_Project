# Kiểm thử — LocalTour

Thư mục `tests/` lưu kế hoạch, ca kiểm thử và kết quả kiểm thử dự án. Nội dung hiện tại là bản phác thảo cho MVP; chưa có mã kiểm thử tự động và chưa thực hiện kiểm thử sản phẩm.

## Tài liệu

| File / Thư mục | Nội dung |
| --- | --- |
| [test_plan.md](test_plan.md) | Phạm vi, cách thực hiện và điều kiện hoàn thành kiểm thử. |
| [test_cases.md](test_cases.md) | Các ca kiểm thử thủ công sơ bộ cho chức năng chính. |
| `results/` | Kết quả thực hiện, ảnh minh chứng và báo cáo lỗi khi có sản phẩm. |

## Quy ước

- Mỗi ca kiểm thử có mã riêng, điều kiện ban đầu, bước thực hiện và kết quả mong đợi.
- Dùng dữ liệu mẫu; không lưu thông tin cá nhân thật hoặc khóa bí mật trong minh chứng.
- Khi thực hiện, ghi phiên bản/commit, môi trường, người kiểm thử, ngày kiểm thử và kết quả thực tế.
- Sử dụng trạng thái `Not Run`, `Pass`, `Fail` hoặc `Blocked`. Ca thất bại cần liên kết đến báo cáo lỗi.
- Lưu báo cáo trong `results/` theo tên `YYYY-MM-DD_test-report.md`; ghi lỗi với bước tái hiện, kết quả mong đợi, kết quả thực tế và minh chứng.
- Bổ sung kiểm thử tự động và hướng dẫn chạy sau khi nhóm chọn công nghệ.
