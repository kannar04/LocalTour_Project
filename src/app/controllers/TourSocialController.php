<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\TourSocialModel;
use Core\Auth;
use Core\Controller;

/**
 * Thích / Lưu tour / Chia sẻ và trang "Tour đã lưu" (CR2 – Nguyễn Minh Thức).
 * Mọi người (kể cả khách chưa đăng nhập) xem được số lượt thích và số bình luận; chỉ tài khoản khách hàng
 * thích / lưu được. Chia sẻ làm hoàn toàn ở trình duyệt (tour-social.js), không cần endpoint.
 *
 *   GET  /api/social/tours?ids=<mã>,<mã>  số tương tác của tối đa 60 tour (thẻ tour, trang chi tiết)
 *   POST /api/tours/{id}/like             liked = 1 | 0 (trống = đảo trạng thái), _csrf, next
 *   POST /api/tours/{id}/save             saved = 1 | 0 (trống = đảo trạng thái), _csrf, next
 *   GET  /tour-da-luu                     "Tour đã lưu" của tài khoản khách hàng
 *
 * Khách chưa đăng nhập bấm Thích / Lưu: JSON 401 kèm login_url (đăng nhập xong quay lại trang đang xem,
 * theo trường next). Tài khoản quản trị viên / đơn vị tổ chức: 403.
 */
final class TourSocialController extends Controller
{
    private const CSRF_FAILED = 'Phiên làm việc đã hết hạn, vui lòng tải lại trang rồi thử lại.';
    private const NOT_FOUND = 'Không tìm thấy tour hoặc tour đã ngừng hiển thị.';

    private TourSocialModel $social;

    public function __construct()
    {
        $this->social = new TourSocialModel();
    }

    /** GET /api/social/tours?ids= */
    public function apiState(): void
    {
        $raw = $this->query('ids');
        // 60 mã UUID 36 ký tự + dấu phẩy: chuỗi dài hơn chắc chắn vượt giới hạn.
        if (strlen($raw) > TourSocialModel::MAX_IDS * 40) {
            $this->json(false, 'Mỗi lần chỉ lấy được tối đa ' . TourSocialModel::MAX_IDS . ' tour.', null, 400);
        }

        $ids = [];
        foreach (explode(',', $raw) as $part) {
            $part = trim($part);
            if ($part === '') {
                continue;
            }
            $id = self::parseUuid($part);
            if ($id === null) {
                $this->json(false, 'Mã tour không hợp lệ.', null, 400);
            }
            $ids[$id] = true;
        }
        if ($ids === []) {
            $this->json(false, 'Thiếu mã tour.', null, 400);
        }
        if (count($ids) > TourSocialModel::MAX_IDS) {
            $this->json(false, 'Mỗi lần chỉ lấy được tối đa ' . TourSocialModel::MAX_IDS . ' tour.', null, 400);
        }

        $user = Auth::user();
        $viewer = $user === null ? 'guest' : ($user['role'] === 'customer' ? 'customer' : 'other');
        $states = $this->social->states($viewer === 'customer' ? $user['user_id'] : null, array_keys($ids));

        // (object): không có tour nào vẫn trả {} chứ không phải [].
        $this->json(true, '', ['viewer' => $viewer, 'tours' => (object) $states]);
    }

    /** POST /api/tours/{id}/like */
    public function like(string $id): void
    {
        $user = $this->interactingCustomer('thích');
        $tourId = self::parseUuid($id) ?? $this->json(false, self::NOT_FOUND, null, 404);

        $row = $this->social->like($user['user_id'], $tourId, $this->wanted('liked'));
        $this->failOnResult($row['result'], 'thích');

        $this->json(true, $row['liked'] ? 'Đã thích tour.' : 'Đã bỏ thích tour.', [
            'tour_id' => $tourId,
            'liked' => $row['liked'],
            'like_count' => $row['like_count'],
        ]);
    }

    /** POST /api/tours/{id}/save */
    public function save(string $id): void
    {
        $user = $this->interactingCustomer('lưu');
        $tourId = self::parseUuid($id) ?? $this->json(false, self::NOT_FOUND, null, 404);

        $row = $this->social->save($user['user_id'], $tourId, $this->wanted('saved'));
        $this->failOnResult($row['result'], 'lưu');

        $this->json(true, $row['saved'] ? 'Đã lưu tour. Xem lại ở "Tour đã lưu".' : 'Đã bỏ lưu tour.', [
            'tour_id' => $tourId,
            'saved' => $row['saved'],
        ]);
    }

