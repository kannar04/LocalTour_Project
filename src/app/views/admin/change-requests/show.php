<?php declare(strict_types=1); ?>
<?php
/*
 * Chi tiết và xử lý một yêu cầu đổi ngày / hủy tour (US14-S5-03, FR-12 – Nguyễn Tuấn Khôi).
 * Biến: $request (LTP_sp_admin_change_request_detail), $others (các yêu cầu khác của cùng đơn),
 *       $old (decision, note, refund), $errors (theo ô; 'form' = lỗi chung), $success.
 * Chính sách hủy, số tiền đã thanh toán và số dự kiến hoàn là ảnh chụp lúc khách gửi yêu cầu.
 */
use App\Models\AdminChangeRequestModel;

$requestId = (string) $request['request_id'];
$isPending = $request['status'] === 'pending';
$isCancel = $request['type'] === 'cancel';
$paidNow = (int) $request['paid_now_vnd'];
$estimate = min((int) $request['estimated_refund_vnd'], $paidNow);
$reviewCount = (int) $request['review_payment_count'];
$hasPolicy = $request['refund_percent'] !== null;
$policyLines = $hasPolicy ? cancellation_policy_lines($request['free_before_hours'], $request['refund_percent']) : [];
$fieldError = static fn (string $field): string => $errors[$field] ?? '';
$requestedText = '';
if (!$isCancel && $request['requested_starts_at'] !== null) {
    $requestedText = format_date((string) $request['requested_starts_at']) . ' · '
        . schedule_time_text((string) $request['requested_starts_at'], (string) $request['requested_ends_at']);
}
$fields = [
    'Khách hàng' => $request['customer_name'] . ' · ' . $request['customer_email'],
    'Người liên hệ' => $request['contact_name'] . ' · ' . $request['contact_phone'],
    'Tour' => $request['tour_title'],
    'Gói tour' => $request['package_name'] !== null ? (string) $request['package_name'] : 'Không chia gói',
    'Ngày đang đặt' => format_date((string) $request['starts_at']) . ' · ' . schedule_time_text((string) $request['starts_at'], (string) $request['ends_at']),
    'Số khách' => (int) $request['people'] . ' khách',
    'Tổng tiền đơn' => format_vnd($request['total_vnd']),
    'Trạng thái đơn' => booking_status_label((string) $request['booking_status'])
        . ($request['booking_status'] !== $request['booking_status_at_request']
            ? ' (lúc gửi: ' . booking_status_label((string) $request['booking_status_at_request']) . ')'
            : ''),
    'Gửi lúc' => format_datetime((string) $request['created_at']),
];
if (!$isCancel) {
    $fields['Muốn đổi sang'] = $requestedText !== ''
        ? $requestedText . ' · ' . schedule_status_label((string) $request['requested_status']) . ', còn ' . (int) $request['requested_remaining'] . ' chỗ'
        : or_missing(null);
}
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/admin/change-requests' . ($isPending ? '' : '?status=all'))) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Yêu cầu đổi ngày / hủy tour
            </a>
            <header class="lt-admin__head lt-admin__head--row">
                <div>
                    <h1 class="lt-admin__title" id="admin-title"><?= e(change_request_type_label((string) $request['type'])) ?> · Đơn <?= e($request['booking_code']) ?></h1>
                    <p class="lt-admin__subtitle">
                        <span class="lt-badge lt-badge--<?= e($request['status']) ?>"><?= e(change_request_status_label((string) $request['status'])) ?></span>
                        <?= e($request['tour_title']) ?>
                    </p>
                </div>
                <div class="lt-admin__actions">
                    <a class="lt-btn lt-btn--soft" href="<?= e(url('/admin/bookings/' . $request['booking_id'])) ?>">Xem đơn</a>
                </div>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Chưa xử lý được: vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>
