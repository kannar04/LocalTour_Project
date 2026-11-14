<?php declare(strict_types=1); ?>
<?php
/*
 * Duyệt "bản sửa" của tour đã duyệt (Sprint 6, Nguyễn Tuấn Khôi): so sánh nội dung đang hiển thị cho khách với
 * nội dung đơn vị tổ chức đề xuất. Dùng trong admin/tours/show.php.
 * Biến: $revision = ['current' => [...], 'proposed' => [...]], mỗi bên gồm info (NTK_sp_admin_tour_revision_compare),
 *       images, itinerary, inclusions (danh sách của file 21) và policy (phiên bản chính sách hủy mới nhất hoặc null).
 * Chỉ hiện phần có thay đổi; lịch khởi hành và giá vé không nằm trong bản sửa.
 */
$sideLabels = ['current' => 'Đang hiển thị', 'proposed' => 'Bản sửa'];

// Thông tin tour: nhãn → cách đổi một dòng info thành chữ.
$infoFields = [
    'Tên tour' => static fn (array $i): string => (string) $i['title'],
    'Mô tả' => static fn (array $i): string => or_missing($i['description']),
    'Điểm đến' => static fn (array $i): string => or_missing($i['destination_name']),
    'Loại hình' => static fn (array $i): string => or_missing($i['category_name']),
    'Thời lượng' => static fn (array $i): string => format_duration($i['duration_minutes']),
    'Số khách tối đa' => static fn (array $i): string => $i['max_group_size'] . ' người',
    'Ngôn ngữ' => static fn (array $i): string => format_languages($i['language_codes']),
    'Nơi khởi hành' => static fn (array $i): string => departure_text($i['pickup_mode'], $i['meeting_point']),
    'Điểm trả khách' => static fn (array $i): string => or_missing($i['dropoff_point']),
    'Phương tiện' => static fn (array $i): string => or_missing($i['transport']),
    'Hướng dẫn viên' => static fn (array $i): string => or_missing($i['guide_info']),
    'Giấy tờ' => static fn (array $i): string => or_missing($i['document_terms']),
    'Ăn uống' => static fn (array $i): string => or_missing($i['meal_terms']),
    'Voucher' => static fn (array $i): string => or_missing($i['voucher_terms']),
    'Đổi lịch' => static fn (array $i): string => or_missing($i['reschedule_terms']),
];
$infoChanges = [];
foreach ($infoFields as $label => $text) {
    $old = $text($revision['current']['info']);
    $new = $text($revision['proposed']['info']);
    if ($old !== $new) {
        $infoChanges[$label] = [$old, $new];
    }
}

// Nội dung: mỗi bên thành danh sách dòng chữ để so sánh và hiển thị.
$itineraryLines = static fn (array $items): array => array_map(
    static fn (array $item): string => ($item['start_time'] !== null ? format_time((string) $item['start_time']) . ' – ' : '') . $item['description'],
    $items
);
$inclusionLines = static fn (array $items): array => array_map(
    static fn (array $item): string => ((int) $item['is_included'] === 1 ? 'Bao gồm: ' : 'Không bao gồm: ') . $item['item_text'],
    $items
);
$policyLines = static fn (?array $policy): array => $policy === null
    ? []
    : array_merge(cancellation_policy_lines($policy['free_before_hours'], $policy['refund_percent']), [(string) $policy['terms']]);
$imageKeys = static fn (array $images): array => array_map(
    static fn (array $image): string => $image['url'] . '|' . $image['alt_text'],
    $images
);

$lists = [];
foreach (['Lịch trình' => ['itinerary', $itineraryLines], 'Dịch vụ bao gồm / không bao gồm' => ['inclusions', $inclusionLines], 'Chính sách hủy' => ['policy', $policyLines]] as $label => [$key, $toLines]) {
    $old = $toLines($revision['current'][$key]);
    $new = $toLines($revision['proposed'][$key]);
    if ($old !== $new) {
        $lists[$label] = ['current' => $old, 'proposed' => $new];
    }
}
$imagesChanged = $imageKeys($revision['current']['images']) !== $imageKeys($revision['proposed']['images']);
$urlsOf = static fn (array $images): array => array_map(static fn (array $image): string => (string) $image['url'], $images);
$otherUrls = ['current' => $urlsOf($revision['proposed']['images']), 'proposed' => $urlsOf($revision['current']['images'])];
$imageBadges = ['current' => 'Bị bỏ', 'proposed' => 'Mới'];
$nothingChanged = $infoChanges === [] && $lists === [] && !$imagesChanged;
?>
            <section class="lt-panel" id="revision-compare" aria-labelledby="revision-compare-title">
                <h2 class="lt-panel__title" id="revision-compare-title">So sánh với tour đang hiển thị</h2>
