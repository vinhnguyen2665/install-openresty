FROM ubuntu:24.04

# dinh nghaa phien ban OpenResty muon cai dat thu nghiem
#export OPENRESTY_VERSION=1.31.1.1 
ENV OPENRESTY_VERSION=1.31.1.1 
ENV NGINX_PATH="/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin"
ENV PATH="$PATH:${NGINX_PATH}"
ENV CONF_FILE="/usr/local/openresty/nginx/conf/nginx.conf"

COPY install-openresty.sh /tmp/install-openresty.sh
COPY includes /tmp/openresty-includes
COPY init-config-openresty-metrics.sh /tmp/init-config-openresty-metrics.sh
RUN chmod +x /tmp/install-openresty.sh && /tmp/install-openresty.sh && rm -rf /tmp/install-openresty.sh /tmp/openresty-includes
RUN chmod +x /tmp/init-config-openresty-metrics.sh && /tmp/init-config-openresty-metrics.sh && rm /tmp/init-config-openresty-metrics.sh

# Thiet lap thu muc lam viec mac dinh khi truy cap vao container
WORKDIR /usr/local/openresty

# Giu container chay ngam (Detached mode) de lam LAB bang cach chay OpenResty o foreground
CMD ["openresty", "-g", "daemon off;"]
