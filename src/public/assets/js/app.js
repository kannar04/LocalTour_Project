/*
 * LocalTour – app.js (Nguyễn Tuấn Khôi)
 * Tiện ích dùng chung cho mọi trang: window.LocalTour = { baseUrl, url(path), formatVnd(n), ... }.
 * Quy ước: dữ liệu từ server chỉ được đưa vào DOM bằng .text() / .attr(), không ghép chuỗi HTML.
 */
(function (window, document, $) {
    'use strict';

    var metaBase = document.querySelector('meta[name="app-base-url"]');
    var baseUrl = String((metaBase && metaBase.getAttribute('content')) || '/').replace(/\/+$/, '');

    /** url('/api/tours') -> '<thư mục gốc>/api/tours' */
    function url(path) {
        var cleanPath = String(path === undefined || path === null ? '' : path).replace(/^\/+/, '');
        return baseUrl + '/' + cleanPath;
    }

    /** 650000 -> '650.000đ' */
    function formatVnd(amount) {
        var value = Math.round(Number(amount) || 0);
        var sign = value < 0 ? '-' : '';
        return sign + String(Math.abs(value)).replace(/\B(?=(\d{3})+(?!\d))/g, '.') + 'đ';
    }

    /** Icon trang trí: <span class="lt-icon lt-icon--name" aria-hidden="true">. */
    function icon(name) {
        return $('<span>').addClass('lt-icon lt-icon--' + name).attr('aria-hidden', 'true');
    }

    /** Nhãn nhỏ "Sắp có" cho chức năng chưa làm. */
    function soonBadge() {
        return $('<span>').addClass('lt-soon').text('Sắp có');
    }

    var UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    /** UUID chữ thường nếu đúng định dạng, ngược lại '' (= tất cả / không hợp lệ). */
    function normaliseId(value) {
        var text = String(value === undefined || value === null ? '' : value).trim();
        return UUID_PATTERN.test(text) ? text.toLowerCase() : '';
    }

    /** Link lọc theo điểm đến; id '' = tất cả. */
    function destinationHref(id) {
        return id ? url('/tours') + '?destination_id=' + encodeURIComponent(id) : url('/tours');
    }

    /** Đánh dấu điểm đến đang chọn trong danh sách ở thanh bên. */
    function setActiveDestination($list, id) {
        var activeId = normaliseId(id);
        $list.find('.lt-dest-link').each(function () {
            var isActive = normaliseId($(this).attr('data-destination-id')) === activeId;
            $(this).toggleClass('is-active', isActive);
            if (isActive) {
                $(this).attr('aria-current', 'true');
            } else {
                $(this).removeAttr('aria-current');
            }
        });
    }

    /** Dựng danh sách điểm đến (kèm số tour) trong #sidebar-destinations; điểm đến được nhận diện bằng destination_id. */
    function renderDestinationNav($list, destinations, activeId) {
        var total = 0;
        var items = [];

        $.each(destinations, function (index, destination) {
            total += Number(destination.tour_count) || 0;
        });

        items.push(buildDestinationItem('', 'Tất cả điểm đến', total));
        $.each(destinations, function (index, destination) {
            var id = normaliseId(destination.destination_id);
            var name = String(destination.name || '').trim();
            if (id && name) {
                items.push(buildDestinationItem(id, name, Number(destination.tour_count) || 0));
            }
        });

        $list.empty().append(items);
        setActiveDestination($list, activeId);
    }

    function buildDestinationItem(id, label, count) {
        var $link = $('<a>')
            .addClass('lt-dest-link')
            .attr('href', destinationHref(id))
            .attr('data-destination-id', id)
            .append(
                $('<span>').addClass('lt-dest-link__name').text(label),
                $('<span>').addClass('lt-dest-link__count')
                    .append(document.createTextNode(String(count)), $('<span>').addClass('sr-only').text(' tour'))
            );
        return $('<li>').append($link);
    }

    function renderDestinationStatus($list, message) {
        $list.empty().append($('<li>').addClass('lt-dest-list__status').text(message));
    }

    /** Ở trang không phải bảng tin: tải điểm đến khi mở menu lần đầu (link chuyển về bảng tin đã lọc). */
    function loadDestinationLinks($list) {
        renderDestinationStatus($list, 'Đang tải điểm đến…');
        $.getJSON(url('/api/destinations'))
            .done(function (response) {
                var list = response && response.success && response.data && response.data.destinations;
                if ($.isArray(list)) {
                    renderDestinationNav($list, list, null);
                    $list.find('.lt-dest-link').removeClass('is-active').removeAttr('aria-current');
                } else {
                    renderDestinationStatus($list, 'Không tải được điểm đến.');
                }
            })
            .fail(function () {
                renderDestinationStatus($list, 'Không tải được điểm đến.');
            });
    }

    window.LocalTour = {
        baseUrl: baseUrl,
        url: url,
        formatVnd: formatVnd,
        icon: icon,
        soonBadge: soonBadge,
        normaliseId: normaliseId,
        destinationHref: destinationHref,
        renderDestinationNav: renderDestinationNav,
        renderDestinationStatus: renderDestinationStatus,
        setActiveDestination: setActiveDestination,
        prefersReducedMotion: function () {
            return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
        }
    };

    $(function () {
        // Link "Sắp có" (nếu có) không bao giờ điều hướng.
        $(document).on('click', 'a[aria-disabled="true"]', function (event) {
            event.preventDefault();
        });

        var $sidebar = $('#lt-sidebar');
        if (!$sidebar.length) {
            $('.js-menu-toggle').addClass('d-none');
            return;
        }

        if ($sidebar.attr('data-destination-mode') === 'link') {
            $sidebar.one('show.bs.collapse', function () {
                loadDestinationLinks($('#sidebar-destinations'));
            });
        }

        // Thu panel lại bằng phím Esc trên mobile và trả focus cho nút Menu.
        $(document).on('keydown', function (event) {
            if (event.key === 'Escape' && $sidebar.hasClass('show') && window.innerWidth < 992) {
                $sidebar.collapse('hide');
                $('.js-menu-toggle').trigger('focus');
            }
        });
    });
})(window, document, jQuery);
