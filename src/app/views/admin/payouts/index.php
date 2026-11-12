<?php declare(strict_types=1); ?>
<?php
/*
 * Chi trả đơn vị tổ chức (Nguyễn Tuấn Khôi): danh sách khoản chi trả theo trạng thái, tổng tiền thực thu / phí dịch vụ
 * LocalTour / thực nhận, lịch đã kết thúc chưa lập được khoản chi trả và khoản hoàn tiền còn phải chuyển cho khách.
 * Biến: $filter ('pending' | 'paid' | 'all'), $summary (NTK_sp_admin_payout_summary), $payouts (NTK_sp_admin_payout_list),
 *       $waiting (NTK_sp_admin_payout_waiting_list), $refunds (NTK_sp_admin_refund_open_list),
 *       $refundErrors (lỗi theo mã khoản hoàn; 'form' = lỗi chung), $oldReference (mã giao dịch hoàn tiền đang nhập),
 *       $success ('' = không có), $payoutsFrom (mốc bắt đầu lập khoản chi trả 'Y-m-d H:i:s'; null = không có mốc).
 */
use App\Models\PayoutModel;

$emptyTexts = [
    'pending' => 'Không có khoản nào đang chờ chi trả.',
    'paid' => 'Chưa có khoản nào được chi trả.',
    'all' => 'Chưa có khoản chi trả nào. Khoản chi trả được lập tự động sau khi lịch khởi hành kết thúc.',
];
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Chi trả đơn vị tổ chức</h1>
                <p class="lt-admin__subtitle">Sau khi lịch khởi hành kết thúc, hệ thống tự lập một khoản chi trả cho mỗi lịch. Chuyển khoản cho đơn vị ngoài hệ thống rồi bấm “Ghi nhận đã chi trả” kèm mã giao dịch.<?php if ($payoutsFrom !== null): ?> Chi trả được lập cho các lịch kết thúc từ <?= e(format_datetime($payoutsFrom)) ?>.<?php endif; ?></p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($refundErrors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($refundErrors['form']) ?></span></div>
<?php elseif ($refundErrors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Chưa ghi nhận được hoàn tiền, vui lòng xem lỗi ở mục “Hoàn tiền cho khách”.</span></div>
<?php endif; ?>

            <section class="lt-tiles" aria-label="Tổng các khoản chi trả">
                <article class="lt-tile">
                    <h2 class="lt-tile__label">Tiền thực thu</h2>
                    <p class="lt-tile__value"><?= e(format_vnd($summary['gross_vnd'] ?? 0)) ?></p>
                    <p class="lt-tile__meta"><?= e((int) ($summary['payout_count'] ?? 0)) ?> khoản chi trả · đã trừ tiền hoàn cho khách</p>
                </article>
                <article class="lt-tile">
                    <h2 class="lt-tile__label">Phí dịch vụ LocalTour</h2>
                    <p class="lt-tile__value"><?= e(format_vnd($summary['commission_vnd'] ?? 0)) ?></p>
                    <p class="lt-tile__meta">Phần LocalTour giữ lại</p>
                </article>
                <article class="lt-tile lt-tile--accent">
                    <h2 class="lt-tile__label">Thực nhận chờ chi trả</h2>
                    <p class="lt-tile__value"><?= e(format_vnd($summary['net_pending_vnd'] ?? 0)) ?></p>
                    <p class="lt-tile__meta"><?= e((int) ($summary['pending_count'] ?? 0)) ?> khoản · đã chi trả <?= e(format_vnd($summary['net_paid_vnd'] ?? 0)) ?> (<?= e((int) ($summary['paid_count'] ?? 0)) ?> khoản)</p>
                </article>
            </section>

            <nav class="lt-tabs" aria-label="Lọc theo trạng thái chi trả">
<?php foreach (PayoutModel::FILTERS as $value => $label): ?>
                <a class="lt-tabs__link<?= $value === $filter ? ' is-active' : '' ?>" href="<?= e(url('/admin/payouts' . ($value === 'pending' ? '' : '?status=' . $value))) ?>"<?= $value === $filter ? ' aria-current="page"' : '' ?>><?= e($label) ?></a>
<?php endforeach; ?>
            </nav>

            <section class="lt-panel" aria-label="Danh sách khoản chi trả">
<?php if ($payouts === []): ?>
                <p class="lt-empty"><?= e($emptyTexts[$filter]) ?></p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Lịch khởi hành</th>
                                <th scope="col">Đơn vị tổ chức</th>
                                <th scope="col" class="text-right">Tiền thực thu</th>
                                <th scope="col" class="text-right">Phí dịch vụ</th>
                                <th scope="col" class="text-right">Thực nhận</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($payouts as $payout): ?>
<?php $isPending = $payout['status'] === 'pending'; ?>
                            <tr>
                                <td>
                                    <strong><?= e($payout['tour_title']) ?></strong>
                                    <span class="lt-table__sub"><?= e(format_datetime((string) $payout['starts_at'])) ?> · <?= e((int) $payout['booking_count']) ?> đơn</span>
                                </td>
                                <td>
                                    <?= e($payout['business_name']) ?>
<?php if ($isPending && (int) $payout['has_bank'] !== 1): ?>
                                    <span class="lt-table__sub">Chưa khai tài khoản nhận tiền</span>
<?php endif; ?>
                                </td>
                                <td class="text-right lt-nowrap"><?= e(format_vnd($payout['gross_vnd'])) ?></td>
                                <td class="text-right lt-nowrap"><?= e(format_vnd($payout['commission_vnd'])) ?></td>
                                <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['net_vnd'])) ?></strong></td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($payout['status']) ?>"><?= e(PayoutModel::statusLabel((string) $payout['status'])) ?></span>
