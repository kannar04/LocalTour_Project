<?php declare(strict_types=1); ?>
<?php
/*
 * Danh sách yêu cầu đổi ngày / hủy tour (US14-S5-03, FR-12 – Nguyễn Tuấn Khôi).
 * Biến: $filter ('pending' | 'approved' | 'rejected' | 'all'), $requests (LTP_sp_admin_change_request_list,
 *       yêu cầu chờ xử lý trước).
 */
use App\Models\AdminChangeRequestModel;
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Yêu cầu đổi ngày / hủy tour</h1>
                <p class="lt-admin__subtitle">Khách gửi từ trang đơn. Đồng ý hủy thì đơn bị hủy và ghi số tiền cần hoàn; LocalTour chuyển khoản lại thủ công.</p>
            </header>

            <nav class="lt-tabs" aria-label="Lọc theo trạng thái xử lý">
<?php foreach (AdminChangeRequestModel::FILTERS as $value => $label): ?>
                <a class="lt-tabs__link<?= $value === $filter ? ' is-active' : '' ?>" href="<?= e(url('/admin/change-requests' . ($value === 'pending' ? '' : '?status=' . $value))) ?>"<?= $value === $filter ? ' aria-current="page"' : '' ?>><?= e($label) ?></a>
<?php endforeach; ?>
            </nav>

            <section class="lt-panel" aria-label="Danh sách yêu cầu">
<?php if ($requests === []): ?>
                <p class="lt-empty"><?= $filter === 'pending' ? 'Không có yêu cầu nào đang chờ xử lý.' : 'Không có yêu cầu nào ở trạng thái này.' ?></p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Gửi lúc</th>
                                <th scope="col">Đơn</th>
                                <th scope="col">Tour</th>
                                <th scope="col">Yêu cầu</th>
                                <th scope="col" class="text-right">Đã thanh toán</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($requests as $request): ?>
<?php $isCancel = $request['type'] === 'cancel'; ?>
                            <tr>
                                <td><?= e(format_datetime((string) $request['created_at'])) ?></td>
                                <td>
                                    <strong><?= e($request['booking_code']) ?></strong>
                                    <span class="lt-table__sub"><?= e($request['customer_name']) ?> · <?= e(booking_status_label((string) $request['booking_status'])) ?></span>
                                </td>
                                <td>
                                    <?= e($request['tour_title']) ?>
                                    <span class="lt-table__sub"><?= e(format_datetime((string) $request['starts_at'])) ?> · <?= e((int) $request['people']) ?> khách</span>
                                </td>
                                <td>
                                    <?= e(change_request_type_label((string) $request['type'])) ?>
<?php if (!$isCancel && $request['requested_starts_at'] !== null): ?>
                                    <span class="lt-table__sub">Sang <?= e(format_datetime((string) $request['requested_starts_at'])) ?></span>
<?php elseif ($isCancel && (int) $request['paid_vnd'] > 0): ?>
                                    <span class="lt-table__sub"><?= $request['refund_vnd'] !== null ? 'Hoàn ' . e(format_vnd($request['refund_vnd'])) : 'Dự kiến hoàn ' . e(format_vnd($request['estimated_refund_vnd'])) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right"><?= e(format_vnd($request['paid_vnd'])) ?></td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($request['status']) ?>"><?= e(change_request_status_label((string) $request['status'])) ?></span>
<?php if ($request['handler_name'] !== null): ?>
                                    <span class="lt-table__sub"><?= e($request['handler_name']) ?><?= $request['handled_at'] !== null ? ' · ' . e(format_datetime((string) $request['handled_at'])) : '' ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right">
                                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/admin/change-requests/' . $request['request_id'])) ?>"><?= $request['status'] === 'pending' ? 'Xử lý' : 'Xem' ?><span class="sr-only"> yêu cầu của đơn <?= e($request['booking_code']) ?></span></a>
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
