# LocalTour

**Website khám phá, so sánh và đặt tour du lịch địa phương.**

LocalTour là dự án học phần hướng đến xây dựng một sản phẩm khả dụng tối thiểu (MVP), tập trung thông tin tour theo cấu trúc thống nhất để người dùng tìm kiếm, so sánh và đặt tour phù hợp với ngân sách, nhu cầu và lịch trình.

## Trạng thái hiện tại

Repository đang ở giai đoạn khởi tạo: đã có tài liệu phân tích, kế hoạch tuần 01, khung thư mục mã nguồn và tài liệu kiểm thử sơ bộ. Chưa có mã ứng dụng, công nghệ triển khai, cấu hình chạy/build hoặc kiểm thử tự động.

Các chức năng bên dưới là phạm vi dự kiến. Nhận định về vấn đề và nhu cầu người dùng chưa được xác nhận bằng khảo sát thực tế.

## Vấn đề và người dùng mục tiêu

Theo quan sát ban đầu của nhóm, người muốn đặt tour phải tham khảo nhiều nguồn rời rạc. Giá, lịch trình, thời lượng, dịch vụ và đánh giá có thể không được trình bày thống nhất, khiến việc so sánh và đánh giá độ tin cậy mất nhiều thời gian.

- **Nhóm trọng tâm:** Sinh viên và người trẻ ít kinh nghiệm đặt tour, có ngân sách hạn chế hoặc muốn khám phá các điểm đến địa phương ít phổ biến.
- **Nhóm mở rộng:** Gia đình và người trung niên có nhu cầu lựa chọn tour phù hợp; giả định này cần xác minh.
- **Đơn vị tổ chức tour:** Cung cấp, quản lý thông tin tour và tiếp cận khách hàng.

Nhóm dự kiến kiểm chứng vấn đề bằng khoảng 200 phản hồi khảo sát, 10 cuộc phỏng vấn và phân tích các website du lịch hiện có. Đây là mục tiêu thu thập bằng chứng, chưa phải kết quả đã đạt được. Xem [Problem Statement](docs/docs/problem_statement.md).

## Phạm vi MVP

- Xem danh sách và thông tin chi tiết tour địa phương.
- Tìm kiếm, lọc và sắp xếp theo địa điểm, giá, thời lượng.
- So sánh thông tin giữa các tour theo cùng tiêu chí.
- Xem đánh giá của người dùng.
- Đặt tour cơ bản và lưu thông tin đặt tour.
- Quản lý thông tin tour ở phía quản trị/đơn vị cung cấp.

Thông tin tour dự kiến gồm địa điểm, giá, thời lượng, lịch trình và dịch vụ đi kèm. Nhóm có thể sử dụng dữ liệu mẫu nếu chưa tiếp cận được dữ liệu thực tế.

### Ngoài phạm vi

- Ứng dụng Android/iOS riêng và thanh toán trực tuyến thực tế.
- AI đề xuất tour nâng cao và theo dõi GPS thời gian thực.
- Đặt khách sạn hoặc phương tiện di chuyển.
- Thị trường du lịch quốc tế, hệ thống tích điểm phức tạp và tích hợp quy mô lớn với nền tảng bên thứ ba.

Phạm vi, ràng buộc, giả định và rủi ro được mô tả trong [Project Charter](docs/docs/project_charter.md).

## Cấu trúc repository

```text
LocalTour_Project/
├── README.md
├── docs/          # Phân tích vấn đề, điều lệ dự án và tài liệu nhóm
├── planning/      # Kế hoạch và theo dõi công việc
├── src/           # Giao diện và xử lý máy chủ trong một dự án chung
└── tests/         # Kế hoạch, ca kiểm thử và kết quả
```

`src/` tổ chức theo trách nhiệm: `pages/`, `components/`, `layouts/` dành cho giao diện; `routes/`, `controllers/`, `services/`, `models/` và `database/` dành cho xử lý yêu cầu, nghiệp vụ và dữ liệu. Cấu trúc có thể được điều chỉnh khi nhóm thống nhất framework. Xem [hướng dẫn cấu trúc mã nguồn](src/README.md).

## Tài liệu dự án

| Tài liệu | Nội dung |
| --- | --- |
| [Problem Statement](docs/docs/problem_statement.md) | Lý do chọn đề tài, vấn đề, người dùng và kế hoạch kiểm chứng. |
| [Project Charter](docs/docs/project_charter.md) | Mục tiêu, phạm vi, sản phẩm bàn giao, rủi ro và tiêu chí thành công. |
| [Stakeholder Register](docs/docs/stakeholder_register.md) | Các bên liên quan, kỳ vọng, mức ảnh hưởng và cách phối hợp. |
| [Team Charter](docs/docs/team_charter.md) | Thành viên, vai trò và quy tắc làm việc nhóm. |
| [Kế hoạch tuần 01](planning/week_01_plan.md) | Công việc, người phụ trách, hạn và trạng thái theo ảnh Trello. |
| [Cấu trúc mã nguồn](src/README.md) | Nơi lưu từng phần trong dự án chung. |
| [Hướng dẫn kiểm thử](tests/README.md) | Quy ước quản lý ca kiểm thử, kết quả và minh chứng. |

## Thành viên

| Thành viên | Vai trò |
| --- | --- |
| Lê Trung Phong | Project Manager, Developer |
| Hồ Duy Hải | Business Analyst, QA/Documentation |
| Nguyễn Tuấn Khôi | UI/UX Designer, Developer |
| Nguyễn Minh Thức | Developer, UI/UX Designer |
| Đỗ Sơn Thành | QA/Documentation, Business Analyst |

Nhóm trao đổi qua Discord và Zalo, phân công công việc qua ClickUp và quản lý mã nguồn bằng GitHub. Lịch họp nội bộ là 10h30 Chủ nhật; họp với PCG lúc 17h15 thứ Năm. Quy tắc phối hợp và sử dụng AI được ghi trong [Team Charter](docs/docs/team_charter.md).

## Kiểm thử và tiêu chí hoàn thành

[Kế hoạch kiểm thử](tests/test_plan.md) và [16 ca kiểm thử sơ bộ](tests/test_cases.md) bao phủ tìm kiếm, lọc, so sánh, đặt tour, quản lý tour, phân quyền và giao diện. Các ca hiện ở trạng thái `Not Run`; kết quả thực hiện sẽ được lưu tại `tests/results/`.

MVP cần hoàn thành trong thời gian học phần, các chức năng chính hoạt động đúng, người dùng hoàn thành được quy trình đặt tour cơ bản, có phản hồi từ người dùng mục tiêu và được giảng viên chấp nhận cùng tài liệu dự án.

## Chuẩn bị triển khai

Hiện chưa có lệnh cài đặt hoặc chạy ứng dụng. Bước tiếp theo là thống nhất công nghệ, thiết kế giao diện và cơ sở dữ liệu, rồi triển khai các chức năng trong phạm vi MVP. Hướng dẫn cài đặt, cấu hình môi trường, chạy và kiểm thử sẽ được bổ sung khi có ứng dụng thực tế.
