<?php declare(strict_types=1); ?>
<?php
/*
 * Form thêm tour / sửa thông tin tour (FR-13, NFR-07, Nguyễn Minh Thức).
 * Biến: $tour (NMT_sp_admin_tour_form; null = thêm tour), $old (giá trị đang nhập của các ô),
 *       $errors (lỗi theo ô; 'form' = lỗi chung như hết phiên),
 *       $options (providers, destinations, categories: mã → nhãn).
 * Ảnh, lịch trình, dịch vụ bao gồm, dịch vụ thêm và chính sách hủy chưa sửa được ở trang này.
 */
use App\Controllers\AdminTourFormController;

$isNew = $tour === null;
$action = $isNew ? '/admin/tours/new' : '/admin/tours/' . $tour['tour_id'] . '/edit';
$cancelHref = $isNew ? '/admin/tours' : '/admin/tours/' . $tour['tour_id'];
$max = AdminTourFormController::MAX_LENGTHS;
$verifiedHint = 'Cần nguồn tham khảo; ngày xác minh là ngày lưu.';
if (!$isNew && $tour['verification_status'] === 'verified' && $tour['verified_at'] !== null) {
    $verifiedHint = 'Đã xác minh ngày ' . format_date($tour['verified_at']) . '. Giữ "Đã xác minh" thì không đổi ngày.';
}

