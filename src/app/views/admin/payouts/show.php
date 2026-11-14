<?php declare(strict_types=1); ?>
<?php
/*
 * Một khoản chi trả cho đơn vị tổ chức (Nguyễn Tuấn Khôi): lịch khởi hành, đơn vị, tài khoản nhận tiền, từng đơn trong
 * khoản và form ghi nhận đã chi trả (ô ẩn account_no = số tài khoản đang hiện, để phát hiện đơn vị vừa đổi tài khoản).
 * Đơn vị chưa khai tài khoản nhận tiền: hiện thông báo thay cho form.
 * Khoản còn chờ: tài khoản đơn vị đang khai phải được quản trị viên xác minh trước. Chưa xác minh thì hiện form xác minh
 * (ô ẩn bank_name, account_no, account_name = đúng tài khoản đang hiện) thay cho form ghi nhận đã chi trả.
 * Biến: $payout (NTK_sp_admin_payout_detail), $items (NTK_sp_admin_payout_item_list), $old (reference, note đang nhập),
 *       $errors (lỗi theo ô; 'form' = lỗi chung), $success ('' = không có).
 */
use App\Models\PayoutModel;

$isPending = $payout['status'] === 'pending';
// Khoản đã chi trả: tài khoản đã chụp lúc ghi nhận đã chi trả. Khoản còn chờ: tài khoản đơn vị đang khai.
$bank = $isPending
    ? ['name' => $payout['provider_bank_name'], 'no' => $payout['provider_bank_account_no'], 'holder' => $payout['provider_bank_account_name']]
    : ['name' => $payout['bank_name'], 'no' => $payout['bank_account_no'], 'holder' => $payout['bank_account_name']];
$hasBank = trim((string) $bank['name']) !== '' && trim((string) $bank['no']) !== '' && trim((string) $bank['holder']) !== '';
// Dấu xác minh thuộc về tài khoản đơn vị đang khai nên chỉ xét với khoản còn chờ.
$bankVerified = $isPending && $hasBank && $payout['provider_bank_verified_at'] !== null;
$needsVerify = $isPending && $hasBank && !$bankVerified;
$referenceError = $errors['reference'] ?? '';
$noteError = $errors['note'] ?? '';
?>
<div class="container-xl lt-container lt-page">
    <div class="row">
        <div class="col-12 lt-col-sidebar">
<?php require __DIR__ . '/../partials/nav.php'; ?>
        </div>

        <main id="main-content" class="col-12 col-lg lt-admin" tabindex="-1" aria-labelledby="admin-title">
            <a class="lt-admin__back" href="<?= e(url('/admin/payouts' . ($isPending ? '' : '?status=paid'))) ?>">
                <span class="lt-icon lt-icon--arrow-left" aria-hidden="true"></span> Chi trả đơn vị tổ chức
            </a>
            <header class="lt-admin__head">
                <h1 class="lt-admin__title" id="admin-title">Chi trả <?= e(format_vnd($payout['net_vnd'])) ?></h1>
                <p class="lt-admin__subtitle">
                    <span class="lt-badge lt-badge--<?= e($payout['status']) ?>"><?= e(PayoutModel::statusLabel((string) $payout['status'])) ?></span>
                    <?= e($payout['business_name']) ?> · lập lúc <?= e(format_datetime((string) $payout['created_at'])) ?>
                </p>
            </header>

<?php if ($success !== ''): ?>
            <div class="lt-alert lt-alert--success" role="status"><span class="lt-icon lt-icon--check" aria-hidden="true"></span><span><?= e($success) ?></span></div>
<?php endif; ?>
<?php if (isset($errors['form'])): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span><?= e($errors['form']) ?></span></div>
<?php elseif ($errors !== []): ?>
            <div class="lt-alert lt-alert--danger" role="alert"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Vui lòng kiểm tra lại các ô được đánh dấu.</span></div>
<?php endif; ?>

            <div class="row">
                <div class="col-12 col-xl-7">
                    <section class="lt-panel" aria-labelledby="payout-schedule-title">
                        <h2 class="lt-panel__title" id="payout-schedule-title">Lịch khởi hành và số tiền</h2>
                        <dl class="lt-fields">
                            <dt>Tour</dt><dd><a href="<?= e(url('/admin/tours/' . $payout['tour_id'])) ?>"><?= e($payout['tour_title']) ?></a></dd>
                            <dt>Khởi hành</dt><dd><?= e(format_datetime((string) $payout['starts_at'])) ?> – kết thúc <?= e(format_datetime((string) $payout['ends_at'])) ?></dd>
                            <dt>Tiền thực thu</dt><dd><?= e(format_vnd($payout['gross_vnd'])) ?> <span class="lt-muted">(<?= e((int) $payout['booking_count']) ?> đơn, đã trừ tiền hoàn cho khách)</span></dd>
                            <dt>Phí dịch vụ LocalTour</dt><dd><?= e(format_vnd($payout['commission_vnd'])) ?></dd>
                            <dt>Thực nhận</dt><dd><strong><?= e(format_vnd($payout['net_vnd'])) ?></strong></dd>
                        </dl>

                        <h3 class="lt-panel__subtitle">Các đơn trong khoản chi trả</h3>
                        <div class="table-responsive">
                            <table class="table lt-table mb-0">
                                <thead>
                                    <tr>
                                        <th scope="col">Đơn</th>
                                        <th scope="col" class="text-right">Tiền thực thu</th>
                                        <th scope="col" class="text-right">Phí dịch vụ</th>
                                        <th scope="col" class="text-right">Thực nhận</th>
                                    </tr>
                                </thead>
                                <tbody>
