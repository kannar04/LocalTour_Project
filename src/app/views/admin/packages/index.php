<?php declare(strict_types=1); ?>
<?php
/*
 * Gói tour của một tour (US06-S5-01, FR-07 – Nguyễn Tuấn Khôi): danh sách gói và form thêm / sửa gói.
 * Biến: $tour (LTP_sp_admin_tour_detail), $packages (LTP_sp_admin_package_list), $old (form; package_id '' = gói mới),
 *       $errors (theo ô; 'form' = lỗi chung), $success.
 * Gói không xóa được (đơn cũ còn ghi tên gói): bỏ chọn "Đang bán" để ngừng bán.
 */
use App\Models\AdminPackageModel;

$tourId = (string) $tour['tour_id'];
$isEdit = $old['package_id'] !== '';
$baseUrl = '/admin/tours/' . $tourId . '/packages';
$activeCount = count(array_filter($packages, static fn (array $package): bool => (int) $package['active'] === 1));
$fields = [
    ['name' => 'name', 'label' => 'Tên gói', 'col' => 'col-md-8', 'max' => AdminPackageModel::NAME_MAX_LENGTH, 'hint' => 'Ví dụ: Gói tiêu chuẩn, Gói có xe đưa đón.'],
    ['name' => 'sort_order', 'label' => 'Thứ tự hiển thị', 'col' => 'col-md-4', 'max' => 3, 'hint' => 'Số nhỏ hiện trước (0–' . AdminPackageModel::SORT_MAX . ').'],
    ['name' => 'adult_price', 'label' => 'Giá người lớn (đ)', 'col' => 'col-md-6', 'max' => 15, 'hint' => 'Từ 12 tuổi.'],
    ['name' => 'child_price', 'label' => 'Giá trẻ em (đ)', 'col' => 'col-md-6', 'max' => 15, 'hint' => '4–11 tuổi. Để trống nếu gói không bán vé trẻ em.'],
];
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/admin/tours/' . $tourId)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Chi tiết tour
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Gói tour</h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($tour['approval_status']) ?>"><?= e(tour_status_label($tour['approval_status'])) ?></span>
                    <?= e($tour['title']) ?>
                </p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Chưa lưu được gói: vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>
<?= $activeCount > 0
    ? 'Tour đang bán ' . e($activeCount) . ' gói: khách phải chọn gói khi đặt, giá vé lấy theo gói (giá vé của lịch khởi hành không dùng nữa).'
    : 'Tour chưa có gói đang bán: khách đặt theo giá vé của từng lịch khởi hành.' ?>
            </span></div>

            <section class="lt-panel" aria-labelledby="package-list-title">
                <h2 class="lt-panel__title" id="package-list-title">Các gói</h2>
<?php if ($packages === []): ?>
                <p class="lt-empty">Tour chưa có gói nào.</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr>
                                <th scope="col">Gói</th>
                                <th scope="col">Giá</th>
                                <th scope="col">Trạng thái</th>
                                <th scope="col" class="text-right">Đơn đã đặt</th>
                                <th scope="col"><span class="sr-only">Thao tác</span></th>
                            </tr>
                        </thead>
                        <tbody>
<?php foreach ($packages as $package): ?>
<?php $isActive = (int) $package['active'] === 1; ?>
                            <tr>
                                <td>
                                    <strong><?= e($package['name']) ?></strong>
<?php if ($package['description'] !== null && $package['description'] !== ''): ?>
                                    <span class="lt-table__sub"><?= e($package['description']) ?></span>
<?php endif; ?>
                                </td>
                                <td>
                                    Người lớn <?= e(format_vnd($package['adult_price_vnd'])) ?>
                                    <span class="lt-table__sub"><?= $package['child_price_vnd'] !== null ? 'Trẻ em ' . e(format_vnd($package['child_price_vnd'])) : 'Không bán vé trẻ em' ?></span>
                                </td>
                                <td><span class="lt-badge lt-badge--<?= $isActive ? 'open' : 'rejected' ?>"><?= $isActive ? 'Đang bán' : 'Ngừng bán' ?></span></td>
                                <td class="text-right">
                                    <?= e((int) $package['booking_count']) ?>
<?php if ((int) $package['active_booking_count'] > 0): ?>
                                    <span class="lt-table__sub"><?= e((int) $package['active_booking_count']) ?> đang xử lý</span>
<?php endif; ?>
                                </td>
                                <td class="text-right">
                                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url($baseUrl . '?edit=' . $package['package_id'])) ?>#package-form-title">Sửa<span class="sr-only"> gói <?= e($package['name']) ?></span></a>
                                </td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>
            </section>

            <section class="lt-panel" aria-labelledby="package-form-title">
                <h2 class="lt-panel__title" id="package-form-title"><?= $isEdit ? 'Sửa gói “' . e($old['name']) . '”' : 'Thêm gói' ?></h2>
                <form class="lt-admin-form" action="<?= e(url($baseUrl)) ?>" method="post" novalidate>
                    <?= csrf_field() ?>
                    <input type="hidden" name="package_id" value="<?= e($old['package_id']) ?>">
                    <div class="row">
<?php foreach ($fields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'package-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
?>
                        <div class="col-12 <?= e($field['col']) ?>">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
                                <input class="lt-admin-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="text" id="<?= e($id) ?>" name="<?= e($name) ?>"
                                       value="<?= e($old[$name]) ?>" maxlength="<?= e($field['max']) ?>"<?= $name !== 'name' ? ' inputmode="numeric" autocomplete="off"' : '' ?>
                                       aria-describedby="<?= e($id) ?>-hint<?= $error !== '' ? ' ' . e($id) . '-error' : '' ?>"<?= $error !== '' ? ' aria-invalid="true"' : '' ?>>
                                <p class="lt-admin-hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php if ($error !== ''): ?>
                                <p class="lt-admin-error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
                            </div>
                        </div>
<?php endforeach; ?>
                        <div class="col-12">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="package-description">Mô tả (không bắt buộc)</label>
                                <textarea class="lt-admin-input<?= isset($errors['description']) ? ' is-invalid' : '' ?>" id="package-description" name="description" rows="2"
                                          maxlength="<?= e(AdminPackageModel::DESCRIPTION_MAX_LENGTH) ?>"><?= e($old['description']) ?></textarea>
<?php if (isset($errors['description'])): ?>
                                <p class="lt-admin-error"><?= e($errors['description']) ?></p>
<?php endif; ?>
                            </div>
                            <div class="custom-control custom-checkbox lt-admin-field">
                                <input class="custom-control-input" type="checkbox" id="package-active" name="active" value="1"<?= $old['active'] === '1' ? ' checked' : '' ?>>
                                <label class="custom-control-label" for="package-active">Đang bán (bỏ chọn để ngừng bán; đơn đã đặt không bị ảnh hưởng)</label>
                            </div>
                        </div>
                    </div>
                    <button class="lt-btn lt-btn--primary" type="submit">
                        <span class="lt-icon lt-icon--<?= $isEdit ? 'check' : 'plus' ?>" aria-hidden="true"></span> <?= $isEdit ? 'Lưu gói' : 'Thêm gói' ?>
                    </button>
<?php if ($isEdit): ?>
                    <a class="lt-btn lt-btn--outline" href="<?= e(url($baseUrl)) ?>">Hủy sửa</a>
<?php endif; ?>
                </form>
            </section>
        </main>
    </div>
</div>
