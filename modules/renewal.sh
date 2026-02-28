#!/bin/bash

# 自动续期模块 - 处理证书自动续期的设置

# Source guard: 防止重复加载
[[ -n "${_RENEWAL_SH_LOADED:-}" ]] && return 0
_RENEWAL_SH_LOADED=1

# 加载基础模块和系统检查模块
source "$MODULES_DIR/base.sh"
source "$MODULES_DIR/system.sh"

# 设置自动续期
setup_auto_renew() {
    print_status "title" "设置自动续期"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装"
        return 1
    fi

    if check_auto_renew; then
        print_status "success" "自动续期已设置"
        return 0
    fi
    
    local method=""
    if [[ -n "${RENEWAL_METHOD:-}" ]]; then
        method="${RENEWAL_METHOD:-}"
        print_status "info" "使用配置文件中的续期方式: $method"
    fi

    # 尝试使用systemd
    if [[ -z "$method" || "$method" == "systemd" ]]; then
    if command -v systemctl &> /dev/null && check_root; then
        print_status "info" "尝试使用systemd timer设置自动续期..."

        CERTBOT_BIN=$(command -v certbot || echo /usr/bin/certbot)
        cat > /etc/systemd/system/certbot.service << EOF
[Unit]
Description=Let's Encrypt renewal
[Service]
Type=oneshot
ExecStart=${CERTBOT_BIN} renew --post-hook "systemctl reload nginx"
EOF

        cat > /etc/systemd/system/certbot.timer << EOF
[Unit]
Description=Run certbot twice daily
[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=1h
Persistent=true
[Install]
WantedBy=timers.target
EOF

        systemctl daemon-reload
        systemctl enable --now certbot.timer

        if systemctl is-active --quiet certbot.timer; then
            print_status "success" "自动续期设置成功（systemd timer）"
            return 0
        fi
    fi
    fi

    # 备用方案：使用cron
    if [[ -z "$method" || "$method" == "cron" ]]; then
    if command -v crontab &> /dev/null; then
        print_status "info" "使用cron设置自动续期..."

        local cron_job
        cron_job="0 12 * * * $(command -v certbot || echo /usr/bin/certbot) renew --quiet"
        if crontab -l 2>/dev/null | grep -q "certbot renew"; then
            :
        else
            (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        fi

        if crontab -l 2>/dev/null | grep -q "certbot renew"; then
            print_status "success" "自动续期设置成功（cron）"
            return 0
        fi
    fi
    fi

    print_status "error" "自动续期设置失败"
    print_status "info" "请手动设置自动续期任务"
    return 1
}
