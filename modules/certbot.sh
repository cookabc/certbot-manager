#!/bin/bash

# Certbot管理模块 - 处理Certbot的安装、卸载等操作

# 加载基础模块
source "$MODULES_DIR/base.sh"

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
    if [[ -n "$CERTBOT_INSTALL_METHOD" && "$CERTBOT_INSTALL_METHOD" != "auto" ]]; then
        install_method="$CERTBOT_INSTALL_METHOD"
        print_status "info" "使用配置文件中的安装方式: $install_method"
    fi

    if [[ -z "$install_method" ]]; then
        if [[ -f /etc/debian_version ]]; then
        print_status "info" "检测到Debian/Ubuntu系统"
        if command -v snap &> /dev/null; then
            install_method="snap"
        else
            install_method="apt"
        fi
        if ! check_root; then
            print_status "warning" "需要root权限安装"
            print_status "info" "请运行: sudo $0 install"
            return 2
        fi
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        print_status "info" "检测到CentOS/RHEL系统"
        install_method="yum"
        if ! check_root; then
            print_status "warning" "需要root权限安装"
            print_status "info" "请运行: sudo $0 install"
            return 2
        fi
    elif command -v brew &> /dev/null; then
        # macOS
        print_status "info" "检测到macOS系统，使用brew安装"
        install_method="brew"
    else
        print_status "error" "不支持的操作系统"
        print_status "info" "请手动安装certbot: https://certbot.eff.org/"
        return 2
    fi
    fi

    # 确认安装
    echo ""
    print_status "info" "即将安装Certbot："
    print_status "info" "  安装方式: $install_method"
    print_status "info" "  系统类型: $([ "$install_method" = "apt" ] && echo "Debian/Ubuntu" || [ "$install_method" = "yum" ] && echo "CentOS/RHEL" || echo "macOS")"
    echo ""

    confirm_action "确认要安装Certbot吗？"
    if [[ $? -ne 0 ]]; then
        print_status "info" "操作已取消"
        return 2
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
        "snap")
            snap install certbot --classic
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

# 卸载certbot
uninstall_certbot() {
    print_status "title" "卸载Certbot"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "info" "Certbot未安装，无需卸载"
        return 2
    fi

    # 获取certbot版本信息
    local certbot_version
    certbot_version=$(certbot --version 2>/dev/null || echo "未知版本")
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
        delete_certs=true
    else
        print_status "info" "保留SSL证书文件"
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

    confirm_action "确认要卸载Certbot吗？此操作不可逆！"
    if [[ $? -ne 0 ]]; then
        print_status "info" "操作已取消"
        return 2
    fi

    print_status "info" "开始卸载Certbot..."

    # 根据安装方式选择卸载方法
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        if check_root; then
            print_status "info" "使用apt卸载..."
            apt remove --purge -y certbot python3-certbot-nginx python3-certbot-apache 2>/dev/null || true
            apt autoremove -y 2>/dev/null || true
        else
            print_status "error" "需要root权限进行卸载"
            print_status "info" "请运行: sudo $0 uninstall"
            return 2
        fi
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        if check_root; then
            print_status "info" "使用yum卸载..."
            yum remove -y certbot python3-certbot-nginx python3-certbot-apache 2>/dev/null || true
        else
            print_status "error" "需要root权限进行卸载"
            print_status "info" "请运行: sudo $0 uninstall"
            return 2
        fi
    elif command -v brew &> /dev/null; then
        # macOS
        print_status "info" "使用brew卸载..."
        brew uninstall certbot 2>/dev/null || true
    else
        print_status "warning" "无法确定安装方式，尝试手动清理..."
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
