-- =====================================================================
-- LocalTour v0.6 - 32_procedures_NTK_tour_revision.sql
-- Mục đích  : Vòng duyệt tour của đơn vị tổ chức (khu /host): gửi duyệt, ngừng hiển thị và
--             "bản sửa" của tour đã duyệt.
-- Phụ trách : Nguyễn Tuấn Khôi (NTK) - Sprint 6
-- Procedures: NTK_sp_host_tour_submit, NTK_sp_host_tour_archive,
--             NTK_sp_host_tour_revision_start, NTK_sp_host_tour_revision_discard,
--             NTK_sp_admin_tour_revision_compare, NTK_sp_tour_image_in_use,
--             NTK_sp_tour_revision_purge, NTK_sp_tour_revision_purge_of,
--             NTK_sp_tour_revision_apply (3 procedure sau dùng nội bộ)
-- Quy tắc   : * Trạng thái tour của đơn vị:
--                 draft -> pending -> approved            (đơn vị gửi duyệt, quản trị viên duyệt)
--                 pending -> rejected -> draft -> pending (từ chối kèm lý do, đơn vị sửa rồi gửi lại)
--                 approved -> archived                    (đơn vị hoặc quản trị viên ngừng hiển thị)
--               Đơn vị chỉ sửa thông tin và nội dung khi tour đang 'draft' / 'rejected' (file 27);
--               tour 'pending' bị khóa cho tới khi quản trị viên xử lý. Đơn vị không tự duyệt,
--               không đổi đơn vị tổ chức của tour, không tự đánh dấu "Đã xác minh".
--             * Bản sửa (tours.revision_of, file 31): đơn vị muốn sửa tour ĐÃ DUYỆT thì tạo bản
--               sửa = một dòng tours ẩn chép từ tour gốc (thông tin, ảnh, lịch trình, dịch vụ,
--               chính sách hủy mới nhất), trạng thái 'draft'. Đơn vị sửa bản đó bằng chính các
--               trang sửa tour, rồi gửi duyệt như một tour thường. Tour gốc vẫn hiển thị nguyên
--               nội dung cũ cho khách. Quản trị viên xem phần khác nhau giữa bản đang hiển thị và
--               bản sửa rồi:
--                 - phê duyệt: LTP_sp_admin_tour_set_approval (file 03) gọi
--                   NTK_sp_tour_revision_apply, trong MỘT transaction chép nội dung bản sửa vào
--                   tour gốc rồi xóa dòng bản sửa; tour gốc vẫn 'approved'.
--                 - từ chối (kèm lý do): bản sửa sang 'rejected', tour gốc không đổi; đơn vị xem
--                   lý do, sửa tiếp (bản sửa về 'draft') rồi gửi lại, hoặc hủy bản sửa.
--               Mỗi tour tối đa một bản sửa đang mở. Bản sửa không bao giờ 'approved' nên không
--               hiện ở trang khách; bản sửa không có lịch khởi hành, giá vé hay đơn đặt tour (lịch
--               và giá của tour gốc không cần duyệt, sửa thẳng trên tour gốc).
--             * Áp dụng bản sửa chỉ chép các ô đơn vị sửa được. Đơn vị tổ chức, nguồn tham khảo,
--               trạng thái xác minh, tọa độ bản đồ và trạng thái duyệt của tour gốc giữ nguyên.
--               Chính sách hủy: bản sửa có chính sách khác chính sách mới nhất của tour gốc thì
--               thêm thành phiên bản mới của tour gốc (đơn đã đặt giữ phiên bản lúc đặt).
--             * Ngừng hiển thị: đơn vị chỉ ngừng được tour đang 'approved' và không còn đơn đang
--               chờ / đã xác nhận (như quy tắc của quản trị viên, file 21). Tour không bị xóa.
--               Hiển thị lại vẫn do quản trị viên làm (NMT_sp_admin_tour_restore).
--             * Mọi procedure kiểm tra lại trong SQL: người thao tác là tài khoản đơn vị đang
--               hoạt động, đơn vị đang hợp tác và là chủ của tour. Không có DEFINER.
-- Chạy sau  : 01 -> 31. Chạy lại được (DROP PROCEDURE IF EXISTS).
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- NTK_sp_host_tour_submit(p_user_id, p_tour_id)
--   Đơn vị gửi tour (hoặc bản sửa) cho quản trị viên duyệt: 'draft' / 'rejected' -> 'pending'.
--   Từ lúc này đơn vị không sửa được thông tin, nội dung cho tới khi quản trị viên xử lý.
--   Ghi admin_logs 'tour_submit'.
--   1 dòng: result.
--     result = 'ok'
--              'forbidden'             : không phải tài khoản đơn vị đang hoạt động, đang hợp tác.
--              'not_found'             : không có tour này hoặc tour của đơn vị khác.
--              'invalid_transition'    : tour không ở trạng thái 'draft' / 'rejected'.
--              'original_not_approved' : bản sửa của tour gốc không còn 'approved' (tour gốc đang
--                                        ngừng hiển thị hoặc chờ duyệt lại).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_tour_submit;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_tour_submit(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status   VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_original CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_owner    BOOLEAN     DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1
                     FROM users u
                     JOIN providers p ON p.user_id = u.id
                    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND u.role = 'provider' AND u.status = 'active'
                      AND p.approval_status = 'approved') THEN
        SELECT 'forbidden' AS result;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT t.approval_status, t.revision_of INTO v_status, v_original
      FROM tours t
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    SET v_owner = EXISTS (SELECT 1
                            FROM tours t
                            JOIN providers p ON p.id = t.provider_id
                           WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                             AND p.user_id = (p_user_id COLLATE utf8mb4_unicode_ci));

    IF v_status IS NULL OR NOT v_owner THEN
        ROLLBACK;
        SELECT 'not_found' AS result;
        LEAVE proc;
    END IF;

    IF v_status NOT IN ('draft', 'rejected') THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result;
        LEAVE proc;
    END IF;

    IF v_original IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM tours o WHERE o.id = v_original AND o.approval_status = 'approved') THEN
        ROLLBACK;
        SELECT 'original_not_approved' AS result;
        LEAVE proc;
    END IF;

    UPDATE tours
       SET approval_status = 'pending'
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_user_id, 'tour', p_tour_id, 'tour_submit', v_status, 'pending',
            IF(v_original IS NULL, 'Đơn vị tổ chức gửi duyệt tour', 'Đơn vị tổ chức gửi duyệt bản sửa'), NOW());

    COMMIT;
    SELECT 'ok' AS result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_tour_archive(p_user_id, p_tour_id)
