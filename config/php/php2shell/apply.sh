#!/bin/bash
# Vá PHP2Shell (CVE-2026-109618 / CVE-2026-109619) cho image moodlehq/moodle-php-apache.
#
# - PHP 7.4 (EOL, php.net không ra bản mới): build lại PHP từ source có sẵn trong image
#   (/usr/src/php.tar.xz) + patch chính thức của php-src
#   ("Avoid state corruption via bailout - Minimal mitigation for EOL version"):
#     php-src 712e60f9edfd03f0960fc4fc3c2c375f42b90aa2 (nhánh PHP-7.4-CVE-2026-109618-109619)
# - PHP 8.3+ : đã có bản vá chính thức (8.3.36 / 8.4.27 / 8.5.12), chỉ kiểm tra, không build.
#   Patch chỉ thêm hàm/macro, không đổi ABI => các extension có sẵn (sqlsrv, redis, ...) vẫn dùng được.
#   Configure lại đúng các option của bản gốc (php-config --configure-options) và build lại opcache.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MARKER=/usr/local/etc/php/PHP2SHELL_PATCHED
minor=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
full=$(php -r 'echo PHP_VERSION;')

case "$minor" in
    8.3) min=8.3.36 ;;
    8.4) min=8.4.27 ;;
    8.5) min=8.5.12 ;;
    7.4) min="" ;;
    *) echo "PHP2Shell: PHP ${full} không được hỗ trợ (không có bản vá)." >&2; exit 1 ;;
esac

if [ -n "$min" ]; then
    if php -r "exit(version_compare(PHP_VERSION, '${min}', '>=') ? 0 : 1);"; then
        echo "PHP2Shell: PHP ${full} đã vá (>= ${min})."
        echo "upstream ${full}" > "$MARKER"
        exit 0
    fi
    echo "PHP2Shell: PHP ${full} chưa vá, cần >= ${min}. Build lại với: docker compose build --pull" >&2
    exit 1
fi

patchfile="${HERE}/php-${minor}.patch"
[ -f "$patchfile" ] || { echo "PHP2Shell: thiếu ${patchfile}" >&2; exit 1; }
[ -f /usr/src/php.tar.xz ] || { echo "PHP2Shell: image không có /usr/src/php.tar.xz" >&2; exit 1; }

echo "PHP2Shell: build lại PHP ${full} với ${patchfile##*/} ..."
configure_opts=$(php-config --configure-options)

export DEBIAN_FRONTEND=noninteractive
# Ghi lại danh sách gói trước khi cài build deps để gỡ sạch sau khi build.
pkgs_before=$(dpkg-query -W -f='${binary:Package}\n' | sort)
build_deps="patch pkg-config autoconf dpkg-dev file g++ gcc libc-dev make re2c bison \
    apache2-dev libargon2-dev libcurl4-openssl-dev libonig-dev libreadline-dev \
    libsodium-dev libsqlite3-dev libssl-dev libxml2-dev zlib1g-dev"
install_build_deps() {
    apt-get update -qq && apt-get install -y -qq --no-install-recommends $build_deps >/dev/null
}
if ! install_build_deps; then
    # Image PHP EOL chạy Debian EOL (vd: bullseye cho 7.4): mirror chính không còn đủ gói
    # => chuyển sang archive.debian.org rồi cài lại.
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    echo "PHP2Shell: mirror Debian ${codename} lỗi, chuyển sang archive.debian.org"
    printf 'deb http://archive.debian.org/debian %s main\ndeb http://archive.debian.org/debian-security %s-security main\ndeb http://archive.debian.org/debian %s-updates main\n' \
        "$codename" "$codename" "$codename" > /etc/apt/sources.list
    install_build_deps
fi

src=/usr/src/php-php2shell
rm -rf "$src" && mkdir -p "$src"
tar -xf /usr/src/php.tar.xz -C "$src" --strip-components=1
cd "$src"
patch -p1 < "$patchfile"

# Giữ nguyên các option configure + cờ hardening (PIE, stack protector, -O2) gốc của image.
export CFLAGS="${PHP_CFLAGS:-}" CPPFLAGS="${PHP_CPPFLAGS:-}" LDFLAGS="${PHP_LDFLAGS:-}"
eval "./configure ${configure_opts}" >/dev/null
make -j"$(nproc)" >/dev/null
make install >/dev/null

# opcache là extension của php-src và phụ thuộc Zend VM/allocator => build lại từ source đã vá.
if [ -f "$(php-config --extension-dir)/opcache.so" ]; then
    (cd ext/opcache && phpize >/dev/null && ./configure >/dev/null && make -j"$(nproc)" >/dev/null && make install >/dev/null)
fi

cd / && rm -rf "$src"

# Strip như Dockerfile chính thức của image php.
find /usr/local/bin /usr/local/sbin "$(php-config --extension-dir)" /usr/lib/apache2/modules -type f -newer "$patchfile" \
    -exec sh -c 'file "$1" | grep -q ELF && strip --strip-all "$1"' _ {} \; 2>/dev/null || true

# Gỡ compiler và các gói -dev vừa cài (không để lại trong image chạy production).
pkgs_added=$(comm -13 <(echo "$pkgs_before") <(dpkg-query -W -f='${binary:Package}\n' | sort))
if [ -n "$pkgs_added" ]; then
    apt-get purge -y -qq --auto-remove $pkgs_added >/dev/null
fi
apt-get clean && rm -rf /var/lib/apt/lists/*

# Kiểm tra binary mới có chứa code của bản vá.
grep -q zend_mm_safe_error_ex "$(command -v php)" || { echo "PHP2Shell: không thấy code bản vá trong php CLI" >&2; exit 1; }
php -v | head -1
echo "backport ${full} ${patchfile##*/} $(sha256sum "$patchfile" | cut -d' ' -f1)" > "$MARKER"
echo "PHP2Shell: đã vá PHP ${full} bằng backport chính thức."
