<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminStatsModel;
use DateTimeImmutable;

/**
 * Trang "Tổng quan" của quản trị viên (FR-19 → FR-23, Nguyễn Minh Thức).
 * Bộ lọc GET: period = day | month | year, from / to = Y-m-d.
 * Mặc định: theo ngày = 30 ngày gần nhất, theo tháng = 12 tháng gần nhất, theo năm = toàn bộ.
 * Mỗi kỳ doanh thu mở được danh sách khoản thanh toán của kỳ đó (/admin/revenue), để đối chiếu giao dịch nguồn.
 */
final class AdminDashboardController extends AdminController
{
    public const PERIODS = ['day' => 'Theo ngày', 'month' => 'Theo tháng', 'year' => 'Theo năm'];

    private AdminStatsModel $stats;

    public function __construct()
    {
        parent::__construct();
        $this->stats = new AdminStatsModel();
    }

    /** GET /admin */
    public function index(): void
    {
        $period = $this->query('period');
        if (!isset(self::PERIODS[$period])) {
            $period = 'month';
        }

        // Ô ngày để trống hoặc sai định dạng → dùng khoảng mặc định của kiểu thống kê.
        [$defaultFrom, $defaultTo] = self::defaultRange($period);
        $from = self::parseDate($this->query('from')) ?? $defaultFrom;
        $to = self::parseDate($this->query('to')) ?? $defaultTo;
        if ($from !== null && $to !== null && $from > $to) {
            [$from, $to] = [$to, $from];
        }

        $this->render('admin/dashboard', [
            'title' => 'Tổng quan',
            'adminNav' => 'dashboard',
            'summary' => $this->stats->summary(),
            'byStatus' => $this->stats->bookingsByStatus(),
            'byTime' => self::withLabels($this->stats->bookingsByTime($period, $from, $to), $period),
            'revenue' => self::withRanges(self::withLabels($this->stats->revenue($period, $from, $to), $period), $period, $from, $to),
            'period' => $period,
            'from' => $from,
            'to' => $to,
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** GET /admin/revenue?from=&to= – các khoản thanh toán của một kỳ doanh thu (đối chiếu giao dịch nguồn, FR-23). */
    public function revenuePayments(): void
    {
        $from = self::parseDate($this->query('from'));
        $to = self::parseDate($this->query('to'));
        if ($from !== null && $to !== null && $from > $to) {
            [$from, $to] = [$to, $from];
        }

        $this->render('admin/revenue', [
            'title' => 'Khoản thanh toán theo kỳ',
            'adminNav' => 'dashboard',
            'payments' => $this->stats->revenuePayments($from, $to),
            'from' => $from,
            'to' => $to,
            'pageStyles' => ['css/admin.css'],
        ]);
    }

    /** @return array{0: ?string, 1: ?string} */
    private static function defaultRange(string $period): array
    {
        $today = new DateTimeImmutable('today');

        return match ($period) {
            'day' => [$today->modify('-29 days')->format('Y-m-d'), $today->format('Y-m-d')],
            'month' => [$today->modify('first day of -11 months')->format('Y-m-d'), $today->format('Y-m-d')],
            default => [null, null],
        };
    }

    /** "2026-10-25" → "2026-10-25"; ngày sai (2026-02-30, 25/10/2026...) → null. */
    private static function parseDate(string $value): ?string
    {
        $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);

        return $date !== false && $date->format('Y-m-d') === $value ? $value : null;
    }

    /**
     * Thêm nhãn kỳ: "25/10/2026", "Tháng 10/2026", "Năm 2026".
     *
     * @param list<array<string, mixed>> $rows
     * @return list<array<string, mixed>>
     */
    private static function withLabels(array $rows, string $period): array
    {
        return array_map(static function (array $row) use ($period): array {
            $key = (string) $row['period_key'];
            $row['label'] = match ($period) {
                'day' => format_date($key),
                'month' => 'Tháng ' . substr($key, 5, 2) . '/' . substr($key, 0, 4),
                default => 'Năm ' . $key,
            };

            return $row;
        }, $rows);
    }

    /**
     * Thêm khoảng ngày của từng kỳ (range_from, range_to: 'Y-m-d'), cắt theo khoảng lọc của trang, để mở danh sách
     * khoản thanh toán của kỳ.
     *
     * @param list<array<string, mixed>> $rows
     * @return list<array<string, mixed>>
     */
    private static function withRanges(array $rows, string $period, ?string $from, ?string $to): array
    {
        return array_map(static function (array $row) use ($period, $from, $to): array {
            $key = (string) $row['period_key'];
            [$start, $end] = match ($period) {
                'day' => [$key, $key],
                'month' => [$key . '-01', (new DateTimeImmutable($key . '-01'))->format('Y-m-t')],
                default => [$key . '-01-01', $key . '-12-31'],
            };
            $row['range_from'] = $from !== null && $from > $start ? $from : $start;
            $row['range_to'] = $to !== null && $to < $end ? $to : $end;

            return $row;
        }, $rows);
    }
}
