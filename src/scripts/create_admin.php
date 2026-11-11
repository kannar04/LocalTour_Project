<?php

declare(strict_types=1);

/*
 * Tạo hoặc đặt lại tài khoản quản trị viên (Sprint 6 – đóng gói demo).
 * Tài khoản mẫu có password_hash NULL nên không đăng nhập được; trang quản trị /admin/login chỉ nhận tài khoản
 * role 'admin', đang hoạt động, có mật khẩu (AdminAuthController). Script này đặt mật khẩu cho một email:
 *   - email chưa có: tạo tài khoản quản trị mới;
 *   - email là quản trị viên (vd. admin@localtour.test của dữ liệu mẫu): đặt mật khẩu mới, mở khóa;
 *   - email của khách hàng / nhà cung cấp: dừng, không nâng quyền.
 * Mật khẩu gõ ở cửa sổ dòng lệnh (không hiện khi gõ) hoặc tự sinh (--generate) và chỉ in ra một lần.
 * Database chỉ nhận chuỗi băm password_hash(); script không ghi mật khẩu vào file hay log.
 *
 * Cách dùng (đứng ở thư mục src):
 *   C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test             gõ mật khẩu
 *   C:\xampp\php\php.exe scripts\create_admin.php --email=admin@localtour.test --generate  tự sinh mật khẩu
 *   thêm --name="Tên hiển thị" (tài khoản mới), --database=ten_database (database khác .env)
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/setup_common.php';

use App\Models\UserModel;
use Core\Database;

const ADMIN_USAGE = <<<'TXT'
Cách dùng (đứng ở thư mục src):
  C:\xampp\php\php.exe scripts\create_admin.php --email=<email> [--generate] [--name="Tên"] [--database=ten_database]
  --generate  tự sinh mật khẩu và in ra một lần; không có thì gõ mật khẩu (2 lần)
TXT;

exit(admin_main($argv));

/** @param list<string> $argv */
function admin_main(array $argv): int
{
    SetupReport::title('LocalTour – tài khoản quản trị');

    try {
        $options = setup_args($argv, ['email', 'name', 'generate', 'database', 'help']);
    } catch (InvalidArgumentException $exception) {
        SetupReport::error($exception->getMessage());
        SetupReport::info(ADMIN_USAGE);
        return 1;
    }
    if (isset($options['help'])) {
        SetupReport::info(ADMIN_USAGE);
        return 0;
    }

    if (!setup_load_env()) {
        SetupReport::error('Chưa có file src\\.env. Đứng ở thư mục src, chạy: copy .env.example .env');
        return 1;
    }
    if (isset($options['database'])) {
        $database = trim((string) $options['database']);
        if (!setup_valid_database_name($database)) {
            SetupReport::error('Tên database "' . $database . '" không hợp lệ.');
            return 1;
        }
        putenv('DB_DATABASE=' . $database);
    }

    require SETUP_SRC . '/core/bootstrap.php';

    $email = isset($options['email']) && $options['email'] !== true ? (string) $options['email'] : admin_prompt('Email tài khoản quản trị: ');
    $email = mb_strtolower(trim($email));
    if ($email === '' || mb_strlen($email) > UserModel::EMAIL_MAX_LENGTH || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        SetupReport::error('Email không hợp lệ. Ví dụ: --email=admin@localtour.test');
        SetupReport::info(ADMIN_USAGE);
        return 1;
    }

    $name = null;
    if (isset($options['name']) && $options['name'] !== true) {
        $name = trim((string) $options['name']);
        if ($name === '' || !mb_check_encoding($name, 'UTF-8') || mb_strlen($name) > UserModel::NAME_MAX_LENGTH) {
            SetupReport::error('Tên hiển thị phải có 1–' . UserModel::NAME_MAX_LENGTH . ' ký tự.');
            return 1;
        }
    }

    $config = setup_db_config();
    try {
        $existing = (new UserModel())->findByEmail($email);
    } catch (Throwable $exception) {
        SetupReport::error('Không đọc được database ' . $config['database'] . ' tại ' . $config['host'] . ':' . $config['port'] . ':'
            . PHP_EOL . admin_db_message($exception));
        return 1;
    }

    if ($existing !== null && $existing['role'] !== 'admin') {
        SetupReport::error(sprintf(
            '%s là tài khoản %s. Script không đổi tài khoản này thành quản trị viên; dùng email khác.',
            $email,
            $existing['role'] === 'customer' ? 'khách hàng' : 'nhà cung cấp'
        ));
        return 1;
    }
    SetupReport::ok($existing === null
        ? 'Database ' . $config['database'] . ': chưa có ' . $email . ', sẽ tạo tài khoản quản trị mới.'
        : 'Database ' . $config['database'] . ': ' . $email . ' là quản trị viên, sẽ đặt mật khẩu mới.');

    $generated = isset($options['generate']);
    $password = $generated ? admin_generate_password() : admin_ask_password();
    if ($password === null) {
        return 1;
    }

    try {
        $rows = Database::call('NTK_sp_setup_admin_save', [$email, $name, password_hash($password, PASSWORD_DEFAULT)]);
    } catch (Throwable $exception) {
        SetupReport::error('Chưa lưu được tài khoản:' . PHP_EOL . admin_db_message($exception));
        return 1;
    }

    $result = (string) ($rows[0]['result'] ?? '');
    if ($result === 'not_admin') {
        SetupReport::error($email . ' không phải tài khoản quản trị; không thay đổi gì.');
        return 1;
    }
    if ($result !== 'created' && $result !== 'reset') {
        SetupReport::error('Không lưu được tài khoản (kết quả: ' . ($result === '' ? 'trống' : $result) . ').');
        return 1;
    }

    SetupReport::ok(($result === 'created' ? 'Đã tạo tài khoản quản trị ' : 'Đã đặt mật khẩu mới cho ')
        . $email . ' (' . (string) $rows[0]['name'] . ')'
        . (($rows[0]['old_status'] ?? '') === 'locked' ? ', tài khoản đã được mở khóa' : '') . '.');
    if ($generated) {
        SetupReport::info('Mật khẩu (chỉ hiện lần này, ghi lại ngay; không lưu vào file, không gửi vào nhóm chat):');
        SetupReport::info('  ' . $password);
    }
    SetupReport::info('Đăng nhập ở trang /admin/login của ứng dụng, ví dụ http://127.0.0.1:8080/admin/login');

    return 0;
}