    /** GET /tour-da-luu */
    public function saved(): void
    {
        // Trang có dữ liệu của tài khoản: trình duyệt không được lưu cache.
        header('Cache-Control: no-store');

        $user = Auth::user();
        if ($user === null) {
            $this->redirect('/login?next=' . rawurlencode('/tour-da-luu'));
        }
        if ($user['role'] !== 'customer') {
            $this->render('bookings/message', [
                'title' => 'Tour đã lưu',
                'activeNav' => 'saved',
                'errorCode' => 'Lỗi 403',
                'heading' => 'Tài khoản này không lưu tour',
                'text' => '"Tour đã lưu" chỉ dành cho tài khoản khách hàng.',
                'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
            ], 403);
            return;
        }

        $tours = array_map([$this, 'presentSaved'], $this->social->savedTours($user['user_id']));

        $this->render('tours/saved', [
            'title' => 'Tour đã lưu',
            'activeNav' => 'saved',
            'tours' => $tours,
            'pageStyles' => ['css/tour-detail.css', 'css/tour-social.css'],
            'pageScripts' => ['js/tour-social.js'],
        ]);
    }

    /**
     * Tài khoản được thích / lưu tour; khách chưa đăng nhập, tài khoản khác hoặc sai mã CSRF thì trả lỗi JSON luôn.
     *
     * @return array{user_id: string, name: string, email: string, role: string}
     */
    private function interactingCustomer(string $verb): array
    {
        $user = Auth::user();
        if ($user === null) {
            $next = safe_next_path($this->input('next'));
            $this->json(false, 'Vui lòng đăng nhập để ' . $verb . ' tour.', [
                'login_url' => url('/login?next=' . rawurlencode($next)),
            ], 401);
        }
        if ($user['role'] !== 'customer') {
            $this->json(false, 'Chỉ tài khoản khách hàng mới ' . $verb . ' được tour.', null, 403);
        }
        if (!Auth::verifyCsrf($_POST['_csrf'] ?? null)) {
            $this->json(false, self::CSRF_FAILED, null, 403);
        }

        return $user;
    }

    /** Trường liked / saved: '1' = bật, '0' = tắt, trống = đảo trạng thái hiện tại. */
    private function wanted(string $field): ?bool
    {
        return match ($this->input($field)) {
            '' => null,
            '1' => true,
            '0' => false,
            default => $this->json(false, 'Yêu cầu không hợp lệ.', null, 400),
        };
    }

    private function failOnResult(string $result, string $verb): void
    {
        if ($result === 'forbidden') {
            $this->json(false, 'Tài khoản của bạn hiện không ' . $verb . ' được tour.', null, 403);
        }
        if ($result !== 'ok') {
            $this->json(false, self::NOT_FOUND, null, 404);
        }
    }

    /**
     * Một tour trên trang "Tour đã lưu": giá trị gốc kèm chuỗi đã định dạng.
     *
     * @param array<string, mixed> $row
     * @return array<string, mixed>
     */
    private function presentSaved(array $row): array
    {
        $tourId = (string) $row['tour_id'];
        $price = $row['from_price_vnd'] === null ? null : (int) $row['from_price_vnd'];
        $nextStartsAt = $row['next_starts_at'] === null ? null : (string) $row['next_starts_at'];
        $cover = $row['cover_image_url'] === null ? '' : trim((string) $row['cover_image_url']);
        $place = array_filter([(string) $row['destination_name'], (string) ($row['category_name'] ?? '')], static fn (string $part): bool => $part !== '');

        return [
            'tour_id' => $tourId,
            'title' => (string) $row['title'],
            'url' => url('/tours/' . $tourId),
            'place_text' => implode(' · ', $place),
            'provider_name' => (string) $row['provider_name'],
            'duration_text' => format_duration($row['duration_minutes']),
            'languages_text' => format_languages($row['language_codes']),
            'departure_text' => departure_text($row['pickup_mode'], $row['meeting_point']),
            'is_hotel_pickup' => $row['pickup_mode'] === 'hotel_pickup',
            'price_text' => $price === null ? null : format_vnd($price),
            'next_departure_text' => $nextStartsAt === null ? null : format_date($nextStartsAt) . ' · ' . format_time($nextStartsAt),
            'rating_text' => format_rating($row['rating_avg']),
            'review_count' => (int) $row['review_count'],
            'like_count' => (int) $row['like_count'],
            'cover_url' => $cover === '' ? null : image_src($cover),
            'cover_alt' => trim((string) $row['cover_alt_text']) !== '' ? (string) $row['cover_alt_text'] : (string) $row['title'],
            'is_visible' => (int) $row['is_visible'] === 1,
            'bookable' => (int) $row['bookable'] === 1,
            'saved_text' => format_date((string) $row['saved_at']),
        ];
    }
}
