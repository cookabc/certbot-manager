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
    echo ""
    echo "Certbot管理:"
    echo "  install          安装certbot"
    echo "  uninstall        卸载certbot"
    echo "  reinstall         重新安装certbot"
    echo ""
    echo "SSL证书管理:"
    echo "  list             列出已安装证书"
    echo "  create <domain>  为域名创建SSL证书"
    echo "  cert-uninstall <domain>  卸载SSL证书"
    echo "  cert-reinstall <domain> 重新安装SSL证书"
    echo "  renew            手动续期证书"
    echo "  renew-setup      设置自动续期"
    echo "  nginx-check      检查nginx配置"
    echo ""
    echo "其他:"
    echo "  interactive      交互式菜单（推荐）"
    echo "  version          显示版本信息"
    echo "  help             显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 interactive                # 启动交互式菜单（推荐）"
    echo "  $0 status                     # 检查系统状态"
    echo "  $0 create example.com         # 创建证书"
    echo "  $0 cert-uninstall example.com # 卸载证书"
    echo "  $0 renew-setup                # 设置自动续期"
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

# 通用用户输入函数，支持返回和取消
get_user_input() {
    local prompt=$1
    local allow_empty=${2:-false}  # 是否允许空输入
    local input_type=${3:-"text"}  # 输入类型：text/email/domain
    local user_input

    while true; do
        echo -n "$prompt"
        read -r user_input

        # 检查返回操作
        if [[ "$user_input" == "back" || "$user_input" == "返回" || "$user_input" == "b" || "$user_input" == "B" ]]; then
            return 1  # 返回码1表示返回
        fi

        # 检查取消操作
        if [[ "$user_input" == "cancel" || "$user_input" == "取消" || "$user_input" == "c" || "$user_input" == "C" || "$user_input" == "q" || "$user_input" == "Q" ]]; then
            return 2  # 返回码2表示取消
        fi

        # 检查是否为空
        if [[ -z "$user_input" ]]; then
            if $allow_empty; then
                echo "$user_input"
                return 0
            else
                print_status "error" "输入不能为空，请重新输入"
                print_status "info" "提示: 输入 'back' 返回上级菜单，输入 'cancel' 取消操作"
                continue
            fi
        fi

        # 根据类型验证输入
        case "$input_type" in
            "email")
                if [[ ! "$user_input" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    print_status "error" "邮箱格式不正确，请重新输入"
                    print_status "info" "提示: 输入 'back' 返回上级菜单，输入 'cancel' 取消操作"
                    continue
                fi
                ;;
            "domain")
                if [[ ! "$user_input" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
                    print_status "error" "域名格式不正确，请重新输入"
                    print_status "info" "提示: 输入 'back' 返回上级菜单，输入 'cancel' 取消操作"
                    continue
                fi
                ;;
        esac

        echo "$user_input"
        return 0
    done
}

# 确认操作函数
confirm_action() {
    local message=$1
    local default=${2:-"n"}  # 默认值

    while true; do
        echo -n "$message (y/n/取消): "
        read -r confirm

        # 检查取消操作
        if [[ "$confirm" == "cancel" || "$confirm" == "取消" || "$confirm" == "c" || "$confirm" == "C" || "$confirm" == "q" || "$confirm" == "Q" ]]; then
            return 2  # 返回码2表示取消
        fi

        case "$confirm" in
            [yY]|[yY][eE][sS])
                return 0  # 返回码0表示确认
                ;;
            [nN]|[nN][oO]|"")
                return 1  # 返回码1表示取消
                ;;
            *)
                print_status "info" "请输入 y(是), n(否) 或 cancel(取消)"
                ;;
        esac
    done
}

