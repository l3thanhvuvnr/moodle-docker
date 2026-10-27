# Image LMS: moodlehq/moodle-php-apache (đã có sẵn sqlsrv, pgsql, redis, intl, ...).
#
# Bảo mật PHP2Shell (CVE-2026-109618 / CVE-2026-109619): lỗi RCE không cần đăng nhập nằm
# trong runtime PHP (trước khi code Moodle chạy) => chỉ vá được ở tầng PHP.
#   - PHP 7.4 (EOL): build lại PHP với patch backport chính thức của php-src.
#   - PHP 8.3+ : yêu cầu bản đã vá 8.3.36 / 8.4.27 / 8.5.12 (build thất bại nếu cũ hơn).
# Chi tiết: config/php/php2shell/apply.sh
#
# Moodle 3.11 => PHP 7.4 (mặc định, đã vá). Luôn build bằng --pull.
ARG PHP_VERSION=7.4
FROM moodlehq/moodle-php-apache:${PHP_VERSION}

COPY config/php/php2shell/ /usr/local/src/php2shell/
RUN /usr/local/src/php2shell/apply.sh
