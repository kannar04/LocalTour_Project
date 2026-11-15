/*
 * LocalTour – tour-social.js (CR3, Nguyễn Minh Thức)
 * Thích / Bình luận / Chia sẻ / Lưu tour.
 *  - Khối .js-tour-social (data-tour-id, data-variant = "card" | "detail", data-tour-title, data-tour-url) được điền
 *    nút khi trang tải xong và sau sự kiện 'lt:tours-rendered' (tour-list.js vẽ lại thẻ tour).
 *    Số lượt thích / bình luận, đã thích / đã lưu: một lần GET /api/social/tours?ids=... cho cả trang (tối đa 60 mã).
 *  - Thích / Lưu: POST /api/tours/{id}/like | /save (liked / saved = 1 | 0, _csrf, next). Chỉ tài khoản khách hàng;
 *    khách chưa đăng nhập được chuyển tới trang đăng nhập rồi quay lại đúng trang đang xem.
 *    Nút đổi trạng thái ngay (optimistic), lỗi thì trả lại như cũ và báo lỗi.
 *  - Chia sẻ: Web Share API của trình duyệt; không có thì chép liên kết vào bộ nhớ tạm.
 *  - "Bình luận": link tới mục #binh-luan của trang chi tiết; sự kiện 'lt:comment-count' [tourId, count]
 *    (tour-comments.js) cập nhật số bình luận.
 *  - Trang "Tour đã lưu": nút .js-saved-remove bỏ lưu và gỡ thẻ.
 * window.LocalTourSocial = { refresh() } – vẽ lại và tải lại số liệu của mọi khối trên trang.
 * Dữ liệu từ server chỉ được đưa vào DOM bằng .text() / .attr().
 */
