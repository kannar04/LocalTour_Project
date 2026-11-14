<?php

declare(strict_types=1);

/*
 * Cài database LocalTour (Sprint 6 – đóng gói demo).
 * Import lần lượt mọi file src/database/NN_*.sql (01, 02, …) vào database ghi trong src/.env (DB_DATABASE),
 * bằng mysql.exe của XAMPP, bảng mã utf8mb4. Không dùng file gộp db_localtour.sql.
 *
 * Cách dùng (đứng ở thư mục src):
 *   C:\xampp\php\php.exe scripts\install_database.php                  cài vào database trong .env (phải trống)
 *   C:\xampp\php\php.exe scripts\install_database.php --fresh          xóa database đó rồi cài lại từ đầu
 *   C:\xampp\php\php.exe scripts\install_database.php --database=ten   cài vào database khác
 * Hoặc bấm đúp scripts\install_database.bat. mysql.exe không nằm ở C:\xampp\mysql\bin thì đặt MYSQL_BIN.
 * Database chưa có thì được tạo (utf8mb4_unicode_ci). Database đã có bảng / procedure thì dừng, trừ khi có --fresh.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/setup_common.php';

const INSTALL_USAGE = <<<'TXT'
Cách dùng (đứng ở thư mục src):
  C:\xampp\php\php.exe scripts\install_database.php [--database=ten_database] [--fresh]
  --database=...  cài vào database này thay cho DB_DATABASE trong .env
  --fresh         xóa database đó (mất hết dữ liệu) rồi cài lại từ đầu
TXT;

exit(install_main($argv));

/** @param list<string> $argv */
function install_main(array $argv): int
{
    SetupReport::title('LocalTour – cài database');

    try {
        $options = setup_args($argv, ['database', 'fresh', 'help']);
    } catch (InvalidArgumentException $exception) {
        SetupReport::error($exception->getMessage());
        SetupReport::info(INSTALL_USAGE);
        return 1;
    }
    if (isset($options['help'])) {
        SetupReport::info(INSTALL_USAGE);
        return 0;
    }

    if (!setup_load_env()) {
        SetupReport::error('Chưa có file src\\.env. Đứng ở thư mục src, chạy: copy .env.example .env rồi sửa DB_… nếu cần.');
        return 1;
    }

    $config = setup_db_config();
    $envDatabase = $config['database'];
    if (isset($options['database'])) {
        $config['database'] = trim((string) $options['database']);
    }
    $database = $config['database'];
    if (!setup_valid_database_name($database)) {
        SetupReport::error('Tên database "' . $database . '" không hợp lệ: chỉ dùng chữ không dấu, số và dấu gạch dưới.');
        return 1;
    }
    $fresh = isset($options['fresh']);

    $files = setup_sql_files();
    if ($files === []) {
        SetupReport::error('Không có file NN_*.sql nào trong ' . setup_display_path(SETUP_SRC . '/database') . '.');
        return 1;
    }
    foreach ($files as $file) {
        $switch = setup_database_switch($file);
        if ($switch !== null) {
            SetupReport::error(basename($file) . ' có câu "' . $switch . '": file sẽ ghi sang database khác. Bỏ câu này rồi chạy lại.');
            return 1;
        }
    }

    $binary = setup_find_mysql();
    if ($binary === null) {
        SetupReport::error(Core\Env::get('MYSQL_BIN') !== ''
            ? 'MYSQL_BIN = "' . Core\Env::get('MYSQL_BIN') . '" không phải file mysql.exe.'
            : 'Không tìm thấy mysql.exe (đã thử C:\\xampp\\mysql\\bin). Đặt đường dẫn, ví dụ: set MYSQL_BIN=D:\\xampp\\mysql\\bin\\mysql.exe');
        return 1;
    }
    SetupReport::ok('mysql: ' . $binary);

    try {
        $mysql = new SetupMysql($binary, $config);
    } catch (RuntimeException $exception) {
        SetupReport::error($exception->getMessage());
        return 1;
    }

    try {
        $rerun = 'scripts\\install_database.bat' . (isset($options['database']) ? ' --database=' . $database : '') . ' --fresh';
        return install_run($mysql, $config, $files, $fresh, $envDatabase, $rerun);
    } finally {
        $mysql->close();
    }
}

/**
 * @param array{host: string, port: int, database: string, username: string, password: string} $config
 * @param list<string> $files
 */
