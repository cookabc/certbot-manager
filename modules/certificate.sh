#!/bin/bash

# Certificate module - Handles certificate creation, listing, renewal, and deletion

# Source guard: Prevent duplicate loading
[[ -n "${_CERTIFICATE_SH_LOADED:-}" ]] && return 0
_CERTIFICATE_SH_LOADED=1

# Load base module and system check module
source "$MODULES_DIR/base.sh"
source "$MODULES_DIR/system.sh"

# List all certificates for selection
list_certificates_for_selection() {
    print_status "info" "Fetching installed certificate list..." >&2

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot is not installed" >&2
        return 1
    fi

    local cert_output
    if check_root; then
        cert_output=$(certbot certificates 2>/dev/null)
    elif command -v sudo &> /dev/null; then
        cert_output=$(sudo certbot certificates 2>/dev/null)
    else
        print_status "warning" "Sudo privileges required to view certificate list" >&2
        print_status "info" "Please run: sudo $0 list" >&2
        return 1
    fi
    if [[ -z "$cert_output" || "$cert_output" == *"No certificates found"* ]]; then
        print_status "info" "No certificates installed" >&2
        return 1
    fi

    local domains=()
    local domain
    while IFS= read -r line; do
        if [[ "$line" == *"Certificate Name:"* ]]; then
            domain=${line#*Certificate Name: }
            domain=${domain%% *}
            domains+=("$domain")
        fi
    done <<< "$cert_output"

    if [[ ${#domains[@]} -eq 0 ]]; then
        print_status "info" "No certificates installed" >&2
        return 1
    fi

    # Output only plain domain list to stdout
    printf '%s\n' "${domains[@]}"
    return 0
}

# List installed certificates
list_certificates() {
    print_status "title" "Certificate List"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot is not installed, cannot list certificates"
        return 1
    fi

    local cert_output
    if check_root; then
        cert_output=$(certbot certificates 2>/dev/null)
    elif command -v sudo &> /dev/null; then
        cert_output=$(sudo certbot certificates 2>/dev/null)
    else
        print_status "warning" "Sudo privileges required to view certificate list"
        print_status "info" "Please run: sudo $0 list"
        return 1
    fi
    if [[ -z "$cert_output" || "$cert_output" == *"No certificates found"* ]]; then
        print_status "info" "No certificates installed"
        return 0
    fi

    while IFS= read -r line; do
        if [[ "$line" == *"Certificate Name:"* ]]; then
            domain=${line#*Certificate Name: }
            domain=${domain%% *}
            echo ""
            print_status "info" "📋 Certificate domain: $domain"
        elif [[ "$line" == *"Expiry Date:"* ]]; then
            expiry=${line#*Expiry Date: }
            echo "   Expiry date: $expiry"
        elif [[ "$line" == *"Certificate Path:"* ]]; then
            cert_path=${line#*Certificate Path: }
            echo "   Certificate path: $cert_path"
        elif [[ "$line" == *"Private Key Path:"* ]]; then
            key_path=${line#*Private Key Path: }
            echo "   Private key path: $key_path"
        fi
    done <<< "$cert_output"
    echo ""
}

# Create SSL certificate
create_certificate() {
    local domain=$1

    print_status "title" "Create SSL Certificate"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot is not installed, please run first: $0 install"
        return 2
    fi

    # If no domain provided, get it interactively
    if [[ -z "$domain" ]]; then
        echo -n "Enter the domain for certificate issuance: "
        read -r domain
        if [[ -z "$domain" ]]; then
            print_status "error" "Domain cannot be empty"
            return 2
        fi
    fi

    if domain=$(convert_to_punycode "$domain"); then
        :
    else
        print_status "error" "Domain is not in ASCII format, please enter an ASCII domain"
        return 2
    fi

    # Validate domain format (stricter validation)
    # Support wildcard *.example.com
    if [[ ! "$domain" =~ ^(\*\.)?([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        # Exclude localhost
        if [[ "$domain" != "localhost" ]]; then
             print_status "warning" "Domain format may be non-standard, please verify: $domain"
        fi
    fi

    # Get email address
    local email=""
    if [[ -n "${CERTBOT_EMAIL:-}" ]]; then
        email="${CERTBOT_EMAIL:-}"
        print_status "info" "Using email from config: $email"
    else
        echo -n "Enter the email address for Let's Encrypt: "
        read -r email
    fi
    
    if [[ -z "$email" ]]; then
        print_status "error" "Email address cannot be empty"
        return 2
    fi

    # Validate email format
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_status "error" "Invalid email format"
        return 2
    fi

    nginx_available=false
    mode=$(detect_certbot_mode)
    
    local dns_plugin_mode=false
    local dns_plugin_name=""
    local dns_credentials_file=""
    
    # Check if wildcard domain
    if [[ "$domain" == \*.* ]]; then
        print_status "warning" "Wildcard domain detected, DNS validation required"
        
        # Check if DNS plugin is configured
        if [[ -n "${CERTBOT_DNS_PLUGIN:-}" ]]; then
             dns_plugin_name="$CERTBOT_DNS_PLUGIN"
             dns_credentials_file="${CERTBOT_DNS_CREDENTIALS:-}"
             dns_plugin_mode=true
             mode="dns-plugin"
             print_status "info" "Using configured DNS plugin: $dns_plugin_name"
        else
             print_status "warning" "Nginx plugin does not support DNS validation, will use manual mode"
             mode="manual"
        fi
        
        nginx_available=false
    else
        # Recheck Nginx config to ensure correct mode selection
        if [[ "$mode" == "nginx" ]]; then
            # Check if nginx config is valid
            local nginx_conf_check
            nginx_conf_check=$(sudo nginx -c "${NGINX_DIR}/nginx.conf" -t 2>&1)
            if [[ $? -eq 0 ]]; then
                nginx_available=true
                print_status "info" "Nginx and plugin detected, will use nginx plugin"
            else
                print_status "warning" "Nginx configuration invalid, forcing standalone mode"
                mode="standalone"
            fi
        else
            if command -v nginx &> /dev/null; then
                print_status "info" "Nginx detected but plugin not installed or config invalid, using standalone mode"
            else
                print_status "info" "Nginx not detected, will use standalone mode (requires stopping web server)"
            fi
        fi
    fi

    # Confirm operation
    echo ""
    print_status "title" "Certificate Information Confirmation"
    echo "=================================================="
    echo "📍 Domain: $domain"
    echo "📧 Email: $email"
    # Display the current mode correctly
    local mode_display
    if $dns_plugin_mode; then
        mode_display="DNS Plugin Mode ($dns_plugin_name)"
    elif [[ "$domain" == \*.* ]]; then
        mode_display="Manual Mode (DNS Validation)"
    elif $nginx_available; then
        mode_display="Nginx Plugin"
    else
        mode_display="Standalone Mode"
    fi
    echo "🔧 Mode: $mode_display"
    echo "=================================================="
    echo ""

    confirm_action "Confirm creating SSL certificate?"
    if [[ $? -ne 0 ]]; then
        print_status "info" "Operation cancelled"
        return 2
    fi

    print_status "info" "Starting SSL certificate creation for domain $domain..."

    local success=false
    local nginx_was_running=false
    
    # Check if nginx is running
    if check_nginx_status; then
        nginx_was_running=true
    fi
    
    # Handle wildcard domains
    if [[ "$domain" == \*.* ]]; then
        if $dns_plugin_mode; then
            print_status "info" "Verifying with DNS plugin..."
            local cmd=(certbot certonly --non-interactive --agree-tos --email "$email" -d "$domain" "--dns-${dns_plugin_name}")
            
            if [[ -n "$dns_credentials_file" ]]; then
                cmd+=("--dns-${dns_plugin_name}-credentials" "$dns_credentials_file")
            fi
            
            if check_root; then
                if "${cmd[@]}"; then success=true; fi
            elif command -v sudo &> /dev/null; then
                if sudo "${cmd[@]}"; then success=true; fi
            else
                print_status "error" "Sudo privileges required to configure certificate"
                return 1
            fi
        else
            print_status "info" "Wildcard domain requires DNS validation, will use manual mode"
            print_status "info" "The system will prompt you to add DNS records, please have your DNS management panel ready"
            
            # Wildcard domains require DNS validation, using manual mode
            if check_root; then
                if certbot certonly --manual --preferred-challenges dns --agree-tos --email "$email" -d "$domain"; then success=true; fi
            elif command -v sudo &> /dev/null; then
                if sudo certbot certonly --manual --preferred-challenges dns --agree-tos --email "$email" -d "$domain"; then success=true; fi
            else
                print_status "error" "Sudo privileges required to configure certificate"
                return 1
            fi
        fi
    elif $nginx_available; then
        # Use nginx plugin mode
        if check_root; then
            if certbot --nginx --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        elif command -v sudo &> /dev/null; then
            if sudo certbot --nginx --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        else
            print_status "error" "Sudo privileges required to configure certificate"
            return 1
        fi
    else
        # Use standalone mode, need to stop nginx service
        if $nginx_was_running; then
            print_status "info" "Stopping nginx service for standalone mode..."
            stop_nginx
        fi
        
        if check_root; then
            if certbot certonly --standalone --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        elif command -v sudo &> /dev/null; then
            if sudo certbot certonly --standalone --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        else
            print_status "error" "Sudo privileges required to configure certificate"
            return 1
        fi
        
        # If nginx was running before, restart it
        if $nginx_was_running; then
            print_status "info" "Restarting nginx service..."
            start_nginx
        fi
    fi

    if $success; then
        print_status "success" "SSL certificate created successfully!"
        # Fix certificate file location display for wildcard domains
        local cert_dir=$(sudo certbot certificates 2>/dev/null | grep -A 1 "Certificate Name: ${domain//\*/\*}" | grep "Certificate Path:" | awk '{print $3}' | sed 's/cert.pem$//' || echo "${LETSENCRYPT_DIR}/live/${domain//\*/\*}/")
        print_status "info" "Certificate file location: $cert_dir"
        print_status "info" "Please ensure Nginx configuration points to the certificate files correctly"
    else
        print_status "error" "SSL certificate creation failed"
        print_status "info" "Please check the following:"
        print_status "info" "  • Is the domain correctly resolved to this server"
        print_status "info" "  • Are ports 80 and 443 open in the firewall"
        print_status "info" "  • If using standalone mode, ensure port 80 is not in use"
        return 1
    fi
}

# Uninstall SSL certificate
uninstall_certificate() {
    local domain=$1

    print_status "title" "Uninstall SSL Certificate"
    echo "=================================================="

    if [[ -n "$domain" ]]; then
        # Command-line mode, use specified domain directly
        local target_domain="$domain"
    else
        # Interactive mode, let user select certificate
        print_status "info" "Select SSL certificate to uninstall:"
        local domains=()
        readarray -t domains < <(list_certificates_for_selection)

        if [[ ${#domains[@]} -eq 0 ]]; then
            return 3
        fi

        print_status "info" "Installed certificates:"
        for i in "${!domains[@]}"; do
            echo "  $((i+1))) ${domains[i]}"
        done

        echo -n "Enter the domain or number to uninstall: "
        read -r target_domain
        if [[ -z "$target_domain" ]]; then
            print_status "error" "Input cannot be empty"
            return 2
        fi

        # If input is a number, convert to domain
        if [[ "$target_domain" =~ ^[0-9]+$ ]]; then
            local index=$((target_domain - 1))
            if [[ $index -ge 0 && $index -lt ${#domains[@]} ]]; then
                target_domain="${domains[$index]}"
            else
                print_status "error" "Invalid number"
                return 2
            fi
        fi

        # Verify domain is in the list
        local found=false
        for d in "${domains[@]}"; do
            if [[ "$d" == "$target_domain" ]]; then
                found=true
                break
            fi
        done

        if ! $found; then
            print_status "error" "Domain $target_domain has no corresponding SSL certificate"
            return 2
        fi
    fi

    # Show certificate info
    print_status "info" "SSL certificate to be uninstalled:"
    print_status "info" "  Domain: $target_domain"
    print_status "info" "  Certificate path: ${LETSENCRYPT_DIR}/live/$target_domain/"
    print_status "info" "  Config file: ${LETSENCRYPT_DIR}/renewal/$target_domain.conf"
    echo ""

    # Warning information
    print_status "warning" "⚠️  Important notice:"
    print_status "warning" "  Uninstalling SSL certificate will:"
    print_status "warning" "  • Delete certificate files"
    print_status "warning" "  • Delete private key files"
    print_status "warning" "  • Remove renewal configuration"
    print_status "warning" "  • Nginx configuration needs to be updated manually"
    print_status "warning" "  This will cause HTTPS websites to become inaccessible!"
    echo ""

    # Confirm operation
    confirm_action "Confirm uninstalling SSL certificate for domain $target_domain?"
    if [[ $? -ne 0 ]]; then
        print_status "info" "Operation cancelled"
        return 2
    fi

    print_status "info" "Starting SSL certificate uninstallation..."

    if ! check_root; then
        print_status "error" "Root privileges required for uninstallation"
        print_status "info" "Please run: sudo $0 delete $target_domain"
        return 2
    fi

    # Delete certificate files
    print_status "info" "Deleting certificate files..."
    if certbot delete --cert-name "$target_domain" 2>/dev/null; then
        print_status "success" "SSL certificate uninstalled successfully!"
        print_status "info" "Certificate files have been removed from the system"
        print_status "warning" "Remember to manually update Nginx configuration files and remove SSL-related settings"
        print_status "info" "Nginx config is usually located at: ${NGINX_DIR}/sites-available/ or ${NGINX_DIR}/conf.d/"
    else
        # Fallback: manual deletion
        print_status "warning" "certbot delete failed, attempting manual deletion..."

        local cert_dir="${LETSENCRYPT_DIR}/live/$target_domain"
        local archive_dir="${LETSENCRYPT_DIR}/archive/$target_domain"
        local renewal_file="${LETSENCRYPT_DIR}/renewal/$target_domain.conf"

        rm -rf "$cert_dir" 2>/dev/null || true
        rm -rf "$archive_dir" 2>/dev/null || true
        rm -f "$renewal_file" 2>/dev/null || true

        print_status "success" "SSL certificate manually deleted"
        print_status "warning" "Remember to manually update Nginx configuration"
    fi
}

# Manually renew certificates
renew_certificates() {
    print_status "title" "Renew Certificates"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot is not installed"
        return 1
    fi

    print_status "info" "Starting certificate renewal..."

    if check_root; then
        if certbot renew; then
            print_status "success" "Certificate renewal successful!"
        else
            print_status "error" "Certificate renewal failed"
            return 1
        fi
    elif command -v sudo &> /dev/null; then
        if sudo certbot renew; then
            print_status "success" "Certificate renewal successful!"
        else
            print_status "error" "Certificate renewal failed"
            return 1
        fi
    else
        print_status "warning" "Sudo privileges required to renew certificates"
        print_status "info" "Please run: sudo $0 renew"
        return 1
    fi
}

# Check nginx configuration
check_nginx() {
    print_status "title" "Check Nginx Configuration"
    echo "=================================================="

    if ! command -v nginx &> /dev/null; then
        print_status "error" "Nginx is not installed"
        return 1
    fi

    print_status "info" "Checking Nginx configuration syntax..."
    if nginx -t; then
        print_status "success" "Nginx configuration syntax is correct"
    else
        print_status "error" "Nginx configuration has syntax errors"
        return 1
    fi

    # Show nginx version and config file location
    echo ""
    print_status "info" "Nginx version: $(nginx -v 2>&1 | cut -d' ' -f3)"
    print_status "info" "Main config file: $(nginx -t 2>&1 | grep 'configuration file' | awk '{print $5}' || echo "${NGINX_DIR}/nginx.conf")"
}
