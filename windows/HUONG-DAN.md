# Build PHP 7.4.33 cho Windows/IIS có vá PHP2Shell (CVE-2026-109618 / CVE-2026-109619)

## Bối cảnh

- PHP2Shell là lỗi RCE không cần đăng nhập nằm trong **runtime PHP**. Lỗi xảy ra ngay khi PHP đọc request POST, trước khi code Moodle chạy, và ảnh hưởng cả IIS FastCGI (`php-cgi.exe`).
- php.net **không phát hành** bản 7.4 mới cho Windows. php-src chỉ công bố patch source chính thức: commit `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2`, nhánh `PHP-7.4-CVE-2026-109618-109619` ("Avoid state corruption via bailout – Minimal mitigation for EOL version").
- Bộ này build lại **PHP 7.4.33 NTS x64 (vc15)**, đúng loại IIS dùng, có kèm patch đó. Moodle 3.11 vẫn chạy trên PHP 7.4 như cũ, không sửa source LMS.
- Patch chỉ thêm hàm và macro, không đổi ABI. Vì vậy các extension DLL bên thứ ba đang dùng (sqlsrv, pdo_sqlsrv, redis, …) bản `7.4 / nts / x64 / vc15` dùng lại được, không cần tải lại.

> Patch giống hệt bản đã build và test trên Docker (PR VnResource-LMS/moodle-docker#1). Các script Windows trong bộ này **chưa được chạy thử trên Windows**. Phải build và kiểm tra trên máy staging trước khi đưa lên production.

## Nội dung thư mục

| File | Dùng ở đâu | Tác dụng |
|---|---|---|
| `php-7.4.patch` | máy build | Patch chính thức của php-src. SHA256: `5fe57ca6ee96d59b36c6e0ca842843c50884f177bef1e85234cf669b577f5e48` |
| `build.bat` | máy build | Mở PHP SDK shell vc15 x64 rồi chạy `build-task.bat` |
| `build-task.bat` | máy build (gọi tự động) | Kiểm tra patch → clone php-7.4.33 → áp patch → tải deps → configure → `nmake` → `nmake snap` → kiểm tra |
| `verify-server.bat` | máy chủ IIS | Kiểm tra bản PHP đã vá chưa và so sánh danh sách extension với bản cũ |

---

## Phần A – Chuẩn bị máy build (một lần)

Máy Windows 10/11 hoặc Server 2016+ x64, có Internet, trống khoảng 15 GB. Không nên build trên máy chủ production.

1. **Trình biên dịch VC15 (MSVC v141)**, chọn **một** trong hai cách:
   - **Cách 1 (khuyến nghị):** cài *Build Tools for Visual Studio 2017* (https://aka.ms/vs/15/release/vs_buildtools.exe), chọn workload **"Visual C++ build tools"**, có *Windows 10 SDK*.
   - **Cách 2:** đã có VS 2019 hoặc 2022 (hay Build Tools 2019/2022) thì vào Visual Studio Installer → *Modify* → *Individual components*, tick:
     - **MSVC v141 – VS 2017 C++ x64/x86 build tools (v14.16)**
     - **MSVC v142/v143 … (latest)** (thường đã có sẵn)
     - **Windows 10 SDK** (hoặc Windows 11 SDK)

     Trước khi chạy `build.bat`, mở cmd và chạy: `set TOOLSET=14.16`.
2. **Git for Windows**: https://git-scm.com/download/win (để mặc định là được).
3. **PHP SDK binary tools**:
   ```bat
   git clone --branch php-sdk-2.9.0 https://github.com/php/php-sdk-binary-tools.git C:\php-sdk
   ```
   Nếu để chỗ khác thì chạy `set PHP_SDK_DIR=<đường dẫn>` trước khi build.
4. Chép cả thư mục này sang máy build, đặt ở **`C:\php74-build`**. Đường dẫn **không được có dấu cách**.

## Phần B – Build

Mở **cmd thường** (không cần Developer Prompt), chạy:

```bat
rem chỉ khi dùng Cách 2 (VS 2019/2022 + v141):
set TOOLSET=14.16

C:\php74-build\build.bat
```

Build mất khoảng 20–40 phút. Script dừng ngay nếu có lỗi và in dòng `[LOI] ...`. Nếu thành công, cuối cùng sẽ in ra:

```
[OK] Patch sha256 khop.
[OK] Da ap patch PHP2Shell.
[OK] php7.dll co code ban va PHP2Shell.
PHP 7.4.33 (cli) ...
 XONG. Goi PHP da va nam trong: C:\php74-build\out
php-7.4.33-nts-Win32-vc15-x64.zip
php-7.4.33-nts-Win32-vc15-x64.zip.sha256
```

Muốn build lại từ đầu thì xoá `C:\php74-build\work` trước.

### Lỗi thường gặp khi build

| Hiện tượng | Cách xử lý |
|---|---|
| `Could not determine 'vc15' directory` | Chưa cài VS 2017 Build Tools. Nếu dùng VS 2019/2022 thì kiểm tra đã tick v141 và đã `set TOOLSET=14.16` |
| `Windows SDK not found` | Cài thêm Windows 10/11 SDK trong Visual Studio Installer |
| `Patch khong ap duoc` | Thư mục `work` cũ còn sót, hoặc Git đã đổi xuống dòng. Xoá `work` rồi chạy lại (script đã clone với `core.autocrlf=false`) |
| `phpsdk_deps` lỗi tải | Kiểm tra mạng hoặc proxy tới `windows.php.net` / `downloads.php.net` |
| `SHA256 cua php-7.4.patch khong khop` | File patch bị sửa hoặc hỏng khi chép. Lấy lại file gốc |

---

## Phần C – Triển khai lên máy chủ IIS

Máy chủ cần có sẵn *Visual C++ Redistributable 2015–2022 (x64)*. Bản 7.4 đang chạy đã cần nó nên thường có sẵn.

Ví dụ dưới đây coi PHP hiện tại nằm ở `C:\PHP`. Đổi đường dẫn cho đúng máy chủ: xem đường dẫn `php-cgi.exe` trong IIS Manager → *Handler Mappings* / *FastCGI Settings*.

1. **Chép zip lên máy chủ và kiểm tra checksum** (so với file `.sha256`):
   ```bat
   certutil -hashfile php-7.4.33-nts-Win32-vc15-x64.zip SHA256
   ```
2. **Giải nén** ra `C:\PHP-new`.
3. **Chép cấu hình và extension bên thứ ba từ bản cũ sang:**
   - `C:\PHP\php.ini` → `C:\PHP-new\php.ini`
   - Các DLL trong `C:\PHP\ext` **không có** trong `C:\PHP-new\ext`, ví dụ `php_sqlsrv_74_nts_x64.dll`, `php_pdo_sqlsrv_74_nts_x64.dll`, `php_redis.dll`… → chép vào `C:\PHP-new\ext`. **Không** ghi đè các DLL đã có sẵn trong bản mới (`php_curl.dll`, `php_openssl.dll`, `php_opcache.dll`…).
   - DLL phụ khác ở thư mục gốc `C:\PHP` mà bản mới không có (nếu extension bên thứ ba cần).
   - Mở `C:\PHP-new\php.ini`, kiểm tra `extension_dir`. Nên đặt `extension_dir = "ext"` (đường dẫn tương đối) để bước 5 kiểm tra đúng DLL của bản mới. Nếu để `"C:\PHP\ext"` thì bước 5 sẽ nạp nhầm DLL của bản cũ. Sau khi đổi tên ở bước 6, đường dẫn đó lại đúng.
   - Nếu máy chủ có biến môi trường `PHPRC` trỏ về `C:\PHP`, php.exe của bản mới sẽ đọc php.ini của bản cũ. Bước 5 vẫn dùng được, nhưng nhớ rằng nó đang chạy với ini cũ.
4. **Thêm vào `C:\PHP-new\php.ini`** để giảm thêm rủi ro (Moodle không dùng tính năng này):
   ```ini
   session.upload_progress.enabled = 0
   ```
5. **Kiểm tra trước khi đổi** (chưa ảnh hưởng site):
   ```bat
   C:\php74-build\verify-server.bat C:\PHP-new C:\PHP
   ```
   Phải ra `KET QUA: DAT`. Nếu danh sách extension khác bản cũ thì đọc phần `fc` mà script in ra: thường là thiếu DLL bên thứ ba ở bước 3.
6. **Đổi bản**, việc này làm site gián đoạn khoảng 1 phút:
   ```bat
   iisreset /stop
   ren C:\PHP PHP-7.4.33-old
   ren C:\PHP-new PHP
   iisreset /start
   ```
   Giữ nguyên tên thư mục `C:\PHP` để không phải sửa cấu hình FastCGI trong IIS.
   Nếu máy chủ chạy nhiều site, `iisreset /stop` sẽ dừng **tất cả**. Muốn chỉ gián đoạn Moodle thì dừng riêng app pool của Moodle (`%windir%\system32\inetsrv\appcmd stop apppool /apppool.name:"<tên pool>"`), nhưng chỉ được làm vậy khi **không** site nào khác dùng chung `C:\PHP`. Nếu còn site khác dùng, `php-cgi.exe` vẫn chạy và việc đổi tên thư mục sẽ thất bại. Trước khi `ren`, kiểm tra không còn `php-cgi.exe` nào: `tasklist | findstr php-cgi`.
7. **Kiểm tra sau khi đổi:**
   ```bat
   C:\php74-build\verify-server.bat C:\PHP C:\PHP-7.4.33-old
   ```
   Trên web: đăng nhập Moodle, mở Dashboard và trang Admin, upload thử một file, xem một khoá học. Chạy cron một lần: `C:\PHP\php.exe <moodle>\admin\cli\cron.php`, hoặc kiểm tra scheduled task đang chạy cron.
8. **Ghi dấu đã vá** (để đội vận hành và bảo mật tra cứu):
   ```bat
   echo backport 7.4.33 php-7.4.patch 5fe57ca6ee96d59b36c6e0ca842843c50884f177bef1e85234cf669b577f5e48 > C:\PHP\PHP2SHELL_PATCHED.txt
   ```

### Rollback

```bat
iisreset /stop
ren C:\PHP PHP-7.4.33-patched
ren C:\PHP-7.4.33-old PHP
iisreset /start
```

Bản cũ vẫn dính lỗi, nên chỉ rollback tạm thời.

---

## Lưu ý

- `php -v` vẫn hiện **7.4.33**. Scanner dựa vào số phiên bản (Nessus, Qualys…) vẫn sẽ báo dính lỗi. Bằng chứng đã vá là `verify-server.bat` báo `[OK] php7.dll co code ban va PHP2Shell` (php7.dll có export `zend_mm_safe_error_ex`, bản gốc không có) cùng file `PHP2SHELL_PATCHED.txt`.
- Build dùng `--enable-snapshot-build` giống bản chính thức của windows.php.net. Extension nào thiếu thư viện sẽ bị bỏ qua mà không báo lỗi, nên **bắt buộc** chạy bước 5 để so sánh với bản cũ. Bản này cố ý không build Oracle (oci8/pdo_oci).
- Một máy build ra zip xong là dùng được cho mọi máy chủ IIS chạy PHP 7.4 NTS x64. Không cần build lại cho từng máy.
- Giải pháp lâu dài: nâng lên Moodle 4.x + PHP 8.3 (≥ 8.3.36), hoặc chạy bằng Docker đã vá.

## Nguồn

- Patch chính thức: https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2
- Hướng dẫn build PHP trên Windows: https://wiki.php.net/internals/windows/stepbystepbuild_sdk_2
- PHP SDK binary tools: https://github.com/php/php-sdk-binary-tools
- Phân tích lỗi: https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/
