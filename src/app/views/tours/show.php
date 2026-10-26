<?php declare(strict_types=1); ?>
<?php
/*
 * Chi tiết tour (UIEx2, Nguyễn Tuấn Khôi) – render phía server, tour-detail.js chỉ xử lý thẻ giá và tab neo.
 * Biến: $tour (NMT_sp_tour_detail, gồm destination_id/destination_name, category_id/category_name, transport,
 *       guide_info, dropoff_point, document_terms, meal_terms, voucher_terms, reschedule_terms),
 *       $schedules (lịch còn đặt được), $tickets (vé đang bán của các lịch đó),
 *       $itinerary (mục lịch trình theo sort_order: [{item_id, start_time, time_text, description}]),
 *       $inclusions (['included' => [...], 'excluded' => [...]]), $extras (phụ thu / hoạt động tùy chọn, phụ thu trước),
 *       $reviews (tối đa 5, mới nhất trước), $policy (null hoặc chính sách hủy mới nhất),
 *       $gallery (ảnh của chính tour: [{url, caption}], có thể rỗng), $title.
 * Dữ liệu thiếu hiển thị "Chưa cập nhật" (FR-01..05), không lấy từ tour khác và không tự suy diễn.
 * Thẻ đặt tour là form GET tới /tours/{id}/book (trang "Hoàn tất thông tin đặt tour") kèm lịch và số khách đã chọn.
 * Chế độ khách: nút "Đăng nhập để đặt tour" (đăng nhập xong vào thẳng trang đặt tour với lựa chọn hiện tại).
 * Tài khoản khách hàng: nút "Đặt tour". Thích / Bình luận / Chia sẻ / Lưu tour / So sánh: sắp có.
 */
$missing = or_missing(null);

/** Văn bản mỗi dòng một mục (vd. meal_terms) → các dòng; trống → ["Chưa cập nhật"]. */
$linesOrMissing = static function (?string $text) use ($missing): array {
    $lines = text_lines($text);

    return $lines !== [] ? $lines : [$missing];
};
$listUrl = url('/tours');
$tourPath = '/tours/' . $tour['tour_id'];
$isGuest = current_user() === null;
$isCustomer = (current_user()['role'] ?? '') === 'customer';
$bookPath = $tourPath . '/book';
$loginUrl = url('/login') . '?next=' . rawurlencode($bookPath);
// Điểm đến / loại hình: link lọc bảng tin theo ID; tour chưa gán ID thì chỉ hiện tên (hoặc "Chưa cập nhật").
$destination = trim((string) $tour['destination_name']);
$destinationId = $tour['destination_id'] === null ? null : (string) $tour['destination_id'];
$destinationUrl = $destinationId === null ? null : url('/tours?destination_id=' . rawurlencode($destinationId));
$categoryName = trim((string) ($tour['category_name'] ?? ''));
$categoryUrl = $tour['category_id'] === null ? null : url('/tours?category_id=' . rawurlencode((string) $tour['category_id']));
$ratingText = format_rating($tour['rating_avg']);
$reviewCount = (int) $tour['review_count'];
$priceText = $tour['from_price_vnd'] === null ? null : format_vnd((int) $tour['from_price_vnd']);
$maxGroup = max(1, (int) $tour['max_group_size']);
$hasSchedules = !empty($schedules);
$providerName = (string) $tour['provider_name'];
$providerInitial = mb_strtoupper(mb_substr($providerName, 0, 1));
$providerSince = format_date($tour['provider_approved_at'] === null ? null : (string) $tour['provider_approved_at']);
$isHotelPickup = $tour['pickup_mode'] === 'hotel_pickup';
$meetingPoint = trim((string) ($tour['meeting_point'] ?? ''));

// Đoạn đầu của mô tả làm câu dẫn, các đoạn sau là nội dung.
$paragraphs = text_paragraphs((string) $tour['description']);
$leadParagraph = array_shift($paragraphs);
$includedItems = $inclusions['included'];
$excludedItems = $inclusions['excluded'];

