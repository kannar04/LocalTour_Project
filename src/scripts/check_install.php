<?php

declare(strict_types=1);

/*
 * Kiểm tra cài đặt LocalTour trên máy đang dùng (Sprint 6 – đóng gói demo, thử cài trên máy khác).
 * Kiểm tra PHP và extension, src/.env, kết nối database, đủ bảng / procedure của các file src/database/NN_*.sql,
 * bảng mã, tài khoản quản trị, lịch còn nhận khách, thư mục ghi được, ảnh tour, cách chạy (Apache / php -S).
 * Mỗi dòng: OK, CẢNH BÁO (vẫn chạy được) hoặc LỖI (phải sửa). Có LỖI thì mã thoát 1.
 *
 * Cách dùng (đứng ở thư mục src):
 *   C:\xampp\php\php.exe scripts\check_install.php
 *   C:\xampp\php\php.exe scripts\check_install.php --database=ten_database    kiểm tra database khác .env
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/setup_common.php';

use App\Services\VietQr;
use App\Services\VnpayGateway;
use Core\Database;
use Core\Env;

/** Extension ứng dụng cần: PDO MySQL (database), mbstring (chuỗi tiếng Việt), curl, openssl, json, fileinfo (ảnh tải lên). */
const CHECK_EXTENSIONS = ['pdo_mysql', 'mbstring', 'curl', 'openssl', 'json', 'fileinfo'];

exit(check_main($argv));

/** @param list<string> $argv */
function check_main(array $argv): int
{
    SetupReport::title('LocalTour – kiểm tra cài đặt (' . setup_display_path(SETUP_SRC) . ')');

    try {
        $options = setup_args($argv, ['database', 'help']);
    } catch (InvalidArgumentException $exception) {
        SetupReport::error($exception->getMessage() . PHP_EOL . 'Cách dùng: C:\\xampp\\php\\php.exe scripts\\check_install.php [--database=ten_database]');
        return 1;
    }
    if (isset($options['help'])) {
        SetupReport::info('Cách dùng (đứng ở thư mục src): C:\\xampp\\php\\php.exe scripts\\check_install.php [--database=ten_database]');
        return 0;
    }

    $phpReady = check_php();
    $envReady = check_env_file();
    if (isset($options['database'])) {
        $database = trim((string) $options['database']);
        if (!setup_valid_database_name($database)) {
            SetupReport::error('Tên database "' . $database . '" không hợp lệ.');
            return 1;
        }
        putenv('DB_DATABASE=' . $database);
    }

    if ($phpReady && $envReady) {
        require SETUP_SRC . '/core/bootstrap.php';
        check_config();
        check_database();
    } elseif (!$phpReady) {
        SetupReport::error('Bỏ qua kiểm tra cấu hình và database vì PHP chưa đủ yêu cầu ở trên.');
    } else {
        SetupReport::info('Bỏ qua kiểm tra cấu hình và database cho tới khi có file .env.');
    }

    check_folders();
    check_run_modes();

    SetupReport::summary();

    return SetupReport::errors() > 0 ? 1 : 0;
}

/** PHP ≥ 8.2 và đủ extension. Trả về false khi không chạy tiếp được phần dùng mã ứng dụng. */
function check_php(): bool
{
    $versionOk = version_compare(PHP_VERSION, '8.2.0', '>=');
    if ($versionOk) {
        SetupReport::ok('PHP ' . PHP_VERSION . ' (' . PHP_BINARY . ')');
    } else {
        SetupReport::error('PHP ' . PHP_VERSION . ' (' . PHP_BINARY . '): cần PHP 8.2 trở lên (XAMPP 8.2.x).');
    }

    $missing = array_values(array_filter(CHECK_EXTENSIONS, static fn (string $name): bool => !extension_loaded($name)));
    if ($missing === []) {
        SetupReport::ok('Extension PHP: ' . implode(', ', CHECK_EXTENSIONS));
    } else {
        $ini = php_ini_loaded_file();
        SetupReport::error('Thiếu extension PHP: ' . implode(', ', $missing) . PHP_EOL
            . 'Mở ' . ($ini === false ? 'php.ini' : $ini) . ', bỏ dấu ; trước dòng extension=' . $missing[0]
            . ' (mỗi extension một dòng), lưu rồi khởi động lại Apache / server.');
    }

    return $versionOk && extension_loaded('pdo_mysql') && extension_loaded('mbstring');
}

