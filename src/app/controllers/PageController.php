<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\SettingModel;
use Core\Controller;

/**
 * Trang thông tin chung (CR2 – Nguyễn Tuấn Khôi): "Trợ giúp" (GET /tro-giup, câu hỏi thường gặp) và
 * "Điều khoản sử dụng" (GET /dieu-khoan). Khách chưa đăng nhập và mọi vai trò đều xem được.
 * Thời gian giữ chỗ, hạn nhận đặt, hạn nhận chuyển khoản VietQR và % phí dịch vụ lấy từ "Thông số vận hành"
 * (SettingModel, NTK_sp_setting_list); thiếu dòng thì dùng giá trị mặc định như các procedure.
 */
final class PageController extends Controller
{
    /** GET /tro-giup */
    public function help(): void
    {
        $this->render('pages/help', [
            'title' => 'Trợ giúp',
            'rules' => $this->rules(),
            'activeNav' => 'help',
            'pageStyles' => ['css/pages.css'],
        ]);
    }

    /** GET /dieu-khoan */
    public function terms(): void
    {
        $this->render('pages/terms', [
            'title' => 'Điều khoản sử dụng',
            'rules' => $this->rules(),
            'activeNav' => 'terms',
            'pageStyles' => ['css/pages.css'],
        ]);
    }

    /**
     * Thông số đang áp dụng, đã định dạng để in thẳng ra trang.
     *
     * @return array{hold_minutes: string, booking_cutoff_minutes: string, vietqr_cutoff_hours: string, commission_percent: string}
     */
    private function rules(): array
    {
        $saved = (new SettingModel())->all();
        $value = static fn (string $name): string => trim((string) ($saved[$name]['value'] ?? SettingModel::FIELDS[$name]['default']));

        return [
            'hold_minutes' => (string) (int) $value('hold_minutes'),
            'booking_cutoff_minutes' => (string) (int) $value('booking_cutoff_minutes'),
            'vietqr_cutoff_hours' => (string) (int) $value('vietqr_cutoff_hours'),
            'commission_percent' => self::percent($value('commission_percent')),
        ];
    }

    /** "10" -> "10", "12.50" -> "12,5" (dấu phẩy thập phân như trang "Thông số vận hành"). */
    private static function percent(string $raw): string
    {
        if (!is_numeric($raw)) {
            return SettingModel::FIELDS['commission_percent']['default'];
        }
        $text = rtrim(rtrim(number_format((float) $raw, 2, '.', ''), '0'), '.');

        return str_replace('.', ',', $text);
    }
}
