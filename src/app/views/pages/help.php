<?php declare(strict_types=1); ?>
<?php
/*
 * Trợ giúp – câu hỏi thường gặp (CR2, Nguyễn Tuấn Khôi).
 * Biến: $rules (PageController::rules(): hold_minutes, booking_cutoff_minutes, vietqr_cutoff_hours,
 *       commission_percent – đã định dạng), $title.
 * Mỗi nhóm là một <section> có id (mục lục nhảy tới); mỗi câu hỏi là một <details> (mở/đóng không cần JS).
 * Nội dung lấy theo Hướng dẫn sử dụng (docs/sprint6/03) và các chức năng của CR2.
 */
$hold = $rules['hold_minutes'];
$cutoff = $rules['booking_cutoff_minutes'];
$vietqr = $rules['vietqr_cutoff_hours'];
$commission = $rules['commission_percent'];

$groups = [
    'tim-tour' => [
        'title' => 'Tìm và so sánh tour',
        'icon' => 'search',
        'items' => [
            [
                'q' => 'Tìm tour như thế nào?',
                'a' => [
                    'Gõ điểm đến, tên tour hoặc người dẫn vào ô tìm kiếm ở đầu trang rồi bấm “Tìm”.',
                    'Ở Bảng tin, chọn “Điểm đến:” và “Loại hình:”, hoặc bấm một điểm đến trong menu bên trái. Sắp xếp bằng tab “Nổi bật” / “Sắp khởi hành” và ô “Giá”.',
                ],
                'links' => [['Mở Bảng tin', '/tours']],
            ],
            [
                'q' => 'Lọc theo ngày đi, giá, thời lượng, ngôn ngữ hoặc đón tại khách sạn?',
                'a' => [
                    'Chọn “Ngày đi” để chỉ xem tour còn lịch nhận đặt vào ngày đó.',
                    'Bấm “Bộ lọc” để chọn khoảng giá, thời lượng, ngôn ngữ hướng dẫn và tour có đón tại khách sạn, rồi bấm “Áp dụng”. Bấm “Xóa bộ lọc” để xem lại tất cả tour.',
                    'Bộ lọc đang chọn được ghi lên địa chỉ trang, nên tải lại trang hoặc gửi đường dẫn cho người khác vẫn giữ nguyên kết quả.',
                ],
            ],
            [
                'q' => 'Giá trên thẻ tour là giá gì?',
                'a' => [
                    'Là giá thấp nhất cho một khách người lớn, tính bằng VND. Phụ thu và hoạt động tùy chọn tính riêng ở bước đặt tour.',
                    'Thông tin đơn vị tổ chức chưa cung cấp ghi “Chưa cập nhật”.',
                ],
            ],
            [
                'q' => 'So sánh nhiều tour?',
                'a' => [
                    'Bấm “Thêm vào so sánh” trên thẻ tour hoặc ở trang tour, chọn 2–3 tour rồi bấm “So sánh tour”. Không cần đăng nhập.',
                    'Tối đa 3 tour. Danh sách so sánh lưu trên trình duyệt bạn đang dùng và được xóa khi bạn đăng nhập, đăng xuất hoặc đổi tài khoản.',
                ],
                'links' => [['Mở trang so sánh', '/compare']],
            ],
            [
                'q' => 'Vì sao không thấy một tour?',
                'a' => [
                    'Khách chỉ thấy tour đã được quản trị viên duyệt, của đơn vị tổ chức đang hợp tác với LocalTour.',
                ],
            ],
        ],
    ],
    'dat-tour' => [
        'title' => 'Đặt tour và giữ chỗ',
        'icon' => 'calendar',
        'items' => [
            [
                'q' => 'Có cần tài khoản để đặt tour không?',
                'a' => [
                    'Có. Đặt tour cần tài khoản khách hàng: bấm “Đăng ký” ở góc phải (mật khẩu tối thiểu 8 ký tự). Xem, tìm, lọc và so sánh tour thì không cần đăng nhập.',
                    'Tài khoản quản trị và tài khoản đơn vị tổ chức không đặt tour được.',
                ],
            ],
            [
                'q' => 'Đặt xong thì chỗ được giữ bao lâu?',
                'a' => [
                    'LocalTour giữ chỗ ngay lúc bạn đặt, đơn ở trạng thái “Chờ thanh toán”. Bạn có ' . $hold . ' phút để thanh toán, không muộn hơn giờ khởi hành.',
                    'Quá hạn chưa thanh toán, đơn tự hủy và chỗ được trả lại cho lịch. Thanh toán lại không gia hạn thời gian giữ chỗ.',
                ],
            ],
            [
                'q' => 'Vì sao không thấy ngày muốn đi ở ô “Ngày tham gia”?',
                'a' => [
                    'Lịch đó đã hết chỗ, đã hủy, hoặc còn dưới ' . $cutoff . ' phút tới giờ khởi hành: LocalTour ngừng nhận đặt trước giờ khởi hành ' . $cutoff . ' phút.',
                ],
            ],
            [
                'q' => 'Theo dõi đơn và lấy voucher ở đâu?',
                'a' => [
                    'Bấm “Đơn của tôi” ở đầu trang. Mỗi đơn ghi trạng thái, hạn thanh toán, lịch sử đơn và chính sách hủy của đơn.',
                    'Voucher có sau khi thanh toán thành công. Đưa mã voucher cho hướng dẫn viên và có mặt ở điểm hẹn trước giờ khởi hành 15 phút.',
                ],
                'links' => [['Đơn của tôi', '/bookings']],
            ],
        ],
    ],
    'thanh-toan' => [
        'title' => 'Thanh toán',
        'icon' => 'shield',
        'items' => [
            [
                'q' => 'Thanh toán bằng cách nào?',
                'a' => [
                    'Bằng VNPay hoặc chuyển khoản VietQR, khi đơn đang “Chờ thanh toán” và còn hạn giữ chỗ. Giá tính bằng VND; đơn giữ giá lúc đặt.',
                    'Trang demo dùng môi trường thử nghiệm, không thu tiền thật.',
                ],
            ],
            [
                'q' => 'Khi nào dùng được chuyển khoản VietQR?',
                'a' => [
                    'Khi còn ít nhất ' . $vietqr . ' giờ tới giờ khởi hành, vì LocalTour đối chiếu chuyển khoản bằng tay. Sát giờ hơn thì thanh toán bằng VNPay.',
                ],
            ],
            [
                'q' => 'Đã chuyển khoản nhưng đơn chưa được xác nhận?',
                'a' => [
                    'Sau khi chuyển đúng số tiền và nội dung, bấm “Tôi đã chuyển khoản”. Khoản thanh toán chuyển sang “Chờ đối chiếu” và đơn không bị tự hủy trong lúc chờ.',
                    'LocalTour đối chiếu xong thì đơn chuyển “Đã xác nhận” và có voucher.',
                ],
            ],
        ],
    ],
    'doi-huy' => [
        'title' => 'Đổi lịch, hủy và hoàn tiền',
        'icon' => 'refresh',
        'items' => [
            [
                'q' => 'Đổi ngày hoặc hủy tour như thế nào?',
                'a' => [
                    'Ở trang đơn, bấm “Đổi ngày / hủy tour”, chọn việc muốn làm, nhập lý do (bắt buộc, tối đa 500 ký tự) rồi bấm “Gửi yêu cầu”. Kết quả và phản hồi của LocalTour hiện ở trang đơn.',
                    'Mỗi đơn chỉ có một yêu cầu đang chờ xử lý. Không gửi được khi tour đã khởi hành hoặc đơn đã đóng. Đổi ngày giữ nguyên số khách, gói và tổng tiền.',
                ],
            ],
            [
                'q' => 'Hủy tour thì được hoàn bao nhiêu?',
                'a' => [
                    'Theo chính sách hủy của đúng tour đó (mục “Chính sách” ở trang tour): mốc hủy miễn phí và tỷ lệ hoàn sau mốc. Đơn giữ phiên bản chính sách lúc đặt; trang “Đổi ngày / hủy tour” ghi số tiền dự kiến được hoàn.',
                ],
            ],
            [
                'q' => 'Tiền hoàn về khi nào?',
                'a' => [
                    'LocalTour chuyển khoản lại cho bạn thủ công, không hoàn tự động qua VNPay. Chuyển xong, quản trị viên ghi “Đã hoàn tiền” cho đơn.',
                ],
            ],
        ],
    ],
    'tai-khoan' => [
        'title' => 'Tài khoản và ảnh đại diện',
        'icon' => 'user',
        'items' => [
            [
                'q' => 'Sửa thông tin tài khoản ở đâu?',
                'a' => [
                    'Bấm tên hoặc ảnh đại diện ở góc phải, hoặc mục “Tài khoản” trong menu, để mở trang tài khoản. Ở đó bạn đổi được họ tên, số điện thoại, ảnh đại diện và mật khẩu.',
                    'Email dùng để đăng nhập nên không đổi được.',
                ],
                'links' => [['Mở trang tài khoản', '/tai-khoan']],
            ],
            [
                'q' => 'Ảnh đại diện cần như thế nào?',
                'a' => [
                    'Ảnh JPG, PNG hoặc WebP, tối đa 2 MB. Ảnh hiện ở góc phải và cạnh bình luận của bạn. Xóa ảnh thì LocalTour hiện chữ cái đầu của tên.',
                ],
            ],
            [
                'q' => 'Đổi mật khẩu?',
                'a' => [
                    'Ở trang tài khoản, nhập mật khẩu hiện tại và mật khẩu mới (tối thiểu 8 ký tự), rồi nhập lại mật khẩu mới.',
                ],
            ],
            [
                'q' => 'Dùng nhiều tài khoản cùng lúc?',
                'a' => [
                    'Mỗi trình duyệt chỉ đăng nhập một tài khoản. Đăng nhập tài khoản khác sẽ thay tài khoản đang đăng nhập. Muốn dùng song song thì mở thêm một cửa sổ ẩn danh hoặc một trình duyệt khác.',
                ],
            ],
        ],
    ],
    'tuong-tac' => [
        'title' => 'Thích, lưu, chia sẻ, bình luận và đánh giá',
        'icon' => 'heart',
        'items' => [
            [
                'q' => 'Thích và lưu tour?',
                'a' => [
                    'Bấm “Thích” trên thẻ tour hoặc ở trang tour; bấm lại để bỏ thích. Ai cũng thấy số lượt thích.',
                    'Bấm “Lưu tour” để đưa tour vào “Tour đã lưu” (trong menu). Bấm lại, hoặc “Bỏ lưu” ở trang Tour đã lưu, để bỏ. Lưu tour không giữ chỗ và không giữ giá.',
                    'Thích và lưu cần tài khoản khách hàng; chưa đăng nhập thì LocalTour mở trang đăng nhập.',
                ],
                'links' => [['Tour đã lưu', '/tour-da-luu']],
            ],
            [
                'q' => 'Chia sẻ tour?',
                'a' => [
                    'Bấm “Chia sẻ”: thiết bị mở bảng chia sẻ của nó; trình duyệt không có bảng chia sẻ thì LocalTour sao chép đường dẫn tour để bạn dán vào nơi muốn gửi. Không cần đăng nhập.',
                ],
            ],
            [
                'q' => 'Bình luận ở trang tour?',
                'a' => [
                    'Mục “Bình luận” ở cuối trang tour. Tài khoản khách hàng viết được bình luận từ 1 đến 1000 ký tự và tự xóa bình luận của mình.',
                    'Quản trị viên có thể ẩn bình luận vi phạm điều khoản sử dụng.',
                ],
            ],
            [
                'q' => 'Đánh giá sao cho tour đã đi?',
                'a' => [
                    'Khi đơn ở trạng thái “Đã hoàn thành”, mở đơn trong “Đơn của tôi” để chấm từ 1 đến 5 sao và viết nhận xét. Mỗi đơn một đánh giá.',
                    'Đánh giá hiện ở mục “Đánh giá” của trang tour sau khi quản trị viên duyệt.',
                ],
            ],
            [
                'q' => 'Bình luận khác đánh giá thế nào?',
                'a' => [
                    'Bình luận dùng để hỏi và góp ý, mọi tài khoản khách hàng đều viết được và hiện ngay. Đánh giá chỉ dành cho khách đã đi tour, có điểm sao, và chỉ hiện sau khi được duyệt.',
                ],
            ],
        ],
    ],
    'don-vi' => [
        'title' => 'Dành cho đơn vị tổ chức',
        'icon' => 'verified',
        'items' => [
            [
                'q' => 'Đơn vị tổ chức có tự đăng ký được không?',
                'a' => [
                    'Không. Quản trị viên LocalTour thêm đơn vị và cấp tài khoản. Đơn vị đăng nhập ở trang “Đăng nhập đơn vị tổ chức” bằng email liên hệ và mật khẩu được cấp, khi đơn vị đang hợp tác.',
                ],
                'links' => [['Đăng nhập đơn vị tổ chức', '/host/login']],
            ],
            [
                'q' => 'Đăng tour lên LocalTour?',
                'a' => [
                    'Bấm “Thêm tour” (tour ở trạng thái “Nháp”), nhập lịch khởi hành, giá vé, ảnh và chính sách hủy, rồi bấm “Gửi duyệt”. Tour chỉ hiện cho khách sau khi quản trị viên duyệt.',
                    'Tour đã duyệt được sửa qua một bản sửa, cũng cần duyệt. Lịch khởi hành và giá vé đơn vị sửa trực tiếp, không qua duyệt.',
                ],
            ],
            [
                'q' => 'Đơn vị nhận tiền như thế nào?',
                'a' => [
                    'Phí dịch vụ LocalTour hiện là ' . $commission . ' % tiền thực thu, lưu vào từng đơn lúc đặt. Sau khi lịch khởi hành kết thúc, hệ thống lập một khoản chi trả: thực nhận = tiền thực thu − phí dịch vụ.',
                    'LocalTour chuyển khoản vào tài khoản nhận tiền của đơn vị sau khi đã xác minh tài khoản đó.',
                ],
            ],
        ],
    ],
];
?>
<?php $sidebarMode = 'mobile'; require __DIR__ . '/../partials/sidebar.php'; ?>

