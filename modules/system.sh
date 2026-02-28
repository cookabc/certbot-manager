#!/bin/bash

# 系统检查模块 - 检查系统状态和组件安装情况

# Source guard: 防止重复加载
[[ -n "${_SYSTEM_SH_LOADED:-}" ]] && return 0
_SYSTEM_SH_LOADED=1

# 加载基础模块
source "$MODULES_DIR/base.sh"

# 检查自动续期设置
# 返回: 0表示已设置，1表示未设置
check_auto_renew() {
    # 检查systemd timer
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet certbot.timer 2>/dev/null; then
            return 0
        fi
    fi

    # 检查cron任务
    if command -v crontab &> /dev/null; then
        if crontab -l 2>/dev/null | grep -q "certbot renew"; then
            return 0
        fi
    fi

    return 1
}

# 显示系统状态
show_system_status() {
    print_status "title" "系统状态检查"
    echo "=================================================="

    # 检查certbot
    if command -v certbot &> /dev/null; then
        print_status "success" "Certbot: 已安装"
        certbot_version=$(certbot --version 2>/dev/null | grep -o 'certbot [0-9.]*' || echo "")
        if [[ -n "$certbot_version" ]]; then
            echo "   版本: $certbot_version"
        fi
    else
        print_status "error" "Certbot: 未安装"
    fi

    # 检查nginx
    if command -v nginx &> /dev/null; then
        nginx_status="安装成功"
        if nginx -t &> /dev/null; then
            print_status "success" "Nginx: $nginx_status，配置正确"
        else
            print_status "warning" "Nginx: $nginx_status，但配置有错误"
        fi
    else
        print_status "error" "Nginx: 未安装"
    fi

    # 检查证书数量
    if command -v certbot &> /dev/null; then
        if check_root; then
            cert_count=$(certbot certificates 2>/dev/null | grep -c "Certificate Name:")
            print_status "info" "已安装证书数量: $cert_count"
            if check_auto_renew; then
                print_status "success" "自动续期: 已设置"
            else
                print_status "warning" "自动续期: 未设置"
            fi
        else
            if command -v sudo &> /dev/null; then
                cert_count=$(sudo certbot certificates 2>/dev/null | grep -c "Certificate Name:")
                print_status "info" "已安装证书数量: $cert_count"
                if check_auto_renew; then
                    print_status "success" "自动续期: 已设置"
                else
                    print_status "warning" "自动续期: 未设置"
                fi
            else
                print_status "warning" "需要sudo权限查看证书信息"
            fi
        fi
    fi

    echo ""
}