<?php if ($isPending && $isCancel && $reviewCount > 0): ?>
            <div class="lt-alert lt-alert--warning"><span class="lt-icon lt-icon--info" aria-hidden="true"></span><span>Đơn còn <?= e($reviewCount) ?> khoản chuyển khoản chờ đối chiếu: đối chiếu ở trang "Đối chiếu thanh toán" trước khi đồng ý hủy.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="request-info-title">
                        <h2 class="lt-panel__title" id="request-info-title">Yêu cầu của khách</h2>
                        <p class="lt-admin__text"><strong>Lý do:</strong> <?= nl2br(e($request['reason'])) ?></p>
                        <dl class="lt-fields">
<?php foreach ($fields as $label => $value): ?>
                            <dt><?= e($label) ?></dt>
                            <dd><?= e($value) ?></dd>
<?php endforeach; ?>
                        </dl>
                    </section>

                    <section class="lt-panel" aria-labelledby="request-policy-title">
                        <h2 class="lt-panel__title" id="request-policy-title">Chính sách hủy áp dụng</h2>
<?php if ($hasPolicy): ?>
<?php foreach ($policyLines as $line): ?>
                        <p class="lt-admin__text"><?= e($line) ?></p>
<?php endforeach; ?>
<?php foreach (text_lines($request['policy_terms'] === null ? null : (string) $request['policy_terms']) as $term): ?>
                        <p class="lt-admin__text"><?= e($term) ?></p>
<?php endforeach; ?>
<?php else: ?>
                        <p class="lt-empty">Đơn không có chính sách hủy.</p>
<?php endif; ?>
                        <dl class="lt-fields lt-fields--compact">
                            <dt>Phiên bản</dt>
                            <dd><?= e((int) $request['policy_version']) ?></dd>
                            <dt>Lúc gửi</dt>
                            <dd><?= (int) $request['in_free_window'] === 1 ? 'Trong thời gian hủy miễn phí' : 'Ngoài thời gian hủy miễn phí' ?></dd>
                            <dt>Đã thanh toán lúc gửi</dt>
                            <dd><?= e(format_vnd($request['paid_vnd'])) ?></dd>
                            <dt>Đã thanh toán hiện tại</dt>
                            <dd><?= e(format_vnd($paidNow)) ?></dd>
<?php if ($isCancel): ?>
                            <dt>Dự kiến hoàn</dt>
                            <dd><?= e(format_vnd($request['estimated_refund_vnd'])) ?></dd>
<?php endif; ?>
                        </dl>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
<?php if ($isPending): ?>
                    <section class="lt-panel" aria-labelledby="request-decide-title">
                        <h2 class="lt-panel__title" id="request-decide-title">Xử lý</h2>
                        <form class="lt-admin-form" action="<?= e(url('/admin/change-requests/' . $requestId . '/decide')) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
                            <fieldset class="lt-admin-field">
                                <legend class="lt-admin-label">Kết quả</legend>
<?php foreach (['approved' => $isCancel ? 'Đồng ý hủy tour' : 'Đồng ý đổi ngày', 'rejected' => 'Từ chối, giữ nguyên đơn'] as $value => $label): ?>
                                <div class="custom-control custom-radio">
                                    <input class="custom-control-input" type="radio" id="decision-<?= e($value) ?>" name="decision" value="<?= e($value) ?>"<?= $old['decision'] === $value ? ' checked' : '' ?>>
                                    <label class="custom-control-label" for="decision-<?= e($value) ?>"><?= e($label) ?></label>
                                </div>
<?php endforeach; ?>
<?php if ($fieldError('decision') !== ''): ?>
                                <p class="lt-admin-error"><?= e($fieldError('decision')) ?></p>
<?php endif; ?>
                            </fieldset>
