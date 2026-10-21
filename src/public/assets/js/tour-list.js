/*
 * LocalTour – tour-list.js (Nguyễn Tuấn Khôi)
 * Bảng tin du lịch: tải /api/destinations và /api/tours bằng AJAX, hiển thị skeleton / thẻ tour /
 * trạng thái rỗng / lỗi; tìm kiếm, lọc điểm đến, sắp xếp không tải lại trang và giữ URL đồng bộ.
 * Mọi dữ liệu từ server được đưa vào DOM bằng .text() / .attr().
 */
(function (window, document, $) {
    'use strict';

    var SORTS = ['recommended', 'newest', 'price_asc', 'price_desc'];
    var DEFAULT_SORT = 'recommended';
    var QUERY_MAX_LENGTH = 100;
    var SEARCH_DELAY_MS = 400;
    var REQUEST_TIMEOUT_MS = 15000;
    var GENERIC_ERROR = 'Máy chủ đang bận hoặc mất kết nối. Vui lòng thử lại sau ít phút.';
    var TIMEOUT_ERROR = 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.';
    var INTERACTIONS = [
        { icon: 'heart', label: 'Thích' },
        { icon: 'message', label: 'Bình luận' },
        { icon: 'share', label: 'Chia sẻ' },
        { icon: 'bookmark', label: 'Lưu' }
    ];

    $(function () {
        var LT = window.LocalTour;
        var $page = $('#tour-list-page');
        if (!$page.length || !LT) {
            return;
        }

        var $searchForm = $('#header-search');
        var $searchInput = $('#header-search-input');
        var $destinationSelect = $('#filter-destination');
        var $sortTabs = $('.js-sort-tab');
        var $priceSort = $('#sort-price');
        var $count = $('#tour-count');
        var $loading = $('#tour-loading');
        var $feed = $('#tour-feed');
        var $empty = $('#tour-empty');
        var $emptyText = $('#tour-empty-text');
        var $error = $('#tour-error');
        var $errorMessage = $('#tour-error-message');
        var $sidebar = $('#lt-sidebar');
        var $sidebarList = $('#sidebar-destinations');

        var urlSort = new URLSearchParams(window.location.search).get('sort');
        var state = {
            q: String($page.attr('data-initial-query') || '').trim().slice(0, QUERY_MAX_LENGTH),
            destination: LT.normaliseId($page.attr('data-initial-destination')),
            sort: SORTS.indexOf(urlSort) !== -1 ? urlSort : DEFAULT_SORT
        };
        var destinationNames = {};
        var destinationsLoaded = false;
        var requestSeq = 0;
        var currentRequest = null;
        var searchTimer = null;

        /* ---------- Đồng bộ điều khiển và URL ---------- */

        function syncSortControls() {
            $sortTabs.each(function () {
                var isActive = $(this).attr('data-sort') === state.sort;
                $(this).toggleClass('is-active', isActive).attr('aria-pressed', isActive ? 'true' : 'false');
            });
            $priceSort.val(state.sort === 'price_asc' || state.sort === 'price_desc' ? state.sort : '');
        }

        function hasDestinationOption(id) {
            return $destinationSelect.find('option').filter(function () {
                return this.value === id;
            }).length > 0;
        }

        function syncDestinationControls() {
            var exists = hasDestinationOption(state.destination);
            if (state.destination && !exists && destinationsLoaded) {
                // Điểm đến trong URL không còn tồn tại: vẫn hiển thị để người dùng biết đang lọc.
                $destinationSelect.append($('<option>').val(state.destination).text('Điểm đến không xác định'));
                exists = true;
            }
            // Chưa tải xong danh sách thì tạm giữ "Tất cả điểm đến" thay vì để ô chọn trống.
            $destinationSelect.val(exists ? state.destination : '');
            LT.setActiveDestination($sidebarList, state.destination);
        }

        function syncControls() {
            $searchInput.val(state.q);
            syncDestinationControls();
            syncSortControls();
        }

        function syncUrl() {
            if (!window.history || typeof window.history.replaceState !== 'function') {
                return;
            }
            var params = new URLSearchParams();
            if (state.q) {
                params.set('q', state.q);
            }
            if (state.destination) {
                params.set('destination', state.destination);
            }
            if (state.sort !== DEFAULT_SORT) {
                params.set('sort', state.sort);
            }
            var query = params.toString();
            window.history.replaceState(window.history.state, '', window.location.pathname + (query ? '?' + query : '') + window.location.hash);
        }

        /* ---------- Trạng thái hiển thị ---------- */

        function showState(name) {
            $loading.prop('hidden', name !== 'loading');
            $feed.prop('hidden', name !== 'results').attr('aria-busy', name === 'loading' ? 'true' : 'false');
            $empty.prop('hidden', name !== 'empty');
            $error.prop('hidden', name !== 'error');
        }

        function filterContext() {
            var parts = [];
            if (state.q) {
                parts.push('từ khóa “' + state.q + '”');
            }
            if (state.destination) {
                parts.push(destinationNames[state.destination] || 'điểm đến đã chọn');
            }
            return parts;
        }

        function setCount(mainText) {
            var context = filterContext();
            $count.empty().append($('<strong>').text(mainText));
            if (context.length) {
                $count.append(document.createTextNode(' · ' + context.join(' · ')));
            }
        }

        function showError(message) {
            $errorMessage.text(message || GENERIC_ERROR);
            $count.empty().text('Không tải được danh sách tour');
            showState('error');
        }

        /* ---------- Thẻ tour ---------- */

        function initialOf(name) {
            var text = String(name || '').trim();
            return text ? text.charAt(0).toUpperCase() : 'L';
        }

        function safeTourUrl(tour) {
            var href = typeof tour.url === 'string' ? tour.url : '';
            // Chỉ nhận đường dẫn nội bộ hoặc http(s); còn lại tự dựng từ ID.
            if (/^\//.test(href) && !/^\/\//.test(href)) {
                return href;
            }
            if (/^https?:\/\//i.test(href)) {
                return href;
            }
            return LT.url('/tours/' + encodeURIComponent(String(tour.tour_id)));
        }

        function metaItem(iconName, text, extraClass) {
            return $('<li>')
                .addClass('lt-meta__item' + (extraClass ? ' ' + extraClass : ''))
                .append(LT.icon(iconName), $('<span>').addClass('lt-meta__text').text(text));
        }

        function mediaPlaceholder(caption) {
            return $('<div>')
                .addClass('lt-media-placeholder')
                .attr({ role: 'img', 'aria-label': caption })
                .append(LT.icon('image'), $('<span>').attr('aria-hidden', 'true').text(caption));
        }

        function disabledAction(iconName, label, collapsible) {
            return $('<button>')
                .attr({ type: 'button', title: 'Sắp có' })
                .prop('disabled', true)
                .addClass('lt-action')
                .append(
                    LT.icon(iconName),
                    $('<span>').addClass('lt-action__label' + (collapsible ? ' lt-action__label--collapsible' : '')).text(label)
                );
        }

        function buildCard(tour) {
            var tourId = parseInt(tour.tour_id, 10) || 0;
            var titleId = 'tour-title-' + tourId;
            var href = safeTourUrl(tour);
            var caption = tour.cover_caption || tour.title || 'Ảnh tour';
            var $card = $('<article>').addClass('lt-tour-card').attr({ 'data-tour-id': tourId, 'aria-labelledby': titleId });

            // Người tổ chức
            var $provider = $('<p>').addClass('lt-tour-card__provider')
                .append($('<span>').text(tour.provider_name || 'Người tổ chức địa phương'));
            if (tour.provider_verified) {
                $provider.append(
                    $('<span>').addClass('lt-verified').attr('title', 'Nhà tổ chức đã xác minh')
                        .append(LT.icon('verified'), $('<span>').addClass('sr-only').text('Đã xác minh'))
                );
            }
            $provider.append($('<span>').addClass('lt-tour-card__role').text('Người tổ chức'));

            var subParts = [tour.category_name, tour.destination_name].filter(Boolean);
            var $head = $('<header>').addClass('lt-tour-card__head').append(
                $('<span>').addClass('lt-avatar').attr('aria-hidden', 'true').text(initialOf(tour.provider_name)),
                $('<div>').addClass('lt-tour-card__org').append(
                    $provider,
                    $('<p>').addClass('lt-tour-card__sub').text(subParts.join(' · '))
                )
            );

            // Tiêu đề: link phủ cả thẻ (stretched-link) để bấm vào đâu trên thẻ cũng mở chi tiết.
            var $title = $('<h2>').addClass('lt-tour-card__title').attr('id', titleId).append(
                $('<a>').addClass('lt-tour-card__link stretched-link').attr('href', href).text(tour.title || 'Tour chưa có tên')
            );

            // Ảnh bìa
            var $media = $('<div>').addClass('lt-tour-card__media');
            if (tour.cover_image_url) {
                var $img = $('<img>').attr({
                    src: tour.cover_image_url,
                    alt: caption,
                    width: 640,
                    height: 360,
                    loading: 'lazy',
                    decoding: 'async'
                });
                $img.one('error', function () {
                    $img.replaceWith(mediaPlaceholder(caption));
                });
                $media.append($img);
            } else {
                $media.append(mediaPlaceholder(caption));
            }
            if (tour.destination_name) {
                $media.append(
                    $('<span>').addClass('lt-tour-card__badge').attr('aria-hidden', 'true')
                        .append(LT.icon('pin'), $('<span>').text(tour.destination_name))
                );
            }

            // Thông tin nhanh
            var reviewCount = parseInt(tour.review_count, 10) || 0;
            var $rating = tour.rating_text
                ? $('<li>').addClass('lt-meta__item lt-meta__item--rating').append(
                    LT.icon('star'),
                    $('<span>').addClass('lt-meta__text').append(
                        $('<strong>').text(tour.rating_text + '/5'),
                        document.createTextNode(' (' + reviewCount + ' đánh giá)')
                    )
                )
                : metaItem('star', 'Chưa có đánh giá', 'lt-meta__item--rating');
            var $meta = $('<ul>').addClass('lt-meta').attr('aria-label', 'Thông tin nhanh').append($rating);
            if (tour.duration_text) {
                $meta.append(metaItem('clock', tour.duration_text));
            }
            if (tour.meeting_point) {
                $meta.append(metaItem('pin', 'Gặp tại ' + tour.meeting_point));
            }
            $meta.append(metaItem('calendar', tour.next_departure_text
                ? 'Khởi hành ' + tour.next_departure_text
                : 'Chưa có lịch khởi hành'));

            // Giá + nút xem chi tiết
            var $buy = $('<div>').addClass('lt-tour-card__buy').append(
                $('<p>').addClass('lt-price').append(
                    document.createTextNode('Từ '),
                    $('<strong>').addClass('lt-price__amount').text(tour.price_text || LT.formatVnd(tour.price_per_person)),
                    document.createTextNode(' / người')
                ),
                $('<a>').addClass('lt-btn lt-btn--primary lt-tour-card__cta')
                    .attr({ href: href, 'aria-describedby': titleId })
                    .text('Xem chi tiết')
            );

            // Tương tác: chưa làm ở Sprint 3, luôn tắt.
            var $actionsMain = $('<div>').addClass('lt-tour-card__actions-main');
            $.each(INTERACTIONS, function (index, action) {
                $actionsMain.append(disabledAction(action.icon, action.label, true));
            });
            var $actions = $('<div>').addClass('lt-tour-card__actions')
                .attr({ role: 'group', 'aria-label': 'Tương tác (sắp có)' })
                .append(
                    $actionsMain,
                    disabledAction('columns', 'Thêm vào so sánh', false).addClass('lt-action--compare').append(LT.soonBadge())
                );

            return $card.append(
                $head,
                $title,
                $('<p>').addClass('lt-tour-card__summary').text(tour.summary || ''),
                $media,
                $meta,
                $buy,
                $actions
            );
        }

        function renderTours(tours, total) {
            $feed.empty();
            if (!tours.length) {
                $emptyText.text(state.q || state.destination
                    ? 'Thử từ khóa khác hoặc chọn điểm đến khác nhé.'
                    : 'Hiện chưa có tour nào đang mở. Vui lòng quay lại sau.');
                $('#tour-clear-filters').prop('hidden', !(state.q || state.destination));
                setCount('Không có tour');
                showState('empty');
                return;
            }

            var cards = $.map(tours, function (tour) {
                return buildCard(tour);
            });
            $feed.append(cards).append(
                $('<p>').addClass('lt-feed__end').text('Bạn đã xem hết ' + total + ' tour phù hợp.')
            );
            setCount(total + ' tour');
            showState('results');
        }

        /* ---------- AJAX ---------- */

        function loadTours() {
            var seq = ++requestSeq;
            if (currentRequest) {
                currentRequest.abort();
            }

            var params = { sort: state.sort };
            if (state.q) {
                params.q = state.q;
            }
            if (state.destination) {
                params.destination = state.destination;
            }

            showState('loading');
            $count.empty().text('Đang tải tour…');

            currentRequest = $.ajax({
                url: LT.url('/api/tours'),
                method: 'GET',
                data: params,
                dataType: 'json',
                timeout: REQUEST_TIMEOUT_MS
            });

            currentRequest
                .done(function (response) {
                    if (seq !== requestSeq) {
                        return; // Đã có yêu cầu mới hơn.
                    }
                    if (!response || response.success !== true || !response.data || !$.isArray(response.data.tours)) {
                        showError(response && typeof response.message === 'string' ? response.message : '');
                        return;
                    }
                    var tours = response.data.tours;
                    var total = typeof response.data.total === 'number' ? response.data.total : tours.length;
                    renderTours(tours, total);
                })
                .fail(function (xhr, textStatus) {
                    if (seq !== requestSeq || textStatus === 'abort') {
                        return;
                    }
                    var body = xhr && xhr.responseJSON;
                    var message = body && typeof body.message === 'string' ? body.message : '';
                    showError(textStatus === 'timeout' ? TIMEOUT_ERROR : message);
                })
                .always(function () {
                    if (seq === requestSeq) {
                        currentRequest = null;
                    }
                });
        }

        function loadDestinations() {
            LT.renderDestinationStatus($sidebarList, 'Đang tải điểm đến…');
            $.ajax({ url: LT.url('/api/destinations'), method: 'GET', dataType: 'json', timeout: REQUEST_TIMEOUT_MS })
                .done(function (response) {
                    var list = response && response.success && response.data && response.data.destinations;
                    if (!$.isArray(list)) {
                        LT.renderDestinationStatus($sidebarList, 'Không tải được điểm đến.');
                        return;
                    }

                    var $options = [$('<option>').val('').text('Tất cả')];
                    destinationNames = {};
                    $.each(list, function (index, destination) {
                        var id = LT.normaliseId(destination.destination_id);
                        if (!id) {
                            return;
                        }
                        destinationNames[id] = String(destination.name || '');
                        $options.push($('<option>').val(id).text(destination.name + ' (' + (Number(destination.tour_count) || 0) + ')'));
                    });
                    destinationsLoaded = true;
                    $destinationSelect.empty().append($options);
                    LT.renderDestinationNav($sidebarList, list, state.destination);
                    syncDestinationControls();

                    // Cập nhật dòng đếm để hiện tên điểm đến khi danh sách tour về trước.
                    if (!$feed.prop('hidden')) {
                        setCount($count.find('strong').first().text());
                    }
                })
                .fail(function () {
                    LT.renderDestinationStatus($sidebarList, 'Không tải được điểm đến.');
                });
        }

        function refresh() {
            syncUrl();
            loadTours();
        }

        /* ---------- Sự kiện ---------- */

        function applyQuery(value) {
            var query = String(value || '').trim().slice(0, QUERY_MAX_LENGTH);
            if (query === state.q) {
                return false;
            }
            state.q = query;
            refresh();
            return true;
        }

        $searchForm.on('submit', function (event) {
            event.preventDefault();
            window.clearTimeout(searchTimer);
            if (!applyQuery($searchInput.val())) {
                loadTours(); // Bấm "Tìm" lại với cùng từ khóa = tải lại.
            }
        });

        $searchInput.on('input', function () {
            window.clearTimeout(searchTimer);
            searchTimer = window.setTimeout(function () {
                applyQuery($searchInput.val());
            }, SEARCH_DELAY_MS);
        });

        $destinationSelect.on('change', function () {
            state.destination = LT.normaliseId($destinationSelect.val());
            LT.setActiveDestination($sidebarList, state.destination);
            refresh();
        });

        $sidebarList.on('click', '.lt-dest-link', function (event) {
            event.preventDefault();
            state.destination = LT.normaliseId($(this).attr('data-destination-id'));
            syncDestinationControls();
            refresh();
            if ($sidebar.hasClass('show') && window.innerWidth < 992) {
                $sidebar.collapse('hide');
                var target = document.getElementById('main-content');
                if (target) {
                    target.focus({ preventScroll: true });
                    target.scrollIntoView({ behavior: LT.prefersReducedMotion() ? 'auto' : 'smooth', block: 'start' });
                }
            }
        });

        $sortTabs.on('click', function () {
            var sort = $(this).attr('data-sort');
            if (SORTS.indexOf(sort) === -1 || sort === state.sort) {
                return;
            }
            state.sort = sort;
            syncSortControls();
            refresh();
        });

        $priceSort.on('change', function () {
            var value = $priceSort.val();
            state.sort = SORTS.indexOf(value) !== -1 ? value : DEFAULT_SORT;
            syncSortControls();
            refresh();
        });

        $('#tour-retry').on('click', function () {
            loadTours();
            if (!destinationsLoaded) {
                loadDestinations();
            }
        });

        $('#tour-clear-filters').on('click', function () {
            window.clearTimeout(searchTimer);
            state.q = '';
            state.destination = '';
            syncControls();
            refresh();
            $searchInput.trigger('focus');
        });

        /* ---------- Khởi động ---------- */

        syncControls();
        syncUrl();
        loadDestinations();
        loadTours();
    });
})(window, document, jQuery);
