#!/bin/bash

# 基础架构模块 - 提供通用工具函数和基础配置

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 版本信息
VERSION="2.0.0"
GITHUB_REPO="https://github.com/cookabc/certbot-manager"

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
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "title")
            echo -e "${PURPLE}🎯 $message${NC}"
            ;;
    esac
}

# 确认操作函数
confirm_action() {
    local message=$1

    while true; do
        echo -n "$message (y/n): "
        read -r confirm

        case "$confirm" in
            [yY]|[yY][eE][sS])
                return 0  # 返回码0表示确认
                ;;
            [nN]|[nN][oO]|"")
                return 1  # 返回码1表示取消
                ;;
            *)
                print_status "info" "请输入 y(是) 或 n(否)"
                ;;
        esac
    done
}

# 检测certbot模式
# 返回: nginx 或 standalone
detect_certbot_mode() {
    if command -v nginx &> /dev/null; then
        if certbot plugins 2>/dev/null | grep -q "nginx"; then
            echo nginx
            return 0
        fi
    fi
    echo standalone
    return 0
}

# 域名转换为Punycode（简化版）
convert_to_punycode() {
    local domain=$1
    domain=${domain//$'\r'/}
    domain=${domain//$'\u200b'/}
    domain=${domain//$'\ufeff'/}
    domain=${domain//$'\u00a0'/}
    domain=${domain//$'\u00ad'/}
    domain=${domain//$'\u200d'/}
    domain=${domain//$'\u2060'/}
    domain=${domain//$'\u180e'/}
    domain=${domain//$'\u2010'/-}
    domain=${domain//$'\u2011'/-}
    domain=${domain//$'\u2012'/-}
    domain=${domain//$'\u2013'/-}
    domain=${domain//$'\u2014'/-}
    domain=${domain//$'\u2212'/-}
    domain=${domain//$'\uff0d'/-}
    domain=${domain//$'\uff0e'/'.'}
    domain=${domain//$'\u3002'/'.'}
    if [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] && [[ ! "$domain" =~ ^\. ]] && [[ ! "$domain" =~ \.$ ]] && [[ ! "$domain" =~ \.\. ]]; then
        echo "$domain"
        return 0
    fi
    return 1
}

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
    echo ""
    echo "Certbot管理:"
    echo "  install          安装certbot"
    echo "  uninstall        卸载certbot"
    echo ""
    echo "SSL证书管理:"
    echo "  list             列出已安装证书"
    echo "  create <domain>  为域名创建SSL证书"
    echo "  delete <domain>  卸载SSL证书"
    echo "  renew            手动续期证书"
    echo "  renew-setup      设置自动续期"
    echo "  nginx-check      检查nginx配置"
    echo ""
    echo "其他:"
    echo "  help             显示帮助信息"
    echo "  version          显示版本信息"
    echo ""
    echo "示例:"
    echo "  $0 status                     # 检查系统状态"
    echo "  $0 create example.com         # 创建SSL证书"
    echo "  $0 renew-setup                # 设置自动续期"
    echo ""
}