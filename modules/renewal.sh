#!/bin/bash

# Auto-renewal module - Handles certificate auto-renewal setup

# Source guard: Prevent duplicate loading
[[ -n "${_RENEWAL_SH_LOADED:-}" ]] && return 0
_RENEWAL_SH_LOADED=1

# Load base module and system check module
source "$MODULES_DIR/base.sh"
source "$MODULES_DIR/system.sh"

# Setup auto-renewal
setup_auto_renew() {
    print_status "title" "Setup Auto-Renewal"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot is not installed"
        return 1
    fi

    if check_auto_renew; then
        print_status "success" "Auto-renewal is already configured"
        return 0
    fi
    
    local method=""
    if [[ -n "${RENEWAL_METHOD:-}" ]]; then
        method="${RENEWAL_METHOD:-}"
        print_status "info" "Using renewal method from config: $method"
    fi

    # Try using systemd
    if [[ -z "$method" || "$method" == "systemd" ]]; then
    if command -v systemctl &> /dev/null && check_root; then
        print_status "info" "Attempting to setup auto-renewal with systemd timer..."

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
            print_status "success" "Auto-renewal setup successful (systemd timer)"
            return 0
        fi
    fi
    fi

    # Fallback: use cron
    if [[ -z "$method" || "$method" == "cron" ]]; then
    if command -v crontab &> /dev/null; then
        print_status "info" "Setting up auto-renewal with cron..."

        local cron_job
        cron_job="0 12 * * * $(command -v certbot || echo /usr/bin/certbot) renew --quiet"
        if crontab -l 2>/dev/null | grep -q "certbot renew"; then
            :
        else
            (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        fi

        if crontab -l 2>/dev/null | grep -q "certbot renew"; then
            print_status "success" "Auto-renewal setup successful (cron)"
            return 0
        fi
    fi
    fi

    print_status "error" "Auto-renewal setup failed"
    print_status "info" "Please set up auto-renewal manually"
    return 1
}
