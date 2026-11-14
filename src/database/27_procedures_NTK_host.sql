-- =====================================================================
-- LocalTour v0.5 - 27_procedures_NTK_host.sql
-- Mục đích  : Tài khoản đơn vị tổ chức (khu /host): đơn vị đăng nhập, xem tour của mình, thêm /
--             sửa tour, lịch khởi hành, ảnh, lịch trình, dịch vụ và chính sách hủy. Quản trị viên
--             vẫn là người duyệt tour trước khi tour hiển thị cho khách.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - Sprint 6
-- Procedures: NTK_sp_host_profile, NTK_sp_host_tour_list, NTK_sp_host_tour_access,
--             NTK_sp_host_can_edit_tour, NTK_sp_host_can_manage_schedule,
--             NTK_sp_host_can_use_provider, NTK_sp_host_tour_resubmit
--             (4 procedure sau dùng nội bộ, được các procedure ghi dữ liệu của file 13 và 21 gọi),
--             NTK_sp_admin_provider_set_password, NTK_sp_admin_provider_account,
--             NTK_sp_host_booking_list, NTK_sp_host_booking_detail, NTK_sp_host_booking_change_list
--             (đơn vị xem đơn đặt tour của tour mình, chỉ đọc)
-- Quy tắc   : * Tài khoản đơn vị tổ chức = dòng users role 'provider' đi kèm dòng providers
--               (đã có từ Sprint 4). Đơn vị KHÔNG tự đăng ký: quản trị viên thêm đơn vị rồi cấp
--               mật khẩu ở trang "Đơn vị tổ chức". Đơn vị chỉ dùng được khu /host khi tài khoản
--               đang 'active' và trạng thái hợp tác là 'approved'.
--             * Tài khoản đơn vị tách riêng với tài khoản khách hàng: mỗi email chỉ thuộc một
--               tài khoản, tài khoản khách hàng không chuyển thành tài khoản đơn vị.
--             * Đơn vị chỉ thao tác trên tour của chính mình. Việc kiểm tra nằm ở đây (lớp chặn
--               cuối), không chỉ ở PHP: NMT_sp_admin_tour_create / _update và các procedure ảnh,
--               lịch trình, dịch vụ, chính sách hủy gọi NTK_sp_host_can_edit_tour /
--               NTK_sp_host_can_use_provider; NMT_sp_admin_schedule_create / _update gọi
--               NTK_sp_host_can_manage_schedule khi người thao tác không phải quản trị viên.
--             * Vòng duyệt tour của đơn vị: tour mới là "Bản nháp" ('draft'); đơn vị bấm "Gửi
--               duyệt" thì tour sang 'pending' và bị khóa cho tới khi quản trị viên phê duyệt
--               hoặc từ chối (kèm lý do). Đơn vị chỉ sửa thông tin và nội dung (ảnh, lịch trình,
--               dịch vụ, chính sách hủy) khi tour đang 'draft' hoặc 'rejected'; sửa tour bị từ
--               chối thì tour quay về 'draft' (admin_logs 'tour_redraft'). Tour đã duyệt không
--               sửa trực tiếp: đơn vị tạo "bản sửa" (file 32), tour đang hiển thị giữ nguyên cho
--               tới khi quản trị viên duyệt bản sửa. Thêm / sửa lịch khởi hành và giá vé không
--               cần duyệt, làm được ở mọi trạng thái trừ 'archived'.
--             * Đơn đặt tour: đơn vị chỉ XEM đơn của tour mình (ai đi, bao nhiêu khách, số điện
--               thoại và email liên hệ, đơn đã xác nhận / đã thanh toán chưa, khách có xin đổi
--               ngày / hủy không). Hủy đơn, xử lý đổi ngày / hủy và đối chiếu thanh toán vẫn là
--               việc của quản trị viên. Các procedure NTK_sp_host_booking_* không trả mã giao
--               dịch thanh toán hay số tiền hoàn, và chỉ trả dữ liệu khi đơn vị đang hợp tác,
--               tài khoản đang hoạt động.
--             * Không có DEFINER.
-- Chạy sau  : 01_schema.sql -> 21. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- NTK_sp_host_profile(p_user_id)
--   Đơn vị tổ chức của tài khoản đang đăng nhập. 0 hoặc 1 dòng: provider_id, business_name,
--   contact_phone, email, approval_status, user_status, tour_count.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_profile;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_profile(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        p.id              AS provider_id,
        p.business_name,
        p.contact_phone,
        u.email,
        p.approval_status,
        u.status          AS user_status,
        (SELECT COUNT(*)
           FROM tours t
          WHERE t.provider_id = p.id
            AND t.revision_of IS NULL) AS tour_count
    FROM users u
    JOIN providers p ON p.user_id = u.id
    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_tour_list(p_user_id)
--   Mọi tour của đơn vị (mọi trạng thái duyệt): tour bị từ chối, bản nháp và chờ duyệt trước.
--   Bản sửa của tour đã duyệt (tours.revision_of, file 32) không thành dòng riêng: tour gốc
--   mang revision_id / revision_status.
--   Cột: tour_id, title, destination_name, category_name, approval_status, is_public,
--        schedule_count, upcoming_count (lịch chưa khởi hành, đang mở bán hoặc hết chỗ),
--        next_starts_at, reject_note (lý do từ chối gần nhất, chỉ khi tour đang 'rejected'),
--        revision_id, revision_status (bản sửa đang mở của tour; NULL = không có).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_tour_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_tour_list(
    IN p_user_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id                AS tour_id,
        t.title,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        t.approval_status,
        (t.approval_status = 'approved'
         AND p.approval_status = 'approved'
         AND u.status = 'active') AS is_public,
        (SELECT COUNT(*)
           FROM schedules s
          WHERE s.tour_id = t.id) AS schedule_count,
        (SELECT COUNT(*)
           FROM schedules s
          WHERE s.tour_id = t.id
            AND s.status IN ('open', 'full')
            AND s.starts_at > NOW()) AS upcoming_count,
        (SELECT MIN(s.starts_at)
           FROM schedules s
          WHERE s.tour_id = t.id
            AND s.status IN ('open', 'full')
            AND s.starts_at > NOW()) AS next_starts_at,
        IF(t.approval_status = 'rejected',
           (SELECT l.note
              FROM admin_logs l
             WHERE l.target_type = 'tour'
               AND l.target_id = t.id
               AND l.action = 'tour_reject'
             ORDER BY l.created_at DESC, l.id DESC
             LIMIT 1),
           NULL) AS reject_note,
        r.id                AS revision_id,
        r.approval_status   AS revision_status
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    LEFT JOIN tours        r ON r.revision_of = t.id
    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND t.revision_of IS NULL
    ORDER BY FIELD(t.approval_status, 'rejected', 'draft', 'pending', 'approved', 'archived'),
             t.title ASC, t.id ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_tour_access(p_user_id, p_tour_id)
--   Tour (hoặc bản sửa) có thuộc đơn vị của tài khoản này không. 0 dòng = không phải của đơn vị.
--   1 dòng: tour_id, approval_status,
--     can_edit     : 1 = sửa được thông tin và nội dung (tour đang 'draft' / 'rejected', đơn vị
--                    đang hợp tác, tài khoản đang hoạt động),
--     can_schedule : 1 = thêm / sửa được lịch khởi hành và giá vé (không 'archived', không phải
--                    bản sửa),
--     reject_note  : lý do từ chối gần nhất khi đang 'rejected',
--     revision_of, revision_of_title, revision_of_status : tour gốc khi dòng này là bản sửa,
--     revision_id, revision_status : bản sửa đang mở của tour này (NULL = không có).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_tour_access;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_tour_access(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        t.id AS tour_id,
        t.approval_status,
        (t.approval_status IN ('draft', 'rejected')
         AND p.approval_status = 'approved'
         AND u.status = 'active') AS can_edit,
        (t.approval_status <> 'archived'
         AND t.revision_of IS NULL
         AND p.approval_status = 'approved'
         AND u.status = 'active') AS can_schedule,
        IF(t.approval_status = 'rejected',
           (SELECT l.note
              FROM admin_logs l
             WHERE l.target_type = 'tour'
               AND l.target_id = t.id
               AND l.action = 'tour_reject'
             ORDER BY l.created_at DESC, l.id DESC
             LIMIT 1),
           NULL) AS reject_note,
        t.revision_of,
        o.title             AS revision_of_title,
        o.approval_status   AS revision_of_status,
        r.id                AS revision_id,
        r.approval_status   AS revision_status
    FROM tours t
    JOIN providers p ON p.id = t.provider_id
    JOIN users     u ON u.id = p.user_id
    LEFT JOIN tours o ON o.id = t.revision_of
    LEFT JOIN tours r ON r.revision_of = t.id
    WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
      AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_can_edit_tour(p_user_id, p_tour_id, OUT p_allowed)   (dùng nội bộ)
--   Sửa thông tin và nội dung tour (ảnh, lịch trình, dịch vụ, chính sách hủy).
--   p_allowed = TRUE khi p_user_id là tài khoản đơn vị tổ chức đang hoạt động, đơn vị đang
--   hợp tác, là chủ của tour và tour (hoặc bản sửa) đang 'draft' hoặc 'rejected'. Tour đang
--   'pending' bị khóa chờ quản trị viên; tour 'approved' chỉ sửa qua bản sửa (file 32).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_can_edit_tour;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_can_edit_tour(
    IN  p_user_id CHAR(36),
    IN  p_tour_id CHAR(36),
    OUT p_allowed BOOLEAN
)
READS SQL DATA
BEGIN
    SET p_allowed = EXISTS (
        SELECT 1
          FROM tours t
          JOIN providers p ON p.id = t.provider_id
          JOIN users     u ON u.id = p.user_id
         WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
           AND t.approval_status IN ('draft', 'rejected')
           AND p.approval_status = 'approved'
           AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND u.role = 'provider'
           AND u.status = 'active');
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_can_manage_schedule(p_user_id, p_tour_id, OUT p_allowed)   (dùng nội bộ)
--   Thêm / sửa lịch khởi hành và giá vé: không cần duyệt nên làm được ở mọi trạng thái duyệt,
--   trừ tour 'archived'. Bản sửa (tours.revision_of) không có lịch riêng: lịch nằm ở tour gốc.
--   p_allowed = TRUE khi p_user_id là tài khoản đơn vị tổ chức đang hoạt động, đơn vị đang
--   hợp tác và là chủ của tour.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_can_manage_schedule;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_can_manage_schedule(
    IN  p_user_id CHAR(36),
    IN  p_tour_id CHAR(36),
    OUT p_allowed BOOLEAN
)
READS SQL DATA
BEGIN
    SET p_allowed = EXISTS (
        SELECT 1
          FROM tours t
          JOIN providers p ON p.id = t.provider_id
          JOIN users     u ON u.id = p.user_id
         WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
           AND t.approval_status <> 'archived'
           AND t.revision_of IS NULL
           AND p.approval_status = 'approved'
           AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND u.role = 'provider'
           AND u.status = 'active');
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_can_use_provider(p_user_id, p_provider_id, OUT p_allowed)   (dùng nội bộ)
--   p_allowed = TRUE khi p_provider_id là đơn vị (đang hợp tác) của chính tài khoản đơn vị
--   tổ chức p_user_id. Dùng khi đơn vị thêm tour mới.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_can_use_provider;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_can_use_provider(
    IN  p_user_id     CHAR(36),
    IN  p_provider_id CHAR(36),
    OUT p_allowed     BOOLEAN
)
READS SQL DATA
BEGIN
    SET p_allowed = EXISTS (
        SELECT 1
          FROM providers p
          JOIN users u ON u.id = p.user_id
         WHERE p.id = (p_provider_id COLLATE utf8mb4_unicode_ci)
           AND p.approval_status = 'approved'
           AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
           AND u.role = 'provider'
           AND u.status = 'active');
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_tour_resubmit(p_user_id, p_tour_id)   (dùng nội bộ)
--   Gọi bên trong transaction của procedure vừa ghi thay đổi do đơn vị tổ chức thực hiện
--   (không tự START TRANSACTION / COMMIT, không trả dòng nào). Tour (hoặc bản sửa) đang
--   'rejected' quay về 'draft' và ghi admin_logs 'tour_redraft'; đơn vị sửa xong thì bấm "Gửi
--   duyệt" (NTK_sp_host_tour_submit, file 32). Các trạng thái khác giữ nguyên.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_tour_resubmit;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_tour_resubmit(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;

    SELECT t.approval_status INTO v_status
      FROM tours t
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_status = 'rejected' THEN
        UPDATE tours
           SET approval_status = 'draft'
         WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

        INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
        VALUES (UUID(), p_user_id, 'tour', p_tour_id, 'tour_redraft', v_status, 'draft',
                'Đơn vị tổ chức sửa tour bị từ chối: tour về bản nháp', NOW());
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_provider_set_password(p_actor_user_id, p_provider_id, p_password_hash)
--   Quản trị viên cấp hoặc đổi mật khẩu đăng nhập của đơn vị tổ chức (mật khẩu đã băm bằng
--   password_hash() của PHP). Ghi admin_logs 'provider_password' (from / to = trạng thái hợp tác).
--   1 dòng: result = 'ok', 'forbidden' (không phải quản trị viên đang hoạt động),
--           'not_found', 'invalid' (chuỗi băm rỗng hoặc quá dài).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_provider_set_password;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_provider_set_password(
    IN p_actor_user_id CHAR(36),
    IN p_provider_id   CHAR(36),
    IN p_password_hash VARCHAR(300)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_user_id CHAR(36)    DEFAULT NULL;
    DECLARE v_status  VARCHAR(20) DEFAULT NULL;
    DECLARE v_had     BOOLEAN     DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM users
                    WHERE id = (p_actor_user_id COLLATE utf8mb4_unicode_ci)
                      AND role = 'admin' AND status = 'active') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    IF p_password_hash IS NULL OR CHAR_LENGTH(p_password_hash) NOT BETWEEN 20 AND 255 THEN
        SELECT 'invalid' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT p.user_id, p.approval_status, (u.password_hash IS NOT NULL)
      INTO v_user_id, v_status, v_had
      FROM providers p
      JOIN users u ON u.id = p.user_id
     WHERE p.id = (p_provider_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_user_id IS NULL THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    UPDATE users
       SET password_hash = p_password_hash
     WHERE id = v_user_id;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'provider', p_provider_id, 'provider_password', v_status, v_status,
            IF(v_had, 'Đổi mật khẩu đăng nhập', 'Cấp mật khẩu đăng nhập lần đầu'), NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_provider_account(p_provider_id)
--   Tài khoản đăng nhập của đơn vị, cho form "Sửa đơn vị tổ chức".
--   0 hoặc 1 dòng: has_password (1 = đã được cấp mật khẩu), user_status.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_provider_account;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_provider_account(
    IN p_provider_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        (u.password_hash IS NOT NULL AND u.password_hash <> '') AS has_password,
        u.status AS user_status
    FROM providers p
    JOIN users u ON u.id = p.user_id
    WHERE p.id = (p_provider_id COLLATE utf8mb4_unicode_ci);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_register: đã bỏ. Đơn vị tổ chức không tự đăng ký; quản trị viên thêm đơn vị và
--   cấp mật khẩu ở trang "Đơn vị tổ chức". Dòng DROP giữ lại để cơ sở dữ liệu cũ gỡ procedure này.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_register;

-- ---------------------------------------------------------------------
-- NTK_sp_host_booking_list(p_user_id, p_status, p_tour_id)
--   Đơn đặt tour trên các tour của đơn vị (chỉ đọc), đơn mới tạo trước, tối đa 200 dòng.
--   p_status : NULL / '' = mọi trạng thái; ngược lại một giá trị của bookings.status.
--   p_tour_id: NULL / '' = mọi tour của đơn vị; ngược lại chỉ đơn của tour đó.
--   Cột: booking_id, code, status, created_at, contact_name, contact_phone, tour_id, tour_title,
--        package_name, starts_at, people (tổng số vé), total_vnd, payment_status (khoản thanh
--        toán tiêu biểu, NULL = chưa có), pending_change_count (yêu cầu đổi ngày / hủy đang chờ
--        quản trị viên xử lý).
--   0 dòng khi tài khoản không phải đơn vị đang hợp tác hoặc tour không thuộc đơn vị.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_booking_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_booking_list(
    IN p_user_id CHAR(36),
    IN p_status  VARCHAR(30),
    IN p_tour_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id              AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.contact_name,
        b.contact_phone,
        t.id              AS tour_id,
        t.title           AS tour_title,
        b.package_name,
        s.starts_at,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        b.total_vnd,
        (SELECT p.status
           FROM payments p
          WHERE p.booking_id = b.id
          ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
          LIMIT 1)        AS payment_status,
        (SELECT COUNT(*)
           FROM booking_change_requests r
          WHERE r.booking_id = b.id
            AND r.status = 'pending') AS pending_change_count
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    JOIN users u      ON u.id = pr.user_id
    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND u.status = 'active'
      AND pr.approval_status = 'approved'
      AND (NULLIF(p_status, '') IS NULL OR b.status = (p_status COLLATE utf8mb4_unicode_ci))
      AND (NULLIF(p_tour_id, '') IS NULL OR t.id = (p_tour_id COLLATE utf8mb4_unicode_ci))
    ORDER BY b.created_at DESC, b.code
    LIMIT 200;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_booking_detail(p_user_id, p_booking_id)
--   Một đơn đặt tour của tour thuộc đơn vị (chỉ đọc). 0 dòng = không có đơn này hoặc đơn thuộc
--   tour của đơn vị khác (ứng dụng trả 404).
--   1 dòng: booking_id, code, status, created_at, hold_expires_at, total_vnd, tickets_vnd,
--   extras_vnd, voucher_code (NULL = chưa cấp), package_name, contact_name, contact_phone,
--   contact_email (người liên hệ của đơn, để đơn vị báo cho khách trước chuyến đi),
--   tour_id, tour_title, starts_at, ends_at, schedule_capacity, schedule_remaining,
--   schedule_status, people, payment_status (khoản thanh toán tiêu biểu, NULL = chưa có).
--   Dòng vé, phụ thu và danh sách khách đọc bằng NTK_sp_admin_booking_line_list /
--   _extra_list / _passenger_list (file 07) sau khi procedure này trả về đơn.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_booking_detail;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_booking_detail(
    IN p_user_id    CHAR(36),
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.id                AS booking_id,
        b.code,
        b.status,
        b.created_at,
        b.hold_expires_at,
        b.total_vnd,
        (SELECT COALESCE(SUM(bl.line_total_vnd), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS tickets_vnd,
        (SELECT COALESCE(SUM(bx.line_total_vnd), 0)
           FROM booking_extras bx
          WHERE bx.booking_id = b.id) AS extras_vnd,
        b.voucher_code,
        b.package_name,
        b.contact_name,
        b.contact_phone,
        b.contact_email,
        t.id                AS tour_id,
        t.title             AS tour_title,
        s.starts_at,
        s.ends_at,
        s.capacity          AS schedule_capacity,
        s.remaining         AS schedule_remaining,
        s.status            AS schedule_status,
        (SELECT COALESCE(SUM(bl.quantity), 0)
           FROM booking_lines bl
          WHERE bl.booking_id = b.id) AS people,
        (SELECT p.status
           FROM payments p
          WHERE p.booking_id = b.id
          ORDER BY FIELD(p.status, 'paid', 'awaiting_reconciliation', 'processing', 'pending', 'failed'), p.id
          LIMIT 1)          AS payment_status
    FROM bookings b
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    JOIN users u      ON u.id = pr.user_id
    WHERE b.id = (p_booking_id COLLATE utf8mb4_unicode_ci)
      AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND u.status = 'active'
      AND pr.approval_status = 'approved';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_booking_change_list(p_user_id, p_booking_id)
--   Yêu cầu đổi ngày / hủy tour của một đơn thuộc tour của đơn vị (chỉ đọc, mới trước): đơn vị
--   biết khách xin gì và quản trị viên đã trả lời thế nào, không xử lý được.
--   Cột: request_id, type, status, reason, created_at, handled_at, requested_starts_at (lịch
--        khách xin đổi sang, NULL với yêu cầu hủy), result_note (kết quả xử lý, NULL = chưa xử lý).
--   0 dòng khi đơn không thuộc tour của đơn vị.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_booking_change_list;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_booking_change_list(
    IN p_user_id    CHAR(36),
    IN p_booking_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        r.id           AS request_id,
        r.type,
        r.status,
        r.reason,
        r.created_at,
        r.handled_at,
        ns.starts_at   AS requested_starts_at,
        r.result_note
    FROM booking_change_requests r
    JOIN bookings b   ON b.id = r.booking_id
    JOIN schedules s  ON s.id = b.schedule_id
    JOIN tours t      ON t.id = s.tour_id
    JOIN providers pr ON pr.id = t.provider_id
    JOIN users u      ON u.id = pr.user_id
    LEFT JOIN schedules ns ON ns.id = r.requested_schedule_id
    WHERE r.booking_id = (p_booking_id COLLATE utf8mb4_unicode_ci)
      AND u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
      AND u.role = 'provider'
      AND u.status = 'active'
      AND pr.approval_status = 'approved'
    ORDER BY r.created_at DESC, r.id;
END$$
DELIMITER ;
