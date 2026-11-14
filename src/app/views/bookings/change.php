<?php declare(strict_types=1); ?>
<?php
/*
 * Đổi ngày / hủy tour (US14-S5-01, FR-12 – Nguyễn Tuấn Khôi): form gửi yêu cầu, chính sách hủy đã áp dụng lúc đặt,
 * số tiền dự kiến được hoàn và các yêu cầu đã gửi.
 * Biến: $quote (LTP_sp_change_quote), $options (lịch khác còn đủ chỗ: schedule_id, starts_at, ends_at, remaining),
 *       $requests (LTP_sp_change_request_list, mới nhất trước), $blockedMessage (lý do không gửi được, '' = gửi được),
 *       $old (type, schedule_id, reason), $errors (theo ô; 'form' = lỗi chung), $success, $title.
 * change-request.js chỉ hiện ô "Ngày muốn đổi sang" khi chọn đổi ngày và đếm ký tự lý do (không có JS vẫn gửi được).
 */
use App\Models\ChangeRequestModel;

$code = (string) $quote['booking_code'];
$bookingUrl = url('/bookings/' . $code);
$canRequest = (int) $quote['can_request'] === 1;
$hasPolicy = $quote['refund_percent'] !== null;
$policyLines = $hasPolicy ? cancellation_policy_lines($quote['free_before_hours'], $quote['refund_percent']) : [];
$paidVnd = (int) $quote['paid_vnd'];
$estimatedRefund = (int) $quote['estimated_refund_vnd'];
$inFreeWindow = (int) $quote['in_free_window'] === 1;
$freeUntil = format_datetime($quote['free_until'] === null ? null : (string) $quote['free_until']);
$hasOptions = $options !== [];
$type = $old['type'];
$reasonLength = mb_strlen($old['reason']);
$fieldError = static fn (string $field): string => $errors[$field] ?? '';
$typeOptions = [
    'cancel' => [
        'label' => 'Hủy tour',
        'note' => $paidVnd > 0
            ? 'Dự kiến được hoàn ' . format_vnd($estimatedRefund) . ' theo chính sách hủy.'
            : 'Đơn chưa thanh toán nên không có tiền hoàn.',
    ],
    'change_date' => [
        'label' => 'Đổi sang ngày khác',
        'note' => $hasOptions
            ? 'Giữ nguyên số khách và tổng tiền; LocalTour xác nhận lại chỗ ở lịch mới.'
            : 'Hiện chưa có lịch khác còn đủ chỗ cho ' . (int) $quote['people'] . ' khách.',
    ],
];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-detail lt-book" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/bookings')) ?>">Đơn của tôi</a></li>
                <li class="breadcrumb-item"><a href="<?= e($bookingUrl) ?>"><?= e($code) ?></a></li>
                <li class="breadcrumb-item active" aria-current="page">Đổi ngày / hủy tour</li>
            </ol>
        </nav>

<?php if ($success !== ''): ?>
        <div class="lt-book-success" role="status">
            <span class="lt-icon lt-icon--check" aria-hidden="true"></span>
            <div><p><?= e($success) ?></p></div>
        </div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
        <div class="lt-book-alert" role="alert">
            <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
            <span><?= e($errors['form']) ?></span>
        </div>
<?php elseif ($errors !== []): ?>
        <div class="lt-book-alert" role="alert">
            <span class="lt-icon lt-icon--alert" aria-hidden="true"></span>
            <span>Chưa gửi được yêu cầu: vui lòng kiểm tra lại các ô được đánh dấu.</span>
        </div>
<?php endif; ?>

        <div class="lt-book-head">
            <a class="lt-book-back" href="<?= e($bookingUrl) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                Đơn <?= e($code) ?>
            </a>
            <h1 class="lt-book-head__title">Đổi ngày / hủy tour</h1>
            <p class="lt-book-head__lead">
                <?= e($quote['tour_title']) ?> · <?= e(format_date((string) $quote['starts_at'])) ?>
                <?= e(schedule_time_text((string) $quote['starts_at'], (string) $quote['ends_at'])) ?> · <?= e((int) $quote['people']) ?> khách
            </p>
        </div>

        <div class="row">
            <div class="col-12 col-lg-7 col-xl-8">
<?php if (!$canRequest): ?>
                <section class="lt-book-card" aria-labelledby="change-blocked-title">
                    <h2 class="lt-book-card__title" id="change-blocked-title">Không gửi được yêu cầu mới</h2>
                    <p><?= e($blockedMessage) ?></p>
                    <a class="lt-btn lt-btn--outline" href="<?= e($bookingUrl) ?>">Về trang đơn</a>
                </section>
