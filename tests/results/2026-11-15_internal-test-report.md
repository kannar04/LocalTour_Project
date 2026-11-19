# BÁO CÁO TỔNG HỢP LẦN CHẠY THỬ NỘI BỘ NGÀY 15/11/2026

## 1. Thông tin phiên bản kiểm thử

| Thuộc tính | Thông tin có thể xác nhận từ repository |
|---|---|
| Ngày chạy được ghi nhận | 15/11/2026 |
| Loại hoạt động | Chạy thử nội bộ trước UAT |
| Baseline chức năng | SRS v1.2; phạm vi mở rộng CR2; Product Backlog 39 User Story |
| Bộ ca tham chiếu | UAT-01–UAT-64, gồm 61 Must và 3 Should |
| Phiên bản/commit | Chưa có dữ liệu được lưu trong repository |
| Người thực hiện/giờ chạy | Chưa có dữ liệu được lưu trong repository |

## 2. Môi trường kiểm thử

Tài liệu Sprint 6 ghi nhận UAT dự kiến/chạy trên trang demo `https://localtour.alwaysdata.net` bằng Chrome desktop và các phiên riêng theo vai trò. Tuy nhiên repository không lưu biên bản môi trường riêng cho lần chạy nội bộ ngày 15/11/2026. Vì vậy báo cáo này không khẳng định URL, phiên bản trình duyệt, hệ điều hành, cấu hình máy hoặc database cụ thể của lần chạy.

## 3. Phạm vi kiểm thử

- 39/39 User Story được đưa vào bộ checklist.
- FR-01–FR-36 và các NFR liên quan tới phân quyền, dữ liệu, thiết bị, trình duyệt, phục hồi và nhật ký.
- Bốn nhóm tác nhân: Khách vãng lai, Khách hàng, Admin và Đơn vị tổ chức.
- Các luồng chính: xem/tìm/lọc/so sánh; đặt tour và giữ chỗ; VNPay/VietQR; đổi/hủy; quản trị; khu đơn vị tổ chức; chi trả; tương tác, bình luận, đánh giá, tài khoản và trợ giúp.

## 4. Số lượng ca đã chạy

| Mốc | Số ca được tài liệu Sprint 6 ghi nhận | Ý nghĩa |
|---|---:|---|
| 13/11/2026 | 54 | Lần chạy thử trên bản tích hợp trước khi bổ sung đủ phạm vi |
| 15/11/2026 | 64 | Lần chạy thử đủ bộ sau đợt cập nhật mở rộng CR2 |

Bộ 64 ca gồm 61 ca Must và 3 ca Should. Con số này mô tả số ca được ghi nhận là đã chạy, không phải số ca Pass.

## 5. Kết quả được ghi nhận

Repository không có bảng kết quả Pass/Fail/Blocked/Not Run theo từng UAT Case hoặc Test Case cho lần chạy ngày 15/11/2026. Do đó:

- Không thể xác nhận 64/64 Pass.
- Không có cơ sở tổng hợp tỷ lệ đạt hoặc danh sách ca lỗi.
- Không có Defect ID được liên kết riêng với lần chạy này.
- Không có Evidence theo từng ca để kiểm chứng độc lập.
- Không có cơ sở kết luận đã hoàn tất System Testing, UAT hoặc nghiệm thu chính thức chỉ từ ghi nhận “đã chạy thử đủ 64 ca”.

## 6. Điểm đã điều chỉnh sau lần chạy

Tài liệu Sprint 6 ghi nhận checklist đã được điều chỉnh câu chữ để khớp màn hình, trong đó lần mở rộng đến 64 ca có một điều chỉnh tại UAT-64. Repository cũng ghi nhận phạm vi mới gồm bộ lọc nâng cao, thích/lưu/chia sẻ, bình luận, đánh giá, tài khoản và trợ giúp đã được đưa vào checklist. Không có dữ liệu đủ chi tiết để quy kết các điều chỉnh này cho Defect cụ thể.

## 7. Hạn chế về Evidence

- Không có ảnh/log thực thi được tổ chức theo từng ca trong `tests/results/`.
- Ảnh trong `docs/sprint6/images/` là tài sản tài liệu/hướng dẫn; báo cáo này không tự coi chúng là Evidence của lần chạy.
- Không có danh sách người chạy, giờ chạy, commit, cấu hình máy hoặc defect log gắn với lần chạy.
- Không tạo dữ liệu thay thế cho các khoảng trống trên.

## 8. Phân biệt các mức xác nhận

| Mức | Tình trạng có thể kết luận |
|---|---|
| Đã chạy thử nội bộ | Có ghi nhận 64 ca ngày 15/11/2026 |
| Đã kiểm thử hệ thống và có kết quả từng ca | Chưa đủ dữ liệu trong repository |
| Đã thực hiện UAT chính thức | Chưa có kết quả từng ca/biên bản được nhóm PCG xác nhận |
| Đã nghiệm thu chính thức | Chưa có căn cứ kết luận |

## 9. Kết luận và đề xuất

Lần chạy nội bộ ngày 15/11/2026 đã bao quát bộ checklist 64 ca và 39/39 User Story theo ghi nhận Sprint 6, nhưng bằng chứng hiện tại chỉ đủ xác nhận số ca đã chạy. Cần thu thập bảng kết quả từng ca từ nguồn thực tế, liên kết Evidence/Defect, ghi rõ phiên bản và môi trường, sau đó mới tính tỷ lệ Pass và đưa ra kết luận System Testing. UAT chính thức tiếp tục do nhóm PCG thực hiện và xác nhận riêng.
