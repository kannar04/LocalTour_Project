/*
 * LocalTour – tour-map.js (Nguyễn Tuấn Khôi)
 * Bản đồ Leaflet (nền OpenStreetMap) và địa điểm quanh điểm khởi hành của tour. Một khối .js-places-map mỗi trang:
 *   - data-mode="tour" (trang chi tiết tour): ghim điểm khởi hành, tải /api/tours/{id}/places, nút bật / tắt từng
 *     nhóm (Quán ăn, Bar, Giải trí, Quán nước) và danh sách ngắn (tên + khoảng cách) của từng nhóm;
 *   - data-mode="all" (trang /ban-do): ghim điểm khởi hành của mọi tour; chọn một tour (bấm ghim hoặc nút trong
 *     danh sách) để xem địa điểm quanh đó và link sang trang tour;
 *   - data-mode="pick" (trang quản trị): bấm lên bản đồ hoặc kéo ghim để điền vĩ độ / kinh độ.
 * Địa điểm chỉ lấy từ API của LocalTour (máy chủ gọi Overpass), trình duyệt không gọi Overpass.
 * Không tải được Leaflet hoặc API lỗi: không có lỗi JS, danh sách / ô nhập vẫn dùng được, có dòng thông báo.
 * Dữ liệu từ server chỉ đưa vào DOM bằng textContent / .text() / .attr().
 */