<?php else: ?>
                <section class="lt-book-card" aria-labelledby="change-form-title">
                    <h2 class="lt-book-card__title" id="change-form-title">Gửi yêu cầu</h2>
                    <p class="lt-book-card__lead">LocalTour xem xét từng yêu cầu và báo kết quả trên trang này. Đơn vẫn giữ nguyên cho tới khi yêu cầu được đồng ý.</p>
                    <form class="lt-book-form" action="<?= e(url('/bookings/' . $code . '/change')) ?>" method="post" novalidate>
                        <?= csrf_field() ?>
                        <fieldset class="lt-field lt-extras" aria-describedby="<?= $fieldError('type') !== '' ? 'change-type-error' : '' ?>">
                            <legend class="lt-field__label">Bạn muốn</legend>
                            <ul class="lt-extras__list">
<?php foreach ($typeOptions as $value => $option): ?>
<?php $typeDisabled = $value === 'change_date' && !$hasOptions; ?>
                                <li class="lt-extras__item<?= $typeDisabled ? ' is-disabled' : '' ?>">
                                    <input class="lt-check__input js-change-type" type="radio" id="change-type-<?= e($value) ?>" name="type" value="<?= e($value) ?>"
                                           <?= $type === $value && !$typeDisabled ? 'checked' : '' ?><?= $typeDisabled ? ' disabled' : '' ?>>
                                    <label class="lt-extras__label" for="change-type-<?= e($value) ?>">
                                        <span class="lt-extras__name"><?= e($option['label']) ?></span>
                                        <span class="lt-extras__note"><?= e($option['note']) ?></span>
                                    </label>
                                </li>
<?php endforeach; ?>
                            </ul>
<?php if ($fieldError('type') !== ''): ?>
                            <p class="lt-field__error" id="change-type-error"><?= e($fieldError('type')) ?></p>
<?php endif; ?>
                        </fieldset>

<?php if ($hasOptions): ?>
                        <div class="lt-field js-change-schedule">
                            <label class="lt-field__label" for="change-schedule">Ngày muốn đổi sang</label>
                            <select class="lt-input lt-select" id="change-schedule" name="schedule_id"
                                    <?= $fieldError('schedule_id') !== '' ? 'aria-invalid="true" aria-describedby="change-schedule-error"' : 'aria-describedby="change-schedule-hint"' ?>>
                                <option value="">Chọn ngày</option>
<?php foreach ($options as $option): ?>
                                <option value="<?= e($option['schedule_id']) ?>"<?= $old['schedule_id'] === $option['schedule_id'] ? ' selected' : '' ?>>
                                    <?= e(format_date((string) $option['starts_at'])) ?> · <?= e(schedule_time_text((string) $option['starts_at'], (string) $option['ends_at'])) ?> · còn <?= e((int) $option['remaining']) ?> chỗ
                                </option>
<?php endforeach; ?>
                            </select>
                            <p class="lt-field__hint" id="change-schedule-hint">Chỉ hiện các lịch còn đủ chỗ cho <?= e((int) $quote['people']) ?> khách.</p>
<?php if ($fieldError('schedule_id') !== ''): ?>
                            <p class="lt-field__error" id="change-schedule-error"><?= e($fieldError('schedule_id')) ?></p>
<?php endif; ?>
                        </div>
<?php endif; ?>

                        <div class="lt-field">
                            <label class="lt-field__label" for="change-reason">Lý do</label>
                            <textarea class="lt-input lt-textarea" id="change-reason" name="reason" rows="4" maxlength="<?= e(ChangeRequestModel::REASON_MAX_LENGTH) ?>" required
                                      aria-describedby="change-reason-count<?= $fieldError('reason') !== '' ? ' change-reason-error' : '' ?>"<?= $fieldError('reason') !== '' ? ' aria-invalid="true"' : '' ?>><?= e($old['reason']) ?></textarea>
                            <p class="lt-field__hint lt-field__count" id="change-reason-count" aria-live="polite"><?= e($reasonLength) ?>/<?= e(ChangeRequestModel::REASON_MAX_LENGTH) ?> ký tự</p>
<?php if ($fieldError('reason') !== ''): ?>
                            <p class="lt-field__error" id="change-reason-error"><?= e($fieldError('reason')) ?></p>
<?php endif; ?>
                        </div>

                        <div class="lt-book-actions">
                            <a class="lt-btn lt-btn--outline" href="<?= e($bookingUrl) ?>">Quay lại</a>
                            <button type="submit" class="lt-btn lt-btn--primary">Gửi yêu cầu</button>
                        </div>
                    </form>
                </section>
<?php endif; ?>

                <section class="lt-book-card" aria-labelledby="change-history-title">
                    <h2 class="lt-book-card__title" id="change-history-title">Yêu cầu đã gửi</h2>