// Phụ thu / hoạt động tùy chọn (FR-04, FR-10): giá tách riêng, không bao giờ cộng vào giá tour hay tạm tính.
$extraGroups = [
    'surcharge' => ['title' => 'Phụ thu', 'items' => []],
    'optional' => ['title' => 'Hoạt động tùy chọn', 'items' => []],
];
foreach ($extras as $extra) {
    $extraKind = (string) $extra['kind'];
    if (!isset($extraGroups[$extraKind])) {
        continue;
    }
    $extraUnit = trim((string) ($extra['price_unit'] ?? ''));
    $extraGroups[$extraKind]['items'][] = [
        'name' => (string) $extra['name'],
        'price' => $extra['price_vnd'] === null
            ? 'Giá: ' . $missing
            : format_vnd($extra['price_vnd']) . ($extraUnit !== '' ? ' / ' . $extraUnit : ' · đơn vị chưa cập nhật'),
        'priceMissing' => $extra['price_vnd'] === null,
        'conditions' => trim((string) ($extra['conditions'] ?? '')),
    ];
}

// Thư viện ảnh: tối đa 3 ảnh đầu của tour; bố cục đổi theo số ảnh.
$galleryImages = array_slice(array_values($gallery), 0, 3);
$galleryLayout = ['lt-gallery--empty', 'lt-gallery--single', 'lt-gallery--pair', ''][count($galleryImages)];

// Thông tin tour (FR-02).
$departureLines = [departure_text((string) $tour['pickup_mode'], $meetingPoint)];
if ($isHotelPickup && $meetingPoint !== '') {
    $departureLines[] = 'Khu vực đón: ' . $meetingPoint;
}
$infoRows = [
    'Điểm đến' => [or_missing($destination)],
    'Loại hình' => [or_missing($categoryName)],
    'Nơi khởi hành / điểm đón' => $departureLines,
    'Điểm trả' => [or_missing($tour['dropoff_point'])],
    'Phương tiện' => [or_missing($tour['transport'])],
    'Hướng dẫn viên' => [or_missing($tour['guide_info'])],
    'Ngôn ngữ hướng dẫn' => [or_missing(format_languages($tour['language_codes'] === null ? null : (string) $tour['language_codes']))],
    'Thời lượng' => [format_duration($tour['duration_minutes'])],
    'Số khách tối đa' => [$maxGroup . ' khách'],
];

/** "17:00 – 21:00"; thêm ngày kết thúc nếu tour qua ngày hôm sau. */
$scheduleTime = static function (array $schedule): string {
    $start = (string) $schedule['starts_at'];
    $end = (string) $schedule['ends_at'];
    $text = format_time($start) . ' – ' . format_time($end);
    if ($end !== '' && substr($end, 0, 10) !== substr($start, 0, 10)) {
        $text .= ' (' . format_date($end) . ')';
    }

    return $text;
};

// Dữ liệu cho tour-detail.js: mỗi lịch kèm các loại vé để dựng hàng chọn số khách.
// Đồng thời gom độ tuổi theo loại vé cho mục "Điều kiện & chính sách" (bỏ trùng giữa các lịch).
$ticketsBySchedule = [];
$ageLines = [];
foreach ($tickets as $ticket) {
    $ticketLabel = ticket_label((string) $ticket['name']);
    $ticketAges = age_range_text($ticket['min_age'], $ticket['max_age']);
    $ticketsBySchedule[(string) $ticket['schedule_id']][] = [
        'id' => (string) $ticket['ticket_type_id'],
        'label' => $ticketLabel,
        'ages' => $ticketAges,
        'price' => (int) $ticket['price_vnd'],
    ];
    if ($ticketAges !== '') {
        $ageLines[$ticketLabel . ': ' . $ticketAges] = true;
    }
}
$ageLines = array_keys($ageLines);
$bookingData = ['maxGroup' => $maxGroup, 'schedules' => []];
foreach ($schedules as $schedule) {
    $scheduleId = (string) $schedule['schedule_id'];
    $bookingData['schedules'][] = [
        'id' => $scheduleId,
        'timeText' => $scheduleTime($schedule),
        'remaining' => (int) $schedule['remaining'],
        'tickets' => $ticketsBySchedule[$scheduleId] ?? [],
    ];
}
$bookingJson = json_encode($bookingData, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE) ?: 'null';

