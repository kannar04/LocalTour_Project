<?php

declare(strict_types=1);

namespace App\Controllers;

/**
 * Khu đơn vị tổ chức: ảnh, lịch trình, dịch vụ bao gồm / không bao gồm và chính sách hủy của tour của chính đơn vị
 * (/host/tours/{id}/content...). Dùng lại AdminTourContentController với PORTAL = 'host'; xóa / hiển thị lại tour
 * không có ở khu này (chỉ quản trị viên).
 */
final class HostTourContentController extends AdminTourContentController
{
    protected const PORTAL = 'host';
}
