/*
 * LocalTour – payment-submit.js (Nguyễn Minh Thức)
 * Trang chọn phương thức thanh toán và trang chuyển khoản VietQR (Sprint 7, 6.6, góp ý UAT): bấm một nút thanh toán
 * (form .js-pay-once) thì nút đó đổi chữ (data-busy-text, mặc định "Đang gửi…") và mọi nút thanh toán trên trang bị khóa
 * tới khi chuyển trang, nên bấm liên tiếp hoặc mạng chậm không tạo nhiều lượt thanh toán / gửi trùng.
 * Quay lại trang bằng nút Back của trình duyệt thì các nút mở lại như cũ.
 */
(function (window, $) {
    'use strict';

    $(function () {
        var $forms = $('form.js-pay-once');
        if (!$forms.length) {
            return;
        }
        var $buttons = $forms.find('button[type="submit"]');
        var $status = $('.js-pay-status');
        var sending = false;

        $buttons.each(function () {
            $(this).attr('data-label', $(this).text());
        });

        $forms.on('submit', function (event) {
            if (sending) {
                event.preventDefault();
                return;
            }
            sending = true;
            var $form = $(this);
            // Khóa nút sau khi trình duyệt đã nhận lệnh gửi form (nút bị khóa ngay thì form không gửi được).
            window.setTimeout(function () {
                $buttons.prop('disabled', true);
                $form.find('button[type="submit"]').each(function () {
                    $(this).attr('aria-busy', 'true').text($(this).attr('data-busy-text') || 'Đang gửi…');
                });
                $status.text($form.attr('data-busy-status') || 'Đang tạo yêu cầu thanh toán, vui lòng đợi trong giây lát.')
                    .prop('hidden', false);
            }, 0);
        });

        // Trang lấy lại từ bộ nhớ đệm của trình duyệt (nút Back): mở lại các nút.
        $(window).on('pageshow', function (event) {
            if (event.originalEvent && event.originalEvent.persisted) {
                sending = false;
                $buttons.each(function () {
                    $(this).prop('disabled', false).removeAttr('aria-busy').text($(this).attr('data-label'));
                });
                $status.prop('hidden', true).text('');
            }
        });
    });
})(window, jQuery);