function install_run(SetupMysql $mysql, array $config, array $files, bool $fresh, string $envDatabase, string $rerun): int
{
    $database = $config['database'];
    $server = $config['host'] . ':' . $config['port'];

    try {
        $version = $mysql->query("SHOW VARIABLES LIKE 'version'")[0][1] ?? '?';
        $databases = array_map(static fn (array $row): string => strtolower($row[0]), $mysql->query('SHOW DATABASES'));
    } catch (SetupMysqlException $exception) {
        SetupReport::error('Không kết nối được MySQL tại ' . $server . ' (tài khoản ' . $config['username'] . '):' . PHP_EOL
            . $exception->getMessage() . PHP_EOL . install_connect_hint($exception->getCode()));
        return 1;
    }
    SetupReport::ok('Kết nối MySQL ' . $server . ' (tài khoản ' . $config['username'] . ', ' . $version . ')');

    try {
        $exists = in_array(strtolower($database), $databases, true);
        if ($exists) {
            $tables = count($mysql->query('SHOW FULL TABLES FROM `' . $database . '`'));
            $routines = count($mysql->query("SHOW PROCEDURE STATUS WHERE Db = '" . $database . "'"))
                + count($mysql->query("SHOW FUNCTION STATUS WHERE Db = '" . $database . "'"));

            if ($tables + $routines > 0 && !$fresh) {
                SetupReport::error(sprintf(
                    'Database %s đã có %d bảng và %d procedure, không cài đè.' . PHP_EOL
                    . 'Muốn xóa hết dữ liệu trong %s rồi cài lại từ đầu: thêm --fresh (đứng ở thư mục src)' . PHP_EOL
                    . '  %s',
                    $database,
                    $tables,
                    $routines,
                    $database,
                    $rerun
                ));
                return 1;
            }
            if ($tables + $routines > 0) {
                SetupReport::warn(sprintf('--fresh: xóa database %s trên %s (%d bảng, %d procedure) rồi cài lại.', $database, $server, $tables, $routines));
                if (!install_confirm_fresh($database)) {
                    SetupReport::error('Đã hủy, database không thay đổi.');
                    return 1;
                }
                $mysql->query('DROP DATABASE `' . $database . '`');
                $exists = false;
            }
        }

        if (!$exists) {
            $mysql->query('CREATE DATABASE `' . $database . '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
            SetupReport::ok('Tạo database ' . $database . ' (utf8mb4_unicode_ci)');
        } else {
            // Database trống có sẵn: đặt lại bảng mã để procedure nhận tiếng Việt đúng.
            $mysql->query('ALTER DATABASE `' . $database . '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
            SetupReport::ok('Dùng database trống ' . $database . ' (đặt bảng mã utf8mb4_unicode_ci)');
        }
    } catch (SetupMysqlException $exception) {
        SetupReport::error('Không chuẩn bị được database ' . $database . ':' . PHP_EOL . $exception->getMessage());
        return 1;
    }

    SetupReport::info(sprintf('Import %d file từ %s:', count($files), setup_display_path(SETUP_SRC . '/database')));
    foreach ($files as $file) {
        $started = microtime(true);
        try {
            $mysql->import($database, $file);
        } catch (SetupMysqlException $exception) {
            SetupReport::error(basename($file) . ':' . PHP_EOL . $exception->getMessage() . PHP_EOL
                . 'Database ' . $database . ' mới được cài một phần. Sửa lỗi rồi chạy lại: ' . $rerun);
            return 1;
        }
        SetupReport::ok(sprintf('%s (%s giây)', basename($file), number_format(microtime(true) - $started, 1, ',', '.')));
    }

    return install_verify($mysql, $database, $files, $envDatabase);
}

/** @param list<string> $files */
function install_verify(SetupMysql $mysql, string $database, array $files, string $envDatabase): int
{
    $expected = setup_expected_objects($files);
    try {
        $tables = array_map(static fn (array $row): string => strtolower($row[0]),
            $mysql->query("SHOW FULL TABLES FROM `" . $database . "` WHERE Table_type = 'BASE TABLE'"));
        $procedures = array_map(static fn (array $row): string => strtolower($row[1]),
            $mysql->query("SHOW PROCEDURE STATUS WHERE Db = '" . $database . "'"));
    } catch (SetupMysqlException $exception) {
        SetupReport::error('Không đếm được bảng / procedure:' . PHP_EOL . $exception->getMessage());
        return 1;
    }

    $missingTables = array_diff_key($expected['tables'], array_flip($tables));
    $missingProcedures = array_diff_key($expected['procedures'], array_flip($procedures));
    if ($missingTables !== [] || $missingProcedures !== []) {
        SetupReport::error(sprintf('Database %s có %d bảng, %d procedure nhưng còn thiếu:', $database, count($tables), count($procedures))
            . ($missingTables === [] ? '' : PHP_EOL . 'Bảng: ' . setup_name_list($missingTables))
            . ($missingProcedures === [] ? '' : PHP_EOL . 'Procedure: ' . setup_name_list($missingProcedures)));
        return 1;
    }

    SetupReport::ok(sprintf(
        'Database %s: %d bảng, %d procedure (đủ như các file %s → %s).',
        $database,
        count($tables),
        count($procedures),
        basename($files[0]),
        basename($files[count($files) - 1])
    ));
    if (strcasecmp($database, $envDatabase) !== 0) {
        SetupReport::warn('Ứng dụng đang dùng DB_DATABASE=' . $envDatabase . ' trong .env. Muốn chạy web với ' . $database . ' thì sửa dòng đó.');
    }
    SetupReport::info('Bước tiếp theo (đứng ở thư mục src):' . PHP_EOL
        . '  C:\\xampp\\php\\php.exe scripts\\create_admin.php --email=admin@localtour.test --generate' . PHP_EOL
        . '  C:\\xampp\\php\\php.exe scripts\\check_install.php');

    return 0;
}

/** Hỏi lại trước khi xóa database (chỉ khi đang chạy trong cửa sổ dòng lệnh). */
function install_confirm_fresh(string $database): bool
{
    if (!stream_isatty(STDIN)) {
        return true;
    }

    fwrite(STDOUT, '          Gõ tên database (' . $database . ') rồi Enter để xóa và cài lại, Enter để thoát: ');
    $answer = fgets(STDIN);

    return $answer !== false && trim($answer) === $database;
}

function install_connect_hint(int $code): string
{
    return match ($code) {
        1045 => 'Sai DB_USERNAME / DB_PASSWORD trong .env (XAMPP mặc định: root, mật khẩu trống).',
        2002, 2003, 2005 => 'MySQL chưa chạy hoặc sai DB_HOST / DB_PORT: mở XAMPP Control Panel, Start MySQL.',
        default => 'Kiểm tra MySQL đang chạy và các dòng DB_… trong .env.',
    };
}
