<?php

declare(strict_types=1);

namespace Core;

use RuntimeException;

/**
 * Không kết nối được MySQL (sai .env, máy chủ tắt, mất VPN...).
 * Front controller trả HTTP 503 cho lỗi này thay vì 500.
 */
final class DatabaseException extends RuntimeException
{
}