# 显示操作提示
show_operation_tips() {
    print_status "info" "💡 操作提示:"
    print_status "info" "   • 输入 'back' 或 '返回' - 返回上级菜单"
    print_status "info" "   • 输入 'cancel' 或 '取消' - 取消当前操作"
    print_status "info" "   • 输入 'q' 或 'Q' - 快速退出"
    echo ""
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

    local install_method=""

    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        print_status "info" "检测到Debian/Ubuntu系统"
        install_method="apt"
        if ! check_root; then
            print_status "warning" "需要root权限安装"
            print_status "info" "请运行: sudo $0 install"
            read -p "按回车键返回..."
            return 2
        fi
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        print_status "info" "检测到CentOS/RHEL系统"
        install_method="yum"
        if ! check_root; then
            print_status "warning" "需要root权限安装"
            print_status "info" "请运行: sudo $0 install"
            read -p "按回车键返回..."
            return 2
        fi
    elif command -v brew &> /dev/null; then
        # macOS
        print_status "info" "检测到macOS系统，使用brew安装"
        install_method="brew"
    else
        print_status "error" "不支持的操作系统"
        print_status "info" "请手动安装certbot: https://certbot.eff.org/"
        read -p "按回车键返回..."
        return 2
    fi

    # 确认安装
    echo ""
    print_status "info" "即将安装Certbot："
    print_status "info" "  安装方式: $install_method"
    print_status "info" "  系统类型: $([ "$install_method" = "apt" ] && echo "Debian/Ubuntu" || [ "$install_method" = "yum" ] && echo "CentOS/RHEL" || echo "macOS")"
    echo ""

    if ! confirm_action "确认要安装Certbot吗？"; then
        case $? in
            1) print_status "info" "操作已取消"; return 2 ;;
            2) print_status "warning" "操作已取消"; return 2 ;;
        esac
    fi

    print_status "info" "开始安装Certbot..."

    case "$install_method" in
        "apt")
            apt update && apt install -y certbot python3-certbot-nginx
            ;;
        "yum")
            yum install -y epel-release && yum install -y certbot python3-certbot-nginx
            ;;
        "brew")
            brew install certbot
            ;;
    esac

    if command -v certbot &> /dev/null; then
        print_status "success" "Certbot安装成功"
        certbot --version
        print_status "info" "现在可以创建SSL证书了！"
    else
        print_status "error" "Certbot安装失败"
        print_status "info" "请检查网络连接和包管理器配置"
        return 1
    fi
}

# 创建SSL证书
create_certificate() {
    local domain=$1

    print_status "title" "创建SSL证书"
    echo "=================================================="

    # 显示操作提示
    show_operation_tips

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装，请先运行: $0 install"
        read -p "按回车键返回..."
        return 2
    fi

    # 如果没有提供域名，则交互式获取
    if [[ -z "$domain" ]]; then
        if ! domain=$(get_user_input "请输入域名: " false "domain"); then
            case $? in
                1) print_status "info" "返回上级菜单"; return 2 ;;
                2) print_status "warning" "操作已取消"; return 2 ;;
            esac
        fi
    fi

    # 获取邮箱地址
    print_status "info" "请输入用于Let's Encrypt的邮箱地址"
    if ! email=$(get_user_input "邮箱地址: " false "email"); then
        case $? in
            1) print_status "info" "返回上级菜单"; return 2 ;;
            2) print_status "warning" "操作已取消"; return 2 ;;
        esac
    fi

    # 检查nginx是否安装
    nginx_available=false
    if command -v nginx &> /dev/null; then
        nginx_available=true
        print_status "info" "检测到Nginx，将使用nginx插件自动配置SSL"
    else
        print_status "info" "未检测到Nginx，将使用standalone模式（需要停止Web服务器）"
    fi

    # 确认操作
    echo ""
    print_status "info" "即将创建SSL证书："
    print_status "info" "  域名: $domain"
    print_status "info" "  邮箱: $email"
    print_status "info" "  模式: $([ "$nginx_available" = true ] && echo "Nginx插件" || echo "Standalone模式")"
    echo ""

    if ! confirm_action "确认要创建SSL证书吗？"; then
        case $? in
            1) print_status "info" "操作已取消"; return 2 ;;
            2) print_status "warning" "操作已取消"; return 2 ;;
        esac
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
        print_status "info" "请确保Nginx配置正确指向证书文件"
    else
        print_status "error" "SSL证书创建失败"
        print_status "info" "请检查以下问题："
        print_status "info" "  • 域名是否正确解析到此服务器"
        print_status "info" "  • 防火墙是否开放80和443端口"
        print_status "info" "  • 如果使用standalone模式，请确保80端口未被占用"
        return 1
    fi
}

