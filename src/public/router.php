<?php

/*
 * Router cho PHP built-in server (không dùng với Apache):
 *   cd src
 *   C:\xampp\php\php.exe -S 127.0.0.1:8080 -t public public/router.php
 * File tĩnh có thật trong public/ được trả trực tiếp, còn lại chuyển cho index.php.
 */

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
if ($path !== '/' && is_file(__DIR__ . $path)) {
    return false;
}

$_SERVER['SCRIPT_NAME'] = '/index.php';
require __DIR__ . '/index.php';
