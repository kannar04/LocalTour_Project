<?php declare(strict_types=1); ?>
<?php
/*
 * Trang "Tổng quan" của quản trị viên (FR-19 → FR-23, Nguyễn Minh Thức).
 * Biến: $summary (1 dòng NMT_sp_admin_summary), $byStatus (FR-21), $byTime (FR-22), $revenue (FR-23),
 *       $period ('day' | 'month' | 'year'), $from, $to ('Y-m-d' hoặc null = không giới hạn).
 * Thanh ngang là CSS thuần (độ dài theo giá trị lớn nhất của bảng), không dùng thư viện biểu đồ.
 */
use App\Controllers\AdminDashboardController;

$num = static fn (mixed $value): string => number_format((int) $value, 0, ',', '.');
$barWidth = static fn (int $value, int $max): string => $max > 0 ? round($value * 100 / $max, 1) . '%' : '0%';

$maxStatus = max(array_map(static fn (array $row): int => (int) $row['booking_count'], $byStatus) ?: [0]);
$maxTime = max(array_map(static fn (array $row): int => (int) $row['booking_count'], $byTime) ?: [0]);
$maxRevenue = max(array_map(static fn (array $row): int => (int) $row['net_vnd'], $revenue) ?: [0]);
$timeTotal = array_sum(array_map(static fn (array $row): int => (int) $row['booking_count'], $byTime));
$revenueTotal = ['paid_count' => 0, 'gross_vnd' => 0, 'refund_vnd' => 0, 'net_vnd' => 0];
foreach ($revenue as $row) {
    foreach ($revenueTotal as $key => $value) {
        $revenueTotal[$key] = $value + (int) $row[$key];
    }
}
$rangeText = match (true) {
    $from !== null && $to !== null => 'Từ ' . format_date($from) . ' đến ' . format_date($to),
    $from !== null => 'Từ ' . format_date($from),
    $to !== null => 'Đến ' . format_date($to),
    default => 'Toàn bộ thời gian',
};
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Tổng quan</h1>
                <p class="lt-admin__subtitle">Số liệu tài khoản, tour, yêu cầu đặt tour và doanh thu của LocalTour</p>
            </header>

            <section class="lt-tiles" aria-label="Số liệu chính">
                <article class="lt-tile">
                    <h2 class="lt-tile__label">Tài khoản khách hàng</h2>
                    <p class="lt-tile__value"><?= e($num($summary['customer_total'] ?? 0)) ?></p>
                    <p class="lt-tile__meta"><?= e($num($summary['customer_active'] ?? 0)) ?> đang hoạt động · <?= e($num($summary['customer_locked'] ?? 0)) ?> bị khóa</p>
                </article>
                <article class="lt-tile">
                    <h2 class="lt-tile__label">Tour</h2>
                    <p class="lt-tile__value"><?= e($num($summary['tour_total'] ?? 0)) ?></p>
                    <p class="lt-tile__meta">
                        <?= e($num($summary['tour_pending'] ?? 0)) ?> chờ duyệt · <?= e($num($summary['tour_approved'] ?? 0)) ?> đã duyệt · <?= e($num($summary['tour_rejected'] ?? 0)) ?> bị từ chối<?= (int) ($summary['tour_draft'] ?? 0) > 0 ? ' · ' . e($num($summary['tour_draft'])) . ' nháp' : '' ?>
                    </p>
<?php if ((int) ($summary['tour_pending'] ?? 0) > 0): ?>
                    <a class="lt-tile__link" href="<?= e(url('/admin/tours')) ?>">Duyệt tour</a>
<?php endif; ?>
                </article>
                <article class="lt-tile lt-tile--accent">
                    <h2 class="lt-tile__label">Yêu cầu chờ xác nhận</h2>
                    <p class="lt-tile__value"><?= e($num($summary['booking_pending'] ?? 0)) ?></p>
                    <p class="lt-tile__meta">Trên tổng <?= e($num($summary['booking_total'] ?? 0)) ?> yêu cầu đặt tour</p>
<?php if ((int) ($summary['booking_pending'] ?? 0) > 0): ?>
                    <a class="lt-tile__link" href="<?= e(url('/admin/bookings?status=pending')) ?>">Xử lý yêu cầu</a>
<?php endif; ?>
                </article>
            </section>

            <section class="lt-panel" aria-labelledby="stats-status-title">
                <h2 class="lt-panel__title" id="stats-status-title">Yêu cầu đặt tour theo trạng thái</h2>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr><th scope="col">Trạng thái</th><th scope="col" class="text-right">Số yêu cầu</th><th scope="col" class="lt-table__bar-col"><span class="sr-only">Biểu đồ</span></th></tr>
                        </thead>
                        <tbody>