# 卸载certbot
uninstall_certbot() {
    print_status "title" "卸载Certbot"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "info" "Certbot未安装，无需卸载"
        read -p "按回车键返回..."
        return 2
    fi

    # 获取certbot版本信息
    local certbot_version=$(certbot --version 2>/dev/null || echo "未知版本")
    print_status "info" "当前Certbot版本: $certbot_version"

    # 警告用户
    echo ""
    print_status "warning" "⚠️  重要提醒："
    print_status "warning" "  卸载Certbot将会："
    print_status "warning" "  • 删除certbot程序文件"
    print_status "warning" "  • 删除所有已安装的SSL证书（可选）"
    print_status "warning" "  • 移除自动续期配置"
    print_status "warning" "  这将导致所有HTTPS网站无法访问！"
    echo ""

    # 询问是否删除证书
    local delete_certs=false
    if confirm_action "是否同时删除所有SSL证书？"; then
        case $? in
            0) delete_certs=true ;;
            1|2) print_status "info" "保留SSL证书文件" ;;
        esac
    fi

    # 最终确认
    echo ""
    print_status "info" "即将执行的操作："
    print_status "info" "  • 卸载Certbot程序"
    if $delete_certs; then
        print_status "info" "  • 删除所有SSL证书"
    fi
    print_status "info" "  • 移除自动续期配置"
    echo ""

    if ! confirm_action "确认要卸载Certbot吗？此操作不可逆！"; then
        case $? in
            1) print_status "info" "操作已取消"; return 2 ;;
            2) print_status "warning" "操作已取消"; return 2 ;;
        esac
    fi

    print_status "info" "开始卸载Certbot..."

    local uninstall_success=false

    # 根据安装方式选择卸载方法
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        if check_root; then
            print_status "info" "使用apt卸载..."
            apt remove --purge -y certbot python3-certbot-nginx python3-certbot-apache 2>/dev/null || true
            apt autoremove -y 2>/dev/null || true
            uninstall_success=true
        else
            print_status "error" "需要root权限进行卸载"
            print_status "info" "请运行: sudo $0 uninstall"
            read -p "按回车键返回..."
            return 2
        fi
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        if check_root; then
            print_status "info" "使用yum卸载..."
            yum remove -y certbot python3-certbot-nginx python3-certbot-apache 2>/dev/null || true
            uninstall_success=true
        else
            print_status "error" "需要root权限进行卸载"
            print_status "info" "请运行: sudo $0 uninstall"
            read -p "按回车键返回..."
            return 2
        fi
    elif command -v brew &> /dev/null; then
        # macOS
        print_status "info" "使用brew卸载..."
        brew uninstall certbot 2>/dev/null || true
        uninstall_success=true
    else
        print_status "warning" "无法确定安装方式，尝试手动清理..."
        uninstall_success=true
    fi

    # 删除证书文件
    if $delete_certs && check_root; then
        print_status "info" "删除SSL证书文件..."
        rm -rf /etc/letsencrypt 2>/dev/null || true
    fi

    # 移除自动续期配置
    if check_root; then
        print_status "info" "移除自动续期配置..."
        # 移除systemd timer
        systemctl stop certbot.timer 2>/dev/null || true
        systemctl disable certbot.timer 2>/dev/null || true
        rm -f /etc/systemd/system/certbot.service /etc/systemd/system/certbot.timer 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true

        # 移除cron任务
        (crontab -l 2>/dev/null | grep -v "certbot renew") | crontab - 2>/dev/null || true
    fi

    # 验证卸载结果
    if ! command -v certbot &> /dev/null; then
        print_status "success" "Certbot卸载成功！"
        if $delete_certs; then
            print_status "info" "SSL证书已删除"
        else
            print_status "info" "SSL证书文件保留在 /etc/letsencrypt/"
        fi
    else
        print_status "error" "Certbot卸载失败，请手动清理"
        return 1
    fi
}

# 重新安装certbot
reinstall_certbot() {
    print_status "title" "重新安装Certbot"
    echo "=================================================="

    print_status "info" "重新安装将会："
    print_status "info" "  • 完全卸载当前的Certbot"
    print_status "info" "  • 重新安装最新版本的Certbot"
    print_status "warning" "⚠️  这可能会影响现有的SSL证书"
    echo ""

    if ! confirm_action "确认要重新安装Certbot吗？"; then
        case $? in
            1) print_status "info" "操作已取消"; return 2 ;;
            2) print_status "warning" "操作已取消"; return 2 ;;
        esac
    fi

    # 先卸载
    if command -v certbot &> /dev/null; then
        print_status "info" "正在卸载现有Certbot..."
        uninstall_certbot
        local uninstall_result=$?
        if [[ $uninstall_result -eq 1 ]]; then
            print_status "error" "卸载失败，重新安装终止"
            return 1
        fi
    fi

    # 重新安装
    print_status "info" "正在重新安装Certbot..."
    install_certbot
    local install_result=$?

    if [[ $install_result -eq 0 ]]; then
        print_status "success" "Certbot重新安装成功！"
        print_status "info" "现在可以重新配置SSL证书了"
    else
        print_status "error" "重新安装失败"
        return 1
    fi
}

