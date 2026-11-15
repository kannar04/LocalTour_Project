/*
 * LocalTour – account_email.js (Nguyễn Tuấn Khôi – NTK)
 * Ô email khi bật xác minh email (views/account/partials/email_verify.php; chỉ partial nạp file này):
 * - nút gửi mã (.js-email-wait, data-wait = số giây còn phải chờ) tạm khóa và đếm ngược đến khi gửi lại được;
 * - ô nhập mã (.js-email-code) chỉ giữ chữ số (mã dán từ email có thể kèm khoảng trắng);
 * - mỗi form chỉ gửi một lần (tránh bấm hai lần gửi hai mã).
 * Máy chủ vẫn kiểm tra lại mọi giới hạn. Dữ liệu chỉ đưa vào DOM bằng .text() / .prop().
 */
(function ($) {
    'use strict';

    function initWaitButtons() {
        $('.js-email-wait').each(function () {
            var $button = $(this);
            var left = parseInt($button.attr('data-wait'), 10) || 0;
            if (left <= 0) {
                return;
            }
            var label = $.trim($button.text());
            var timer = null;

            function tick() {
                if (left <= 0) {
                    window.clearInterval(timer);
                    $button.prop('disabled', false).text(label);
                    return;
                }
                $button.prop('disabled', true).text(label + ' (' + left + ' giây)');
                left -= 1;
            }

            tick();
            timer = window.setInterval(tick, 1000);
        });
    }

    function initCodeInputs() {
        $('.js-email-code').on('input', function () {
            var digits = this.value.replace(/\D+/g, '').slice(0, 6);
            if (digits !== this.value) {
                this.value = digits;
            }
        });
    }

    function initSubmitOnce() {
        $('.lt-email form').on('submit', function () {
            var $form = $(this);
            if ($form.data('ltSent')) {
                return false;
            }
            $form.data('ltSent', true);
            // Để sau sự kiện submit: account.js còn đổi ô mật khẩu về dạng ẩn trước khi gửi.
            window.setTimeout(function () {
                $form.find('button[type="submit"]').prop('disabled', true);
            }, 0);
            return true;
        });
        // Quay lại trang bằng nút Back (trang lấy từ bộ nhớ đệm): mở lại các form (nút đang đếm ngược tự khóa lại).
        $(window).on('pageshow', function (event) {
            if (event.originalEvent && event.originalEvent.persisted) {
                $('.lt-email form').removeData('ltSent').find('button[type="submit"]').prop('disabled', false);
            }
        });
    }

    $(function () {
        initWaitButtons();
        initCodeInputs();
        initSubmitOnce();
    });
})(jQuery);