<?php if (!$isPending): ?>
                                    <span class="lt-table__sub"><?= e(format_datetime((string) $payout['paid_at'])) ?> · mã GD <?= e($payout['transfer_reference']) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right">
                                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/admin/payouts/' . $payout['payout_id'])) ?>"><?= $isPending ? 'Chi trả' : 'Xem' ?><span class="sr-only"> khoản của lịch <?= e(format_datetime((string) $payout['starts_at'])) ?>, <?= e($payout['tour_title']) ?></span></a>
                                </td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
            </section>

            <section class="lt-panel" id="refunds" aria-labelledby="payout-refunds-title">
                <h2 class="lt-panel__title" id="payout-refunds-title">Hoàn tiền cho khách</h2>
<?php if ($refunds === []): ?>
                <p class="lt-empty">Không có khoản hoàn tiền nào đang chờ chuyển cho khách.</p>
<?php else: ?>
                <p class="lt-panel__lead">LocalTour chuyển khoản lại cho khách ngoài hệ thống rồi ghi “Đã hoàn tiền” kèm mã giao dịch. Lịch còn khoản hoàn chưa ghi thì chưa được lập khoản chi trả.</p>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Đơn</th>
                                <th scope="col">Lý do</th>
                                <th scope="col" class="text-right">Số tiền hoàn</th>
                                <th scope="col">Ghi nhận đã hoàn</th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($refunds as $refund): ?>
<?php
    $refundId = (string) $refund['refund_id'];
    $refundError = $refundErrors[$refundId] ?? '';
