# OpenResty trên Ubuntu

Dự án này ưu tiên cài OpenResty trực tiếp trên Ubuntu host. OpenResty được biên dịch từ source, sau đó nạp cấu hình trong `includes/` cho virtual host mặc định, WAF, giới hạn request, log, API unban và Prometheus metrics.

## Thành phần và cổng

| Thành phần | Địa chỉ | Ghi chú |
| --- | --- | --- |
| OpenResty | `http://localhost` | HTTP trên cổng 80 |
| OpenResty metrics | `http://127.0.0.1:9145/metrics` | Chỉ nhận loopback và mạng metrics `172.30.0.0/24` |
| Prometheus | `http://localhost:9090` | Chạy tùy chọn bằng Docker Compose |
| Grafana | `http://localhost:3000` | Chạy tùy chọn bằng Docker Compose |

Với cài đặt trực tiếp trên host, đặt nội dung web (ví dụ `index.html`) trong `/usr/local/openresty/nginx/html/`. Thư mục `html/` trong dự án được mount cho chế độ Docker.

## Cài OpenResty trực tiếp trên host

Yêu cầu Ubuntu, quyền `sudo`/root và kết nối mạng để tải mã nguồn cùng thư viện metrics. Chạy từ thư mục dự án:

```bash
sudo ./install-openresty.sh
sudo ./init-config-openresty-metrics.sh
```

Tạo systemd service và khởi động OpenResty:

```bash
sudo ./install_openresty_service.sh
```

Kiểm tra trạng thái, cấu hình và truy cập:

```bash
sudo systemctl status openresty
sudo /usr/local/openresty/bin/openresty -t
curl -I http://127.0.0.1/
curl http://127.0.0.1:9145/metrics
```

Các file cấu hình được cài vào `/usr/local/openresty/nginx/conf/includes/`; nội dung website được đọc từ `/usr/local/openresty/nginx/html/`. Sau khi chỉnh cấu hình, kiểm tra bằng `openresty -t`, rồi reload:

```bash
sudo /usr/local/openresty/bin/openresty -t
sudo systemctl reload openresty
```

### API unban

API lắng nghe cổng `8888`, chỉ cho phép loopback và chỉ nhận `POST`. Gỡ chặn một IP hoặc xóa toàn bộ blacklist:

```bash
curl -X POST 'http://127.0.0.1:8888/nginx_api/unban?ip=203.0.113.10'
curl -X POST http://127.0.0.1:8888/nginx_api/flush-all
```

### Cài monitoring tùy chọn

Prometheus và Grafana có thể chạy bằng Docker trong khi OpenResty tiếp tục chạy trực tiếp trên host. Prometheus cần kết nối tới host qua mạng `openresty-metrics-net`. Tạo mạng nếu chưa tồn tại:

```bash
docker network inspect openresty-metrics-net >/dev/null 2>&1 || \
  docker network create --driver bridge --subnet 172.30.0.0/24 openresty-metrics-net
```

Khởi chạy Prometheus và Grafana:

```bash
docker compose -f docker-compose-prometheus.yml up -d
docker compose -f docker-compose-grafana.yml up -d
```

Mở Prometheus tại `http://localhost:9090`. Trong Grafana (`http://localhost:3000`), tạo Prometheus data source với URL `http://prometheus:9090`.

Dừng hai dịch vụ monitoring:

```bash
docker compose -f docker-compose-grafana.yml down
docker compose -f docker-compose-prometheus.yml down
```

### Dùng OpenResty trong Docker (tùy chọn)

Nếu muốn chạy OpenResty trong container thay cho bản cài trên host, chạy:

```bash
docker compose -f docker-compose-openresty.yml up -d --build
```

Mở `http://localhost:8080`. Khi scrape container OpenResty bằng Prometheus, đổi target trong `prometheus.yml` từ `host.docker.internal:9145` thành `openresty-lab:9145`.

## Cấu hình chính

- `includes/site/default-site.conf`: virtual host mặc định, security headers, WAF và giới hạn request.
- `includes/site/lua_unban_api.conf`: API unban chỉ truy cập từ loopback.
- `includes/site/proxy.conf`: cấu hình reverse proxy template.
- `includes/security/waf.conf`: kiểm tra blacklist, phát hiện vi phạm và ghi metrics.
- `includes/security/00-shared-memory.conf`: shared memory cho blacklist và violation tracker.
- `includes/security/rate_limit.conf`, `includes/security/rate_limit_location.conf`: cấu hình giới hạn request.
- `includes/security/cloudflare-realip.conf`: dải IP Cloudflare được tin cậy; giữ cấu hình này nếu traffic thực sự đi qua Cloudflare.
- `includes/security/security-headers.conf`, `includes/security/basic-*.conf`, `includes/security/strict-transport-security.conf`: các HTTP security headers.
- `includes/log/json_log_format.conf`, `includes/log/time_iso8601.conf`: định dạng log JSON và bóc tách thời gian ISO8601.
- `includes/ssl/ssl_it.local_certificate.conf`, `includes/ssl/force-ssl.conf` và `ssl/`: chứng chỉ tự ký và cấu hình HTTPS.
- `prometheus.yml`: cấu hình scrape metrics của OpenResty.

## Gỡ cài đặt bản host

Mặc định, script gỡ cài đặt sẽ giữ lại các vhost trong `sites-available` và `sites-enabled`, đồng thời chuyển `conf.d` thành `conf.d.old` và `includes` thành `includes.old` trong `/usr/local/openresty/nginx/conf/`:

```bash
sudo ./uninstall.sh
```

Nếu muốn xóa sạch toàn bộ thư mục `/usr/local/openresty` bao gồm tất cả các file cấu hình như trước đây, hãy truyền thêm cờ `--clean`:

```bash
sudo ./uninstall.sh --clean
```

`install-openresty.sh` hiện tải source với `--no-check-certificate` theo cấu hình được giữ lại trong dự án.
