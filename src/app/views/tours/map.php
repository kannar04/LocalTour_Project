<?php declare(strict_types=1); ?>
<?php
/*
 * Bản đồ tour /ban-do (Nguyễn Tuấn Khôi): điểm khởi hành của mọi tour đang hiển thị có vị trí. Bấm ghim trên bản đồ
 * hoặc nút trong danh sách để xem quán ăn, bar, giải trí, quán nước quanh điểm đó (tour-map.js, data-mode="all")
 * và link sang trang tour.
 * Biến: $points (TourMapController::pointData() + destination, category, duration, image, imageAlt),
 *       $selectedId (tour chọn sẵn từ ?tour=, null = chưa chọn), $mapReady (false = chưa chạy file 23), $title.
 */
use App\Services\NearbyPlaces;

$listUrl = url('/tours');
$count = count($points);
$mapRadius = (int) ((require BASE_PATH . '/config/map.php')['radius_m']);
$radiusText = number_format($mapRadius / 1000, 1, ',', '') . ' km';
$mapJson = json_encode(['tours' => $points, 'selected' => $selectedId], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: 'null';
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-tmap" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e($listUrl) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item active" aria-current="page">Bản đồ</li>
            </ol>
        </nav>

        <div class="lt-tmap-head">
            <h1 class="lt-tmap-head__title">Bản đồ tour</h1>
            <p class="lt-tmap-head__lead">Điểm khởi hành của các tour đang mở bán. Chọn một tour để xem quán ăn, bar, chỗ giải trí và quán nước trong bán kính <?= e($radiusText) ?>.</p>
        </div>

<?php if (!$mapReady || $count === 0): ?>
        <section class="lt-detail-card lt-tmap-empty" aria-labelledby="tmap-empty-title">
            <span class="lt-tmap-empty__icon" aria-hidden="true"><span class="lt-icon lt-icon--map"></span></span>
            <h2 class="lt-tmap-empty__title" id="tmap-empty-title"><?= $mapReady ? 'Chưa có tour nào có vị trí trên bản đồ' : 'Bản đồ tour đang tạm ngưng' ?></h2>
            <p class="lt-tmap-empty__text"><?= $mapReady
                ? 'Đơn vị tổ chức chưa đặt vị trí điểm khởi hành cho tour nào. Bạn vẫn xem được điểm hẹn trong trang của từng tour.'
                : 'Bản đồ chưa sẵn sàng, vui lòng quay lại sau. Bạn vẫn xem được điểm hẹn trong trang của từng tour.' ?></p>
            <a class="lt-btn lt-btn--primary" href="<?= e($listUrl) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Về bảng tin
            </a>
        </section>
<?php else: ?>
<?php require __DIR__ . '/../partials/leaflet.php'; ?>
        <script type="application/json" class="js-map-data"><?= $mapJson ?></script>
        <div class="row lt-tmap-body">
            <div class="col-12 col-lg-8 lt-tmap-main">
                <div class="lt-detail-card lt-tmap-card">
                    <div class="lt-map lt-map--tall js-places-map" data-mode="all">
                        <div class="lt-map__canvas js-map-canvas" role="region" aria-label="Bản đồ điểm khởi hành của <?= e($count) ?> tour"></div>
                        <p class="lt-map__notice js-map-notice" hidden></p>
                    </div>
                </div>

                <section class="lt-detail-card lt-section lt-map-places js-map-places" aria-labelledby="tmap-places-title">
                    <p class="lt-empty-note js-map-pick-hint">Bấm một ghim trên bản đồ hoặc chọn tour trong danh sách để xem địa điểm xung quanh điểm khởi hành.</p>
                    <div class="js-map-selected" hidden>
                        <h2 class="lt-section__title" id="tmap-places-title">Quanh điểm khởi hành: <span class="js-map-tour-title"></span></h2>
                        <p class="lt-map-departure">
                            <span class="lt-icon lt-icon--pin" aria-hidden="true"></span>
                            <span class="js-map-tour-departure"></span>
                        </p>
                        <div class="lt-map-filters js-map-filters" role="group" aria-label="Hiện / ẩn loại địa điểm">
<?php foreach (NearbyPlaces::GROUPS as $groupKey => $groupLabel): ?>
                            <button type="button" class="lt-map-chip lt-map-chip--<?= e($groupKey) ?> js-map-toggle" data-group="<?= e($groupKey) ?>" aria-pressed="true" disabled>
                                <span class="lt-map-chip__dot" aria-hidden="true"></span>
                                <span><?= e($groupLabel) ?></span>
                                <span class="lt-map-chip__count js-map-count" aria-label="số địa điểm">…</span>
                            </button>
<?php endforeach; ?>
                        </div>
                        <p class="lt-map-status js-map-status" role="status" aria-live="polite"></p>
                        <div class="lt-map-lists js-map-lists"></div>
                        <a class="lt-btn lt-btn--primary js-map-tour-link" href="<?= e($listUrl) ?>">
                            Xem chi tiết tour
                        </a>
                    </div>
                    <p class="lt-map-credit">Dữ liệu địa điểm và nền bản đồ © <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap contributors</a>, tra qua Overpass API; khoảng cách tính theo đường chim bay. Thông tin có thể chưa đầy đủ, nên kiểm tra trước khi đến.</p>
                </section>
            </div>

            <div class="col-12 col-lg-4">
                <section class="lt-detail-card lt-tmap-list" aria-labelledby="tmap-list-title">
                    <h2 class="lt-tmap-list__title" id="tmap-list-title">Tour trên bản đồ (<?= e($count) ?>)</h2>
                    <ul class="lt-tmap-list__items">
<?php foreach ($points as $point): ?>
                        <li class="lt-tmap-tour">
                            <button type="button" class="lt-tmap-tour__select js-map-tour" data-tour-id="<?= e($point['id']) ?>" aria-pressed="false">
<?php if ($point['image'] !== ''): ?>
                                <img class="lt-tmap-tour__image" src="<?= e($point['image']) ?>" alt="" loading="lazy" width="64" height="48">
<?php else: ?>
                                <span class="lt-tmap-tour__image lt-tmap-tour__image--empty" aria-hidden="true"><span class="lt-icon lt-icon--image"></span></span>
<?php endif; ?>
                                <span class="lt-tmap-tour__body">
                                    <span class="lt-tmap-tour__title"><?= e($point['title']) ?></span>
                                    <span class="lt-tmap-tour__meta"><?= e($point['destination']) ?> · <?= e($point['duration']) ?></span>
                                    <span class="lt-tmap-tour__meta"><?= e($point['departure']) ?></span>
                                </span>
                            </button>
                            <a class="lt-tmap-tour__link" href="<?= e($point['url']) ?>">Xem tour<span class="sr-only"> <?= e($point['title']) ?></span></a>
                        </li>
<?php endforeach; ?>
                    </ul>
                </section>
            </div>
        </div>
<?php endif; ?>
    </div>
</main>