/** Mật khẩu ngẫu nhiên 16 ký tự, bỏ các ký tự dễ nhầm (0/O, 1/l/I). */
function admin_generate_password(): string
{
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    $password = '';
    for ($i = 0; $i < 16; $i++) {
        $password .= $alphabet[random_int(0, strlen($alphabet) - 1)];
    }

    return $password;
}

/** Gõ mật khẩu 2 lần; null khi không hợp lệ (đã in lỗi). */
function admin_ask_password(): ?string
{
    $interactive = stream_isatty(STDIN);
    $rule = sprintf('%d–%d ký tự', UserModel::PASSWORD_MIN_LENGTH, UserModel::PASSWORD_MAX_LENGTH);

    for ($attempt = 1; $attempt <= 3; $attempt++) {
        $password = admin_read_secret('Mật khẩu mới (' . $rule . ', không hiện khi gõ): ');
        if ($password === null) {
            SetupReport::error('Không đọc được mật khẩu.');
            return null;
        }

        $error = null;
        if (strlen($password) < UserModel::PASSWORD_MIN_LENGTH || strlen($password) > UserModel::PASSWORD_MAX_LENGTH) {
            $error = 'Mật khẩu phải có ' . $rule . '.';
        } elseif ($interactive && admin_read_secret('Gõ lại mật khẩu: ') !== $password) {
            $error = 'Hai lần gõ không khớp.';
        }

        if ($error === null) {
            return $password;
        }
        SetupReport::error($error);
        if (!$interactive) {
            return null;
        }
    }

    return null;
}

