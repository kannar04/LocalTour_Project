<?php

declare(strict_types=1);

namespace App\Services;

use RuntimeException;
use Throwable;

/**
 * Gửi email qua SMTP, tự viết bằng stream_socket_client (không dùng thư viện ngoài) – Nguyễn Tuấn Khôi.
 * Hỗ trợ STARTTLS (MAIL_ENCRYPTION=tls, cổng 587), TLS ngay khi kết nối (ssl, 465) và không mã hóa (none, chỉ để thử
 * trên máy), đăng nhập AUTH LOGIN. Email gồm hai phần text/plain và text/html (UTF-8, quoted-printable); tiêu đề và
 * tên người gửi mã hóa RFC 2047.
 * Mỗi lần kết nối / chờ máy chủ trả lời tối đa 10 giây, cả lượt gửi tối đa 15 giây, để không làm treo trang thanh toán.
 * Lỗi (mạng, TLS, máy chủ từ chối) được ném ra dưới dạng RuntimeException kèm bước bị lỗi, mã trả lời của máy chủ và
 * các dòng trao đổi cuối (không có mật khẩu).
 */
final class SmtpMailer
{
    private const STEP_TIMEOUT = 10.0;
    private const TOTAL_TIMEOUT = 15.0;
    private const ENCRYPTIONS = ['tls', 'ssl', 'none'];

    /** @var resource|null */
    private $socket = null;
    private float $deadline = 0.0;
    /** @var list<string> Các dòng trao đổi với máy chủ (C: gửi, S: nhận), không có mật khẩu. */
    private array $transcript = [];
    /** @var list<string> Cảnh báo PHP trong lúc gửi (lỗi kết nối, TLS...). */
    private array $warnings = [];

    /** @param array<string, mixed> $config config/mail.php */
    public function __construct(private array $config)
    {
    }

    /** MAIL_HOST trống = tắt gửi email. */
    public static function enabled(array $config): bool
    {
        return (string) ($config['host'] ?? '') !== '';
    }

    /**
     * Gửi một email multipart (văn bản thuần + HTML). Trả Message-ID của email đã được máy chủ SMTP nhận.
     *
     * @throws RuntimeException
     */
    public function send(string $toAddress, string $toName, string $subject, string $text, string $html): string
    {
        $from = $this->fromAddress();
        $built = self::buildMessage($from, (string) $this->config['from_name'], $toAddress, $toName, $subject, $text, $html);

        $this->run(function () use ($from, $toAddress, $built): void {
            $this->openSession();
            $this->command('MAIL FROM:<' . $from . '>', [250]);
            $this->command('RCPT TO:<' . $toAddress . '>', [250, 251]);
            $this->command('DATA', [354]);
            // Email kết thúc bằng CRLF, nên chỉ cần thêm ".\r\n" để báo hết DATA.
            $this->write(self::dotStuff($built['message']) . ".\r\n", '<nội dung email, ' . strlen($built['message']) . ' byte>');
            $this->expect([250], 'gửi nội dung email');
            $this->quit();
        });

        return $built['message_id'];
    }

    /**
     * Kiểm tra kết nối mà không gửi email: kết nối, EHLO, STARTTLS (khi tls), EHLO, đăng nhập (khi $login và có
     * MAIL_USERNAME), QUIT. Trả các dòng trao đổi.
     *
     * @return list<string>
     * @throws RuntimeException
     */
    public function probe(bool $login = false): array
    {
        $this->run(function () use ($login): void {
            $this->openSession($login);
            $this->quit();
        });

        return $this->transcript;
    }

