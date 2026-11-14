<?php

declare(strict_types=1);

namespace App\Controllers;

/**
 * Khu đơn vị tổ chức: thêm tour và sửa thông tin tour của chính đơn vị (/host/tours/new, /host/tours/{id}/edit).
 * Dùng lại form và kiểm tra của AdminTourFormController; khác biệt của khu /host nằm ở AdminController
 * (PORTAL = 'host': chỉ tài khoản đơn vị tổ chức đang hợp tác, chỉ tour của chính đơn vị).
 */
final class HostTourFormController extends AdminTourFormController
{
    protected const PORTAL = 'host';
}
