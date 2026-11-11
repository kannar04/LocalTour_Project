<?php

declare(strict_types=1);

use Core\Env;

/*
 * Bản đồ và địa điểm quanh điểm khởi hành (Nguyễn Tuấn Khôi).
 * Nền bản đồ: OpenStreetMap (trình duyệt tải ô bản đồ, Leaflet 1.9.4). Địa điểm: Overpass API, chỉ gọi từ máy chủ,
 * kết quả lưu ở bảng map_place_cache 7 ngày. Không cần khóa API.
 * OVERPASS_URL (không bắt buộc, chỉ để thử nghiệm): một hoặc nhiều địa chỉ interpreter cách nhau bằng dấu phẩy,
 * thay cho danh sách mặc định. Máy chủ đầu là chính, các máy sau là dự phòng.
 * Mặc định overpass.openstreetmap.fr đứng trước: từ mạng ở Việt Nam overpass-api.de và overpass.private.coffee
 * hay bị chặn (kết nối được nhưng không nhận dữ liệu), nên chỉ dùng overpass-api.de làm dự phòng.
 */
$overpassUrls = array_values(array_filter(
    array_map('trim', explode(',', Env::get('OVERPASS_URL'))),
    static fn (string $url): bool => preg_match('~^https?://\S+$~i', $url) === 1
));

return [
    'overpass_urls' => $overpassUrls !== [] ? array_slice($overpassUrls, 0, 2) : [
        'https://overpass.openstreetmap.fr/api/interpreter',
        'https://overpass-api.de/api/interpreter',
    ],
    'user_agent' => 'LocalTour-school-demo/1.0',
    // Giây chờ kết nối mỗi máy chủ / tổng thời gian cho cả máy chính và máy dự phòng.
    'connect_timeout' => 6,
    'timeout' => 20,
    // Bán kính tìm quanh điểm khởi hành (mét) và số địa điểm tối đa mỗi nhóm.
    'radius_m' => 1500,
    'per_group' => 25,
    // Kết quả dùng lại trong 7 ngày; tải lỗi thì 10 phút sau mới thử lại (trong lúc đó dùng kết quả cũ nếu có).
    'cache_ttl' => 7 * 24 * 3600,
    'retry_after' => 600,
];
