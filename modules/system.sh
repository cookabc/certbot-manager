#!/bin/bash

# System check module - Check system status and component installation

# Source guard: Prevent duplicate loading
[[ -n "${_SYSTEM_SH_LOADED:-}" ]] && return 0
_SYSTEM_SH_LOADED=1

# Load base module
source "$MODULES_DIR/base.sh"

# Check auto-renewal setup
# Returns: 0 if configured, 1 if not configured
check_auto_renew() {
    # Check systemd timer
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet certbot.timer 2>/dev/null; then
            return 0
        fi
    fi

    # Check cron jobs
    if command -v crontab &> /dev/null; then
        if crontab -l 2>/dev/null | grep -q "certbot renew"; then
            return 0
        fi
    fi

    return 1
}

# Show system status
show_system_status() {
    print_status "title" "System Status Check"
    echo "=================================================="

    # Check certbot
    if command -v certbot &> /dev/null; then
        print_status "success" "Certbot: Installed"
        certbot_version=$(certbot --version 2>/dev/null | grep -o 'certbot [0-9.]*' || echo "")
        if [[ -n "$certbot_version" ]]; then
            echo "   Version: $certbot_version"
        fi
    else
        print_status "error" "Certbot: Not installed"
    fi

    # Check nginx
    if command -v nginx &> /dev/null; then
        nginx_status="Installed"
        if nginx -t &> /dev/null; then
            print_status "success" "Nginx: $nginx_status, configuration valid"
        else
            print_status "warning" "Nginx: $nginx_status, but configuration has errors"
        fi
    else
        print_status "error" "Nginx: Not installed"
    fi

    # Check certificate count
    if command -v certbot &> /dev/null; then
        if check_root; then
            cert_count=$(certbot certificates 2>/dev/null | grep -c "Certificate Name:")
            print_status "info" "Installed certificates: $cert_count"
            if check_auto_renew; then
                print_status "success" "Auto-renewal: Configured"
            else
                print_status "warning" "Auto-renewal: Not configured"
            fi
        else
            if command -v sudo &> /dev/null; then
                cert_count=$(sudo certbot certificates 2>/dev/null | grep -c "Certificate Name:")
                print_status "info" "Installed certificates: $cert_count"
                if check_auto_renew; then
                    print_status "success" "Auto-renewal: Configured"
                else
                    print_status "warning" "Auto-renewal: Not configured"
                fi
            else
                print_status "warning" "Sudo privileges required to view certificate information"
            fi
        fi
    fi

    echo ""
}