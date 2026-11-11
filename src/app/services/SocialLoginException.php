<?php

declare(strict_types=1);

namespace App\Services;

use RuntimeException;

/**
 * Lỗi khi đăng nhập bằng Google / Facebook (Nguyễn Tuấn Khôi).
 * reason: 'network' (không kết nối được / quá thời gian chờ), 'token' (đổi mã lấy token thất bại),
 * 'profile' (không đọc được thông tin tài khoản), 'config' (thiếu cấu hình địa chỉ trả về).
 * Message chỉ để ghi log (không chứa khóa bí mật), không hiện cho khách.
 */
final class SocialLoginException extends RuntimeException
{
    public function __construct(private readonly string $reason, string $message)
    {
        parent::__construct($message);
    }

    public function reason(): string
    {
        return $this->reason;
    }
}
