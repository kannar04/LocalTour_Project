/*
 * LocalTour – tour-list.js (Nguyễn Tuấn Khôi)
 * Bảng tin du lịch: tải /api/destinations, /api/categories và /api/tours bằng AJAX, hiển thị skeleton /
 * thẻ tour / trạng thái rỗng / lỗi; tìm kiếm, lọc điểm đến và loại hình (theo ID), sắp xếp không tải lại
 * trang và giữ URL đồng bộ.
 * Mọi dữ liệu từ server được đưa vào DOM bằng .text() / .attr().
 */
(function (window, document, $) {
    'use strict';

    var SORTS = ['recommended', 'upcoming', 'price_asc', 'price_desc'];
    var UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    var PRICE_SORTS = ['price_asc', 'price_desc'];
    var DEFAULT_SORT = 'recommended';
    var MISSING = 'Chưa cập nhật';
    var UNPRICED_NOTE = 'Các tour dưới đây chưa cập nhật giá nên không được xếp theo giá.';
    var QUERY_MAX_LENGTH = 100;
    var SEARCH_DELAY_MS = 400;
    var REQUEST_TIMEOUT_MS = 15000;
    var GENERIC_ERROR = 'Máy chủ đang bận hoặc mất kết nối. Vui lòng thử lại sau ít phút.';
    var TIMEOUT_ERROR = 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.';

    $(function () {
        var LT = window.LocalTour;
        var $page = $('#tour-list-page');
        if (!$page.length || !LT) {
            return;
        }

        var $searchForm = $('#header-search');
        var $searchInput = $('#header-search-input');
        var $destinationSelect = $('#filter-destination');
        var $categorySelect = $('#filter-category');
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
            destinationId: LT.normaliseId($page.attr('data-initial-destination-id')),
            categoryId: LT.normaliseId($page.attr('data-initial-category-id')),
            sort: SORTS.indexOf(urlSort) !== -1 ? urlSort : DEFAULT_SORT
        };
        // Tên hiển thị theo ID, để dòng đếm ghi "Hà Nội · Ẩm thực" thay vì UUID.
        var destinationNames = {};
        var categoryNames = {};
        var destinationsLoaded = false;
        var categoriesLoaded = false;
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

        /**
         * Chọn đúng option theo ID. ID trong URL không còn tour nào (không có trong danh sách): thêm một
         * option tạm "(0)" để người dùng biết đang lọc. Chưa tải xong danh sách thì tạm giữ "Tất cả".
         */
        function syncSelect($select, id, loaded, unknownLabel) {
            $select.find('option[data-unknown]').remove();
            var $match = id ? $select.find('option').filter(function () { return this.value === id; }).first() : $();
            if (!$match.length && id && loaded) {
                $match = $('<option>').attr('data-unknown', '1').val(id).text(unknownLabel + ' (0)');
                $select.append($match);
            }
            $select.val($match.length ? id : '');
        }

        function syncDestinationControls() {
            syncSelect($destinationSelect, state.destinationId, destinationsLoaded, 'Điểm đến đã chọn');
            LT.setActiveDestination($sidebarList, state.destinationId);
        }

        function syncCategoryControls() {
            syncSelect($categorySelect, state.categoryId, categoriesLoaded, 'Loại hình đã chọn');
        }

        function syncControls() {
            $searchInput.val(state.q);
            syncDestinationControls();
            syncCategoryControls();
            syncSortControls();
        }

        function hasFilters() {
            return !!(state.q || state.destinationId || state.categoryId);
        }

        function syncUrl() {
            if (!window.history || typeof window.history.replaceState !== 'function') {
                return;
            }
            var params = new URLSearchParams();
            if (state.q) {
                params.set('q', state.q);
            }
            if (state.destinationId) {
                params.set('destination_id', state.destinationId);
            }
            if (state.categoryId) {
                params.set('category_id', state.categoryId);
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
            if (state.destinationId && destinationNames[state.destinationId]) {
                parts.push(destinationNames[state.destinationId]);
            }
            if (state.categoryId && categoryNames[state.categoryId]) {
                parts.push(categoryNames[state.categoryId]);
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

        function mediaPlaceholder(text) {
            return $('<div>')
                .addClass('lt-media-placeholder')
                .append(LT.icon('image'), $('<span>').text(text));
        }

        function hasPrice(tour) {
            return typeof tour.price_text === 'string' && tour.price_text !== '';
        }

        function disabledAction(iconName, label) {
            return $('<button>')
                .attr({ type: 'button', title: label + ' – sắp có', 'aria-label': label + ' (sắp có)' })
                .prop('disabled', true)
                .addClass('lt-action')
                .append(LT.icon(iconName), $('<span>').addClass('lt-action__label').text(label));
        }

        function buildCard(tour, index) {
            var tourId = UUID_PATTERN.test(String(tour.tour_id || '')) ? String(tour.tour_id).toLowerCase() : '';
            var titleId = 'tour-title-' + (tourId || 'i' + index);
            var href = safeTourUrl(tour);
            var caption = tour.cover_caption || tour.title || '';
            var $card = $('<article>').addClass('lt-tour-card').attr({ 'data-tour-id': tourId, 'aria-labelledby': titleId });

            // Người tổ chức + điểm đến
            var $provider = $('<p>').addClass('lt-tour-card__provider').append(
                $('<span>').text(tour.provider_name || 'Người tổ chức địa phương'),
                $('<span>').addClass('lt-tour-card__role').text('Người tổ chức')
            );

            var place = [tour.destination_name, tour.category_name].filter(function (part) {
                return typeof part === 'string' && part !== '';
            }).join(' · ');
            var $head = $('<header>').addClass('lt-tour-card__head').append(
                $('<span>').addClass('lt-avatar').attr('aria-hidden', 'true').text(initialOf(tour.provider_name)),
                $('<div>').addClass('lt-tour-card__org').append(
                    $provider,
                    $('<p>').addClass('lt-tour-card__sub').text(place)
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
                    $img.replaceWith(mediaPlaceholder('Không tải được ảnh'));
                });
                $media.append($img);
            } else {
                $media.append(mediaPlaceholder('Chưa cập nhật ảnh'));
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
            $meta.append(metaItem(
                tour.pickup_mode === 'hotel_pickup' ? 'navigation' : 'pin',
                'Nơi khởi hành: ' + (tour.departure_text || MISSING)
            ));
            $meta.append(metaItem('calendar', tour.next_departure_text
                ? 'Khởi hành ' + tour.next_departure_text
                : 'Chưa có lịch khởi hành sắp tới'));

            // Giá vé người lớn thấp nhất trong các lịch còn đặt được + nút xem chi tiết
            var $price = $('<p>').addClass('lt-price');
            if (hasPrice(tour)) {
                $price.append(
                    document.createTextNode('Từ '),
                    $('<strong>').addClass('lt-price__amount').text(tour.price_text),
                    document.createTextNode(' / người lớn')
                );
            } else {
                $price.addClass('lt-price--none').text('Giá: ' + MISSING);
            }

            var $buy = $('<div>').addClass('lt-tour-card__buy').append(
                $price,
                $('<a>').addClass('lt-btn lt-btn--primary lt-tour-card__cta')
                    .attr({ href: href, 'aria-describedby': titleId })
                    .text('Xem chi tiết')
            );

            // Thích / Bình luận / Chia sẻ / Lưu tour và So sánh tour (FR-15): chưa làm ở Sprint 3, luôn tắt.
            var $social = $('<div>').addClass('lt-tour-card__social').attr({ role: 'group', 'aria-label': 'Tương tác (sắp có)' }).append(
                disabledAction('heart', 'Thích'),
                disabledAction('message', 'Bình luận'),
                disabledAction('share', 'Chia sẻ'),
                disabledAction('bookmark', 'Lưu tour'),
                LT.soonBadge()
            );
            var $actions = $('<div>').addClass('lt-tour-card__actions').append(
                $social,
                disabledAction('columns', 'Thêm vào so sánh').addClass('lt-action--compare').append(LT.soonBadge())
            );

            return $card.append(
                $head,
                $title,
                tour.excerpt
                    ? $('<p>').addClass('lt-tour-card__excerpt').text(tour.excerpt)
                    : $('<p>').addClass('lt-tour-card__excerpt lt-tour-card__excerpt--missing').text('Tóm tắt: ' + MISSING),
                $media,
                $meta,
                $buy,
                $actions
            );
        }

        function renderTours(tours, total) {
            $feed.empty();
            if (!tours.length) {
                $emptyText.text(hasFilters()
                    ? 'Thử từ khóa khác hoặc chọn điểm đến, loại hình khác nhé.'
                    : 'Hiện chưa có tour nào đang mở. Vui lòng quay lại sau.');
                $('#tour-clear-filters').prop('hidden', !hasFilters());
                setCount('Không có tour');
                showState('empty');
                return;
            }

            // FR-06: khi xếp theo giá, tour chưa có giá không xếp lẫn với tour có giá mà nằm sau một dải phân cách.
            var bySort = PRICE_SORTS.indexOf(state.sort) !== -1;
            var ordered = bySort
                ? $.grep(tours, hasPrice).concat($.grep(tours, hasPrice, true))
                : tours;
            var dividerAdded = false;
            var cards = [];
            $.each(ordered, function (index, tour) {
                if (bySort && !dividerAdded && !hasPrice(tour)) {
                    dividerAdded = true;
                    cards.push($('<p>').addClass('lt-feed__divider').text(UNPRICED_NOTE));
                }
                cards.push(buildCard(tour, index));
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
            if (state.destinationId) {
                params.destination_id = state.destinationId;
            }
            if (state.categoryId) {
                params.category_id = state.categoryId;
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

                    destinationNames = {};
                    destinationsLoaded = true;
                    $destinationSelect.empty().append(buildOptions(list, 'destination_id', destinationNames));
                    LT.renderDestinationNav($sidebarList, list, state.destinationId);
                    syncDestinationControls();
                    refreshCount();
                })
                .fail(function () {
                    LT.renderDestinationStatus($sidebarList, 'Không tải được điểm đến.');
                });
        }

        function loadCategories() {
            $.ajax({ url: LT.url('/api/categories'), method: 'GET', dataType: 'json', timeout: REQUEST_TIMEOUT_MS })
                .done(function (response) {
                    var list = response && response.success && response.data && response.data.categories;
                    if (!$.isArray(list)) {
                        return; // Giữ "Tất cả": vẫn xem được mọi tour.
                    }
                    categoryNames = {};
                    categoriesLoaded = true;
                    $categorySelect.empty().append(buildOptions(list, 'category_id', categoryNames));
                    syncCategoryControls();
                    refreshCount();
                });
        }

        /** Option "Tất cả" + mỗi mục "Tên (số tour)"; ghi tên theo ID vào names. */
        function buildOptions(list, idKey, names) {
            var $options = [$('<option>').val('').text('Tất cả')];
            $.each(list, function (index, item) {
                var id = LT.normaliseId(item[idKey]);
                var name = String(item.name || '').trim();
                if (id && name) {
                    names[id] = name;
                    $options.push($('<option>').val(id).text(name + ' (' + (Number(item.tour_count) || 0) + ')'));
                }
            });
            return $options;
        }

        /** Danh sách tour về trước danh mục: cập nhật lại dòng đếm để hiện tên điểm đến / loại hình. */
        function refreshCount() {
            if (!$feed.prop('hidden')) {
                setCount($count.find('strong').first().text());
            }
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
            state.destinationId = LT.normaliseId($destinationSelect.val());
            syncDestinationControls();
            refresh();
        });

        $categorySelect.on('change', function () {
            state.categoryId = LT.normaliseId($categorySelect.val());
            syncCategoryControls();
            refresh();
        });

        $sidebarList.on('click', '.lt-dest-link', function (event) {
            event.preventDefault();
            state.destinationId = LT.normaliseId($(this).attr('data-destination-id'));
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
            if (!categoriesLoaded) {
                loadCategories();
            }
        });

        $('#tour-clear-filters').on('click', function () {
            window.clearTimeout(searchTimer);
            state.q = '';
            state.destinationId = '';
            state.categoryId = '';
            syncControls();
            refresh();
            $searchInput.trigger('focus');
        });

        /* ---------- Khởi động ---------- */

        syncControls();
        syncUrl();
        loadDestinations();
        loadCategories();
        loadTours();
    });
})(window, document, jQuery);
