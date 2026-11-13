<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: "Doanh thu & chi trả" (Nguyễn Tuấn Khôi). Chỉ xem: khoản chi trả do hệ thống lập sau khi lịch
 * khởi hành kết thúc, LocalTour chuyển khoản rồi ghi "Đã chi trả".
 * Biến: $host (đơn vị đang đăng nhập), $summary (NTK_sp_host_payout_summary: commission_percent, has_bank, bank_verified,
 *       gross_vnd, commission_vnd, net_pending_vnd, net_paid_vnd), $payouts (NTK_sp_host_payout_list, lịch kết thúc gần đây trước).
 */
use App\Models\PayoutModel;

$hasBank = (int) ($summary['has_bank'] ?? 0) === 1;
// Tài khoản mới khai hoặc vừa đổi: LocalTour phải xác minh rồi mới chuyển khoản chi trả.
$bankVerified = (int) ($summary['bank_verified'] ?? 0) === 1;
$percentText = PayoutModel::percentText($summary['commission_percent'] ?? 0);
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Doanh thu &amp; chi trả</h1>
                <p class="lt-admin__subtitle"><?= e($host['business_name']) ?> · Sau khi lịch khởi hành kết thúc, LocalTour chuyển phần thực nhận vào tài khoản của đơn vị</p>
            </header>

<?php if (!$hasBank): ?>
            <div class="lt-alert lt-alert--warning" role="note"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Đơn vị chưa khai tài khoản nhận tiền nên LocalTour chưa chuyển khoản được. <a href="<?= e(url('/host/bank')) ?>">Khai tài khoản nhận tiền</a>.</span></div>
<?php elseif (!$bankVerified): ?>
            <div class="lt-alert lt-alert--warning" role="note"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Tài khoản nhận tiền đang chờ LocalTour xác minh: khoản chi trả chỉ được chuyển sau khi LocalTour xác minh tài khoản. <a href="<?= e(url('/host/bank')) ?>">Xem tài khoản nhận tiền</a>.</span></div>
<?php endif; ?>

            <section class="lt-tiles" aria-label="Tổng doanh thu và chi trả">
                <article class="lt-tile">
                    <h2 class="lt-tile__label">Tiền thực thu</h2>
                    <p class="lt-tile__value"><?= e(format_vnd($summary['gross_vnd'] ?? 0)) ?></p>
                    <p class="lt-tile__meta">Khách đã trả cho các lịch đã kết thúc, đã trừ tiền hoàn · phí dịch vụ LocalTour <?= e(format_vnd($summary['commission_vnd'] ?? 0)) ?></p>
                </article>
                <article class="lt-tile lt-tile--accent">
                    <h2 class="lt-tile__label">Thực nhận chờ chi trả</h2>
                    <p class="lt-tile__value"><?= e(format_vnd($summary['net_pending_vnd'] ?? 0)) ?></p>
                    <p class="lt-tile__meta">LocalTour sẽ chuyển khoản cho đơn vị</p>
                </article>
                <article class="lt-tile">
                    <h2 class="lt-tile__label">Thực nhận đã chi trả</h2>
                    <p class="lt-tile__value"><?= e(format_vnd($summary['net_paid_vnd'] ?? 0)) ?></p>
                    <p class="lt-tile__meta">Đã chuyển vào tài khoản của đơn vị</p>
                </article>
            </section>

            <div class="lt-alert lt-alert--warning" role="note"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Phí dịch vụ LocalTour hiện là <strong><?= e($percentText) ?></strong> trên tiền thực thu của mỗi đơn, áp dụng cho đơn khách đặt từ lúc này; đơn đã đặt giữ mức phí lúc đặt. Thực nhận = tiền thực thu − phí dịch vụ. Khách trả đúng giá đơn vị niêm yết.</span></div>

            <section class="lt-panel" aria-labelledby="host-payouts-title">
                <h2 class="lt-panel__title" id="host-payouts-title">Các khoản chi trả</h2>
<?php if ($payouts === []): ?>
                <p class="lt-empty">Chưa có khoản chi trả nào. Mỗi lịch khởi hành có khách đã thanh toán sẽ có một khoản chi trả sau khi lịch kết thúc và các đơn của lịch đã xử lý xong.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Lịch khởi hành</th>
                                <th scope="col" class="text-right">Tiền thực thu</th>
                                <th scope="col" class="text-right">Phí dịch vụ</th>
                                <th scope="col" class="text-right">Thực nhận</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($payouts as $payout): ?>
                            <tr>
                                <td>
                                    <strong><?= e($payout['tour_title']) ?></strong>
                                    <span class="lt-table__sub"><?= e(format_datetime((string) $payout['starts_at'])) ?> · <?= e((int) $payout['booking_count']) ?> đơn</span>
                                </td>
                                <td class="text-right lt-nowrap"><?= e(format_vnd($payout['gross_vnd'])) ?></td>
                                <td class="text-right lt-nowrap"><?= e(format_vnd($payout['commission_vnd'])) ?></td>
                                <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['net_vnd'])) ?></strong></td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($payout['status']) ?>"><?= e(PayoutModel::statusLabel((string) $payout['status'])) ?></span>
<?php if ($payout['status'] === 'paid'): ?>
                                    <span class="lt-table__sub"><?= e(format_datetime((string) $payout['paid_at'])) ?> · mã GD <?= e($payout['transfer_reference']) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right">
                                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/host/payouts/' . $payout['payout_id'])) ?>">Xem<span class="sr-only"> khoản của lịch <?= e(format_datetime((string) $payout['starts_at'])) ?>, <?= e($payout['tour_title']) ?></span></a>
                                </td>
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