--   Đơn vị ngừng hiển thị tour của mình: 'approved' -> 'archived' (ghi admin_logs
--   'tour_archive'). Tour không bị xóa; đơn và lịch sử giữ nguyên. Quản trị viên hiển thị lại.
--   1 dòng: result, active_bookings.
--     result = 'ok'
--              'forbidden'          : không phải tài khoản đơn vị đang hoạt động, đang hợp tác.
--              'not_found'          : không có tour này hoặc tour của đơn vị khác.
--              'invalid_transition' : tour không ở trạng thái 'approved' (hoặc là bản sửa).
--              'has_bookings'       : còn đơn pending / awaiting_payment / confirmed
--                                     (active_bookings = số đơn đó).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_tour_archive;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_tour_archive(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status   VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_original CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_owner    BOOLEAN     DEFAULT FALSE;
    DECLARE v_locked   INT         DEFAULT 0;
    DECLARE v_active   INT         DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1
                     FROM users u
                     JOIN providers p ON p.user_id = u.id
                    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND u.role = 'provider' AND u.status = 'active'
                      AND p.approval_status = 'approved') THEN
        SELECT 'forbidden' AS result, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT t.approval_status, t.revision_of INTO v_status, v_original
      FROM tours t
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    SET v_owner = EXISTS (SELECT 1
                            FROM tours t
                            JOIN providers p ON p.id = t.provider_id
                           WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                             AND p.user_id = (p_user_id COLLATE utf8mb4_unicode_ci));

    IF v_status IS NULL OR NOT v_owner THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS active_bookings;
        LEAVE proc;
    END IF;

    IF v_status <> 'approved' OR v_original IS NOT NULL THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, 0 AS active_bookings;
        LEAVE proc;
    END IF;

    -- Khóa các lịch của tour: không có đơn mới được tạo trong lúc kiểm tra (như file 21).
    SELECT COUNT(*) INTO v_locked
      FROM schedules s
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    SELECT COUNT(*) INTO v_active
      FROM bookings b
      JOIN schedules s ON s.id = b.schedule_id
     WHERE s.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       AND b.status IN ('pending', 'awaiting_payment', 'confirmed');

    IF v_active > 0 THEN
        ROLLBACK;
        SELECT 'has_bookings' AS result, v_active AS active_bookings;
        LEAVE proc;
    END IF;

    UPDATE tours
       SET approval_status = 'archived'
     WHERE id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_user_id, 'tour', p_tour_id, 'tour_archive', v_status, 'archived',
            'Đơn vị tổ chức ngừng hiển thị tour', NOW());

    COMMIT;
    SELECT 'ok' AS result, 0 AS active_bookings;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_tour_revision_start(p_user_id, p_tour_id)
