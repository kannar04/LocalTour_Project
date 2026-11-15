/*
 * LocalTour – tour-comments.js (CR3 – Nguyễn Minh Thức)
 * Mục "Bình luận" trên trang chi tiết tour (views/tours/comments-section.php):
 *   - tải bình luận qua GET /api/tours/{id}/comments?page=N (10 bình luận mỗi lần, mới nhất trước), nút "Xem thêm";
 *   - tài khoản khách hàng gửi bình luận (POST /api/tours/{id}/comments, 1–1000 ký tự) và xóa bình luận của mình
 *     (POST /api/comments/{id}/delete);
 *   - sau khi gửi / xóa: $(document).trigger('lt:comment-count', [tourId, total]) để nút "Bình luận" (tour-social.js)
 *     cập nhật số bình luận.
 * Dữ liệu từ server chỉ đưa vào DOM bằng .text() / .attr().
 */
(function (window, document, $) {
    'use strict';

    var LT = window.LocalTour;

    $(function () {
        var $root = $('.js-tour-comments').first();
        if (!$root.length || !LT) {
            return;
        }

        var tourId = LT.normaliseId($root.attr('data-tour-id'));
        if (!tourId) {
            return;
        }

        var maxLength = Number($root.attr('data-max-length')) || 1000;
        var loginUrl = $root.attr('data-login-url') || LT.url('/login');
        var $section = $root.closest('.lt-section');
        var $count = $section.find('.js-comments-count');
        var $list = $root.find('.js-comments-list');
        var $status = $root.find('.js-comments-status');
        var $more = $root.find('.js-comments-more');
        var $form = $root.find('.js-comment-form');
        var $input = $form.find('.js-comment-input');
        var $counter = $form.find('.js-comment-counter');
        var $error = $form.find('.js-comment-error');
        var $submit = $form.find('.js-comment-submit');

        var state = { page: 0, total: 0, loading: false, sending: false, seen: {} };

        function csrfToken() {
            var meta = document.querySelector('meta[name="csrf-token"]');
            return meta ? String(meta.getAttribute('content') || '') : '';
        }

        /** Số ký tự như mb_strlen ở server (emoji = 1 ký tự). */
        function charCount(text) {
            return String(text).replace(/[\uD800-\uDBFF][\uDC00-\uDFFF]/g, '_').length;
        }

        function cleanText(text) {
            return String(text || '').replace(/\r\n?/g, '\n').trim();
        }

        function responseMessage(xhr, fallback) {
            var body = xhr && xhr.responseJSON;
            return body && typeof body.message === 'string' && body.message !== '' ? body.message : fallback;
        }

        function setCount(total) {
            state.total = Math.max(0, Number(total) || 0);
            if (state.total > 0) {
                $count.text(String(state.total)).prop('hidden', false);
            } else {
                $count.text('').prop('hidden', true);
            }
        }

        function setStatus(message) {
            $status.text(message).prop('hidden', message === '');
        }

        function showEmptyIfNeeded() {
            if ($list.children().length === 0) {
                setStatus($form.length
                    ? 'Chưa có bình luận nào. Hãy là người đầu tiên đặt câu hỏi về tour này.'
                    : 'Chưa có bình luận nào cho tour này.');
            }
        }

        /** "2026-11-15 08:19:49" → "2026-11-15T08:19:49+07:00" (giờ Việt Nam) cho thuộc tính datetime. */
        function isoTime(value) {
            var text = String(value || '');
            return /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(text) ? text.replace(' ', 'T') + '+07:00' : '';
        }

        function buildAvatar(comment) {
            var src = typeof comment.avatar_src === 'string' ? comment.avatar_src : '';
            if (src !== '') {
                return $('<img>').addClass('lt-avatar lt-avatar--sm')
                    .attr({ src: src, alt: '', width: 34, height: 34, loading: 'lazy' });
            }
            return $('<span>').addClass('lt-avatar lt-avatar--sm').attr('aria-hidden', 'true')
                .text(String(comment.initial || '?'));
        }

        function buildComment(comment) {
            var id = LT.normaliseId(comment.comment_id);
            var $head = $('<p>').addClass('lt-comment__head').append(
                $('<span>').addClass('lt-comment__name').text(String(comment.user_name || ''))
            );
            if (comment.is_mine) {
                $head.append($('<span>').addClass('lt-comment__mine').text('Bạn'));
            }
            $head.append(
                $('<time>').addClass('lt-comment__time')
                    .attr('datetime', isoTime(comment.created_at))
                    .text(String(comment.created_text || ''))
            );

            var $body = $('<div>').addClass('lt-comment__body').append(
                $head,
                $('<p>').addClass('lt-comment__text').text(String(comment.content || ''))
            );
            if (comment.is_mine) {
                $body.append(
                    $('<button>').addClass('lt-linklike lt-comment__delete js-comment-delete').attr('type', 'button')
                        .append(LT.icon('trash'), document.createTextNode('Xóa'),
                            $('<span>').addClass('sr-only').text(' bình luận của bạn'))
                );
            }

            return $('<li>').addClass('lt-comment').attr('data-comment-id', id)
                .append(buildAvatar(comment), $body);
        }

        function load(page) {
            if (state.loading) {
                return;
            }
            state.loading = true;
            $more.prop('disabled', true).text('Đang tải…');
            if (page === 1) {
                setStatus('Đang tải bình luận…');
            }

            $.getJSON(LT.url('/api/tours/' + tourId + '/comments'), { page: page })
                .done(function (response) {
                    var data = response && response.success ? response.data : null;
                    if (!data || !$.isArray(data.comments)) {
                        setStatus('Không tải được bình luận. Vui lòng tải lại trang.');
                        return;
                    }
                    state.page = page;
                    setCount(data.total);
                    $.each(data.comments, function (index, comment) {
                        var id = LT.normaliseId(comment.comment_id);
                        if (id && !state.seen[id]) {
                            state.seen[id] = true;
                            $list.append(buildComment(comment));
                        }
                    });
                    setStatus('');
                    showEmptyIfNeeded();
                    $more.prop('hidden', !data.has_more);
                })
                .fail(function (xhr) {
                    setStatus(responseMessage(xhr, 'Không tải được bình luận. Vui lòng thử lại.'));
                })
                .always(function () {
                    state.loading = false;
                    $more.prop('disabled', false).text('Xem thêm bình luận');
                });
        }

        function updateCounter() {
            var length = charCount(cleanText($input.val()));
            $counter.text(length + '/' + maxLength + ' ký tự').toggleClass('is-over', length > maxLength);
        }

        function showError(message, withLogin) {
            $error.empty().text(message);
            if (withLogin) {
                $error.append(' ', $('<a>').attr('href', loginUrl).text('Đăng nhập lại'));
            }
            $error.prop('hidden', false);
            $input.addClass('is-invalid').attr('aria-invalid', 'true').attr('aria-describedby', 'comment-error comment-counter comment-rules');
        }

        function clearError() {
            $error.empty().prop('hidden', true);
            $input.removeClass('is-invalid').removeAttr('aria-invalid').attr('aria-describedby', 'comment-counter comment-rules');
        }

        function setSending(sending) {
            state.sending = sending;
            $submit.prop('disabled', sending).text(sending ? 'Đang gửi…' : 'Gửi bình luận');
        }

        $input.on('input', function () {
            updateCounter();
            if (!$error.prop('hidden')) {
                clearError();
            }
        });

        $form.on('submit', function (event) {
            event.preventDefault();
            if (state.sending) {
                return;
            }

            var content = cleanText($input.val());
            var length = charCount(content);
            if (length === 0) {
                showError('Vui lòng nhập nội dung bình luận.', false);
                $input.trigger('focus');
                return;
            }
            if (length > maxLength) {
                showError('Bình luận tối đa ' + maxLength + ' ký tự (hiện có ' + length + ').', false);
                $input.trigger('focus');
                return;
            }

            clearError();
            setSending(true);
            $.ajax({
                url: LT.url('/api/tours/' + tourId + '/comments'),
                method: 'POST',
                dataType: 'json',
                data: { content: content, _csrf: csrfToken() }
            })
                .done(function (response) {
                    var data = response && response.success ? response.data : null;
                    if (!data || !data.comment) {
                        showError('Không gửi được bình luận. Vui lòng thử lại.', false);
                        return;
                    }
                    var id = LT.normaliseId(data.comment.comment_id);
                    if (id) {
                        state.seen[id] = true;
                    }
                    var $item = buildComment(data.comment).addClass('is-new');
                    $list.prepend($item);
                    $input.val('');
                    updateCounter();
                    setCount(data.total);
                    setStatus('');
                    $(document).trigger('lt:comment-count', [tourId, state.total]);
                })
                .fail(function (xhr) {
                    var status = xhr && xhr.status;
                    showError(responseMessage(xhr, 'Không gửi được bình luận. Vui lòng thử lại.'), status === 401);
                })
                .always(function () {
                    setSending(false);
                });
        });

        $list.on('click', '.js-comment-delete', function () {
            var $button = $(this);
            var $item = $button.closest('.lt-comment');
            var id = LT.normaliseId($item.attr('data-comment-id'));
            if (!id || !window.confirm('Xóa bình luận này? Bình luận đã xóa không khôi phục được.')) {
                return;
            }

            $button.prop('disabled', true);
            $.ajax({
                url: LT.url('/api/comments/' + id + '/delete'),
                method: 'POST',
                dataType: 'json',
                data: { _csrf: csrfToken() }
            })
                .done(function (response) {
                    var data = response && response.success ? response.data : null;
                    $item.remove();
                    setCount(data ? data.total : state.total - 1);
                    showEmptyIfNeeded();
                    $section.trigger('focus');
                    $(document).trigger('lt:comment-count', [tourId, state.total]);
                })
                .fail(function (xhr) {
                    $button.prop('disabled', false);
                    window.alert(responseMessage(xhr, 'Không xóa được bình luận. Vui lòng thử lại.'));
                });
        });

        $more.on('click', function () {
            load(state.page + 1);
        });

        updateCounter();
        load(1);
    });
})(window, document, jQuery);
