@echo off
rem =====================================================================
rem Task chay BEN TRONG PHP SDK shell (build.bat goi qua phpsdk-vc15-x64.bat -t).
rem Khong chay truc tiep file nay.
rem
rem 1. Kiem tra sha256 cua php-7.4.patch
rem 2. Tao cay build, clone php-src tag php-7.4.33, ap patch PHP2Shell chinh thuc
rem    (php-src commit 712e60f9edfd03f0960fc4fc3c2c375f42b90aa2,
rem     nhanh PHP-7.4-CVE-2026-109618-109619)
rem 3. Tai deps vc15 cua 7.4, configure giong ban release chinh thuc (NTS), build, dong goi zip
rem 4. Kiem tra php7.dll co code ban va
rem =====================================================================
setlocal EnableDelayedExpansion

set "HERE=%~dp0"
set "PATCH=%HERE%php-7.4.patch"
set "PATCH_SHA256=5fe57ca6ee96d59b36c6e0ca842843c50884f177bef1e85234cf669b577f5e48"
set "WORK=%HERE%work"
set "OUT=%HERE%out"

rem --- 1. Kiem tra patch -------------------------------------------------
if not exist "%PATCH%" ( echo [LOI] Thieu %PATCH% & exit /b 1 )
set "H="
for /f "delims=" %%h in ('certutil -hashfile "%PATCH%" SHA256 ^| findstr /v /c:":"') do if not defined H set "H=%%h"
set "H=!H: =!"
if /i not "!H!"=="%PATCH_SHA256%" (
    echo [LOI] SHA256 cua php-7.4.patch khong khop: !H!
    exit /b 1
)
echo [OK] Patch sha256 khop.

where git >nul 2>&1 || ( echo [LOI] Chua cai Git for Windows. & exit /b 1 )

rem --- 2. Cay build + source + patch --------------------------------------
if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"
call phpsdk_buildtree phpdev
if errorlevel 1 ( echo [LOI] phpsdk_buildtree & exit /b 1 )
rem phpsdk_buildtree da cd vao %WORK%\phpdev\vc15\x64

if exist php-src (
    echo [LOI] Da co thu muc %CD%\php-src tu lan build truoc. Xoa thu muc "%WORK%" roi chay lai.
    exit /b 1
)
rem core.autocrlf=false: giu LF de patch (LF) ap duoc.
git clone -c core.autocrlf=false --depth 1 --branch php-7.4.33 https://github.com/php/php-src.git php-src
if errorlevel 1 ( echo [LOI] git clone php-src & exit /b 1 )
cd php-src

git apply --check "%PATCH%" || ( echo [LOI] Patch khong ap duoc vao php-7.4.33 & exit /b 1 )
git apply "%PATCH%" || exit /b 1
echo [OK] Da ap patch PHP2Shell.

rem --- 3. Deps + configure + build ----------------------------------------
call phpsdk_deps --update --branch 7.4
if errorlevel 1 ( echo [LOI] phpsdk_deps & exit /b 1 )

call buildconf.bat
if errorlevel 1 ( echo [LOI] buildconf & exit /b 1 )

rem Giong lenh configure cua ban release 7.4 NTS chinh thuc tren windows.php.net,
rem bo phan Oracle (oci8/pdo_oci can Instant Client), PGO va debug pack.
call configure.bat --enable-snapshot-build --disable-zts --enable-com-dotnet=shared --without-analyzer --without-pdo-oci --without-oci8 --without-oci8-11g --without-oci8-12c --disable-debug-pack
if errorlevel 1 ( echo [LOI] configure & exit /b 1 )

nmake
if errorlevel 1 ( echo [LOI] nmake & exit /b 1 )
nmake snap
if errorlevel 1 ( echo [LOI] nmake snap & exit /b 1 )

rem --- 4. Kiem tra + gom ket qua ------------------------------------------
set "REL=%CD%\x64\Release"
if not exist "%REL%\php7.dll" ( echo [LOI] Khong thay %REL%\php7.dll & exit /b 1 )

dumpbin /exports "%REL%\php7.dll" | findstr /c:"zend_mm_safe_error_ex" >nul
if errorlevel 1 (
    echo [LOI] php7.dll KHONG co zend_mm_safe_error_ex - ban va chua vao build.
    exit /b 1
)
echo [OK] php7.dll co code ban va PHP2Shell.

"%REL%\php.exe" -n -v

if not exist "%OUT%" mkdir "%OUT%"
set "ZIP=php-7.4.33-nts-Win32-vc15-x64.zip"
if not exist "%REL%\%ZIP%" ( echo [LOI] Khong thay %REL%\%ZIP% & exit /b 1 )
copy /y "%REL%\%ZIP%" "%OUT%\" >nul
for %%f in ("%OUT%\%ZIP%") do certutil -hashfile "%%f" SHA256 | findstr /v /c:":" > "%%f.sha256"

echo.
echo ==================================================================
echo  XONG. Goi PHP da va nam trong: %OUT%
dir /b "%OUT%"
echo ==================================================================
exit /b 0
