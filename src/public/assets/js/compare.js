/*
 * LocalTour – compare.js (Nguyễn Tuấn Khôi)
 * So sánh tour (US04-S5-01, FR-15): khách chọn / bỏ tour để so sánh, tối đa 3 tour, lưu trong localStorage
 * của trình duyệt (không cần đăng nhập).
 *   - Nút .js-compare-toggle [data-tour-id, data-tour-title, data-tour-image] trên thẻ tour và trang chi tiết;
 *   - Khung "Tour đang so sánh" ở bảng tin (#compare-panel) và thanh so sánh dưới màn hình (#compare-bar);
 *   - Link .js-compare-link mở /compare?ids=<mã 1>,<mã 2>,... theo các tour đã chọn;
 *   - Trang /compare (#compare-data): đồng bộ danh sách theo các tour server trả về, nút "Bỏ khỏi so sánh".
 * Chọn tour thứ 4 bị chặn kèm thông báo; server cũng chỉ nhận tối đa 3 tour (CompareController).
 * window.LocalTourCompare = { MAX, MIN, list(), has(id), compareUrl(), sync() }.
 */
(function (window, document, $) {
    'use strict';

    var KEY = 'localtour.compare';
    var FLASH_KEY = 'localtour.compare.flash'; // Thông báo chờ hiện sau khi trang /compare tải lại.
    var MAX = 3;
    var MIN = 2;
    var LIMIT_MESSAGE = 'Chỉ so sánh tối đa ' + MAX + ' tour. Bỏ bớt một tour trước khi thêm tour khác.';
    var memory = []; // Khi trình duyệt chặn localStorage: chỉ giữ trong trang đang mở.
    var LT = null;
    var toastTimer = null;

    function store() {
        try {
            return window.localStorage || null;
        } catch (error) {
            return null;
        }
    }

    /** Ảnh chỉ nhận đường dẫn trong site hoặc http(s). */
    function safeImage(value) {
        var text = String(value || '');
        return /^(https?:\/\/|\/)/i.test(text) ? text : '';
    }

    /** Danh sách đã chọn: [{ id, title, image }], bỏ mã sai dạng / trùng, tối đa MAX. */
    function list() {
        var items = memory;
        var storage = store();
        if (storage) {
            try {
                items = JSON.parse(storage.getItem(KEY) || '[]');
            } catch (error) {
                items = [];
            }
        }

        var seen = Object.create(null);
        var clean = [];
        $.each($.isArray(items) ? items : [], function (index, item) {
            var id = LT.normaliseId(item && item.id);
            if (id && !seen[id] && clean.length < MAX) {
                seen[id] = true;
                clean.push({ id: id, title: String((item && item.title) || 'Tour').slice(0, 300), image: safeImage(item && item.image) });
            }
        });
        return clean;
    }

    function save(items) {
        memory = items.slice(0, MAX);
        var storage = store();
        if (storage) {
            try {
                storage.setItem(KEY, JSON.stringify(memory));
            } catch (error) {
                // Bộ nhớ đầy / bị chặn: vẫn dùng được trong trang này.
            }
        }
        sync();
    }

    function has(id) {
        id = LT.normaliseId(id);
        return $.grep(list(), function (item) { return item.id === id; }).length > 0;
    }

    function compareUrl(items) {
        items = items || list();
        var ids = $.map(items, function (item) { return item.id; });
        return LT.url('/compare') + (ids.length ? '?ids=' + ids.join(',') : '');
    }

    /** Thêm / bỏ một tour. Trả false khi đã đủ MAX tour (không thêm). */
    function toggle(tour) {
        var id = LT.normaliseId(tour && tour.id);
        if (!id) {
            return false;
        }
        var items = list();
        if (has(id)) {
            save($.grep(items, function (item) { return item.id !== id; }));
            notify('Đã bỏ "' + String(tour.title || 'tour') + '" khỏi so sánh.');
            return true;
        }
        if (items.length >= MAX) {
            notify(LIMIT_MESSAGE, true);
            return false;
        }
        items.push({ id: id, title: String(tour.title || 'Tour'), image: safeImage(tour.image) });
        save(items);
        notify(items.length >= MIN
            ? 'Đã thêm vào so sánh (' + items.length + '/' + MAX + ' tour).'
            : 'Đã thêm vào so sánh. Chọn thêm ít nhất 1 tour để so sánh.');
        return true;
    }

    function remove(id) {
        id = LT.normaliseId(id);
        save($.grep(list(), function (item) { return item.id !== id; }));
    }

    /* ---------- Thông báo ngắn (vùng aria-live) ---------- */

    function notify(message, isWarning) {
        var $toast = $('#compare-toast');
        if (!$toast.length) {
            $toast = $('<div>').attr({ id: 'compare-toast', role: 'status', 'aria-live': 'polite' }).addClass('lt-compare-toast');
            $('body').append($toast);
        }
        $toast.toggleClass('is-warning', !!isWarning).text(message).addClass('is-visible');
        window.clearTimeout(toastTimer);
        toastTimer = window.setTimeout(function () {
            $toast.removeClass('is-visible');
        }, 4000);
    }

    /** Trang /compare tải lại theo danh sách mới: giữ thông báo trong sessionStorage để hiện sau khi tải. */
    function reloadWithMessage(message) {
        try {
            window.sessionStorage.setItem(FLASH_KEY, message);
        } catch (error) {
            // Bị chặn sessionStorage: trang vẫn tải lại, chỉ mất thông báo.
        }
        window.location.assign(compareUrl());
    }

    function showPendingMessage() {
        var message = null;
        try {
            message = window.sessionStorage.getItem(FLASH_KEY);
            window.sessionStorage.removeItem(FLASH_KEY);
        } catch (error) {
            return;
        }
        if (message) {
            notify(message);
        }
    }

    /* ---------- Hiển thị theo danh sách hiện tại ---------- */

    function renderButtons(items) {
        var ids = Object.create(null);
        $.each(items, function (index, item) { ids[item.id] = true; });

        $('.js-compare-toggle').each(function () {
            var $button = $(this);
            var active = !!ids[LT.normaliseId($button.attr('data-tour-id'))];
            $button.toggleClass('is-active', active).attr('aria-pressed', active ? 'true' : 'false');
            $button.find('.js-compare-label').text(active ? 'Đã thêm vào so sánh' : 'Thêm vào so sánh');
            $button.find('.lt-icon').first().toggleClass('lt-icon--check', active).toggleClass('lt-icon--columns', !active);
        });
    }

    function renderPanel(items) {
        var $panel = $('#compare-panel');
        if (!$panel.length) {
            return;
        }
        var $slots = $panel.find('.js-compare-slots').empty();
        for (var slot = 0; slot < MAX; slot++) {
            var item = items[slot];
            var $li = $('<li>').addClass('lt-compare__slot' + (item ? ' is-filled' : ''));
            $li.append($('<span>').addClass('lt-compare__num').text(slot + 1));
            if (item) {
                $li.append(
                    $('<a>').addClass('lt-compare__name').attr('href', LT.url('/tours/' + item.id)).text(item.title),
                    $('<button>').addClass('lt-compare__remove js-compare-remove')
                        .attr({ type: 'button', 'data-tour-id': item.id, 'aria-label': 'Bỏ "' + item.title + '" khỏi so sánh' })
                        .append(LT.icon('x'))
                );
            } else {
                $li.append($('<span>').addClass('lt-compare__hint').text(slot === items.length
                    ? 'Bấm “Thêm vào so sánh” trên thẻ tour'
                    : 'Ô so sánh trống'));
            }
            $slots.append($li);
        }

        var ready = items.length >= MIN;
        $panel.find('.js-compare-count').text(items.length + '/' + MAX + ' tour');
        $panel.find('.js-compare-note').text(ready
            ? 'Bấm "So sánh tour" để xem các tour cạnh nhau.'
            : 'Chọn ' + MIN + '–' + MAX + ' tour để so sánh' + (items.length ? ' (cần thêm ' + (MIN - items.length) + ' tour).' : '.'));
        $panel.find('.js-compare-clear').prop('hidden', !items.length);
    }

    function renderBar(items) {
        var $bar = $('#compare-bar');
        if (!$bar.length) {
            return;
        }
        $bar.prop('hidden', !items.length);
        $bar.find('.js-compare-bar-text').text(items.length + '/' + MAX + ' tour đang so sánh');
    }

    /** Link / nút "So sánh tour": đủ 2 tour mới bấm được. */
    function renderLinks(items) {
        var ready = items.length >= MIN;
        var href = compareUrl(items);
        $('.js-compare-link').attr('href', href);
        $('.js-compare-go').each(function () {
            var $link = $(this).attr('href', href);
            $link.toggleClass('is-disabled', !ready).attr('aria-disabled', ready ? null : 'true');
        });
        $('.js-compare-status').text(items.length
            ? 'Đang chọn ' + items.length + '/' + MAX + ' tour để so sánh.'
            : 'Chọn 2–3 tour để so sánh giá, lịch trình và chính sách.');
    }

    function sync() {
        var items = list();
        renderButtons(items);
        renderPanel(items);
        renderBar(items);
        renderLinks(items);
    }

    /* ---------- Trang /compare ---------- */

    function readCompareData() {
        var node = document.getElementById('compare-data');
        if (!node) {
            return null;
        }
        try {
            var data = JSON.parse(node.textContent || 'null');
            return data && $.isArray(data.tours) ? data : null;
        } catch (error) {
            return null;
        }
    }

    /**
     * Mở /compare không kèm mã tour mà trình duyệt đã có danh sách: chuyển sang đúng danh sách đó.
     * Có mã tour: lưu lại danh sách server trả về (tour bị ẩn / không có đã bị bỏ).
     */
    function initComparePage() {
        var data = readCompareData();
        if (!data) {
            return;
        }
        if (!data.requested) {
            if (list().length) {
                window.location.replace(compareUrl());
            }
            return;
        }
        save($.map(data.tours, function (tour) {
            return tour && tour.id ? { id: tour.id, title: tour.title, image: tour.image } : null;
        }));
    }

    $(function () {
        LT = window.LocalTour;
        if (!LT) {
            return;
        }

        $(document).on('click', '.js-compare-toggle', function () {
            var $button = $(this);
            toggle({
                id: $button.attr('data-tour-id'),
                title: $button.attr('data-tour-title'),
                image: $button.attr('data-tour-image')
            });
        });

        $(document).on('click', '.js-compare-remove', function () {
            var id = LT.normaliseId($(this).attr('data-tour-id'));
            var tour = $.grep(list(), function (item) { return item.id === id; })[0];
            remove(id);
            // Trang so sánh: tải lại theo danh sách mới.
            if (document.getElementById('compare-data')) {
                reloadWithMessage('Đã bỏ "' + String((tour && tour.title) || 'tour') + '" khỏi so sánh.');
            }
        });

        $(document).on('click', '.js-compare-clear', function () {
            save([]);
            if (document.getElementById('compare-data')) {
                reloadWithMessage('Đã xóa danh sách so sánh.');
                return;
            }
            notify('Đã xóa danh sách so sánh.');
        });

        $(document).on('click', '.js-compare-go', function (event) {
            if (list().length < MIN) {
                event.preventDefault();
                notify('Chọn ít nhất ' + MIN + ' tour để so sánh.', true);
            }
        });

        // Tab khác vừa đổi danh sách: cập nhật lại nút và khung so sánh.
        $(window).on('storage', function (event) {
            if (event.originalEvent && event.originalEvent.key === KEY) {
                sync();
            }
        });

        initComparePage();
        sync();
        showPendingMessage();
    });

    window.LocalTourCompare = {
        MAX: MAX,
        MIN: MIN,
        list: function () { return LT ? list() : []; },
        has: function (id) { return LT ? has(id) : false; },
        compareUrl: function () { return LT ? compareUrl() : ''; },
        sync: function () { if (LT) { sync(); } }
    };
})(window, document, jQuery);
