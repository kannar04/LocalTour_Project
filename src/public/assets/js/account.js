/*
 * LocalTour – account.js (CR2 – Lê Trung Phong)
 * Trang "Tài khoản": xem trước ảnh đại diện và kiểm tra loại / dung lượng / kích thước ngay khi chọn file
 * (máy chủ vẫn kiểm tra lại), hỏi lại trước khi xóa ảnh, nút hiện / ẩn mật khẩu.
 * Sprint 7 (6.6, UAT-63): ô "Địa chỉ" đếm số ký tự còn lại và cắt phần gõ / dán vượt 255 ký tự.
 * Dữ liệu chỉ đưa vào DOM bằng .text() / .attr().
 */
(function ($) {
    'use strict';

    var TYPES = ['image/jpeg', 'image/png', 'image/webp'];
    var EXTENSIONS = /\.(jpe?g|png|webp)$/i;

    function initAvatar() {
        var $form = $('.js-avatar-form');
        if (!$form.length) {
            return;
        }

        var $input = $form.find('.js-avatar-input');
        var $error = $form.find('.js-avatar-error');
        var $name = $form.find('.js-avatar-name');
        var $preview = $('.js-avatar-preview');
        var original = $preview.children().clone();
        var maxBytes = parseInt($form.attr('data-max-bytes'), 10) || 2097152;
        var minSide = parseInt($form.attr('data-min-side'), 10) || 64;
        var maxSide = parseInt($form.attr('data-max-side'), 10) || 4096;
        var objectUrl = null;
        var checking = false;

        function showError(message) {
            $error.text(message).prop('hidden', message === '');
            if (message === '') {
                $input.removeAttr('aria-invalid');
            } else {
                $input.attr('aria-invalid', 'true');
            }
        }

        function restorePreview() {
            if (objectUrl) {
                URL.revokeObjectURL(objectUrl);
                objectUrl = null;
            }
            $preview.empty().append(original.clone());
        }

        function reject(message) {
            $input.val('');
            $name.text('');
            restorePreview();
            showError(message);
        }

        $input.on('change', function () {
            var file = this.files && this.files[0];
            showError('');
            if (!file) {
                $name.text('');
                restorePreview();
                return;
            }
            if (TYPES.indexOf(file.type) === -1 || !EXTENSIONS.test(file.name)) {
                reject('Chỉ nhận ảnh JPG, PNG hoặc WebP.');
                return;
            }
            if (file.size > maxBytes) {
                reject('Ảnh tối đa ' + Math.round(maxBytes / 1048576) + ' MB.');
                return;
            }
            if (!window.URL || !URL.createObjectURL) {
                $name.text('Đã chọn: ' + file.name);
                return;
            }

            restorePreview();
            objectUrl = URL.createObjectURL(file);
            checking = true;
            $name.text('Đang kiểm tra ảnh ' + file.name + '…');
            var image = new Image();
            image.onload = function () {
                checking = false;
                var shortest = Math.min(image.naturalWidth, image.naturalHeight);
                var longest = Math.max(image.naturalWidth, image.naturalHeight);
                if (shortest < minSide || longest > maxSide) {
                    reject('Ảnh cần có cạnh từ ' + minSide + ' đến ' + maxSide + ' px.');
                    return;
                }
                $preview.empty().append(
                    $('<img>').attr({ src: objectUrl, alt: 'Xem trước ảnh đại diện mới', width: 96, height: 96 })
                );
                $name.text('Đã chọn: ' + file.name + '. Bấm "Lưu ảnh" để cập nhật.');
            };
            image.onerror = function () {
                checking = false;
                reject('Không đọc được ảnh này, vui lòng chọn ảnh khác.');
            };
            image.src = objectUrl;
        });

        $form.on('submit', function (event) {
            if (checking) {
                event.preventDefault();
                $name.text('Đang kiểm tra ảnh, vui lòng bấm "Lưu ảnh" lại sau giây lát.');
                return;
            }
            if (!$input[0].files || !$input[0].files.length) {
                event.preventDefault();
                showError('Vui lòng chọn ảnh.');
                $input.trigger('focus');
                return;
            }
            $form.find('.js-avatar-submit').prop('disabled', true).text('Đang tải lên…');
        });
    }

    function initConfirm() {
        $('.js-confirm-form').on('submit', function (event) {
            var message = $(this).attr('data-confirm');
            if (message && !window.confirm(message)) {
                event.preventDefault();
            }
        });
    }

    function initPasswordToggles() {
        $('.js-password-toggle').each(function () {
            var $button = $(this);
            var $input = $('#' + $button.attr('aria-controls'));
            if (!$input.length) {
                return;
            }
            $button.prop('hidden', false).on('click', function () {
                var show = $input.attr('type') === 'password';
                $input.attr('type', show ? 'text' : 'password');
                $button.attr({
                    'aria-pressed': show ? 'true' : 'false',
                    'aria-label': show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'
                });
                $button.find('.lt-icon').toggleClass('lt-icon--eye', !show).toggleClass('lt-icon--eye-off', show);
            });
        });
        // Gửi form thì ẩn lại mật khẩu (trình duyệt không lưu ô dạng text).
        $('.js-password-toggle').closest('form').on('submit', function () {
            $(this).find('.js-password-toggle[aria-pressed="true"]').trigger('click');
        });
    }

    /**
     * Ô có giới hạn ký tự (.js-char-limit, vd. "Địa chỉ"): hiện số ký tự còn lại; nội dung gõ hoặc dán vượt giới hạn
     * (kể cả công cụ điền form bỏ qua maxlength) được cắt về đúng giới hạn và báo cho người dùng.
     */
    function initCharLimits() {
        $('.js-char-limit').each(function () {
            var $input = $(this);
            var max = parseInt($input.attr('maxlength'), 10);
            var $count = $('#' + $input.attr('data-count-id'));
            var $left = $count.find('.js-char-count');
            var $trimmed = $count.find('.js-char-trimmed');
            if (!max || !$count.length) {
                return;
            }

            function update(event) {
                var value = String($input.val());
                if (value.length > max) {
                    var cut = value.slice(0, max);
                    // Không để lại nửa ký tự (cặp surrogate bị cắt đôi).
                    if (/[\uD800-\uDBFF]$/.test(cut)) {
                        cut = cut.slice(0, -1);
                    }
                    $input.val(cut);
                    value = cut;
                    $trimmed.text('Chỉ giữ ' + max + ' ký tự đầu, phần dư đã bị bỏ.');
                } else if (event) {
                    $trimmed.text('');
                }
                $left.text('Còn ' + Math.max(0, max - value.length) + ' ký tự.');
            }

            $input.on('input change', update);
            update(null);
        });
    }

    $(function () {
        initAvatar();
        initConfirm();
        initPasswordToggles();
        initCharLimits();
    });
})(jQuery);
