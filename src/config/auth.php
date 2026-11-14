<?php

declare(strict_types=1);

use Core\Env;

/*
 * Đăng nhập bằng Google / Facebook (OAuth 2.0) và reCAPTCHA v2 (Nguyễn Tuấn Khôi).
 * Giá trị thật chỉ nằm trong src/.env (không commit). Xem src/.env.example.
 * Thiếu mã / khóa bí mật của nhà cung cấp nào (hoặc 'enabled' => false) thì nút của nhà cung cấp đó bị ẩn;
 * thiếu khóa reCAPTCHA thì các trang đăng nhập, đăng ký không có captcha.
 * Các địa chỉ *_URL chỉ dùng khi kiểm thử với nhà cung cấp giả lập; mặc định là địa chỉ thật.
 */
return [
    'google' => [
        'client_id' => trim(Env::get('GOOGLE_CLIENT_ID')),
        'client_secret' => trim(Env::get('GOOGLE_CLIENT_SECRET')),
        // Để trống: tự tính theo địa chỉ đang mở (…/auth/google/callback).
        'redirect_uri' => trim(Env::get('GOOGLE_REDIRECT_URI')),
        'authorize_url' => trim(Env::get('GOOGLE_AUTHORIZE_URL', 'https://accounts.google.com/o/oauth2/v2/auth')),
        'token_url' => trim(Env::get('GOOGLE_TOKEN_URL', 'https://oauth2.googleapis.com/token')),
        'userinfo_url' => trim(Env::get('GOOGLE_USERINFO_URL', 'https://openidconnect.googleapis.com/v1/userinfo')),
    ],
    // Graph API v27.0. Đang ẩn: enabled = false thì không có nút Facebook và không mở /auth/facebook, kể cả khi
    // .env có khóa.
    'facebook' => [
        'enabled' => false,
        'client_id' => trim(Env::get('FACEBOOK_APP_ID')),
        'client_secret' => trim(Env::get('FACEBOOK_APP_SECRET')),
        // Để trống: tự tính theo địa chỉ đang mở (…/auth/facebook/callback).
        'redirect_uri' => trim(Env::get('FACEBOOK_REDIRECT_URI')),
        'authorize_url' => trim(Env::get('FACEBOOK_AUTHORIZE_URL', 'https://www.facebook.com/v27.0/dialog/oauth')),
        'token_url' => trim(Env::get('FACEBOOK_TOKEN_URL', 'https://graph.facebook.com/v27.0/oauth/access_token')),
        'userinfo_url' => trim(Env::get('FACEBOOK_USERINFO_URL', 'https://graph.facebook.com/v27.0/me')),
    ],
    'recaptcha' => [
        'site_key' => trim(Env::get('RECAPTCHA_SITE_KEY')),
        'secret_key' => trim(Env::get('RECAPTCHA_SECRET_KEY')),
        'verify_url' => trim(Env::get('RECAPTCHA_VERIFY_URL', 'https://www.google.com/recaptcha/api/siteverify')),
    ],
];