/**
 * Đọc một dòng không hiện ký tự. Cửa sổ dòng lệnh Windows: dùng Read-Host -AsSecureString của PowerShell (hiện dấu *).
 * Không phải cửa sổ dòng lệnh (dữ liệu chuyển qua stdin): đọc dòng đầu tiên.
 */
function admin_read_secret(string $prompt): ?string
{
    if (!stream_isatty(STDIN)) {
        $line = fgets(STDIN);
        return $line === false ? null : rtrim($line, "\r\n");
    }

    fwrite(STDOUT, '          ' . $prompt);
    if (PHP_OS_FAMILY === 'Windows') {
        // PowerShell hiện dấu * trên cửa sổ dòng lệnh; mật khẩu chỉ trả về PHP qua stderr (UTF-8), không ra màn hình.
        $script = '$s = Read-Host -AsSecureString; $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s); '
            . '$w = New-Object IO.StreamWriter([Console]::OpenStandardError(), (New-Object Text.UTF8Encoding $false)); '
            . 'try { $w.Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)); $w.Flush() } '
            . 'finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }';
        $process = @proc_open(['powershell.exe', '-NoProfile', '-Command', $script], [0 => STDIN, 1 => STDOUT, 2 => ['pipe', 'w']], $pipes);
        if (is_resource($process)) {
            $secret = (string) stream_get_contents($pipes[2]);
            fclose($pipes[2]);
            if (proc_close($process) === 0) {
                return $secret;
            }
        }
        SetupReport::warn('Không ẩn được ký tự khi gõ: mật khẩu sẽ hiện trên màn hình.');
        fwrite(STDOUT, '          ' . $prompt);
    } else {
        shell_exec('stty -echo 2>/dev/null');
        $line = fgets(STDIN);
        shell_exec('stty echo 2>/dev/null');
        fwrite(STDOUT, PHP_EOL);
        return $line === false ? null : rtrim($line, "\r\n");
    }

    $line = fgets(STDIN);

    return $line === false ? null : rtrim($line, "\r\n");
}

function admin_prompt(string $prompt): string
{
    if (!stream_isatty(STDIN)) {
        return '';
    }
    fwrite(STDOUT, '          ' . $prompt);
    $line = fgets(STDIN);

    return $line === false ? '' : trim($line);
}

/** Thông báo dễ hiểu cho lỗi kết nối / thiếu procedure / thiếu quyền (không chứa mật khẩu). */
function admin_db_message(Throwable $exception): string
{
    $previous = $exception->getPrevious() ?? $exception;
    $text = $previous->getMessage();
    $code = $previous instanceof PDOException ? (int) ($previous->errorInfo[1] ?? 0) : 0;
    if ($code === 0 && preg_match('/\[(\d{4})\]/', $text, $match)) {
        $code = (int) $match[1];
    }

    $hint = match (true) {
        $code === 1049 => 'Chưa có database này: chạy scripts\\install_database.bat trước.',
        $code === 1045 => 'Sai DB_USERNAME / DB_PASSWORD trong .env.',
        $code === 2002 || $code === 2003 => 'MySQL chưa chạy hoặc sai DB_HOST / DB_PORT: Start MySQL trong XAMPP Control Panel.',
        $code === 1305 || $code === 1146 => 'Database chưa cài đủ (thiếu bảng / procedure, kể cả 26_procedures_NTK_setup.sql): chạy scripts\\install_database.bat --fresh.',
        $code === 1142 || $code === 1143 || $code === 1370 => 'Tài khoản database trong .env không có quyền ghi bảng users (tài khoản ứng dụng của database dùng chung chỉ được gọi procedure). Chạy script trên máy đặt database, bằng tài khoản quản trị MySQL.',
        default => 'Kiểm tra MySQL và các dòng DB_… trong .env, hoặc chạy scripts\\check_install.php.',
    };

    return $text . PHP_EOL . $hint;
}