(function (window, document, $) {
    'use strict';

    var LT = window.LocalTour;
    var MAX_IDS = 60;
    var ONLY_CUSTOMER = 'Chỉ tài khoản khách hàng mới thích hoặc lưu được tour.';
    var GENERIC_ERROR = 'Chưa lưu được thao tác. Vui lòng thử lại.';

    /** Trạng thái theo mã tour: { like_count, comment_count, liked, saved } (null = chưa tải được). */
    var states = {};
    /** Người đang xem: 'guest' | 'customer' | 'other' (null = chưa biết). */
    var viewer = null;
    /** Thao tác đang gửi theo "mã tour:loại" để không gửi chồng. */
    var pending = {};

    function csrfToken() {
        var meta = document.querySelector('meta[name="csrf-token"]');
        return meta ? String(meta.getAttribute('content') || '') : '';
    }

    /** Đường dẫn trang hiện tại tính từ thư mục gốc của ứng dụng (tham số next khi đăng nhập). */
    function currentPath() {
        var basePath = '';
        try {
            basePath = new URL(LT.baseUrl + '/', window.location.href).pathname.replace(/\/+$/, '');
        } catch (error) {
            basePath = '';
        }
        var path = window.location.pathname;
        if (basePath && path.indexOf(basePath) === 0) {
            path = path.slice(basePath.length);
        }
        return (path.charAt(0) === '/' ? path : '/' + path) + window.location.search + window.location.hash;
    }

    function loginUrl() {
        return LT.url('/login') + '?next=' + encodeURIComponent(currentPath());
    }

    function absoluteUrl(href) {
        try {
            return new URL(href, window.location.href).href;
        } catch (error) {
            return String(href || window.location.href);
        }
    }

    /* ---------- Thông báo nhỏ (kiêm vùng aria-live cho trình đọc màn hình) ---------- */

    var $toast = null;
    var toastTimer = null;

    function toast(message, isError) {
        if (!$toast) {
            $toast = $('<div>').addClass('lt-social-toast').attr({ role: 'status', 'aria-live': 'polite' });
            $('body').append($toast);
        }
        window.clearTimeout(toastTimer);
        $toast.removeClass('is-visible').toggleClass('is-error', !!isError).text(message);
        // Đổi lớp ở khung hình sau để hiệu ứng chạy lại khi thông báo liên tiếp.
        window.setTimeout(function () {
            $toast.addClass('is-visible');
        }, 20);
        toastTimer = window.setTimeout(function () {
            $toast.removeClass('is-visible');
        }, isError ? 5000 : 3000);
    }

    /* ---------- Vẽ nút ---------- */

    function countSpan(count, srSuffix) {
        return $('<span>').addClass('lt-social-btn__count').append(
            document.createTextNode(String(count)),
            $('<span>').addClass('sr-only').text(srSuffix)
        );
    }

    /** Nhãn + số (ẩn số khi bằng 0 hoặc chưa tải được). Thẻ: "Thích 12"; chi tiết: "Thích · 12". */
    function labelled($el, label, count, srSuffix, variant) {
        $el.append($('<span>').addClass('lt-social-btn__label').text(label));
        if (typeof count === 'number' && count > 0) {
            if (variant === 'detail') {
                $el.append($('<span>').addClass('lt-social-btn__sep').attr('aria-hidden', 'true').text('·'));
            }
            $el.append(countSpan(count, srSuffix));
        }
        return $el;
    }

    function buttonClass(variant) {
        return (variant === 'detail' ? 'lt-detail-action' : 'lt-action') + ' lt-social-btn';
    }

    function render($box) {
        var id = String($box.attr('data-tour-id') || '');
        var variant = $box.attr('data-variant') === 'detail' ? 'detail' : 'card';
        var title = String($box.attr('data-tour-title') || '');
        var tourUrl = String($box.attr('data-tour-url') || LT.url('/tours/' + encodeURIComponent(id)));
        var state = states[id] || null;
        var loaded = state !== null;
        var liked = loaded && state.liked;
        var saved = loaded && state.saved;

        if (variant === 'card' && !$box.attr('role')) {
            $box.attr({ role: 'group', 'aria-label': 'Tương tác với tour ' + title });
        }

        var $like = labelled(
            $('<button>').attr({ type: 'button', 'aria-pressed': liked ? 'true' : 'false' })
                .addClass(buttonClass(variant) + ' lt-social-btn--like js-social-like')
                .append(LT.icon('heart')),
            'Thích', loaded ? state.like_count : null, ' lượt thích', variant
        );

        var $comment = labelled(
            $('<a>').attr('href', variant === 'detail' ? '#binh-luan' : tourUrl + '#binh-luan')
                .addClass(buttonClass(variant) + ' lt-social-btn--comment js-social-comment')
                .append(LT.icon('message')),
            'Bình luận', loaded ? state.comment_count : null, ' bình luận', variant
        );

        var $share = labelled(
            $('<button>').attr('type', 'button')
                .addClass(buttonClass(variant) + ' lt-social-btn--share js-social-share')
                .append(LT.icon('share')),
            'Chia sẻ', null, '', variant
        );

        var saveLabel = variant === 'detail' ? (saved ? 'Đã lưu' : 'Lưu tour') : (saved ? 'Đã lưu' : 'Lưu');
        var $save = labelled(
            $('<button>').attr({ type: 'button', 'aria-pressed': saved ? 'true' : 'false' })
                .addClass(buttonClass(variant) + ' lt-social-btn--save js-social-save')
                .append(LT.icon('bookmark')),
            saveLabel, null, '', variant
        );

        // Chưa biết đã thích / đã lưu chưa thì chưa cho bấm (tránh đảo sai trạng thái).
        if (!loaded && viewer !== 'guest') {
            $like.prop('disabled', true);
            $save.prop('disabled', true);
        }
        // Đang gửi: aria-disabled (không dùng disabled) để nút vẫn giữ được focus bàn phím.
        $.each([['like', $like], ['save', $save]], function (index, pair) {
            if (pending[id + ':' + pair[0]]) {
                pair[1].attr({ 'aria-disabled': 'true', 'aria-busy': 'true' });
            }
        });

        // Vẽ lại thì trả focus về đúng nút đang được chọn.
        var focusedKind = null;
        var active = document.activeElement;
        if (active && $box[0] !== active && $.contains($box[0], active)) {
            $.each(['like', 'comment', 'share', 'save'], function (index, kind) {
                if ($(active).hasClass('js-social-' + kind)) {
                    focusedKind = kind;
                }
            });
        }

        $box.empty().append($like, $comment, $share, $save).attr('data-social-ready', 'done');
        if (focusedKind) {
            $box.find('.js-social-' + focusedKind).trigger('focus');
        }
    }

    function renderTour(id) {
        $('.js-tour-social').filter(function () {
            return $(this).attr('data-tour-id') === id;
        }).each(function () {
            render($(this));
        });
    }

    /* ---------- Tải số liệu ---------- */

    function fetchStates(ids) {
        if (!ids.length) {
            return;
        }
        $.getJSON(LT.url('/api/social/tours'), { ids: ids.join(',') })
            .done(function (response) {
                var data = response && response.success ? response.data : null;
                if (!data) {
                    return;
                }
                if (data.viewer === 'guest' || data.viewer === 'customer' || data.viewer === 'other') {
                    viewer = data.viewer;
                }
                var tours = data.tours || {};
                $.each(ids, function (index, id) {
                    var row = tours[id];
                    if (row) {
                        states[id] = {
                            like_count: Number(row.like_count) || 0,
                            comment_count: Number(row.comment_count) || 0,
                            liked: row.liked === true,
                            saved: row.saved === true
                        };
                    }
                    renderTour(id);
                });
            })
            .fail(function () {
                // Không tải được số liệu: vẫn cho bấm, server trả trạng thái thật.
                $.each(ids, function (index, id) {
                    if (!states[id]) {
                        states[id] = { like_count: null, comment_count: null, liked: false, saved: false, unknown: true };
                    }
                    renderTour(id);
                });
            });
    }

    /** Điền các khối chưa có nút; force = vẽ lại và tải lại tất cả. */
    function scan(force) {
        var ids = [];
        $('.js-tour-social').each(function () {
            var $box = $(this);
            var id = LT.normaliseId($box.attr('data-tour-id'));
            if (!id) {
                return;
            }
            $box.attr('data-tour-id', id);
            if (!force && $box.attr('data-social-ready')) {
                return;
            }
            if (force) {
                delete states[id];
            }
            render($box);
            if (ids.indexOf(id) === -1 && (force || !states[id] || states[id].unknown)) {
                ids.push(id);
            }
        });
        for (var start = 0; start < ids.length; start += MAX_IDS) {
            fetchStates(ids.slice(start, start + MAX_IDS));
        }
    }

    /* ---------- Thích / Lưu ---------- */

    function failMessage(xhr) {
        var response = xhr && xhr.responseJSON;
        return response && typeof response.message === 'string' && response.message !== '' ? response.message : GENERIC_ERROR;
    }

    /**
     * Gửi thích / lưu. kind = 'like' | 'save'; want = trạng thái muốn có.
     * Trả về jqXHR (hoặc null khi không gửi).
     */
    function send(id, kind, want) {
        var key = id + ':' + kind;
        if (pending[key]) {
            return null;
        }
        if (viewer === 'guest') {
            window.location.href = loginUrl();
            return null;
        }
        if (viewer === 'other') {
            toast(ONLY_CUSTOMER, true);
            return null;
        }

        var field = kind === 'like' ? 'liked' : 'saved';
        var payload = { _csrf: csrfToken(), next: currentPath() };
        payload[field] = want ? '1' : '0';
        pending[key] = true;

        return $.ajax({
            url: LT.url('/api/tours/' + encodeURIComponent(id) + '/' + kind),
            method: 'POST',
            data: payload,
            dataType: 'json'
        }).fail(function (xhr) {
            if (xhr.status === 401) {
                var data = xhr.responseJSON && xhr.responseJSON.data;
                window.location.href = data && typeof data.login_url === 'string' && /^(\/|https?:\/\/)/i.test(data.login_url)
                    ? data.login_url
                    : loginUrl();
            }
        }).always(function () {
            delete pending[key];
        });
    }

    function toggle(id, kind) {
        var state = states[id];
        if (!state) {
            return;
        }
        var field = kind === 'like' ? 'liked' : 'saved';
        var before = $.extend({}, state);
        var want = !state[field];

        var request = send(id, kind, want);
        if (!request) {
            return;
        }

        // Đổi ngay trên giao diện, đợi server xác nhận.
        state[field] = want;
        if (kind === 'like' && typeof state.like_count === 'number') {
            state.like_count = Math.max(0, state.like_count + (want ? 1 : -1));
        }
        renderTour(id);

        request.done(function (response) {
            var data = response && response.data ? response.data : {};
            var current = states[id] || state;
            if (kind === 'like') {
                current.liked = data.liked === true;
                current.like_count = Number(data.like_count) || 0;
            } else {
                current.saved = data.saved === true;
            }
            current.unknown = false;
            states[id] = current;
            renderTour(id);
            toast(response && response.message ? response.message : (want ? 'Đã lưu.' : 'Đã bỏ.'));
        }).fail(function (xhr) {
            states[id] = before;
            renderTour(id);
            if (xhr.status !== 401) {
                toast(failMessage(xhr), true);
            }
        });
    }

    /* ---------- Chia sẻ ---------- */

    function copyFallback(text) {
        var $area = $('<textarea>').attr({ readonly: 'readonly', 'aria-hidden': 'true' })
            .css({ position: 'fixed', top: 0, left: '-9999px', opacity: 0 })
            .val(text);
        $('body').append($area);
        $area[0].select();
        var copied = false;
        try {
            copied = document.execCommand('copy');
        } catch (error) {
            copied = false;
        }
        $area.remove();
        if (copied) {
            toast('Đã sao chép liên kết');
        } else {
            window.prompt('Sao chép liên kết tour:', text);
        }
    }

    function copyLink(text) {
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(text).then(function () {
                toast('Đã sao chép liên kết');
            }, function () {
                copyFallback(text);
            });
            return;
        }
        copyFallback(text);
    }

    function share($box) {
        var title = String($box.attr('data-tour-title') || document.title);
        var link = absoluteUrl($box.attr('data-tour-url') || window.location.href);
        var data = { title: title, text: title + ' – LocalTour', url: link };

        if (navigator.share && (!navigator.canShare || navigator.canShare(data))) {
            navigator.share(data).catch(function (error) {
                // Khách tự đóng bảng chia sẻ: không làm gì.
                if (!error || error.name !== 'AbortError') {
                    copyLink(link);
                }
            });
            return;
        }
        copyLink(link);
    }

    /* ---------- Trang "Tour đã lưu" ---------- */

    function removeSaved($button) {
        var id = LT.normaliseId($button.attr('data-tour-id'));
        if (!id || $button.attr('aria-busy') === 'true') {
            return;
        }
        var request = send(id, 'save', false);
        if (!request) {
            return;
        }
        $button.prop('disabled', true).attr('aria-busy', 'true');

        request.done(function (response) {
            var $card = $button.closest('.js-saved-card');
            var $next = $card.next('.js-saved-card').add($card.prev('.js-saved-card')).first();
            var finish = function () {
                $card.remove();
                var left = $('.js-saved-card').length;
                $('#saved-count').text(left + ' tour').prop('hidden', left === 0);
                if (left === 0) {
                    $('#saved-list').remove();
                    $('#saved-empty').prop('hidden', false);
                    $('#saved-title').attr('tabindex', '-1').trigger('focus');
                } else {
                    $next.find('.js-saved-remove').trigger('focus');
                }
            };
            toast(response && response.message ? response.message : 'Đã bỏ lưu tour.');
            if (LT.prefersReducedMotion()) {
                finish();
            } else {
                $card.addClass('is-removing');
                window.setTimeout(finish, 200);
            }
        }).fail(function (xhr) {
            $button.prop('disabled', false).removeAttr('aria-busy');
            if (xhr.status !== 401) {
                toast(failMessage(xhr), true);
            }
        });
    }

    /* ---------- Gắn sự kiện ---------- */

    $(function () {
        if (!LT) {
            return;
        }

        $(document).on('click', '.js-tour-social .js-social-like', function (event) {
            event.preventDefault();
            toggle(String($(this).closest('.js-tour-social').attr('data-tour-id') || ''), 'like');
        });

        $(document).on('click', '.js-tour-social .js-social-save', function (event) {
            event.preventDefault();
            toggle(String($(this).closest('.js-tour-social').attr('data-tour-id') || ''), 'save');
        });

        $(document).on('click', '.js-tour-social .js-social-share', function (event) {
            event.preventDefault();
            share($(this).closest('.js-tour-social'));
        });

        // Trang chi tiết: cuộn tới mục "Bình luận" giống tab neo (tour-detail.js lo phần bù thanh dính).
        $(document).on('click', '.js-tour-social[data-variant="detail"] .js-social-comment', function (event) {
            var $tab = $('.lt-anchor-tab[href="#binh-luan"]').first();
            if ($tab.length && document.getElementById('binh-luan')) {
                event.preventDefault();
                $tab.trigger('click');
            }
        });

        $(document).on('click', '.js-saved-remove', function (event) {
            event.preventDefault();
            removeSaved($(this));
        });

        $(document).on('lt:tours-rendered', function () {
            scan(false);
        });

        $(document).on('lt:comment-count', function (event, tourId, count) {
            var id = LT.normaliseId(tourId);
            var value = Number(count);
            if (!id || !isFinite(value) || value < 0) {
                return;
            }
            if (states[id]) {
                states[id].comment_count = Math.floor(value);
                renderTour(id);
            }
        });

        scan(false);
    });

    window.LocalTourSocial = {
        refresh: function () {
            scan(true);
        }
    };
})(window, document, jQuery);
