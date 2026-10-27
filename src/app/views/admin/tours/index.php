<?php declare(strict_types=1); ?>
<?php
/*
 * Danh sách tour cho quản trị viên duyệt (FR-24, Lê Trung Phong).
 * Biến: $filter ('pending' | 'approved' | 'rejected' | 'all'), $tours (LTP_sp_admin_tour_list).
 */
use App\Controllers\AdminTourController;
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Duyệt tour</h1>
                <p class="lt-admin__subtitle">Tour chỉ hiển thị cho khách khi đã được duyệt và đơn vị tổ chức đã được duyệt, đang hoạt động</p>
            </header>

            <nav class="lt-tabs" aria-label="Lọc theo trạng thái duyệt">
<?php foreach (AdminTourController::FILTERS as $value => $label): ?>
                <a class="lt-tabs__link<?= $value === $filter ? ' is-active' : '' ?>" href="<?= e(url('/admin/tours' . ($value === 'pending' ? '' : '?status=' . $value))) ?>"<?= $value === $filter ? ' aria-current="page"' : '' ?>><?= e($label) ?></a>
<?php endforeach; ?>
            </nav>

            <section class="lt-panel" aria-label="Danh sách tour">
<?php if ($tours === []): ?>
                <p class="lt-empty"><?= $filter === 'pending' ? 'Không có tour nào đang chờ duyệt.' : 'Không có tour nào ở trạng thái này.' ?></p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Tour</th>
                                <th scope="col">Đơn vị tổ chức</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col">Hiển thị</th>
                                <th scope="col" class="text-right">Lịch</th>
                                <th scope="col">Xử lý gần nhất</th>
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
                                <td><?= e($tour['provider_name']) ?></td>
                                <td><span class="lt-badge lt-badge--<?= e($tour['approval_status']) ?>"><?= e(tour_status_label($tour['approval_status'])) ?></span></td>
                                <td><?= (int) $tour['is_public'] === 1 ? 'Có' : 'Không' ?></td>
                                <td class="text-right"><?= e($tour['schedule_count']) ?></td>
                                <td><?= $tour['last_action_at'] !== null ? e(format_datetime($tour['last_action_at'])) : '<span class="lt-muted">Chưa có</span>' ?></td>
                                <td class="text-right"><a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url('/admin/tours/' . $tour['tour_id'])) ?>"><?= $tour['approval_status'] === 'pending' ? 'Xem và duyệt' : 'Xem' ?></a></td>
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
