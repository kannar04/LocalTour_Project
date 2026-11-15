<?php

declare(strict_types=1);

namespace App\Models;

use Core\Database;

/**
 * Thích, Lưu tour và "Tour đã lưu" (CR3 – Nguyễn Minh Thức).
 * Procedure: NMT_sp_tour_social_state, NMT_sp_tour_like_toggle, NMT_sp_tour_save_toggle,
 *            NMT_sp_saved_tour_list (file 34).
 */
final class TourSocialModel
{
    /** Số mã tour tối đa trong một lần lấy số tương tác (một trang danh sách). */
    public const MAX_IDS = 60;

    /**
     * Số lượt thích, số bình luận đang hiển thị, đã thích / đã lưu của từng tour đang hiển thị.
     *
     * @param list<string> $tourIds UUID chữ thường, không trùng, tối đa MAX_IDS.
     * @return array<string, array{like_count: int, comment_count: int, liked: bool, saved: bool}> Theo mã tour.
     */
    public function states(?string $userId, array $tourIds): array
    {
        $tourIds = array_slice(array_values($tourIds), 0, self::MAX_IDS);
        if ($tourIds === []) {
            return [];
        }

        $states = [];
        foreach (Database::call('NMT_sp_tour_social_state', [$userId, implode(',', $tourIds)]) as $row) {
            $states[(string) $row['tour_id']] = [
                'like_count' => (int) $row['like_count'],
                'comment_count' => (int) $row['comment_count'],
                'liked' => (int) $row['liked'] === 1,
                'saved' => (int) $row['saved'] === 1,
            ];
        }

        return $states;
    }

    /**
     * Thích (true) / bỏ thích (false) / đảo trạng thái (null).
     *
     * @return array{result: string, liked: bool, like_count: int} result: ok | forbidden | not_found
     */
    public function like(string $userId, string $tourId, ?bool $want): array
    {
        $row = Database::call('NMT_sp_tour_like_toggle', [$userId, $tourId, $want === null ? null : (int) $want])[0] ?? [];

        return [
            'result' => (string) ($row['result'] ?? 'not_found'),
            'liked' => (int) ($row['liked'] ?? 0) === 1,
            'like_count' => (int) ($row['like_count'] ?? 0),
        ];
    }

    /**
     * Lưu (true) / bỏ lưu (false) / đảo trạng thái (null).
     *
     * @return array{result: string, saved: bool} result: ok | forbidden | not_found
     */
    public function save(string $userId, string $tourId, ?bool $want): array
    {
        $row = Database::call('NMT_sp_tour_save_toggle', [$userId, $tourId, $want === null ? null : (int) $want])[0] ?? [];

        return [
            'result' => (string) ($row['result'] ?? 'not_found'),
            'saved' => (int) ($row['saved'] ?? 0) === 1,
        ];
    }

    /**
     * "Tour đã lưu", lưu gần nhất trước (gồm cả tour đã ngừng hiển thị: is_visible = 0).
     *
     * @return list<array<string, mixed>>
     */
    public function savedTours(string $userId): array
    {
        return Database::call('NMT_sp_saved_tour_list', [$userId]);
    }
}
