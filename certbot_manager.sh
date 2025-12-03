#!/bin/bash

# ==============================================================================
# Certbot Manager - SSL证书管理工具
# ==============================================================================
# 版本: 1.0.0
# 作者: cookabc
# 仓库: https://github.com/cookabc/certbot-manager
# 描述: 纯Shell脚本工具，用于管理Let's Encrypt SSL证书
# 许可: MIT License
# ==============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 版本信息
VERSION="1.0.0"
GITHUB_REPO="https://github.com/cookabc/certbot-manager"

# 显示帮助信息
show_help() {
    echo "🔧 Certbot SSL证书管理工具 v$VERSION"
    echo ""
    echo "📦 GitHub仓库: $GITHUB_REPO"
    echo ""
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  status           显示系统状态"
    echo "  list             列出已安装证书"
    echo "  install          安装certbot"
    echo "  create <domain>  为域名创建SSL证书"
    echo "  renew            手动续期证书"
    echo "  renew-setup      设置自动续期"
    echo "  nginx-check      检查nginx配置"
    echo "  interactive      交互式菜单"
    echo "  version          显示版本信息"
    echo "  help             显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 status                     # 检查系统状态"
    echo "  $0 create example.com         # 创建证书"
    echo "  $0 interactive                # 启动交互式菜单"
    echo ""
}

# 显示版本信息
show_version() {
    echo "🔧 Certbot SSL证书管理工具"
    echo "版本: v$VERSION"
    echo "作者: cookabc"
    echo "仓库: $GITHUB_REPO"
    echo "许可: MIT License"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 显示带颜色的消息
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️ $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️ $message${NC}"
            ;;
        "title")
            echo -e "${PURPLE}🎯 $message${NC}"
            ;;
    esac
}

# 检查系统状态
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
            cert_count=$(sudo certbot certificates 2>/dev/null | grep "Certificate Name:" | wc -l | tr -d ' ')
            print_status "info" "已安装证书数量: $cert_count"

            # 检查自动续期
            if check_auto_renew; then
                print_status "success" "自动续期: 已设置"
            else
                print_status "warning" "自动续期: 未设置"
            fi
        else
            print_status "warning" "需要sudo权限查看证书信息"
        fi
    fi

    echo ""
}

# 检查自动续期设置
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

# 列出已安装证书
list_certificates() {
    print_status "title" "证书列表"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装，无法列出证书"
        return 1
    fi

    if ! check_root; then
        print_status "warning" "需要sudo权限查看证书列表"
        print_status "info" "请运行: sudo $0 list"
        return 1
    fi

    local cert_output=$(sudo certbot certificates 2>/dev/null)
    if [[ -z "$cert_output" || "$cert_output" == *"No certificates found"* ]]; then
        print_status "info" "暂无已安装的证书"
        return 0
    fi

    echo "$cert_output" | while IFS= read -r line; do
        if [[ "$line" == *"Certificate Name:"* ]]; then
            domain=$(echo "$line" | awk '{print $3}')
            echo ""
            print_status "info" "📋 证书域名: $domain"
        elif [[ "$line" == *"Expiry Date:"* ]]; then
            expiry=$(echo "$line" | sed 's/.*Expiry Date: //')
            echo "   到期时间: $expiry"
        elif [[ "$line" == *"Certificate Path:"* ]]; then
            cert_path=$(echo "$line" | sed 's/.*Certificate Path: //')
            echo "   证书路径: $cert_path"
        elif [[ "$line" == *"Private Key Path:"* ]]; then
            key_path=$(echo "$line" | sed 's/.*Private Key Path: //')
            echo "   私钥路径: $key_path"
        fi
    done
    echo ""
}

# 安装certbot
install_certbot() {
    print_status "title" "安装Certbot"
    echo "=================================================="

    if command -v certbot &> /dev/null; then
        print_status "success" "Certbot已安装"
        certbot --version
        return 0
    fi

    print_status "info" "检测操作系统并安装certbot..."

    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        print_status "info" "检测到Debian/Ubuntu系统"
        if check_root; then
            apt update
            apt install -y certbot python3-certbot-nginx
        else
            print_status "warning" "需要root权限安装"
            print_status "info" "请运行: sudo $0 install"
            return 1
        fi
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        print_status "info" "检测到CentOS/RHEL系统"
        if check_root; then
            yum install -y epel-release
            yum install -y certbot python3-certbot-nginx
        else
            print_status "warning" "需要root权限安装"
            print_status "info" "请运行: sudo $0 install"
            return 1
        fi
    elif command -v brew &> /dev/null; then
        # macOS
        print_status "info" "检测到macOS系统，使用brew安装"
        brew install certbot
    else
        print_status "error" "不支持的操作系统"
        print_status "info" "请手动安装certbot: https://certbot.eff.org/"
        return 1
    fi

    if command -v certbot &> /dev/null; then
        print_status "success" "Certbot安装成功"
        certbot --version
    else
        print_status "error" "Certbot安装失败"
        return 1
    fi
}

