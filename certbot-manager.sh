#!/bin/bash

# Certbot Manager - SSL证书管理工具
# 版本: v2.0.0

set -euo pipefail

# 加载所有模块
MODULES_DIR="$(dirname "$0")/modules"

# 检查modules目录是否存在
if [[ ! -d "$MODULES_DIR" ]]; then
    echo "❌ 错误: 找不到modules目录"
    echo "请确保您在正确的目录中运行此脚本"
    exit 1
fi

# 加载基础模块
source "$MODULES_DIR/base.sh"

# 加载其他模块
source "$MODULES_DIR/system.sh"
source "$MODULES_DIR/certbot.sh"
source "$MODULES_DIR/certificate.sh"
source "$MODULES_DIR/renewal.sh"

# 加载配置文件
CONFIG_FILE="$(dirname "$0")/config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    load_config "$CONFIG_FILE"
fi

# 显示版本信息
show_version() {
    echo "🔧 Certbot SSL证书管理工具"
    echo "版本: v$VERSION"
    echo "作者: cookabc"
    echo "仓库: $GITHUB_REPO"
    echo "许可: MIT License"
}

# 主函数
main() {
    case "${1:-help}" in
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
        "create")
            create_certificate "${2:-}"
            ;;
        "delete")
            uninstall_certificate "${2:-}"
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
