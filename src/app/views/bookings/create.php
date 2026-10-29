<?php declare(strict_types=1); ?>
<?php
/*
 * Hoàn tất thông tin đặt tour (M4 mục 4, Nguyễn Tuấn Khôi) – theo wireframe 4.
 * Biến: $tour (NMT_sp_tour_detail), $schedules (lịch còn đặt được), $tickets (vé đang bán của các lịch đó),
 *       $extras (phụ thu / hoạt động tùy chọn của tour, dạng extra_option() trong BookingController),
 *       $policy (null hoặc chính sách hủy mới nhất), $coverUrl (ảnh bìa hoặc null),
 *       $selectedScheduleId, $selectedTickets ([mã vé => số khách] chọn ở trang chi tiết),
 *       $scheduleNotice (lịch đã chọn không còn nhận khách), $contact (name, email, phone),
 *       $requestToken (mã một lần mở form), $loginUrl (đăng nhập lại khi hết phiên), $title.
 * Hai bước trong cùng trang: điền thông tin → "Xem lại & xác nhận" → "Gửi yêu cầu đặt tour".
 * booking.js dựng hàng vé, danh sách khách, tạm tính và gửi POST /api/bookings; trang cần JavaScript.
 * Sprint 4 (4.3.2.3): khách chọn phụ thu / hoạt động tùy chọn; tổng tiền = tiền vé + các khoản đã chọn.
 * Chưa thu tiền ở bước này: đơn mới là "Chờ xác nhận", thanh toán làm sau khi LocalTour xác nhận chỗ và chốt tổng giá.
 */
$missing = or_missing(null);
$tourUrl = url('/tours/' . $tour['tour_id']);
$maxGroup = max(1, (int) $tour['max_group_size']);
$hasSchedules = $schedules !== [];
$destination = or_missing((string) $tour['destination_name']);
$meetingPoint = trim((string) ($tour['meeting_point'] ?? ''));
$isHotelPickup = $tour['pickup_mode'] === 'hotel_pickup';
$meetingLines = [departure_text((string) $tour['pickup_mode'], $meetingPoint)];
if ($isHotelPickup && $meetingPoint !== '') {
    $meetingLines[] = 'Khu vực đón: ' . $meetingPoint;
}
$policyLines = $policy === null ? [] : cancellation_policy_lines($policy['free_before_hours'], $policy['refund_percent']);

// Dữ liệu cho booking.js: mỗi lịch kèm các loại vé; lịch và số khách đã chọn ở trang chi tiết.
$ticketsBySchedule = [];
foreach ($tickets as $ticket) {
    $ticketsBySchedule[(string) $ticket['schedule_id']][] = ticket_option($ticket);
}
$bookData = [
    'maxGroup' => $maxGroup,
    'selected' => (object) $selectedTickets,
    'schedules' => [],
];
foreach ($schedules as $schedule) {
    $scheduleId = (string) $schedule['schedule_id'];
    $bookData['schedules'][] = [
        'id' => $scheduleId,
        'dateText' => format_date((string) $schedule['starts_at']),
        'timeText' => schedule_time_text((string) $schedule['starts_at'], (string) $schedule['ends_at']),
        'remaining' => (int) $schedule['remaining'],
        'tickets' => $ticketsBySchedule[$scheduleId] ?? [],
    ];
}
$bookJson = json_encode($bookData, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE) ?: 'null';