function check_env_file(): bool
{
    if (setup_load_env()) {
        SetupReport::ok('Có file src\\.env');
        return true;
    }

    SetupReport::error('Chưa có file src\\.env (ứng dụng sẽ dùng giá trị mặc định).' . PHP_EOL
        . 'Đứng ở thư mục src, chạy: copy .env.example .env rồi sửa các dòng DB_… nếu cần.');

    return false;
}

/** APP_DEBUG, APP_URL và các khóa thanh toán thử (tùy chọn, không in giá trị khóa). */
function check_config(): void
{
    $app = require SETUP_SRC . '/config/app.php';
    if ($app['debug']) {
        SetupReport::warn('APP_DEBUG=true: trang lỗi hiện chi tiết kỹ thuật cho người xem. Demo và máy khác: đặt APP_DEBUG=false.');
    } else {
        SetupReport::ok('APP_DEBUG=false');
    }

    if ($app['url'] === '') {
        SetupReport::ok('APP_URL để trống: đường dẫn tự tính theo cách chạy (khuyến nghị)');
    } else {
        SetupReport::warn('APP_URL=' . $app['url'] . ': mọi link và ảnh dùng địa chỉ này. Link hoặc ảnh trỏ sai thì để trống APP_URL.');
    }

    $payment = require SETUP_SRC . '/config/payment.php';
    if (VnpayGateway::enabled($payment)) {
        SetupReport::ok('VNPay sandbox: đã có khóa (giá trị không in ra)');
    } else {
        SetupReport::warn('VNPay sandbox chưa có VNPAY_TMN_CODE / VNPAY_HASH_SECRET (tùy chọn): trang thanh toán hiện "VNPay đang tạm ngưng".');
    }
    if (VietQr::enabled($payment)) {
        SetupReport::ok('VietQR: đã có tài khoản nhận (giá trị không in ra)');
    } else {
        SetupReport::warn('VietQR chưa có PAYMENT_BANK_ID / PAYMENT_ACCOUNT_NO hợp lệ (tùy chọn): trang thanh toán hiện "VietQR đang tạm ngưng".');
    }
}

function check_database(): void
{
    $config = setup_db_config();
    $label = $config['database'] . ' tại ' . $config['host'] . ':' . $config['port'] . ' (tài khoản ' . $config['username'] . ')';

    try {
        Database::connection();
        $info = Database::call('NTK_sp_setup_db_info')[0] ?? [];
    } catch (Throwable $exception) {
        SetupReport::error('Database ' . $label . ':' . PHP_EOL . check_db_message($exception));
        return;
    }

    SetupReport::ok('Kết nối database ' . $label . ', ' . (string) $info['server_version']);
    if (!str_starts_with((string) $info['db_charset'], 'utf8mb4')) {
        SetupReport::error('Database dùng bảng mã ' . $info['db_charset'] . ' (' . $info['db_collation'] . '): tiếng Việt sẽ bị lỗi.' . PHP_EOL
            . 'Cài lại database: scripts\\install_database.bat --fresh (tạo database utf8mb4_unicode_ci).');
    } elseif ($info['db_collation'] !== 'utf8mb4_unicode_ci') {
        SetupReport::warn('Collation của database là ' . $info['db_collation'] . ', nên là utf8mb4_unicode_ci (có thể gặp lỗi 1267 khi so sánh chuỗi).');
    } else {
        SetupReport::ok('Bảng mã database: utf8mb4_unicode_ci');
    }

    check_objects();
    check_demo_data();
}

