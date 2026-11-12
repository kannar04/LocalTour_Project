<?php declare(strict_types=1); ?>
<?php
/*
 * Nội dung tour (US07-S5-01, FR-13 – Nguyễn Tuấn Khôi): ảnh, lịch trình, dịch vụ bao gồm / không bao gồm,
 * chính sách hủy theo phiên bản, xóa tour / ngừng hiển thị và hiển thị lại.
 * Biến: $tour (LTP_sp_admin_tour_detail), $images, $itinerary, $inclusions, $policies (NMT_sp_admin_*_list),
 *       $old (giá trị các form, AdminTourContentController::EMPTY_FORM), $errors (theo ô; 'form' = lỗi chung), $success.
 *       $portal ('/admin' hoặc '/host'), $host (đơn vị tổ chức đang đăng nhập ở khu /host; null ở trang quản trị):
 *       đơn vị không có phần xóa / hiển thị lại tour.
 */
use App\Models\AdminTourContentModel;

$tourId = (string) $tour['tour_id'];
$isHost = $host !== null;
$base = $portal . '/tours/' . $tourId . '/content';
$isArchived = $tour['approval_status'] === 'archived';
$isEditItem = $old['item_id'] !== '';
$fieldError = static fn (string $field): string => $errors[$field] ?? '';
$invalid = static fn (string $field): string => isset($errors[$field]) ? ' is-invalid' : '';
$included = array_values(array_filter($inclusions, static fn (array $row): bool => (int) $row['is_included'] === 1));
$excluded = array_values(array_filter($inclusions, static fn (array $row): bool => (int) $row['is_included'] !== 1));
$maxMb = AdminTourContentModel::IMAGE_MAX_BYTES / 1024 / 1024;
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url($portal . '/tours/' . $tourId)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Chi tiết tour
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Ảnh, lịch trình, dịch vụ và chính sách</h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($tour['approval_status']) ?>"><?= e(tour_status_label($tour['approval_status'])) ?></span>
                    <?= e($tour['title']) ?>
                </p>
<?php if ($isHost && $tour['approval_status'] === 'approved'): ?>
                <p class="lt-admin-hint">Tour đang hiển thị cho khách. Mỗi thay đổi ở trang này đưa tour về "Chờ duyệt" cho tới khi quản trị viên duyệt lại.</p>
<?php endif; ?>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Chưa lưu được: vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <nav class="lt-tabs" aria-label="Mục trong trang">
                <a class="lt-tabs__link" href="#content-images">Ảnh (<?= e(count($images)) ?>)</a>
                <a class="lt-tabs__link" href="#content-itinerary">Lịch trình (<?= e(count($itinerary)) ?>)</a>
                <a class="lt-tabs__link" href="#content-inclusions">Dịch vụ (<?= e(count($inclusions)) ?>)</a>
                <a class="lt-tabs__link" href="#content-policy">Chính sách hủy</a>
<?php if (!$isHost): ?>
                <a class="lt-tabs__link" href="#content-delete"><?= $isArchived ? 'Hiển thị lại' : 'Xóa tour' ?></a>
<?php endif; ?>
            </nav>

            <!-- Ảnh -->
            <section class="lt-panel" id="content-images" aria-labelledby="images-title">
                <h2 class="lt-panel__title" id="images-title">Ảnh (<?= e(count($images)) ?>/<?= e(AdminTourContentModel::IMAGE_MAX) ?>)</h2>
<?php if ($images === []): ?>
                <p class="lt-empty">Tour chưa có ảnh. Trang tour sẽ hiện "Chưa cập nhật ảnh".</p>
<?php else: ?>
                <ul class="lt-thumbs">
<?php foreach ($images as $image): ?>
<?php $isCover = (int) $image['is_cover'] === 1; ?>
                    <li class="lt-thumb<?= $isCover ? ' is-cover' : '' ?>">
                        <img class="lt-thumb__img" src="<?= e(image_src((string) $image['url'])) ?>" alt="<?= e((string) $image['alt_text']) ?>" width="240" height="135" loading="lazy" decoding="async">
                        <p class="lt-thumb__caption"><?= $isCover ? '<span class="lt-badge lt-badge--approved">Ảnh bìa</span> ' : '' ?><?= e(or_missing($image['alt_text'] === null ? null : (string) $image['alt_text'])) ?></p>
                        <div class="lt-thumb__actions">
