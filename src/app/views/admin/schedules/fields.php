<?php declare(strict_types=1); ?>
<?php
/*
 * Các ô chung của form thêm / sửa lịch khởi hành (FR-14, Nguyễn Minh Thức).
 * Biến: $old (starts_at, ends_at, capacity, adult_price, child_price), $errors (lỗi theo ô),
 *       $prefix (tiền tố id của ô), $lockTimes (true = lịch đã khởi hành, không đổi giờ),
 *       $heldSeats (số chỗ đang giữ: sức chứa tối thiểu).
 */
use App\Models\AdminScheduleModel;

$scheduleFields = [
    ['name' => 'starts_at', 'label' => 'Khởi hành', 'type' => 'datetime-local', 'col' => 'col-md-6', 'required' => true,
        'hint' => $lockTimes ? 'Lịch đã khởi hành nên không đổi được giờ.' : ''],
    ['name' => 'ends_at', 'label' => 'Kết thúc', 'type' => 'datetime-local', 'col' => 'col-md-6', 'required' => true, 'hint' => ''],
    ['name' => 'capacity', 'label' => 'Sức chứa (chỗ)', 'type' => 'number', 'col' => 'col-md-4', 'required' => true,
        'hint' => $heldSeats > 0 ? 'Đang giữ ' . $heldSeats . ' chỗ: không nhập nhỏ hơn số này.' : 'Từ 1 đến ' . AdminScheduleModel::CAPACITY_MAX . ' chỗ.'],
    ['name' => 'adult_price', 'label' => 'Giá vé người lớn (đ)', 'type' => 'text', 'col' => 'col-md-4', 'required' => true, 'hint' => 'Từ 12 tuổi.'],
    ['name' => 'child_price', 'label' => 'Giá vé trẻ em (đ)', 'type' => 'text', 'col' => 'col-md-4', 'required' => false,
        'hint' => '4–11 tuổi. Để trống nếu không bán vé trẻ em.'],
];
?>
<div class="row">
<?php foreach ($scheduleFields as $field): ?>
<?php
    $name = $field['name'];
    $id = $prefix . '-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
    $describedBy = trim(($field['hint'] !== '' ? $id . '-hint ' : '') . ($error !== '' ? $id . '-error' : ''));
    $isTime = $field['type'] === 'datetime-local';
?>
    <div class="col-12 <?= e($field['col']) ?>">
        <div class="lt-admin-field">
            <label class="lt-admin-label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
            <input class="lt-admin-input<?= $error !== '' ? ' is-invalid' : '' ?>" type="<?= e($field['type']) ?>" id="<?= e($id) ?>"
                   name="<?= e($name) ?>" value="<?= e($old[$name]) ?>"<?= $field['required'] ? ' required' : '' ?>
<?php if ($field['type'] === 'number'): ?>
                   min="<?= e(max(1, $heldSeats)) ?>" max="<?= e(AdminScheduleModel::CAPACITY_MAX) ?>" step="1" inputmode="numeric"
<?php elseif (!$isTime): ?>
                   inputmode="numeric" maxlength="15" autocomplete="off"
<?php endif; ?>
                   <?= $isTime && $lockTimes ? 'readonly' : '' ?> <?= $error !== '' ? 'aria-invalid="true"' : '' ?>
                   <?= $describedBy !== '' ? 'aria-describedby="' . e($describedBy) . '"' : '' ?>>
<?php if ($field['hint'] !== ''): ?>
            <p class="lt-admin-hint" id="<?= e($id) ?>-hint"><?= e($field['hint']) ?></p>
<?php endif; ?>
<?php if ($error !== ''): ?>
            <p class="lt-admin-error" id="<?= e($id) ?>-error"><?= e($error) ?></p>
<?php endif; ?>
        </div>
    </div>
<?php endforeach; ?>
</div>
