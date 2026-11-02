<?php

declare(strict_types=1);

use Core\Env;

/*
 * Cấu hình thanh toán trực tuyến (Sprint 4, 4.5.1.1 – Nguyễn Minh Thức).
 * Giá trị thật chỉ nằm trong src/.env (không commit). Xem src/.env.example.
 * VietQR hiện khi có tài khoản nhận tiền; VNPay hiện khi có mã website và khóa bí mật (sandbox).
 */
return [
    'bank_id' => trim(Env::get('PAYMENT_BANK_ID')),
    'bank_name' => trim(Env::get('PAYMENT_BANK_NAME')),
    'account_no' => trim(Env::get('PAYMENT_ACCOUNT_NO')),
    'account_name' => trim(Env::get('PAYMENT_ACCOUNT_NAME')),
    'vnpay_tmn_code' => trim(Env::get('VNPAY_TMN_CODE')),
    'vnpay_hash_secret' => trim(Env::get('VNPAY_HASH_SECRET')),
    'vnpay_pay_url' => trim(Env::get('VNPAY_PAY_URL', 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html')),
    // Để trống: tự tính theo địa chỉ khách đang mở (chạy được cả localhost lẫn qua Radmin VPN).
    'vnpay_return_url' => trim(Env::get('VNPAY_RETURN_URL')),
];
