<?php declare(strict_types=1); ?>
<?php
/*
 * Danh sách yêu cầu đặt tour cho quản trị viên (FR-25, Nguyễn Tuấn Khôi).
 * Biến: $filter ('' = tất cả), $keyword (mã, tên, email hoặc số điện thoại), $bookings (NTK_sp_admin_booking_list).
 */
use App\Controllers\AdminBookingController;

$filterHref = static function (string $value) use ($keyword): string {
    $query = array_filter(['status' => $value, 'q' => $keyword], static fn (string $part): bool => $part !== '');

    return url('/admin/bookings') . ($query !== [] ? '?' . http_build_query($query) : '');
};
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Yêu cầu đặt tour</h1>
                <p class="lt-admin__subtitle">Xác nhận, từ chối, hủy hoặc cập nhật trạng thái yêu cầu của khách</p>
            </header>

            <form class="lt-admin-search" action="<?= e(url('/admin/bookings')) ?>" method="get" role="search">
<?php if ($filter !== ''): ?>
                <input type="hidden" name="status" value="<?= e($filter) ?>">
<?php endif; ?>
                <label class="sr-only" for="booking-search">Tìm theo mã đặt chỗ, tên, email hoặc số điện thoại</label>
                <input class="lt-admin-input" type="search" id="booking-search" name="q" value="<?= e($keyword) ?>"
                       maxlength="<?= AdminBookingController::KEYWORD_MAX_LENGTH ?>" placeholder="Mã đặt chỗ, tên, email hoặc số điện thoại">
                <button class="lt-btn lt-btn--primary" type="submit">Tìm</button>
<?php if ($keyword !== ''): ?>
                <a class="lt-btn lt-btn--soft" href="<?= e(url('/admin/bookings' . ($filter !== '' ? '?status=' . $filter : ''))) ?>">Xóa tìm kiếm</a>
<?php endif; ?>
            </form>

            <nav class="lt-tabs" aria-label="Lọc theo trạng thái">
<?php foreach (AdminBookingController::FILTERS as $value): ?>
                <a class="lt-tabs__link<?= $value === $filter ? ' is-active' : '' ?>" href="<?= e($filterHref($value)) ?>"<?= $value === $filter ? ' aria-current="page"' : '' ?>><?= e($value === '' ? 'Tất cả' : booking_status_label($value)) ?></a>
<?php endforeach; ?>
            </nav>

            <section class="lt-panel" aria-label="Danh sách yêu cầu đặt tour">
<?php if ($bookings === []): ?>
                <p class="lt-empty"><?= $keyword !== '' ? 'Không tìm thấy yêu cầu nào khớp với “' . e($keyword) . '”.' : 'Không có yêu cầu nào ở trạng thái này.' ?></p>
<?php else: ?>
                <p class="lt-panel__lead"><?= count($bookings) ?> yêu cầu, mới nhất trước<?= count($bookings) >= 200 ? ' (hiển thị 200 yêu cầu đầu tiên)' : '' ?></p>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Mã</th>
                                <th scope="col">Khách liên hệ</th>
                                <th scope="col" class="lt-table__grow">Tour</th>
                                <th scope="col" class="text-right">Tổng tiền</th>
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
                                    <?= e($booking['tour_title']) ?>
                                    <span class="lt-table__sub">Khởi hành <?= e(format_datetime($booking['starts_at'])) ?></span>
                                </td>
                                <td class="text-right lt-nowrap">
                                    <?= e(format_vnd($booking['total_vnd'])) ?>
                                    <span class="lt-table__sub"><?= e($booking['people']) ?> khách</span>
                                </td>
                                <td><span class="lt-badge lt-badge--<?= e($booking['payment_status'] ?? 'none') ?>"><?= e(payment_status_label($booking['payment_status'])) ?></span></td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($booking['status']) ?>"><?= e(booking_status_label($booking['status'])) ?></span>
<?php if ($booking['hold_expires_at'] !== null): ?>
                                    <span class="lt-table__sub">Hạn thanh toán <?= e(format_datetime($booking['hold_expires_at'])) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right"><a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/admin/bookings/' . $booking['booking_id'])) ?>">Xem</a></td>
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
