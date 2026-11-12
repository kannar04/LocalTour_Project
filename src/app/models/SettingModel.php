<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;
use DateTimeImmutable;

/**
 * Thông số vận hành quản trị viên chỉnh được (Nguyễn Tuấn Khôi): % phí dịch vụ LocalTour, thời gian giữ chỗ, hạn nhận
 * đặt trước giờ khởi hành, hạn nhận chuyển khoản VietQR; mốc bắt đầu lập khoản chi trả (chỉ đọc). Procedure: NTK_sp_setting_list, NTK_sp_admin_setting_save (file 30).
 */
final class SettingModel
{
    /** Tên thông số → nhãn, đơn vị, giải thích một dòng, giá trị nhỏ nhất / lớn nhất, giá trị mặc định (procedure dùng khi thiếu dòng). */
    public const FIELDS = [
        'commission_percent' => [
            'label' => 'Phí dịch vụ LocalTour',
            'unit' => '%',
            'hint' => 'Phần trăm LocalTour giữ lại trên tiền thực thu của mỗi đơn. Chỉ áp dụng cho đơn đặt sau khi lưu; đơn cũ giữ mức đã chụp lúc đặt.',
            'min' => 0,
            'max' => 100,
            'default' => '10',
        ],
        'hold_minutes' => [
            'label' => 'Thời gian giữ chỗ',
            'unit' => 'phút',
            'hint' => 'Đơn “Chờ thanh toán” được giữ chỗ bấy nhiêu phút; quá hạn chưa thanh toán thì đơn tự hủy và trả chỗ.',
            'min' => 5,
            'max' => 1440,
            'default' => '30',
        ],
        'booking_cutoff_minutes' => [
            'label' => 'Ngừng nhận đặt trước giờ khởi hành',
            'unit' => 'phút',
            'hint' => 'Còn ít hơn bấy nhiêu phút tới giờ khởi hành thì lịch không nhận đơn mới. 0 = nhận tới giờ khởi hành.',
            'min' => 0,
            'max' => 1440,
            'default' => '60',
        ],
        'vietqr_cutoff_hours' => [
            'label' => 'Ngừng nhận chuyển khoản VietQR',
            'unit' => 'giờ',
            'hint' => 'Còn ít hơn bấy nhiêu giờ tới giờ khởi hành thì chỉ nhận VNPay / MoMo, không nhận chuyển khoản phải đối chiếu tay. 0 = luôn nhận.',
            'min' => 0,
            'max' => 168,
            'default' => '24',
        ],
    ];

    /**
     * Thông số đang lưu theo tên.
     *
     * @return array<string, array<string, mixed>> name => [name, value, updated_at, updated_by_name]
     */
    public function all(): array
    {
        return array_column(Database::call('NTK_sp_setting_list'), null, 'name');
    }

    /**
     * Mốc bắt đầu lập khoản chi trả (settings 'payouts_from', ghi lúc file 28 chạy lần đầu; không sửa ở form): chỉ lịch
     * kết thúc từ mốc này mới được lập khoản chi trả. null = thiếu dòng hoặc sai dạng (không có mốc).
     */
    public function payoutsFrom(): ?string
    {
        $value = (string) ($this->all()['payouts_from']['value'] ?? '');
        $date = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $value);

        return $date !== false && $date->format('Y-m-d H:i:s') === $value ? $value : null;
    }

    /**
     * Lưu 4 thông số. $commission dạng "10" hoặc "12.5" (dấu chấm).
     *
     * @return array{result: string, field: ?string} result: ok, unchanged, forbidden, invalid (field = thông số sai)
     */
    public function save(string $actorUserId, string $commission, int $holdMinutes, int $cutoffMinutes, int $vietqrHours): array
    {
        $row = Database::call('NTK_sp_admin_setting_save', [$actorUserId, $commission, $holdMinutes, $cutoffMinutes, $vietqrHours])[0] ?? [];

        return ['result' => (string) ($row['result'] ?? 'invalid'), 'field' => isset($row['field']) ? (string) $row['field'] : null];
    }
}