<?php foreach ($items as $item): ?>
                                    <tr>
                                        <td>
                                            <a href="<?= e(url('/admin/bookings/' . $item['booking_id'])) ?>"><strong><?= e($item['code']) ?></strong></a>
                                            <span class="lt-table__sub"><?= e($item['contact_name']) ?> · <?= e((int) $item['people']) ?> khách · <?= e(booking_status_label((string) $item['booking_status'])) ?><?= $item['booking_status'] === 'cancelled' ? ' (phí hủy giữ lại)' : '' ?></span>
                                        </td>
                                        <td class="text-right lt-nowrap"><?= e(format_vnd($item['kept_vnd'])) ?></td>
                                        <td class="text-right lt-nowrap"><?= e(format_vnd($item['commission_vnd'])) ?> <span class="lt-table__sub"><?= e(PayoutModel::percentText($item['commission_rate'])) ?></span></td>
                                        <td class="text-right lt-nowrap"><?= e(format_vnd($item['net_vnd'])) ?></td>
                                    </tr>
<?php endforeach; ?>
                                </tbody>
                                <tfoot>
                                    <tr>
                                        <th scope="row">Tổng</th>
                                        <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['gross_vnd'])) ?></strong></td>
                                        <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['commission_vnd'])) ?></strong></td>
                                        <td class="text-right lt-nowrap"><strong><?= e(format_vnd($payout['net_vnd'])) ?></strong></td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                    </section>
                </div>

                <div class="col-12 col-xl-5">
                    <section class="lt-panel" aria-labelledby="payout-provider-title">
                        <h2 class="lt-panel__title" id="payout-provider-title">Đơn vị nhận tiền</h2>
                        <dl class="lt-fields">
                            <dt>Đơn vị</dt><dd><a href="<?= e(url('/admin/providers/' . $payout['provider_id'] . '/edit')) ?>"><?= e($payout['business_name']) ?></a></dd>
                            <dt>Liên hệ</dt><dd><?= e($payout['contact_phone']) ?> · <?= e($payout['provider_email']) ?></dd>
<?php if ($hasBank): ?>
                            <dt>Ngân hàng</dt><dd><?= e($bank['name']) ?></dd>
                            <dt>Số tài khoản</dt><dd><strong><?= e($bank['no']) ?></strong></dd>
                            <dt>Chủ tài khoản</dt><dd><?= e($bank['holder']) ?></dd>
<?php endif; ?>
<?php if ($bankVerified): ?>
                            <dt>Xác minh</dt><dd id="payout-bank-state"><span class="lt-badge lt-badge--verified">Đã xác minh</span> <?= e(format_datetime((string) $payout['provider_bank_verified_at'])) ?><?= $payout['provider_bank_verified_by_name'] !== null ? ' · ' . e($payout['provider_bank_verified_by_name']) : '' ?></dd>
<?php elseif ($needsVerify): ?>
                            <dt>Xác minh</dt><dd id="payout-bank-state"><span class="lt-badge lt-badge--pending">Chưa xác minh</span></dd>
<?php endif; ?>
                        </dl>
<?php if (!$hasBank): ?>
                        <div class="lt-alert lt-alert--warning" role="note"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Đơn vị chưa khai tài khoản nhận tiền. Nhắc đơn vị khai ở mục “Tài khoản nhận tiền” của khu đơn vị tổ chức rồi mới chuyển khoản.</span></div>
<?php elseif ($needsVerify): ?>
                        <div class="lt-alert lt-alert--warning" role="note"><span class="lt-icon lt-icon--alert" aria-hidden="true"></span><span>Tài khoản này đơn vị mới khai hoặc vừa đổi. Trước khi bấm xác minh, hãy kiểm tra tài khoản với đơn vị ngoài hệ thống, ví dụ gọi số điện thoại liên hệ ở trên hoặc đối chiếu giấy tờ của đơn vị. Chưa xác minh thì chưa ghi nhận đã chi trả được.</span></div>
                        <form class="lt-admin-form" action="<?= e(url('/admin/payouts/' . $payout['payout_id'] . '/bank/verify')) ?>" method="post">
                            <?= csrf_field() ?>
                            <input type="hidden" name="bank_name" value="<?= e($bank['name']) ?>">
                            <input type="hidden" name="account_no" value="<?= e($bank['no']) ?>">
                            <input type="hidden" name="account_name" value="<?= e($bank['holder']) ?>">
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit"><span class="lt-icon lt-icon--check" aria-hidden="true"></span> Đã kiểm tra, xác minh tài khoản này</button>
                        </form>
                        <p class="lt-admin-hint">Đơn vị đổi tài khoản thì dấu xác minh bị xóa và phải xác minh lại.</p>
