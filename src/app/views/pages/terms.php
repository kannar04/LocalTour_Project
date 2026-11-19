<?php declare(strict_types=1); ?>
<?php
/*
 * Điều khoản sử dụng (CR2, Nguyễn Tuấn Khôi).
 * Biến: $rules (PageController::rules(): hold_minutes, booking_cutoff_minutes, vietqr_cutoff_hours,
 *       commission_percent – đã định dạng), $title.
 * Các mục đánh số, mục lục nhảy tới từng mục. Mốc thời gian và % phí dịch vụ là thông số đang áp dụng.
 */
$hold = $rules['hold_minutes'];
$cutoff = $rules['booking_cutoff_minutes'];
$vietqr = $rules['vietqr_cutoff_hours'];
$commission = $rules['commission_percent'];

$sections = [
    'pham-vi' => [
        'title' => 'Phạm vi',
        'points' => [
            'LocalTour là trang kết nối khách với tour địa phương do các đơn vị tổ chức thực hiện. LocalTour nhận đặt tour, nhận thanh toán, xử lý yêu cầu đổi ngày / hủy tour và chi trả cho đơn vị tổ chức.',
            'Điều khoản này áp dụng cho mọi người dùng trang: khách chưa đăng nhập, tài khoản khách hàng, đơn vị tổ chức và quản trị viên.',
            'Dùng trang LocalTour nghĩa là bạn đồng ý với điều khoản này.',
        ],
    ],
    'tai-khoan' => [
        'title' => 'Tài khoản',
        'points' => [
            'Thông tin tài khoản (họ tên, email, số điện thoại) phải đúng và là của bạn. Mỗi email chỉ dùng cho một tài khoản.',
            'Bạn tự giữ mật khẩu và chịu trách nhiệm cho việc làm bằng tài khoản của mình. Mỗi trình duyệt chỉ đăng nhập một tài khoản tại một thời điểm.',
            'Tài khoản đơn vị tổ chức do quản trị viên LocalTour cấp, đơn vị không tự đăng ký.',
            'LocalTour có thể khóa tài khoản vi phạm điều khoản này.',
        ],
    ],
    'dat-tour' => [
        'title' => 'Đặt tour và giữ chỗ',
        'points' => [
            'Đặt tour cần tài khoản khách hàng. Mỗi đơn gắn với một tour, gói (nếu có), ngày khởi hành và số khách. Họ tên khách nhập đúng như trên giấy tờ.',
            'LocalTour giữ chỗ ngay khi đặt, trong ' . $hold . ' phút và không muộn hơn giờ khởi hành. Quá hạn chưa thanh toán, đơn tự hủy và chỗ được trả lại cho lịch.',
            'LocalTour ngừng nhận đặt ' . $cutoff . ' phút trước giờ khởi hành.',
            'Đơn giữ giá lúc đặt; giá thay đổi sau đó chỉ áp dụng cho đơn đặt sau.',
        ],
    ],
    'thanh-toan' => [
        'title' => 'Thanh toán',
        'points' => [
            'Giá tính bằng VND. Bạn thanh toán bằng VNPay hoặc chuyển khoản VietQR trong thời gian giữ chỗ.',
            'Chuyển khoản VietQR chỉ nhận khi còn ít nhất ' . $vietqr . ' giờ tới giờ khởi hành. Khoản VietQR chỉ thành công sau khi LocalTour đối chiếu đủ tiền; khoản VNPay chỉ thành công sau khi LocalTour xác minh kết quả giao dịch.',
            'Voucher chỉ có sau khi thanh toán thành công.',
            'Trang demo dùng môi trường thử nghiệm, không thu tiền thật.',
        ],
    ],
    'huy-doi' => [
        'title' => 'Hủy, đổi lịch và hoàn tiền',
        'points' => [
            'Mỗi tour có chính sách hủy riêng (mốc hủy miễn phí và tỷ lệ hoàn sau mốc), ghi ở trang tour. Đơn áp dụng phiên bản chính sách lúc đặt.',
            'Muốn đổi ngày hoặc hủy, gửi yêu cầu ở trang đơn kèm lý do. Mỗi đơn chỉ có một yêu cầu đang chờ xử lý; không gửi được khi tour đã khởi hành hoặc đơn đã đóng. LocalTour xử lý theo chính sách hủy của đơn và ghi kết quả ở trang đơn.',
            'LocalTour có thể hủy đơn kèm lý do; đơn đã thanh toán thì được hoàn tiền theo quy định của đơn.',
            'Tiền hoàn được LocalTour chuyển khoản lại thủ công, không hoàn tự động.',
        ],
    ],
    'noi-dung' => [
        'title' => 'Nội dung người dùng: bình luận và đánh giá',
        'points' => [
            'Bình luận: tài khoản khách hàng viết được bình luận từ 1 đến 1000 ký tự ở trang tour và tự xóa bình luận của mình.',
            'Đánh giá: chỉ đơn đã hoàn thành mới được đánh giá, mỗi đơn một đánh giá, từ 1 đến 5 sao kèm nhận xét. Đánh giá chỉ hiện sau khi quản trị viên duyệt.',
            'Không đăng nội dung sai sự thật, xúc phạm hoặc gây thù ghét, quảng cáo hoặc lặp lại nhiều lần, liên kết lừa đảo, thông tin cá nhân của người khác (số điện thoại, số tài khoản…), hoặc nội dung trái pháp luật.',
            'Quản trị viên có thể ẩn bình luận và từ chối đánh giá vi phạm hoặc không liên quan tới tour, kèm lý do. LocalTour không sửa nội dung bạn viết.',
            'Bạn chịu trách nhiệm về nội dung mình đăng. Bình luận và đánh giá hiện công khai cùng tên và ảnh đại diện của bạn.',
        ],
    ],
    'thich-luu' => [
        'title' => 'Thích và lưu tour',
        'points' => [
            'Thích và lưu tour cần tài khoản khách hàng. Số lượt thích hiện công khai; LocalTour không hiện ai đã thích.',
            'Danh sách “Tour đã lưu” chỉ chủ tài khoản thấy. Lưu tour không giữ chỗ và không giữ giá.',
        ],
    ],
    'du-lieu' => [
        'title' => 'Ảnh đại diện và dữ liệu tài khoản',
        'points' => [
            'Ảnh đại diện là ảnh JPG, PNG hoặc WebP, tối đa 2 MB. Chỉ dùng ảnh của bạn hoặc ảnh bạn có quyền dùng; không dùng ảnh phản cảm hoặc ảnh giả danh người khác. Bạn đổi hoặc xóa ảnh bất cứ lúc nào ở trang tài khoản.',
            'LocalTour dùng họ tên, email và số điện thoại để xử lý đơn và liên hệ về chuyến đi. Đơn vị tổ chức thấy người liên hệ và danh sách khách của các đơn trên tour của mình.',
            'LocalTour không bán dữ liệu tài khoản cho bên khác.',
        ],
    ],
    'don-vi' => [
        'title' => 'Trách nhiệm của đơn vị tổ chức',
        'points' => [
            'Đơn vị tổ chức cung cấp thông tin tour đúng và đầy đủ, cập nhật lịch khởi hành, sức chứa và giá vé, và thực hiện tour như đã mô tả.',
            'Tour mới và bản sửa của tour đã duyệt chỉ hiện cho khách sau khi quản trị viên duyệt.',
            'Phí dịch vụ LocalTour hiện là ' . $commission . ' % tiền thực thu, lưu vào từng đơn lúc đặt. Sau khi lịch khởi hành kết thúc, LocalTour chi trả phần thực nhận (tiền thực thu − phí dịch vụ) vào tài khoản nhận tiền đã được xác minh của đơn vị.',
        ],
    ],
    'thay-doi' => [
        'title' => 'Thay đổi điều khoản',
        'points' => [
            'LocalTour có thể cập nhật điều khoản này; ngày hiệu lực ghi ở đầu trang. Đơn đã đặt vẫn giữ giá và chính sách hủy lúc đặt.',
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
                <li class="breadcrumb-item active" aria-current="page">Điều khoản sử dụng</li>
            </ol>
        </nav>

        <header class="lt-doc-head">
            <h1 class="lt-doc-head__title">Điều khoản sử dụng</h1>
            <p class="lt-doc-head__lead">Hiệu lực từ ngày 16/11/2026.</p>
            <p class="lt-doc-head__note">
                <span class="lt-icon lt-icon--info" aria-hidden="true"></span>
                Dữ liệu và điều khoản minh họa phục vụ đồ án.
            </p>
        </header>

        <div class="lt-doc-layout">
            <nav class="lt-doc-toc" aria-labelledby="doc-toc-title">
                <h2 class="lt-doc-toc__title" id="doc-toc-title">Nội dung</h2>
                <ol class="lt-doc-toc__list lt-doc-toc__list--numbered">
<?php foreach ($sections as $sectionId => $section): ?>
                    <li><a class="lt-doc-toc__link" href="#<?= e($sectionId) ?>"><?= e($section['title']) ?></a></li>
<?php endforeach; ?>
                </ol>
            </nav>

            <div class="lt-doc-body">
<?php $number = 0; ?>
<?php foreach ($sections as $sectionId => $section): ?>
<?php $number++; ?>
                <section class="lt-doc-section lt-terms" id="<?= e($sectionId) ?>" tabindex="-1" aria-labelledby="<?= e($sectionId) ?>-title">
                    <h2 class="lt-doc-section__title" id="<?= e($sectionId) ?>-title">
                        <span class="lt-doc-section__num" aria-hidden="true"><?= e($number) ?>.</span>
                        <?= e($section['title']) ?>
                    </h2>
                    <ol class="lt-terms__list">
<?php foreach ($section['points'] as $point): ?>
                        <li><?= e($point) ?></li>
<?php endforeach; ?>
                    </ol>
                </section>
<?php endforeach; ?>

                <aside class="lt-doc-note" aria-label="Câu hỏi thường gặp">
                    <span class="lt-icon lt-icon--help" aria-hidden="true"></span>
                    <p>Hướng dẫn từng bước và câu hỏi thường gặp ở trang <a href="<?= e(url('/tro-giup')) ?>">Trợ giúp</a>.</p>
                </aside>
            </div>
        </div>
    </div>
</main>
