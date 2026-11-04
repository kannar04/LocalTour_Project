@echo off
rem Đăng ký Windows Task Scheduler chạy expire_holds.php mỗi 15 phút (Sprint 4, 4.5.4.1 – Lê Trung Phong).
rem Cách dùng (trên máy chạy demo, sau khi đã có src\.env và MySQL đang chạy):
rem   register_expire_task.bat                    dùng PHP của XAMPP ở C:\xampp\php
rem   register_expire_task.bat D:\xampp\php       thư mục PHP khác
rem   register_expire_task.bat /delete            gỡ lịch chạy
rem Lịch chạy dùng php-win.exe nên không hiện cửa sổ; chỉ chạy khi tài khoản Windows này đang đăng nhập.
setlocal
chcp 65001 >nul
set "TASK=LocalTour - Tu huy don qua han"

if /i "%~1"=="/delete" (
    schtasks /Delete /TN "%TASK%" /F
    exit /b %errorlevel%
)

set "PHPDIR=%~1"
if "%PHPDIR%"=="" set "PHPDIR=C:\xampp\php"
if not exist "%PHPDIR%\php.exe" (
    echo Không tìm thấy %PHPDIR%\php.exe. Chạy lại kèm thư mục PHP, ví dụ: register_expire_task.bat D:\xampp\php
    exit /b 1
)
if not exist "%PHPDIR%\php-win.exe" (
    echo Không tìm thấy %PHPDIR%\php-win.exe trong thư mục PHP.
    exit /b 1
)
set "SCRIPT=%~dp0expire_holds.php"

rem Chạy thử một lần: lỗi kết nối database thì dừng, không đăng ký.
"%PHPDIR%\php.exe" "%SCRIPT%"
if errorlevel 1 (
    echo Chạy thử expire_holds.php bị lỗi: kiểm tra src\.env và MySQL rồi chạy lại.
    exit /b 1
)

schtasks /Create /TN "%TASK%" /SC MINUTE /MO 15 /TR "\"%PHPDIR%\php-win.exe\" \"%SCRIPT%\"" /F
if errorlevel 1 exit /b 1
echo Đã đăng ký "%TASK%": chạy mỗi 15 phút. Gỡ bằng: register_expire_task.bat /delete
