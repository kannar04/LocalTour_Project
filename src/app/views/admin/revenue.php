<?php declare(strict_types=1); ?>
<?php
/*
 * Các khoản thanh toán của một kỳ doanh thu (FR-23 – đối chiếu giao dịch nguồn, Nguyễn Minh Thức).
 * Biến: $payments (NMT_sp_admin_revenue_payment_list, thanh toán trước lên trước), $from, $to ('Y-m-d' hoặc null).
 * Cùng điều kiện với bảng doanh thu ở trang "Tổng quan": khoản "Thành công" theo ngày thanh toán, trừ tiền đã hoàn.
 */
$totals = ['amount_vnd' => 0, 'refund_vnd' => 0, 'net_vnd' => 0];
foreach ($payments as $row) {
    foreach ($totals as $key => $value) {
        $totals[$key] = $value + (int) $row[$key];
    }
}
$rangeText = match (true) {
    $from !== null && $to !== null && $from === $to => 'Ngày ' . format_date($from),
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
            <a class="lt-admin__back" href="<?= e(url('/admin')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Tổng quan
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Khoản thanh toán theo kỳ</h1>
                <p class="lt-admin__subtitle"><?= e($rangeText) ?> · khoản thanh toán thành công theo ngày thanh toán, dùng để đối chiếu doanh thu với VNPay và sao kê</p>
            </header>

            <section class="lt-panel" aria-labelledby="revenue-list-title">
                <h2 class="lt-panel__title" id="revenue-list-title">Danh sách khoản thanh toán</h2>
<?php if ($payments === []): ?>
                <p class="lt-empty">Không có khoản thanh toán thành công nào trong khoảng thời gian này.</p>
<?php else: ?>
                <p class="lt-panel__lead"><?= count($payments) ?> khoản · tổng khớp với dòng doanh thu của kỳ ở trang Tổng quan</p>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Thanh toán lúc</th>
                                <th scope="col">Đơn</th>
                                <th scope="col">Phương thức</th>
                                <th scope="col">Mã thanh toán</th>
                                <th scope="col" class="text-right">Số tiền</th>
                                <th scope="col" class="text-right">Đã hoàn</th>
                                <th scope="col" class="text-right">Thuần</th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($payments as $row): ?>
                            <tr>
                                <td class="lt-nowrap"><?= e(format_datetime($row['paid_at'])) ?></td>
                                <td>
                                    <a href="<?= e(url('/admin/bookings/' . $row['booking_id']) . '#payments') ?>"><strong><?= e($row['code']) ?></strong></a>
                                    <span class="lt-table__sub"><?= e($row['tour_title']) ?></span>
                                </td>
                                <td class="lt-nowrap"><?= e(payment_method_label($row['method'])) ?></td>
                                <td class="lt-nowrap">
                                    <code><?= e(or_missing($row['reference'])) ?></code>
<?php if ($row['method'] === 'vnpay' && $row['provider_txn_id'] !== null && $row['provider_txn_id'] !== $row['reference']): ?>
                                    <span class="lt-table__sub">Mã GD VNPay <?= e($row['provider_txn_id']) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right lt-nowrap"><?= e(format_vnd($row['amount_vnd'])) ?></td>
                                <td class="text-right lt-nowrap"><?= (int) $row['refund_vnd'] > 0 ? '−' . e(format_vnd($row['refund_vnd'])) : '0đ' ?></td>
                                <td class="text-right lt-nowrap"><strong><?= e(format_vnd($row['net_vnd'])) ?></strong></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                        <tfoot>
                            <tr>
                                <th scope="row" colspan="4">Tổng</th>
                                <td class="text-right lt-nowrap"><?= e(format_vnd($totals['amount_vnd'])) ?></td>
                                <td class="text-right lt-nowrap"><?= $totals['refund_vnd'] > 0 ? '−' . e(format_vnd($totals['refund_vnd'])) : '0đ' ?></td>
                                <td class="text-right lt-nowrap"><strong><?= e(format_vnd($totals['net_vnd'])) ?></strong></td>
                            </tr>
                        </tfoot>
                    </table>
                </div>
<?php endif; ?>
            </section>
        </main>
    </div>
</div>
