<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: "Đơn đặt tour" – đơn đặt trên các tour của đơn vị, chỉ xem (Nguyễn Tuấn Khôi).
 * Biến: $host (đơn vị đang đăng nhập), $filter (trạng thái đơn, '' = tất cả), $tourId (lọc theo tour, '' = mọi tour),
 *       $tours (NTK_sp_host_tour_list, cho ô chọn tour), $bookings (NTK_sp_host_booking_list).
 * Không có nút xử lý: xác nhận, từ chối, hủy đơn và đổi ngày / hủy tour do quản trị viên LocalTour làm.
 */
use App\Controllers\AdminBookingController;

$filterHref = static function (string $value) use ($tourId): string {
    $query = array_filter(['status' => $value, 'tour' => $tourId], static fn (string $part): bool => $part !== '');

    return url('/host/bookings') . ($query !== [] ? '?' . http_build_query($query) : '');
};
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Đơn đặt tour</h1>
                <p class="lt-admin__subtitle"><?= e($host['business_name']) ?> · Đơn khách đặt trên tour của đơn vị. Chỉ xem: quản trị viên LocalTour xác nhận, hủy đơn và xử lý đổi ngày / hủy tour</p>
            </header>

<?php if ($tours !== []): ?>
            <form class="lt-admin-search" action="<?= e(url('/host/bookings')) ?>" method="get">
<?php if ($filter !== ''): ?>
                <input type="hidden" name="status" value="<?= e($filter) ?>">
<?php endif; ?>
                <label class="sr-only" for="booking-tour">Lọc theo tour</label>
                <select class="lt-admin-input" id="booking-tour" name="tour">
                    <option value="">Tất cả tour của đơn vị</option>
<?php foreach ($tours as $tour): ?>
                    <option value="<?= e($tour['tour_id']) ?>"<?= $tour['tour_id'] === $tourId ? ' selected' : '' ?>><?= e($tour['title']) ?></option>
<?php endforeach; ?>
                </select>
                <button class="lt-btn lt-btn--primary" type="submit">Lọc</button>
            </form>
<?php endif; ?>

            <nav class="lt-tabs" aria-label="Lọc theo trạng thái">
<?php foreach (AdminBookingController::FILTERS as $value): ?>
                <a class="lt-tabs__link<?= $value === $filter ? ' is-active' : '' ?>" href="<?= e($filterHref($value)) ?>"<?= $value === $filter ? ' aria-current="page"' : '' ?>><?= e($value === '' ? 'Tất cả' : booking_status_label($value)) ?></a>
<?php endforeach; ?>
            </nav>

            <section class="lt-panel" aria-label="Danh sách đơn đặt tour">
<?php if ($bookings === []): ?>
                <p class="lt-empty"><?= $filter === '' && $tourId === '' ? 'Chưa có khách nào đặt tour của đơn vị.' : 'Không có đơn nào khớp với lựa chọn này.' ?></p>
<?php else: ?>
                <p class="lt-panel__lead"><?= count($bookings) ?> đơn, mới nhất trước<?= count($bookings) >= 200 ? ' (hiển thị 200 đơn đầu tiên)' : '' ?></p>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Mã</th>
                                <th scope="col">Khách liên hệ</th>
                                <th scope="col" class="lt-table__grow">Tour</th>
                                <th scope="col" class="text-right">Số khách</th>
                                <th scope="col">Thanh toán</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($bookings as $booking): ?>
                            <tr>
                                <td class="lt-nowrap">
                                    <strong><?= e($booking['code']) ?></strong>
                                    <span class="lt-table__sub"><?= e(format_datetime($booking['created_at'])) ?></span>
                                </td>
                                <td>
                                    <?= e($booking['contact_name']) ?>
                                    <span class="lt-table__sub"><?= e($booking['contact_phone']) ?></span>
                                </td>
                                <td>
                                    <?= e($booking['tour_title']) ?><?= $booking['package_name'] !== null ? ' · ' . e($booking['package_name']) : '' ?>
                                    <span class="lt-table__sub">Khởi hành <?= e(format_datetime($booking['starts_at'])) ?></span>
                                </td>
                                <td class="text-right lt-nowrap">
                                    <?= e($booking['people']) ?> khách
                                    <span class="lt-table__sub"><?= e(format_vnd($booking['total_vnd'])) ?></span>
                                </td>
                                <td><span class="lt-badge lt-badge--<?= e($booking['payment_status'] ?? 'none') ?>"><?= e(payment_status_label($booking['payment_status'])) ?></span></td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($booking['status']) ?>"><?= e(booking_status_label($booking['status'])) ?></span>
<?php if ((int) $booking['pending_change_count'] > 0): ?>
                                    <span class="lt-table__sub">Khách xin đổi ngày / hủy, chờ LocalTour xử lý</span>
<?php endif; ?>
                                </td>
                                <td class="text-right"><a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/host/bookings/' . $booking['booking_id'])) ?>">Xem<span class="sr-only"> đơn <?= e($booking['code']) ?></span></a></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
            </section>
        </main>
    </div>
</div>