<?php if ($nothingChanged): ?>
                <p class="lt-empty">Bản sửa chưa có thay đổi nào so với tour đang hiển thị.</p>
<?php else: ?>
                <p class="lt-admin__text">Chỉ liệt kê phần có thay đổi. Lịch khởi hành và giá vé không nằm trong bản sửa.</p>
<?php endif; ?>

<?php if ($infoChanges !== []): ?>
                <h3 class="lt-panel__subtitle">Thông tin tour</h3>
                <div class="table-responsive">
                    <table class="table lt-table mb-0">
                        <thead>
                            <tr><th scope="col">Mục</th><th scope="col">Đang hiển thị</th><th scope="col">Bản sửa</th></tr>
                        </thead>
                        <tbody>
<?php foreach ($infoChanges as $label => [$old, $new]): ?>
                            <tr>
                                <th scope="row"><?= e($label) ?></th>
                                <td><?= nl2br(e($old)) ?></td>
                                <td><?= nl2br(e($new)) ?></td>
                            </tr>
<?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
<?php endif; ?>

<?php if ($imagesChanged): ?>
                <h3 class="lt-panel__subtitle">Ảnh</h3>
                <div class="row">
<?php foreach ($sideLabels as $side => $sideLabel): ?>
                    <div class="col-12 col-lg-6">
                        <p class="lt-admin__text"><strong><?= e($sideLabel) ?></strong> (<?= e(count($revision[$side]['images'])) ?> ảnh)</p>
<?php if ($revision[$side]['images'] === []): ?>
                        <p class="lt-empty">Không có ảnh.</p>
<?php else: ?>
                        <ul class="lt-thumbs">
<?php foreach ($revision[$side]['images'] as $image): ?>
                            <li class="lt-thumb<?= (int) $image['is_cover'] === 1 ? ' is-cover' : '' ?>">
                                <img class="lt-thumb__img" src="<?= e(image_src((string) $image['url'])) ?>" alt="<?= e((string) $image['alt_text']) ?>" width="240" height="135" loading="lazy" decoding="async">
                                <p class="lt-thumb__caption">
<?php if (!in_array((string) $image['url'], $otherUrls[$side], true)): ?>
                                    <span class="lt-badge lt-badge--<?= $side === 'proposed' ? 'approved' : 'rejected' ?>"><?= e($imageBadges[$side]) ?></span>
<?php endif; ?>
                                    <?= (int) $image['is_cover'] === 1 ? 'Ảnh bìa · ' : '' ?><?= e(or_missing($image['alt_text'] === null ? null : (string) $image['alt_text'])) ?>
                                </p>
                            </li>
<?php endforeach; ?>
                        </ul>
<?php endif; ?>
                    </div>
<?php endforeach; ?>
                </div>
<?php endif; ?>

<?php foreach ($lists as $label => $sides): ?>
                <h3 class="lt-panel__subtitle"><?= e($label) ?></h3>
                <div class="row">
<?php foreach ($sideLabels as $side => $sideLabel): ?>
                    <div class="col-12 col-lg-6">
                        <p class="lt-admin__text"><strong><?= e($sideLabel) ?></strong></p>
<?php if ($sides[$side] === []): ?>
                        <p class="lt-empty">Chưa có.</p>
<?php else: ?>
                        <ul class="lt-plain-list">
<?php foreach ($sides[$side] as $line): ?>
                            <li><?= nl2br(e($line)) ?></li>
<?php endforeach; ?>
                        </ul>
<?php endif; ?>
                    </div>
<?php endforeach; ?>
                </div>
<?php endforeach; ?>
            </section>
