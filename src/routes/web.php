<?php

declare(strict_types=1);

use App\Controllers\AdminAuthController;
use App\Controllers\AdminBookingController;
use App\Controllers\AdminDashboardController;
use App\Controllers\AdminTourController;
use App\Controllers\AuthController;
use App\Controllers\TourDetailController;
use App\Controllers\TourListController;
use Core\Router;

$router = new Router();

// Danh sách tour (WBS 3.2.3)
$router->get('/', [TourListController::class, 'index']);
$router->get('/tours', [TourListController::class, 'index']);
$router->get('/api/tours', [TourListController::class, 'apiIndex']);
$router->get('/api/destinations', [TourListController::class, 'apiDestinations']);
$router->get('/api/categories', [TourListController::class, 'apiCategories']);

// Chi tiết tour theo ID (WBS 3.2.4)
$router->get('/tours/{id}', [TourDetailController::class, 'show']);
$router->get('/api/tours/{id}', [TourDetailController::class, 'apiShow']);

// Tài khoản khách hàng: đăng ký, đăng nhập, đăng xuất (WBS 3.2.8). Chưa đăng nhập = chế độ khách.
$router->get('/login', [AuthController::class, 'showLogin']);
$router->post('/login', [AuthController::class, 'login']);
$router->get('/register', [AuthController::class, 'showRegister']);
$router->post('/register', [AuthController::class, 'register']);
$router->post('/logout', [AuthController::class, 'logout']);

// Trang quản trị (FR-19 → FR-25): đăng nhập riêng, chỉ tài khoản quản trị viên.
$router->get('/admin/login', [AdminAuthController::class, 'showLogin']);
$router->post('/admin/login', [AdminAuthController::class, 'login']);
$router->post('/admin/logout', [AdminAuthController::class, 'logout']);
$router->get('/admin', [AdminDashboardController::class, 'index']);
$router->get('/admin/tours', [AdminTourController::class, 'index']);
$router->get('/admin/tours/{id}', [AdminTourController::class, 'show']);
$router->post('/admin/tours/{id}/approve', [AdminTourController::class, 'approve']);
$router->post('/admin/tours/{id}/reject', [AdminTourController::class, 'reject']);
$router->get('/admin/bookings', [AdminBookingController::class, 'index']);
$router->get('/admin/bookings/{id}', [AdminBookingController::class, 'show']);
$router->post('/admin/bookings/{id}/status', [AdminBookingController::class, 'updateStatus']);

return $router;
