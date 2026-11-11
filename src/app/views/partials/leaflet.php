<?php declare(strict_types=1); ?>
<?php
/*
 * Leaflet 1.9.4 từ CDN jsDelivr, khóa bằng mã SRI (Nguyễn Tuấn Khôi). Chỉ nạp ở trang có bản đồ:
 * chi tiết tour (tour có vị trí), /ban-do, trang quản trị "Điểm khởi hành trên bản đồ".
 * Script có defer: chạy xong trước sự kiện DOMContentLoaded, tour-map.js khởi tạo bản đồ trong $(function () {...}).
 * Không tải được Leaflet (mất mạng, CDN lỗi): tour-map.js bỏ qua bản đồ, danh sách địa điểm vẫn dùng được.
 */
?>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="anonymous">
<script src="https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin="anonymous" defer></script>
