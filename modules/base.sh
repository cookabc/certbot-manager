#!/bin/bash

# Base module - Provides common utility functions and base configuration

# Source guard: Prevent duplicate loading
[[ -n "${_BASE_SH_LOADED:-}" ]] && return 0
_BASE_SH_LOADED=1

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Version information
VERSION="2.0.0"
GITHUB_REPO="https://github.com/cookabc/certbot-manager"

# System path definitions
LETSENCRYPT_DIR="/etc/letsencrypt"
NGINX_DIR="/etc/nginx"

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Logging function
log_message() {
    local level=$1
    local message=$2
    
    # Check if log file is configured
    if [[ -n "${LOGGING_FILE:-}" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        # Ensure log directory exists
        local log_dir=$(dirname "$LOGGING_FILE")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || return
        fi
        
        # Write to log
        echo "[$timestamp] [$level] $message" >> "$LOGGING_FILE" 2>/dev/null || true
    fi
}

# Display colored messages
print_status() {
    local status=$1
    local message=$2
    
    # Log the message
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

# Confirmation prompt function
confirm_action() {
    local message=$1

    while true; do
        echo -n "$message (y/n): "
        read -r confirm

        case "$confirm" in
            [yY]|[yY][eE][sS])
                return 0  # Return 0 means confirmed
                ;;
            [nN]|[nN][oO]|"")
                return 1  # Return 1 means cancelled
                ;;
            *)
                print_status "info" "Please enter y(yes) or n(no)"
                ;;
        esac
    done
}

# Detect certbot mode
# Returns: nginx or standalone
detect_certbot_mode() {
    # First check if nginx is available
    if command -v nginx &> /dev/null; then
        # Check if certbot has nginx plugin
        if certbot plugins 2>/dev/null | grep -q "nginx"; then
            # Don't check config with sudo to avoid permission issues
            # Because certbot will use sudo during actual execution
            local nginx_conf_check
            nginx_conf_check=$(sudo nginx -c "${NGINX_DIR}/nginx.conf" -t 2>&1)
            if [[ $? -eq 0 ]]; then
                echo nginx
                return 0
            else
                print_status "warning" "Nginx configuration invalid: $nginx_conf_check"
                print_status "warning" "Will use standalone mode"
            fi
        else
            print_status "warning" "Certbot nginx plugin not detected, will use standalone mode"
        fi
    else
        print_status "warning" "Nginx not detected, will use standalone mode"
    fi
    echo standalone
    return 0
}

# Start nginx service
start_nginx() {
    if command -v systemctl &> /dev/null; then
        sudo systemctl start nginx
    elif command -v service &> /dev/null; then
        sudo service nginx start
    else
        sudo nginx
    fi
}

# Stop nginx service
stop_nginx() {
    if command -v systemctl &> /dev/null; then
        sudo systemctl stop nginx
    elif command -v service &> /dev/null; then
        sudo service nginx stop
    else
        sudo nginx -s stop
    fi
}

# Check nginx service status
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

# Convert domain to Punycode (simplified)
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
    # Allow wildcard domains (starting with *)
    # Simplified regex to ensure correct wildcard domain matching
    if [[ "$domain" == \*.* ]] || [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        echo "$domain"
        return 0
    fi
    return 1
}

# Load configuration file
load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        local current_section=""
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            # Ignore comments and empty lines
            [[ $key =~ ^#.* ]] && continue
            [[ -z $key ]] && continue
            
            # Handle section headers [section]
            if [[ $key =~ ^\[(.*)\]$ ]]; then
                current_section="${BASH_REMATCH[1]}"
                continue
            fi
            
            # Remove inline comments
            value=$(echo "$value" | sed 's/[[:space:]]*#.*//')
            # Remove leading/trailing whitespace (using sed instead of xargs to avoid quotes/backslash being parsed)
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [[ -n $current_section && -n $key ]]; then
                # Construct variable name: SECTION_KEY (uppercase)
                local var_name=$(echo "${current_section}_${key}" | tr '[:lower:]' '[:upper:]')
                # Security check: Only allow known prefix variable names to prevent arbitrary env var injection
                case "$var_name" in
                    CERTBOT_*|RENEWAL_*|NGINX_*|LOGGING_*|DNS_*)
                        export "$var_name"="$value"
                        ;;
                    *)
                        # Ignore unknown config items to avoid injection risk
                        ;;
                esac
            fi
        done < "$config_file"
    fi
}

# Show help information
show_help() {
    echo "🔧 Certbot SSL Certificate Management Tool v$VERSION"
    echo ""
    echo "📦 GitHub Repository: $GITHUB_REPO"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status           Show system status"
    echo ""
    echo "Certbot Management:"
    echo "  install          Install certbot"
    echo "  uninstall        Uninstall certbot"
    echo ""
    echo "SSL Certificate Management:"
    echo "  list             List installed certificates"
    echo "  create <domain>  Create SSL certificate for domain"
    echo "  delete <domain>  Delete SSL certificate"
    echo "  renew            Manually renew certificates"
    echo "  renew-setup      Setup auto-renewal"
    echo "  nginx-check      Check nginx configuration"
    echo ""
    echo "Other:"
    echo "  help             Show help information"
    echo "  version          Show version information"
    echo ""
    echo "Examples:"
    echo "  $0 status                     # Check system status"
    echo "  $0 create example.com         # Create SSL certificate"
    echo "  $0 renew-setup                # Setup auto-renewal"
    echo ""
}