/** Đủ bảng / procedure của các file NN_*.sql, cùng bảng mã utf8mb4. */
function check_objects(): void
{
    $files = setup_sql_files();
    $expected = setup_expected_objects($files);
    $actual = ['table' => [], 'procedure' => []];
    $badCollation = [];
    $badClient = [];

    try {
        foreach (Database::call('NTK_sp_setup_object_list') as $row) {
            $type = (string) $row['object_type'];
            $name = (string) $row['object_name'];
            $actual[$type][strtolower($name)] = $name;
            if (!str_starts_with((string) $row['collation_name'], 'utf8mb4')) {
                $badCollation[] = $name . ' (' . $row['collation_name'] . ')';
            }
            $client = strtolower((string) ($row['client_charset'] ?? 'utf8mb4'));
            if (!in_array($client, ['utf8mb4', 'utf8', 'utf8mb3'], true)) {
                $badClient[] = $name . ' (' . $client . ')';
            }
        }
    } catch (Throwable $exception) {
        SetupReport::error('Không đọc được danh sách bảng / procedure:' . PHP_EOL . check_db_message($exception));
        return;
    }

    $source = count($files) . ' file ' . basename($files[0] ?? '') . ' → ' . basename($files[count($files) - 1] ?? '');
    foreach (['tables' => ['table', 'bảng'], 'procedures' => ['procedure', 'procedure']] as $key => [$type, $word]) {
        $missing = array_diff_key($expected[$key], $actual[$type]);
        $extra = array_diff_key($actual[$type], $expected[$key]);
        if ($missing === []) {
            SetupReport::ok(sprintf('Đủ %d %s của %s', count($expected[$key]), $word, $source));
        } else {
            SetupReport::error(sprintf('Thiếu %d/%d %s: %s', count($missing), count($expected[$key]), $word, setup_name_list($missing)) . PHP_EOL
                . 'Database cài từ bản cũ hoặc chưa import đủ file: chạy scripts\\install_database.bat --fresh.');
        }
        if ($extra !== []) {
            SetupReport::warn(sprintf('Database có thêm %d %s không có trong các file NN_*.sql: %s', count($extra), $word, setup_name_list($extra)));
        }
    }

    if ($badCollation !== []) {
        SetupReport::error('Bảng / procedure không dùng utf8mb4 (tiếng Việt sẽ lỗi): ' . setup_name_list($badCollation) . PHP_EOL
            . 'Cài lại database: scripts\\install_database.bat --fresh.');
    }
    if ($badClient !== []) {
        SetupReport::error('Procedure được import với bảng mã khác UTF-8 (chữ tiếng Việt trong procedure bị lỗi): ' . setup_name_list($badClient) . PHP_EOL
            . 'Cài lại bằng scripts\\install_database.bat --fresh, hoặc import trong phpMyAdmin với Character set utf-8.');
    }
}

/** Tài khoản quản trị đăng nhập được, lịch còn nhận khách, ảnh tour có file trên máy. */
function check_demo_data(): void
{
    try {
        $status = Database::call('NTK_sp_setup_demo_status')[0] ?? [];
        $images = array_map(static fn (array $row): string => (string) $row['url'], Database::call('NTK_sp_setup_local_image_list'));
    } catch (Throwable $exception) {
        SetupReport::error('Không đọc được dữ liệu demo:' . PHP_EOL . check_db_message($exception));
        return;
    }

    $admins = (int) ($status['admin_ready'] ?? 0);
    if ($admins > 0) {
        SetupReport::ok($admins . ' tài khoản quản trị đăng nhập được');
    } else {
        SetupReport::warn('Chưa có tài khoản quản trị đăng nhập được (tài khoản mẫu không có mật khẩu). Tạo bằng:' . PHP_EOL
            . '  ' . PHP_BINARY . ' scripts\\create_admin.php --email=admin@localtour.test --generate');
    }

    $schedules = (int) ($status['open_schedules'] ?? 0);
    if ($schedules > 0) {
        SetupReport::ok($schedules . ' lịch khởi hành còn nhận khách');
    } else {
        SetupReport::warn('Không còn lịch khởi hành nào nhận khách: lịch mẫu tính theo ngày cài database.' . PHP_EOL
            . 'Cài lại database trước buổi demo: scripts\\install_database.bat --fresh');
    }

    $missing = array_values(array_filter($images, static fn (string $url): bool => !is_file(SETUP_SRC . '/public/assets/' . ltrim($url, '/'))));
    if ($missing === []) {
        SetupReport::ok('Ảnh tour: đủ file của ' . count($images) . ' ảnh lưu trên máy');
    } else {
        SetupReport::warn(sprintf('%d/%d ảnh tour không có file trên máy này, trang hiện ảnh thay thế: %s', count($missing), count($images), setup_name_list($missing, 5)) . PHP_EOL
            . 'Chép thư mục src\\public\\assets\\uploads\\tours từ máy đã tải ảnh lên (ảnh tải lên không có trong Git).');
    }
}

