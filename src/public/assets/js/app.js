/*
 * LocalTour – app.js (Nguyễn Tuấn Khôi)
 * Tiện ích dùng chung cho mọi trang: window.LocalTour = { baseUrl, url(path), formatVnd(n), ... }.
 * Quy ước: dữ liệu từ server chỉ được đưa vào DOM bằng .text() / .attr(), không ghép chuỗi HTML.
 * CR2: nút "Menu" trên máy tính (ẩn/hiện cột trái của bảng tin, nhớ trong localStorage; trang khác mở ngăn menu nổi)
 * và ảnh đại diện ở header không tải được thì đổi về chữ cái đầu tên.
 * Sprint 7 (6.6): bấm ra ngoài thì menu đóng ở mọi cỡ màn hình (UAT-64).
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

    /** localStorage có thể bị chặn (chế độ riêng tư): lỗi thì coi như không lưu. */
    function storageGet(key) {
        try {
            return window.localStorage.getItem(key);
        } catch (error) {
            return null;
        }
    }

    function storageSet(key, value) {
        try {
            if (value === null) {
                window.localStorage.removeItem(key);
            } else {
                window.localStorage.setItem(key, value);
            }
        } catch (error) {
            // Không lưu được thì lần sau dùng trạng thái mặc định.
        }
    }

    /** Ảnh đại diện ở header không tải được: đổi về ô chữ cái đầu tên. */
    function replaceBrokenAvatar(img) {
        var $img = $(img);
        var classes = String($img.attr('class') || '').replace(/\b(lt-avatar--img|js-avatar-img)\b/g, '').trim();
        $img.replaceWith($('<span>').attr({ 'class': classes, 'aria-hidden': 'true' }).text($img.attr('data-initial') || ''));
    }

    // Sự kiện error của <img> không nổi bọt: nghe ở pha capture. Ảnh lỗi trước khi script chạy được kiểm tra lúc sẵn sàng.
    document.addEventListener('error', function (event) {
        var target = event.target;
        if (target && target.tagName === 'IMG' && $(target).hasClass('js-avatar-img')) {
            replaceBrokenAvatar(target);
        }
    }, true);

    var SIDEBAR_HIDDEN_KEY = 'lt.sidebarHidden';

    /** Bảng tin trên máy tính: ẩn/hiện cột trái (body.lt-sidebar-hidden), nhớ lựa chọn trong localStorage. */
    function setColumnHidden(hidden, remember) {
        $('body').toggleClass('lt-sidebar-hidden', hidden);
        $('.js-menu-desktop').attr('aria-expanded', hidden ? 'false' : 'true');
        if (remember) {
            storageSet(SIDEBAR_HIDDEN_KEY, hidden ? '1' : null);
        }
    }

    // Áp trạng thái đã nhớ ngay khi script chạy (cuối <body>) để cột trái không nháy lên rồi mới ẩn.
    if (document.querySelector('.js-menu-desktop[data-menu-mode="column"]') && storageGet(SIDEBAR_HIDDEN_KEY) === '1') {
        setColumnHidden(true, false);
    }

    window.LocalTour = {
        baseUrl: baseUrl,
        url: url,
        formatVnd: formatVnd,
        icon: icon,
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
        // Link đang tạm tắt (vd. nút so sánh khi chưa đủ 2 tour) không điều hướng.
        $(document).on('click', 'a[aria-disabled="true"]', function (event) {
            event.preventDefault();
        });

        // Nút "In" (voucher): mở hộp thoại in của trình duyệt.
        $(document).on('click', '.js-print', function () {
            window.print();
        });

        $('img.js-avatar-img').each(function () {
            if (this.complete && this.naturalWidth === 0) {
                replaceBrokenAvatar(this);
            }
        });

        var $sidebar = $('#lt-sidebar');
        var $desktopMenu = $('.js-menu-desktop');
        if (!$sidebar.length) {
            $('.js-menu-toggle').addClass('d-none');
            $desktopMenu.addClass('d-none');
            return;
        }

        var isDesktop = function () {
            return window.innerWidth >= 992;
        };
        var isDrawer = $desktopMenu.attr('data-menu-mode') === 'drawer';

        if ($sidebar.attr('data-destination-mode') === 'link') {
            $sidebar.one('show.bs.collapse', function () {
                loadDestinationLinks($('#sidebar-destinations'));
            });
        }

        // Nút "Menu" trên máy tính. Cột trái: ẩn/hiện cột. Trang khác: mở/đóng ngăn menu nổi (cùng collapse với mobile).
        $desktopMenu.on('click', function () {
            if (isDrawer) {
                $sidebar.collapse('toggle');
            } else {
                setColumnHidden(!$('body').hasClass('lt-sidebar-hidden'), true);
            }
        });

        if (isDrawer) {
            $sidebar.on('shown.bs.collapse hidden.bs.collapse', function (event) {
                if (event.target === $sidebar[0]) {
                    $desktopMenu.attr('aria-expanded', $sidebar.hasClass('show') ? 'true' : 'false');
                }
            });

        }

        // Bấm ra ngoài menu thì đóng (góp ý UAT-64): ngăn menu nổi trên máy tính và panel menu trên màn hình nhỏ.
        // Cột trái của bảng tin trên máy tính luôn hiện nên không đóng.
        $(document).on('click', function (event) {
            if (!$sidebar.hasClass('show') || (isDesktop() && !isDrawer)) {
                return;
            }
            if (!$(event.target).closest('#lt-sidebar, .js-menu-desktop, .js-menu-toggle').length) {
                $sidebar.collapse('hide');
            }
        });

        // Thu panel / ngăn menu lại bằng phím Esc và trả focus cho nút Menu đang hiện.
        $(document).on('keydown', function (event) {
            if (event.key !== 'Escape' || !$sidebar.hasClass('show')) {
                return;
            }
            if (!isDesktop()) {
                $sidebar.collapse('hide');
                $('.js-menu-toggle').trigger('focus');
            } else if (isDrawer) {
                $sidebar.collapse('hide');
                $desktopMenu.trigger('focus');
            }
        });
    });
})(window, document, jQuery);