# 创建SSL证书
create_certificate() {
    local domain=$1
    if [[ -z "$domain" ]]; then
        print_status "error" "请提供域名: $0 create <domain>"
        return 1
    fi

    print_status "title" "创建SSL证书: $domain"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装，请先运行: $0 install"
        return 1
    fi

    # 获取邮箱
    read -p "请输入邮箱地址: " email
    if [[ -z "$email" ]]; then
        print_status "error" "邮箱地址不能为空"
        return 1
    fi

    # 检查nginx是否安装
    nginx_available=false
    if command -v nginx &> /dev/null; then
        nginx_available=true
        print_status "info" "检测到Nginx，将使用nginx插件"
    fi

    print_status "info" "开始为域名 $domain 创建SSL证书..."

    local cert_cmd=""
    if $nginx_available; then
        cert_cmd="sudo certbot --nginx --non-interactive --agree-tos --email $email -d $domain"
    else
        cert_cmd="sudo certbot certonly --standalone --non-interactive --agree-tos --email $email -d $domain"
    fi

    if eval "$cert_cmd"; then
        print_status "success" "SSL证书创建成功！"
        print_status "info" "证书文件位置: /etc/letsencrypt/live/$domain/"
    else
        print_status "error" "SSL证书创建失败"
        print_status "info" "请检查域名解析和防火墙设置"
        return 1
    fi
}

# 手动续期证书
renew_certificates() {
    print_status "title" "续期证书"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装"
        return 1
    fi

    if ! check_root; then
        print_status "warning" "需要sudo权限续期证书"
        print_status "info" "请运行: sudo $0 renew"
        return 1
    fi

    print_status "info" "开始续期证书..."

    if sudo certbot renew; then
        print_status "success" "证书续期成功！"
    else
        print_status "error" "证书续期失败"
        return 1
    fi
}

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

    # 尝试使用systemd
    if command -v systemctl &> /dev/null && check_root; then
        print_status "info" "尝试使用systemd timer设置自动续期..."

        # 创建systemd timer service
        cat > /etc/systemd/system/certbot.service << EOF
[Unit]
Description=Let's Encrypt renewal
[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --post-hook "systemctl reload nginx"
EOF

        # 创建systemd timer
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

    # 备用方案：使用cron
    if command -v crontab &> /dev/null; then
        print_status "info" "使用cron设置自动续期..."

        local cron_job="0 12 * * * /usr/bin/certbot renew --quiet"
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

        if crontab -l 2>/dev/null | grep -q "certbot renew"; then
            print_status "success" "自动续期设置成功（cron）"
            return 0
        fi
    fi

    print_status "error" "自动续期设置失败"
    print_status "info" "请手动设置自动续期任务"
    return 1
}

# 检查nginx配置
check_nginx() {
    print_status "title" "检查Nginx配置"
    echo "=================================================="

    if ! command -v nginx &> /dev/null; then
        print_status "error" "Nginx未安装"
        return 1
    fi

    print_status "info" "检查Nginx配置语法..."
    if nginx -t; then
        print_status "success" "Nginx配置语法正确"
    else
        print_status "error" "Nginx配置有语法错误"
        return 1
    fi

    # 显示nginx版本和配置文件位置
    echo ""
    print_status "info" "Nginx版本: $(nginx -v 2>&1 | cut -d' ' -f3)"
    print_status "info" "主配置文件: $(nginx -T 2>/dev/null | head -1 | grep -o '#.*' || echo '/etc/nginx/nginx.conf')"
}

# 交互式菜单
interactive_menu() {
    while true; do
        clear
        echo "🔧 Certbot SSL证书管理工具 v$VERSION"
        echo "=================================================="
        echo ""
        echo "请选择操作:"
        echo "1) 显示系统状态"
        echo "2) 列出已安装证书"
        echo "3) 安装certbot"
        echo "4) 创建SSL证书"
        echo "5) 续期证书"
        echo "6) 设置自动续期"
        echo "7) 检查nginx配置"
        echo "8) 帮助信息"
        echo "9) 退出"
        echo ""
        read -p "请输入选项 (1-9): " choice

        case $choice in
            1)
                show_system_status
                read -p "按回车键继续..."
                ;;
            2)
                list_certificates
                read -p "按回车键继续..."
                ;;
            3)
                install_certbot
                read -p "按回车键继续..."
                ;;
            4)
                read -p "请输入域名: " domain
                create_certificate "$domain"
                read -p "按回车键继续..."
                ;;
            5)
                renew_certificates
                read -p "按回车键继续..."
                ;;
            6)
                setup_auto_renew
                read -p "按回车键继续..."
                ;;
            7)
                check_nginx
                read -p "按回车键继续..."
                ;;
            8)
                show_help
                read -p "按回车键继续..."
                ;;
            9)
                print_status "info" "退出程序"
                exit 0
                ;;
            *)
                print_status "error" "无效选项，请重新选择"
                sleep 2
                ;;
        esac
    done
}

# 主函数
main() {
    case "${1:-interactive}" in
        "status")
            show_system_status
            ;;
        "list")
            list_certificates
            ;;
        "install")
            install_certbot
            ;;
        "create")
            create_certificate "$2"
            ;;
        "renew")
            renew_certificates
            ;;
        "renew-setup")
            setup_auto_renew
            ;;
        "nginx-check")
            check_nginx
            ;;
        "interactive")
            interactive_menu
            ;;
        "version"|"-v"|"--version")
            show_version
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_status "error" "未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@"