@echo off
rem =====================================================================
rem Kiem tra ban PHP tren may chu IIS da va PHP2Shell chua.
rem Cach dung:  verify-server.bat C:\PHP [C:\PHP-old]
rem   - Tham so 1: thu muc PHP can kiem tra (ban moi)
rem   - Tham so 2 (tuy chon): thu muc PHP cu de so sanh danh sach extension
rem =====================================================================
setlocal
set "PHPDIR=%~1"
set "OLDDIR=%~2"
if "%PHPDIR%"=="" ( echo Cach dung: %~nx0 C:\PHP [C:\PHP-old] & exit /b 1 )
if not exist "%PHPDIR%\php.exe" ( echo [LOI] Khong thay %PHPDIR%\php.exe & exit /b 1 )

set "FAIL=0"

"%PHPDIR%\php.exe" -v

rem Doi chung: ham co trong moi ban 7.4. Khong thay => findstr khong doc duoc DLL, khong ket luan.
findstr /m /c:"zend_hash_str_find" "%PHPDIR%\php7.dll" >nul
if errorlevel 1 ( echo [LOI] findstr khong doc duoc %PHPDIR%\php7.dll - khong kiem tra duoc. & exit /b 2 )

findstr /m /c:"zend_mm_safe_error_ex" "%PHPDIR%\php7.dll" >nul
if errorlevel 1 (
    echo [LOI] %PHPDIR%\php7.dll CHUA VA PHP2Shell.
    set "FAIL=1"
) else (
    echo [OK] php7.dll co code ban va PHP2Shell.
)

"%PHPDIR%\php.exe" -i | findstr /b /c:"session.upload_progress.enabled => Off" >nul
if errorlevel 1 (
    echo [CANH BAO] session.upload_progress.enabled dang bat - them "session.upload_progress.enabled = 0" vao php.ini
) else (
    echo [OK] session.upload_progress.enabled = Off
)

"%PHPDIR%\php.exe" -m > "%TEMP%\php-modules-new.txt" 2>&1
findstr /i /c:"Warning" /c:"Unable to load" "%TEMP%\php-modules-new.txt" >nul && (
    echo [LOI] Co extension khong load duoc:
    findstr /i /c:"Warning" /c:"Unable to load" "%TEMP%\php-modules-new.txt"
    set "FAIL=1"
)

if not "%OLDDIR%"=="" (
    "%OLDDIR%\php.exe" -m > "%TEMP%\php-modules-old.txt" 2>&1
    fc /n "%TEMP%\php-modules-old.txt" "%TEMP%\php-modules-new.txt" >nul
    if errorlevel 1 (
        echo [LOI] Danh sach extension khac ban cu:
        fc /n "%TEMP%\php-modules-old.txt" "%TEMP%\php-modules-new.txt"
        set "FAIL=1"
    ) else (
        echo [OK] Danh sach extension giong ban cu.
    )
)

if "%FAIL%"=="1" ( echo. & echo KET QUA: CHUA DAT & exit /b 1 )
echo. & echo KET QUA: DAT
exit /b 0