    /**
     * Dựng email (header + thân) theo RFC 5322 / MIME, dòng kết thúc CRLF. Trả ['message' => ..., 'message_id' => ...].
     *
     * @return array{message: string, message_id: string}
     */
    public static function buildMessage(
        string $fromAddress,
        string $fromName,
        string $toAddress,
        string $toName,
        string $subject,
        string $text,
        string $html
    ): array {
        foreach ([$fromAddress, $toAddress] as $address) {
            if (filter_var($address, FILTER_VALIDATE_EMAIL) === false) {
                throw new RuntimeException('Địa chỉ email không hợp lệ: ' . self::oneLine($address));
            }
        }

        $domain = substr((string) strrchr($fromAddress, '@'), 1);
        $messageId = bin2hex(random_bytes(12)) . '.' . time() . '@' . $domain;
        $boundary = '=_lt_' . bin2hex(random_bytes(12));

        $headers = [
            'Date: ' . date('r'),
            'From: ' . self::mailbox($fromAddress, $fromName),
            'To: ' . self::mailbox($toAddress, $toName),
            'Subject: ' . self::encodeHeader($subject),
            'Message-ID: <' . $messageId . '>',
            'MIME-Version: 1.0',
            'Content-Type: multipart/alternative; boundary="' . $boundary . '"',
        ];

        $parts = [];
        foreach (['text/plain' => $text, 'text/html' => $html] as $type => $body) {
            $parts[] = '--' . $boundary . "\r\n"
                . 'Content-Type: ' . $type . '; charset=UTF-8' . "\r\n"
                . 'Content-Transfer-Encoding: quoted-printable' . "\r\n\r\n"
                . quoted_printable_encode(self::crlf($body));
        }

        $message = implode("\r\n", $headers) . "\r\n\r\n"
            . 'This is a multi-part message in MIME format.' . "\r\n\r\n"
            . implode("\r\n", $parts) . "\r\n"
            . '--' . $boundary . '--' . "\r\n";

        return ['message' => $message, 'message_id' => $messageId];
    }

    /**
     * Mã hóa giá trị header theo RFC 2047 (UTF-8, base64), cắt thành nhiều encoded-word không quá 75 ký tự, không cắt
     * đôi một ký tự UTF-8. Chuỗi chỉ gồm ký tự ASCII in được thì giữ nguyên.
     */
    public static function encodeHeader(string $value): string
    {
        $value = self::oneLine($value);
        if (preg_match('/^[\x20-\x7E]*$/D', $value) && !str_contains($value, '=?')) {
            return $value;
        }

        // 39 byte → 52 ký tự base64; "=?UTF-8?B?" + 52 + "?=" = 64 ký tự, cả dòng "Subject: ..." dưới 78 ký tự.
        $words = [];
        $chunk = '';
        foreach (mb_str_split($value, 1, 'UTF-8') as $char) {
            if ($chunk !== '' && strlen($chunk) + strlen($char) > 39) {
                $words[] = '=?UTF-8?B?' . base64_encode($chunk) . '?=';
                $chunk = '';
            }
            $chunk .= $char;
        }
        if ($chunk !== '') {
            $words[] = '=?UTF-8?B?' . base64_encode($chunk) . '?=';
        }

        return implode("\r\n ", $words);
    }

    /** Dòng bắt đầu bằng "." được thêm một dấu "." (RFC 5321, 4.5.2) để không bị hiểu là kết thúc DATA. */
    public static function dotStuff(string $message): string
    {
        return (string) preg_replace('/^\./m', '..', self::crlf($message));
    }

    /** "Tên <địa chỉ>"; tên trống → chỉ địa chỉ. */
    private static function mailbox(string $address, string $name): string
    {
        $name = self::oneLine($name);
        if ($name === '') {
            return '<' . $address . '>';
        }
        if (preg_match('/^[A-Za-z0-9 ]+$/D', $name)) {
            $display = $name;
        } elseif (preg_match('/^[\x20-\x7E]+$/D', $name) && !str_contains($name, '=?')) {
            $display = '"' . addcslashes($name, '"\\') . '"';
        } else {
            $display = self::encodeHeader($name);
        }

        return $display . ' <' . $address . '>';
    }

    /** Bỏ xuống dòng / tab trong giá trị header (chặn chèn header). */
    private static function oneLine(string $value): string
    {
        return trim((string) preg_replace('/[\r\n\t]+/', ' ', $value));
    }

    private static function crlf(string $value): string
    {
        return (string) preg_replace('/\r\n|\r|\n/', "\r\n", $value);
    }

    private function fromAddress(): string
    {
        $from = (string) $this->config['from_address'];
        if ($from === '' && filter_var((string) $this->config['username'], FILTER_VALIDATE_EMAIL) !== false) {
            $from = (string) $this->config['username'];
        }
        if (filter_var($from, FILTER_VALIDATE_EMAIL) === false) {
            throw new RuntimeException('MAIL_FROM_ADDRESS chưa có hoặc không phải địa chỉ email hợp lệ.');
        }

        return $from;
    }