// Chính sách hủy (phiên bản mới nhất).
$policyLines = [];
$policyTerms = [];
if ($policy !== null) {
    $freeHours = $policy['free_before_hours'] === null ? null : (int) $policy['free_before_hours'];
    $refundPercent = (int) $policy['refund_percent'];
    if ($freeHours !== null) {
        $policyLines[] = $freeHours > 0
            ? 'Hủy miễn phí trước giờ khởi hành ' . $freeHours . ' giờ.'
            : 'Hủy miễn phí đến giờ khởi hành.';
        $policyLines[] = $refundPercent > 0
            ? 'Sau thời điểm này hoàn ' . $refundPercent . '% tiền tour.'
            : 'Sau thời điểm này không hoàn tiền.';
    } else {
        $policyLines[] = $refundPercent > 0
            ? 'Hủy tour được hoàn ' . $refundPercent . '% tiền tour.'
            : 'Tour không hoàn tiền khi hủy.';
    }
    $policyTerms = text_lines($policy['terms'] === null ? null : (string) $policy['terms']);
}

// Điều kiện đón khách: hình thức đón theo dữ liệu tour; gặp tại điểm hẹn mà chưa ghi điểm hẹn → thiếu dữ liệu.
$pickupLines = $isHotelPickup || $meetingPoint !== ''
    ? [pickup_text((string) $tour['pickup_mode'], $meetingPoint)]
    : [$missing];
if ($isHotelPickup && $meetingPoint !== '') {
    $pickupLines[] = 'Khu vực đón: ' . $meetingPoint;
}

// Điều kiện & chính sách (FR-05).
$policyRows = [
    'Độ tuổi' => $ageLines !== [] ? $ageLines : [$missing],
    'Giấy tờ' => $linesOrMissing($tour['document_terms']),
    'Ăn uống' => $linesOrMissing($tour['meal_terms']),
    'Voucher' => $linesOrMissing($tour['voucher_terms']),
    'Đổi lịch' => $linesOrMissing($tour['reschedule_terms']),
    'Hủy & hoàn tiền' => $policy !== null ? array_merge($policyLines, $policyTerms) : [$missing],
    'Điều kiện đón khách' => $pickupLines,
];

$sections = [
    'thong-tin' => 'Thông tin tour',
    'lich-trinh' => 'Lịch trình',
    'lich-khoi-hanh' => 'Lịch khởi hành',
    'dich-vu' => 'Dịch vụ',
    'chinh-sach' => 'Chính sách',
    'danh-gia' => 'Đánh giá',
];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e($listUrl) ?>">Bảng tin</a></li>
<?php if ($destinationUrl !== null): ?>
                <li class="breadcrumb-item"><a href="<?= e($destinationUrl) ?>"><?= e($destination) ?></a></li>
<?php endif; ?>
<?php if ($categoryUrl !== null && $categoryName !== ''): ?>
                <li class="breadcrumb-item"><a href="<?= e($categoryUrl) ?>"><?= e($categoryName) ?></a></li>
<?php endif; ?>
                <li class="breadcrumb-item active" aria-current="page"><?= e($tour['title']) ?></li>
            </ol>
        </nav>

        <div class="lt-detail-head">
            <div class="lt-detail-head__main">
                <h1 class="lt-detail-head__title"><?= e($tour['title']) ?></h1>
                <ul class="lt-detail-meta">
                    <li class="lt-detail-meta__item lt-detail-meta__item--rating">
                        <span class="lt-icon lt-icon--star" aria-hidden="true"></span>
<?php if ($ratingText !== null): ?>
                        <span><strong><?= e($ratingText) ?>/5</strong> (<?= e($reviewCount) ?> đánh giá)</span>
<?php else: ?>
                        <span>Chưa có đánh giá</span>
<?php endif; ?>
                    </li>
                    <li class="lt-detail-meta__item">
                        <span class="lt-icon lt-icon--pin" aria-hidden="true"></span>
                        <span><?= e(or_missing($destination)) ?></span>
                    </li>
<?php if ($categoryName !== ''): ?>
                    <li class="lt-detail-meta__item">
                        <span class="lt-icon lt-icon--compass" aria-hidden="true"></span>
                        <span><?= e($categoryName) ?></span>
                    </li>
<?php endif; ?>
                    <li class="lt-detail-meta__item">
                        <span>Tổ chức bởi <strong><?= e($providerName) ?></strong></span>
                        <span class="lt-verified" title="Đã được LocalTour duyệt">
                            <span class="lt-icon lt-icon--verified" aria-hidden="true"></span>
                            <span class="sr-only">Đã được LocalTour duyệt</span>
                        </span>
                    </li>
                </ul>
            </div>
            <div class="lt-detail-actions" role="group" aria-label="Tương tác (sắp có)">