$contactFields = [
    ['name' => 'contact_name', 'id' => 'book-contact-name', 'label' => 'Họ tên', 'type' => 'text', 'maxlength' => 100, 'autocomplete' => 'name', 'value' => $contact['name']],
    ['name' => 'contact_email', 'id' => 'book-contact-email', 'label' => 'Email', 'type' => 'email', 'maxlength' => 150, 'autocomplete' => 'email', 'value' => $contact['email']],
    ['name' => 'contact_phone', 'id' => 'book-contact-phone', 'label' => 'Số điện thoại', 'type' => 'tel', 'maxlength' => 20, 'autocomplete' => 'tel', 'value' => $contact['phone']],
];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-book" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/tours')) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item"><a href="<?= e($tourUrl) ?>"><?= e($tour['title']) ?></a></li>
                <li class="breadcrumb-item active" aria-current="page">Đặt tour</li>
            </ol>
        </nav>

        <div class="lt-book-head">
            <a class="lt-book-back" href="<?= e($tourUrl) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Quay lại chi tiết tour
            </a>
            <h1 class="lt-book-head__title">Hoàn tất thông tin đặt tour</h1>
            <ol class="lt-steps" aria-label="Các bước đặt tour">
                <li class="lt-steps__item is-current" aria-current="step"><span class="lt-steps__num">1</span>Thông tin chuyến đi</li>
                <li class="lt-steps__item"><span class="lt-steps__num">2</span>Thanh toán</li>
                <li class="lt-steps__item"><span class="lt-steps__num">3</span>Xác nhận</li>
            </ol>
        </div>

<?php if (!$hasSchedules): ?>
        <section class="lt-book-card lt-book-empty" aria-labelledby="book-empty-title">
            <h2 class="lt-book-card__title" id="book-empty-title">Chưa có lịch khởi hành để đặt</h2>
            <p class="lt-booking__alert">
                <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                Tour này hiện chưa có lịch khởi hành còn nhận khách. Vui lòng quay lại sau hoặc chọn tour khác.
            </p>
            <div class="lt-book-actions">
                <a class="lt-btn lt-btn--outline" href="<?= e($tourUrl) ?>">Xem chi tiết tour</a>
                <a class="lt-btn lt-btn--primary" href="<?= e(url('/tours')) ?>">Xem tour khác</a>
            </div>
        </section>
<?php else: ?>
        <noscript>
            <p class="lt-book-alert">Trang đặt tour cần bật JavaScript để chọn số khách và gửi yêu cầu.</p>
        </noscript>

        <form class="row lt-book-form" id="book-form" action="<?= e(url('/api/bookings')) ?>" method="post" novalidate
              data-login-url="<?= e($loginUrl) ?>">
            <?= csrf_field() ?>
            <input type="hidden" name="request_token" value="<?= e($requestToken) ?>">
            <input type="hidden" name="expected_total" id="book-expected-total" value="0">

            <div class="col-12 col-lg-7 col-xl-8">
                <div class="lt-book-alert" id="book-alert" role="alert" tabindex="-1" hidden>
                    <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
                    <span class="js-alert-text"></span>
                </div>
<?php if ($scheduleNotice !== ''): ?>
                <p class="lt-booking__alert lt-book-notice">
                    <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                    <?= e($scheduleNotice) ?>
                </p>
<?php endif; ?>

                <div id="book-step-edit">
                    <section class="lt-book-card" aria-labelledby="book-contact-title">
                        <h2 class="lt-book-card__title" id="book-contact-title"><span class="lt-book-card__num">1</span>Thông tin liên hệ</h2>
                        <p class="lt-book-card__lead">LocalTour dùng thông tin này để báo kết quả xác nhận chỗ và hướng dẫn thanh toán.</p>
                        <div class="lt-book-grid">
<?php foreach ($contactFields as $field): ?>
                            <div class="lt-field">
                                <label class="lt-field__label" for="<?= e($field['id']) ?>"><?= e($field['label']) ?></label>
                                <input class="lt-input" type="<?= e($field['type']) ?>" id="<?= e($field['id']) ?>" name="<?= e($field['name']) ?>"
                                       value="<?= e($field['value']) ?>" maxlength="<?= e($field['maxlength']) ?>" autocomplete="<?= e($field['autocomplete']) ?>"
                                       required aria-describedby="<?= e($field['id']) ?>-error">
                                <p class="lt-field__error" id="<?= e($field['id']) ?>-error" data-error-for="<?= e($field['name']) ?>" hidden></p>
                            </div>