<main id="main-content" class="lt-doc" tabindex="-1">
    <div class="container-xl lt-container lt-page">
        <nav aria-label="Đường dẫn">
            <ol class="breadcrumb lt-breadcrumb">
                <li class="breadcrumb-item"><a href="<?= e(url('/tours')) ?>">Bảng tin</a></li>
                <li class="breadcrumb-item active" aria-current="page">Trợ giúp</li>
            </ol>
        </nav>

        <header class="lt-doc-head">
            <h1 class="lt-doc-head__title">Trợ giúp</h1>
            <p class="lt-doc-head__lead">Câu hỏi thường gặp khi tìm, đặt và thanh toán tour trên LocalTour. Các mốc thời gian dưới đây là thông số đang áp dụng.</p>
        </header>

        <ul class="lt-doc-facts" aria-label="Thông số đang áp dụng">
            <li class="lt-doc-fact">
                <span class="lt-icon lt-icon--clock" aria-hidden="true"></span>
                <span class="lt-doc-fact__value"><?= e($hold) ?> phút</span>
                <span class="lt-doc-fact__label">giữ chỗ để thanh toán</span>
            </li>
            <li class="lt-doc-fact">
                <span class="lt-icon lt-icon--calendar" aria-hidden="true"></span>
                <span class="lt-doc-fact__value"><?= e($cutoff) ?> phút</span>
                <span class="lt-doc-fact__label">trước giờ khởi hành thì ngừng nhận đặt</span>
            </li>
            <li class="lt-doc-fact">
                <span class="lt-icon lt-icon--shield" aria-hidden="true"></span>
                <span class="lt-doc-fact__value"><?= e($vietqr) ?> giờ</span>
                <span class="lt-doc-fact__label">trước giờ khởi hành mới nhận chuyển khoản VietQR</span>
            </li>
        </ul>

        <div class="lt-doc-layout">
            <nav class="lt-doc-toc" aria-labelledby="doc-toc-title">
                <h2 class="lt-doc-toc__title" id="doc-toc-title">Nội dung</h2>
                <ul class="lt-doc-toc__list">
