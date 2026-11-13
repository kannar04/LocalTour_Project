<?php declare(strict_types=1); ?>
<?php
/*
 * Khu đơn vị tổ chức: "Tour của tôi" (Nguyễn Tuấn Khôi).
 * Biến: $host (đơn vị đang đăng nhập, NTK_sp_host_profile), $tours (NTK_sp_host_tour_list: mọi tour của đơn vị,
 *       tour bị từ chối và bản nháp trước; revision_id / revision_status = bản sửa đang mở của tour đã duyệt).
 */
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../../admin/partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head lt-admin__head--row">
                <div>
                    <h1 class="lt-admin__title" id="admin-title">Tour của tôi</h1>
                    <p class="lt-admin__subtitle"><?= e($host['business_name']) ?> · Tour chỉ hiển thị cho khách sau khi quản trị viên LocalTour duyệt</p>
                </div>
                <a class="lt-btn lt-btn--primary" href="<?= e(url('/host/tours/new')) ?>">
                    <span class="lt-icon lt-icon--plus" aria-hidden="true"></span> Thêm tour
                </a>
            </header>

            <section class="lt-panel" aria-label="Danh sách tour của đơn vị">
<?php if ($tours === []): ?>
                <p class="lt-empty">Đơn vị chưa có tour nào. Chọn "Thêm tour" để đăng tour đầu tiên.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Tour</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col">Hiển thị cho khách</th>
                                <th scope="col">Lịch sắp khởi hành</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($tours as $tour): ?>
                            <tr>
                                <td>
                                    <strong><?= e($tour['title']) ?></strong>
                                    <span class="lt-table__sub"><?= e($tour['destination_name']) ?><?= $tour['category_name'] !== null ? ' · ' . e($tour['category_name']) : '' ?></span>
                                </td>
                                <td>
                                    <span class="lt-badge lt-badge--<?= e($tour['approval_status']) ?>"><?= e(tour_status_label($tour['approval_status'])) ?></span>
<?php if ($tour['reject_note'] !== null): ?>
                                    <span class="lt-table__sub">Lý do: <?= e($tour['reject_note']) ?></span>
<?php endif; ?>
<?php if ($tour['revision_id'] !== null): ?>
                                    <span class="lt-table__sub"><a href="<?= e(url('/host/tours/' . $tour['revision_id'])) ?>">Bản sửa: <?= e(tour_status_label($tour['revision_status'])) ?></a></span>
<?php endif; ?>
                                </td>
                                <td><?= (int) $tour['is_public'] === 1 ? 'Có' : 'Không' ?></td>
                                <td>
<?php if ((int) $tour['upcoming_count'] > 0): ?>
                                    <?= e($tour['upcoming_count']) ?> lịch
                                    <span class="lt-table__sub">Gần nhất <?= e(format_datetime($tour['next_starts_at'])) ?></span>
<?php else: ?>
                                    <span class="lt-muted">Chưa có</span>
<?php endif; ?>
                                </td>
                                <td class="text-right"><a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/host/tours/' . $tour['tour_id'])) ?>">Xem<span class="sr-only"> tour <?= e($tour['title']) ?></span></a></td>
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
