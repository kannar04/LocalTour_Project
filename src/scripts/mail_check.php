<?php

declare(strict_types=1);

/*
 * Kiểm tra cấu hình gửi email (các khóa MAIL_* trong src/.env) – Nguyễn Tuấn Khôi.
 *   C:\xampp\php\php.exe src\scripts\mail_check.php                kết nối, STARTTLS / TLS, đăng nhập rồi QUIT (không gửi email)
 *   C:\xampp\php\php.exe src\scripts\mail_check.php ban@gmail.com  gửi thêm một email thử tới địa chỉ này
 * In các dòng trao đổi với máy chủ SMTP (không in mật khẩu).
 */

use App\Services\SmtpMailer;

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require dirname(__DIR__) . '/core/bootstrap.php';

$config = require BASE_PATH . '/config/mail.php';
if (!SmtpMailer::enabled($config)) {
    fwrite(STDERR, 'MAIL_HOST trống: gửi email đang tắt.' . PHP_EOL);
    exit(1);
}

$to = trim((string) ($argv[1] ?? ''));
try {
    $mailer = new SmtpMailer($config);
    if ($to === '') {
        foreach ($mailer->probe(true) as $line) {
            echo $line . PHP_EOL;
        }
        echo 'Kết nối được ' . $config['host'] . ':' . $config['port'] . ' (' . $config['encryption'] . ')'
            . ($config['username'] !== '' ? ' và đăng nhập thành công.' : '.') . PHP_EOL;
    } else {
        $messageId = $mailer->send(
            $to,
            '',
            'LocalTour – email thử',
            "Email thử từ LocalTour: cấu hình gửi email đã dùng được.\r\n",
            '<p style="font-family:Arial,sans-serif;">Email thử từ <strong>LocalTour</strong>: cấu hình gửi email đã dùng được.</p>'
        );
        echo 'Đã gửi email thử tới ' . $to . ' (Message-ID ' . $messageId . ').' . PHP_EOL;
    }
} catch (Throwable $exception) {
    fwrite(STDERR, 'Lỗi: ' . $exception->getMessage() . PHP_EOL);
    exit(1);
}