<?php endforeach; ?>
                        </div>
                    </section>

                    <section class="lt-book-card" aria-labelledby="book-trip-title">
                        <h2 class="lt-book-card__title" id="book-trip-title"><span class="lt-book-card__num">2</span>Chuyến đi</h2>
                        <div class="lt-book-grid">
                            <div class="lt-field">
                                <label class="lt-field__label" for="book-schedule">Ngày tham gia</label>
                                <select class="lt-input lt-select" id="book-schedule" name="schedule_id" aria-describedby="book-schedule-error">
<?php foreach ($schedules as $schedule): ?>
                                    <option value="<?= e($schedule['schedule_id']) ?>"<?= (string) $schedule['schedule_id'] === $selectedScheduleId ? ' selected' : '' ?>><?= e(format_date((string) $schedule['starts_at'])) ?> · <?= e(format_time((string) $schedule['starts_at'])) ?> · còn <?= e((int) $schedule['remaining']) ?> chỗ</option>
<?php endforeach; ?>
                                </select>
                                <p class="lt-field__error" id="book-schedule-error" data-error-for="schedule_id" hidden></p>
                            </div>
                            <div class="lt-field">
                                <label class="lt-field__label" for="book-time">Giờ</label>
                                <input class="lt-input" type="text" id="book-time" readonly value="—">
                            </div>
                        </div>

                        <fieldset class="lt-field lt-tickets" aria-describedby="book-guests-hint">
                            <legend class="lt-field__label">Số khách</legend>
                            <div class="lt-tickets__list" id="book-tickets">
                                <p class="lt-field__hint">Đang tải giá vé…</p>
                            </div>
                            <p class="lt-field__hint" id="book-guests-hint">Nhóm tối đa <?= e($maxGroup) ?> khách</p>
                            <p class="lt-field__error" data-error-for="passengers" hidden></p>
                        </fieldset>

<?php if ($extras !== []): ?>
                        <fieldset class="lt-field lt-extras" aria-describedby="book-extras-hint">
                            <legend class="lt-field__label">Phụ thu và hoạt động tùy chọn <span class="lt-field__optional">(không bắt buộc)</span></legend>
                            <ul class="lt-extras__list">
<?php foreach ($extras as $extra): ?>
<?php $extraInputId = 'book-extra-' . $extra['id']; ?>
                                <li class="lt-extras__item<?= $extra['price'] === null ? ' is-disabled' : '' ?>">
                                    <input class="lt-check__input js-extra" type="checkbox" id="<?= e($extraInputId) ?>" name="extras[]" value="<?= e($extra['id']) ?>"
                                           data-price="<?= e((int) $extra['price']) ?>" data-per-person="<?= $extra['perPerson'] ? '1' : '0' ?>" data-name="<?= e($extra['name']) ?>"<?= $extra['price'] === null ? ' disabled' : '' ?>>
                                    <label class="lt-extras__label" for="<?= e($extraInputId) ?>">
                                        <span class="lt-extras__name">
                                            <span class="lt-extras__kind"><?= $extra['kind'] === 'surcharge' ? 'Phụ thu' : 'Tùy chọn' ?></span>
                                            <?= e($extra['name']) ?>
                                        </span>
                                        <span class="lt-extras__price"><?= e($extra['priceText']) ?></span>
<?php if ($extra['conditions'] !== ''): ?>
                                        <span class="lt-extras__note"><?= e($extra['conditions']) ?></span>
<?php endif; ?>
                                    </label>
                                </li>
<?php endforeach; ?>
                            </ul>
                            <p class="lt-field__hint" id="book-extras-hint">Khoản tính theo người nhân với số khách; các khoản khác tính một lần cho cả nhóm. Khoản chưa có giá sẽ được LocalTour báo khi xác nhận chỗ.</p>
                        </fieldset>
<?php endif; ?>

                        <div class="lt-book-meeting">
                            <span class="lt-icon lt-icon--pin" aria-hidden="true"></span>
                            <div>
                                <p class="lt-book-meeting__label"><?= $isHotelPickup ? 'Điểm đón' : 'Điểm gặp' ?></p>
<?php foreach ($meetingLines as $meetingLine): ?>
                                <p><?= e($meetingLine) ?></p>