--   Đơn vị tạo bản sửa của một tour đã duyệt: chép tour thành một dòng tours ẩn ('draft',
--   revision_of = p_tour_id) cùng ảnh, lịch trình, dịch vụ bao gồm / không bao gồm và chính sách
--   hủy mới nhất. Ảnh của bản sửa lúc đầu trỏ tới cùng file với tour gốc (file chỉ bị xóa khi
--   không còn dòng ảnh nào dùng, xem NTK_sp_tour_image_in_use). Lịch khởi hành, giá vé, gói tour,
--   phụ thu và vị trí bản đồ không chép: vẫn nằm ở tour gốc.
--   Ghi admin_logs 'tour_revision_start' (ở tour gốc và ở bản sửa).
--   1 dòng: result, revision_id.
--     result = 'ok'                 : revision_id = mã bản sửa mới.
--              'exists'             : tour đã có bản sửa đang mở; revision_id = mã bản sửa đó.
--              'forbidden'          : không phải tài khoản đơn vị đang hoạt động, đang hợp tác.
--              'not_found'          : không có tour này hoặc tour của đơn vị khác.
--              'invalid_transition' : tour không ở trạng thái 'approved', hoặc chính nó là bản sửa.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_tour_revision_start;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_tour_revision_start(
    IN p_user_id CHAR(36),
    IN p_tour_id CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status   VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_original CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_existing CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_new_id   CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT UUID();
    DECLARE v_owner    BOOLEAN     DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1
                     FROM users u
                     JOIN providers p ON p.user_id = u.id
                    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND u.role = 'provider' AND u.status = 'active'
                      AND p.approval_status = 'approved') THEN
        SELECT 'forbidden' AS result, NULL AS revision_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Khóa tour gốc: hai lần bấm cùng lúc không tạo ra hai bản sửa.
    SELECT t.approval_status, t.revision_of INTO v_status, v_original
      FROM tours t
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    SET v_owner = EXISTS (SELECT 1
                            FROM tours t
                            JOIN providers p ON p.id = t.provider_id
                           WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci)
                             AND p.user_id = (p_user_id COLLATE utf8mb4_unicode_ci));

    IF v_status IS NULL OR NOT v_owner THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS revision_id;
        LEAVE proc;
    END IF;

    SELECT r.id INTO v_existing
      FROM tours r
     WHERE r.revision_of = (p_tour_id COLLATE utf8mb4_unicode_ci);

    IF v_existing IS NOT NULL THEN
        ROLLBACK;
        SELECT 'exists' AS result, v_existing AS revision_id;
        LEAVE proc;
    END IF;

    IF v_status <> 'approved' OR v_original IS NOT NULL THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, NULL AS revision_id;
        LEAVE proc;
    END IF;

    INSERT INTO tours (id, provider_id, destination_id, category_id, title, description,
                       destination, duration_minutes, max_group_size, language_codes,
                       pickup_mode, meeting_point, latitude, longitude, included_summary,
                       transport, guide_info, dropoff_point, excluded_summary, document_terms,
                       meal_terms, voucher_terms, reschedule_terms, source_url, verified_at,
                       verification_status, approval_status, revision_of)
    SELECT v_new_id, t.provider_id, t.destination_id, t.category_id, t.title, t.description,
           t.destination, t.duration_minutes, t.max_group_size, t.language_codes,
           t.pickup_mode, t.meeting_point, NULL, NULL, t.included_summary,
           t.transport, t.guide_info, t.dropoff_point, t.excluded_summary, t.document_terms,
           t.meal_terms, t.voucher_terms, t.reschedule_terms, t.source_url, t.verified_at,
           t.verification_status, 'draft', t.id
      FROM tours t
     WHERE t.id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO tour_images (id, tour_id, url, alt_text, sort_order)
    SELECT UUID(), v_new_id, i.url, i.alt_text, i.sort_order
      FROM tour_images i
     WHERE i.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO tour_itinerary_items (id, tour_id, start_time, description, sort_order)
    SELECT UUID(), v_new_id, i.start_time, i.description, i.sort_order
      FROM tour_itinerary_items i
     WHERE i.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    INSERT INTO tour_inclusions (id, tour_id, item_text, is_included, sort_order)
    SELECT UUID(), v_new_id, i.item_text, i.is_included, i.sort_order
      FROM tour_inclusions i
     WHERE i.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci);

    -- Chỉ chép chính sách hủy mới nhất (thành phiên bản 1 của bản sửa).
    INSERT INTO cancellation_policies (id, tour_id, free_before_hours, refund_percent, terms, version)
    SELECT UUID(), v_new_id, cp.free_before_hours, cp.refund_percent, cp.terms, 1
      FROM cancellation_policies cp
     WHERE cp.tour_id = (p_tour_id COLLATE utf8mb4_unicode_ci)
     ORDER BY cp.version DESC
     LIMIT 1;

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_user_id, 'tour', p_tour_id, 'tour_revision_start', 'approved', 'approved',
            'Đơn vị tổ chức tạo bản sửa; tour đang hiển thị giữ nguyên', NOW()),
           (UUID(), p_user_id, 'tour', v_new_id, 'tour_revision_start', NULL, 'draft',
            'Bản sửa của tour đã duyệt', NOW());

    COMMIT;
    SELECT 'ok' AS result, v_new_id AS revision_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_revision_purge(p_revision_id)   (dùng nội bộ)
