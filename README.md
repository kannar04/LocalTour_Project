# LocalTour

**Website khám phá, so sánh và đặt tour du lịch địa phương.**

LocalTour là dự án học phần hướng đến xây dựng một sản phẩm khả dụng tối thiểu
(MVP), giúp người dùng tìm kiếm, so sánh và đặt tour dựa trên thông tin được
trình bày thống nhất về giá, lịch trình, thời lượng và dịch vụ đi kèm.

## Trạng thái dự án

Dự án hiện ở giai đoạn **phân tích yêu cầu và thiết kế kỹ thuật**. Repository đã
có:

- Báo cáo phân tích 200 phản hồi khảo sát và bản SRS v0.1.
- Problem Statement, Project Charter, Stakeholder Register và Team Charter.
- Use Case, User Flow, BPMN, wireframe cho bốn màn hình chính và ERD sơ bộ.
- Lược đồ cơ sở dữ liệu gồm 26 bảng, tương thích MariaDB 10.4 và MySQL 8.
- Hợp đồng dữ liệu, route API dự kiến và quy ước lỗi cho Sprint 3.
- Kế hoạch kiểm thử và 16 ca kiểm thử sơ bộ.

Mã ứng dụng, cấu hình cài đặt/build và kiểm thử tự động **chưa được triển khai**
trên nhánh `main`. Các route trong tài liệu Sprint 3 là thiết kế mục tiêu, chưa
phải API đang hoạt động.

## Phạm vi MVP

- Xem danh sách và thông tin chi tiết tour địa phương.
- Tìm kiếm, lọc và sắp xếp tour theo các tiêu chí chính.
- So sánh thông tin giữa các tour.
- Xem đánh giá của người dùng.
- Đặt tour và lưu thông tin đặt tour.
- Quản lý tour và đơn đặt tour ở phía đơn vị cung cấp/quản trị.

### Ngoài phạm vi hiện tại

- Ứng dụng Android/iOS riêng.
- AI đề xuất tour nâng cao và theo dõi GPS thời gian thực.
- Đặt khách sạn hoặc phương tiện di chuyển.
- Thị trường quốc tế và tích hợp quy mô lớn với nền tảng bên thứ ba.

## Cấu trúc repository

```text
LocalTour_Project/
├── docs/
│   ├── diagram/       # BPMN, Use Case, User Flow, wireframe và ERD
│   ├── docs/          # Tài liệu phân tích, SRS và quy tắc nhóm
│   └── sprint3/       # Thiết kế dữ liệu, route API và quy ước lỗi
├── planning/          # Kế hoạch và báo cáo theo tuần/sprint
├── src/
│   ├── database/      # Schema, migration và dữ liệu mẫu
│   └── ...            # Khung thư mục mã nguồn theo trách nhiệm
├── tests/             # Kế hoạch, ca kiểm thử và kết quả
└── README.md
```

Xem [hướng dẫn cấu trúc mã nguồn](src/README.md) để biết trách nhiệm của từng
thư mục trong `src/`.

## Tài liệu chính

| Tài liệu | Nội dung |
| --- | --- |
| [Problem Statement](docs/docs/problem_statement.md) | Vấn đề, người dùng mục tiêu và cơ sở lựa chọn đề tài. |
| [Project Charter](docs/docs/project_charter.md) | Mục tiêu, phạm vi, sản phẩm bàn giao và rủi ro. |
| [Stakeholder Register](docs/docs/stakeholder_register.md) | Các bên liên quan, kỳ vọng và cách phối hợp. |
| [Team Charter](docs/docs/team_charter.md) | Thành viên, vai trò và quy tắc làm việc nhóm. |
| [Research Report](docs/docs/Research%20reports) | Kết quả phân tích 200 phản hồi khảo sát. |
| [SRS v0.1](docs/docs/SRS%20v0.1) | Đặc tả yêu cầu phần mềm phiên bản 0.1. |
| [Trường dữ liệu Tour](docs/sprint3/01-truong-du-lieu.md) | Hợp đồng dữ liệu cho Tour List và Tour Detail. |
| [Route và quy ước lỗi](docs/sprint3/03-route-va-quy-uoc-loi.md) | Route dự kiến, hợp đồng API và định dạng lỗi. |
| [Lược đồ cơ sở dữ liệu](src/database/01_schema.sql) | Script tạo schema 26 bảng. |
| [Kế hoạch Sprint 1](planning/week_01_plan.md) | Kế hoạch công việc tuần đầu tiên. |
| [Kế hoạch Sprint 2](planning/week_02_plan) | Kế hoạch và báo cáo hoàn thành Sprint 2. |
| [Hướng dẫn kiểm thử](tests/README.md) | Quy ước quản lý ca kiểm thử và minh chứng. |

Các sơ đồ và wireframe được lưu tại [`docs/diagram/`](docs/diagram/).

## Cơ sở dữ liệu

File [`src/database/01_schema.sql`](src/database/01_schema.sql) tạo lược đồ
`db_localtour` với các đặc điểm chính:

- 26 bảng sử dụng InnoDB và `utf8mb4_unicode_ci`.
- Khóa chính dạng UUID (`CHAR(36)`).
- Tương thích MariaDB 10.4 (XAMPP) và MySQL 8.

Hiện repository chưa có migration hoàn chỉnh hoặc seed data. Hãy kiểm tra script
trong môi trường phát triển trước khi sử dụng với dữ liệu thật.

## Kiểm thử

[Kế hoạch kiểm thử](tests/test_plan.md) và
[16 ca kiểm thử sơ bộ](tests/test_cases.md) bao phủ các luồng tìm kiếm, lọc, so
sánh, đặt tour, quản lý tour, phân quyền và giao diện. Các ca kiểm thử hiện chưa
được chạy; kết quả và minh chứng sẽ được lưu tại `tests/results/`.

## Thành viên

| Thành viên | Vai trò |
| --- | --- |
| Lê Trung Phong | Project Manager, Developer |
| Hồ Duy Hải | Business Analyst, QA/Documentation |
| Nguyễn Tuấn Khôi | UI/UX Designer, Developer |
| Nguyễn Minh Thức | Developer, UI/UX Designer |
| Đỗ Sơn Thành | QA/Documentation, Business Analyst |

## Bước tiếp theo

1. Thống nhất framework và cấu hình môi trường phát triển.
2. Hoàn thiện migration/seed từ schema hiện tại.
3. Triển khai route, controller, model và giao diện theo hợp đồng đã thiết kế.
4. Bổ sung hướng dẫn cài đặt, chạy ứng dụng và kiểm thử tự động.