?>
                            <tr>
                                <td>
                                    <a href="<?= e(url('/admin/bookings/' . $refund['booking_id'])) ?>"><strong><?= e($refund['code']) ?></strong></a>
                                    <span class="lt-table__sub"><?= e($refund['contact_name']) ?> · <?= e($refund['contact_phone']) ?></span>
                                    <span class="lt-table__sub"><?= e($refund['tour_title']) ?> · <?= e(format_datetime((string) $refund['starts_at'])) ?></span>
                                </td>
                                <td>
                                    <?= e($refund['reason']) ?>
                                    <span class="lt-table__sub">Tạo lúc <?= e(format_datetime((string) $refund['requested_at'])) ?> · khách trả qua <?= e(payment_method_label((string) $refund['payment_method'])) ?><?= $refund['payment_reference'] !== null ? ' (' . e($refund['payment_reference']) . ')' : '' ?></span>
                                </td>
                                <td class="text-right lt-nowrap"><strong><?= e(format_vnd($refund['amount_vnd'])) ?></strong></td>
                                <td>
                                    <form action="<?= e(url('/admin/refunds/' . $refundId . '/complete')) ?>" method="post" class="lt-admin-form" novalidate>
                                        <?= csrf_field() ?>
                                        <label class="sr-only" for="refund-ref-<?= e($refundId) ?>">Mã giao dịch hoàn tiền của đơn <?= e($refund['code']) ?></label>
                                        <input class="lt-admin-input<?= $refundError !== '' ? ' is-invalid' : '' ?>" type="text" id="refund-ref-<?= e($refundId) ?>" name="reference"
                                               value="<?= $refundError !== '' ? e($oldReference) : '' ?>" maxlength="<?= e(PayoutModel::REFERENCE_MAX_LENGTH) ?>" placeholder="Mã giao dịch hoàn tiền" required
                                               <?= $refundError !== '' ? 'aria-invalid="true" aria-describedby="refund-error-' . e($refundId) . '" autofocus' : '' ?>>
<?php if ($refundError !== ''): ?>
                                        <p class="lt-admin-error" id="refund-error-<?= e($refundId) ?>"><?= e($refundError) ?></p>
<?php endif; ?>
                                        <button class="lt-btn lt-btn--soft lt-btn--sm" type="submit">Đã hoàn tiền<span class="sr-only"> cho đơn <?= e($refund['code']) ?></span></button>
                                    </form>
                                </td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
            </section>

<?php if ($waiting !== []): ?>
            <section class="lt-panel" aria-labelledby="payout-waiting-title">
                <h2 class="lt-panel__title" id="payout-waiting-title">Lịch đã kết thúc, chưa lập được khoản chi trả</h2>
                <p class="lt-panel__lead">Khoản chi trả chỉ được lập khi lịch không còn việc dang dở. Xử lý xong các việc bên dưới, hệ thống sẽ tự lập khoản chi trả.</p>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Lịch khởi hành</th>
                                <th scope="col">Đơn vị tổ chức</th>
                                <th scope="col" class="text-right">Khách đã trả</th>
                                <th scope="col">Còn dang dở</th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($waiting as $row): ?>
<?php
    $reasons = array_filter([
        (int) $row['open_bookings'] > 0 ? (int) $row['open_bookings'] . ' đơn chưa hoàn thành (chờ thanh toán hoặc có yêu cầu đổi ngày / hủy chờ xử lý)' : '',
        (int) $row['payments_in_review'] > 0 ? (int) $row['payments_in_review'] . ' khoản thanh toán chờ đối chiếu' : '',
        (int) $row['refunds_open'] > 0 ? (int) $row['refunds_open'] . ' khoản hoàn tiền chưa chuyển cho khách' : '',
        (int) $row['changes_pending'] > 0 ? (int) $row['changes_pending'] . ' yêu cầu đổi ngày / hủy tour chờ xử lý' : '',
    ]);
?>
                            <tr>
                                <td>
                                    <strong><?= e($row['tour_title']) ?></strong>
                                    <span class="lt-table__sub"><?= e(format_datetime((string) $row['starts_at'])) ?> – kết thúc <?= e(format_datetime((string) $row['ends_at'])) ?></span>
                                </td>
                                <td><?= e($row['business_name']) ?></td>
                                <td class="text-right lt-nowrap"><?= e(format_vnd($row['paid_vnd'])) ?></td>
                                <td><?= e(implode('; ', $reasons)) ?></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </section>
<?php endif; ?>
        </main>
    </div>
</div>
