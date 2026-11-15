/*
 * LocalTour – booking-review.js (Nguyễn Tuấn Khôi)
 * Thẻ "Đánh giá tour" trên trang đơn (FR-16, CR3): tô các sao tới số sao đã chọn, hiện lời mô tả (Tệ … Tuyệt vời)
 * và đếm ký tự nhận xét. Không có JavaScript thì form vẫn gửi được (server kiểm tra lại mọi ô).
 */
(function ($) {
    'use strict';

    $(function () {
        var $picker = $('.js-star-picker');
        var $word = $('.js-star-word');
        var $content = $('.js-review-content');
        var $count = $('.js-review-count');
        var max = parseInt($content.attr('maxlength'), 10) || 1000;

        function syncStars() {
            var value = parseInt($picker.find('input:checked').val(), 10) || 0;
            $picker.find('.lt-star-picker__label').each(function (index) {
                $(this).toggleClass('is-lit', index < value);
            });
            if (value > 0) {
                $word.text(value + ' sao · ' + $picker.find('label[for="review-rating-' + value + '"]').attr('data-word'));
            }
        }

        function syncCount() {
            $count.text(String($content.val() || '').length + '/' + max + ' ký tự');
        }

        $picker.on('change', 'input', syncStars);
        $content.on('input', syncCount);
        if ($picker.length) {
            syncStars();
        }
        if ($content.length) {
            syncCount();
        }
    });
})(jQuery);
