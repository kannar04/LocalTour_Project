<?php declare(strict_types=1); ?>
<?php
/*
 * Khoản chuyển khoản VietQR chờ đối chiếu (Sprint 4, 4.5.3.2 – Nguyễn Minh Thức, Nguyễn Tuấn Khôi).
 * Biến: $payments (NMT_sp_admin_payment_queue, báo trước lên trước), $error ('' = không có).
 * Quản trị viên mở yêu cầu để so số tiền và nội dung chuyển khoản với sao kê rồi bấm "Đã nhận tiền" / "Không khớp".
 */
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Đối chiếu thanh toán</h1>
                <p class="lt-admin__subtitle">Chuyển khoản VietQR khách đã báo, chờ kiểm tra sao kê tài khoản nhận tiền</p>
            </header>

<?php if ($error !== ''): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($error) ?></span></div>
<?php endif; ?>

            <section class="lt-panel" aria-label="Khoản chờ đối chiếu">
<?php if ($payments === []): ?>
                <p class="lt-empty">Không có khoản chuyển khoản nào chờ đối chiếu.</p>
<?php else: ?>
                <p class="lt-panel__lead"><?= count($payments) ?> khoản chờ đối chiếu, khách báo trước ở trên. Đơn có khoản chờ đối chiếu không bị tự hủy khi quá hạn.</p>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Nội dung CK</th>
                                <th scope="col" class="text-right">Số tiền</th>
                                <th scope="col">Đơn</th>
                                <th scope="col" class="lt-table__grow">Tour</th>
                                <th scope="col">Khách báo lúc</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($payments as $payment): ?>
                            <tr>
                                <td class="lt-nowrap"><code><?= e($payment['reference']) ?></code></td>
                                <td class="text-right lt-nowrap">
                                    <?= e(format_vnd($payment['amount_vnd'])) ?>
<?php if ((int) $payment['amount_vnd'] !== (int) $payment['total_vnd']): ?>
                                    <span class="lt-table__sub">Tổng đơn <?= e(format_vnd($payment['total_vnd'])) ?></span>
<?php endif; ?>
                                </td>
                                <td class="lt-nowrap">
                                    <strong><?= e($payment['code']) ?></strong>
                                    <span class="lt-table__sub"><?= e($payment['contact_name']) ?> · <?= e($payment['contact_phone']) ?></span>
                                </td>
                                <td>
                                    <?= e($payment['tour_title']) ?>
                                    <span class="lt-table__sub">Khởi hành <?= e(format_datetime($payment['starts_at'])) ?></span>
                                </td>
                                <td class="lt-nowrap">
                                    <?= e(format_datetime($payment['submitted_at'])) ?>
<?php if ($payment['hold_expires_at'] !== null): ?>
                                    <span class="lt-table__sub">Hạn giữ chỗ <?= e(format_datetime($payment['hold_expires_at'])) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right"><a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/admin/bookings/' . $payment['booking_id']) . '#payments') ?>">Đối chiếu</a></td>
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
