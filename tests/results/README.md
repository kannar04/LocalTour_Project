# QUẢN LÝ KẾT QUẢ KIỂM THỬ VÀ EVIDENCE

Thư mục này lưu báo cáo thực thi kiểm thử. Không lưu khóa bí mật, mật khẩu, token, CCCD hoặc dữ liệu cá nhân thật.

## 1. Tài liệu hiện có

| Tệp | Nội dung |
|---|---|
| [2026-11-15_internal-test-report.md](2026-11-15_internal-test-report.md) | Tổng hợp lần chạy thử nội bộ 64 ca ngày 15/11/2026 từ tài liệu Sprint 6 |

## 2. Cấu trúc Evidence

Khi có Evidence thực tế, tạo thư mục `<YYYY-MM-DD>-<phạm-vi>/TC-xx/` và đặt tên tệp `TC-xx_<bước>_<mô-tả-ngắn>.<ext>`. Báo cáo lần chạy phải liên kết tương đối tới tệp đó.

Không sao chép ảnh hướng dẫn sử dụng thành Evidence kiểm thử. Không tạo ảnh, log, thời gian, người chạy, commit hoặc Defect ID khi repository không có dữ liệu thực tế.

## 3. Quy tắc kết quả

| Trạng thái | Điều kiện |
|---|---|
| Pass | Kết quả thực tế khớp toàn bộ kết quả mong đợi |
| Fail | Có sai lệch; liên kết Defect ID nếu đã cấp |
| Blocked | Không thể hoàn tất do phụ thuộc/môi trường/dữ liệu |
| Not Run | Chưa thực hiện trên phiên bản báo cáo |

“Đã chạy” chỉ xác nhận hoạt động thực thi đã diễn ra, không mặc nhiên là Pass. Kết quả nội bộ, System Testing, UAT chính thức và nghiệm thu là các mốc độc lập.

## 4. Defect và hồi quy

- Defect phải liên kết đến Test Case, phiên bản, bước tái hiện và Evidence thật.
- Sau khi sửa, ghi kết quả retest và các ca regression liên quan.
- Nếu chưa có defect log chính thức, để Defect ID là `—`.
- UAT chính thức chỉ cập nhật khi có kết quả do nhóm PCG cung cấp.
