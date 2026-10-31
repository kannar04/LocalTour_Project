<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\BookingAvailabilityModel;
use Core\Controller;

/**
 * Kiểm tra lịch khởi hành và số chỗ trống (M4 mục 5 – Nguyễn Minh Thức).
 * Trang đặt tour gọi endpoint này trước bước "Xem lại & xác nhận". Kết quả chỉ để báo sớm cho khách:
 * lúc tạo đơn LTP_sp_booking_create kiểm tra lại trong transaction.
 */
final class ScheduleController extends Controller
{
    /** Số khách lớn nhất nhận trong tham số people (giống số khách tối đa của một đơn). */
    public const PEOPLE_MAX = 50;

    private BookingAvailabilityModel $availability;

    public function __construct()
    {
        $this->availability = new BookingAvailabilityModel();
    }

    /** GET /api/schedules/{id}/availability?people=N (không có people = 1 khách) */
    public function apiAvailability(string $id): void
    {
        $scheduleId = self::parseUuid($id);
        if ($scheduleId === null) {
            $this->json(false, 'Mã lịch khởi hành không hợp lệ.', null, 400);
        }

        $peopleText = $this->query('people');
        $people = $peopleText === '' ? 1 : filter_var($peopleText, FILTER_VALIDATE_INT, [
            'options' => ['min_range' => 1, 'max_range' => self::PEOPLE_MAX],
        ]);
        if ($people === false) {
            $this->json(false, 'Số khách phải từ 1 đến ' . self::PEOPLE_MAX . '.', null, 422);
        }

        $schedule = $this->availability->find($scheduleId);
        if ($schedule === null) {
            $this->json(false, 'Không tìm thấy lịch khởi hành.', null, 404);
        }

        $remaining = (int) $schedule['remaining'];
        $maxGroup = (int) $schedule['max_group_size'];
        $bookable = (int) $schedule['bookable'] === 1;

        $message = match (true) {
            !$bookable => 'Lịch này không còn nhận đặt. Vui lòng chọn ngày khác.',
            $people > $maxGroup => 'Mỗi nhóm tối đa ' . $maxGroup . ' khách.',
            $people > $remaining => 'Lịch này chỉ còn ' . $remaining . ' chỗ.',
            default => 'Lịch còn đủ chỗ cho ' . $people . ' khách.',
        };

        $this->json(true, $message, [
            'schedule_id' => $schedule['schedule_id'],
            'tour_id' => $schedule['tour_id'],
            'starts_at' => $schedule['starts_at'],
            'ends_at' => $schedule['ends_at'],
            'status' => $schedule['status'],
            'remaining' => $remaining,
            'max_group_size' => $maxGroup,
            'bookable' => $bookable,
            'people' => $people,
            'enough' => $bookable && $people <= $maxGroup && $people <= $remaining,
            'tickets' => array_map('ticket_option', $this->availability->tickets($scheduleId)),
        ]);
    }
}