# Certbot管理子菜单
certbot_management() {
    while true; do
        clear
        echo "🔧 Certbot SSL证书管理工具 - Certbot管理"
        echo "=================================================="
        echo ""
        echo "请选择操作:"
        echo "1) 安装Certbot"
        echo "2) 卸载Certbot"
        echo "3) 重新安装Certbot"
        echo "4) 返回主菜单"
        echo ""
        echo "💡 提示: 在任何输入步骤中都可以输入 'back' 返回或 'cancel' 取消"
        echo ""
        read -p "请输入选项 (1-4): " choice

        case $choice in
            1)
                install_certbot
                local install_result=$?
                if [[ $install_result -eq 2 ]]; then
                    continue
                fi
                read -p "按回车键继续..."
                ;;
            2)
                uninstall_certbot
                local uninstall_result=$?
                if [[ $uninstall_result -eq 2 ]]; then
                    continue
                fi
                read -p "按回车键继续..."
                ;;
            3)
                reinstall_certbot
                local reinstall_result=$?
                if [[ $reinstall_result -eq 2 ]]; then
                    continue
                fi
                read -p "按回车键继续..."
                ;;
            4)
                return 0
                ;;
            "q"|"Q"|"back"|"返回")
                print_status "info" "返回主菜单"
                return 0
                ;;
            *)
                print_status "error" "无效选项，请重新选择"
                sleep 2
                ;;
        esac
    done
}