    /**
     * Chạy một lượt trao đổi SMTP: đặt hạn 15 giây, gom cảnh báo PHP thành thông tin lỗi, luôn đóng kết nối.
     */
    private function run(callable $steps): void
    {
        $this->transcript = [];
        $this->warnings = [];
        $this->deadline = microtime(true) + self::TOTAL_TIMEOUT;

        set_error_handler(function (int $severity, string $message): bool {
            $this->warnings[] = $message;

            return true;
        });
        try {
            $steps();
        } catch (Throwable $exception) {
            throw new RuntimeException($this->describe($exception->getMessage()), 0, $exception);
        } finally {
            restore_error_handler();
            if (is_resource($this->socket)) {
                fclose($this->socket);
            }
            $this->socket = null;
        }
    }

    /** Kết nối, chờ lời chào 220, EHLO; STARTTLS + EHLO lại khi tls; AUTH LOGIN khi có MAIL_USERNAME. */
    private function openSession(bool $login = true): void
    {
        $host = (string) $this->config['host'];
        $port = (int) $this->config['port'];
        $encryption = (string) $this->config['encryption'];

        if (!in_array($encryption, self::ENCRYPTIONS, true)) {
            throw new RuntimeException('MAIL_ENCRYPTION phải là tls, ssl hoặc none (đang là "' . self::oneLine($encryption) . '").');
        }
        if (!preg_match('/^[A-Za-z0-9.\-]{1,253}$/D', $host) || $port < 1 || $port > 65535) {
            throw new RuntimeException('MAIL_HOST hoặc MAIL_PORT không hợp lệ.');
        }

        $context = stream_context_create(['ssl' => [
            'verify_peer' => true,
            'verify_peer_name' => true,
            'peer_name' => $host,
            'SNI_enabled' => true,
            'allow_self_signed' => false,
            'crypto_method' => STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT | STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT,
        ]]);
        $remote = ($encryption === 'ssl' ? 'ssl://' : 'tcp://') . $host . ':' . $port;
        $this->transcript[] = '-- kết nối ' . $remote;
        $socket = stream_socket_client($remote, $errorCode, $errorText, $this->remaining(), STREAM_CLIENT_CONNECT, $context);
        if ($socket === false) {
            throw new RuntimeException('Không kết nối được ' . $host . ':' . $port . ' (' . $errorCode . ' ' . self::oneLine((string) $errorText) . ')');
        }
        $this->socket = $socket;
        $this->expect([220], 'chờ lời chào của máy chủ');

        $extensions = $this->ehlo();
        if ($encryption === 'tls') {
            if (!isset($extensions['STARTTLS'])) {
                throw new RuntimeException('Máy chủ không hỗ trợ STARTTLS; thử MAIL_ENCRYPTION=ssl với cổng 465.');
            }
            $this->command('STARTTLS', [220]);
            $this->armTimeout();
            if (stream_socket_enable_crypto($this->socket, true, STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT | STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT) !== true) {
                throw new RuntimeException('Không bật được TLS sau STARTTLS.');
            }
            $this->transcript[] = '-- đã bật TLS';
            $extensions = $this->ehlo();
        }

        $username = (string) $this->config['username'];
        if (!$login || $username === '') {
            return;
        }
        if ($encryption === 'none' && !in_array($host, ['127.0.0.1', 'localhost', '::1'], true)) {
            throw new RuntimeException('Không gửi mật khẩu SMTP qua kết nối không mã hóa: dùng MAIL_ENCRYPTION=tls hoặc ssl.');
        }
        if (isset($extensions['AUTH']) && !preg_match('/\bLOGIN\b/i', $extensions['AUTH'])) {
            throw new RuntimeException('Máy chủ không hỗ trợ đăng nhập AUTH LOGIN (chỉ có: ' . $extensions['AUTH'] . ').');
        }
        $this->command('AUTH LOGIN', [334]);
        $this->command(base64_encode($username), [334], '<tên đăng nhập>');
        $this->command(base64_encode((string) $this->config['password']), [235], '<mật khẩu>');
    }