<?php foreach (['heart' => 'Thích', 'message' => 'Bình luận', 'share' => 'Chia sẻ', 'bookmark' => 'Lưu tour'] as $actionIcon => $actionLabel): ?>
                <button type="button" class="lt-detail-action" disabled title="<?= e($actionLabel) ?> – sắp có">
                    <span class="lt-icon lt-icon--<?= e($actionIcon) ?>" aria-hidden="true"></span>
                    <span><?= e($actionLabel) ?></span>
                </button>
<?php endforeach; ?>
                <span class="lt-soon">Sắp có</span>
            </div>
        </div>

        <div class="lt-gallery<?= $galleryLayout !== '' ? ' ' . e($galleryLayout) : '' ?>">
<?php if ($galleryImages === []): ?>
            <div class="lt-gallery__item lt-gallery__item--main">
                <div class="lt-media-placeholder">
                    <span class="lt-icon lt-icon--image" aria-hidden="true"></span>
                    <span>Chưa cập nhật ảnh</span>
                </div>
            </div>
<?php endif; ?>
<?php foreach ($galleryImages as $slot => $image): ?>
<?php $caption = (string) $image['caption']; ?>
            <figure class="lt-gallery__item<?= $slot === 0 ? ' lt-gallery__item--main' : '' ?>">
                <img src="<?= e($image['url']) ?>" alt="<?= e($caption) ?>" width="1280" height="720"<?= $slot === 0 ? '' : ' loading="lazy"' ?> decoding="async">
                <figcaption class="lt-gallery__caption" aria-hidden="true"><?= e($caption) ?></figcaption>
            </figure>
<?php endforeach; ?>
        </div>

        <div class="row lt-detail-body">
            <div class="col-12 col-lg-7 col-xl-8 lt-detail-content">
                <div class="lt-detail-card">
                <nav class="lt-anchor-tabs js-detail-tabs" aria-label="Mục trong trang">
                    <ul class="lt-anchor-tabs__list">
<?php foreach ($sections as $sectionId => $sectionLabel): ?>
                        <li><a class="lt-anchor-tab<?= $sectionId === 'thong-tin' ? ' is-active' : '' ?>" href="#<?= e($sectionId) ?>"<?= $sectionId === 'thong-tin' ? ' aria-current="true"' : '' ?>><?= e($sectionLabel) ?></a></li>
<?php endforeach; ?>
                    </ul>
                </nav>

                <section class="lt-section" id="thong-tin" tabindex="-1" aria-labelledby="thong-tin-title">
                    <h2 class="lt-section__title" id="thong-tin-title">Thông tin tour</h2>
<?php if ($leadParagraph === null): ?>
                    <p class="lt-empty-note">Mô tả tour: <?= e($missing) ?></p>
<?php else: ?>
                    <p class="lt-section__lead"><?= nl2br(e($leadParagraph), false) ?></p>
<?php endif; ?>
<?php if ($paragraphs !== []): ?>
                    <div class="lt-prose">
<?php foreach ($paragraphs as $paragraph): ?>
                        <p><?= nl2br(e($paragraph), false) ?></p>
<?php endforeach; ?>
                    </div>
<?php endif; ?>
                    <dl class="lt-info">
<?php foreach ($infoRows as $rowLabel => $rowLines): ?>
                        <dt class="lt-info__label"><?= e($rowLabel) ?></dt>
                        <dd class="lt-info__value<?= $rowLines === [$missing] ? ' lt-info__value--missing' : '' ?>">
<?php foreach ($rowLines as $rowLine): ?>
                            <span class="lt-info__line"><?= e($rowLine) ?></span>
<?php endforeach; ?>
                        </dd>
<?php endforeach; ?>
                    </dl>
                </section>

                <section class="lt-section" id="lich-trinh" tabindex="-1" aria-labelledby="lich-trinh-title">
                    <h2 class="lt-section__title" id="lich-trinh-title">Lịch trình</h2>
<?php if (empty($itinerary)): ?>
                    <p class="lt-empty-note"><?= e($missing) ?></p>
<?php else: ?>
                    <ol class="lt-itinerary">
