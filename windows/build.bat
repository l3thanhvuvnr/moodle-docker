@echo off
rem =====================================================================
rem Build PHP 7.4.33 NTS x64 (vc15) cho Windows/IIS + ban va PHP2Shell
rem (CVE-2026-109618 / CVE-2026-109619).
rem
rem Cach dung (cmd thuong, KHONG can mo Developer Prompt):
rem     C:\php74-build\build.bat
rem
rem Bien moi truong tuy chon:
rem     PHP_SDK_DIR  thu muc php-sdk-binary-tools (mac dinh C:\php-sdk)
rem     TOOLSET      dat 14.16 neu dung VS 2019/2022 + component MSVC v141
rem                  (de trong neu cai VS 2017 Build Tools)
rem =====================================================================
setlocal

if "%PHP_SDK_DIR%"=="" set "PHP_SDK_DIR=C:\php-sdk"

if not exist "%PHP_SDK_DIR%\phpsdk-vc15-x64.bat" (
    echo [LOI] Khong thay "%PHP_SDK_DIR%\phpsdk-vc15-x64.bat".
    echo       Clone php-sdk truoc:
    echo       git clone --branch php-sdk-2.9.0 https://github.com/php/php-sdk-binary-tools.git C:\php-sdk
    exit /b 1
)

rem Duong dan task script khong duoc co dau cach (gioi han cua phpsdk-starter).
set "TASK=%~dp0build-task.bat"
echo "%TASK%" | findstr /c:" " >nul && (
    echo [LOI] Duong dan "%~dp0" co dau cach. Chep thu muc nay ra C:\php74-build roi chay lai.
    exit /b 1
)

rem Truyen %TASK% KHONG co ngoac kep: phpsdk-starter tu boc ngoac khi kiem tra file.
call "%PHP_SDK_DIR%\phpsdk-vc15-x64.bat" -t %TASK%
exit /b %ERRORLEVEL%
