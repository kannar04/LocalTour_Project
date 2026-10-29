<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\CustomerBookingModel;
use Core\Auth;
use Core\Controller;
use Core\Router;

/**
 * Voucher của đơn (Sprint 4, 4.5.4.2 – Lê Trung Phong): chỉ xuất khi đơn đã xác nhận nhờ thanh toán đã xác minh
 * (VNPay thành công hoặc quản trị viên đã đối chiếu chuyển khoản). Mã voucher do LTP_sp_voucher_issue cấp.
 * Trang in được (Ctrl+P) để khách mang theo hoặc đưa cho hướng dẫn viên.
 */
final class VoucherController extends Controller
{
    /** GET /bookings/{code}/voucher */
    public function show(string $code): void
    {
        header('Cache-Control: no-store');
        $user = Auth::user();
        if ($user === null) {
            $uri = $_SERVER['REQUEST_URI'] ?? '/bookings';
            $this->redirect('/login?next=' . rawurlencode(Router::pathFromUri($uri)));
        }
        if ($user['role'] !== 'customer') {
            $this->redirect('/bookings');
        }

        $bookings = new CustomerBookingModel();
        $code = strtoupper(trim($code));
        $booking = preg_match(CustomerBookingModel::CODE_PATTERN, $code) ? $bookings->find($user['user_id'], $code) : null;
        if ($booking === null) {
            $this->redirect('/bookings/' . rawurlencode($code));
        }
        if ($booking['voucher_code'] === null || !in_array($booking['status'], ['confirmed', 'completed'], true)) {
            $this->redirect('/bookings/' . $booking['code']);
        }

        $this->render('vouchers/show', [
            'title' => 'Voucher ' . $booking['voucher_code'],
            'activeNav' => 'bookings',
            'booking' => $booking,
            'lines' => $bookings->lines($user['user_id'], $code),
            'extras' => $bookings->extras($user['user_id'], $code),
            'passengers' => $bookings->passengers($user['user_id'], $code),
            'pageStyles' => ['css/tour-detail.css', 'css/booking.css'],
        ]);
    }
}