<?php endforeach; ?>
                            </div>
                        </div>
                    </section>

                    <section class="lt-book-card" aria-labelledby="book-guests-title">
                        <h2 class="lt-book-card__title" id="book-guests-title"><span class="lt-book-card__num">3</span>Danh sách khách</h2>
                        <p class="lt-book-card__lead">Nhập họ tên từng khách đúng như giấy tờ tùy thân. Số ô theo số khách đã chọn ở trên.</p>
                        <ol class="lt-passengers" id="book-passengers"></ol>

                        <div class="lt-field lt-book-request">
                            <label class="lt-field__label" for="book-special-request">Yêu cầu đặc biệt <span class="lt-field__optional">(không bắt buộc)</span></label>
                            <textarea class="lt-input lt-textarea" id="book-special-request" name="special_request" rows="3" maxlength="500"
                                      placeholder="Ví dụ: ăn chay, dị ứng hải sản, cần hỗ trợ xe lăn…" aria-describedby="book-special-request-count book-special-request-error"></textarea>
                            <p class="lt-field__hint lt-field__count" id="book-special-request-count" aria-live="polite">0/500 ký tự</p>
                            <p class="lt-field__error" id="book-special-request-error" data-error-for="special_request" hidden></p>
                        </div>
                    </section>

                    <section class="lt-book-card" aria-labelledby="book-terms-title">
                        <h2 class="lt-book-card__title" id="book-terms-title"><span class="lt-book-card__num">4</span>Điều kiện đặt tour</h2>
                        <ul class="lt-book-terms">
                            <li>Yêu cầu được gửi tới LocalTour ở trạng thái <strong>Chờ xác nhận</strong>, chưa giữ chỗ và chưa thu tiền.</li>
                            <li>Khi LocalTour xác nhận còn chỗ và chốt tổng giá, đơn chuyển sang <strong>Chờ thanh toán</strong>: bạn thanh toán bằng VNPay hoặc VietQR trong 24 giờ, quá hạn đơn tự hủy.</li>
<?php foreach ($policyLines as $policyLine): ?>
                            <li><?= e($policyLine) ?></li>
<?php endforeach; ?>
<?php if ($policy === null): ?>
                            <li>Chính sách hủy: <?= e($missing) ?></li>
<?php endif; ?>
                        </ul>
                        <div class="lt-check">
                            <input class="lt-check__input" type="checkbox" id="book-terms" name="terms" value="1" aria-describedby="book-terms-error">
                            <label class="lt-check__label" for="book-terms">
                                Tôi đồng ý với điều kiện đặt tour và
                                <a href="<?= e($tourUrl) ?>#chinh-sach" target="_blank" rel="noopener">chính sách hủy<span class="sr-only"> (mở tab mới)</span></a>.
                            </label>
                        </div>
                        <p class="lt-field__error" id="book-terms-error" data-error-for="terms" hidden></p>
                    </section>

                    <div class="lt-book-actions">
                        <a class="lt-btn lt-btn--outline" href="<?= e($tourUrl) ?>">Hủy</a>
                        <button type="submit" class="lt-btn lt-btn--primary" id="book-review-btn">
                            Xem lại &amp; xác nhận
                        </button>
                    </div>
                </div>

                <section class="lt-book-card lt-book-review" id="book-step-review" aria-labelledby="book-review-title" tabindex="-1" hidden>
                    <h2 class="lt-book-card__title" id="book-review-title">Xem lại yêu cầu đặt tour</h2>
                    <p class="lt-book-card__lead">Kiểm tra lại thông tin trước khi gửi. Bạn vẫn có thể quay lại để sửa.</p>
                    <dl class="lt-book-summary">
                        <div><dt>Tour</dt><dd><?= e($tour['title']) ?></dd></div>
                        <div><dt>Ngày tham gia</dt><dd class="js-review-date"></dd></div>
                        <div><dt>Giờ</dt><dd class="js-review-time"></dd></div>
                        <div><dt>Số khách</dt><dd class="js-review-people"></dd></div>
                        <div><dt>Người liên hệ</dt><dd class="js-review-contact"></dd></div>
                        <div><dt>Danh sách khách</dt><dd><ol class="lt-book-summary__list js-review-passengers"></ol></dd></div>
                        <div><dt>Yêu cầu đặc biệt</dt><dd class="js-review-request"></dd></div>
