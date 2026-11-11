<?php declare(strict_types=1); ?>
<?php
/*
 * Mục "Bản đồ và địa điểm quanh điểm khởi hành" của trang chi tiết tour (Nguyễn Tuấn Khôi).
 * Chỉ được nạp khi tour có vị trí ($mapPoint từ TourLocationModel::point()).
 * tour-map.js dựng bản đồ Leaflet (nền OpenStreetMap), tải /api/tours/{id}/places rồi điền nút lọc và danh sách
 * từng nhóm; không có JS / Leaflet thì vẫn còn dòng điểm khởi hành và link mở bản đồ lớn.
 */
use App\Controllers\TourMapController;
use App\Services\NearbyPlaces;

$mapData = TourMapController::pointData($mapPoint);
$mapJson = json_encode($mapData, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: 'null';
$mapRadius = (int) ((require BASE_PATH . '/config/map.php')['radius_m']);
?>
                <section class="lt-section" id="ban-do" tabindex="-1" aria-labelledby="ban-do-title">
                    <h2 class="lt-section__title" id="ban-do-title">Bản đồ và địa điểm quanh điểm khởi hành</h2>
                    <p class="lt-map-departure">
                        <span class="lt-icon lt-icon--pin" aria-hidden="true"></span>
                        <span><?= e($mapData['departure']) ?></span>
                    </p>
<?php if ($mapData['isPickup']): ?>
                    <p class="lt-empty-note">Tour đón tại khách sạn: điểm trên bản đồ là khu vực đón, không phải địa chỉ khách sạn của bạn.</p>
<?php endif; ?>
<?php require __DIR__ . '/../partials/leaflet.php'; ?>
                    <div class="lt-map js-places-map" data-mode="tour">
                        <div class="lt-map__canvas js-map-canvas" role="region" aria-label="Bản đồ điểm khởi hành và địa điểm xung quanh"></div>
                        <p class="lt-map__notice js-map-notice" hidden></p>
                    </div>
                    <script type="application/json" class="js-map-data"><?= $mapJson ?></script>

                    <div class="lt-map-places js-map-places" aria-labelledby="ban-do-places-title">
                        <h3 class="lt-subheading" id="ban-do-places-title">Trong bán kính <?= e(number_format($mapRadius / 1000, 1, ',', '')) ?> km</h3>
                        <div class="lt-map-filters js-map-filters" role="group" aria-label="Hiện / ẩn loại địa điểm">
<?php foreach (NearbyPlaces::GROUPS as $groupKey => $groupLabel): ?>
                            <button type="button" class="lt-map-chip lt-map-chip--<?= e($groupKey) ?> js-map-toggle" data-group="<?= e($groupKey) ?>" aria-pressed="true" disabled>
                                <span class="lt-map-chip__dot" aria-hidden="true"></span>
                                <span><?= e($groupLabel) ?></span>
                                <span class="lt-map-chip__count js-map-count" aria-label="số địa điểm">…</span>
                            </button>
<?php endforeach; ?>
                        </div>
                        <p class="lt-map-status js-map-status" role="status" aria-live="polite">Đang tải địa điểm quanh điểm khởi hành…</p>
                        <div class="lt-map-lists js-map-lists"></div>
                        <p class="lt-map-credit">Dữ liệu địa điểm và nền bản đồ © <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap contributors</a>, tra qua Overpass API; khoảng cách tính theo đường chim bay. Thông tin có thể chưa đầy đủ, nên kiểm tra trước khi đến.</p>
                        <a class="lt-btn lt-btn--outline" href="<?= e(url('/ban-do') . '?tour=' . rawurlencode($mapData['id'])) ?>">
                            <span class="lt-icon lt-icon--map" aria-hidden="true"></span>
                            Xem bản đồ tất cả tour
                        </a>
                    </div>
                </section>