<?php elseif ($isPending): ?>
                        <p class="lt-admin-hint">Tài khoản đơn vị đang khai, đã được xác minh. Khi bấm “Ghi nhận đã chi trả”, hệ thống lưu lại tài khoản này cùng khoản chi trả. Đơn vị đổi tài khoản thì phải xác minh lại.</p>
<?php else: ?>
                        <p class="lt-admin-hint">Tài khoản đã nhận tiền, lưu lại lúc ghi nhận đã chi trả.</p>
<?php endif; ?>
                    </section>

                    <section class="lt-panel" aria-labelledby="payout-pay-title">
                        <h2 class="lt-panel__title" id="payout-pay-title">Chuyển khoản</h2>
<?php if ($isPending && !$hasBank): ?>
                        <p class="lt-empty">Chưa chuyển khoản được: đơn vị chưa khai tài khoản nhận tiền. Khi đơn vị khai xong, form ghi nhận đã chi trả sẽ hiện ở đây.</p>
<?php elseif ($needsVerify): ?>
                        <p class="lt-empty">Chưa chuyển khoản được: tài khoản nhận tiền của đơn vị chưa được xác minh. Xác minh tài khoản ở mục “Đơn vị nhận tiền” xong, form ghi nhận đã chi trả sẽ hiện ở đây.</p>
<?php elseif ($isPending): ?>
                        <p class="lt-admin__text">Chuyển <strong><?= e(format_vnd($payout['net_vnd'])) ?></strong> cho đơn vị bằng ngân hàng của LocalTour, rồi nhập mã giao dịch để ghi nhận. Hệ thống không tự chuyển tiền.</p>
                        <form class="lt-admin-form" action="<?= e(url('/admin/payouts/' . $payout['payout_id'] . '/pay')) ?>" method="post" novalidate>
                            <?= csrf_field() ?>
                            <input type="hidden" name="account_no" value="<?= e($bank['no']) ?>">
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="payout-reference">Mã giao dịch chuyển khoản</label>
                                <input class="lt-admin-input<?= $referenceError !== '' ? ' is-invalid' : '' ?>" type="text" id="payout-reference" name="reference" value="<?= e($old['reference']) ?>"
                                       maxlength="<?= e(PayoutModel::REFERENCE_MAX_LENGTH) ?>" autocomplete="off" required
                                       aria-describedby="payout-reference-hint<?= $referenceError !== '' ? ' payout-reference-error' : '' ?>"<?= $referenceError !== '' ? ' aria-invalid="true" autofocus' : '' ?>>
                                <p class="lt-admin-hint" id="payout-reference-hint">Mã tham chiếu trên biên lai chuyển khoản của ngân hàng. Đơn vị sẽ thấy mã này.</p>
<?php if ($referenceError !== ''): ?>
                                <p class="lt-admin-error" id="payout-reference-error"><?= e($referenceError) ?></p>
<?php endif; ?>
                            </div>
                            <div class="lt-admin-field">
                                <label class="lt-admin-label" for="payout-note">Ghi chú nội bộ (không bắt buộc)</label>
                                <input class="lt-admin-input<?= $noteError !== '' ? ' is-invalid' : '' ?>" type="text" id="payout-note" name="note" value="<?= e($old['note']) ?>"
                                       maxlength="<?= e(PayoutModel::NOTE_MAX_LENGTH) ?>"<?= $noteError !== '' ? ' aria-invalid="true" aria-describedby="payout-note-error"' : '' ?>>
<?php if ($noteError !== ''): ?>
                                <p class="lt-admin-error" id="payout-note-error"><?= e($noteError) ?></p>
<?php endif; ?>
                            </div>
                            <button class="lt-btn lt-btn--primary lt-btn--block" type="submit"><span class="lt-icon lt-icon--check" aria-hidden="true"></span> Ghi nhận đã chi trả</button>
                        </form>
<?php else: ?>
                        <dl class="lt-fields">
                            <dt>Mã giao dịch</dt><dd><strong><?= e($payout['transfer_reference']) ?></strong></dd>
                            <dt>Ghi nhận lúc</dt><dd><?= e(format_datetime((string) $payout['paid_at'])) ?><?= $payout['paid_by_name'] !== null ? ' · ' . e($payout['paid_by_name']) : '' ?></dd>
<?php if ($payout['note'] !== null): ?>
                            <dt>Ghi chú</dt><dd><?= e($payout['note']) ?></dd>
<?php endif; ?>
                        </dl>
<?php endif; ?>
                    </section>
                </div>
            </div>
        </main>
    </div>
</div>
