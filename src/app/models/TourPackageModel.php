<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Gói tour đang bán của một tour (US06-S5-01, FR-07 – Lê Trung Phong): mỗi gói có giá người lớn / trẻ em riêng
 * (child_price_vnd null = gói không bán vé trẻ em). Tour có gói đang bán thì khách phải chọn một gói khi đặt.
 * Procedure: LTP_sp_tour_package_list (file 18).
 */
final class TourPackageModel
{
    /**
     * Gói đang bán của tour đang hiển thị, theo sort_order rồi giá; [] nếu tour không chia gói.
     *
     * @return list<array<string, mixed>> package_id, name, description, adult_price_vnd, child_price_vnd
     */
    public function list(string $tourId): array
    {
        return Database::call('LTP_sp_tour_package_list', [$tourId]);
    }

    /**
     * Dữ liệu cho JS (trang chi tiết và trang đặt tour).
     *
     * @param list<array<string, mixed>> $packages
     * @return list<array{id: string, name: string, description: string, adult: int, child: ?int}>
     */
    public static function options(array $packages): array
    {
        return array_map(static fn (array $package): array => [
            'id' => (string) $package['package_id'],
            'name' => (string) $package['name'],
            'description' => trim((string) $package['description']),
            'adult' => (int) $package['adult_price_vnd'],
            'child' => $package['child_price_vnd'] === null ? null : (int) $package['child_price_vnd'],
        ], $packages);
    }
}
