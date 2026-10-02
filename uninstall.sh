#!/usr/bin/env bash
set -e

# Yêu cầu quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script với quyền sudo hoặc root!"
  exit 1
fi

echo "==> Bắt đầu gỡ cài đặt OpenResty..."

# 1. Dừng các tiến trình OpenResty/Nginx đang chạy (nếu có)
echo "==> Dừng tiến trình OpenResty..."
if pgrep -f "/usr/local/openresty" > /dev/null; then
    pkill -9 -f "/usr/local/openresty" || true
    sleep 1
fi

# Tắt service systemd nếu trước đó bạn có tạo service
if systemctl is-active --quiet openresty 2>/dev/null; then
    systemctl stop openresty
    systemctl disable openresty || true
fi

# 2. Xóa service systemd (nếu tồn tại)
if [ -f "/etc/systemd/system/openresty.service" ]; then
    echo "==> Xóa systemd service..."
    rm -f /etc/systemd/system/openresty.service
    systemctl daemon-reload
fi

# 3. Xóa toàn bộ thư mục cài đặt OpenResty
if [ -d "/usr/local/openresty" ]; then
    echo "==> Xóa thư mục /usr/local/openresty..."
    rm -rf /usr/local/openresty
fi

# 4. Xóa tàn dư source code trong /usr/local/src (nếu còn sót)
echo "==> Dọn dẹp source tarball trong /usr/local/src..."
rm -rf /usr/local/src/openresty-*

# 5. Xóa cấu hình PATH trong /etc/profile
echo "==> Xóa cấu hình PATH trong /etc/profile..."
sed -i '\|/usr/local/openresty|d' /etc/profile

# 6. Xóa các symlink toàn cục (nếu trước đó có link vào /usr/bin hoặc /usr/sbin)
rm -f /usr/local/bin/openresty /usr/local/bin/nginx /usr/sbin/nginx /usr/bin/openresty

echo "==> Đã gỡ cài đặt hoàn toàn OpenResty!"
echo "Lưu ý: Chạy lệnh 'source /etc/profile' hoặc mở lại terminal mới để cập nhật lại biến PATH."