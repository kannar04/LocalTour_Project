/*
 * LocalTour – tour-detail.js (Nguyễn Tuấn Khôi)
 * Trang chi tiết tour: lịch khởi hành quyết định "Giờ bắt đầu" và số khách tối đa
 * (min(nhóm tối đa, chỗ còn lại)), tính tạm tính trực tiếp; tab neo cuộn mượt + đánh dấu mục đang xem.
 * Đặt tour chưa có ở Sprint 3 nên form không bao giờ gửi đi.
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

    function initBookingCard(LT) {
        var $card = $('#booking-card');
        if (!$card.length) {
            return;
        }

        var price = parseInt($card.attr('data-price'), 10) || 0;
        var maxGroup = Math.max(1, parseInt($card.attr('data-max-group'), 10) || 1);
        var $form = $('#booking-form');
        var $schedule = $('#booking-schedule');
        var $guests = $('#booking-guests');
        var $dec = $('#booking-guests-dec');
        var $inc = $('#booking-guests-inc');
        var $startTime = $('#booking-start-time');
        var $hint = $('#booking-guests-hint');
        var $formula = $('#booking-total .js-total-formula');
        var $amount = $('#booking-total .js-total-amount');

        $form.on('submit', function (event) {
            event.preventDefault(); // Chưa có đặt tour ở Sprint 3.
        });

        var hasSchedule = $schedule.length && !$schedule.prop('disabled') && $schedule.find('option[data-seats-left]').length > 0;
        if (!hasSchedule) {
            $guests.prop('disabled', true);
            $dec.prop('disabled', true);
            $inc.prop('disabled', true);
            $startTime.prop('disabled', true).val('—');
            return;
        }

        function selectedOption() {
            return $schedule.find('option:selected');
        }

        function seatsLeft() {
            return parseInt(selectedOption().attr('data-seats-left'), 10) || 0;
        }

        function maxGuests() {
            var seats = seatsLeft();
            return seats > 0 ? Math.max(1, Math.min(maxGroup, seats)) : maxGroup;
        }

        function clamp(value) {
            var max = maxGuests();
            var number = parseInt(value, 10);
            if (isNaN(number) || number < 1) {
                return 1;
            }
            return number > max ? max : number;
        }

        function renderHint(max) {
            var seats = seatsLeft();
            var text = 'Tối đa ' + max + ' khách';
            if (seats > 0 && seats < maxGroup) {
                text += ' · lịch này còn ' + seats + ' chỗ';
            } else {
                text += ' mỗi nhóm';
            }
            $hint.text(text);
        }

        function renderTotal(guests) {
            $formula.text(guests + ' khách × ' + LT.formatVnd(price));
            if (!$amount.length) {
                $amount = $('<strong>').addClass('js-total-amount');
                $formula.after(document.createTextNode(' = '), $amount);
            }
            $amount.text(LT.formatVnd(guests * price));
        }

        /** Cập nhật mọi thứ phụ thuộc lịch và số khách; commit = ghi lại giá trị đã kẹp vào ô nhập. */
        function update(commit) {
            var max = maxGuests();
            var guests = clamp($guests.val());

            $guests.attr('max', max);
            if (commit || String(guests) !== String($guests.val()).trim()) {
                // Khi đang gõ dở (ô trống) thì chưa ghi đè, chỉ tính với giá trị hợp lệ gần nhất.
                if (commit || $guests.val() !== '') {
                    $guests.val(guests);
                }
            }

            $dec.prop('disabled', guests <= 1);
            $inc.prop('disabled', guests >= max);
            $startTime.val(selectedOption().attr('data-start-time') || '—');
            renderHint(max);
            renderTotal(guests);
        }

        $schedule.on('change', function () {
            update(true);
        });

        $guests.on('input', function () {
            update(false);
        });

        $guests.on('change blur', function () {
            update(true);
        });

        $dec.on('click', function () {
            $guests.val(clamp($guests.val()) - 1);
            update(true);
        });

        $inc.on('click', function () {
            $guests.val(clamp($guests.val()) + 1);
            update(true);
        });

        update(true);
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

        // Mở trang với #muc (vd. /tours/1#danh-gia): đánh dấu đúng tab.
        if (window.location.hash && document.getElementById(window.location.hash.slice(1))) {
            setActive(window.location.hash.slice(1));
        }
        spy();
    }
})(window, document, jQuery);