<?php foreach (array_values($itinerary) as $itemIndex => $item): ?>
                        <li class="lt-itinerary__stop">
                            <span class="lt-itinerary__marker" aria-hidden="true"><?= e($itemIndex + 1) ?></span>
                            <div class="lt-itinerary__body">
<?php if ($item['time_text'] !== null): ?>
                                <p class="lt-itinerary__time">
                                    <span class="lt-icon lt-icon--clock" aria-hidden="true"></span>
                                    <time datetime="<?= e($item['time_text']) ?>"><?= e($item['time_text']) ?></time>
                                </p>
<?php endif; ?>
                                <p class="lt-itinerary__text"><?= e($item['description']) ?></p>
                            </div>
                        </li>
<?php endforeach; ?>
                    </ol>
<?php endif; ?>
                </section>

                <section class="lt-section" id="lich-khoi-hanh" tabindex="-1" aria-labelledby="lich-khoi-hanh-title">
                    <h2 class="lt-section__title" id="lich-khoi-hanh-title">Lịch khởi hành</h2>
<?php if (!$hasSchedules): ?>
                    <p class="lt-empty-note">Chưa có lịch khởi hành sắp tới.</p>
<?php else: ?>
                    <ul class="lt-schedules">
<?php foreach ($schedules as $schedule): ?>
<?php $schedulePrice = $schedule['from_price_vnd'] === null ? null : format_vnd((int) $schedule['from_price_vnd']); ?>
                        <li class="lt-schedule">
                            <span class="lt-schedule__icon" aria-hidden="true"><span class="lt-icon lt-icon--calendar"></span></span>
                            <div class="lt-schedule__when">
                                <p class="lt-schedule__date"><?= e(format_date((string) $schedule['starts_at'])) ?></p>
                                <p class="lt-schedule__time"><?= e($scheduleTime($schedule)) ?></p>
                            </div>
                            <p class="lt-schedule__seats">Còn <?= e((int) $schedule['remaining']) ?>/<?= e((int) $schedule['capacity']) ?> chỗ</p>
                            <p class="lt-schedule__price">
<?php if ($schedulePrice !== null): ?>
                                Từ <strong><?= e($schedulePrice) ?></strong> / người lớn
<?php else: ?>
                                Giá: <?= e($missing) ?>
<?php endif; ?>
                            </p>
                        </li>
<?php endforeach; ?>
                    </ul>
<?php endif; ?>
                </section>

                <section class="lt-section" id="dich-vu" tabindex="-1" aria-labelledby="dich-vu-title">
                    <h2 class="lt-section__title" id="dich-vu-title">Dịch vụ</h2>
                    <h3 class="lt-subheading">Đã bao gồm</h3>
<?php if ($includedItems === []): ?>
                    <p class="lt-empty-note"><?= e($missing) ?></p>
<?php else: ?>
                    <ul class="lt-checklist">
<?php foreach ($includedItems as $itemText): ?>
                        <li class="lt-checklist__item"><span class="lt-checklist__mark" aria-hidden="true"><span class="lt-icon lt-icon--check"></span></span><?= e($itemText) ?></li>
<?php endforeach; ?>
                    </ul>
<?php endif; ?>
                    <h3 class="lt-subheading">Không bao gồm</h3>
<?php if ($excludedItems === []): ?>
                    <p class="lt-empty-note"><?= e($missing) ?></p>
<?php else: ?>
                    <ul class="lt-checklist lt-checklist--excluded">
<?php foreach ($excludedItems as $itemText): ?>
                        <li class="lt-checklist__item"><span class="lt-checklist__mark" aria-hidden="true"><span class="lt-icon lt-icon--x"></span></span><?= e($itemText) ?></li>
<?php endforeach; ?>
                    </ul>
<?php endif; ?>
                    <h3 class="lt-subheading">Phụ thu / hoạt động tùy chọn</h3>
<?php if (empty($extras)): ?>
                    <p class="lt-empty-note"><?= e($missing) ?></p>
<?php else: ?>
                    <p class="lt-empty-note">Tính riêng, không cộng vào giá tour và phần tạm tính.</p>
<?php foreach ($extraGroups as $extraGroup): ?>
                    <h4 class="lt-extras__title"><?= e($extraGroup['title']) ?></h4>
<?php if ($extraGroup['items'] === []): ?>
                    <p class="lt-empty-note"><?= e($missing) ?></p>
