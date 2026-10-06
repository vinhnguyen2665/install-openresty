#!/usr/bin/env bash
set -e

CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --clean|-c|clean)
            CLEAN=true
            ;;
        --help|-h)
            echo "Cách dùng: $0 [--clean]"
            echo "  --clean, -c, clean : Xóa sạch hoàn toàn OpenResty bao gồm tất cả file cấu hình (như cũ)."
            echo "  (Mặc định)         : Giữ sites-available, sites-enabled; đổi conf.d -> conf.d.old, includes -> includes.old."
            exit 0
            ;;
        *)
            echo "Tham số không hợp lệ: $arg"
            echo "Cách dùng: $0 [--clean]"
            exit 1
            ;;
    esac
done

# Yêu cầu quyền root
if [ "$EUID" -ne 0 ]; then
  echo "Vui lòng chạy script với quyền sudo hoặc root!"
  exit 1
fi

if [ "$CLEAN" = true ]; then
    echo "==> Bắt đầu gỡ cài đặt OpenResty (chế độ clean: xóa sạch toàn bộ)..."
else
    echo "==> Bắt đầu gỡ cài đặt OpenResty (mặc định: giữ sites-available, sites-enabled; lưu backup conf.d.old, includes.old)..."
fi

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

# 3. Xử lý thư mục cài đặt OpenResty
OPENRESTY_DIR="/usr/local/openresty"
CONF_DIR="${OPENRESTY_DIR}/nginx/conf"

if [ -d "$OPENRESTY_DIR" ]; then
    if [ "$CLEAN" = true ]; then
        echo "==> Xóa toàn bộ thư mục ${OPENRESTY_DIR}..."
        rm -rf "$OPENRESTY_DIR"
    else
        echo "==> Xử lý thư mục ${OPENRESTY_DIR} (giữ cấu hình)..."
        TEMP_BACKUP=$(mktemp -d /tmp/openresty-backup.XXXXXX)

        # Giữ lại sites-available và sites-enabled
        if [ -d "${CONF_DIR}/sites-available" ]; then
            echo "    - Giữ lại sites-available"
            mv "${CONF_DIR}/sites-available" "${TEMP_BACKUP}/sites-available"
        fi
        if [ -d "${CONF_DIR}/sites-enabled" ]; then
            echo "    - Giữ lại sites-enabled"
            mv "${CONF_DIR}/sites-enabled" "${TEMP_BACKUP}/sites-enabled"
        fi

        # conf.d move thành conf.d.old
        if [ -d "${CONF_DIR}/conf.d" ]; then
            echo "    - Di chuyển conf.d -> conf.d.old"
            mv "${CONF_DIR}/conf.d" "${TEMP_BACKUP}/conf.d.old"
        elif [ -d "${CONF_DIR}/conf.d.old" ]; then
            mv "${CONF_DIR}/conf.d.old" "${TEMP_BACKUP}/conf.d.old"
        fi

        # includes move thành includes.old
        if [ -d "${CONF_DIR}/includes" ]; then
            echo "    - Di chuyển includes -> includes.old"
            mv "${CONF_DIR}/includes" "${TEMP_BACKUP}/includes.old"
        elif [ -d "${CONF_DIR}/includes.old" ]; then
            mv "${CONF_DIR}/includes.old" "${TEMP_BACKUP}/includes.old"
        fi

        # Xóa các thành phần còn lại của OpenResty
        echo "==> Xóa các thành phần OpenResty trong ${OPENRESTY_DIR}..."
        rm -rf "$OPENRESTY_DIR"

        # Khôi phục các thư mục cấu hình đã lưu
        if [ -d "${TEMP_BACKUP}/sites-available" ] || [ -d "${TEMP_BACKUP}/sites-enabled" ] || \
           [ -d "${TEMP_BACKUP}/conf.d.old" ] || [ -d "${TEMP_BACKUP}/includes.old" ]; then
            mkdir -p "$CONF_DIR"
            [ -d "${TEMP_BACKUP}/sites-available" ] && mv "${TEMP_BACKUP}/sites-available" "${CONF_DIR}/"
            [ -d "${TEMP_BACKUP}/sites-enabled" ] && mv "${TEMP_BACKUP}/sites-enabled" "${CONF_DIR}/"
            [ -d "${TEMP_BACKUP}/conf.d.old" ] && mv "${TEMP_BACKUP}/conf.d.old" "${CONF_DIR}/"
            [ -d "${TEMP_BACKUP}/includes.old" ] && mv "${TEMP_BACKUP}/includes.old" "${CONF_DIR}/"
        fi

        rm -rf "$TEMP_BACKUP"
    fi
fi

# 4. Xóa tàn dư source code trong /usr/local/src (nếu còn sót)
echo "==> Dọn dẹp source tarball trong /usr/local/src..."
rm -rf /usr/local/src/openresty-*

# 5. Xóa cấu hình PATH trong /etc/profile
echo "==> Xóa cấu hình PATH trong /etc/profile..."
sed -i '\|/usr/local/openresty|d' /etc/profile

# 6. Xóa các symlink toàn cục (nếu trước đó có link vào /usr/bin hoặc /usr/sbin)
rm -f /usr/local/bin/openresty /usr/local/bin/nginx /usr/sbin/nginx /usr/bin/openresty

if [ "$CLEAN" = true ]; then
    echo "==> Đã gỡ cài đặt hoàn toàn OpenResty (chế độ clean)!"
else
    echo "==> Đã gỡ cài đặt OpenResty!"
    echo "    (Đã giữ: sites-available, sites-enabled; lưu backup: conf.d.old, includes.old tại ${CONF_DIR})"
fi
echo "Lưu ý: Chạy lệnh 'source /etc/profile' hoặc mở lại terminal mới để cập nhật lại biến PATH."