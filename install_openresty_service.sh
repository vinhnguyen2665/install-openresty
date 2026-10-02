#!/bin/bash

# Đường dẫn mặc định của OpenResty (hãy sửa lại nếu bạn cài ở thư mục khác)
OPENRESTY_PATH="/usr/local/openresty"
SERVICE_FILE="/etc/systemd/system/openresty.service"

echo "=== Đang khởi tạo file service systemd cho OpenResty ==="

# Tạo file service
sudo bash -c "cat << 'EOF' > $SERVICE_FILE
[Unit]
Description=The OpenResty Application Server
After=syslog.target network-online.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=${OPENRESTY_PATH}/nginx/logs/nginx.pid
ExecStartPre=${OPENRESTY_PATH}/nginx/sbin/nginx -t
ExecStart=${OPENRESTY_PATH}/nginx/sbin/nginx
ExecReload=${OPENRESTY_PATH}/nginx/sbin/nginx -s reload
ExecStop=${OPENRESTY_PATH}/nginx/sbin/nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF"

echo "=== Đang nạp lại cấu hình systemd ==="
sudo systemctl daemon-reload

echo "=== Kích hoạt OpenResty khởi động cùng hệ thống ==="
sudo systemctl enable openresty

echo "=== Khởi chạy dịch vụ OpenResty ==="
sudo systemctl start openresty

echo "=== Kiểm tra trạng thái service ==="
sudo systemctl status openresty