<?php foreach ($byStatus as $row): ?>
                            <tr>
                                <td><a href="<?= e(url('/admin/bookings?status=' . rawurlencode((string) $row['status']))) ?>"><span class="lt-badge lt-badge--<?= e($row['status']) ?>"><?= e(booking_status_label($row['status'])) ?></span></a></td>
                                <td class="text-right"><?= e($num($row['booking_count'])) ?></td>
                                <td class="lt-table__bar-col"><span class="lt-bar" aria-hidden="true"><span class="lt-bar__fill" style="width: <?= e($barWidth((int) $row['booking_count'], $maxStatus)) ?>"></span></span></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </section>

            <form class="lt-panel lt-stats-filter" action="<?= e(url('/admin')) ?>" method="get" aria-label="Khoảng thời gian thống kê">
                <div class="lt-stats-filter__field">
                    <label class="lt-admin-label" for="stats-period">Thống kê</label>
                    <select class="lt-admin-input" id="stats-period" name="period">
<?php foreach (AdminDashboardController::PERIODS as $value => $label): ?>
                        <option value="<?= e($value) ?>"<?= $value === $period ? ' selected' : '' ?>><?= e($label) ?></option>
<?php endforeach; ?>
                    </select>
                </div>
                <div class="lt-stats-filter__field">
                    <label class="lt-admin-label" for="stats-from">Từ ngày</label>
                    <input class="lt-admin-input" type="date" id="stats-from" name="from" value="<?= e($from ?? '') ?>">
                </div>
                <div class="lt-stats-filter__field">
                    <label class="lt-admin-label" for="stats-to">Đến ngày</label>
                    <input class="lt-admin-input" type="date" id="stats-to" name="to" value="<?= e($to ?? '') ?>">
                </div>
                <button class="lt-btn lt-btn--primary" type="submit">Xem thống kê</button>
                <p class="lt-stats-filter__hint">Để trống ngày: theo ngày = 30 ngày gần nhất, theo tháng = 12 tháng gần nhất, theo năm = toàn bộ.</p>
            </form>

            <section class="lt-panel" aria-labelledby="stats-time-title">
                <h2 class="lt-panel__title" id="stats-time-title">Số yêu cầu đặt tour theo ngày tạo</h2>
                <p class="lt-panel__lead"><?= e($rangeText) ?> · Tổng <?= e($num($timeTotal)) ?> yêu cầu</p>
<?php if ($byTime === []): ?>
                <p class="lt-empty">Chưa có dữ liệu trong khoảng thời gian này.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr><th scope="col">Kỳ</th><th scope="col" class="text-right">Số yêu cầu</th><th scope="col" class="lt-table__bar-col"><span class="sr-only">Biểu đồ</span></th></tr>
                        </thead>
                        <tbody>
<?php foreach ($byTime as $row): ?>
                            <tr>
                                <td class="lt-nowrap"><?= e($row['label']) ?></td>
                                <td class="text-right"><?= e($num($row['booking_count'])) ?></td>
                                <td class="lt-table__bar-col"><span class="lt-bar" aria-hidden="true"><span class="lt-bar__fill" style="width: <?= e($barWidth((int) $row['booking_count'], $maxTime)) ?>"></span></span></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
            </section>

            <section class="lt-panel" aria-labelledby="stats-revenue-title">
                <h2 class="lt-panel__title" id="stats-revenue-title">Doanh thu theo ngày thanh toán</h2>
                <p class="lt-panel__lead"><?= e($rangeText) ?> · Doanh thu thuần = tiền đã thanh toán thành công − tiền đã hoàn</p>
<?php if ($revenue === []): ?>
                <p class="lt-empty">Chưa có dữ liệu trong khoảng thời gian này.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Kỳ</th>
                                <th scope="col" class="text-right">Lượt thanh toán</th>
                                <th scope="col" class="text-right">Doanh thu gộp</th>
                                <th scope="col" class="text-right">Hoàn tiền</th>
                                <th scope="col" class="text-right">Doanh thu thuần</th>
                                <th scope="col" class="lt-table__bar-col"><span class="sr-only">Biểu đồ</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($revenue as $row): ?>
                            <tr>
                                <td class="lt-nowrap"><?= e($row['label']) ?></td>
                                <td class="text-right"><?= e($num($row['paid_count'])) ?></td>
                                <td class="text-right"><?= e(format_vnd($row['gross_vnd'])) ?></td>
                                <td class="text-right"><?= (int) $row['refund_vnd'] > 0 ? '−' . e(format_vnd($row['refund_vnd'])) : '0đ' ?></td>
                                <td class="text-right"><strong><?= e(format_vnd($row['net_vnd'])) ?></strong></td>
                                <td class="lt-table__bar-col"><span class="lt-bar" aria-hidden="true"><span class="lt-bar__fill" style="width: <?= e($barWidth((int) $row['net_vnd'], $maxRevenue)) ?>"></span></span></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                        <tfoot>
                            <tr>
                                <th scope="row">Tổng</th>
                                <td class="text-right"><?= e($num($revenueTotal['paid_count'])) ?></td>
                                <td class="text-right"><?= e(format_vnd($revenueTotal['gross_vnd'])) ?></td>
                                <td class="text-right"><?= $revenueTotal['refund_vnd'] > 0 ? '−' . e(format_vnd($revenueTotal['refund_vnd'])) : '0đ' ?></td>
                                <td class="text-right"><strong><?= e(format_vnd($revenueTotal['net_vnd'])) ?></strong></td>
                                <td class="lt-table__bar-col"></td>
                            </tr>
                        </tfoot>
                    </table>
                </div>
<?php endif; ?>
            </section>
        </main>
    </div>
</div>