<?php if (!$isCover): ?>
                            <form action="<?= e(url($base . '/images/' . $image['image_id'] . '/cover')) ?>" method="post">
                                <?= csrf_field() ?>
                                <button class="lt-btn lt-btn--soft lt-btn--sm" type="submit">Đặt làm ảnh bìa</button>
                            </form>
<?php endif; ?>
                            <form action="<?= e(url($base . '/images/' . $image['image_id'] . '/delete')) ?>" method="post">
                                <?= csrf_field() ?>
                                <button class="lt-btn lt-btn--outline lt-btn--sm" type="submit">Xóa<span class="sr-only"> ảnh <?= e((string) $image['alt_text']) ?></span></button>
                            </form>
                        </div>
                    </li>
<?php endforeach; ?>
                </ul>
<?php endif; ?>

<?php if (count($images) < AdminTourContentModel::IMAGE_MAX): ?>
                <h3 class="lt-panel__subtitle">Thêm ảnh</h3>
                <form class="lt-admin-form" action="<?= e(url($base . '/images')) ?>" method="post" enctype="multipart/form-data" novalidate>
                    <?= csrf_field() ?>
                    <input type="hidden" name="MAX_FILE_SIZE" value="<?= e(AdminTourContentModel::IMAGE_MAX_BYTES) ?>">
                    <div class="row">
                        <div class="col-12 col-md-6">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="image-file">Tải ảnh lên</label>
                                <input class="lt-admin-input<?= $invalid('image_file') ?>" type="file" id="image-file" name="image_file" accept="image/jpeg,image/png,image/webp" aria-describedby="image-file-hint">
                                <p class="lt-admin-hint" id="image-file-hint">JPG, PNG hoặc WebP, tối đa <?= e($maxMb) ?> MB.</p>