<?php else: ?>
                    <ul class="lt-extras">
<?php foreach ($extraGroup['items'] as $extraItem): ?>
                        <li class="lt-extra">
                            <div class="lt-extra__head">
                                <span class="lt-extra__name"><?= e($extraItem['name']) ?></span>
                                <span class="lt-extra__price<?= $extraItem['priceMissing'] ? ' lt-extra__price--missing' : '' ?>"><?= e($extraItem['price']) ?></span>
                            </div>
<?php if ($extraItem['conditions'] !== ''): ?>
                            <p class="lt-extra__conditions"><?= nl2br(e($extraItem['conditions']), false) ?></p>
<?php endif; ?>
                        </li>
<?php endforeach; ?>
                    </ul>
<?php endif; ?>
<?php endforeach; ?>
<?php endif; ?>
                </section>

                <section class="lt-section" id="chinh-sach" tabindex="-1" aria-labelledby="chinh-sach-title">
                    <h2 class="lt-section__title" id="chinh-sach-title">Điều kiện & chính sách</h2>
                    <dl class="lt-info">
<?php foreach ($policyRows as $rowLabel => $rowLines): ?>
                        <dt class="lt-info__label"><?= e($rowLabel) ?></dt>
                        <dd class="lt-info__value<?= $rowLines === [$missing] ? ' lt-info__value--missing' : '' ?>">
<?php foreach ($rowLines as $rowLine): ?>
                            <span class="lt-info__line"><?= e($rowLine) ?></span>
<?php endforeach; ?>
                        </dd>
<?php endforeach; ?>
                    </dl>
<?php if ($policy !== null): ?>
                    <p class="lt-empty-note lt-info__note">Chính sách hủy phiên bản <?= e((int) $policy['version']) ?> · minh họa · Kiểm tra trước khi đặt</p>
<?php endif; ?>
                </section>

                <section class="lt-section" id="danh-gia" tabindex="-1" aria-labelledby="danh-gia-title">
                    <h2 class="lt-section__title" id="danh-gia-title">Đánh giá</h2>
<?php if ($ratingText !== null && $reviewCount > 0): ?>
                    <div class="lt-review-summary">
                        <span class="lt-review-summary__score"><?= e($ratingText) ?></span>
                        <div>
                            <span class="lt-stars" style="--lt-rating: <?= e((float) $tour['rating_avg']) ?>" role="img" aria-label="<?= e($ratingText) ?> trên 5 sao"></span>
                            <p class="lt-review-summary__meta"><?= e($reviewCount) ?> đánh giá · Sắp xếp: Mới nhất</p>
                        </div>
                    </div>
<?php endif; ?>
<?php if (empty($reviews)): ?>
                    <div class="lt-empty-card">
                        <span class="lt-empty-card__icon" aria-hidden="true"><span class="lt-icon lt-icon--message"></span></span>
                        <div>
                            <p class="lt-empty-card__title">Chưa có đánh giá</p>
                            <p class="lt-empty-card__text">Tour này chưa có đánh giá nào. Đánh giá sẽ hiển thị sau khi khách tham gia tour.</p>
                        </div>
                    </div>
<?php else: ?>
                    <ul class="lt-reviews">
<?php foreach ($reviews as $review): ?>
<?php
    $reviewerName = (string) $review['reviewer_name'];
    $reviewRating = (int) $review['rating'];
    $reviewContent = trim((string) $review['content']);
    $tourDate = format_date($review['tour_date'] === null ? null : (string) $review['tour_date']);
?>
                        <li class="lt-review">
                            <div class="lt-review__head">
                                <span class="lt-avatar lt-avatar--sm" aria-hidden="true"><?= e(mb_strtoupper(mb_substr($reviewerName, 0, 1))) ?></span>
                                <div class="lt-review__who">
                                    <p class="lt-review__name"><?= e($reviewerName) ?></p>
                                    <p class="lt-review__meta">
                                        <span class="lt-stars lt-stars--sm" style="--lt-rating: <?= e($reviewRating) ?>" role="img" aria-label="<?= e($reviewRating) ?> trên 5 sao"></span>
                                        <span><?= e($reviewRating) ?>/5<?= $tourDate !== '' ? ' · Tham gia ngày ' . e($tourDate) : '' ?></span>
                                    </p>
                                </div>
                            </div>