<?php if ($requests === []): ?>
                    <p class="lt-field__hint">Chưa có yêu cầu nào cho đơn này.</p>
<?php else: ?>
                    <ol class="lt-book-history">
<?php foreach ($requests as $request): ?>
<?php
    $isCancel = $request['type'] === 'cancel';
    $refund = $request['refund_vnd'] !== null ? (int) $request['refund_vnd'] : null;
?>
                        <li>
                            <p class="lt-book-history__title">
                                <?= e(change_request_type_label((string) $request['type'])) ?>
<?php if (!$isCancel && $request['requested_starts_at'] !== null): ?>
                                sang <?= e(format_datetime((string) $request['requested_starts_at'])) ?>
<?php endif; ?>
                                · <strong><?= e(change_request_status_label((string) $request['status'])) ?></strong>
                            </p>
                            <p class="lt-book-history__meta">
                                Gửi lúc <?= e(format_datetime((string) $request['created_at'])) ?>
<?php if ($request['handled_at'] !== null): ?>
                                · xử lý lúc <?= e(format_datetime((string) $request['handled_at'])) ?>
<?php endif; ?>
                            </p>
                            <p class="lt-book-history__note">Lý do: <?= e($request['reason']) ?></p>
<?php if ($isCancel && (int) $request['paid_vnd'] > 0): ?>
                            <p class="lt-book-history__note">
<?php if ($refund !== null): ?>
                                Số tiền hoàn: <strong><?= e(format_vnd($refund)) ?></strong> (LocalTour chuyển lại thủ công)
<?php else: ?>
                                Dự kiến hoàn: <?= e(format_vnd($request['estimated_refund_vnd'])) ?>
<?php endif; ?>
                            </p>
<?php endif; ?>
<?php if ($request['result_note'] !== null && trim((string) $request['result_note']) !== ''): ?>
                            <p class="lt-book-history__note">Phản hồi của LocalTour: <?= e($request['result_note']) ?></p>
<?php endif; ?>
                        </li>
<?php endforeach; ?>
                    </ol>
<?php endif; ?>
                </section>
            </div>

            <div class="col-12 col-lg-5 col-xl-4 lt-detail-aside">
                <aside class="lt-booking lt-book-aside" aria-labelledby="change-policy-title">
                    <h2 class="lt-book-aside__title" id="change-policy-title">Chính sách hủy của đơn</h2>
                    <div class="lt-booking__policy">
                        <span class="lt-icon lt-icon--shield" aria-hidden="true"></span>
                        <div>
<?php if ($hasPolicy): ?>
<?php foreach ($policyLines as $policyLine): ?>
                            <p><?= e($policyLine) ?></p>
<?php endforeach; ?>
<?php foreach (text_lines($quote['policy_terms'] === null ? null : (string) $quote['policy_terms']) as $term): ?>
                            <p><?= e($term) ?></p>
<?php endforeach; ?>
                            <p class="lt-booking__policy-note">Phiên bản <?= e((int) $quote['policy_version']) ?>, áp dụng từ lúc đặt.</p>
<?php else: ?>
                            <p>Chính sách hủy: <?= e(or_missing(null)) ?></p>
<?php endif; ?>
                        </div>
                    </div>
                    <ul class="lt-book-lines">
<?php if ($freeUntil !== ''): ?>
                        <li><span>Hủy miễn phí đến</span><span><?= e($freeUntil) ?></span></li>
                        <li><span>Hiện tại</span><span><?= $inFreeWindow ? 'Trong thời gian hủy miễn phí' : 'Đã qua thời gian hủy miễn phí' ?></span></li>
<?php endif; ?>
                        <li><span>Đã thanh toán</span><span><?= e(format_vnd($paidVnd)) ?></span></li>
                    </ul>
                    <div class="lt-booking__total">
                        <div class="lt-booking__total-main">
                            <span class="lt-booking__total-label">Dự kiến hoàn nếu hủy bây giờ</span>
                            <span class="lt-booking__total-formula">LocalTour xác nhận số tiền khi xử lý</span>
                        </div>
                        <strong class="lt-booking__total-value"><?= e(format_vnd($estimatedRefund)) ?></strong>
                    </div>
                    <p class="lt-field__hint">Tiền hoàn được LocalTour chuyển khoản lại thủ công sau khi đồng ý hủy, chưa hoàn tự động qua cổng thanh toán.</p>
                    <a class="lt-btn lt-btn--outline lt-btn--block" href="<?= e($bookingUrl) ?>">
                        <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span>
                        Về trang đơn
                    </a>
                </aside>
            </div>
        </div>
    </div>
</main>
