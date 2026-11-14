<?php declare(strict_types=1); ?>
<?php
/*
 * So sánh tour (US04-S5-01, FR-15 – Nguyễn Tuấn Khôi): 2 – 3 tour đặt cạnh nhau theo cùng đơn vị.
 * Biến: $headers (CompareModel::headers(): id, title, url, image, image_alt, provider, destination, category),
 *       $rows (CompareModel::rows(): nhóm → dòng → ô {lines, missing}; [] khi chưa đủ 2 tour),
 *       $notices (quá 3 tour, tour bị bỏ), $requested (URL có ?ids=), $title.
 * Ô thiếu dữ liệu hiện "Chưa cập nhật" (chữ nhạt). compare.js đồng bộ danh sách đã chọn trong trình duyệt và
 * xử lý nút "Bỏ khỏi so sánh"; mở /compare không kèm mã tour thì compare.js chuyển sang danh sách đã lưu.
 */
$listUrl = url('/tours');
$count = count($headers);
$ready = $rows !== [];
$emptySlots = max(0, 3 - $count);
$compareData = [
    'requested' => $requested,
    'tours' => array_map(static fn (array $tour): array => [
        'id' => $tour['id'],
        'title' => $tour['title'],
        'image' => $tour['image'] ?? '',
    ], $headers),
];
$compareJson = json_encode($compareData, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: 'null';
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-cmp" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e($listUrl) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item active" aria-current="page">So sánh tour</li>
            </ol>
        </nav>

        <div class="lt-cmp-head">
            <div>
                <h1 class="lt-cmp-head__title">So sánh tour</h1>
                <p class="lt-cmp-head__lead">Giá tính theo mỗi khách, thời lượng theo giờ, chính sách hủy theo giờ trước khởi hành. Ô "Chưa cập nhật" là thông tin đơn vị tổ chức chưa cung cấp.</p>
            </div>
<?php if ($count > 0): ?>
            <button type="button" class="lt-btn lt-btn--outline js-compare-clear">
                <span class="lt-icon lt-icon--x" aria-hidden="true"></span>
                Xóa danh sách
            </button>
<?php endif; ?>
        </div>

<?php foreach ($notices as $notice): ?>
        <p class="lt-booking__alert lt-cmp-notice" role="status">
            <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
            <?= e($notice) ?>
        </p>
<?php endforeach; ?>

<?php if (!$ready): ?>
        <section class="lt-cmp-empty" aria-labelledby="cmp-empty-title">
            <span class="lt-cmp-empty__icon" aria-hidden="true"><span class="lt-icon lt-icon--columns"></span></span>
            <h2 class="lt-cmp-empty__title" id="cmp-empty-title"><?= $count === 0 ? 'Chưa chọn tour để so sánh' : 'Cần ít nhất 2 tour để so sánh' ?></h2>
            <p class="lt-cmp-empty__text">
                Bấm “Thêm vào so sánh” trên thẻ tour ở bảng tin hoặc ở trang chi tiết tour. Chọn 2–3 tour để xem giá, lịch trình và chính sách cạnh nhau.
            </p>
<?php if ($count === 1): ?>
            <p class="lt-cmp-empty__chosen">Đã chọn: <a href="<?= e($headers[0]['url']) ?>"><?= e($headers[0]['title']) ?></a></p>
<?php endif; ?>
            <a class="lt-btn lt-btn--primary" href="<?= e($listUrl) ?>">
                <span class="lt-icon lt-icon--plus" aria-hidden="true"></span>
                Chọn tour ở bảng tin
            </a>
        </section>
<?php else: ?>
        <div class="lt-cmp-scroll" role="region" aria-label="Bảng so sánh tour, cuộn ngang trên màn hình nhỏ" tabindex="0">
            <table class="lt-cmp-table lt-cmp-table--<?= e($count) ?>">
                <caption class="sr-only">So sánh <?= e($count) ?> tour: <?= e(implode(', ', array_column($headers, 'title'))) ?></caption>
                <thead>
                    <tr>
                        <td class="lt-cmp-table__corner"></td>
<?php foreach ($headers as $header): ?>
                        <th scope="col" class="lt-cmp-tour">
<?php if ($header['image'] !== null): ?>
                            <img class="lt-cmp-tour__img" src="<?= e($header['image']) ?>" alt="<?= e($header['image_alt']) ?>" width="320" height="180" loading="lazy" decoding="async">
<?php else: ?>
                            <div class="lt-cmp-tour__img lt-media-placeholder"><span class="lt-icon lt-icon--image" aria-hidden="true"></span></div>
<?php endif; ?>
                            <a class="lt-cmp-tour__title" href="<?= e($header['url']) ?>"><?= e($header['title']) ?></a>
                            <span class="lt-cmp-tour__meta"><?= e($header['destination']) ?> · <?= e($header['category']) ?></span>
                            <span class="lt-cmp-tour__meta">Tổ chức bởi <?= e($header['provider']) ?></span>
                            <span class="lt-cmp-tour__actions">
                                <a class="lt-btn lt-btn--primary lt-btn--sm" href="<?= e($header['url']) ?>">Xem chi tiết</a>
                                <button type="button" class="lt-btn lt-btn--outline lt-btn--sm js-compare-remove" data-tour-id="<?= e($header['id']) ?>"
                                        aria-label="Bỏ &quot;<?= e($header['title']) ?>&quot; khỏi so sánh">Bỏ</button>
                            </span>
                        </th>
<?php endforeach; ?>
<?php if ($emptySlots > 0): ?>
                        <td class="lt-cmp-add">
                            <a class="lt-cmp-add__link" href="<?= e($listUrl) ?>">
                                <span class="lt-icon lt-icon--plus" aria-hidden="true"></span>
                                Thêm tour<span class="sr-only"> vào so sánh</span>
                            </a>
                        </td>
<?php endif; ?>
                    </tr>
                </thead>
<?php foreach ($rows as $group): ?>
                <tbody>
                    <tr class="lt-cmp-group">
                        <th scope="colgroup" colspan="<?= e($count + 1 + ($emptySlots > 0 ? 1 : 0)) ?>"><?= e($group['group']) ?></th>
                    </tr>
<?php foreach ($group['rows'] as $row): ?>
                    <tr>
                        <th scope="row" class="lt-cmp-label"><?= e($row['label']) ?></th>
<?php foreach ($row['cells'] as $cell): ?>
                        <td class="lt-cmp-cell<?= $cell['missing'] ? ' lt-cmp-cell--missing' : '' ?>">
<?php if (count($cell['lines']) > 1): ?>
                            <ul class="lt-cmp-lines">
<?php foreach ($cell['lines'] as $line): ?>
                                <li><?= e($line) ?></li>
<?php endforeach; ?>
                            </ul>
<?php else: ?>
                            <?= e($cell['lines'][0] ?? '') ?>
<?php endif; ?>
                        </td>
<?php endforeach; ?>
<?php if ($emptySlots > 0): ?>
                        <td class="lt-cmp-cell lt-cmp-cell--empty" aria-hidden="true"></td>
<?php endif; ?>
                    </tr>
<?php endforeach; ?>
                </tbody>
<?php endforeach; ?>
            </table>
        </div>
        <p class="lt-field__hint lt-cmp-foot">Giá là giá thấp nhất của các lịch còn nhận đặt (tour chia gói: gói rẻ nhất). Giá đúng theo ngày, gói và số khách bạn chọn hiện ở trang đặt tour.</p>
<?php endif; ?>
        <script type="application/json" id="compare-data"><?= $compareJson ?></script>
    </div>
</main>