    /**
     * EHLO; trả các phần mở rộng máy chủ hỗ trợ: ['STARTTLS' => '', 'AUTH' => 'LOGIN PLAIN', ...].
     *
     * @return array<string, string>
     */
    private function ehlo(): array
    {
        // Tên máy trong EHLO: "localhost", không gửi tên máy tính thật ra ngoài.
        [, $lines] = $this->command('EHLO localhost', [250]);

        $extensions = [];
        foreach (array_slice($lines, 1) as $line) {
            $parts = explode(' ', trim(substr($line, 4)), 2);
            $extensions[strtoupper($parts[0])] = $parts[1] ?? '';
        }

        return $extensions;
    }

    private function quit(): void
    {
        try {
            $this->command('QUIT', [221]);
        } catch (Throwable) {
            // Email đã được nhận; lỗi khi chào tạm biệt không quan trọng.
        }
    }

    /**
     * Gửi một lệnh và kiểm tra mã trả lời. $logAs: nội dung ghi vào nhật ký thay cho lệnh thật (tên đăng nhập, mật khẩu).
     *
     * @param list<int> $codes
     * @return array{0: int, 1: list<string>}
     */
    private function command(string $line, array $codes, ?string $logAs = null): array
    {
        $this->write($line . "\r\n", $logAs);

        return $this->expect($codes, $logAs ?? strtok($line, ' '));
    }

    /**
     * Đọc trả lời (có thể nhiều dòng "250-...", dòng cuối "250 ...") và kiểm tra mã.
     *
     * @param list<int> $codes
     * @return array{0: int, 1: list<string>}
     */
    private function expect(array $codes, string $step): array
    {
        $lines = [];
        do {
            $this->armTimeout();
            $line = fgets($this->socket, 2048);
            if ($line === false) {
                $timedOut = (bool) (stream_get_meta_data($this->socket)['timed_out'] ?? false);
                throw new RuntimeException(($timedOut ? 'Hết thời gian chờ máy chủ SMTP trả lời' : 'Máy chủ SMTP đã đóng kết nối') . ' (bước ' . $step . ').');
            }
            $line = rtrim($line, "\r\n");
            $lines[] = $line;
            $this->transcript[] = 'S: ' . $line;
        } while (strlen($line) > 3 && $line[3] === '-' && count($lines) < 100);

        $code = (int) substr($line, 0, 3);
        if (!in_array($code, $codes, true)) {
            throw new RuntimeException('Máy chủ SMTP từ chối ở bước ' . $step . ': ' . implode(' ', $lines));
        }

        return [$code, $lines];
    }

    private function write(string $data, ?string $logAs = null): void
    {
        $this->transcript[] = 'C: ' . ($logAs ?? rtrim($data, "\r\n"));
        $length = strlen($data);
        $written = 0;
        while ($written < $length) {
            $this->armTimeout();
            $count = fwrite($this->socket, substr($data, $written));
            if ($count === false || $count === 0) {
                throw new RuntimeException('Không gửi được dữ liệu tới máy chủ SMTP.');
            }
            $written += $count;
        }
    }

    /** Thời gian còn lại của lượt gửi, tối đa 10 giây cho một bước. */
    private function remaining(): float
    {
        $left = $this->deadline - microtime(true);
        if ($left <= 0) {
            throw new RuntimeException('Quá ' . (int) self::TOTAL_TIMEOUT . ' giây chưa gửi xong email.');
        }

        return min(self::STEP_TIMEOUT, $left);
    }

    private function armTimeout(): void
    {
        $left = $this->remaining();
        $seconds = (int) floor($left);
        stream_set_timeout($this->socket, $seconds, (int) (($left - $seconds) * 1000000));
    }

    /** Thông báo lỗi đầy đủ: lỗi chính, cảnh báo PHP, các dòng trao đổi cuối. */
    private function describe(string $message): string
    {
        $parts = [$message];
        if ($this->warnings !== []) {
            $parts[] = 'PHP: ' . implode(' | ', array_unique($this->warnings));
        }
        if ($this->transcript !== []) {
            $parts[] = 'SMTP: ' . implode(' / ', array_slice($this->transcript, -8));
        }

        return self::oneLine(implode(' — ', $parts));
    }
}
