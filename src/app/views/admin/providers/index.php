<?php declare(strict_types=1); ?>
<?php
/*
 * Danh sách đơn vị tổ chức (FR-13, Nguyễn Minh Thức).
 * Biến: $providers (NMT_sp_admin_provider_list), $success (thông báo sau khi lưu, '' = không có).
 */
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head lt-admin__head--row">
                <div>
                    <h1 class="lt-admin__title" id="admin-title">Đơn vị tổ chức</h1>
                    <p class="lt-admin__subtitle">Tour của đơn vị chỉ hiển thị cho khách khi đơn vị đang hợp tác</p>
                </div>
                <a class="lt-btn lt-btn--primary" href="<?= e(url('/admin/providers/new')) ?>">
                    <span class="lt-icon lt-icon--plus" aria-hidden="true"></span> Thêm đơn vị
                </a>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>

            <section class="lt-panel" aria-label="Danh sách đơn vị tổ chức">
<?php if ($providers === []): ?>
                <p class="lt-empty">Chưa có đơn vị tổ chức nào.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Tên đơn vị</th>
                                <th scope="col">Số điện thoại</th>
                                <th scope="col">Email</th>
                                <th scope="col">Trạng thái hợp tác</th>
                                <th scope="col" class="text-right">Số tour</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($providers as $provider): ?>
                            <tr>
                                <td>
                                    <strong><?= e($provider['business_name']) ?></strong>
<?php if ($provider['user_status'] !== 'active'): ?>
                                    <span class="lt-table__sub">Tài khoản đang bị khóa</span>
<?php endif; ?>
                                </td>
                                <td><?= e($provider['contact_phone']) ?></td>
                                <td><?= e($provider['email']) ?></td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($provider['approval_status']) ?>"><?= e(provider_status_label($provider['approval_status'])) ?></span>
<?php if ($provider['approved_at'] !== null): ?>
                                    <span class="lt-table__sub">Từ <?= e(format_date($provider['approved_at'])) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right"><?= e($provider['tour_count']) ?></td>
                                <td class="text-right"><a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/admin/providers/' . $provider['provider_id'] . '/edit')) ?>">Sửa</a></td>
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
