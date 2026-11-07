/*
 * LocalTour – change-request.js (Nguyễn Tuấn Khôi)
 * Trang "Đổi ngày / hủy tour" (US14-S5-01): chỉ hiện ô "Ngày muốn đổi sang" khi khách chọn đổi ngày,
 * đếm ký tự lý do. Không có JavaScript thì form vẫn gửi được (server kiểm tra lại mọi ô).
 */
(function ($) {
    'use strict';

    $(function () {
        var $types = $('.js-change-type');
        var $schedule = $('.js-change-schedule');
        var $select = $schedule.find('select');
        var $reason = $('#change-reason');
        var $count = $('#change-reason-count');
        var max = parseInt($reason.attr('maxlength'), 10) || 500;

        function syncType() {
            var isChange = $types.filter(':checked').val() === 'change_date';
            $schedule.prop('hidden', !isChange);
            $select.prop('required', isChange);
        }

        function syncCount() {
            $count.text(String($reason.val() || '').length + '/' + max + ' ký tự');
        }

        $types.on('change', syncType);
        $reason.on('input', syncCount);
        syncType();
        syncCount();
    });
})(jQuery);
