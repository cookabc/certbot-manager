#!/bin/bash

# Certbot Manager - SSL Certificate Management Tool
# Version: v2.0.0

set -euo pipefail

# Load all modules
MODULES_DIR="$(dirname "$0")/modules"

# Check if modules directory exists
if [[ ! -d "$MODULES_DIR" ]]; then
    echo "❌ Error: modules directory not found"
    echo "Please make sure you are running this script in the correct directory"
    exit 1
fi

# Load base module
source "$MODULES_DIR/base.sh"

# Load other modules
source "$MODULES_DIR/system.sh"
source "$MODULES_DIR/certbot.sh"
source "$MODULES_DIR/certificate.sh"
source "$MODULES_DIR/renewal.sh"

# Load configuration file
CONFIG_FILE="$(dirname "$0")/config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    load_config "$CONFIG_FILE"
fi

# Show version information
show_version() {
    echo "🔧 Certbot SSL Certificate Management Tool"
    echo "Version: v$VERSION"
    echo "Author: cookabc"
    echo "Repository: $GITHUB_REPO"
    echo "License: MIT License"
}

# Main function
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
            print_status "error" "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Script entry point
main "$@"
