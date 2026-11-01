/*
 * LocalTour – booking.js (Nguyễn Tuấn Khôi)
 * Trang "Hoàn tất thông tin đặt tour" (M4 mục 4, 7):
 *   - chọn lịch và số khách theo loại vé (giống thẻ giá ở trang chi tiết), tổng từ 1 đến min(nhóm tối đa, chỗ còn lại);
 *   - mỗi khách một ô họ tên, họ tên đã gõ được giữ lại khi đổi số khách hoặc đổi lịch;
 *   - Sprint 4 (4.3.2.3): phụ thu / hoạt động tùy chọn cộng vào tổng tiền (theo người thì nhân số khách);
 *   - "Xem lại & xác nhận": kiểm tra ở trình duyệt rồi hỏi chỗ trống (GET /api/schedules/{id}/availability);
 *   - "Gửi yêu cầu đặt tour": POST /api/bookings, thành công thì chuyển tới trang đơn.
 * Lỗi từ server (401, 403, 409, 422) hiện ngay trên form và giữ nguyên thông tin đã nhập.
 * Dữ liệu đọc từ <script type="application/json" id="book-data"> và chỉ đưa vào DOM bằng .text() / .attr().
 */
(function (window, document, $) {
    'use strict';

    var NAME_MAX = 100;
    var EMAIL_MAX = 150;
    var REQUEST_MAX = 500;
    var PHONE_PATTERN = /^(?=.{8,20}$)\+?[0-9 ]+$/;
    var EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    $(function () {
        var LT = window.LocalTour;
        var $form = $('#book-form');
        if (!LT || !$form.length) {
            return;
        }
        initBooking(LT, $form);
    });

    function toInt(value) {
        var number = parseInt(value, 10);
        return isNaN(number) ? 0 : number;
    }

    /** { maxGroup, scheduleId, selected: { <mã vé>: số khách }, schedules: [{ id, dateText, timeText, remaining, tickets }] } */
    function readData() {
        var node = document.getElementById('book-data');
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

    function initBooking(LT, $form) {
        var data = readData();
        if (!data) {
            return;
        }

        var maxGroup = Math.max(1, toInt(data.maxGroup));
        var selected = data.selected && typeof data.selected === 'object' ? data.selected : {};
        var schedules = {};
        $.each(data.schedules, function (index, schedule) {
            if (schedule && schedule.id) {
                schedules[String(schedule.id)] = schedule;
            }
        });

        var $schedule = $('#book-schedule');
        var $time = $('#book-time');
        var $tickets = $('#book-tickets');
        var $hint = $('#book-guests-hint');
        var $passengers = $('#book-passengers');
        var $request = $('#book-special-request');
        var $requestCount = $('#book-special-request-count');
        var $expected = $('#book-expected-total');
        var $extras = $form.find('.js-extra');
        var $alert = $('#book-alert');
        var $stepEdit = $('#book-step-edit');
        var $stepReview = $('#book-step-review');
        var $reviewBtn = $('#book-review-btn');
        var $submitBtn = $('#book-submit-btn');
        var reviewLabel = $reviewBtn.text().trim();
        var submitLabel = $submitBtn.find('.js-submit-label').text();

        var rows = []; // { ticket, label, price, qty, $input, $dec, $inc } của lịch đang chọn
        var names = Object.create(null); // nhãn loại vé -> [họ tên đã nhập], giữ lại khi đổi số khách / đổi lịch
        var busy = false;

        /* ---------- Lịch và số khách ---------- */

        function currentSchedule() {
            return schedules[String($schedule.val())] || null;
        }

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

        function clampRow(row, value) {
            var limit = Math.max(0, maxGuests(currentSchedule()) - totalGuests(row));
            return Math.min(Math.max(toInt(value), 0), limit);
        }

        /** Phụ thu / tùy chọn đang chọn; khoản tính theo người nhân với số khách (giống LTP_sp_booking_create). */
        function selectedExtras() {
            var guests = totalGuests(null);
            return $extras.filter(':checked:not(:disabled)').map(function () {
                var $box = $(this);
                var quantity = $box.attr('data-per-person') === '1' ? guests : 1;
                return { name: String($box.attr('data-name')), quantity: quantity, amount: quantity * toInt($box.attr('data-price')) };
            }).get();
        }

        function totalAmount() {
            var amount = 0;
            $.each(rows, function (index, row) {
                amount += row.qty * row.price;
            });
            $.each(selectedExtras(), function (index, extra) {
                amount += extra.amount;
            });
            return amount;
        }

        /** Nút +/−, gợi ý số khách, thẻ "Tour bạn đã chọn" và tổng tiền gửi kèm form. */
        function render() {
            var schedule = currentSchedule();
            var max = maxGuests(schedule);
            var total = totalGuests(null);
            var remaining = toInt(schedule && schedule.remaining);
            var $lines = $('#book-sum-lines').empty();

            $.each(rows, function (index, row) {
                row.$dec.prop('disabled', row.qty <= 0 || total <= 1);
                row.$inc.prop('disabled', total >= max);
                row.$input.attr('max', row.qty + Math.max(0, max - total));
                if (row.qty > 0) {
                    $lines.append($('<li>').append(
                        $('<span>').text(row.qty + ' × ' + row.label + ' '),
                        $('<span>').text(LT.formatVnd(row.qty * row.price))
                    ));
                }
            });
            $.each(selectedExtras(), function (index, extra) {
                $lines.append($('<li>').append(
                    $('<span>').text((extra.quantity > 1 ? extra.quantity + ' × ' : '') + extra.name + ' '),
                    $('<span>').text(LT.formatVnd(extra.amount))
                ));
            });

            $hint.text('Tối đa ' + max + ' khách' + (remaining > 0 && remaining < maxGroup ? ' · lịch này còn ' + remaining + ' chỗ' : ' mỗi nhóm'));
            $('.js-sum-date').text(schedule ? String(schedule.dateText || '—') : '—');
            $('.js-sum-time').text(schedule ? String(schedule.timeText || '—') : '—');
            $('.js-sum-people').text(total > 0 ? total + ' khách' : '—');
            $('#book-sum-total').text(rows.length ? LT.formatVnd(totalAmount()) : '—');
            $expected.val(totalAmount());
        }

        /** Đổi số vé của một loại; commit = ghi giá trị đã kẹp vào ô nhập và giữ tổng ít nhất 1 khách. */
        function setQty(row, value, commit) {
            var typed = String(row.$input.val()).trim();
            var before = row.qty;
            row.qty = clampRow(row, value);
            if (commit && totalGuests(null) === 0) {
                row.qty = 1;
            }
            if (commit || (typed !== '' && String(row.qty) !== typed)) {
                row.$input.val(row.qty);
            }
            render();
            if (row.qty !== before) {
                renderPassengers();
                clearError('passengers');
            }
        }

        function buildRow(ticket, index, qty) {
            var label = String(ticket.label || 'Khách');
            var inputId = 'book-ticket-' + index;
            var metaId = inputId + '-meta';
            var price = Math.max(0, toInt(ticket.price));

            var $dec = $('<button>').addClass('lt-stepper__btn')
                .attr({ type: 'button', 'aria-controls': inputId, 'aria-label': 'Bớt 1 vé ' + label })
                .append(LT.icon('minus'));
            var $inc = $('<button>').addClass('lt-stepper__btn')
                .attr({ type: 'button', 'aria-controls': inputId, 'aria-label': 'Thêm 1 vé ' + label })
                .append(LT.icon('plus'));
            // Không có name: số vé được gửi qua danh sách khách (mỗi khách một loại vé).
            var $input = $('<input>').addClass('lt-input lt-stepper__input')
                .attr({ type: 'number', id: inputId, min: 0, step: 1, inputmode: 'numeric', 'aria-describedby': metaId })
                .val(qty);

            var $meta = $('<span>').addClass('lt-ticket__meta').attr('id', metaId);
            if (ticket.ages) {
                $meta.append(document.createTextNode(String(ticket.ages) + ' · '));
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

            var row = { ticket: ticket, label: label, price: price, qty: qty, $input: $input, $dec: $dec, $inc: $inc };
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
         * Dựng lại hàng vé của lịch đang chọn. initial: lấy số khách đã chọn ở trang chi tiết (theo mã vé);
         * sau đó: giữ số khách theo loại vé (nhãn) nếu lịch mới còn đủ chỗ.
         */
        function buildRows(initial) {
            var schedule = currentSchedule();
            var previous = Object.create(null);
            $.each(rows, function (index, row) {
                previous[row.label] = row.qty;
            });

            rows = [];
            $tickets.empty();

            var tickets = schedule && $.isArray(schedule.tickets) ? schedule.tickets : [];
            if (!tickets.length) {
                $tickets.append($('<p>').addClass('lt-field__hint').text('Lịch này chưa có giá vé. Vui lòng chọn ngày khác.'));
                return;
            }

            var max = maxGuests(schedule);
            var total = 0;
            var hasPrevious = !initial && !$.isEmptyObject(previous);
            $.each(tickets, function (index, ticket) {
                ticket = ticket || {};
                var label = String(ticket.label || 'Khách');
                var wanted = initial
                    ? toInt(selected[String(ticket.id)])
                    : (hasPrevious ? toInt(previous[label]) : (index === 0 ? 1 : 0));
                var qty = Math.max(0, Math.min(wanted, max - total));
                total += qty;
                rows.push(buildRow(ticket, index, qty));
            });

            if (total === 0) {
                rows[0].qty = 1;
                rows[0].$input.val(1);
            }
        }

        /* ---------- Danh sách khách ---------- */

        function renderPassengers() {
            $passengers.empty();
            var index = 0;
            $.each(rows, function (rowIndex, row) {
                var list = names[row.label] || (names[row.label] = []);
                for (var k = 0; k < row.qty; k++) {
                    $passengers.append(buildPassenger(index, row, list, k));
                    index++;
                }
            });
        }

        function buildPassenger(index, row, list, position) {
            var number = index + 1;
            var inputId = 'book-passenger-' + index;
            var $input = $('<input>').addClass('lt-input')
                .attr({
                    type: 'text',
                    id: inputId,
                    name: 'passengers[' + index + '][full_name]',
                    maxlength: NAME_MAX,
                    autocomplete: 'off',
                    placeholder: 'Họ tên như trên giấy tờ',
                    'aria-describedby': inputId + '-error'
                })
                .val(list[position] || '');
            $input.on('input', function () {
                list[position] = $input.val();
            });

            return $('<li>').addClass('lt-passenger').append(
                $('<div>').addClass('lt-passenger__head').append(
                    $('<label>').addClass('lt-passenger__label').attr('for', inputId).append(
                        document.createTextNode('Khách ' + number + ' '),
                        $('<span>').addClass('lt-passenger__type').text(row.label)
                    )
                ),
                $input,
                $('<input>').attr({ type: 'hidden', name: 'passengers[' + index + '][ticket_type_id]' }).val(String(row.ticket.id)),
                $('<p>').addClass('lt-field__error').attr({ id: inputId + '-error', 'data-error-for': 'passengers.' + index }).prop('hidden', true)
            );
        }

        function selectSchedule(initial) {
            var schedule = currentSchedule();
            $time.val(schedule && schedule.timeText ? String(schedule.timeText) : '—');
            buildRows(initial);
            render();
            renderPassengers();
        }

        /** Giá / loại vé mới từ server: cập nhật lịch đang chọn, giữ số khách và họ tên theo loại vé. */
        function replaceTickets(tickets) {
            var schedule = currentSchedule();
            if (schedule && $.isArray(tickets)) {
                schedule.tickets = $.map(tickets, function (ticket) {
                    return ticket && ticket.id ? ticket : null;
                });
                selectSchedule(false);
            }
        }

        /* ---------- Lỗi ---------- */

        function showAlert(message, $extra) {
            $alert.find('.js-alert-text').text(message).append($extra || null);
            $alert.prop('hidden', false);
        }

        function hideAlert() {
            $alert.prop('hidden', true).find('.js-alert-text').empty();
        }

        function errorNode(key) {
            return $form.find('[data-error-for]').filter(function () {
                return $(this).attr('data-error-for') === key;
            });
        }

        /** Ô nhập ứng với một dòng lỗi: lỗi "<id>-error" thuộc ô "<id>". */
        function fieldFor($error) {
            var id = String($error.attr('id') || '');
            return id ? $('#' + id.replace(/-error$/, '')) : $();
        }

        function clearError(key) {
            var $error = errorNode(key);
            $error.prop('hidden', true).text('');
            fieldFor($error).removeClass('is-invalid').removeAttr('aria-invalid');
        }

        function clearErrors() {
            hideAlert();
            $form.find('[data-error-for]').prop('hidden', true).text('');
            $form.find('.is-invalid').removeClass('is-invalid').removeAttr('aria-invalid');
        }

        /** Hiện lỗi theo từng ô ({ khóa: thông báo }); 'form' hoặc khóa không có ô thì hiện ở khung lỗi chung. */
        function showErrors(errors, message) {
            clearErrors();
            var $first = null;
            var general = '';
            $.each(errors || {}, function (key, text) {
                var $error = errorNode(key);
                if (key === 'form' || !$error.length) {
                    general = general || String(text);
                    return;
                }
                $error.text(String(text)).prop('hidden', false);
                var $field = fieldFor($error);
                $field.addClass('is-invalid').attr('aria-invalid', 'true');
                if (!$first) {
                    $first = $field.length ? $field : $tickets.find('input').first();
                }
            });

            showAlert(general || message || 'Vui lòng kiểm tra lại các ô được đánh dấu.');
            if ($first && $first.length) {
                $first.trigger('focus');
            } else {
                $alert.trigger('focus');
            }
        }

        /** Kiểm tra ở trình duyệt, cùng quy tắc với BookingController. */
        function validate() {
            var errors = {};
            var name = String($('#book-contact-name').val()).trim();
            var email = String($('#book-contact-email').val()).trim();
            var phone = String($('#book-contact-phone').val()).trim();

            if (name === '') {
                errors.contact_name = 'Vui lòng nhập họ tên người liên hệ.';
            } else if (name.length > NAME_MAX) {
                errors.contact_name = 'Họ tên tối đa ' + NAME_MAX + ' ký tự.';
            }
            if (email === '') {
                errors.contact_email = 'Vui lòng nhập email.';
            } else if (email.length > EMAIL_MAX || !EMAIL_PATTERN.test(email)) {
                errors.contact_email = 'Email không hợp lệ.';
            }
            if (phone === '') {
                errors.contact_phone = 'Vui lòng nhập số điện thoại.';
            } else if (!PHONE_PATTERN.test(phone)) {
                errors.contact_phone = 'Số điện thoại không hợp lệ.';
            }
            if (!currentSchedule() || !rows.length) {
                errors.schedule_id = 'Vui lòng chọn ngày tham gia còn giá vé.';
            } else if (totalGuests(null) < 1) {
                errors.passengers = 'Vui lòng chọn ít nhất 1 khách.';
            }
            $passengers.find('input[type="text"]').each(function (index) {
                var value = String($(this).val()).trim();
                if (value === '') {
                    errors['passengers.' + index] = 'Vui lòng nhập họ tên khách ' + (index + 1) + '.';
                } else if (value.length > NAME_MAX) {
                    errors['passengers.' + index] = 'Họ tên khách tối đa ' + NAME_MAX + ' ký tự.';
                }
            });
            if (String($request.val()).length > REQUEST_MAX) {
                errors.special_request = 'Yêu cầu đặc biệt tối đa ' + REQUEST_MAX + ' ký tự.';
            }
            if (!$('#book-terms').is(':checked')) {
                errors.terms = 'Vui lòng đồng ý điều kiện đặt tour và chính sách hủy.';
            }
            return errors;
        }

        /* ---------- Xem lại & gửi ---------- */

        function setBusy(isBusy, $button, text) {
            busy = isBusy;
            $button.prop('disabled', isBusy).attr('aria-busy', isBusy ? 'true' : null);
            if ($button.is($reviewBtn)) {
                $button.text(text);
            } else {
                $button.find('.js-submit-label').text(text);
            }
        }

        function scrollToTop($element) {
            var top = $element.offset().top - 96;
            window.scrollTo({ top: Math.max(0, top), behavior: LT.prefersReducedMotion() ? 'auto' : 'smooth' });
        }

        function showReview() {
            var schedule = currentSchedule();
            var $list = $stepReview.find('.js-review-passengers').empty();
            $passengers.find('.lt-passenger').each(function () {
                var $item = $(this);
                var fullName = String($item.find('input[type="text"]').val()).trim();
                $list.append($('<li>').text(fullName + ' (' + $item.find('.lt-passenger__type').text() + ')'));
            });
            var request = String($request.val()).trim();

            $stepReview.find('.js-review-date').text(schedule ? String(schedule.dateText) : '—');
            $stepReview.find('.js-review-time').text(schedule ? String(schedule.timeText) : '—');
            $stepReview.find('.js-review-people').text(totalGuests(null) + ' khách');
            $stepReview.find('.js-review-contact').text(
                [$('#book-contact-name').val(), $('#book-contact-email').val(), $('#book-contact-phone').val()]
                    .map(function (value) { return String(value).trim(); }).join(' · ')
            );
            $stepReview.find('.js-review-request').text(request !== '' ? request : 'Không có');
            var extras = selectedExtras();
            $stepReview.find('.js-review-extras').text(extras.length ? $.map(extras, function (extra) {
                return (extra.quantity > 1 ? extra.quantity + ' × ' : '') + extra.name + ' (' + LT.formatVnd(extra.amount) + ')';
            }).join(' · ') : 'Không chọn');
            $stepReview.find('.js-review-total').text(LT.formatVnd(totalAmount()));

            hideAlert();
            $stepEdit.prop('hidden', true);
            $stepReview.prop('hidden', false);
            scrollToTop($stepReview);
            $stepReview[0].focus({ preventScroll: true });
        }

        function backToEdit() {
            $stepReview.prop('hidden', true);
            $stepEdit.prop('hidden', false);
        }

        /** Hỏi server lịch còn nhận khách, còn đủ chỗ và giá còn đúng không, rồi mới sang bước xem lại. */
        function checkAvailability() {
            var schedule = currentSchedule();
            var people = totalGuests(null);
            setBusy(true, $reviewBtn, 'Đang kiểm tra chỗ…');

            $.getJSON(LT.url('/api/schedules/' + encodeURIComponent(String(schedule.id)) + '/availability'), { people: people })
                .done(function (response) {
                    var info = response && response.data;
                    if (!info) {
                        showAlert('Không kiểm tra được chỗ trống. Vui lòng thử lại.');
                        return;
                    }
                    schedule.remaining = toInt(info.remaining);
                    if (!info.bookable || !info.enough) {
                        selectSchedule(false);
                        showErrors(info.bookable ? { passengers: response.message } : { schedule_id: response.message }, response.message);
                        return;
                    }
                    if (pricesChanged(info.tickets)) {
                        replaceTickets(info.tickets);
                        showAlert('Giá vé vừa thay đổi, tổng tiền mới là ' + LT.formatVnd(totalAmount()) + '. Vui lòng xem lại rồi bấm "Xem lại & xác nhận".');
                        $alert.trigger('focus');
                        return;
                    }
                    showReview();
                })
                .fail(function (xhr) {
                    var message = xhr.responseJSON && xhr.responseJSON.message;
                    showErrors(xhr.status === 404 ? { schedule_id: 'Lịch này không còn nhận đặt. Vui lòng chọn ngày khác.' } : {},
                        message || 'Không kiểm tra được chỗ trống. Vui lòng kiểm tra kết nối và thử lại.');
                })
                .always(function () {
                    setBusy(false, $reviewBtn, reviewLabel);
                });
        }

        /** Loại vé đang chọn còn bán với đúng giá đang hiện không. */
        function pricesChanged(tickets) {
            if (!$.isArray(tickets)) {
                return false;
            }
            var current = Object.create(null);
            $.each(tickets, function (index, ticket) {
                if (ticket && ticket.id) {
                    current[String(ticket.id)] = toInt(ticket.price);
                }
            });
            var changed = false;
            $.each(rows, function (index, row) {
                var id = String(row.ticket.id);
                if (!(id in current) || (row.qty > 0 && current[id] !== row.price)) {
                    changed = true;
                }
            });
            return changed;
        }

        function submitBooking() {
            setBusy(true, $submitBtn, 'Đang gửi…');

            $.ajax({ url: LT.url('/api/bookings'), method: 'POST', data: $form.serialize(), dataType: 'json' })
                .done(function (response) {
                    var target = response && response.success && response.data && response.data.url;
                    if (target) {
                        window.location.assign(String(target));
                        return; // Giữ nút ở trạng thái đang gửi tới khi chuyển trang.
                    }
                    setBusy(false, $submitBtn, submitLabel);
                    showAlert('Không gửi được yêu cầu. Vui lòng thử lại.');
                })
                .fail(function (xhr) {
                    setBusy(false, $submitBtn, submitLabel);
                    handleFailure(xhr);
                });
        }

        function handleFailure(xhr) {
            var response = xhr.responseJSON || {};
            var info = response.data || {};
            var message = response.message || 'Không gửi được yêu cầu. Vui lòng kiểm tra kết nối và bấm gửi lại.';

            // Mất kết nối hoặc lỗi máy chủ: ở lại bước xem lại để gửi lại (mã yêu cầu chống tạo trùng đơn).
            if (xhr.status === 0 || xhr.status >= 500) {
                showAlert(message);
                $alert.trigger('focus');
                return;
            }

            backToEdit();
            if (xhr.status === 401) {
                showAlert(message + ' ', $('<a>').attr('href', String($form.attr('data-login-url') || LT.url('/login'))).text('Đăng nhập lại'));
                $alert.trigger('focus');
            } else if (xhr.status === 422) {
                showErrors(info.errors, message);
            } else if (xhr.status === 409) {
                handleConflict(info, message);
            } else {
                showAlert(message);
                $alert.trigger('focus');
            }
        }

        function reloadLink() {
            return $('<a>').attr('href', window.location.href).text('Tải lại trang');
        }

        /** 409: lịch, số chỗ hoặc giá đã đổi từ lúc mở trang. Cập nhật lại form theo dữ liệu mới. */
        function handleConflict(info, message) {
            var schedule = currentSchedule();
            if (info.reason === 'extras_changed') {
                showAlert(message + ' ', reloadLink());
                $alert.trigger('focus');
                return;
            }
            if ((info.reason === 'price_changed' || info.reason === 'tickets_changed') && $.isArray(info.tickets)) {
                replaceTickets(info.tickets);
                // Giá vé mới đã cập nhật mà tổng vẫn lệch: giá phụ thu / tùy chọn đổi, cần tải lại trang.
                if (info.reason === 'price_changed' && info.total_vnd !== undefined && totalAmount() !== toInt(info.total_vnd)) {
                    showAlert(message + ' ', reloadLink());
                    $alert.trigger('focus');
                    return;
                }
                showErrors(info.reason === 'tickets_changed' ? { passengers: message } : {}, message);
                return;
            }
            if (info.reason === 'no_seats' && schedule) {
                schedule.remaining = toInt(info.remaining);
                selectSchedule(false);
                showErrors({ passengers: message }, message);
                return;
            }
            if (info.reason === 'group_limit') {
                showErrors({ passengers: message }, message);
                return;
            }
            showErrors(info.reason === 'schedule_unavailable' ? { schedule_id: message } : {}, message);
        }

        /* ---------- Sự kiện ---------- */

        $schedule.on('change', function () {
            clearError('schedule_id');
            selectSchedule(false);
        });

        $request.on('input', function () {
            $requestCount.text(String($request.val()).length + '/' + REQUEST_MAX + ' ký tự');
        });

        $extras.on('change', function () {
            render();
        });

        // Sửa một ô đang báo lỗi thì bỏ đánh dấu lỗi của ô đó.
        $form.on('input change', '.is-invalid', function () {
            $(this).removeClass('is-invalid').removeAttr('aria-invalid');
            $('#' + this.id + '-error').prop('hidden', true).text('');
        });

        $form.on('submit', function (event) {
            event.preventDefault();
            if (busy || !$stepReview.prop('hidden')) {
                return;
            }
            var errors = validate();
            if (!$.isEmptyObject(errors)) {
                showErrors(errors);
                return;
            }
            checkAvailability();
        });

        $('#book-edit-btn').on('click', function () {
            backToEdit();
            $reviewBtn.trigger('focus');
        });

        $submitBtn.on('click', function () {
            if (!busy) {
                submitBooking();
            }
        });

        // Quay lại trang bằng nút Back (bfcache): mở lại được các nút.
        $(window).on('pageshow', function (event) {
            if (event.originalEvent && event.originalEvent.persisted) {
                setBusy(false, $submitBtn, submitLabel);
                setBusy(false, $reviewBtn, reviewLabel);
            }
        });

        // Lịch đã chọn ở trang chi tiết được đánh dấu selected sẵn trong HTML.
        selectSchedule(true);
    }
})(window, document, jQuery);