# 列出所有证书供选择
list_certificates_for_selection() {
    print_status "info" "获取已安装的证书列表..."

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装"
        return 1
    fi

    if ! check_root; then
        print_status "warning" "需要sudo权限查看证书列表"
        print_status "info" "请运行: sudo $0 cert-uninstall"
        return 1
    fi

    local cert_output=$(sudo certbot certificates 2>/dev/null)
    if [[ -z "$cert_output" || "$cert_output" == *"No certificates found"* ]]; then
        print_status "info" "暂无已安装的证书"
        return 1
    fi

    local domains=()
    while IFS= read -r line; do
        if [[ "$line" == *"Certificate Name:"* ]]; then
            domain=$(echo "$line" | awk '{print $3}')
            domains+=("$domain")
        fi
    done <<< "$cert_output"

    if [[ ${#domains[@]} -eq 0 ]]; then
        print_status "info" "暂无已安装的证书"
        return 1
    fi

    print_status "info" "已安装的证书："
    for i in "${!domains[@]}"; do
        echo "  $((i+1))) ${domains[i]}"
    done

    # 返回域名数组
    printf '%s\n' "${domains[@]}"
    return 0
}

# 卸载SSL证书
uninstall_certificate() {
    local domain=$1

    print_status "title" "卸载SSL证书"
    echo "=================================================="

    if [[ -n "$domain" ]]; then
        # 命令行模式，直接使用指定域名
        local target_domain="$domain"
    else
        # 交互式模式，让用户选择证书
        print_status "info" "选择要卸载的SSL证书："
        local domains=()
        readarray -t domains < <(list_certificates_for_selection)

        if [[ ${#domains[@]} -eq 0 ]]; then
            read -p "按回车键返回..."
            return 2
        fi

        echo ""
        if ! target_domain=$(get_user_input "请输入要卸载的域名或编号: " false "domain"); then
            case $? in
                1) print_status "info" "返回上级菜单"; return 2 ;;
                2) print_status "warning" "操作已取消"; return 2 ;;
            esac
        fi

        # 如果输入的是编号，转换为域名
        if [[ "$target_domain" =~ ^[0-9]+$ ]]; then
            local index=$((target_domain - 1))
            if [[ $index -ge 0 && $index -lt ${#domains[@]} ]]; then
                target_domain="${domains[$index]}"
            else
                print_status "error" "无效的编号"
                read -p "按回车键返回..."
                return 2
            fi
        fi

        # 验证域名是否在列表中
        local found=false
        for d in "${domains[@]}"; do
            if [[ "$d" == "$target_domain" ]]; then
                found=true
                break
            fi
        done

        if ! $found; then
            print_status "error" "域名 $target_domain 没有对应的SSL证书"
            read -p "按回车键返回..."
            return 2
        fi
    fi

    # 显示证书信息
    print_status "info" "即将卸载的SSL证书："
    print_status "info" "  域名: $target_domain"
    print_status "info" "  证书路径: /etc/letsencrypt/live/$target_domain/"
    print_status "info" "  配置文件: /etc/letsencrypt/renewal/$target_domain.conf"
    echo ""

    # 警告信息
    print_status "warning" "⚠️  重要提醒："
    print_status "warning" "  卸载SSL证书将会："
    print_status "warning" "  • 删除证书文件"
    print_status "warning" "  • 删除私钥文件"
    print_status "warning" "  • 移除续期配置"
    print_status "warning" "  • 需要手动更新Nginx配置"
    print_status "warning" "  这将导致HTTPS网站无法访问！"
    echo ""

    # 确认操作
    if ! confirm_action "确认要卸载域名 $target_domain 的SSL证书吗？"; then
        case $? in
            1) print_status "info" "操作已取消"; return 2 ;;
            2) print_status "warning" "操作已取消"; return 2 ;;
        esac
    fi

    print_status "info" "开始卸载SSL证书..."

    if ! check_root; then
        print_status "error" "需要root权限进行卸载"
        print_status "info" "请运行: sudo $0 cert-uninstall $target_domain"
        read -p "按回车键返回..."
        return 2
    fi

    # 删除证书文件
    print_status "info" "删除证书文件..."
    if sudo certbot delete --cert-name "$target_domain" 2>/dev/null; then
        print_status "success" "SSL证书卸载成功！"
        print_status "info" "证书文件已从系统中删除"
        print_status "warning" "请记得手动更新Nginx配置文件，移除SSL相关配置"
        print_status "info" "Nginx配置通常位于: /etc/nginx/sites-available/ 或 /etc/nginx/conf.d/"
    else
        # 备用方案：手动删除
        print_status "warning" "使用certbot delete失败，尝试手动删除..."

        local cert_dir="/etc/letsencrypt/live/$target_domain"
        local archive_dir="/etc/letsencrypt/archive/$target_domain"
        local renewal_file="/etc/letsencrypt/renewal/$target_domain.conf"

        sudo rm -rf "$cert_dir" 2>/dev/null || true
        sudo rm -rf "$archive_dir" 2>/dev/null || true
        sudo rm -f "$renewal_file" 2>/dev/null || true

        print_status "success" "SSL证书手动删除完成"
        print_status "warning" "请记得手动更新Nginx配置"
    fi

    # 检查nginx配置并建议修改
    if command -v nginx &> /dev/null; then
        echo ""
        print_status "info" "建议的后续操作："
        print_status "info" "1. 编辑Nginx配置文件，移除SSL配置"
        print_status "info" "2. 重新加载Nginx配置: sudo nginx -s reload"
        print_status "info" "3. 测试网站访问是否正常"
    fi
}

# 重新安装SSL证书
reinstall_certificate() {
    local domain=$1

    print_status "title" "重新安装SSL证书"
    echo "=================================================="

    if [[ -n "$domain" ]]; then
        # 命令行模式，直接使用指定域名
        local target_domain="$domain"
    else
        # 交互式模式，让用户选择证书
        print_status "info" "选择要重新安装的SSL证书："
        local domains=()
        readarray -t domains < <(list_certificates_for_selection)

        if [[ ${#domains[@]} -eq 0 ]]; then
            print_status "info" "没有找到可以重新安装的证书"
            print_status "info" "您可以创建新的SSL证书"
            read -p "按回车键返回..."
            return 2
        fi

        echo ""
        if ! target_domain=$(get_user_input "请输入要重新安装的域名或编号: " false "domain"); then
            case $? in
                1) print_status "info" "返回上级菜单"; return 2 ;;
                2) print_status "warning" "操作已取消"; return 2 ;;
            esac
        fi

        # 如果输入的是编号，转换为域名
        if [[ "$target_domain" =~ ^[0-9]+$ ]]; then
            local index=$((target_domain - 1))
            if [[ $index -ge 0 && $index -lt ${#domains[@]} ]]; then
                target_domain="${domains[$index]}"
            else
                print_status "error" "无效的编号"
                read -p "按回车键返回..."
                return 2
            fi
        fi

        # 验证域名是否在列表中
        local found=false
        for d in "${domains[@]}"; do
            if [[ "$d" == "$target_domain" ]]; then
                found=true
                break
            fi
        done

        if ! $found; then
            print_status "error" "域名 $target_domain 没有对应的SSL证书"
            read -p "按回车键返回..."
            return 2
        fi
    fi

    print_status "info" "重新安装SSL证书将会："
    print_status "info" "  • 先删除现有的SSL证书"
    print_status "info" "  • 重新创建新的SSL证书"
    print_status "warning" "⚠️  这将暂时影响HTTPS访问"
    echo ""

    # 确认操作
    if ! confirm_action "确认要重新安装域名 $target_domain 的SSL证书吗？"; then
        case $? in
            1) print_status "info" "操作已取消"; return 2 ;;
            2) print_status "warning" "操作已取消"; return 2 ;;
        esac
    fi

    # 先删除现有证书
    print_status "info" "正在删除现有SSL证书..."
    uninstall_certificate "$target_domain"
    local uninstall_result=$?

    if [[ $uninstall_result -eq 1 ]]; then
        print_status "error" "删除现有证书失败，重新安装终止"
        return 1
    fi

    echo ""
    print_status "info" "正在重新创建SSL证书..."

    # 重新创建证书
    create_certificate "$target_domain"
    local install_result=$?

    if [[ $install_result -eq 0 ]]; then
        print_status "success" "SSL证书重新安装成功！"
        print_status "info" "新证书已安装并配置完成"
    else
        print_status "error" "SSL证书重新安装失败"
        return 1
    fi
}

# 证书管理子菜单
certificate_management() {
    while true; do
        clear
        echo "🔧 Certbot SSL证书管理工具 - 证书管理"
        echo "=================================================="
        echo ""
        echo "请选择操作:"
        echo "1) 列出已安装证书"
        echo "2) 安装SSL证书"
        echo "3) 卸载SSL证书"
        echo "4) 重新安装SSL证书"
        echo "5) 续期证书"
        echo "6) 设置自动续期"
        echo "7) 检查nginx配置"
        echo "8) 返回主菜单"
        echo ""
        echo "💡 提示: 在任何输入步骤中都可以输入 'back' 返回或 'cancel' 取消"
        echo ""
        read -p "请输入选项 (1-8): " choice

        case $choice in
            1)
                list_certificates
                read -p "按回车键继续..."
                ;;
            2)
                create_certificate ""
                local install_result=$?
                if [[ $install_result -eq 2 ]]; then
                    continue
                fi
                read -p "按回车键继续..."
                ;;
            3)
                uninstall_certificate ""
                local uninstall_result=$?
                if [[ $uninstall_result -eq 2 ]]; then
                    continue
                fi
                read -p "按回车键继续..."
                ;;
            4)
                reinstall_certificate ""
                local reinstall_result=$?
                if [[ $reinstall_result -eq 2 ]]; then
                    continue
                fi
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
                return 0
                ;;
            "q"|"Q"|"back"|"返回")
                print_status "info" "返回主菜单"
                return 0
                ;;
            *)
                print_status "error" "无效选项，请重新选择"
                sleep 2
                ;;
        esac
    done
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
        echo "2) Certbot管理"
        echo "3) 证书管理"
        echo "4) 创建SSL证书"
        echo "5) 帮助信息"
        echo "6) 退出"
        echo ""
        echo "💡 提示: 在任何输入步骤中都可以输入 'back' 返回或 'cancel' 取消"
        echo ""
        read -p "请输入选项 (1-6): " choice

        case $choice in
            1)
                show_system_status
                read -p "按回车键继续..."
                ;;
            2)
                certbot_management
                ;;
            3)
                certificate_management
                ;;
            4)
                create_certificate ""
                local cert_result=$?
                if [[ $cert_result -eq 2 ]]; then
                    # 用户取消或返回，直接返回菜单
                    continue
                fi
                read -p "按回车键继续..."
                ;;
            5)
                show_help
                read -p "按回车键继续..."
                ;;
            6)
                if confirm_action "确定要退出程序吗？"; then
                    print_status "info" "退出程序"
                    exit 0
                fi
                ;;
            "q"|"Q")
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
        "uninstall")
            uninstall_certbot
            ;;
        "reinstall")
            reinstall_certbot
            ;;
        "create")
            create_certificate "$2"
            ;;
        "cert-uninstall")
            uninstall_certificate "$2"
            ;;
        "cert-reinstall")
            reinstall_certificate "$2"
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