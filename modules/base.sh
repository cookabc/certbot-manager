#!/bin/bash

# 基础架构模块 - 提供通用工具函数和基础配置

# Source guard: 防止重复加载
[[ -n "${_BASE_SH_LOADED:-}" ]] && return 0
_BASE_SH_LOADED=1

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

# 系统路径定义
LETSENCRYPT_DIR="/etc/letsencrypt"
NGINX_DIR="/etc/nginx"

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 日志记录函数
log_message() {
    local level=$1
    local message=$2
    
    # 检查是否配置了日志文件
    if [[ -n "${LOGGING_FILE:-}" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        # 确保日志目录存在
        local log_dir=$(dirname "$LOGGING_FILE")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || return
        fi
        
        # 写入日志
        echo "[$timestamp] [$level] $message" >> "$LOGGING_FILE" 2>/dev/null || true
    fi
}

# 显示带颜色的消息
print_status() {
    local status=$1
    local message=$2
    
    # 记录日志
    log_message "$status" "$message"

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
    # 先检查nginx是否可用
    if command -v nginx &> /dev/null; then
        # 检查certbot是否有nginx插件
        if certbot plugins 2>/dev/null | grep -q "nginx"; then
            # 不使用sudo检查配置，避免权限问题
            # 因为实际运行时certbot会使用sudo
            local nginx_conf_check
            nginx_conf_check=$(sudo nginx -c "${NGINX_DIR}/nginx.conf" -t 2>&1)
            if [[ $? -eq 0 ]]; then
                echo nginx
                return 0
            else
                print_status "warning" "Nginx配置无效: $nginx_conf_check"
                print_status "warning" "将使用standalone模式"
            fi
        else
            print_status "warning" "未检测到certbot nginx插件，将使用standalone模式"
        fi
    else
        print_status "warning" "未检测到Nginx，将使用standalone模式"
    fi
    echo standalone
    return 0
}

# 启动nginx服务
start_nginx() {
    if command -v systemctl &> /dev/null; then
        sudo systemctl start nginx
    elif command -v service &> /dev/null; then
        sudo service nginx start
    else
        sudo nginx
    fi
}

# 停止nginx服务
stop_nginx() {
    if command -v systemctl &> /dev/null; then
        sudo systemctl stop nginx
    elif command -v service &> /dev/null; then
        sudo service nginx stop
    else
        sudo nginx -s stop
    fi
}

# 检查nginx服务状态
check_nginx_status() {
    if command -v systemctl &> /dev/null; then
        systemctl is-active --quiet nginx
    elif command -v service &> /dev/null; then
        service nginx status &> /dev/null
    else
        ps aux | grep -q "[n]ginx: master process"
    fi
    return $?
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
    domain=${domain//$'－'/-}
    domain=${domain//$'．'/'.'}
    domain=${domain//$'。'/'.'}
    # 允许通配符域名（以*开头）
    # 简化正则表达式，确保正确匹配通配符域名
    if [[ "$domain" == \*.* ]] || [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        echo "$domain"
        return 0
    fi
    return 1
}

# 加载配置文件
load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        local current_section=""
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            # 忽略注释和空行
            [[ $key =~ ^#.* ]] && continue
            [[ -z $key ]] && continue
            
            # 处理section headers [section]
            if [[ $key =~ ^\[(.*)\]$ ]]; then
                current_section="${BASH_REMATCH[1]}"
                continue
            fi
            
            # 移除行内注释
            value=$(echo "$value" | sed 's/[[:space:]]*#.*//')
            # 移除首尾空格 (使用 sed 替代 xargs 避免引号/反斜杠被解析)
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [[ -n $current_section && -n $key ]]; then
                # 构造变量名: SECTION_KEY (大写)
                local var_name=$(echo "${current_section}_${key}" | tr '[:lower:]' '[:upper:]')
                # 安全检查: 只允许已知前缀的变量名，防止任意环境变量注入
                case "$var_name" in
                    CERTBOT_*|RENEWAL_*|NGINX_*|LOGGING_*|DNS_*)
                        export "$var_name"="$value"
                        ;;
                    *)
                        # 忽略未知配置项，避免注入风险
                        ;;
                esac
            fi
        done < "$config_file"
    fi
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