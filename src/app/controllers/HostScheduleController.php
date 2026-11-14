<?php

declare(strict_types=1);

namespace App\Controllers;

/**
 * Khu đơn vị tổ chức: lịch khởi hành, sức chứa và giá vé của tour của chính đơn vị
 * (/host/tours/{id}/schedules, /host/schedules/{id}/edit). Dùng lại AdminScheduleController với PORTAL = 'host'.
 */
final class HostScheduleController extends AdminScheduleController
{
    protected const PORTAL = 'host';
}
