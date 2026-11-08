<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Dữ liệu so sánh 2 – 3 tour (US04-S5-02, FR-15 – Nguyễn Minh Thức).
 * Procedure: NMT_sp_tour_compare (file 17).
 *
 * Chuẩn hóa để đặt cạnh nhau: giá theo người lớn / trẻ em mỗi người, thời lượng theo giờ phút, quy mô theo số khách,
 * chính sách hủy theo giờ và phần trăm. Ô thiếu dữ liệu hiện "Chưa cập nhật" (không tự suy diễn).
 */
final class CompareModel
{
    public const MIN_TOURS = 2;
    public const MAX_TOURS = 3;
    public const MISSING = 'Chưa cập nhật';

    /**
     * Các tour đang hiển thị trong danh sách mã, theo đúng thứ tự khách chọn; tour không có / bị ẩn bị bỏ qua.
     *
     * @param list<string> $tourIds UUID chữ thường, không trùng, tối đa MAX_TOURS.
     * @return list<array<string, mixed>>
     */
    public function tours(array $tourIds): array
    {
        $tourIds = array_slice(array_values($tourIds), 0, self::MAX_TOURS);
        if ($tourIds === []) {
            return [];
        }

        return Database::call('NMT_sp_tour_compare', [implode(',', $tourIds)]);
    }

    /**
     * Phần đầu mỗi cột: tên, ảnh, nơi tổ chức và link chi tiết.
     *
     * @param list<array<string, mixed>> $tours
     * @return list<array{id: string, title: string, url: string, image: ?string, image_alt: string,
     *                    provider: string, destination: string, category: string}>
     */
    public function headers(array $tours): array
    {
        return array_map(static fn (array $tour): array => [
            'id' => (string) $tour['tour_id'],
            'title' => (string) $tour['title'],
            'url' => url('/tours/' . $tour['tour_id']),
            'image' => trim((string) $tour['cover_image_url']) === '' ? null : image_src((string) $tour['cover_image_url']),
            'image_alt' => trim((string) $tour['cover_alt_text']) !== '' ? (string) $tour['cover_alt_text'] : (string) $tour['title'],
            'provider' => or_missing($tour['provider_name']),
            'destination' => or_missing($tour['destination_name']),
            'category' => or_missing($tour['category_name']),
        ], $tours);
    }

    /**
     * Các dòng so sánh, chia nhóm. Mỗi ô: lines (các dòng chữ) và missing (true = "Chưa cập nhật").
     *
     * @param list<array<string, mixed>> $tours
     * @return list<array{group: string, rows: list<array{label: string, cells: list<array{lines: list<string>, missing: bool}>}>}>
     */
    public function rows(array $tours): array
    {
        $groups = [
            'Giá và lịch' => [
                'Giá người lớn' => static fn (array $t): array => self::adultPrice($t),
                'Giá trẻ em' => static fn (array $t): array => self::childPrice($t),
                'Gói tour' => static fn (array $t): array => (int) $t['package_count'] > 0
                    ? self::cell(explode(' · ', (string) $t['package_names']))
                    : self::cell(['Một gói chung']),
                'Lịch gần nhất' => static fn (array $t): array => $t['next_starts_at'] === null
                    ? self::cell(['Chưa có lịch mở bán'], true)
                    : self::cell([format_datetime((string) $t['next_starts_at']), (int) $t['schedule_count'] . ' lịch còn nhận đặt']),
            ],
            'Thông tin tour' => [
                'Thời lượng' => static fn (array $t): array => (int) $t['duration_minutes'] > 0
                    ? self::cell([format_duration($t['duration_minutes'])])
                    : self::missing(),
                'Quy mô nhóm' => static fn (array $t): array => (int) $t['max_group_size'] > 0
                    ? self::cell(['Tối đa ' . (int) $t['max_group_size'] . ' khách'])
                    : self::missing(),
                'Ngôn ngữ' => static fn (array $t): array => self::text(format_languages($t['language_codes'])),
                'Điểm khởi hành' => static fn (array $t): array => self::text(
                    $t['pickup_mode'] === 'hotel_pickup' ? 'Đón tại khách sạn' : (string) $t['meeting_point']
                ),
                'Điểm kết thúc' => static fn (array $t): array => self::text($t['dropoff_point']),
                'Phương tiện' => static fn (array $t): array => self::text($t['transport']),
                'Hướng dẫn viên' => static fn (array $t): array => self::text($t['guide_info']),
                'Ăn uống' => static fn (array $t): array => self::text($t['meal_terms']),
                'Đánh giá' => static fn (array $t): array => (int) $t['review_count'] > 0
                    ? self::cell([format_rating($t['rating_avg']) . ' / 5 (' . (int) $t['review_count'] . ' đánh giá)'])
                    : self::cell(['Chưa có đánh giá'], true),
            ],
            'Lịch trình và dịch vụ' => [
                'Lịch trình' => static fn (array $t): array => self::list($t['itinerary_items']),
                'Bao gồm' => static fn (array $t): array => self::list($t['included_items']),
                'Không bao gồm' => static fn (array $t): array => self::list($t['excluded_items']),
                'Phụ thu / tùy chọn' => static fn (array $t): array => $t['extras_items'] === null
                    ? self::cell(['Không có'])
                    : self::list($t['extras_items']),
            ],
            'Chính sách' => [
                'Hủy tour' => static fn (array $t): array => $t['policy_version'] === null
                    ? self::missing()
                    : self::cell(cancellation_policy_lines($t['free_before_hours'], $t['refund_percent'])),
                'Đổi lịch' => static fn (array $t): array => self::text($t['reschedule_terms']),
            ],
        ];

        $result = [];
        foreach ($groups as $group => $fields) {
            $rows = [];
            foreach ($fields as $label => $build) {
                $rows[] = ['label' => $label, 'cells' => array_map($build, $tours)];
            }
            $result[] = ['group' => $group, 'rows' => $rows];
        }

        return $result;
    }

    /** @param array<string, mixed> $tour */
    private static function adultPrice(array $tour): array
    {
        if ($tour['from_price_vnd'] === null) {
            return self::missing();
        }

        $prefix = (int) $tour['package_count'] > 1 ? 'Từ ' : '';

        return self::cell([$prefix . format_vnd($tour['from_price_vnd']) . ' / người lớn']);
    }

    /** @param array<string, mixed> $tour */
    private static function childPrice(array $tour): array
    {
        if ($tour['from_price_vnd'] === null) {
            return self::missing();
        }
        if ($tour['child_from_price_vnd'] === null) {
            return self::cell(['Không bán vé trẻ em']);
        }

        return self::cell([format_vnd($tour['child_from_price_vnd']) . ' / trẻ em']);
    }

    /** Văn bản một dòng; rỗng → "Chưa cập nhật". */
    private static function text(mixed $value): array
    {
        $value = trim((string) $value);

        return $value === '' ? self::missing() : self::cell([$value]);
    }

    /** Danh sách ngăn bởi xuống dòng (từ GROUP_CONCAT); rỗng → "Chưa cập nhật". */
    private static function list(mixed $value): array
    {
        $lines = text_lines($value === null ? null : (string) $value);

        return $lines === [] ? self::missing() : self::cell($lines);
    }

    /** @param list<string> $lines */
    private static function cell(array $lines, bool $missing = false): array
    {
        return ['lines' => $lines, 'missing' => $missing];
    }

    private static function missing(): array
    {
        return self::cell([self::MISSING], true);
    }
}