<?php if ($reviewContent !== ''): ?>
                            <p class="lt-review__text">“<?= nl2br(e($reviewContent), false) ?>”</p>
<?php endif; ?>
                        </li>
<?php endforeach; ?>
                    </ul>
<?php if ($reviewCount > count($reviews)): ?>
                    <p class="lt-empty-note">Đang hiển thị <?= e(count($reviews)) ?> đánh giá mới nhất trên tổng số <?= e($reviewCount) ?>.</p>
<?php endif; ?>
<?php endif; ?>
                </section>
                </div>

                <section class="lt-provider" aria-labelledby="provider-title">
                    <span class="lt-avatar lt-avatar--lg" aria-hidden="true"><?= e($providerInitial) ?></span>
                    <div class="lt-provider__body">
                        <p class="lt-provider__eyebrow">Tổ chức bởi</p>
                        <h2 class="lt-provider__name" id="provider-title">
                            <?= e($providerName) ?>
                            <span class="lt-provider__badge"><span class="lt-icon lt-icon--verified" aria-hidden="true"></span>Đã được LocalTour duyệt</span>
                        </h2>
<?php if ($providerSince !== ''): ?>
                        <p class="lt-provider__desc">Đối tác của LocalTour từ <?= e($providerSince) ?>.</p>
<?php endif; ?>
                    </div>
                </section>
            </div>

            <div class="col-12 col-lg-5 col-xl-4 lt-detail-aside">
                <aside class="lt-booking" id="booking-card" aria-labelledby="booking-title">
                    <h2 class="sr-only" id="booking-title">Chọn lịch và giá</h2>
                    <p class="lt-booking__price">
<?php if ($priceText !== null): ?>
                        <span class="lt-booking__unit">Từ</span>
                        <span class="lt-booking__amount"><?= e($priceText) ?></span>
                        <span class="lt-booking__unit">/ người lớn</span>
<?php else: ?>
                        <span class="lt-booking__amount lt-booking__amount--none">Giá: <?= e($missing) ?></span>
<?php endif; ?>
                    </p>
                    <p class="lt-booking__note">Giá minh họa · VND</p>

                    <form class="lt-booking__form" id="booking-form" action="<?= e(url($bookPath)) ?>" method="get" novalidate>
                        <div class="lt-field">
                            <label class="lt-field__label" for="booking-schedule">Ngày tham gia</label>
<?php if ($hasSchedules): ?>
                            <select class="lt-input lt-select" id="booking-schedule" name="schedule_id">
<?php foreach ($schedules as $schedule): ?>
                                <option value="<?= e($schedule['schedule_id']) ?>"><?= e(format_date((string) $schedule['starts_at'])) ?> · <?= e(format_time((string) $schedule['starts_at'])) ?> · còn <?= e((int) $schedule['remaining']) ?> chỗ</option>
<?php endforeach; ?>
                            </select>
<?php else: ?>
                            <select class="lt-input lt-select" id="booking-schedule" name="schedule_id" disabled aria-describedby="booking-no-schedule">
                                <option value="">Chưa có lịch khởi hành sắp tới</option>
                            </select>
                            <p class="lt-booking__alert" id="booking-no-schedule">
                                <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                                Chưa có lịch khởi hành sắp tới. Vui lòng quay lại sau.
                            </p>
<?php endif; ?>
                        </div>

                        <div class="lt-field">
                            <label class="lt-field__label" for="booking-time">Giờ</label>
                            <input class="lt-input" type="text" id="booking-time" readonly
                                   value="<?= e($hasSchedules ? $scheduleTime($schedules[array_key_first($schedules)]) : '—') ?>"<?= $hasSchedules ? '' : ' disabled' ?>>
                        </div>

                        <fieldset class="lt-field lt-tickets" aria-describedby="booking-guests-hint">
                            <legend class="lt-field__label">Số khách</legend>
                            <div class="lt-tickets__list" id="booking-tickets">
<?php if ($hasSchedules): ?>
                                <p class="lt-field__hint">Chọn ngày tham gia để xem giá vé từng loại khách.</p>
