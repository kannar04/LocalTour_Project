<?php

declare(strict_types=1);

/*
 * Hàm dùng chung cho các script cài đặt (Sprint 6 – đóng gói demo):
 * install_database.php, create_admin.php, check_install.php. Chỉ chạy từ dòng lệnh.
 * - In kết quả từng dòng OK / CẢNH BÁO / LỖI.
 * - Đọc src/.env bằng Core\Env như ứng dụng (biến môi trường của máy được ưu tiên).
 * - Tìm mysql.exe và gọi nó, mật khẩu database nằm trong file tạm (xóa ngay sau khi chạy), không đưa lên dòng lệnh.
 * - Đọc danh sách bảng / procedure phải có từ các file src/database/NN_*.sql.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

define('SETUP_SRC', dirname(__DIR__));

require_once SETUP_SRC . '/core/Env.php';

use Core\Env;

/** In kết quả theo dòng và đếm số OK / cảnh báo / lỗi. */
final class SetupReport
{
    private const LABELS = ['ok' => 'OK        ', 'warn' => 'CẢNH BÁO  ', 'error' => 'LỖI       ', 'info' => '          '];

    /** @var array<string, int> */
    private static array $counts = ['ok' => 0, 'warn' => 0, 'error' => 0, 'info' => 0];

    public static function ok(string $message): void
    {
        self::line('ok', $message);
    }

    public static function warn(string $message): void
    {
        self::line('warn', $message);
    }

    public static function error(string $message): void
    {
        self::line('error', $message);
    }

    /** Dòng giải thích / hướng dẫn, thụt lề theo cột nội dung, không tính vào kết quả. */
    public static function info(string $message): void
    {
        self::line('info', $message);
    }

    public static function title(string $message): void
    {
        fwrite(STDOUT, $message . PHP_EOL);
    }

    public static function errors(): int
    {
        return self::$counts['error'];
    }

    public static function summary(): void
    {
        fwrite(STDOUT, sprintf(
            'Kết quả: %d OK, %d cảnh báo, %d lỗi.%s',
            self::$counts['ok'],
            self::$counts['warn'],
            self::$counts['error'],
            PHP_EOL
        ));
    }

    private static function line(string $kind, string $message): void
    {
        self::$counts[$kind]++;
        $lines = preg_split('/\R/', $message) ?: [$message];
        $text = self::LABELS[$kind] . array_shift($lines);
        foreach ($lines as $line) {
            $text .= PHP_EOL . self::LABELS['info'] . $line;
        }
        fwrite(STDOUT, $text . PHP_EOL);
    }
}

/** Lỗi khi chạy mysql.exe; code = mã lỗi MySQL (vd. 1049) nếu đọc được. */
final class SetupMysqlException extends RuntimeException
{
}

/**
 * Gọi mysql.exe (client dòng lệnh của MySQL / MariaDB).
 * Mật khẩu được ghi vào một file tùy chọn tạm ([client] password=...) truyền bằng --defaults-extra-file,
 * nên không hiện trên dòng lệnh hay danh sách tiến trình; file bị xóa khi xong (kể cả khi script dừng giữa chừng).
 */
final class SetupMysql
{
    private string $optionFile = '';

    /** @param array{host: string, port: int, username: string, password: string} $config */
    public function __construct(private string $binary, private array $config)
    {
        $directory = self::tempDirectory($binary);
        $file = $directory === null ? false : @tempnam($directory, 'lt_my');
        if ($file === false) {
            throw new RuntimeException('Không tạo được file tạm để truyền mật khẩu database cho mysql.');
        }

        $this->optionFile = $file;
        register_shutdown_function([$this, 'close']);
        $content = "[client]\npassword=\"" . str_replace(['\\', '"'], ['\\\\', '\\"'], $config['password']) . "\"\n";
        if (@file_put_contents($file, $content) === false) {
            $this->close();
            throw new RuntimeException('Không ghi được file tạm để truyền mật khẩu database cho mysql.');
        }
    }

    public function __destruct()
    {
        $this->close();
    }

    /** Xóa file tạm chứa mật khẩu. */
    public function close(): void
    {
        if ($this->optionFile !== '' && is_file($this->optionFile)) {
            @unlink($this->optionFile);
        }
        $this->optionFile = '';
    }

    /**
     * Chạy một câu lệnh, trả về các dòng kết quả (mỗi dòng là mảng cột).
     *
     * @return list<list<string>>
     */
    public function query(string $sql, ?string $database = null): array
    {
        $arguments = ['--batch', '--skip-column-names', '--execute=' . $sql];
        if ($database !== null) {
            $arguments[] = $database;
        }

        [$code, $output, $error] = $this->run($arguments);
        if ($code !== 0) {
            throw self::exception($error);
        }

        $rows = [];
        foreach (preg_split('/\R/', trim($output)) ?: [] as $line) {
            if ($line !== '') {
                $rows[] = explode("\t", $line);
            }
        }

        return $rows;
    }

