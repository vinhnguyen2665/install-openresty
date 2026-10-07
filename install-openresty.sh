#!/usr/bin/env bash
set -e

# Khai bao phien ban
export OPENRESTY_VERSION=1.31.1.1 
export NGINX_PATH="/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin"
export CONF_FILE="/usr/local/openresty/nginx/conf/nginx.conf"
echo "==> NGINX_PATH: $NGINX_PATH"

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
echo "==> Bat dau cai dat OpenResty phien ban ${OPENRESTY_VERSION}..."

# Buoc 1: Cai dat cac goi phu thuoc
echo "==> Cai dat cac goi phu thuoc..."
UBUNTU_VERSION=$(lsb_release -rs | cut -d. -f1)

EXTRA_CONFIGURE_FLAGS=""
if [ "$UBUNTU_VERSION" -lt 26 ]; then
    PCRE_PKG="libpcre3-dev"
else
    PCRE_PKG="libpcre2-dev"
    # EXTRA_CONFIGURE_FLAGS="--with-pcre2"
fi

apt-get update
apt-get install -y --no-install-recommends \
    build-essential \
    $PCRE_PKG \
    libssl-dev \
    zlib1g-dev \
    perl \
    make \
    curl \
    wget \
    iputils-ping \
    nano \
    net-tools \
    ca-certificates \
    git

# Buoc 2: Tai ma nguon OpenResty, giai nen, bien dich va cai dat
echo "==> Tai va bien dich ma nguon..."
mkdir -p /usr/local/src
cd /usr/local/src

wget "https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz" --no-check-certificate
tar -xzvf "openresty-${OPENRESTY_VERSION}.tar.gz"
cd "openresty-${OPENRESTY_VERSION}"

# Tận dụng số core CPU hiện có để build nhanh hơn
CPU_CORES=$(nproc)

# Đã bổ sung: SSL module, Stream module, stub_status và cờ PCRE2 (nếu có)
./configure \
    --prefix=/usr/local/openresty \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt="-O2" \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_v3_module \
    --with-http_auth_request_module \
    --with-threads \
    --with-file-aio \
    $EXTRA_CONFIGURE_FLAGS \
    -j"$CPU_CORES"

make -j"$CPU_CORES"
make install

# Don dep source code va cache
cd /usr/local/src
rm -rf "openresty-${OPENRESTY_VERSION}"*
apt-get clean

# Buoc 3: Cau hinh bien moi truong PATH
echo "==> Cau hinh bien moi truong PATH..."
if ! grep -q "/usr/local/openresty" /etc/profile; then
    echo "export PATH=\$PATH:${NGINX_PATH}" >> /etc/profile
fi
export PATH="$PATH:${NGINX_PATH}"

# Buoc 4: Cau hinh file nginx.conf
if [ -f "$CONF_FILE" ]; then
    echo "==> Cap nhat cau hinh nginx.conf..."

    # Tu dong nhan dien so luong CPU
    sed -i -E 's/^([[:space:]]*)(worker_processes[[:space:]]+[^;]+;)/# \1\2\n\1worker_processes  auto;/' "$CONF_FILE"

    # Su dung IP thuc cua client khi qua Cloudflare
    # sed -i '/default_type  application\/octet-stream;/a \ \n    map $http_cf_connecting_ip $real_client_ip {\n        default $http_cf_connecting_ip;\n        ""      $remote_addr;\n    }' "$CONF_FILE"

    # Tao san cac thu muc
    mkdir -p /usr/local/openresty/nginx/conf/conf.d \
             /usr/local/openresty/nginx/conf/sites-enabled \
             /usr/local/openresty/nginx/conf/sites-available \
             /usr/local/openresty/nginx/conf/includes

    # Install shared include files in both container and host installs.
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d /tmp/openresty-includes ]; then
        cp -ra /tmp/openresty-includes /usr/local/openresty/nginx/conf/
    elif [ -d "${SCRIPT_DIR}/includes" ]; then
        cp -ra "${SCRIPT_DIR}/includes" /usr/local/openresty/nginx/conf/
    fi

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

    # Kiem tra neu KHONG phai container VA KHONG phai docker compose
    if ! is_in_container && ! is_docker_compose; then
        # Xu ly khi dang chay truc tiep o may Host
        echo "==> Dang chay truc tiep tren may Host"
        echo "==> Shared includes installed for host deployment"
    fi

    # Tao san 1 file config mau/fallback de tranh loi glob include khi thu muc trong
    touch /usr/local/openresty/nginx/conf/conf.d/default.conf

    # Chen directive include mot lan, tranh lap lai khi chay script nhieu lan.
    if ! grep -Fq 'include /usr/local/openresty/nginx/conf/conf.d/*.conf;' "$CONF_FILE"; then
        sed -i '$s/}/    gzip  on;\n    include \/usr\/local\/openresty\/nginx\/conf\/conf.d\/*.conf;\n    include \/usr\/local\/openresty\/nginx\/conf\/sites-enabled\/*;\n}/' "$CONF_FILE"
    fi
else
    echo "Canh bao: Khong tim thay file $CONF_FILE"
fi

echo "==> Kiem tra cu phap Nginx:"
/usr/local/openresty/nginx/sbin/nginx -t

echo "==> Cai dat thanh cong OpenResty!"
