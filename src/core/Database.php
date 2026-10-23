<?php

declare(strict_types=1);

namespace Core;

use InvalidArgumentException;
use PDO;
use PDOException;

/**
 * Kết nối PDO dùng chung và hàm gọi stored procedure.
 * Ứng dụng chỉ truy cập dữ liệu qua CALL <procedure>(?, ...), không viết SELECT/INSERT/UPDATE/DELETE trong PHP.
 */
final class Database
{
    /** Tên procedure hợp lệ: tiền tố người phụ trách + sp_ + tên chữ thường. */
    private const PROCEDURE_PATTERN = '/^(NTK|LTP|NMT)_sp_[a-z0-9_]+$/';

    private static ?PDO $connection = null;

    public static function connection(): PDO
    {
        if (self::$connection instanceof PDO) {
            return self::$connection;
        }

        $config = require BASE_PATH . '/config/database.php';
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $config['host'],
            $config['port'],
            $config['database'],
            $config['charset']
        );

        try {
            self::$connection = new PDO($dsn, $config['username'], $config['password'], [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_TIMEOUT => $config['timeout'],
            ]);
        } catch (PDOException $exception) {
            throw new DatabaseException('Không thể kết nối cơ sở dữ liệu LocalTour.', 0, $exception);
        }

        return self::$connection;
    }

    /**
     * Gọi một stored procedure có tham số và trả về result set đầu tiên.
     *
     * @param list<int|string|null> $params
     * @return list<array<string, mixed>>
     */
    public static function call(string $procedure, array $params = []): array
    {
        if (!preg_match(self::PROCEDURE_PATTERN, $procedure)) {
            throw new InvalidArgumentException('Tên stored procedure không hợp lệ: ' . $procedure);
        }

        $placeholders = implode(', ', array_fill(0, count($params), '?'));
        $statement = self::connection()->prepare(sprintf('CALL %s(%s)', $procedure, $placeholders));

        foreach (array_values($params) as $index => $value) {
            $type = match (true) {
                $value === null => PDO::PARAM_NULL,
                is_int($value) => PDO::PARAM_INT,
                default => PDO::PARAM_STR,
            };
            $statement->bindValue($index + 1, $value, $type);
        }

        $statement->execute();
        $rows = $statement->fetchAll();
        // CALL luôn trả thêm một result set trạng thái; đóng cursor để lệnh CALL kế tiếp chạy được.
        $statement->closeCursor();

        return $rows;
    }
}
