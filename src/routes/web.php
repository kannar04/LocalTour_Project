<?php

declare(strict_types=1);

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

return $router;