/** Thư mục log, thư mục ảnh tải lên, thư mục phiên PHP: phải ghi được. */
function check_folders(): void
{
    $logs = SETUP_SRC . '/storage/logs';
    if (check_writable($logs) && (!is_file($logs . '/app.log') || is_writable($logs . '/app.log'))) {
        SetupReport::ok('Ghi được thư mục log ' . setup_display_path('storage/logs'));
    } else {
        SetupReport::error('Không ghi được ' . setup_display_path($logs) . ' (hoặc app.log): lỗi của trang sẽ không được ghi lại.' . PHP_EOL
            . 'Cho tài khoản chạy Apache / PHP quyền ghi thư mục này (thư mục phải có sẵn, repo có file .gitkeep).');
    }

    $uploads = SETUP_SRC . '/public/assets/uploads';
    $tours = $uploads . '/tours';
    if (!is_dir($uploads)) {
        SetupReport::warn('Chưa có thư mục ' . setup_display_path('public/assets/uploads') . ': tạo thư mục này để quản trị viên tải được ảnh tour.');
    } elseif (check_writable(is_dir($tours) ? $tours : $uploads)) {
        $count = is_dir($tours) ? count(glob($tours . '/*.{jpg,jpeg,png,webp}', GLOB_BRACE) ?: []) : 0;
        SetupReport::ok('Ghi được thư mục ảnh tải lên ' . setup_display_path('public/assets/uploads/tours') . ' (hiện có ' . $count . ' ảnh)');
    } else {
        SetupReport::error('Không ghi được ' . setup_display_path(is_dir($tours) ? $tours : $uploads) . ': tải ảnh tour sẽ báo "Chưa lưu được ảnh trên máy chủ".');
    }
    if (!is_file(SETUP_SRC . '/public/assets/img/tour-placeholder.svg')) {
        SetupReport::error('Thiếu ảnh thay thế public\\assets\\img\\tour-placeholder.svg: lấy lại mã nguồn đầy đủ.');
    }

    $sessions = (string) ini_get('session.save_path');
    $sessions = $sessions === '' ? sys_get_temp_dir() : preg_replace('/^.*;/', '', $sessions);
    if (check_writable($sessions)) {
        SetupReport::ok('Ghi được thư mục phiên đăng nhập của PHP (' . $sessions . ')');
    } else {
        SetupReport::warn('Không ghi được thư mục phiên PHP ' . $sessions . ' (session.save_path trong php.ini): đăng nhập và gửi form sẽ báo "Phiên làm việc đã hết hạn".');
    }
}

/** Thử tạo rồi xóa một file (is_writable() trên Windows không đáng tin với thư mục). */
function check_writable(string $directory): bool
{
    if (!is_dir($directory)) {
        return false;
    }
    $probe = rtrim($directory, '\\/') . DIRECTORY_SEPARATOR . '.check_install_' . bin2hex(random_bytes(4));
    if (@file_put_contents($probe, 'ok') === false) {
        return false;
    }
    @unlink($probe);

    return true;
}

