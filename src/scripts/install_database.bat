@echo off
rem LocalTour - cai database: import moi file src\database\NN_*.sql vao database ghi trong src\.env (Sprint 6, dong goi demo).
rem Bam dup file nay, hoac chay trong Command Prompt, dung o thu muc src (co the them tham so):
rem   scripts\install_database.bat                       cai vao database trong .env (database phai trong hoac chua co)
rem   scripts\install_database.bat --fresh               xoa database do roi cai lai tu dau
rem   scripts\install_database.bat --database=ten_khac   cai vao database khac
rem Dung PHP cua XAMPP o C:\xampp\php; PHP o cho khac thi dat PHP_BIN, vi du: set PHP_BIN=D:\xampp\php\php.exe
rem File chi dung chu khong dau va khong dung nhan / goto, de van chay dung khi mat xuong dong CRLF (vd. ban tai ZIP).
setlocal
set "PHPEXE=%PHP_BIN%"
if "%PHPEXE%"=="" set "PHPEXE=C:\xampp\php\php.exe"
set "CODE=1"

if exist "%PHPEXE%" "%PHPEXE%" "%~dp0install_database.php" %*
if exist "%PHPEXE%" set "CODE=%errorlevel%"
if not exist "%PHPEXE%" echo LOI       Khong tim thay "%PHPEXE%". Dat duong dan php.exe roi chay lai, vi du: set PHP_BIN=D:\xampp\php\php.exe

rem Bam dup thi cua so tu dong khi xong: dung lai de kip doc ket qua.
rem Goi find.exe cua Windows theo duong dan day du (PATH co Git thi "find" co the la lenh find cua Unix).
echo %cmdcmdline% | "%SystemRoot%\System32\find.exe" /i "/c" >nul
if not errorlevel 1 pause
exit /b %CODE%
