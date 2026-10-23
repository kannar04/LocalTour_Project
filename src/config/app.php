<?php

declare(strict_types=1);

use Core\Env;

return [
    'name' => 'LocalTour',
    'env' => Env::get('APP_ENV', 'production'),
    'debug' => Env::bool('APP_DEBUG'),
    'url' => rtrim(Env::get('APP_URL'), '/'),
];