    /** Import một file .sql vào database; lỗi thì ném SetupMysqlException (mysql dừng ở câu lỗi đầu tiên). */
    public function import(string $database, string $file): void
    {
        [$code, , $error] = $this->run(['--batch', $database], $file);
        if ($code !== 0) {
            throw self::exception($error);
        }
    }

    /**
     * @param list<string> $arguments
     * @return array{0: int, 1: string, 2: string} mã thoát, stdout, stderr
     */
    private function run(array $arguments, ?string $stdinFile = null): array
    {
        if ($this->optionFile === '') {
            throw new RuntimeException('Đã đóng kết nối mysql.');
        }

        // --defaults-extra-file phải đứng đầu danh sách tùy chọn.
        $command = array_merge([
            $this->binary,
            '--defaults-extra-file=' . $this->optionFile,
            '--host=' . $this->config['host'],
            '--port=' . $this->config['port'],
            '--user=' . $this->config['username'],
            '--default-character-set=utf8mb4',
        ], $arguments);
        $descriptors = [
            0 => $stdinFile === null ? ['pipe', 'r'] : ['file', $stdinFile, 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $process = proc_open($command, $descriptors, $pipes, null, null, ['bypass_shell' => true]);
        if (!is_resource($process)) {
            throw new RuntimeException('Không chạy được ' . $this->binary . '.');
        }
        if ($stdinFile === null) {
            fclose($pipes[0]);
        }

        $output = (string) stream_get_contents($pipes[1]);
        $error = (string) stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);

        return [proc_close($process), $output, $error];
    }

    private static function exception(string $stderr): SetupMysqlException
    {
        $message = trim($stderr) === '' ? 'mysql báo lỗi nhưng không có nội dung.' : trim($stderr);
        $code = preg_match('/ERROR (\d+)/', $message, $match) ? (int) $match[1] : 0;

        return new SetupMysqlException($message, $code);
    }

    /**
     * Thư mục cho file tạm: mysql.exe đọc tên file theo bảng mã ANSI của Windows, nên chỉ dùng thư mục có
     * đường dẫn không dấu (thư mục Temp của Windows, nếu tên tài khoản Windows có dấu thì dùng xampp\tmp).
     */
    private static function tempDirectory(string $binary): ?string
    {
        $candidates = [sys_get_temp_dir(), dirname($binary, 3) . DIRECTORY_SEPARATOR . 'tmp', SETUP_SRC . '/storage/logs'];
        foreach ($candidates as $directory) {
            if (preg_match('/^[\x20-\x7E]+$/', $directory) === 1 && is_dir($directory) && is_writable($directory)) {
                return $directory;
            }
        }

        return null;
    }
}

/**
 * Đọc tham số dạng --ten=gia-tri hoặc --ten.
 *
 * @param list<string> $argv
 * @param list<string> $allowed tên tham số hợp lệ (không có "--")
 * @return array<string, string|true>
 */
function setup_args(array $argv, array $allowed): array
{
    $options = [];
    foreach (array_slice($argv, 1) as $argument) {
        if (!preg_match('/^--([a-z-]+)(?:=(.*))?$/s', $argument, $match) || !in_array($match[1], $allowed, true)) {
            throw new InvalidArgumentException('Tham số không hợp lệ: ' . $argument);
        }
        $options[$match[1]] = array_key_exists(2, $match) ? $match[2] : true;
    }

    return $options;
}

/** Đọc src/.env (nếu có). Trả về false khi chưa có file. */
function setup_load_env(): bool
{
    $file = SETUP_SRC . '/.env';
    Env::load($file);

    return is_file($file);
}

/** Tên database chỉ gồm chữ không dấu, số và dấu gạch dưới (dùng được trong câu lệnh mà không cần escape). */
function setup_valid_database_name(string $name): bool
{
    return preg_match('/^[A-Za-z0-9_]{1,64}$/', $name) === 1;
}

/**
 * Thông tin kết nối giống ứng dụng (config/database.php đọc từ .env).
 *
 * @return array{host: string, port: int, database: string, username: string, password: string}
 */
function setup_db_config(): array
{
    $config = require SETUP_SRC . '/config/database.php';

    return [
        'host' => (string) $config['host'],
        'port' => (int) $config['port'],
        'database' => (string) $config['database'],
        'username' => (string) $config['username'],
        'password' => (string) $config['password'],
    ];
}

/**
 * Đường dẫn mysql.exe: MYSQL_BIN (biến môi trường hoặc .env), C:\xampp\mysql\bin\mysql.exe,
 * thư mục mysql cạnh thư mục PHP đang chạy (vd. D:\xampp), rồi PATH. null nếu không tìm thấy.
 */
function setup_find_mysql(): ?string
{
    $override = trim(Env::get('MYSQL_BIN'), " \"'");
    if ($override !== '') {
        return is_file($override) ? $override : null;
    }

    $candidates = [
        'C:\\xampp\\mysql\\bin\\mysql.exe',
        dirname(PHP_BINARY, 2) . DIRECTORY_SEPARATOR . 'mysql' . DIRECTORY_SEPARATOR . 'bin' . DIRECTORY_SEPARATOR . 'mysql.exe',
    ];
    foreach (explode(PATH_SEPARATOR, (string) getenv('PATH')) as $directory) {
        $directory = rtrim(trim($directory, '"'), '\\/');
        if ($directory !== '') {
            $candidates[] = $directory . DIRECTORY_SEPARATOR . 'mysql.exe';
            $candidates[] = $directory . DIRECTORY_SEPARATOR . 'mysql';
        }
    }

    foreach ($candidates as $candidate) {
        if (is_file($candidate)) {
            return $candidate;
        }
    }

    return null;
}

/**
 * Các file src/database/NN_*.sql theo thứ tự tên (01, 02, …). Không gồm file gộp db_localtour.sql.
 *
 * @return list<string>
 */
function setup_sql_files(): array
{
    $files = glob(SETUP_SRC . '/database/[0-9][0-9]_*.sql') ?: [];
    sort($files, SORT_STRING);

    return array_values($files);
}

/** Bỏ chú thích SQL (-- …, # …, /* … *\/) để không đọc nhầm tên bảng / procedure trong chú thích. */
function setup_strip_sql_comments(string $sql): string
{
    $sql = preg_replace('#/\*(?!!).*?\*/#s', ' ', $sql) ?? $sql;

    return preg_replace('/(?:--(?=[ \t\r\n]|$)|#)[^\n]*/m', ' ', $sql) ?? $sql;
}

/** Câu USE / CREATE DATABASE / DROP DATABASE trong file (sẽ đổi sang database khác khi import): null nếu không có. */
function setup_database_switch(string $file): ?string
{
    $sql = setup_strip_sql_comments((string) file_get_contents($file));
    if (preg_match('/^[ \t]*(USE[ \t]+`?\w+`?[ \t]*;|(?:CREATE|DROP)[ \t]+(?:DATABASE|SCHEMA)\b[^\n]*)/im', $sql, $match)) {
        return trim($match[1]);
    }

    return null;
}

/**
 * Bảng và procedure phải có sau khi import lần lượt các file: đọc CREATE / DROP theo đúng thứ tự
 * (procedure tạm của file migration tạo rồi xóa ngay thì không tính; bảng tạm TEMPORARY không tính).
 *
 * @param list<string> $files
 * @return array{tables: array<string, string>, procedures: array<string, string>} khóa = tên chữ thường
 */
function setup_expected_objects(array $files): array
{
    $objects = ['table' => [], 'procedure' => []];
    $pattern = '/\b(?:CREATE\s+(?:OR\s+REPLACE\s+)?(?:DEFINER\s*=\s*\S+\s+)?(TABLE|PROCEDURE)\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(\w+)`?'
        . '|DROP\s+(TABLE|PROCEDURE)\s+(?:IF\s+EXISTS\s+)?((?:`?\w+`?\s*,\s*)*`?\w+`?))/i';

    foreach ($files as $file) {
        $sql = setup_strip_sql_comments((string) file_get_contents($file));
        preg_match_all($pattern, $sql, $matches, PREG_SET_ORDER);
        foreach ($matches as $match) {
            if (($match[1] ?? '') !== '') {
                $objects[strtolower($match[1])][strtolower($match[2])] = $match[2];
                continue;
            }
            foreach (preg_split('/\s*,\s*/', str_replace('`', '', $match[4])) ?: [] as $name) {
                unset($objects[strtolower($match[3])][strtolower($name)]);
            }
        }
    }

    ksort($objects['table']);
    ksort($objects['procedure']);

    return ['tables' => $objects['table'], 'procedures' => $objects['procedure']];
}

/** "a, b, c" (tối đa $limit tên, còn lại ghi "… và N tên khác"). */
function setup_name_list(array $names, int $limit = 12): string
{
    $names = array_values($names);
    $text = implode(', ', array_slice($names, 0, $limit));
    if (count($names) > $limit) {
        $text .= sprintf(' … và %d tên khác', count($names) - $limit);
    }

    return $text;
}

/** Đường dẫn hiển thị kiểu Windows (dấu \) cho người dùng. */
function setup_display_path(string $path): string
{
    return DIRECTORY_SEPARATOR === '\\' ? str_replace('/', '\\', $path) : $path;
}
