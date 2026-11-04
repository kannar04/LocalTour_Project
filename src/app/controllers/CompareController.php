<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\CompareModel;
use Core\Controller;

/**
 * So sánh 2 – 3 tour (US04-S5-03, FR-15 – Lê Trung Phong): trang /compare và endpoint JSON tương ứng.
 * Danh sách tour do trình duyệt lưu (compare.js) và gửi qua ?ids=<mã 1>,<mã 2>,<mã 3>; không cần đăng nhập.
 * Quá 3 tour: trang chỉ hiển thị 3 tour đầu và báo cho khách, API trả lỗi 422. Mã sai dạng, trùng, tour không còn
 * hiển thị bị bỏ qua. Dữ liệu thiếu hiện "Chưa cập nhật" (CompareModel).
 */
final class CompareController extends Controller
{
    private const IDS_MAX_LENGTH = 400;

    private CompareModel $compare;

    public function __construct()
    {
        $this->compare = new CompareModel();
    }

    /** GET /compare?ids= */
    public function index(): void
    {
        [$ids, $skipped] = $this->requestedIds();
        $tooMany = count($ids) > CompareModel::MAX_TOURS;
        $ids = array_slice($ids, 0, CompareModel::MAX_TOURS);

        $tours = $this->compare->tours($ids);
        $hidden = count($ids) - count($tours);

        $notices = [];
        if ($tooMany) {
            $notices[] = 'Chỉ so sánh tối đa ' . CompareModel::MAX_TOURS . ' tour. Trang đang hiển thị 3 tour đầu tiên bạn chọn.';
        }
        if ($hidden > 0 || $skipped > 0) {
            $notices[] = ($hidden + $skipped) . ' tour không còn hiển thị hoặc không hợp lệ nên đã được bỏ khỏi so sánh.';
        }

        $headers = $this->compare->headers($tours);

        $this->render('tours/compare', [
            'title' => 'So sánh tour',
            'headers' => $headers,
            'rows' => count($tours) >= CompareModel::MIN_TOURS ? $this->compare->rows($tours) : [],
            'notices' => $notices,
            'requested' => $this->query('ids') !== '',
            'activeNav' => 'compare',
            'pageStyles' => ['css/tour-detail.css', 'css/compare.css'],
            'pageScripts' => ['js/compare.js'],
        ]);
    }

    /** GET /api/compare?ids= */
    public function apiIndex(): void
    {
        [$ids] = $this->requestedIds();
        if (count($ids) > CompareModel::MAX_TOURS) {
            $this->json(false, 'Chỉ so sánh tối đa ' . CompareModel::MAX_TOURS . ' tour.', ['max' => CompareModel::MAX_TOURS], 422);
        }
        if (count($ids) < CompareModel::MIN_TOURS) {
            $this->json(false, 'Chọn ít nhất ' . CompareModel::MIN_TOURS . ' tour để so sánh.', ['min' => CompareModel::MIN_TOURS], 422);
        }

        $tours = $this->compare->tours($ids);
        $this->json(true, '', [
            'tours' => $this->compare->headers($tours),
            'rows' => $this->compare->rows($tours),
            'skipped' => count($ids) - count($tours),
        ]);
    }

    /**
     * Mã tour hợp lệ theo thứ tự, không trùng, và số phần tử bị bỏ (sai dạng / trùng).
     *
     * @return array{0: list<string>, 1: int}
     */
    private function requestedIds(): array
    {
        $raw = substr($this->query('ids'), 0, self::IDS_MAX_LENGTH);
        $ids = [];
        $skipped = 0;
        foreach (explode(',', $raw) as $part) {
            $part = trim($part);
            if ($part === '') {
                continue;
            }
            $id = self::parseUuid($part);
            if ($id === null || isset($ids[$id])) {
                $skipped++;
                continue;
            }
            $ids[$id] = true;
        }

        return [array_keys($ids), $skipped];
    }
}
