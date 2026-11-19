/*
 * LocalTour – tour-list.js (Nguyễn Tuấn Khôi)
 * Bảng tin du lịch: tải /api/destinations, /api/categories và /api/tours bằng AJAX, hiển thị skeleton /
 * thẻ tour / trạng thái rỗng / lỗi; tìm kiếm, lọc điểm đến và loại hình (theo ID), sắp xếp không tải lại
 * trang và giữ URL đồng bộ.
 * CR2 (Lê Trung Phong): ô "Ngày đi" và bảng "Bộ lọc" (khoảng giá, thời lượng, ngôn ngữ hướng dẫn, đón tại khách sạn).
 * Mọi bộ lọc nằm trên URL (date, price_min, price_max, duration, language, hotel_pickup) và được đọc lại khi tải
 * trang hoặc khi bấm lùi / tiến. Thẻ tour có khối trống .js-tour-social để tour-social.js điền nút Thích / Bình luận /
 * Chia sẻ / Lưu; sau mỗi lần dựng danh sách, file này phát sự kiện 'lt:tours-rendered' trên document.
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
    // Bộ lọc CR2: mã thời lượng giống TourListModel::DURATIONS; giá tối đa 9 chữ số.
    var DURATIONS = ['short', 'medium', 'long'];
    var DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
    var PRICE_DIGITS_MAX = 9;

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
        // Ngày đi + Bộ lọc (CR2)
        var $date = $('#filter-date');
        var $dateClear = $('#filter-date-clear');
        var $moreToggle = $('#filter-more-toggle');
        var $moreCount = $('#filter-more-count');
        var $panel = $('#filter-panel');
        var $panelError = $('#filter-panel-error');
        var $priceMin = $('#filter-price-min');
        var $priceMax = $('#filter-price-max');
        var $pricePresets = $panel.find('.js-price-preset');
        var $durationInputs = $panel.find('input[name="duration"]');
        var $language = $('#filter-language');
        var $hotelPickup = $('#filter-hotel-pickup');

        var dateMin = String($page.attr('data-date-min') || '');
        var dateMax = String($page.attr('data-date-max') || '');
        var priceMax = parseInt($page.attr('data-price-max'), 10) || 100000000;
        var languageNames = {};
        try {
            languageNames = JSON.parse($language.attr('data-all-languages') || '{}') || {};
        } catch (ignore) {
            languageNames = {};
        }

        var urlParams = new URLSearchParams(window.location.search);
        var urlSort = urlParams.get('sort');
        var state = $.extend({
            q: String($page.attr('data-initial-query') || '').trim().slice(0, QUERY_MAX_LENGTH),
            destinationId: LT.normaliseId($page.attr('data-initial-destination-id')),
            categoryId: LT.normaliseId($page.attr('data-initial-category-id')),
            sort: SORTS.indexOf(urlSort) !== -1 ? urlSort : DEFAULT_SORT
        }, readAdvanced(urlParams));
        // Tên hiển thị theo ID, để dòng đếm ghi "Hà Nội · Ẩm thực" thay vì UUID.
        var destinationNames = {};
        var categoryNames = {};
        var destinationsLoaded = false;
        var categoriesLoaded = false;
        var requestSeq = 0;
        var currentRequest = null;
        var searchTimer = null;

        /* ---------- Ngày đi + Bộ lọc nâng cao (CR2) ---------- */

        /** 'YYYY-MM-DD' có thật và nằm trong khoảng ô "Ngày đi" cho chọn (hôm nay → 365 ngày tới). */
        function isValidDate(value) {
            var match = DATE_PATTERN.exec(String(value || ''));
            if (!match) {
                return false;
            }
            var day = new Date(Date.UTC(+match[1], +match[2] - 1, +match[3]));
            var sameDay = day.getUTCFullYear() === +match[1] && day.getUTCMonth() === +match[2] - 1 && day.getUTCDate() === +match[3];
            return sameDay && (!dateMin || value >= dateMin) && (!dateMax || value <= dateMax);
        }

        /** Chuỗi giá người dùng gõ ("500.000", "500000đ") → số dạng chuỗi; '' = bỏ trống; null = không hợp lệ. */
        function parsePrice(value) {
            var text = String(value === undefined || value === null ? '' : value).trim();
            if (text === '') {
                return '';
            }
            if (!/^[\d.,\s]+(đ|₫|vnd)?$/i.test(text)) {
                return null;
            }
            var digits = text.replace(/\D/g, '').replace(/^0+(?=\d)/, '');
            if (digits === '' || digits.length > PRICE_DIGITS_MAX || parseInt(digits, 10) > priceMax) {
                return null;
            }
            return String(parseInt(digits, 10));
        }

        /** 500000 -> '500.000' (ô nhập giá). */
        function groupDigits(value) {
            return value === '' ? '' : String(value).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
        }

        /** Đọc bộ lọc nâng cao từ URL; giá trị sai bị bỏ qua (URL được ghi lại sạch ở syncUrl). */
        function readAdvanced(params) {
            var date = params.get('date') || '';
            var minPrice = parsePrice(params.get('price_min'));
            var maxPrice = parsePrice(params.get('price_max'));
            var duration = params.get('duration') || '';
            var language = String(params.get('language') || '');
            if (minPrice === null) {
                minPrice = '';
            }
            if (maxPrice === null) {
                maxPrice = '';
            }
            if (minPrice !== '' && maxPrice !== '' && +minPrice > +maxPrice) {
                minPrice = '';
                maxPrice = '';
            }
            return {
                date: isValidDate(date) ? date : '',
                priceMin: minPrice,
                priceMax: maxPrice,
                duration: DURATIONS.indexOf(duration) !== -1 ? duration : '',
                language: Object.prototype.hasOwnProperty.call(languageNames, language) ? language : '',
                hotelPickup: params.get('hotel_pickup') === '1'
            };
        }

        function advancedCount() {
            return (state.priceMin !== '' || state.priceMax !== '' ? 1 : 0)
                + (state.duration ? 1 : 0)
                + (state.language ? 1 : 0)
                + (state.hotelPickup ? 1 : 0);
        }

        function formatDay(value) {
            var match = DATE_PATTERN.exec(value);
            return match ? match[3] + '/' + match[2] + '/' + match[1] : value;
        }

        function priceText(min, max) {
            if (min !== '' && max !== '') {
                return 'giá ' + LT.formatVnd(min) + ' – ' + LT.formatVnd(max);
            }
            return min !== '' ? 'giá từ ' + LT.formatVnd(min) : 'giá đến ' + LT.formatVnd(max);
        }

        function durationLabel(code) {
            return $.trim($durationInputs.filter(function () { return this.value === code; }).closest('label').text());
        }

        /** Ô "Ngày đi" + nút xóa ngày + số bộ lọc nâng cao trên nút "Bộ lọc". */
        function syncDateAndBadge() {
            if ($date.val() !== state.date) {
                $date.val(state.date);
            }
            $dateClear.prop('hidden', !state.date);
            $page.find('.lt-filter--date').toggleClass('is-active', !!state.date);

            var count = advancedCount();
            $moreToggle.toggleClass('is-active', count > 0);
            $moreCount.prop('hidden', count === 0).empty();
            if (count > 0) {
                $moreCount.append(
                    $('<span>').attr('aria-hidden', 'true').text(String(count)),
                    $('<span>').addClass('sr-only').text(' (' + count + ' bộ lọc đang áp dụng)')
                );
            }
        }

        /** Đánh dấu nút giá có sẵn trùng với hai ô giá đang nhập. */
        function syncPricePresets() {
            var min = parsePrice($priceMin.val());
            var max = parsePrice($priceMax.val());
            $pricePresets.each(function () {
                var pressed = min === String($(this).attr('data-min')) && max === String($(this).attr('data-max'));
                $(this).toggleClass('is-active', pressed).attr('aria-pressed', pressed ? 'true' : 'false');
            });
        }

        /** Điền bảng "Bộ lọc" theo bộ lọc đang áp dụng (bỏ phần đang sửa dở chưa bấm "Áp dụng"). */
        function fillPanel() {
            $priceMin.val(groupDigits(state.priceMin));
            $priceMax.val(groupDigits(state.priceMax));
            $durationInputs.each(function () {
                this.checked = this.value === state.duration;
            });
            $language.find('option[data-unknown]').remove();
            if (state.language && !$language.find('option').filter(function () { return this.value === state.language; }).length) {
                // Ngôn ngữ trên URL hiện chưa có tour: vẫn hiện để người dùng biết đang lọc.
                $language.append($('<option>').attr('data-unknown', '1').val(state.language).text(languageNames[state.language] + ' (0)'));
            }
            $language.val(state.language);
            $hotelPickup.prop('checked', state.hotelPickup);
            showPanelError('');
            syncPricePresets();
            syncDurationChips();
        }

        /** Chip thời lượng đang chọn (CSS :has() chưa có ở mọi trình duyệt). */
        function syncDurationChips() {
            $durationInputs.each(function () {
                $(this).closest('.lt-chip').toggleClass('is-active', this.checked);
            });
        }

        function showPanelError(message) {
            $panelError.text(message).prop('hidden', message === '');
        }

        function isPanelOpen() {
            return !$panel.prop('hidden');
        }

        function openPanel() {
            fillPanel();
            $panel.prop('hidden', false);
            $moreToggle.attr('aria-expanded', 'true');
        }

        function closePanel(returnFocus) {
            $panel.prop('hidden', true);
            $moreToggle.attr('aria-expanded', 'false');
            if (returnFocus) {
                $moreToggle.trigger('focus');
            }
        }

        /** Kiểm tra bảng "Bộ lọc"; hợp lệ thì áp dụng, tải lại danh sách và đóng bảng. */
        function applyPanel() {
            var min = parsePrice($priceMin.val());
            var max = parsePrice($priceMax.val());
            if (min === null || max === null) {
                showPanelError('Giá phải là số từ 0 đến ' + LT.formatVnd(priceMax) + '.');
                (min === null ? $priceMin : $priceMax).trigger('focus');
                return;
            }
            if (min !== '' && max !== '' && +min > +max) {
                showPanelError('Giá “Từ” không được lớn hơn giá “Đến”.');
                $priceMin.trigger('focus');
                return;
            }
            var duration = String($durationInputs.filter(':checked').val() || '');
            var language = String($language.val() || '');
            state.priceMin = min;
            state.priceMax = max;
            state.duration = DURATIONS.indexOf(duration) !== -1 ? duration : '';
            state.language = Object.prototype.hasOwnProperty.call(languageNames, language) ? language : '';
            state.hotelPickup = $hotelPickup.prop('checked');
            closePanel(true);
            syncDateAndBadge();
            refresh();
        }

        function clearAdvanced() {
            state.priceMin = '';
            state.priceMax = '';
            state.duration = '';
            state.language = '';
            state.hotelPickup = false;
        }

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
            syncDateAndBadge();
            if (isPanelOpen()) {
                fillPanel();
            }
        }

        function hasFilters() {
            return !!(state.q || state.destinationId || state.categoryId || state.date || advancedCount() > 0);
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
            $.each(advancedParams(), function (key, value) {
                params.set(key, value);
            });
            var query = params.toString();
            window.history.replaceState(window.history.state, '', window.location.pathname + (query ? '?' + query : '') + window.location.hash);
        }

        /** Ngày đi + bộ lọc nâng cao dưới dạng tham số URL / API (chỉ những bộ lọc đang bật). */
        function advancedParams() {
            var params = {};
            if (state.date) {
                params.date = state.date;
            }
            if (state.priceMin !== '') {
                params.price_min = state.priceMin;
            }
            if (state.priceMax !== '') {
                params.price_max = state.priceMax;
            }
            if (state.duration) {
                params.duration = state.duration;
            }
            if (state.language) {
                params.language = state.language;
            }
            if (state.hotelPickup) {
                params.hotel_pickup = '1';
            }
            return params;
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
            if (state.date) {
                parts.push('ngày ' + formatDay(state.date));
            }
            if (state.priceMin !== '' || state.priceMax !== '') {
                parts.push(priceText(state.priceMin, state.priceMax));
            }
            if (state.duration) {
                parts.push(durationLabel(state.duration).toLowerCase());
            }
            if (state.language && languageNames[state.language]) {
                // "Tiếng Anh" → "hướng dẫn tiếng Anh"
                var languageName = String(languageNames[state.language]);
                parts.push('hướng dẫn ' + languageName.charAt(0).toLowerCase() + languageName.slice(1));
            }
            if (state.hotelPickup) {
                parts.push('đón tại khách sạn');
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

        /** Nút chọn / bỏ so sánh (compare.js xử lý bấm và trạng thái đã chọn). */
        function compareAction(tour, tourId) {
            var $button = $('<button>')
                .attr({
                    type: 'button',
                    'data-tour-id': tourId,
                    'data-tour-title': String(tour.title || ''),
                    'data-tour-image': tour.cover_image_url ? String(tour.cover_image_url) : '',
                    'aria-pressed': 'false'
                })
                .addClass('lt-action lt-action--compare js-compare-toggle')
                .append(LT.icon('columns'), $('<span>').addClass('lt-action__label js-compare-label').text('Thêm vào so sánh'));
            if (!tourId) {
                $button.prop('disabled', true);
            }
            return $button;
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

            // Thích / Bình luận / Chia sẻ / Lưu tour (CR2): khối trống, tour-social.js điền nút khi nhận
            // 'lt:tours-rendered'. So sánh tour (FR-15, Sprint 5): compare.js.
            var $social = $('<div>').addClass('lt-card-social js-tour-social').attr({
                'data-tour-id': tourId,
                'data-variant': 'card',
                'data-tour-title': String(tour.title || ''),
                'data-tour-url': LT.url('/tours/' + encodeURIComponent(tourId))
            });
            if (!tourId) {
                $social.removeClass('js-tour-social');
            }
            var $actions = $('<div>').addClass('lt-tour-card__actions').append(
                $social,
                compareAction(tour, tourId)
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
                    ? 'Thử bỏ bớt bộ lọc, chọn ngày khác hoặc đổi từ khóa nhé. Bấm “Xóa bộ lọc” để xem mọi tour.'
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
            if (window.LocalTourCompare) {
                window.LocalTourCompare.sync();
            }
            // tour-social.js (CR2) điền nút Thích / Bình luận / Chia sẻ / Lưu vào các khối .js-tour-social mới.
            $(document).trigger('lt:tours-rendered');
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
            $.extend(params, advancedParams());

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
            // Làm đúng như link: chỉ lọc theo điểm đến (số tour trên link đếm theo điểm đến).
            window.clearTimeout(searchTimer);
            state.q = '';
            state.categoryId = '';
            state.date = '';
            clearAdvanced();
            state.destinationId = LT.normaliseId($(this).attr('data-destination-id'));
            syncControls();
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
            state.date = '';
            clearAdvanced();
            syncControls();
            refresh();
            $searchInput.trigger('focus');
        });

        /* Ngày đi: áp dụng ngay khi chọn được ngày hợp lệ; ngày gõ dở / ngoài khoảng thì trả lại ngày đang lọc khi rời ô. */
        $date.on('change', function () {
            var value = String($date.val() || '');
            if (value === state.date) {
                return;
            }
            if (value === '' || isValidDate(value)) {
                state.date = value;
                syncDateAndBadge();
                refresh();
            }
        });

        $date.on('blur', function () {
            if (String($date.val() || '') !== state.date) {
                $date.val(state.date);
            }
        });

        $dateClear.on('click', function () {
            state.date = '';
            syncDateAndBadge();
            refresh();
            $date.trigger('focus');
        });

        /* Bảng "Bộ lọc" */
        $moreToggle.on('click', function () {
            if (isPanelOpen()) {
                closePanel(false);
            } else {
                openPanel();
            }
        });

        $('#filter-panel-close').on('click', function () {
            closePanel(true);
        });

        $panel.on('keydown', function (event) {
            if (event.key === 'Escape') {
                event.preventDefault();
                closePanel(true);
            }
        });

        $panel.on('submit', function (event) {
            event.preventDefault();
            applyPanel();
        });

        $('#filter-panel-reset').on('click', function () {
            clearAdvanced();
            closePanel(true);
            syncDateAndBadge();
            refresh();
        });

        $pricePresets.on('click', function () {
            var $preset = $(this);
            if ($preset.attr('aria-pressed') === 'true') {
                $priceMin.val('');
                $priceMax.val('');
            } else {
                $priceMin.val(groupDigits(String($preset.attr('data-min') || '')));
                $priceMax.val(groupDigits(String($preset.attr('data-max') || '')));
            }
            showPanelError('');
            syncPricePresets();
        });

        $durationInputs.on('change', syncDurationChips);

        $priceMin.add($priceMax).on('input', function () {
            showPanelError('');
            syncPricePresets();
        }).on('blur', function () {
            // Gõ "500000" → hiện "500.000"; giá trị sai giữ nguyên để báo lỗi khi bấm "Áp dụng".
            var parsed = parsePrice($(this).val());
            if (parsed !== null) {
                $(this).val(groupDigits(parsed));
            }
        });

        /* Bấm lùi / tiến của trình duyệt: đọc lại mọi bộ lọc trên URL. */
        $(window).on('popstate', function () {
            var params = new URLSearchParams(window.location.search);
            var sort = params.get('sort');
            var next = $.extend({
                q: String(params.get('q') || '').trim().slice(0, QUERY_MAX_LENGTH),
                destinationId: LT.normaliseId(params.get('destination_id')),
                categoryId: LT.normaliseId(params.get('category_id')),
                sort: SORTS.indexOf(sort) !== -1 ? sort : DEFAULT_SORT
            }, readAdvanced(params));
            var changed = false;
            $.each(next, function (key, value) {
                if (state[key] !== value) {
                    changed = true;
                }
            });
            if (!changed) {
                return;
            }
            window.clearTimeout(searchTimer);
            state = next;
            syncControls();
            loadTours();
        });

        /* ---------- Khởi động ---------- */

        syncControls();
        syncUrl();
        loadDestinations();
        loadCategories();
        loadTours();
    });
})(window, document, jQuery);
