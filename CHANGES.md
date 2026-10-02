# Báo Cáo Thay Đổi Cấu Trúc Thư Mục `includes/`

Tài liệu này tổng hợp chi tiết các thay đổi về cấu trúc thư mục cấu hình OpenResty và các cập nhật liên quan trong dự án.

---

## 1. So Sánh Cấu Trúc Thư Mục (Trước đây => Hiện tại)

### Trước đây (Flat structure)
Tất cả các file cấu hình nằm chung trong một thư mục `includes/`:

```text
includes/
├── 00-shared-memory.conf
├── basic-cross-origin-resource-policy.conf
├── basic-referrer-policy.conf
├── cloudflare-realip.conf
├── default-site.conf
├── force-ssl.conf
├── global_block_list.conf
├── json_log_format.conf
├── lua_unban_api.conf
├── proxy.conf
├── rate_limit.conf
├── rate_limit_location.conf
├── security-headers.conf
├── ssl_it.local_certificate.conf
├── strict-transport-security.conf
├── time_iso8601.conf
└── waf.conf
```

### Hiện tại (Categorized structure)
Phân loại theo từng nhóm chức năng riêng biệt: `security/`, `log/`, `ssl/`, `site/`:

```text
includes/
├── security/
│   ├── 00-shared-memory.conf
│   ├── basic-cross-origin-resource-policy.conf
│   ├── basic-referrer-policy.conf
│   ├── cloudflare-realip.conf
│   ├── global_block_list.conf
│   ├── rate_limit.conf
│   ├── rate_limit_location.conf
│   ├── security-headers.conf
│   ├── strict-transport-security.conf
│   └── waf.conf
├── log/
│   ├── json_log_format.conf
│   └── time_iso8601.conf
├── ssl/
│   ├── force-ssl.conf
│   └── ssl_it.local_certificate.conf
└── site/
    ├── default-site.conf
    ├── lua_unban_api.conf
    └── proxy.conf
```

---

## 2. Bảng Chi Tiết Đường Dẫn File (Trước đây => Hiện tại)

| File cấu hình | Đường dẫn trước đây | Đường dẫn hiện tại |
| :--- | :--- | :--- |
| **Shared Memory** | `includes/00-shared-memory.conf` | `includes/security/00-shared-memory.conf` |
| **CORP Header** | `includes/basic-cross-origin-resource-policy.conf` | `includes/security/basic-cross-origin-resource-policy.conf` |
| **Referrer Policy** | `includes/basic-referrer-policy.conf` | `includes/security/basic-referrer-policy.conf` |
| **Cloudflare RealIP** | `includes/cloudflare-realip.conf` | `includes/security/cloudflare-realip.conf` |
| **Global Blocklist** | `includes/global_block_list.conf` | `includes/security/global_block_list.conf` |
| **Rate Limit Zone** | `includes/rate_limit.conf` | `includes/security/rate_limit.conf` |
| **Rate Limit Location**| `includes/rate_limit_location.conf` | `includes/security/rate_limit_location.conf` |
| **Security Headers** | `includes/security-headers.conf` | `includes/security/security-headers.conf` |
| **HSTS Header** | `includes/strict-transport-security.conf` | `includes/security/strict-transport-security.conf` |
| **WAF & Ban Rules** | `includes/waf.conf` | `includes/security/waf.conf` |
| **JSON Log Format** | `includes/json_log_format.conf` | `includes/log/json_log_format.conf` |
| **ISO8601 Time Map**| `includes/time_iso8601.conf` | `includes/log/time_iso8601.conf` |
| **Force SSL (HTTPS)**| `includes/force-ssl.conf` | `includes/ssl/force-ssl.conf` |
| **SSL Certificate** | `includes/ssl_it.local_certificate.conf` | `includes/ssl/ssl_it.local_certificate.conf` |
| **Default VHost** | `includes/default-site.conf` | `includes/site/default-site.conf` |
| **Lua Unban API** | `includes/lua_unban_api.conf` | `includes/site/lua_unban_api.conf` |
| **Proxy Template** | `includes/proxy.conf` | `includes/site/proxy.conf` |

---

## 3. Thay Đổi Trong Các File Code & Script

### 3.1. `includes/security/security-headers.conf`
**Trước đây:**
```nginx
include /usr/local/openresty/nginx/conf/includes/basic-referrer-policy.conf;
include /usr/local/openresty/nginx/conf/includes/basic-cross-origin-resource-policy.conf;
include /usr/local/openresty/nginx/conf/includes/strict-transport-security.conf;
```

**Hiện tại:**
```nginx
include /usr/local/openresty/nginx/conf/includes/security/basic-referrer-policy.conf;
include /usr/local/openresty/nginx/conf/includes/security/basic-cross-origin-resource-policy.conf;
include /usr/local/openresty/nginx/conf/includes/security/strict-transport-security.conf;
```

---

### 3.2. `includes/site/default-site.conf`
**Trước đây:**
```nginx
include /usr/local/openresty/nginx/conf/includes/security-headers.conf;
include /usr/local/openresty/nginx/conf/includes/global_block_list.conf;
include /usr/local/openresty/nginx/conf/includes/waf.conf;

location / {
    include /usr/local/openresty/nginx/conf/includes/rate_limit_location.conf;
    try_files $uri $uri/ =404;
}
```

**Hiện tại:**
```nginx
include /usr/local/openresty/nginx/conf/includes/security/security-headers.conf;
include /usr/local/openresty/nginx/conf/includes/security/global_block_list.conf;
include /usr/local/openresty/nginx/conf/includes/security/waf.conf;

location / {
    include /usr/local/openresty/nginx/conf/includes/security/rate_limit_location.conf;
    try_files $uri $uri/ =404;
}
```

---

### 3.3. `install-openresty.sh`
**Trước đây:**
```bash
for include_file in 00-shared-memory.conf cloudflare-realip.conf json_log_format.conf rate_limit.conf time_iso8601.conf; do
    ln -sfn "/usr/local/openresty/nginx/conf/includes/${include_file}" \
        "/usr/local/openresty/nginx/conf/conf.d/${include_file}"
done
for site_file in default-site.conf lua_unban_api.conf; do
    ln -sfn "/usr/local/openresty/nginx/conf/includes/${site_file}" \
        "/usr/local/openresty/nginx/conf/sites-enabled/${site_file}"
done
```

**Hiện tại:**
```bash
for security_file in 00-shared-memory.conf cloudflare-realip.conf rate_limit.conf; do
    ln -sfn "/usr/local/openresty/nginx/conf/includes/security/${security_file}" \
        "/usr/local/openresty/nginx/conf/conf.d/${security_file}"
done
for log_file in json_log_format.conf time_iso8601.conf; do
    ln -sfn "/usr/local/openresty/nginx/conf/includes/log/${log_file}" \
        "/usr/local/openresty/nginx/conf/conf.d/${log_file}"
done
for site_file in default-site.conf lua_unban_api.conf; do
    ln -sfn "/usr/local/openresty/nginx/conf/includes/site/${site_file}" \
        "/usr/local/openresty/nginx/conf/sites-enabled/${site_file}"
done
```

---

### 3.4. `README.md`
**Trước đây:**
- Các mục cấu hình được liệt kê trực tiếp từ gốc `includes/`.

**Hiện tại:**
- Liệt kê đầy đủ theo từng phân nhóm `includes/site/`, `includes/security/`, `includes/log/`, `includes/ssl/`.