<?php if ($fieldError('image_file') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('image_file')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                        <div class="col-12 col-md-6">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="image-url">Hoặc dán đường dẫn ảnh</label>
                                <input class="lt-admin-input<?= $invalid('image_url') ?>" type="url" id="image-url" name="image_url" value="<?= e($old['image_url']) ?>" maxlength="<?= e(AdminTourContentModel::ALT_MAX_LENGTH) ?>"
                                       placeholder="https://..." aria-describedby="image-url-hint">
                                <p class="lt-admin-hint" id="image-url-hint">Chỉ dùng khi không tải ảnh lên. Đường dẫn https của ảnh đã có trên mạng.</p>
<?php if ($fieldError('image_url') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('image_url')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                        <div class="col-12">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="image-alt">Mô tả ảnh</label>
                                <input class="lt-admin-input<?= $invalid('image_alt') ?>" type="text" id="image-alt" name="image_alt" value="<?= e($old['image_alt']) ?>" maxlength="<?= e(AdminTourContentModel::ALT_MAX_LENGTH) ?>"
                                       aria-describedby="image-alt-hint">
                                <p class="lt-admin-hint" id="image-alt-hint">Hiện dưới ảnh và đọc cho người dùng trình đọc màn hình. Để trống thì dùng tên tour.</p>
<?php if ($fieldError('image_alt') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('image_alt')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                    </div>
                    <button class="lt-btn lt-btn--primary" type="submit"><span class="lt-icon lt-icon--plus" aria-hidden="true"></span> Thêm ảnh</button>
                </form>
<?php endif; ?>
            </section>

            <!-- Lịch trình -->
            <section class="lt-panel" id="content-itinerary" aria-labelledby="itinerary-title">
                <h2 class="lt-panel__title" id="itinerary-title">Lịch trình (<?= e(count($itinerary)) ?>/<?= e(AdminTourContentModel::ITINERARY_MAX) ?>)</h2>
<?php if ($itinerary === []): ?>
                <p class="lt-empty">Tour chưa có lịch trình. Trang tour sẽ hiện "Chưa cập nhật".</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr><th scope="col" class="text-right">Thứ tự</th><th scope="col">Giờ</th><th scope="col">Nội dung</th><th scope="col"><span class="sr-only">Thao tác</span></th></tr>
                        </thead>
                        <tbody>
<?php foreach ($itinerary as $item): ?>
                            <tr>
                                <td class="text-right"><?= e((int) $item['sort_order']) ?></td>
                                <td><?= $item['start_time'] !== null ? e(substr((string) $item['start_time'], 0, 5)) : '<span class="lt-muted">Không ghi giờ</span>' ?></td>
                                <td class="lt-table__grow"><?= e($item['description']) ?></td>
                                <td class="text-right lt-table__actions">
                                    <a class="lt-btn lt-btn--soft lt-btn--sm" href="<?= e(url($base . '?edit_item=' . $item['item_id'])) ?>#itinerary-form-title">Sửa</a>
                                    <form action="<?= e(url($base . '/itinerary/' . $item['item_id'] . '/delete')) ?>" method="post">
                                        <?= csrf_field() ?>
                                        <button class="lt-btn lt-btn--outline lt-btn--sm" type="submit">Xóa</button>
                                    </form>
                                </td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>

                <h3 class="lt-panel__subtitle" id="itinerary-form-title"><?= $isEditItem ? 'Sửa mục lịch trình' : 'Thêm mục lịch trình' ?></h3>
                <form class="lt-admin-form" action="<?= e(url($base . '/itinerary')) ?>" method="post" novalidate>
                    <?= csrf_field() ?>
                    <input type="hidden" name="item_id" value="<?= e($old['item_id']) ?>">
                    <div class="row">
                        <div class="col-6 col-md-3">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="item-time">Giờ</label>
                                <input class="lt-admin-input<?= $invalid('item_time') ?>" type="time" id="item-time" name="item_time" value="<?= e($old['item_time']) ?>" aria-describedby="item-time-hint">
                                <p class="lt-admin-hint" id="item-time-hint">Để trống nếu không ghi giờ.</p>
<?php if ($fieldError('item_time') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('item_time')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                        <div class="col-6 col-md-3">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="item-sort">Thứ tự</label>
                                <input class="lt-admin-input<?= $invalid('item_sort') ?>" type="number" id="item-sort" name="item_sort" value="<?= e($old['item_sort']) ?>" min="0" max="<?= e(AdminTourContentModel::SORT_MAX) ?>" step="1" aria-describedby="item-sort-hint">
                                <p class="lt-admin-hint" id="item-sort-hint">Để trống = cuối danh sách.</p>
<?php if ($fieldError('item_sort') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('item_sort')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                        <div class="col-12 col-md-6">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="item-description">Nội dung</label>
                                <input class="lt-admin-input<?= $invalid('item_description') ?>" type="text" id="item-description" name="item_description" value="<?= e($old['item_description']) ?>"
                                       maxlength="<?= e(AdminTourContentModel::ITINERARY_TEXT_MAX_LENGTH) ?>" required>
<?php if ($fieldError('item_description') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('item_description')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                    </div>
                    <button class="lt-btn lt-btn--primary" type="submit"><?= $isEditItem ? 'Lưu mục' : 'Thêm mục' ?></button>
<?php if ($isEditItem): ?>
                    <a class="lt-btn lt-btn--outline" href="<?= e(url($base)) ?>#content-itinerary">Hủy sửa</a>
<?php endif; ?>
                </form>
            </section>

            <!-- Dịch vụ bao gồm / không bao gồm -->
            <section class="lt-panel" id="content-inclusions" aria-labelledby="inclusions-title">
                <h2 class="lt-panel__title" id="inclusions-title">Dịch vụ (<?= e(count($inclusions)) ?>/<?= e(AdminTourContentModel::INCLUSION_MAX) ?>)</h2>
                <div class="row">
<?php foreach (['Đã bao gồm' => $included, 'Không bao gồm' => $excluded] as $groupLabel => $groupItems): ?>
                    <div class="col-12 col-md-6">
                        <h3 class="lt-panel__subtitle"><?= e($groupLabel) ?></h3>
<?php if ($groupItems === []): ?>
                        <p class="lt-empty">Chưa có.</p>
<?php else: ?>
                        <ul class="lt-plain-list">
<?php foreach ($groupItems as $inclusion): ?>
                            <li>
                                <span><?= e($inclusion['item_text']) ?></span>
                                <form action="<?= e(url($base . '/inclusions/' . $inclusion['inclusion_id'] . '/delete')) ?>" method="post">
                                    <?= csrf_field() ?>
                                    <button class="lt-btn lt-btn--outline lt-btn--sm" type="submit">Xóa<span class="sr-only"> <?= e($inclusion['item_text']) ?></span></button>
                                </form>
                            </li>
<?php endforeach; ?>
                        </ul>
<?php endif; ?>
                    </div>
<?php endforeach; ?>
                </div>

                <h3 class="lt-panel__subtitle">Thêm dịch vụ</h3>
                <form class="lt-admin-form" action="<?= e(url($base . '/inclusions')) ?>" method="post" novalidate>
                    <?= csrf_field() ?>
                    <div class="row">
                        <div class="col-12 col-md-7">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="inclusion-text">Tên dịch vụ</label>
                                <input class="lt-admin-input<?= $invalid('inclusion_text') ?>" type="text" id="inclusion-text" name="inclusion_text" value="<?= e($old['inclusion_text']) ?>"
                                       maxlength="<?= e(AdminTourContentModel::INCLUSION_TEXT_MAX_LENGTH) ?>" required placeholder="Ví dụ: Vé tham quan, Nước uống">
<?php if ($fieldError('inclusion_text') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('inclusion_text')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                        <div class="col-12 col-md-5">
                            <fieldset class="lt-admin-field">
                                <legend class="lt-admin-label">Loại</legend>
<?php foreach (['1' => 'Đã bao gồm', '0' => 'Không bao gồm'] as $value => $label): ?>
                                <div class="custom-control custom-radio custom-control-inline">
                                    <input class="custom-control-input" type="radio" id="inclusion-included-<?= e($value) ?>" name="inclusion_included" value="<?= e($value) ?>"<?= $old['inclusion_included'] === (string) $value ? ' checked' : '' ?>>
                                    <label class="custom-control-label" for="inclusion-included-<?= e($value) ?>"><?= e($label) ?></label>
                                </div>
<?php endforeach; ?>
                            </fieldset>
                        </div>
                    </div>
                    <button class="lt-btn lt-btn--primary" type="submit"><span class="lt-icon lt-icon--plus" aria-hidden="true"></span> Thêm dịch vụ</button>
                </form>
            </section>

            <!-- Chính sách hủy -->
            <section class="lt-panel" id="content-policy" aria-labelledby="policy-title">
                <h2 class="lt-panel__title" id="policy-title">Chính sách hủy</h2>
                <p class="lt-admin__text">Mỗi lần sửa là một phiên bản mới. Đơn đã đặt giữ phiên bản lúc đặt; khách đặt sau dùng phiên bản mới nhất.</p>
<?php if ($policies === []): ?>
                <p class="lt-empty">Tour chưa có chính sách hủy. Trang tour sẽ hiện "Chưa cập nhật".</p>
<?php else: ?>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr><th scope="col">Phiên bản</th><th scope="col">Nội dung</th><th scope="col" class="text-right">Đơn áp dụng</th></tr>
                        </thead>
                        <tbody>
<?php foreach ($policies as $index => $policy): ?>
                            <tr>
                                <td><?= e((int) $policy['version']) ?><?= $index === 0 ? ' <span class="lt-badge lt-badge--open">Đang dùng</span>' : '' ?></td>
                                <td class="lt-table__grow">
                                    <?= e(implode(' ', cancellation_policy_lines($policy['free_before_hours'], $policy['refund_percent']))) ?>
<?php if ($policy['terms'] !== null && trim((string) $policy['terms']) !== ''): ?>
                                    <span class="lt-table__sub"><?= nl2br(e($policy['terms'])) ?></span>
<?php endif; ?>
                                </td>
                                <td class="text-right"><?= e((int) $policy['booking_count']) ?></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>

                <h3 class="lt-panel__subtitle">Thêm phiên bản mới</h3>
                <form class="lt-admin-form" action="<?= e(url($base . '/policy')) ?>" method="post" novalidate>
                    <?= csrf_field() ?>
                    <div class="row">
                        <div class="col-6 col-md-4">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="policy-hours">Hủy miễn phí trước (giờ)</label>
                                <input class="lt-admin-input<?= $invalid('policy_hours') ?>" type="number" id="policy-hours" name="policy_hours" value="<?= e($old['policy_hours']) ?>" min="0" max="<?= e(AdminTourContentModel::POLICY_HOURS_MAX) ?>" step="1" aria-describedby="policy-hours-hint">
                                <p class="lt-admin-hint" id="policy-hours-hint">Ví dụ 24. Để trống nếu không có mốc hủy miễn phí.</p>
<?php if ($fieldError('policy_hours') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('policy_hours')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                        <div class="col-6 col-md-4">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="policy-percent">Hoàn sau mốc đó (%)</label>
                                <input class="lt-admin-input<?= $invalid('policy_percent') ?>" type="number" id="policy-percent" name="policy_percent" value="<?= e($old['policy_percent']) ?>" min="0" max="100" step="1" required aria-describedby="policy-percent-hint">
                                <p class="lt-admin-hint" id="policy-percent-hint">0 = không hoàn tiền.</p>
<?php if ($fieldError('policy_percent') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('policy_percent')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                        <div class="col-12">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="policy-terms">Nội dung chính sách cho khách</label>
                                <textarea class="lt-admin-input<?= $invalid('policy_terms') ?>" id="policy-terms" name="policy_terms" rows="3" maxlength="<?= e(AdminTourContentModel::POLICY_TERMS_MAX_LENGTH) ?>" required
                                          aria-describedby="policy-terms-hint"><?= e($old['policy_terms']) ?></textarea>
                                <p class="lt-admin-hint" id="policy-terms-hint">Khách đọc ở trang tour và trang đơn. Ví dụ: Hủy miễn phí nếu báo trước giờ khởi hành ít nhất 24 giờ; sau mốc này hoàn 50%.</p>
<?php if ($fieldError('policy_terms') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('policy_terms')) ?></p>
<?php endif; ?>
                            </div>
                        </div>
                    </div>
                    <button class="lt-btn lt-btn--primary" type="submit">Lưu phiên bản mới</button>
                </form>
            </section>

<?php if (!$isHost): ?>
            <!-- Xóa tour / ngừng hiển thị (chỉ quản trị viên) -->
            <section class="lt-panel lt-panel--danger" id="content-delete" aria-labelledby="delete-title">
<?php if ($isArchived): ?>
                <h2 class="lt-panel__title" id="delete-title">Hiển thị lại tour</h2>
                <p class="lt-admin__text">Tour đang ngừng hiển thị. Hiển thị lại sẽ chuyển tour về "Chờ duyệt"; phê duyệt lại để khách thấy tour.</p>
                <form action="<?= e(url('/admin/tours/' . $tourId . '/restore')) ?>" method="post" class="lt-admin-form">
                    <?= csrf_field() ?>
                    <button class="lt-btn lt-btn--primary" type="submit">Chuyển về Chờ duyệt</button>
                </form>
<?php else: ?>
                <h2 class="lt-panel__title" id="delete-title">Xóa tour</h2>
                <p class="lt-admin__text">Tour chưa có đơn nào sẽ bị xóa hẳn (cả lịch, giá, ảnh, lịch trình). Tour đã có đơn sẽ chuyển sang "Ngừng hiển thị" để giữ lịch sử đơn.
                    Không xóa được khi còn đơn đang chờ xác nhận, chờ thanh toán hoặc đã xác nhận.</p>
                <form action="<?= e(url('/admin/tours/' . $tourId . '/delete')) ?>" method="post" class="lt-admin-form">
                    <?= csrf_field() ?>
                    <div class="custom-control custom-checkbox lt-admin-field">
                        <input class="custom-control-input<?= $invalid('confirm') ?>" type="checkbox" id="delete-confirm" name="confirm" value="1" required>
                        <label class="custom-control-label" for="delete-confirm">Tôi hiểu tour sẽ bị xóa hoặc ngừng hiển thị với khách.</label>
<?php if ($fieldError('confirm') !== ''): ?>
                        <p class="lt-admin-error"><?= e($fieldError('confirm')) ?></p>
<?php endif; ?>
                    </div>
                    <button class="lt-btn lt-btn--danger" type="submit"><span class="lt-icon lt-icon--x" aria-hidden="true"></span> Xóa tour</button>
                </form>
<?php endif; ?>
            </section>
<?php endif; ?>
        </main>
    </div>
</div>