<?php else: ?>
                                <div class="lt-ticket">
                                    <div class="lt-ticket__info">
                                        <span class="lt-ticket__label">Khách</span>
                                        <span class="lt-ticket__meta">Giá: <?= e($missing) ?></span>
                                    </div>
                                    <div class="lt-stepper">
                                        <button type="button" class="lt-stepper__btn" aria-label="Bớt 1 khách" disabled>
                                            <span class="lt-icon lt-icon--minus" aria-hidden="true"></span>
                                        </button>
                                        <input class="lt-input lt-stepper__input" type="number" value="1" aria-label="Số khách" disabled>
                                        <button type="button" class="lt-stepper__btn" aria-label="Thêm 1 khách" disabled>
                                            <span class="lt-icon lt-icon--plus" aria-hidden="true"></span>
                                        </button>
                                    </div>
                                </div>
<?php endif; ?>
                            </div>
                            <p class="lt-field__hint" id="booking-guests-hint">Nhóm tối đa <?= e($maxGroup) ?> khách</p>
                        </fieldset>

                        <div class="lt-booking__total" id="booking-total" aria-live="polite" aria-atomic="true">
                            <div class="lt-booking__total-main">
                                <span class="lt-booking__total-label">Tạm tính tiền vé</span>
                                <span class="lt-booking__total-formula js-total-formula"><?= e($hasSchedules ? '' : 'Chưa thể tính') ?></span>
                            </div>
                            <strong class="lt-booking__total-value js-total-amount">—</strong>
                        </div>
                        <p class="lt-field__hint">Chưa gồm phụ thu và hoạt động tùy chọn.</p>

                        <div class="lt-booking__actions">
<?php if ($isGuest): ?>
                            <p class="lt-booking__alert">
                                <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                                Bạn đang xem với tư cách khách. Đăng nhập để đặt tour.
                            </p>
                            <a class="lt-btn lt-btn--primary lt-btn--block js-login-to-book" href="<?= e($loginUrl) ?>"
                               data-login-url="<?= e(url('/login')) ?>" data-book-path="<?= e($bookPath) ?>">
                                <span class="lt-icon lt-icon--log-in" aria-hidden="true"></span>
                                Đăng nhập để đặt tour
                            </a>
<?php elseif ($isCustomer): ?>
                            <button type="submit" class="lt-btn lt-btn--primary lt-btn--block"<?= $hasSchedules ? '' : ' disabled' ?>>
                                Đặt tour
                            </button>
<?php else: ?>
                            <p class="lt-booking__alert">
                                <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                                Tài khoản quản trị không đặt tour được. Đăng nhập bằng tài khoản khách hàng để đặt tour.
                            </p>
<?php endif; ?>
                            <button type="button" class="lt-btn lt-btn--soft lt-btn--block" disabled title="Sắp có">
                                <span class="lt-icon lt-icon--columns" aria-hidden="true"></span>
                                Thêm vào so sánh <span class="lt-soon">Sắp có</span>
                            </button>
                        </div>
                    </form>
                    <script type="application/json" id="booking-data"><?= $bookingJson ?></script>

                    <div class="lt-booking__policy">
                        <span class="lt-icon lt-icon--shield" aria-hidden="true"></span>
                        <div>
<?php if ($policy !== null): ?>
<?php foreach ($policyLines as $policyLine): ?>
                            <p><?= e($policyLine) ?></p>
<?php endforeach; ?>
                            <p class="lt-booking__policy-note">Chính sách phiên bản <?= e((int) $policy['version']) ?> · minh họa · Kiểm tra trước khi đặt</p>
<?php else: ?>
                            <p>Chính sách hủy: <?= e($missing) ?></p>
                            <p class="lt-booking__policy-note">Chính sách minh họa · Kiểm tra trước khi đặt</p>
<?php endif; ?>
                        </div>
                    </div>

                    <a class="lt-btn lt-btn--outline lt-btn--block" href="<?= e($listUrl) ?>">
                        <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                        Quay lại danh sách
                    </a>
                </aside>
            </div>
        </div>
    </div>

    <div class="lt-mobile-cta d-lg-none">
<?php if ($priceText !== null): ?>
        <p class="lt-mobile-cta__price">Từ <strong><?= e($priceText) ?></strong> / người lớn</p>
<?php else: ?>
        <p class="lt-mobile-cta__price">Giá: <strong><?= e($missing) ?></strong></p>
<?php endif; ?>
        <a class="lt-btn lt-btn--primary js-scroll-link" href="#booking-card">Chọn lịch</a>
    </div>
</main>
