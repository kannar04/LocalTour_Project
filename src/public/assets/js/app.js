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

    var DESTINATION_MAX_LENGTH = 100;

    /** Tên điểm đến dùng để lọc: bỏ khoảng trắng hai đầu, tối đa 100 ký tự; '' = tất cả. */
    function normaliseDestination(value) {
        var text = String(value === undefined || value === null ? '' : value).trim();
        return text.slice(0, DESTINATION_MAX_LENGTH).trim();
    }

    /** Khóa so sánh tên điểm đến: không phân biệt hoa thường và dấu thanh ("ha noi" = "Hà Nội"); "d" khác "đ" như CSDL. */
    function destinationKey(name) {
        return normaliseDestination(name).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
    }

    /** Link lọc theo điểm đến; name '' = tất cả. */
    function destinationHref(name) {
        return name ? url('/tours') + '?destination=' + encodeURIComponent(name) : url('/tours');
    }

    /** Đánh dấu điểm đến đang chọn trong danh sách ở thanh bên. */
    function setActiveDestination($list, name) {
        var activeKey = destinationKey(name);
        $list.find('.lt-dest-link').each(function () {
            var isActive = destinationKey($(this).attr('data-destination')) === activeKey;
            $(this).toggleClass('is-active', isActive);
            if (isActive) {
                $(this).attr('aria-current', 'true');
            } else {
                $(this).removeAttr('aria-current');
            }
        });
    }

    /** Dựng danh sách điểm đến (kèm số tour) trong #sidebar-destinations; điểm đến được nhận diện bằng tên. */
    function renderDestinationNav($list, destinations, activeName) {
        var total = 0;
        var items = [];

        $.each(destinations, function (index, destination) {
            total += Number(destination.tour_count) || 0;
        });

        items.push(buildDestinationItem('', 'Tất cả điểm đến', total));
        $.each(destinations, function (index, destination) {
            var name = normaliseDestination(destination.name);
            if (name) {
                items.push(buildDestinationItem(name, name, Number(destination.tour_count) || 0));
            }
        });

        $list.empty().append(items);
        setActiveDestination($list, activeName);
    }

    function buildDestinationItem(name, label, count) {
        var $link = $('<a>')
            .addClass('lt-dest-link')
            .attr('href', destinationHref(name))
            .attr('data-destination', name)
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
        normaliseDestination: normaliseDestination,
        destinationKey: destinationKey,
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