<?php foreach ($groups as $groupId => $group): ?>
                    <li><a class="lt-doc-toc__link" href="#<?= e($groupId) ?>"><?= e($group['title']) ?></a></li>
<?php endforeach; ?>
                </ul>
            </nav>

            <div class="lt-doc-body">
<?php foreach ($groups as $groupId => $group): ?>
                <section class="lt-doc-section" id="<?= e($groupId) ?>" tabindex="-1" aria-labelledby="<?= e($groupId) ?>-title">
                    <h2 class="lt-doc-section__title" id="<?= e($groupId) ?>-title">
                        <span class="lt-doc-section__icon" aria-hidden="true"><span class="lt-icon lt-icon--<?= e($group['icon']) ?>"></span></span>
                        <?= e($group['title']) ?>
                    </h2>
<?php foreach ($group['items'] as $item): ?>
                    <details class="lt-faq">
                        <summary class="lt-faq__q">
                            <span><?= e($item['q']) ?></span>
                            <span class="lt-icon lt-icon--chevron-down lt-faq__chevron" aria-hidden="true"></span>
                        </summary>
                        <div class="lt-faq__a">
<?php foreach ($item['a'] as $paragraph): ?>
                            <p><?= e($paragraph) ?></p>
<?php endforeach; ?>
<?php if (!empty($item['links'])): ?>
                            <p class="lt-faq__links">
<?php foreach ($item['links'] as [$linkLabel, $linkPath]): ?>
                                <a class="lt-faq__link" href="<?= e(url($linkPath)) ?>"><?= e($linkLabel) ?></a>
<?php endforeach; ?>
                            </p>
<?php endif; ?>
                        </div>
                    </details>
<?php endforeach; ?>
                </section>
<?php endforeach; ?>

                <aside class="lt-doc-note" aria-label="Cần thêm hỗ trợ">
                    <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                    <p>Cần hỗ trợ về một đơn cụ thể: liên hệ LocalTour kèm mã đơn (dạng LTxxxxxx). Quy định đầy đủ ở trang <a href="<?= e(url('/dieu-khoan')) ?>">Điều khoản sử dụng</a>.</p>
                </aside>
            </div>
        </div>
    </div>
</main>