<?php if ($isCancel): ?>
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="decide-refund">Số tiền hoàn (đ)</label>
                                <input class="lt-admin-input<?= $fieldError('refund') !== '' ? ' is-invalid' : '' ?>" type="text" id="decide-refund" name="refund" value="<?= e($old['refund']) ?>"
                                       inputmode="numeric" maxlength="15" autocomplete="off" placeholder="<?= e(number_format($estimate, 0, ',', '.')) ?>"
                                       aria-describedby="decide-refund-hint<?= $fieldError('refund') !== '' ? ' decide-refund-error' : '' ?>">
                                <p class="lt-admin-hint" id="decide-refund-hint">Chỉ dùng khi đồng ý hủy. Để trống = số dự kiến <?= e(format_vnd($estimate)) ?>; tối đa <?= e(format_vnd($paidNow)) ?>. Hệ thống chỉ ghi nhận, LocalTour chuyển khoản lại thủ công.</p>
<?php if ($fieldError('refund') !== ''): ?>
                                <p class="lt-admin-error" id="decide-refund-error"><?= e($fieldError('refund')) ?></p>
<?php endif; ?>
                            </div>
<?php endif; ?>
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="decide-note">Ghi chú gửi khách (bắt buộc)</label>
                                <textarea class="lt-admin-input<?= $fieldError('note') !== '' ? ' is-invalid' : '' ?>" id="decide-note" name="note" rows="3" maxlength="<?= e(AdminChangeRequestModel::NOTE_MAX_LENGTH) ?>" required
                                          <?= $fieldError('note') !== '' ? 'aria-invalid="true" aria-describedby="decide-note-error"' : '' ?>><?= e($old['note']) ?></textarea>
<?php if ($fieldError('note') !== ''): ?>
                                <p class="lt-admin-error" id="decide-note-error"><?= e($fieldError('note')) ?></p>
<?php endif; ?>
                            </div>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit">Lưu kết quả</button>
                        </form>
                    </section>
<?php else: ?>
                    <section class="lt-panel" aria-labelledby="request-result-title">
                        <h2 class="lt-panel__title" id="request-result-title">Kết quả xử lý</h2>
                        <dl class="lt-fields lt-fields--compact">
                            <dt>Kết quả</dt>
                            <dd><?= e(change_request_status_label((string) $request['status'])) ?></dd>
                            <dt>Người xử lý</dt>
                            <dd><?= e(or_missing($request['handler_name'] === null ? null : (string) $request['handler_name'])) ?></dd>
                            <dt>Lúc</dt>
                            <dd><?= e(format_datetime($request['handled_at'] === null ? null : (string) $request['handled_at'])) ?></dd>
<?php if ($isCancel && $request['status'] === 'approved'): ?>
                            <dt>Số tiền hoàn</dt>
                            <dd><?= e(format_vnd((int) $request['refund_vnd'])) ?></dd>
<?php endif; ?>
                        </dl>
<?php if ($request['result_note'] !== null): ?>
                        <p class="lt-admin__text"><strong>Ghi chú:</strong> <?= e($request['result_note']) ?></p>
<?php endif; ?>
                    </section>
<?php endif; ?>
                </div>
            </div>

<?php if ($others !== []): ?>
            <section class="lt-panel" aria-labelledby="request-others-title">
                <h2 class="lt-panel__title" id="request-others-title">Yêu cầu khác của đơn này</h2>
                <ol class="lt-history">
<?php foreach ($others as $other): ?>
                    <li class="lt-history__item">
                        <p class="lt-history__head">
                            <a href="<?= e(url('/admin/change-requests/' . $other['request_id'])) ?>"><?= e(change_request_type_label((string) $other['type'])) ?></a>
                            · <?= e(change_request_status_label((string) $other['status'])) ?>
                        </p>
                        <p class="lt-history__meta"><?= e(format_datetime((string) $other['created_at'])) ?><?= $other['handler_name'] !== null ? ' · ' . e($other['handler_name']) : '' ?></p>
<?php if ($other['result_note'] !== null): ?>
                        <p class="lt-history__note"><?= e($other['result_note']) ?></p>
<?php endif; ?>
                    </li>
<?php endforeach; ?>
                </ol>
            </section>
<?php endif; ?>
        </main>
    </div>
</div>