<?php if ($extras !== []): ?>
                        <div><dt>Phụ thu / tùy chọn</dt><dd class="js-review-extras"></dd></div>
<?php endif; ?>
                        <div class="lt-book-summary__total"><dt>Tổng tiền</dt><dd class="js-review-total"></dd></div>
                    </dl>
                    <p class="lt-booking__alert">
                        <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                        Chưa thu tiền ở bước này. Sau khi gửi, đơn ở trạng thái "Chờ xác nhận"; LocalTour kiểm tra chỗ, chốt tổng giá rồi mở thanh toán VNPay / VietQR trong "Đơn của tôi".
                    </p>
                    <div class="lt-book-actions">
                        <button type="button" class="lt-btn lt-btn--outline" id="book-edit-btn">
                            <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                            Sửa thông tin
                        </button>
                        <button type="button" class="lt-btn lt-btn--primary" id="book-submit-btn">
                            <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
                            <span class="js-submit-label">Gửi yêu cầu đặt tour</span>
                        </button>
                    </div>
                </section>
            </div>

            <div class="col-12 col-lg-5 col-xl-4 lt-detail-aside">
                <aside class="lt-booking lt-book-aside" aria-labelledby="book-aside-title">
                    <h2 class="lt-book-aside__title" id="book-aside-title">Tour bạn đã chọn</h2>
                    <div class="lt-book-tour">
                        <div class="lt-book-tour__media">
<?php if ($coverUrl !== null): ?>
                            <img src="<?= e($coverUrl) ?>" alt="" loading="lazy">
<?php else: ?>
                            <div class="lt-media-placeholder"><span class="lt-icon lt-icon--image" aria-hidden="true"></span></div>
<?php endif; ?>
                        </div>
                        <div class="lt-book-tour__body">
                            <p class="lt-book-tour__title"><?= e($tour['title']) ?></p>
                            <p class="lt-book-tour__meta"><?= e($destination) ?> · <?= e(format_duration($tour['duration_minutes'])) ?></p>
                        </div>
                    </div>

                    <dl class="lt-book-facts">
                        <div><dt>Ngày tham gia</dt><dd class="js-sum-date">—</dd></div>
                        <div><dt>Giờ</dt><dd class="js-sum-time">—</dd></div>
                        <div><dt>Số khách</dt><dd class="js-sum-people">—</dd></div>
                    </dl>

                    <ul class="lt-book-lines" id="book-sum-lines" aria-label="Tiền vé và các khoản đã chọn"></ul>

                    <div class="lt-booking__total" aria-live="polite" aria-atomic="true">
                        <div class="lt-booking__total-main">
                            <span class="lt-booking__total-label">Tổng tiền</span>
                            <span class="lt-booking__total-formula">Vé + phụ thu / tùy chọn · VND</span>
                        </div>
                        <strong class="lt-booking__total-value" id="book-sum-total">—</strong>
                    </div>
                    <p class="lt-field__hint">Chưa thu tiền ở bước này. LocalTour chốt tổng giá khi xác nhận chỗ, rồi bạn thanh toán trong 24 giờ.</p>

                    <div class="lt-booking__policy">
                        <span class="lt-icon lt-icon--shield" aria-hidden="true"></span>
                        <div>
<?php if ($policy !== null): ?>
<?php foreach ($policyLines as $policyLine): ?>
                            <p><?= e($policyLine) ?></p>
<?php endforeach; ?>
                            <p class="lt-booking__policy-note">Chính sách phiên bản <?= e((int) $policy['version']) ?> được lưu cùng đơn.</p>
<?php else: ?>
                            <p>Chính sách hủy: <?= e($missing) ?></p>
<?php endif; ?>
                        </div>
                    </div>
                </aside>
            </div>
        </form>
        <script type="application/json" id="book-data"><?= $bookJson ?></script>
<?php endif; ?>
    </div>
</main>
