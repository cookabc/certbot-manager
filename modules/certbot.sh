#!/bin/bash

# Certbot module - Handles Certbot installation, uninstallation, etc.

# Source guard: Prevent duplicate loading
[[ -n "${_CERTBOT_SH_LOADED:-}" ]] && return 0
_CERTBOT_SH_LOADED=1

# Load base module
source "$MODULES_DIR/base.sh"

# Install certbot
install_certbot() {
    print_status "title" "Install Certbot"
    echo "=================================================="

    if command -v certbot &> /dev/null; then
        print_status "success" "Certbot is already installed"
        certbot --version
        return 0
    fi

    print_status "info" "Detecting OS and installing certbot..."
    
    local install_method=""
    if [[ -n "${CERTBOT_INSTALL_METHOD:-}" && "${CERTBOT_INSTALL_METHOD:-}" != "auto" ]]; then
        install_method="$CERTBOT_INSTALL_METHOD"
        print_status "info" "Using installation method from config: $install_method"
    fi

    if [[ -z "$install_method" ]]; then
        if [[ -f /etc/debian_version ]]; then
        print_status "info" "Detected Debian/Ubuntu system"
        if command -v snap &> /dev/null; then
            install_method="snap"
        else
            install_method="apt"
        fi
        if ! check_root; then
            print_status "warning" "Root privileges required for installation"
            print_status "info" "Please run: sudo $0 install"
            return 2
        fi
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        print_status "info" "Detected CentOS/RHEL system"
        install_method="yum"
        if ! check_root; then
            print_status "warning" "Root privileges required for installation"
            print_status "info" "Please run: sudo $0 install"
            return 2
        fi
    elif command -v brew &> /dev/null; then
        # macOS
        print_status "info" "Detected macOS, installing with brew"
        install_method="brew"
    else
        print_status "error" "Unsupported operating system"
        print_status "info" "Please install certbot manually: https://certbot.eff.org/"
        return 2
    fi
    fi

    # Confirm installation
    echo ""
    print_status "info" "About to install Certbot:"
    print_status "info" "  Method: $install_method"
    print_status "info" "  System type: $([ "$install_method" = "apt" ] && echo "Debian/Ubuntu" || [ "$install_method" = "yum" ] && echo "CentOS/RHEL" || echo "macOS")"
    echo ""

    confirm_action "Confirm installing Certbot?"
    if [[ $? -ne 0 ]]; then
        print_status "info" "Operation cancelled"
        return 2
    fi

    print_status "info" "Starting Certbot installation..."

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
        print_status "success" "Certbot installed successfully"
        certbot --version
        print_status "info" "You can now create SSL certificates!"
    else
        print_status "error" "Certbot installation failed"
        print_status "info" "Please check network connection and package manager configuration"
        return 1
    fi
}

# Uninstall certbot
uninstall_certbot() {
    print_status "title" "Uninstall Certbot"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "info" "Certbot is not installed, no need to uninstall"
        return 2
    fi

    # Get certbot version info
    local certbot_version
    certbot_version=$(certbot --version 2>/dev/null || echo "unknown version")
    print_status "info" "Current Certbot version: $certbot_version"

    # Warn user
    echo ""
    print_status "warning" "⚠️  Important notice:"
    print_status "warning" "  Uninstalling Certbot will:"
    print_status "warning" "  • Remove certbot program files"
    print_status "warning" "  • Delete all installed SSL certificates (optional)"
    print_status "warning" "  • Remove auto-renewal configuration"
    print_status "warning" "  This will cause all HTTPS websites to become inaccessible!"
    echo ""

    # Ask whether to delete certificates
    local delete_certs=false
    if confirm_action "Also delete all SSL certificates?"; then
        delete_certs=true
    else
        print_status "info" "Keeping SSL certificate files"
    fi

    # Final confirmation
    echo ""
    print_status "info" "Operations to be performed:"
    print_status "info" "  • Uninstall Certbot"
    if $delete_certs; then
        print_status "info" "  • Delete all SSL certificates"
    fi
    print_status "info" "  • Remove auto-renewal configuration"
    echo ""

    confirm_action "Confirm uninstalling Certbot? This action is irreversible!"
    if [[ $? -ne 0 ]]; then
        print_status "info" "Operation cancelled"
        return 2
    fi

    print_status "info" "Starting Certbot uninstallation..."

    # Choose uninstall method based on installation type
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        if check_root; then
            print_status "info" "Uninstalling with apt..."
            apt remove --purge -y certbot python3-certbot-nginx python3-certbot-apache 2>/dev/null || true
            apt autoremove -y 2>/dev/null || true
        else
            print_status "error" "Root privileges required for uninstallation"
            print_status "info" "Please run: sudo $0 uninstall"
            return 2
        fi
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL
        if check_root; then
            print_status "info" "Uninstalling with yum..."
            yum remove -y certbot python3-certbot-nginx python3-certbot-apache 2>/dev/null || true
        else
            print_status "error" "Root privileges required for uninstallation"
            print_status "info" "Please run: sudo $0 uninstall"
            return 2
        fi
    elif command -v brew &> /dev/null; then
        # macOS
        print_status "info" "Uninstalling with brew..."
        brew uninstall certbot 2>/dev/null || true
    else
        print_status "warning" "Cannot determine installation method, attempting manual cleanup..."
    fi

    # Delete certificate files
    if $delete_certs && check_root; then
        print_status "info" "Deleting SSL certificate files..."
        rm -rf "${LETSENCRYPT_DIR}" 2>/dev/null || true
    fi

    # Remove auto-renewal configuration
    if check_root; then
        print_status "info" "Removing auto-renewal configuration..."
        # Remove systemd timer
        systemctl stop certbot.timer 2>/dev/null || true
        systemctl disable certbot.timer 2>/dev/null || true
        rm -f /etc/systemd/system/certbot.service /etc/systemd/system/certbot.timer 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true

        # Remove cron jobs
        (crontab -l 2>/dev/null | grep -v "certbot renew") | crontab - 2>/dev/null || true
    fi

    # Verify uninstall result
    if ! command -v certbot &> /dev/null; then
        print_status "success" "Certbot uninstalled successfully!"
        if $delete_certs; then
            print_status "info" "SSL certificates deleted"
        else
            print_status "info" "SSL certificate files kept at ${LETSENCRYPT_DIR}/"
        fi
    else
        print_status "error" "Certbot uninstallation failed, please clean up manually"
        return 1
    fi
}
