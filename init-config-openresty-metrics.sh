#!/usr/bin/env bash
set -e

# Ham kiem tra xem co dang chay trong container hay khong
is_in_container() {
    # 1. Kiem tra file /.dockerenv (Docker tu tao khi khoi chay container)
    if [ -f "/.dockerenv" ]; then
        return 0
    fi

    # 2. Kiem tra cgroup (chua tu khoa docker / containerd / kubepods)
    if [ -f "/proc/1/cgroup" ] && grep -Eq '(docker|containerd|kubepods)' /proc/1/cgroup; then
        return 0
    fi

    # 3. Kiem tra mountinfo (hoat dong tot tren Docker cgroup v2)
    if [ -f "/proc/self/mountinfo" ] && grep -q 'docker/containers' /proc/self/mountinfo; then
        return 0
    fi

    return 1
}

# Ham kiem tra xem co dang chay qua Docker Compose hay khong
is_docker_compose() {
    # 1. Kiem tra bien moi truong dac trung cua Docker Compose
    if [ -n "$COMPOSE_PROJECT_NAME" ] || [ -n "$COMPOSE_SERVICE_NAME" ]; then
        return 0
    fi

    # 2. Phan giai DNS bridge network mac dinh cua Docker Compose (nameserver 127.0.0.11)
    if [ -f "/etc/resolv.conf" ] && grep -q "127.0.0.11" /etc/resolv.conf; then
        return 0
    fi

    return 1
}

if ! is_in_container && ! is_docker_compose; then
echo "==> Cau hinh bien moi truong PATH..."
export NGINX_PATH="/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin"
if ! grep -q "/usr/local/openresty" /etc/profile; then
    echo "export PATH=\$PATH:${NGINX_PATH}" >> /etc/profile
fi
export PATH="$PATH:${NGINX_PATH}"
export CONF_FILE="/usr/local/openresty/nginx/conf/nginx.conf"
fi


if [ -f "$CONF_FILE" ]; then
    echo "==> Cai dat thu vien nginx-lua-prometheus..."
    opm get knyar/nginx-lua-prometheus

    echo "==> Cap nhat cau hinh nginx.conf cho metrics & security..."

    awk '
    # --- LUOT 1: Quet file kiem tra xem da ton tai shared_dict prometheus_metrics chua ---
    NR == FNR {
        if ($0 ~ /lua_shared_dict *prometheus_metrics/) {
            exists = 1
        }
        next
    }

    # --- LUOT 2: Chen cau hinh vao khoi http { neu chua co ---
    !exists && !done && /http *\{/ {
        print $0
        print "    # Khai bao shared memory cho cac chi so Prometheus"
        print "    lua_shared_dict prometheus_metrics 10M;"
        print "    "
        print "    # Khoi tao thu vien va dinh nghia Metrics"
        print "    init_by_lua_block {"
        print "        prometheus = require(\"prometheus\").init(\"prometheus_metrics\")"
        print "        "
        print "        -- Metric dem so luong HTTP request"
        print "        metric_requests = prometheus:counter("
        print "            \"nginx_http_requests_total\", \"Number of HTTP requests\", {\"host\", \"status\"}"
        print "        )"
        print "        -- Metric do thoi gian xu ly request (Latency)"
        print "        metric_latency = prometheus:histogram("
        print "            \"nginx_http_request_duration_seconds\", \"HTTP request latency\", {\"host\"}"
        print "        )"
        print "        -- Metric ghi nhan hanh vi bao mat (WAF, Rate limit, Scan, Ban)"
        print "        metric_security = prometheus:counter("
        print "            \"nginx_security_violations_total\", \"Security violations and blocked requests\", {\"action\", \"status\"}"
        print "        )"
        print "    }"
        print ""
        print "    # Dong bo hoa worker processes"
        print "    init_worker_by_lua_block {"
        print "        prometheus:init_worker()"
        print "    }"
        print ""
        done = 1
        next
    }
    
    { print }
    ' "$CONF_FILE" "$CONF_FILE" > "${CONF_FILE}.tmp" \
    && cp "$CONF_FILE" "${CONF_FILE}.bak" \
    && mv "${CONF_FILE}.tmp" "$CONF_FILE"

    echo "==> Tao Virtual Host phuc vu endpoint /metrics..."
    mkdir -p /usr/local/openresty/nginx/conf/sites-available
    mkdir -p /usr/local/openresty/nginx/conf/sites-enabled

    cat << 'EOF' > /usr/local/openresty/nginx/conf/sites-available/metrics.conf
server {
    listen 9145;
    allow 127.0.0.1;
    allow ::1;
    allow 172.30.0.0/24; # Only the dedicated Prometheus/OpenResty Compose network
    deny all;

    location /metrics {
        content_by_lua_block {
            prometheus:collect()
        }
    }
}
EOF

    ln -sfn /usr/local/openresty/nginx/conf/sites-available/metrics.conf /usr/local/openresty/nginx/conf/sites-enabled/metrics.conf

    echo "==> Kiem tra cu phap Nginx..."
    /usr/local/openresty/bin/openresty -t
else
    echo "Canh bao: Khong tim thay file $CONF_FILE"
    exit 1
fi

echo "==> Cai dat va khoi tao OpenResty metrics thanh cong!"