// Mỗi nhóm một khung; 'half' = nửa dòng trên màn hình rộng.
$sections = [
    'Thông tin chính' => [
        ['name' => 'title', 'label' => 'Tên tour', 'type' => 'text', 'required' => true, 'hint' => ''],
        ['name' => 'provider_id', 'label' => 'Đơn vị tổ chức', 'type' => 'select', 'required' => true, 'half' => true,
            'options' => $options['providers'], 'placeholder' => 'Chọn đơn vị tổ chức', 'hint' => 'Chưa có trong danh sách? Thêm ở trang "Đơn vị tổ chức".'],
        ['name' => 'destination_id', 'label' => 'Điểm đến', 'type' => 'select', 'required' => true, 'half' => true,
            'options' => $options['destinations'], 'placeholder' => 'Chọn điểm đến', 'hint' => ''],
        ['name' => 'category_id', 'label' => 'Loại hình (không bắt buộc)', 'type' => 'select', 'required' => false, 'half' => true,
            'options' => $options['categories'], 'placeholder' => 'Chưa phân loại', 'hint' => ''],
        ['name' => 'language_codes', 'label' => 'Ngôn ngữ hướng dẫn', 'type' => 'text', 'required' => true, 'half' => true,
            'hint' => 'Mã 2 chữ cái, cách nhau bằng dấu phẩy: vi, en, fr, ko, zh, ja.'],
        ['name' => 'duration_minutes', 'label' => 'Thời lượng (phút)', 'type' => 'number', 'required' => true, 'half' => true,
            'min' => AdminTourFormController::DURATION_MIN, 'max' => AdminTourFormController::DURATION_MAX, 'hint' => 'Ví dụ 240 = 4 giờ.'],
        ['name' => 'max_group_size', 'label' => 'Số khách tối đa mỗi yêu cầu đặt', 'type' => 'number', 'required' => true, 'half' => true,
            'min' => 1, 'max' => AdminTourFormController::GROUP_MAX, 'hint' => ''],
        ['name' => 'description', 'label' => 'Mô tả', 'type' => 'textarea', 'rows' => 7, 'required' => true,
            'hint' => 'Đoạn đầu là câu dẫn ngắn; các đoạn cách nhau bằng một dòng trống.'],
    ],
    'Khởi hành và dịch vụ' => [
        ['name' => 'pickup_mode', 'label' => 'Hình thức đón khách', 'type' => 'radio', 'required' => true,
            'options' => ['meeting_point' => 'Khách tự đến điểm hẹn', 'hotel_pickup' => 'Đón tại khách sạn'], 'hint' => ''],
        ['name' => 'meeting_point', 'label' => 'Điểm hẹn / khu vực đón', 'type' => 'text', 'required' => false,
            'hint' => 'Bắt buộc khi khách tự đến điểm hẹn; khi đón tại khách sạn, ghi khu vực đón.'],
        ['name' => 'dropoff_point', 'label' => 'Điểm trả khách', 'type' => 'text', 'required' => false, 'half' => true, 'hint' => ''],
        ['name' => 'transport', 'label' => 'Phương tiện', 'type' => 'text', 'required' => false, 'half' => true, 'hint' => ''],
        ['name' => 'guide_info', 'label' => 'Hướng dẫn viên', 'type' => 'text', 'required' => false, 'hint' => ''],
    ],
    'Điều kiện tour' => [
        ['name' => 'document_terms', 'label' => 'Giấy tờ', 'type' => 'textarea', 'rows' => 3, 'required' => false, 'half' => true, 'hint' => 'Mỗi ý một dòng.'],
        ['name' => 'meal_terms', 'label' => 'Ăn uống', 'type' => 'textarea', 'rows' => 3, 'required' => false, 'half' => true, 'hint' => 'Mỗi ý một dòng.'],
        ['name' => 'voucher_terms', 'label' => 'Voucher', 'type' => 'textarea', 'rows' => 3, 'required' => false, 'half' => true, 'hint' => 'Mỗi ý một dòng.'],
        ['name' => 'reschedule_terms', 'label' => 'Đổi lịch', 'type' => 'textarea', 'rows' => 3, 'required' => false, 'half' => true, 'hint' => 'Mỗi ý một dòng.'],
    ],
    'Nguồn và xác minh' => [
        ['name' => 'source_url', 'label' => 'Nguồn tham khảo', 'type' => 'url', 'required' => false,
            'hint' => 'Đường dẫn trang web hoặc tài liệu dùng để kiểm tra thông tin tour.'],
        ['name' => 'verification_status', 'label' => 'Trạng thái xác minh', 'type' => 'radio', 'required' => true,
            'options' => ['unverified' => 'Chưa xác minh', 'verified' => 'Đã xác minh'], 'hint' => $verifiedHint],
    ],
];
$focusField = array_key_first(array_diff_key($errors, ['form' => true])) ?? 'title';
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url($cancelHref)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> <?= $isNew ? 'Danh sách tour' : 'Chi tiết tour' ?>
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title"><?= $isNew ? 'Thêm tour' : 'Sửa thông tin tour' ?></h1>
                <p class="lt-admin__subtitle">
<?php if ($isNew): ?>
                    Tour mới ở trạng thái "Chờ duyệt". Sau khi lưu, thêm lịch khởi hành và giá vé rồi phê duyệt ở trang chi tiết tour.
<?php else: ?>
                    <span class="lt-badge lt-badge--<?= e($tour['approval_status']) ?>"><?= e(tour_status_label($tour['approval_status'])) ?></span>
                    Sửa thông tin không đổi trạng thái duyệt của tour.
<?php endif; ?>
                </p>
            </header>

<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <form class="lt-admin-form" action="<?= e(url($action)) ?>" method="post" novalidate>
                <?= csrf_field() ?>
<?php $sectionNo = 0; ?>
<?php foreach ($sections as $sectionTitle => $fields): ?>
<?php $sectionId = 'tour-form-section-' . ++$sectionNo; ?>
                <section class="lt-panel" aria-labelledby="<?= e($sectionId) ?>">
                    <h2 class="lt-panel__title" id="<?= e($sectionId) ?>"><?= e($sectionTitle) ?></h2>
                    <div class="row">