--   Xóa dòng bản sửa và mọi dữ liệu con của nó. Gọi bên trong transaction của procedure khác
--   (không tự START TRANSACTION / COMMIT, không trả dòng nào). Không làm gì khi p_revision_id
--   không phải bản sửa (tours.revision_of IS NULL): không bao giờ xóa tour thường.
--   Bản sửa không có đơn đặt tour (không bao giờ hiển thị cho khách) nên xóa được mọi bảng con.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_revision_purge;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_revision_purge(
    IN p_revision_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id CHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;

    SELECT t.id INTO v_id
      FROM tours t
     WHERE t.id = (p_revision_id COLLATE utf8mb4_unicode_ci)
       AND t.revision_of IS NOT NULL;

    IF v_id IS NOT NULL THEN
        DELETE tt FROM ticket_types tt
          JOIN schedules s ON s.id = tt.schedule_id
         WHERE s.tour_id = v_id;
        DELETE FROM schedules             WHERE tour_id = v_id;
        DELETE FROM tour_schedules        WHERE tour_id = v_id;
        DELETE FROM tour_images           WHERE tour_id = v_id;
        DELETE FROM itinerary_stops       WHERE tour_id = v_id;
        DELETE FROM tour_itinerary_items  WHERE tour_id = v_id;
        DELETE FROM tour_inclusions       WHERE tour_id = v_id;
        DELETE FROM tour_extras           WHERE tour_id = v_id;
        DELETE FROM cancellation_policies WHERE tour_id = v_id;
        DELETE FROM tour_packages         WHERE tour_id = v_id;
        DELETE FROM tour_posts            WHERE tour_id = v_id;
        DELETE FROM favorite_tours        WHERE tour_id = v_id;
        DELETE FROM comparison_tours      WHERE tour_id = v_id;
        DELETE FROM reviews               WHERE tour_id = v_id;
        DELETE FROM tours                 WHERE id = v_id;
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_revision_purge_of(p_tour_id)   (dùng nội bộ)
--   Xóa bản sửa đang mở (nếu có) của tour p_tour_id. NMT_sp_admin_tour_delete (file 21) gọi
--   trước khi xóa hẳn một tour: khóa ngoại tours.revision_of không cho xóa tour còn bản sửa.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_revision_purge_of;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_revision_purge_of(
    IN p_tour_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_revision CHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;

    SELECT r.id INTO v_revision
      FROM tours r
     WHERE r.revision_of = (p_tour_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    IF v_revision IS NOT NULL THEN
        CALL NTK_sp_tour_revision_purge(v_revision);
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_host_tour_revision_discard(p_user_id, p_revision_id)
--   Đơn vị hủy bản sửa của mình (đang 'draft' hoặc 'rejected'): xóa bản sửa, tour gốc không đổi.
--   Bản sửa đang 'pending' bị khóa chờ quản trị viên nên không hủy được.
--   Ghi admin_logs 'tour_revision_discard' ở tour gốc.
--   1 dòng: result, original_id.
--     result = 'ok'                 : original_id = mã tour gốc.
--              'forbidden'          : không phải tài khoản đơn vị đang hoạt động, đang hợp tác.
--              'not_found'          : không có bản sửa này hoặc của đơn vị khác.
--              'invalid_transition' : bản sửa đang chờ duyệt.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_host_tour_revision_discard;

DELIMITER $$
CREATE PROCEDURE NTK_sp_host_tour_revision_discard(
    IN p_user_id     CHAR(36),
    IN p_revision_id CHAR(36)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_status   VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_original CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_owner    BOOLEAN     DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1
                     FROM users u
                     JOIN providers p ON p.user_id = u.id
                    WHERE u.id = (p_user_id COLLATE utf8mb4_unicode_ci)
                      AND u.role = 'provider' AND u.status = 'active'
                      AND p.approval_status = 'approved') THEN
        SELECT 'forbidden' AS result, NULL AS original_id;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT t.approval_status, t.revision_of INTO v_status, v_original
      FROM tours t
     WHERE t.id = (p_revision_id COLLATE utf8mb4_unicode_ci)
       FOR UPDATE;

    SET v_owner = EXISTS (SELECT 1
                            FROM tours t
                            JOIN providers p ON p.id = t.provider_id
                           WHERE t.id = (p_revision_id COLLATE utf8mb4_unicode_ci)
                             AND p.user_id = (p_user_id COLLATE utf8mb4_unicode_ci));

    IF v_status IS NULL OR v_original IS NULL OR NOT v_owner THEN
        ROLLBACK;
        SELECT 'not_found' AS result, NULL AS original_id;
        LEAVE proc;
    END IF;

    IF v_status NOT IN ('draft', 'rejected') THEN
        ROLLBACK;
        SELECT 'invalid_transition' AS result, v_original AS original_id;
        LEAVE proc;
    END IF;

    CALL NTK_sp_tour_revision_purge(p_revision_id);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_user_id, 'tour', v_original, 'tour_revision_discard', NULL, NULL,
            'Đơn vị tổ chức hủy bản sửa; tour đang hiển thị giữ nguyên', NOW());

    COMMIT;
    SELECT 'ok' AS result, v_original AS original_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_revision_apply(p_actor_user_id, p_revision_id, p_note, OUT p_result)   (dùng nội bộ)
--   Áp dụng bản sửa vào tour gốc. LTP_sp_admin_tour_set_approval (file 03) gọi khi quản trị viên
--   phê duyệt một bản sửa đang 'pending', BÊN TRONG transaction của nó (procedure này không tự
--   START TRANSACTION / COMMIT, không trả dòng nào; người gọi đã kiểm tra quản trị viên và đã
--   khóa dòng bản sửa). Mọi thay đổi nằm trong một transaction: hoặc áp dụng hết, hoặc không gì.
--     1. Chép các ô đơn vị sửa được từ bản sửa vào tour gốc (đơn vị tổ chức, nguồn tham khảo,
--        trạng thái xác minh, tọa độ và trạng thái duyệt của tour gốc giữ nguyên).
--     2. Ảnh, lịch trình, dịch vụ bao gồm / không bao gồm: bỏ các dòng của tour gốc, chuyển các
--        dòng của bản sửa sang tour gốc.
--     3. Chính sách hủy mới nhất của bản sửa khác chính sách mới nhất của tour gốc: thêm thành
--        phiên bản mới của tour gốc.
--     4. Xóa dòng bản sửa. Ghi admin_logs 'tour_revision_approve' ở tour gốc.
--   p_result = 'ok'
--              'not_revision'          : p_revision_id không phải bản sửa.
--              'original_not_approved' : tour gốc không còn 'approved' (không áp dụng gì).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_revision_apply;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_revision_apply(
    IN  p_actor_user_id CHAR(36),
    IN  p_revision_id   CHAR(36),
    IN  p_note          VARCHAR(255) CHARACTER SET utf8mb4,
    OUT p_result        VARCHAR(30)
)
MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_original    CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_status      VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_new_policy  CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_old_policy  CHAR(36)    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
    DECLARE v_old_version INT         DEFAULT 0;
    DECLARE v_same_policy BOOLEAN     DEFAULT FALSE;

    SET p_result = 'not_revision';

    SELECT t.revision_of INTO v_original
      FROM tours t
     WHERE t.id = (p_revision_id COLLATE utf8mb4_unicode_ci);

    IF v_original IS NULL THEN
        LEAVE proc;
    END IF;

    -- Khóa tour gốc cho tới khi transaction của người gọi kết thúc.
    SELECT o.approval_status INTO v_status
      FROM tours o
     WHERE o.id = v_original
       FOR UPDATE;

    IF v_status IS NULL OR v_status <> 'approved' THEN
        SET p_result = 'original_not_approved';
        LEAVE proc;
    END IF;

    -- 1. Thông tin tour
    UPDATE tours o
      JOIN tours r ON r.id = (p_revision_id COLLATE utf8mb4_unicode_ci)
       SET o.destination_id   = r.destination_id,
           o.category_id      = r.category_id,
           o.title            = r.title,
           o.description      = r.description,
           o.destination      = r.destination,
           o.duration_minutes = r.duration_minutes,
           o.max_group_size   = r.max_group_size,
           o.language_codes   = r.language_codes,
           o.pickup_mode      = r.pickup_mode,
           o.meeting_point    = r.meeting_point,
           o.transport        = r.transport,
           o.guide_info       = r.guide_info,
           o.dropoff_point    = r.dropoff_point,
           o.document_terms   = r.document_terms,
           o.meal_terms       = r.meal_terms,
           o.voucher_terms    = r.voucher_terms,
           o.reschedule_terms = r.reschedule_terms
     WHERE o.id = v_original;

    -- 2. Ảnh, lịch trình, dịch vụ: không bảng nào khác trỏ tới các dòng này nên thay cả bộ.
    DELETE FROM tour_images WHERE tour_id = v_original;
    UPDATE tour_images SET tour_id = v_original WHERE tour_id = (p_revision_id COLLATE utf8mb4_unicode_ci);

    DELETE FROM tour_itinerary_items WHERE tour_id = v_original;
    UPDATE tour_itinerary_items SET tour_id = v_original WHERE tour_id = (p_revision_id COLLATE utf8mb4_unicode_ci);

    DELETE FROM tour_inclusions WHERE tour_id = v_original;
    UPDATE tour_inclusions SET tour_id = v_original WHERE tour_id = (p_revision_id COLLATE utf8mb4_unicode_ci);

    -- 3. Chính sách hủy: giữ mọi phiên bản cũ của tour gốc, chỉ thêm phiên bản mới khi nội dung khác.
    SELECT cp.id INTO v_new_policy
      FROM cancellation_policies cp
     WHERE cp.tour_id = (p_revision_id COLLATE utf8mb4_unicode_ci)
     ORDER BY cp.version DESC
     LIMIT 1;

    SELECT cp.id, cp.version INTO v_old_policy, v_old_version
      FROM cancellation_policies cp
     WHERE cp.tour_id = v_original
     ORDER BY cp.version DESC
     LIMIT 1;

    IF v_new_policy IS NOT NULL THEN
        SET v_same_policy = v_old_policy IS NOT NULL AND EXISTS (
            SELECT 1
              FROM cancellation_policies n
              JOIN cancellation_policies o ON o.id = v_old_policy
             WHERE n.id = v_new_policy
               AND n.free_before_hours <=> o.free_before_hours
               AND n.refund_percent = o.refund_percent
               AND BINARY n.terms = BINARY o.terms);

        IF NOT v_same_policy THEN
            INSERT INTO cancellation_policies (id, tour_id, free_before_hours, refund_percent, terms, version)
            SELECT UUID(), v_original, n.free_before_hours, n.refund_percent, n.terms, COALESCE(v_old_version, 0) + 1
              FROM cancellation_policies n
             WHERE n.id = v_new_policy;
        END IF;
    END IF;

    -- 4. Xóa bản sửa (và phần còn lại của nó)
    CALL NTK_sp_tour_revision_purge(p_revision_id);

    INSERT INTO admin_logs (id, actor_user_id, target_type, target_id, action, from_status, to_status, note, created_at)
    VALUES (UUID(), p_actor_user_id, 'tour', v_original, 'tour_revision_approve', 'approved', 'approved',
            COALESCE(NULLIF(TRIM(p_note), ''), 'Đã duyệt bản sửa: nội dung mới được áp dụng cho tour'), NOW());

    SET p_result = 'ok';
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_admin_tour_revision_compare(p_revision_id)
--   Dữ liệu để quản trị viên (và đơn vị) so bản sửa với tour đang hiển thị. 0 dòng khi
--   p_revision_id không phải bản sửa; ngược lại 2 dòng, side = 'current' (tour gốc) rồi
--   'proposed' (bản sửa). Cột: side, tour_id, title, description, destination_name,
--   category_name, duration_minutes, max_group_size, language_codes, pickup_mode,
--   meeting_point, transport, guide_info, dropoff_point, document_terms, meal_terms,
--   voucher_terms, reschedule_terms, approval_status.
--   Ảnh, lịch trình, dịch vụ và chính sách hủy của hai bên đọc bằng các procedure danh sách
--   của file 21 (NMT_sp_admin_image_list ...).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_admin_tour_revision_compare;

DELIMITER $$
CREATE PROCEDURE NTK_sp_admin_tour_revision_compare(
    IN p_revision_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        IF(t.id = r.id, 'proposed', 'current') AS side,
        t.id                AS tour_id,
        t.title,
        t.description,
        COALESCE(d.name, t.destination) AS destination_name,
        c.name              AS category_name,
        t.duration_minutes,
        t.max_group_size,
        t.language_codes,
        t.pickup_mode,
        t.meeting_point,
        t.transport,
        t.guide_info,
        t.dropoff_point,
        t.document_terms,
        t.meal_terms,
        t.voucher_terms,
        t.reschedule_terms,
        t.approval_status
    FROM tours r
    JOIN tours t ON t.id IN (r.id, r.revision_of)
    LEFT JOIN destinations d ON d.id = t.destination_id
    LEFT JOIN categories   c ON c.id = t.category_id
    WHERE r.id = (p_revision_id COLLATE utf8mb4_unicode_ci)
      AND r.revision_of IS NOT NULL
    ORDER BY (t.id = r.id) ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- NTK_sp_tour_image_in_use(p_url)
--   File ảnh p_url còn được dòng tour_images nào dùng không. Bản sửa lúc đầu trỏ tới cùng file
--   ảnh với tour gốc, nên ứng dụng chỉ xóa file trên đĩa khi không còn dòng nào dùng.
--   1 dòng: in_use (0 / 1).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS NTK_sp_tour_image_in_use;

DELIMITER $$
CREATE PROCEDURE NTK_sp_tour_image_in_use(
    IN p_url VARCHAR(255) CHARACTER SET utf8mb4
)
READS SQL DATA
BEGIN
    SELECT EXISTS (SELECT 1
                     FROM tour_images i
                    WHERE i.url = (p_url COLLATE utf8mb4_unicode_ci)) AS in_use;
END$$
DELIMITER ;