(function (window, document, $) {
    'use strict';

    var GROUPS = ['an_uong', 'bar', 'giai_tri', 'quan_nuoc'];
    var LABELS = { an_uong: 'Quán ăn', bar: 'Bar', giai_tri: 'Giải trí', quan_nuoc: 'Quán nước' };
    var COLORS = { an_uong: '#c2410c', bar: '#7048e8', giai_tri: '#1c6fb8', quan_nuoc: '#8a5a2b' };
    var SHORT_LIST = 5;
    var FAILED = 'Chưa tải được địa điểm, thử lại sau.';
    var TILE_URL = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    var ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors';
    var VN_CENTER = [16.2, 106.3];
    var BOUNDS = { latMin: 8, latMax: 23.5, lngMin: 102, lngMax: 110 };

    var LT = window.LocalTour || {
        url: function (path) {
            var meta = document.querySelector('meta[name="app-base-url"]');
            var base = String((meta && meta.getAttribute('content')) || '/').replace(/\/+$/, '');
            return base + '/' + String(path || '').replace(/^\/+/, '');
        }
    };

    function hasLeaflet() {
        return typeof window.L !== 'undefined' && window.L && typeof window.L.map === 'function';
    }

    function readJson() {
        var node = document.querySelector('.js-map-data');
        if (!node) {
            return null;
        }
        try {
            return JSON.parse(node.textContent || 'null');
        } catch (error) {
            return null;
        }
    }

    /** 120 → "120 m", 1234 → "1,2 km" */
    function formatDistance(meters) {
        var value = Math.max(0, Math.round(Number(meters) || 0));
        if (value < 1000) {
            return value + ' m';
        }
        return (value / 1000).toFixed(1).replace('.', ',') + ' km';
    }

    /** "2026-11-11 16:30:00" → "11/11/2026" */
    function formatDate(value) {
        var match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(value || ''));
        return match ? match[3] + '/' + match[2] + '/' + match[1] : '';
    }

    function validPoint(lat, lng) {
        return isFinite(lat) && isFinite(lng) && lat >= BOUNDS.latMin && lat <= BOUNDS.latMax
            && lng >= BOUNDS.lngMin && lng <= BOUNDS.lngMax;
    }

    function el(tag, className, text) {
        var node = document.createElement(tag);
        if (className) {
            node.className = className;
        }
        if (text !== undefined && text !== null) {
            node.textContent = String(text);
        }
        return node;
    }

    /** Dòng thông báo trên bản đồ (lỗi nền bản đồ, thiếu Leaflet). */
    function showNotice($map, message) {
        $map.find('.js-map-notice').text(message).prop('hidden', false);
    }

    /** Ghim điểm khởi hành (HTML cố định, không chứa dữ liệu). */
    function pinIcon(extraClass) {
        return window.L.divIcon({
            className: 'lt-map-pin' + (extraClass ? ' ' + extraClass : ''),
            html: '<span class="lt-map-pin__dot"></span>',
            iconSize: [30, 40],
            iconAnchor: [15, 38],
            popupAnchor: [0, -34]
        });
    }

    /** Bản đồ Leaflet với nền OpenStreetMap; cuộn chuột chỉ phóng to sau khi bấm vào bản đồ. */
    function createMap($map, center, zoom) {
        var canvas = $map.find('.js-map-canvas').get(0);
        var map = window.L.map(canvas, { scrollWheelZoom: false }).setView(center, zoom);
        var tiles = window.L.tileLayer(TILE_URL, { maxZoom: 19, attribution: ATTRIBUTION });
        var tileErrors = 0;
        tiles.on('tileerror', function () {
            tileErrors += 1;
            if (tileErrors === 1) {
                showNotice($map, 'Không tải được nền bản đồ OpenStreetMap (kiểm tra kết nối mạng). Các điểm và danh sách vẫn dùng được.');
            }
        });
        tiles.addTo(map);
        map.on('click focus', function () {
            map.scrollWheelZoom.enable();
        });
        map.on('mouseout blur', function () {
            map.scrollWheelZoom.disable();
        });
        return map;
    }

    /** Nội dung popup của một địa điểm (phần tử DOM, không ghép chuỗi HTML). */
    function placePopup(place) {
        var box = el('div', 'lt-map-popup');
        box.appendChild(el('strong', 'lt-map-popup__title', place.name));
        box.appendChild(el('span', 'lt-map-popup__meta', place.type + ' · cách ' + formatDistance(place.distance_m)));
        if (place.address) {
            box.appendChild(el('span', 'lt-map-popup__line', place.address));
        }
        if (place.opening_hours) {
            box.appendChild(el('span', 'lt-map-popup__line', 'Giờ mở cửa: ' + place.opening_hours));
        }
        return box;
    }

    /* ---------- Danh sách và lớp địa điểm theo nhóm ---------- */

    /**
     * $panel chứa .js-map-toggle, .js-map-status, .js-map-lists; map có thể null (không có Leaflet).
     */
    function PlacesView($panel, map, $map) {
        var self = this;
        this.$panel = $panel;
        this.map = map;
        this.$map = $map;
        this.layers = {};
        this.markers = {};
        this.visible = {};
        this.request = null;
        this.circle = null;
        this.tourId = '';

        $.each(GROUPS, function (index, group) {
            self.visible[group] = true;
            self.markers[group] = [];
            if (map) {
                self.layers[group] = window.L.layerGroup().addTo(map);
            }
        });

        $panel.on('click', '.js-map-toggle', function () {
            var group = String($(this).attr('data-group'));
            self.setVisible(group, $(this).attr('aria-pressed') !== 'true');
        });

        $panel.on('click', '.js-map-place', function () {
            self.focusPlace(String($(this).attr('data-group')), Number($(this).attr('data-index')));
        });

        $panel.on('click', '.js-map-more', function () {
            var $button = $(this);
            var expanded = $button.attr('aria-expanded') === 'true';
            $button.closest('.lt-map-group').find('.lt-map-item--extra').prop('hidden', expanded);
            $button.attr('aria-expanded', expanded ? 'false' : 'true').text(expanded ? $button.attr('data-more') : 'Thu gọn');
        });

        $panel.on('click', '.js-map-retry', function () {
            if (self.tourId) {
                self.load(self.tourId);
            }
        });
    }

    PlacesView.prototype.setVisible = function (group, visible) {
        this.visible[group] = visible;
        this.$panel.find('.js-map-toggle[data-group="' + group + '"]').attr('aria-pressed', visible ? 'true' : 'false');
        this.$panel.find('.lt-map-group[data-group="' + group + '"]').prop('hidden', !visible);
        if (this.map && this.layers[group]) {
            if (visible) {
                this.layers[group].addTo(this.map);
            } else {
                this.layers[group].remove();
            }
        }
    };

    PlacesView.prototype.focusPlace = function (group, index) {
        var marker = this.markers[group] && this.markers[group][index];
        if (!this.map || !marker) {
            return;
        }
        if (!this.visible[group]) {
            this.setVisible(group, true);
        }
        this.map.setView(marker.getLatLng(), Math.max(this.map.getZoom(), 17));
        marker.openPopup();
        var canvas = this.$map.find('.js-map-canvas').get(0);
        if (canvas && canvas.getBoundingClientRect().top < 0) {
            canvas.scrollIntoView({ block: 'center' });
        }
    };

    PlacesView.prototype.clear = function () {
        var self = this;
        $.each(GROUPS, function (index, group) {
            self.markers[group] = [];
            if (self.layers[group]) {
                self.layers[group].clearLayers();
            }
        });
        if (this.circle) {
            this.circle.remove();
            this.circle = null;
        }
        this.$panel.find('.js-map-lists').empty();
        this.$panel.find('.js-map-count').text('…');
        this.$panel.find('.js-map-toggle').prop('disabled', true);
    };

    PlacesView.prototype.status = function (message, withRetry) {
        var $status = this.$panel.find('.js-map-status').empty().text(message);
        if (withRetry) {
            $status.append(' ', $('<button type="button" class="lt-linklike js-map-retry">').text('Thử lại'));
        }
    };

    PlacesView.prototype.load = function (tourId) {
        var self = this;
        this.tourId = tourId;
        if (this.request) {
            this.request.abort();
        }
        this.clear();
        this.status('Đang tải địa điểm quanh điểm khởi hành…', false);

        this.request = $.ajax({
            url: LT.url('/api/tours/' + encodeURIComponent(tourId) + '/places'),
            dataType: 'json',
            timeout: 35000
        }).done(function (response) {
            if (!response || response.success !== true || !response.data || !response.data.groups) {
                self.status((response && response.message) || FAILED, true);
                return;
            }
            self.render(response.data);
        }).fail(function (xhr, textStatus) {
            if (textStatus === 'abort') {
                return;
            }
            var message = xhr.responseJSON && xhr.responseJSON.message ? String(xhr.responseJSON.message) : FAILED;
            self.status(message, true);
        }).always(function () {
            self.request = null;
        });
    };

    PlacesView.prototype.render = function (data) {
        var self = this;
        var total = 0;
        var lists = this.$panel.find('.js-map-lists').get(0);
        var tour = data.tour || {};

        // Máy chủ chưa lấy được dữ liệu và chưa có bản lưu: không vẽ danh sách rỗng (không có nghĩa là quanh đó
        // không có gì), chỉ báo lỗi kèm nút "Thử lại".
        if (data.source === 'none') {
            this.$panel.find('.js-map-count').text('–');
            this.status(data.message ? String(data.message) : FAILED, true);
            return;
        }

        if (this.map && isFinite(tour.lat) && isFinite(tour.lng) && data.radius_m) {
            this.circle = window.L.circle([tour.lat, tour.lng], {
                radius: Number(data.radius_m), color: '#176b5f', weight: 1, opacity: 0.6, fillOpacity: 0.04,
                dashArray: '4 6', interactive: false
            }).addTo(this.map);
        }

        $.each(GROUPS, function (index, group) {
            var places = $.isArray(data.groups[group]) ? data.groups[group] : [];
            total += places.length;
            self.$panel.find('.js-map-toggle[data-group="' + group + '"]').prop('disabled', false)
                .find('.js-map-count').text(String(places.length));
            lists.appendChild(self.groupList(group, places));
            $.each(places, function (placeIndex, place) {
                if (!self.map || !isFinite(place.lat) || !isFinite(place.lng)) {
                    return;
                }
                var marker = window.L.circleMarker([place.lat, place.lng], {
                    radius: 7, color: '#ffffff', weight: 2, fillColor: COLORS[group], fillOpacity: 0.95
                }).bindPopup(placePopup(place));
                marker.bindTooltip(String(place.name), { direction: 'top', offset: [0, -6] });
                self.layers[group].addLayer(marker);
                self.markers[group].push(marker);
            });
            if (!self.visible[group]) {
                self.setVisible(group, false);
            }
        });

        var updated = formatDate(data.fetched_at);
        var message = data.message ? String(data.message) : '';
        if (total === 0) {
            this.status(message || 'Không tìm thấy địa điểm có tên trong bán kính ' + formatDistance(data.radius_m) + '.', data.source === 'none');
        } else {
            this.status(message || ('Tìm thấy ' + total + ' địa điểm' + (updated ? ', dữ liệu cập nhật ngày ' + updated : '') + '.'), false);
        }
    };

    /** Một nhóm: tiêu đề, SHORT_LIST địa điểm gần nhất, nút "Xem thêm" cho phần còn lại. */
    PlacesView.prototype.groupList = function (group, places) {
        var section = el('section', 'lt-map-group lt-map-group--' + group);
        section.setAttribute('data-group', group);
        section.hidden = !this.visible[group];
        var title = el('h4', 'lt-map-group__title');
        title.appendChild(el('span', 'lt-map-chip__dot'));
        title.appendChild(document.createTextNode(LABELS[group] + ' '));
        title.appendChild(el('span', 'lt-map-group__count', '(' + places.length + ')'));
        section.appendChild(title);

        if (!places.length) {
            section.appendChild(el('p', 'lt-empty-note', 'Không có địa điểm có tên trong bán kính.'));
            return section;
        }

        var list = el('ol', 'lt-map-list');
        var interactive = !!this.map;
        $.each(places, function (index, place) {
            var item = el('li', 'lt-map-item' + (index >= SHORT_LIST ? ' lt-map-item--extra' : ''));
            item.hidden = index >= SHORT_LIST;
            var body = el(interactive ? 'button' : 'div', 'lt-map-item__body' + (interactive ? ' js-map-place' : ''));
            if (interactive) {
                body.type = 'button';
                body.setAttribute('data-group', group);
                body.setAttribute('data-index', String(index));
                body.setAttribute('title', 'Xem trên bản đồ');
            }
            body.appendChild(el('span', 'lt-map-item__name', place.name));
            body.appendChild(el('span', 'lt-map-item__meta', place.type + ' · ' + formatDistance(place.distance_m)));
            item.appendChild(body);
            list.appendChild(item);
        });
        section.appendChild(list);

        if (places.length > SHORT_LIST) {
            var moreText = 'Xem thêm ' + (places.length - SHORT_LIST) + ' địa điểm';
            var more = el('button', 'lt-linklike lt-map-more js-map-more', moreText);
            more.type = 'button';
            more.setAttribute('aria-expanded', 'false');
            more.setAttribute('data-more', moreText);
            section.appendChild(more);
        }
        return section;
    };

    /* ---------- Trang chi tiết tour ---------- */

    function initTour($map) {
        var tour = readJson();
        if (!tour || !isFinite(tour.lat) || !isFinite(tour.lng)) {
            return;
        }
        var map = null;
        if (hasLeaflet()) {
            map = createMap($map, [tour.lat, tour.lng], 15);
            window.L.marker([tour.lat, tour.lng], { icon: pinIcon(), title: 'Điểm khởi hành: ' + tour.title, keyboard: true, zIndexOffset: 1000 })
                .bindPopup(startPopup(tour))
                .addTo(map);
        } else {
            $map.addClass('is-unavailable');
            showNotice($map, 'Không tải được bản đồ. Danh sách địa điểm bên dưới vẫn dùng được.');
        }
        new PlacesView($('.js-map-places'), map, $map).load(String(tour.id));
    }

    function startPopup(tour) {
        var box = el('div', 'lt-map-popup');
        box.appendChild(el('strong', 'lt-map-popup__title', tour.title));
        box.appendChild(el('span', 'lt-map-popup__line', tour.departure));
        return box;
    }

    /* ---------- Trang /ban-do ---------- */

    function initAll($map) {
        var data = readJson();
        var tours = data && $.isArray(data.tours) ? data.tours : [];
        if (!tours.length) {
            return;
        }
        var map = null;
        var markers = {};
        var $panel = $('.js-map-places');
        var view = null;

        if (hasLeaflet()) {
            map = createMap($map, VN_CENTER, 5);
            var bounds = [];
            $.each(tours, function (index, tour) {
                if (!isFinite(tour.lat) || !isFinite(tour.lng)) {
                    return;
                }
                var marker = window.L.marker([tour.lat, tour.lng], { icon: pinIcon(), title: tour.title, keyboard: true, riseOnHover: true })
                    .bindPopup(tourPopup(tour))
                    .addTo(map);
                marker.on('click', function () {
                    select(tour, false);
                });
                markers[tour.id] = marker;
                bounds.push([tour.lat, tour.lng]);
            });
            if (bounds.length > 1) {
                map.fitBounds(bounds, { padding: [32, 32], maxZoom: 13 });
            } else if (bounds.length === 1) {
                map.setView(bounds[0], 14);
            }
        } else {
            $map.addClass('is-unavailable');
            showNotice($map, 'Không tải được bản đồ. Chọn tour trong danh sách để xem địa điểm xung quanh.');
        }
        view = new PlacesView($panel, map, $map);

        function select(tour, fromList) {
            $('.js-map-tour').each(function () {
                var active = $(this).attr('data-tour-id') === tour.id;
                $(this).attr('aria-pressed', active ? 'true' : 'false').toggleClass('is-active', active);
            });
            $.each(markers, function (id, marker) {
                var element = marker.getElement();
                if (element) {
                    $(element).toggleClass('is-active', id === tour.id);
                }
            });
            $panel.find('.js-map-pick-hint').prop('hidden', true);
            $panel.find('.js-map-selected').prop('hidden', false);
            $panel.find('.js-map-tour-title').text(tour.title);
            $panel.find('.js-map-tour-departure').text(tour.departure);
            $panel.find('.js-map-tour-link').attr('href', tour.url);
            if (map) {
                map.setView([tour.lat, tour.lng], 15);
                if (markers[tour.id]) {
                    markers[tour.id].openPopup();
                }
            }
            if (fromList) {
                var canvas = $map.find('.js-map-canvas').get(0);
                if (canvas && canvas.getBoundingClientRect().top < 0) {
                    canvas.scrollIntoView({ block: 'start' });
                }
            }
            if (window.history && window.history.replaceState) {
                window.history.replaceState(null, '', LT.url('/ban-do') + '?tour=' + encodeURIComponent(tour.id));
            }
            view.load(String(tour.id));
        }

        $('.js-map-tour').on('click', function () {
            var id = $(this).attr('data-tour-id');
            $.each(tours, function (index, tour) {
                if (tour.id === id) {
                    select(tour, true);
                }
            });
        });

        if (data.selected) {
            $.each(tours, function (index, tour) {
                if (tour.id === data.selected) {
                    select(tour, false);
                }
            });
        }
    }

    function tourPopup(tour) {
        var box = el('div', 'lt-map-popup');
        box.appendChild(el('strong', 'lt-map-popup__title', tour.title));
        if (tour.destination) {
            box.appendChild(el('span', 'lt-map-popup__meta', tour.destination + (tour.duration ? ' · ' + tour.duration : '')));
        }
        box.appendChild(el('span', 'lt-map-popup__line', tour.departure));
        var link = el('a', 'lt-map-popup__link', 'Xem chi tiết tour');
        link.href = tour.url;
        box.appendChild(link);
        return box;
    }

    /* ---------- Trang quản trị: chọn vị trí ---------- */

    function parseCoord(value) {
        var text = String(value || '').trim().replace(',', '.');
        return /^-?\d{1,3}(\.\d+)?$/.test(text) ? Number(text) : NaN;
    }

    function initPick($map) {
        var $lat = $('#location-latitude');
        var $lng = $('#location-longitude');
        var $status = $('.js-map-status');
        if (!$lat.length || !$lng.length) {
            return;
        }
        if (!hasLeaflet()) {
            $map.addClass('is-unavailable');
            showNotice($map, 'Không tải được bản đồ. Vẫn nhập được vĩ độ và kinh độ ở trên.');
            return;
        }

        var lat = parseCoord($lat.val());
        var lng = parseCoord($lng.val());
        var hasPoint = validPoint(lat, lng);
        var map = createMap($map, hasPoint ? [lat, lng] : VN_CENTER, hasPoint ? 16 : 5);
        var marker = null;

        function place(latlng) {
            if (!marker) {
                marker = window.L.marker(latlng, { icon: pinIcon(), draggable: true, keyboard: true, title: 'Điểm khởi hành (kéo để chỉnh)' }).addTo(map);
                marker.on('dragend', function () {
                    fill(marker.getLatLng());
                });
            } else {
                marker.setLatLng(latlng);
            }
        }

        function fill(latlng) {
            var newLat = latlng.lat.toFixed(6);
            var newLng = latlng.lng.toFixed(6);
            $lat.val(newLat);
            $lng.val(newLng);
            if (validPoint(Number(newLat), Number(newLng))) {
                $status.text('Đã chọn điểm ' + newLat + ', ' + newLng + '. Bấm "Lưu vị trí" để lưu.');
            } else {
                $status.text('Điểm vừa chọn nằm ngoài khung Việt Nam, không lưu được.');
            }
        }

        if (hasPoint) {
            place([lat, lng]);
        }

        map.on('click', function (event) {
            place(event.latlng);
            fill(event.latlng);
        });

        $lat.add($lng).on('change', function () {
            var newLat = parseCoord($lat.val());
            var newLng = parseCoord($lng.val());
            if (validPoint(newLat, newLng)) {
                place([newLat, newLng]);
                map.setView([newLat, newLng], Math.max(map.getZoom(), 15));
            } else if (String($lat.val()).trim() === '' && String($lng.val()).trim() === '' && marker) {
                marker.remove();
                marker = null;
            }
        });
    }

    $(function () {
        var $map = $('.js-places-map').first();
        if (!$map.length) {
            return;
        }
        try {
            var mode = $map.attr('data-mode');
            if (mode === 'tour') {
                initTour($map);
            } else if (mode === 'all') {
                initAll($map);
            } else if (mode === 'pick') {
                initPick($map);
            }
        } catch (error) {
            // Lỗi bất ngờ của thư viện bản đồ không được làm hỏng phần còn lại của trang.
            showNotice($map, 'Không hiển thị được bản đồ.');
            if (window.console && window.console.warn) {
                window.console.warn('tour-map.js:', error);
            }
        }
    });
}(window, document, window.jQuery));