<?php foreach ($fields as $field): ?>
<?php
    $name = $field['name'];
    $id = 'tour-' . str_replace('_', '-', $name);
    $error = $errors[$name] ?? '';
    $value = $old[$name] ?? '';
    $describedBy = trim(($field['hint'] !== '' ? $id . '-hint ' : '') . ($error !== '' ? $id . '-error' : ''));
    $described = $describedBy !== '' ? ' aria-describedby="' . e($describedBy) . '"' : '';
    $common = ($field['required'] ? ' required' : '')
        . ($error !== '' ? ' aria-invalid="true"' : '')
        . $described
        . ($name === $focusField ? ' autofocus' : '');
    $inputClass = 'lt-admin-input' . ($error !== '' ? ' is-invalid' : '');
?>
                        <div class="<?= !empty($field['half']) ? 'col-12 col-md-6' : 'col-12' ?>">
                            <div class="lt-admin-field">
<?php if ($field['type'] === 'radio'): ?>
                                <fieldset class="lt-choices lt-choices--inline mb-0<?= $error !== '' ? ' is-invalid' : '' ?>"<?= $described ?>>
                                    <legend class="lt-admin-label"><?= e($field['label']) ?></legend>
<?php foreach ($field['options'] as $optionValue => $optionLabel): ?>
                                    <label class="lt-choice">
                                        <input type="radio" name="<?= e($name) ?>" value="<?= e($optionValue) ?>" required<?= $value === (string) $optionValue ? ' checked' : '' ?>>
                                        <span><?= e($optionLabel) ?></span>
                                    </label>
<?php endforeach; ?>
                                </fieldset>
<?php else: ?>
                                <label class="lt-admin-label" for="<?= e($id) ?>"><?= e($field['label']) ?></label>
<?php if ($field['type'] === 'select'): ?>
                                <select class="<?= e($inputClass) ?>" id="<?= e($id) ?>" name="<?= e($name) ?>"<?= $common ?>>
                                    <option value=""><?= e($field['placeholder']) ?></option>
<?php foreach ($field['options'] as $optionValue => $optionLabel): ?>
                                    <option value="<?= e($optionValue) ?>"<?= $value === (string) $optionValue ? ' selected' : '' ?>><?= e($optionLabel) ?></option>
<?php endforeach; ?>
                                </select>
<?php elseif ($field['type'] === 'textarea'): ?>
                                <textarea class="<?= e($inputClass) ?>" id="<?= e($id) ?>" name="<?= e($name) ?>" rows="<?= e($field['rows']) ?>" maxlength="<?= e($max[$name]) ?>"<?= $common ?>><?= e($value) ?></textarea>
<?php elseif ($field['type'] === 'number'): ?>
                                <input class="<?= e($inputClass) ?>" type="number" id="<?= e($id) ?>" name="<?= e($name) ?>" value="<?= e($value) ?>"
                                       min="<?= e($field['min']) ?>" max="<?= e($field['max']) ?>" step="1" inputmode="numeric"<?= $common ?>>
<?php else: ?>
                                <input class="<?= e($inputClass) ?>" type="<?= e($field['type']) ?>" id="<?= e($id) ?>" name="<?= e($name) ?>" value="<?= e($value) ?>"
                                       maxlength="<?= e($max[$name]) ?>"<?= $common ?>>
<?php endif; ?>
<?php endif; ?>
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
                </section>
<?php endforeach; ?>

                <p class="lt-admin-hint">Ảnh, lịch trình, dịch vụ bao gồm và chính sách hủy chưa sửa được ở trang này. Lịch khởi hành và giá vé sửa ở trang "Lịch khởi hành và giá vé" của tour.</p>
                <div class="lt-admin__actions">
                    <button class="lt-btn lt-btn--primary" type="submit"><?= $isNew ? 'Thêm tour' : 'Lưu thay đổi' ?></button>
                    <a class="lt-btn lt-btn--outline" href="<?= e(url($cancelHref)) ?>">Hủy</a>
                </div>
            </form>
        </main>
    </div>
</div>
