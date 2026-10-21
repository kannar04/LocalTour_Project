<?php

declare(strict_types=1);

use App\Controllers\TourDetailController;
use App\Controllers\TourListController;
use Core\Router;

$router = new Router();

// Danh sách tour (WBS 3.2.3)
$router->get('/', [TourListController::class, 'index']);
$router->get('/tours', [TourListController::class, 'index']);
$router->get('/api/tours', [TourListController::class, 'apiIndex']);
$router->get('/api/destinations', [TourListController::class, 'apiDestinations']);

// Chi tiết tour theo ID (WBS 3.2.4)
$router->get('/tours/{id}', [TourDetailController::class, 'show']);
$router->get('/api/tours/{id}', [TourDetailController::class, 'apiShow']);

return $router;
