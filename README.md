# Lưu ý: Phải Get repository MOOELLE-DOCKER-VNR

# Setup moodle
1. Copy file .env và tiến hành cấu hình các biến cần thiết trong file .env
```
cp ./config/templates/.env.example .env
```

2. Tiến hành get source LMS từ git về local theo hướng dẫn bên dưới
Lưu ý: Phải có tài khoản github và tạo có personal access token
```
cd [Đến thư mục project]
git clone --branch [master hoặc Branch mong muốn] https://github.com/kietchungvnr/MOODLE_37.git source
```

3. Sau khi get source thành công tiến hành copy file config vào sourcre. Tiến hành kiểm tra lại file .env xem đã chỉnh sửa hay chưa
Để copy file config vào source làm theo câu lệnh bên dưới
```
cp ./config/templates/config.docker-template.php [Đường dẫn chưa source]
```

# Bảo mật: PHP2Shell (CVE-2026-109618 / CVE-2026-109619)
Lỗi RCE không cần đăng nhập nằm trong **runtime PHP** (xảy ra trước khi code Moodle chạy), nên chỉ vá được ở tầng PHP/Docker, không cần sửa source LMS.

Image LMS giờ được build từ `Dockerfile` (`FROM moodlehq/moodle-php-apache:${PHP_VERSION}`) và tự vá khi build (`config/php/php2shell/apply.sh`):

| PHP_VERSION (.env) | Cách vá | Dùng cho |
|---|---|---|
| `7.4` (mặc định) | Build lại PHP 7.4.33 với patch backport chính thức của php-src (`config/php/php2shell/php-7.4.patch`) | Moodle 3.11 |
| `8.3` / `8.4` / `8.5` | Yêu cầu bản đã vá 8.3.36 / 8.4.27 / 8.5.12, build thất bại nếu cũ hơn | Moodle 4.x |

* Moodle 3.11 **không chạy được trên PHP 8.1+** (lỗi fatal ở `lib/xmlize.php`), nên **không** đổi dự án 3.11 sang 8.3.
* Build lần đầu với 7.4 mất khoảng 5 phút (biên dịch PHP).

Áp dụng bản vá cho dự án đang chạy (image cũ `moodlehq/moodle-php-apache:7.4` **chưa vá**):
1. Pull repo này, thêm dòng `PHP_VERSION=7.4` vào `.env` (xem `config/templates/.env.example`)
2. Build và tạo lại container:
```
sudo docker compose build --pull
sudo docker compose up -d --force-recreate
```
3. Kiểm tra (phải in ra `backport 7.4.33 php-7.4.patch ...` hoặc `upstream 8.x.y`):
```
sudo docker compose exec lms cat /usr/local/etc/php/PHP2SHELL_PATCHED
```
* Lưu ý: `php -v` vẫn hiển thị 7.4.33 vì backport không đổi số phiên bản; file `PHP2SHELL_PATCHED` mới là dấu hiệu đã vá.

# Setup ssl cho LMS
1. Copy chứng chỉ ssl vào /config/apache/ssl
* Lưu ý: Chứng chỉ ssl phải gồm 2 file .crt và .key
2. Tiến hành cấu hình tên ssl cho file default-ssl.conf ở đường dẫn: 
config/apache/default-ssl.conf
Đổi tên file ở 2 dòng SSLCertificateFile và SSLCertificateKeyFile tương ứng với tên chứng chỉ ssl

Ví dụ:
Cấu hình 2 file ssl: vnr.crt và vnr.key thì làm như sau:
```     
SSLCertificateFile	/etc/ssl/moodle/vnr.crt
SSLCertificateKeyFile /etc/ssl/moodle/vnr.key
```

* Lưu ý: Chỉ đổi tên file ssl:
```
[Tên chứng chỉ].crt
[Tên chứng chỉ].key
```

# Sau khi setup moodle ở trên gõ lên bên dưới để tiến hành build LMS
Đối với lần đầu build thì chạy câu lệnh:
```
sudo docker compose build --pull
sudo docker compose up -d
```

Đối với việc muốn update lại file .env thì chạy câu lệnh:
```
sudo docker compose up -d
```

* Đối với source và moodledata phải phân quyền cho thư mục chạy câu lệnh:
```
sudo chmod -R 777 [Đường dẫn source]
sudo chmod -R 777 [Đường dẫn moodledata]
```

# Setup portainer để quản trị Docker sử dụng UI

1. Tạo volume
```
sudo docker volume create portainer_data
```
2. Tạo container cho portainer
```
sudo docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart=always -v portainer_data:/data portainer/portainer-ce:2.9.3
```

# Setup learninglocker(xAPI)
* Truy cập thư mục gốc (moodle-docker-vnr)
* Lưu ý: Chỉ tiến hành cài xAPI trên môi trường nhân linux(ubuntu, debian, centos, etc..)

1. Tiến hành get source learninglocker
```
git clone https://github.com/adlnet/learninglocker-docker learninglocker
```
2. Truy cập vào folder learninglocker và xem file README.md để được hướng dẫn

# Tài liệu hướng dẫn sử dụng kỹ thuật Moodle
```
https://docs.google.com/document/d/1faS3pJzwSamiI_iYEZ4KUtSazkd973KG/edit?usp=sharing&ouid=101094468371402780971&rtpof=true&sd=true
```