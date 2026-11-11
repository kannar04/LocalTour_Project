<?php declare(strict_types=1); ?>
<?php
/*
 * Điểm khởi hành trên bản đồ (Nguyễn Tuấn Khôi): quản trị viên nhập vĩ độ / kinh độ hoặc bấm lên bản đồ để đặt
 * điểm khởi hành của tour (điểm hẹn, hoặc khu vực đón với tour đón tại khách sạn), hoặc xóa vị trí.
 * Biến: $tour (NTK_sp_admin_tour_location; null khi chưa chạy file 23), $old (latitude, longitude),
 *       $errors (theo ô; 'form' = lỗi chung), $success, $ready (false = chưa chạy database/23_map_places_NTK.sql).
 * tour-map.js (data-mode="pick"): bấm bản đồ / kéo ghim để điền hai ô; không tải được bản đồ thì vẫn nhập tay được.
 */
$fieldError = static fn (string $field): string => $errors[$field] ?? '';
$invalid = static fn (string $field): string => isset($errors[$field]) ? ' is-invalid' : '';
$coord = static fn (mixed $value): string => rtrim(rtrim((string) $value, '0'), '.');
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
<?php if (!$ready || $tour === null): ?>
            <a class="lt-admin__back" href="<?= e(url('/admin/tours')) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Danh sách tour
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Điểm khởi hành trên bản đồ</h1>
            </header>
            <div class="lt-alert lt-alert--warning" role="status">
                <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                <span>Bản đồ tour chưa sẵn sàng: cơ sở dữ liệu chưa có cột vị trí. Chạy file <code>database/23_map_places_NTK.sql</code> rồi tải lại trang.</span>
            </div>
<?php else: ?>
<?php
    $tourId = (string) $tour['tour_id'];
    $isPickup = $tour['pickup_mode'] === 'hotel_pickup';
    $meetingPoint = (string) $tour['meeting_point'];
    $hasLocation = $tour['latitude'] !== null && $tour['longitude'] !== null;
    $searchUrl = 'https://www.openstreetmap.org/search?query=' . rawurlencode(trim($meetingPoint . ', ' . $tour['destination_name'], ', '));
?>
            <a class="lt-admin__back" href="<?= e(url('/admin/tours/' . $tourId)) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Chi tiết tour
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Điểm khởi hành trên bản đồ</h1>
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
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Chưa lưu được: vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-8">
                    <section class="lt-panel" aria-labelledby="location-form-title">
                        <h2 class="lt-panel__title" id="location-form-title">Vị trí trên bản đồ</h2>
                        <form class="lt-admin-form" action="<?= e(url('/admin/tours/' . $tourId . '/location')) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
                            <div class="row">
                                <div class="col-12 col-sm-6">
                                    <div class="lt-admin-field">
                                        <label class="lt-admin-label" for="location-latitude">Vĩ độ</label>
                                        <input class="lt-admin-input<?= $invalid('latitude') ?>" type="text" inputmode="decimal" autocomplete="off" id="location-latitude" name="latitude"
                                               value="<?= e($old['latitude']) ?>" maxlength="16" placeholder="21.0285" aria-describedby="location-hint<?= $fieldError('latitude') !== '' ? ' location-latitude-error' : '' ?>">
<?php if ($fieldError('latitude') !== ''): ?>
                                        <p class="lt-admin-error" id="location-latitude-error"><?= e($fieldError('latitude')) ?></p>
<?php endif; ?>
                                    </div>
                                </div>
                                <div class="col-12 col-sm-6">
                                    <div class="lt-admin-field">
                                        <label class="lt-admin-label" for="location-longitude">Kinh độ</label>
                                        <input class="lt-admin-input<?= $invalid('longitude') ?>" type="text" inputmode="decimal" autocomplete="off" id="location-longitude" name="longitude"
                                               value="<?= e($old['longitude']) ?>" maxlength="16" placeholder="105.8542" aria-describedby="location-hint<?= $fieldError('longitude') !== '' ? ' location-longitude-error' : '' ?>">
<?php if ($fieldError('longitude') !== ''): ?>
                                        <p class="lt-admin-error" id="location-longitude-error"><?= e($fieldError('longitude')) ?></p>
<?php endif; ?>
                                    </div>
                                </div>
                            </div>
                            <p class="lt-admin-hint" id="location-hint">
                                Bấm lên bản đồ để đặt điểm hoặc kéo ghim cho đúng chỗ, hai ô sẽ tự điền. Tọa độ phải trong khung Việt Nam
                                (vĩ độ 8 – 23,5; kinh độ 102 – 110).
                                Để trống cả hai ô rồi bấm "Lưu vị trí" cũng là xóa vị trí.
                            </p>

<?php require __DIR__ . '/../../partials/leaflet.php'; ?>
                            <div class="lt-map lt-map--pick js-places-map" data-mode="pick">
                                <div class="lt-map__canvas js-map-canvas" role="region" aria-label="Bản đồ chọn điểm khởi hành: bấm để đặt điểm"></div>
                                <p class="lt-map__notice js-map-notice" hidden></p>
                            </div>
                            <p class="lt-admin-hint lt-map-pick-status js-map-status" role="status" aria-live="polite"></p>

                            <div class="lt-map-pick-actions">
                                <button class="lt-btn lt-btn--primary" type="submit" name="intent" value="save">
                                    <span class="lt-icon lt-icon--check" aria-hidden="true"></span> Lưu vị trí
                                </button>
<?php if ($hasLocation): ?>
                                <button class="lt-btn lt-btn--outline" type="submit" name="intent" value="clear">
                                    <span class="lt-icon lt-icon--x" aria-hidden="true"></span> Xóa vị trí
                                </button>
<?php endif; ?>
                            </div>
                        </form>
                    </section>
                </div>

                <div class="col-12 col-xl-4">
                    <section class="lt-panel" aria-labelledby="location-info-title">
                        <h2 class="lt-panel__title" id="location-info-title">Điểm khởi hành</h2>
                        <dl class="lt-fields">
                            <dt>Điểm đến</dt>
                            <dd><?= e($tour['destination_name']) ?></dd>
                            <dt>Cách đón</dt>
                            <dd><?= $isPickup ? 'Đón tại khách sạn' : 'Gặp tại điểm hẹn' ?></dd>
                            <dt><?= $isPickup ? 'Khu vực đón' : 'Điểm hẹn' ?></dt>
                            <dd><?= e(or_missing($meetingPoint)) ?></dd>
                            <dt>Vị trí đã lưu</dt>
                            <dd><?= $hasLocation ? e($coord($tour['latitude']) . ', ' . $coord($tour['longitude'])) : 'Chưa đặt (trang tour không hiện bản đồ)' ?></dd>
                        </dl>
                        <p class="lt-admin-hint">
<?php if ($isPickup): ?>
                            Tour đón tại khách sạn: đặt điểm ở giữa khu vực đón. Trang tour ghi rõ đây là khu vực đón, không phải khách sạn của khách.
<?php else: ?>
                            Đặt điểm đúng chỗ khách gặp hướng dẫn viên. Trang tour hiện quán ăn, bar, giải trí và quán nước trong bán kính 1,5 km quanh điểm này.
<?php endif; ?>
                        </p>
                        <p class="lt-admin-hint">
                            <a href="<?= e($searchUrl) ?>" target="_blank" rel="noopener">Tìm "<?= e(or_missing($meetingPoint)) ?>" trên OpenStreetMap</a>
                            (mở tab mới; chép tọa độ trên thanh địa chỉ vào hai ô).
                        </p>
                    </section>
                </div>
            </div>
<?php endif; ?>
        </main>
    </div>
</div>
