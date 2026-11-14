<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: một khoản chi trả của đơn vị, chỉ xem (Nguyễn Tuấn Khôi).
 * Biến: $payout (NTK_sp_host_payout_detail), $items (NTK_sp_host_payout_item_list: các đơn trong khoản).
 */
use App\Models\PayoutModel;

$isPaid = $payout['status'] === 'paid';
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/host/payouts')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Doanh thu &amp; chi trả
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Thực nhận <?= e(format_vnd($payout['net_vnd'])) ?></h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($payout['status']) ?>"><?= e(PayoutModel::statusLabel((string) $payout['status'])) ?></span>
                    <?= e($payout['tour_title']) ?> · khởi hành <?= e(format_datetime((string) $payout['starts_at'])) ?>
                </p>
            </header>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="payout-items-title">
                        <h2 class="lt-panel__title" id="payout-items-title">Các đơn trong khoản chi trả</h2>
                        <div class="table-responsive">
                            <table class="table lt-table mb-0">
                                <thead>
                                    <tr>
                                        <th scope="col">Đơn</th>
                                        <th scope="col" class="text-right">Tiền thực thu</th>
                                        <th scope="col" class="text-right">Phí dịch vụ</th>
                                        <th scope="col" class="text-right">Thực nhận</th>
                                    </tr>
                                </thead>
                                <tbody>
<?php foreach ($items as $item): ?>
                                    <tr>
                                        <td>
                                            <a href="<?= e(url('/host/bookings/' . $item['booking_id'])) ?>"><strong><?= e($item['code']) ?></strong></a>
                                            <span class="lt-table__sub"><?= e($item['contact_name']) ?> · <?= e((int) $item['people']) ?> khách · <?= e(booking_status_label((string) $item['booking_status'])) ?><?= $item['booking_status'] === 'cancelled' ? ' (phí hủy giữ lại)' : '' ?></span>
                                        </td>
                                        <td class="text-right lt-nowrap"><?= e(format_vnd($item['kept_vnd'])) ?></td>
                                        <td class="text-right lt-nowrap"><?= e(format_vnd($item['commission_vnd'])) ?> <span class="lt-table__sub"><?= e(PayoutModel::percentText($item['commission_rate'])) ?></span></td>
                                        <td class="text-right lt-nowrap"><?= e(format_vnd($item['net_vnd'])) ?></td>
                                    </tr>
<?php endforeach; ?>
                                </tbody>
                                <tfoot>
                                    <tr>
                                        <th scope="row">Tổng</th>
                                        <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['gross_vnd'])) ?></strong></td>
                                        <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['commission_vnd'])) ?></strong></td>
                                        <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['net_vnd'])) ?></strong></td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                        <p class="lt-admin-hint">Tiền thực thu = số khách đã trả cho đơn, trừ tiền LocalTour đã hoàn cho khách. Đơn đã hủy còn tiền giữ lại (phí hủy) được tính như đơn thường.</p>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="payout-transfer-title">
                        <h2 class="lt-panel__title" id="payout-transfer-title">Chuyển khoản</h2>
                        <dl class="lt-fields">
                            <dt>Tiền thực thu</dt><dd><?= e(format_vnd($payout['gross_vnd'])) ?></dd>
                            <dt>Phí dịch vụ LocalTour</dt><dd><?= e(format_vnd($payout['commission_vnd'])) ?></dd>
                            <dt>Thực nhận</dt><dd><strong><?= e(format_vnd($payout['net_vnd'])) ?></strong></dd>
<?php if ($isPaid): ?>
                            <dt>Chuyển lúc</dt><dd><?= e(format_datetime((string) $payout['paid_at'])) ?></dd>
                            <dt>Mã giao dịch</dt><dd><strong><?= e($payout['transfer_reference']) ?></strong></dd>
                            <dt>Tài khoản nhận</dt><dd><?= e($payout['bank_name']) ?> · <?= e($payout['bank_account_no']) ?> · <?= e($payout['bank_account_name']) ?></dd>
<?php endif; ?>
                        </dl>
<?php if ($isPaid): ?>
                        <p class="lt-admin-hint">LocalTour đã chuyển khoản. Chưa thấy tiền về, liên hệ quản trị viên LocalTour kèm mã giao dịch trên.</p>
<?php else: ?>
                        <p class="lt-admin-hint">LocalTour sẽ chuyển khoản vào <a href="<?= e(url('/host/bank')) ?>">tài khoản nhận tiền</a> của đơn vị. Khi đã chuyển, mã giao dịch hiện ở đây.</p>
<?php endif; ?>
                    </section>
                </div>
            </div>
        </main>
    </div>
</div>