/** File cần cho Apache / php -S và địa chỉ mở trang theo vị trí thư mục. */
function check_run_modes(): void
{
    $missing = array_filter(['.htaccess', 'public/.htaccess', 'public/router.php', 'public/index.php'],
        static fn (string $file): bool => !is_file(SETUP_SRC . '/' . $file));
    if ($missing === []) {
        SetupReport::ok('Có public\\index.php, public\\router.php (php -S), .htaccess và public\\.htaccess (Apache)');
    } else {
        SetupReport::error('Thiếu ' . implode(', ', array_map('setup_display_path', $missing)) . ': lấy lại mã nguồn đầy đủ (giải nén giữ cả file bắt đầu bằng dấu chấm).');
    }

    $src = str_replace('\\', '/', SETUP_SRC);
    $php = PHP_BINARY;
    SetupReport::info('Chạy bằng PHP built-in server (đứng ở thư mục src):' . PHP_EOL
        . '  ' . $php . ' -S 127.0.0.1:8080 -t public public/router.php' . PHP_EOL
        . '  rồi mở http://127.0.0.1:8080');

    if (!preg_match('#^(.*/htdocs)/(.+)$#i', $src, $match)) {
        SetupReport::info('Thư mục không nằm trong htdocs của XAMPP: muốn chạy bằng Apache thì đặt thư mục dự án trong C:\\xampp\\htdocs.');
        return;
    }

    $segments = explode('/', $match[2]);
    $url = 'http://localhost/' . implode('/', array_map('rawurlencode', $segments)) . '/public/';
    SetupReport::info('Chạy bằng Apache của XAMPP (Start Apache trong XAMPP Control Panel), mở:' . PHP_EOL . '  ' . $url);
    if (preg_match('#[^A-Za-z0-9._/-]#', $match[2])) {
        SetupReport::warn('Đường dẫn trong htdocs có khoảng trắng hoặc ký tự đặc biệt / có dấu ("' . $match[2] . '"): địa chỉ phải gõ dạng mã hóa như trên. Nên đổi tên thư mục, ví dụ LocalTour_Project.');
    }

    $httpdConf = dirname($match[1]) . '/apache/conf/httpd.conf';
    $conf = is_file($httpdConf) ? (string) file_get_contents($httpdConf) : '';
    if ($conf === '') {
        return;
    }
    if (!preg_match('/^\s*LoadModule\s+rewrite_module\s/m', $conf)) {
        SetupReport::warn('Apache chưa bật mod_rewrite: mọi trang trừ trang chủ sẽ 404. Trong ' . setup_display_path($httpdConf)
            . ' bỏ dấu # trước dòng LoadModule rewrite_module modules/mod_rewrite.so rồi khởi động lại Apache.');
    } else {
        SetupReport::ok('Apache: đã bật mod_rewrite');
    }
    $block = preg_match('#<Directory\s+"?' . preg_quote($match[1], '#') . '"?\s*>(.*?)</Directory>#is', $conf, $directory) ? $directory[1] : '';
    if ($block !== '' && !preg_match('/^\s*AllowOverride\s+All\b/mi', $block)) {
        SetupReport::warn('Apache bỏ qua .htaccess trong htdocs (AllowOverride khác All): mọi trang trừ trang chủ sẽ 404, .env không được chặn.'
            . ' Trong khối <Directory "' . $match[1] . '"> của httpd.conf đặt AllowOverride All.');
    } elseif ($block !== '') {
        SetupReport::ok('Apache: htdocs cho phép .htaccess (AllowOverride All)');
    }
}

/** Thông báo dễ hiểu cho lỗi database (không chứa mật khẩu). */
function check_db_message(Throwable $exception): string
{
    $previous = $exception->getPrevious() ?? $exception;
    $text = $previous->getMessage();
    $code = $previous instanceof PDOException ? (int) ($previous->errorInfo[1] ?? 0) : 0;
    if ($code === 0 && preg_match('/\[(\d{4})\]/', $text, $match)) {
        $code = (int) $match[1];
    }

    $hint = match (true) {
        $code === 1049 => 'Chưa có database này: sửa DB_DATABASE trong .env, hoặc cài bằng scripts\\install_database.bat.',
        $code === 1045 => 'Sai DB_USERNAME / DB_PASSWORD trong .env (XAMPP mặc định: root, mật khẩu trống).',
        $code === 2002 || $code === 2003 || $code === 2006 => 'MySQL chưa chạy hoặc sai DB_HOST / DB_PORT: mở XAMPP Control Panel, Start MySQL (xem mục cổng 3306 trong hướng dẫn).',
        $code === 1305 || $code === 1146 => 'Database chưa cài đủ các file NN_*.sql (cài từ bản cũ, hoặc file gộp cũ): chạy scripts\\install_database.bat --fresh.',
        default => 'Kiểm tra MySQL đang chạy và các dòng DB_… trong .env.',
    };

    return $text . PHP_EOL . $hint;
}
