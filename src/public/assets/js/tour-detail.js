/*
 * LocalTour – tour-detail.js (Nguyễn Tuấn Khôi)
 * Trang chi tiết tour: lịch khởi hành quyết định giờ và các loại vé (người lớn, trẻ em...). Mỗi loại vé có
 * ô chọn số lượng; tổng số khách từ 1 đến min(nhóm tối đa, chỗ còn lại), tạm tính cập nhật trực tiếp.
 * Tab neo cuộn mượt + đánh dấu mục đang xem.
 * "Đặt tour" gửi form GET tới /tours/{id}/book kèm schedule_id và tickets[<mã vé>]; ở chế độ khách, link
 * "Đăng nhập để đặt tour" được cập nhật để đăng nhập xong vào thẳng trang đặt tour với lựa chọn hiện tại.
 * Dữ liệu vé đọc từ <script type="application/json" id="booking-data"> và chỉ đưa vào DOM bằng .text() / .attr().
 */
(function (window, document, $) {
    'use strict';

    $(function () {
        var LT = window.LocalTour;
        if (!LT) {
            return;
        }

        initBookingCard(LT);
        initAnchorTabs(LT);
    });

    /* ---------- Thẻ giá ---------- */

    function toInt(value) {
        var number = parseInt(value, 10);
        return isNaN(number) ? 0 : number;
    }

    /** { maxGroup, schedules: [{ id, timeText, remaining, tickets: [{ id, label, ages, price }] }] } hoặc null. */
    function readBookingData() {
        var node = document.getElementById('booking-data');
        if (!node) {
            return null;
        }
        try {
            var data = JSON.parse(node.textContent || 'null');
            return data && $.isArray(data.schedules) ? data : null;
        } catch (error) {
            return null;
        }
    }

    function initBookingCard(LT) {
        var $card = $('#booking-card');
        if (!$card.length) {
            return;
        }

        var $form = $('#booking-form');
        var $schedule = $('#booking-schedule');
        var $time = $('#booking-time');
        var $tickets = $('#booking-tickets');
        var $hint = $('#booking-guests-hint');
        var $formula = $('#booking-total .js-total-formula');
        var $amount = $('#booking-total .js-total-amount');
        var $loginLink = $('.js-login-to-book');

        $form.on('submit', function (event) {
            // Không có lịch thì không có gì để đặt.
            if ($schedule.prop('disabled')) {
                event.preventDefault();
            }
        });

        /** Link đăng nhập (chế độ khách): next = trang đặt tour kèm lịch và số khách đang chọn. */
        function updateLoginLink() {
            if (!$loginLink.length) {
                return;
            }
            var query = $form.serialize();
            var next = String($loginLink.attr('data-book-path')) + (query ? '?' + query : '');
            $loginLink.attr('href', String($loginLink.attr('data-login-url')) + '?next=' + encodeURIComponent(next));
        }

        var data = readBookingData();
        var maxGroup = Math.max(1, toInt(data && data.maxGroup));
        var schedules = {};
        $.each(data ? data.schedules : [], function (index, schedule) {
            if (schedule && schedule.id !== undefined && schedule.id !== null) {
                schedules[String(schedule.id)] = schedule;
            }
        });

        if (!$schedule.length || $schedule.prop('disabled') || $.isEmptyObject(schedules)) {
            $time.prop('disabled', true).val('—');
            $tickets.find('input, button').prop('disabled', true);
            $formula.text('Chưa thể tính');
            $amount.text('—');
            return;
        }

        var rows = []; // { label, price, qty, $input, $dec, $inc } của lịch đang chọn

        function currentSchedule() {
            return schedules[String($schedule.val())] || null;
        }

        /** Số khách tối đa của lịch: min(nhóm tối đa, chỗ còn lại). */
        function maxGuests(schedule) {
            var remaining = toInt(schedule && schedule.remaining);
            return Math.max(1, remaining > 0 ? Math.min(maxGroup, remaining) : maxGroup);
        }

        function totalGuests(exceptRow) {
            var total = 0;
            $.each(rows, function (index, row) {
                if (row !== exceptRow) {
                    total += row.qty;
                }
            });
            return total;
        }

        /** Số vé hợp lệ của một loại: từ 0 đến số chỗ còn lại sau khi trừ các loại vé khác. */
        function clampRow(row, value) {
            var limit = Math.max(0, maxGuests(currentSchedule()) - totalGuests(row));
            return Math.min(Math.max(toInt(value), 0), limit);
        }

        function renderHint(schedule, max) {
            var remaining = toInt(schedule && schedule.remaining);
            var text = 'Tối đa ' + max + ' khách';
            if (remaining > 0 && remaining < maxGroup) {
                text += ' · lịch này còn ' + remaining + ' chỗ';
            } else {
                text += ' mỗi nhóm';
            }
            $hint.text(text);
        }

        /** Cập nhật nút +/−, giới hạn ô nhập, gợi ý và dòng "Tạm tính tiền vé" theo số vé hiện tại. */
        function render() {
            var schedule = currentSchedule();
            var max = maxGuests(schedule);
            var total = totalGuests(null);
            var amount = 0;
            var parts = [];

            $.each(rows, function (index, row) {
                row.$dec.prop('disabled', row.qty <= 0 || total <= 1);
                row.$inc.prop('disabled', total >= max);
                row.$input.attr('max', row.qty + Math.max(0, max - total));
                if (row.qty > 0) {
                    parts.push(row.qty + ' ' + row.label);
                    amount += row.qty * row.price;
                }
            });

            renderHint(schedule, max);
            if (!rows.length) {
                $formula.text('Chưa thể tính');
                $amount.text('—');
            } else if (!parts.length) {
                $formula.text('Chưa chọn khách');
                $amount.text(LT.formatVnd(0));
            } else {
                $formula.text(parts.join(' + '));
                $amount.text(LT.formatVnd(amount));
            }
            updateLoginLink();
        }

        /** Đổi số vé của một loại; commit = ghi giá trị đã kẹp vào ô nhập và giữ tổng ít nhất 1 khách. */
        function setQty(row, value, commit) {
            var typed = String(row.$input.val()).trim();
            row.qty = clampRow(row, value);
            if (commit && totalGuests(null) === 0) {
                row.qty = 1;
            }
            // Khi đang gõ dở (ô trống) thì chưa ghi đè, chỉ tính với giá trị hợp lệ.
            if (commit || (typed !== '' && String(row.qty) !== typed)) {
                row.$input.val(row.qty);
            }
            render();
        }

        function buildRow(ticket, label, index, qty) {
            var inputId = 'booking-ticket-' + index;
            var metaId = inputId + '-meta';
            var price = Math.max(0, toInt(ticket.price));
            var ages = ticket.ages ? String(ticket.ages) : '';

            var $dec = $('<button>').addClass('lt-stepper__btn')
                .attr({ type: 'button', 'aria-controls': inputId, 'aria-label': 'Bớt 1 vé ' + label })
                .append(LT.icon('minus'));
            var $inc = $('<button>').addClass('lt-stepper__btn')
                .attr({ type: 'button', 'aria-controls': inputId, 'aria-label': 'Thêm 1 vé ' + label })
                .append(LT.icon('plus'));
            var $input = $('<input>').addClass('lt-input lt-stepper__input')
                .attr({
                    type: 'number',
                    id: inputId,
                    name: 'tickets[' + String(ticket.id) + ']',
                    min: 0,
                    step: 1,
                    inputmode: 'numeric',
                    'aria-describedby': metaId
                })
                .val(qty);

            var $meta = $('<span>').addClass('lt-ticket__meta').attr('id', metaId);
            if (ages) {
                $meta.append(document.createTextNode(ages + ' · '));
            }
            $meta.append($('<strong>').text(LT.formatVnd(price)));

            $tickets.append(
                $('<div>').addClass('lt-ticket').append(
                    $('<div>').addClass('lt-ticket__info').append(
                        $('<label>').addClass('lt-ticket__label').attr('for', inputId).text(label),
                        $meta
                    ),
                    $('<div>').addClass('lt-stepper').append($dec, $input, $inc)
                )
            );

            var row = { label: label, price: price, qty: qty, $input: $input, $dec: $dec, $inc: $inc };
            $dec.on('click', function () {
                setQty(row, row.qty - 1, true);
            });
            $inc.on('click', function () {
                setQty(row, row.qty + 1, true);
            });
            $input.on('input', function () {
                setQty(row, $input.val(), false);
            });
            $input.on('change blur', function () {
                setQty(row, $input.val(), true);
            });
            return row;
        }

        /**
         * Dựng lại hàng vé cho lịch đã chọn. Lần đầu: vé đầu tiên 1, các vé khác 0;
         * khi đổi lịch: giữ số vé theo loại nếu còn đủ chỗ.
         */
        function buildRows(schedule) {
            var previous = Object.create(null);
            var keepPrevious = rows.length > 0;
            $.each(rows, function (index, row) {
                previous[row.label] = row.qty;
            });

            rows = [];
            $tickets.empty();

            var tickets = schedule && $.isArray(schedule.tickets) ? schedule.tickets : [];
            if (!tickets.length) {
                $tickets.append($('<p>').addClass('lt-field__hint').text('Lịch này chưa có giá vé.'));
                return;
            }

            var max = maxGuests(schedule);
            var total = 0;
            $.each(tickets, function (index, ticket) {
                var label = String((ticket && ticket.label) || 'Khách');
                var wanted = keepPrevious ? toInt(previous[label]) : (index === 0 ? 1 : 0);
                var qty = Math.max(0, Math.min(wanted, max - total));
                total += qty;
                rows.push(buildRow(ticket || {}, label, index, qty));
            });

            if (total === 0) {
                rows[0].qty = 1;
                rows[0].$input.val(1);
            }
        }

        function selectSchedule() {
            var schedule = currentSchedule();
            $time.val(schedule && schedule.timeText ? String(schedule.timeText) : '—');
            buildRows(schedule);
            render();
        }

        $schedule.on('change', selectSchedule);
        selectSchedule();
    }

    /* ---------- Tab neo + cuộn mượt ---------- */

    function initAnchorTabs(LT) {
        var $nav = $('.js-detail-tabs');
        var $links = $nav.find('a[href^="#"]');
        var sections = [];
        var lockUntil = 0;
        var ticking = false;

        $links.each(function () {
            var section = document.getElementById(this.getAttribute('href').slice(1));
            if (section) {
                sections.push(section);
            }
        });

        function stickyOffset() {
            var offset = 0;
            var header = document.querySelector('.lt-header');
            if (header && window.getComputedStyle(header).position === 'sticky') {
                offset += header.offsetHeight;
            }
            if ($nav.length) {
                offset += $nav.outerHeight();
            }
            return offset;
        }

        function setActive(id) {
            $links.each(function () {
                var isActive = this.getAttribute('href') === '#' + id;
                $(this).toggleClass('is-active', isActive);
                if (isActive) {
                    $(this).attr('aria-current', 'true');
                    // Giữ tab đang chọn trong vùng nhìn thấy khi thanh tab cuộn ngang (mobile).
                    var list = this.parentNode && this.parentNode.parentNode;
                    if (list && list.scrollWidth > list.clientWidth) {
                        var left = this.offsetLeft - 16;
                        var right = this.offsetLeft + this.offsetWidth + 16;
                        if (left < list.scrollLeft) {
                            list.scrollLeft = left;
                        } else if (right > list.scrollLeft + list.clientWidth) {
                            list.scrollLeft = right - list.clientWidth;
                        }
                    }
                } else {
                    $(this).removeAttr('aria-current');
                }
            });
        }

        function scrollToElement(element) {
            var top = element.getBoundingClientRect().top + window.pageYOffset - stickyOffset() - 8;
            lockUntil = Date.now() + 900;
            window.scrollTo({ top: Math.max(0, top), behavior: LT.prefersReducedMotion() ? 'auto' : 'smooth' });
        }

        function spy() {
            ticking = false;
            if (!sections.length || Date.now() < lockUntil) {
                return;
            }
            var line = stickyOffset() + 24;
            var current = sections[0].id;
            for (var i = 0; i < sections.length; i++) {
                if (sections[i].getBoundingClientRect().top - line <= 0) {
                    current = sections[i].id;
                }
            }
            // Đã cuộn tới cuối trang: mục cuối cùng luôn được đánh dấu.
            var scrollHeight = document.documentElement.scrollHeight;
            if (window.pageYOffset > 0 && window.innerHeight + window.pageYOffset >= scrollHeight - 4) {
                current = sections[sections.length - 1].id;
            }
            setActive(current);
        }

        $links.on('click', function (event) {
            var id = this.getAttribute('href').slice(1);
            var target = document.getElementById(id);
            if (!target) {
                return;
            }
            event.preventDefault();
            setActive(id);
            scrollToElement(target);
            if (window.history && typeof window.history.replaceState === 'function') {
                window.history.replaceState(window.history.state, '', '#' + id);
            }
            target.focus({ preventScroll: true });
        });

        // Link cuộn khác trong trang (vd. "Chọn lịch" trên mobile).
        $('.js-scroll-link').on('click', function (event) {
            var target = document.getElementById((this.getAttribute('href') || '').slice(1));
            if (!target) {
                return;
            }
            event.preventDefault();
            scrollToElement(target);
            var focusTarget = document.getElementById('booking-schedule');
            if (focusTarget && !focusTarget.disabled) {
                window.setTimeout(function () {
                    focusTarget.focus({ preventScroll: true });
                }, LT.prefersReducedMotion() ? 0 : 500);
            }
        });

        $(window).on('scroll resize', function () {
            if (!ticking) {
                ticking = true;
                window.requestAnimationFrame(spy);
            }
        });

        // Mở trang với #muc (vd. /tours/<mã tour>#danh-gia): đánh dấu đúng tab.
        if (window.location.hash && document.getElementById(window.location.hash.slice(1))) {
            setActive(window.location.hash.slice(1));
        }
        spy();
    }
})(window, document, jQuery);
