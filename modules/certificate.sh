#!/bin/bash

# 证书管理模块 - 处理证书的创建、列出、续期和卸载等操作

# 加载基础模块和系统检查模块
source "$MODULES_DIR/base.sh"
source "$MODULES_DIR/system.sh"

# 列出所有证书供选择
list_certificates_for_selection() {
    print_status "info" "获取已安装的证书列表..." >&2

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装" >&2
        return 1
    fi

    local cert_output
    if check_root; then
        cert_output=$(certbot certificates 2>/dev/null)
    elif command -v sudo &> /dev/null; then
        cert_output=$(sudo certbot certificates 2>/dev/null)
    else
        print_status "warning" "需要sudo权限查看证书列表" >&2
        print_status "info" "请运行: sudo $0 list" >&2
        return 1
    fi
    if [[ -z "$cert_output" || "$cert_output" == *"No certificates found"* ]]; then
        print_status "info" "暂无已安装的证书" >&2
        return 1
    fi

    local domains=()
    local domain
    while IFS= read -r line; do
        if [[ "$line" == *"Certificate Name:"* ]]; then
            domain=$(echo "$line" | awk '{print $3}')
            domains+=($domain)
        fi
    done <<< "$cert_output"

    if [[ ${#domains[@]} -eq 0 ]]; then
        print_status "info" "暂无已安装的证书" >&2
        return 1
    fi

    # 仅输出纯域名列表到stdout
    printf '%s\n' "${domains[@]}"
    return 0
}

# 列出已安装证书
list_certificates() {
    print_status "title" "证书列表"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装，无法列出证书"
        return 1
    fi

    local cert_output
    if check_root; then
        cert_output=$(certbot certificates 2>/dev/null)
    elif command -v sudo &> /dev/null; then
        cert_output=$(sudo certbot certificates 2>/dev/null)
    else
        print_status "warning" "需要sudo权限查看证书列表"
        print_status "info" "请运行: sudo $0 list"
        return 1
    fi
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
            expiry=${line#*Expiry Date: }
            echo "   到期时间: $expiry"
        elif [[ "$line" == *"Certificate Path:"* ]]; then
            cert_path=${line#*Certificate Path: }
            echo "   证书路径: $cert_path"
        elif [[ "$line" == *"Private Key Path:"* ]]; then
            key_path=${line#*Private Key Path: }
            echo "   私钥路径: $key_path"
        fi
    done
    echo ""
}

# 创建SSL证书
create_certificate() {
    local domain=$1

    print_status "title" "创建SSL证书"
    echo "=================================================="

    if ! command -v certbot &> /dev/null; then
        print_status "error" "Certbot未安装，请先运行: $0 install"
        return 2
    fi

    # 如果没有提供域名，则交互式获取
    if [[ -z "$domain" ]]; then
        echo -n "请输入要签发证书的域名: "
        read -r domain
        if [[ -z "$domain" ]]; then
            print_status "error" "域名不能为空"
            return 2
        fi
    fi

    if domain=$(convert_to_punycode "$domain"); then
        :
    else
        print_status "error" "域名不符合ASCII格式，请输入英文域名"
        return 2
    fi

    # 验证域名格式（更严格的校验）
    # 支持通配符 *.example.com
    if [[ ! "$domain" =~ ^(\*\.)?([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        # 排除 localhost
        if [[ "$domain" != "localhost" ]]; then
             print_status "warning" "域名格式可能不标准，建议检查: $domain"
        fi
    fi

    # 获取邮箱地址
    local email=""
    if [[ -n "$CERTBOT_EMAIL" ]]; then
        email="$CERTBOT_EMAIL"
        print_status "info" "使用配置文件中的邮箱: $email"
    else
        echo -n "请输入用于 Let's Encrypt 的邮箱地址: "
        read -r email
    fi
    
    if [[ -z "$email" ]]; then
        print_status "error" "邮箱地址不能为空"
        return 2
    fi

    # 验证邮箱格式
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_status "error" "邮箱格式不正确"
        return 2
    fi

    nginx_available=false
    mode=$(detect_certbot_mode)
    
    local dns_plugin_mode=false
    local dns_plugin_name=""
    local dns_credentials_file=""
    
    # 检查是否为通配符域名
    if [[ "$domain" == \*.* ]]; then
        print_status "warning" "检测到通配符域名，需要使用DNS验证方式"
        
        # 检查是否配置了 DNS 插件
        if [[ -n "${CERTBOT_DNS_PLUGIN:-}" ]]; then
             dns_plugin_name="$CERTBOT_DNS_PLUGIN"
             dns_credentials_file="${CERTBOT_DNS_CREDENTIALS:-}"
             dns_plugin_mode=true
             mode="dns-plugin"
             print_status "info" "使用配置的 DNS 插件: $dns_plugin_name"
        else
             print_status "warning" "Nginx插件不支持DNS验证，将使用manual模式"
             mode="manual"
        fi
        
        nginx_available=false
    else
        # 再次检查Nginx配置，确保模式选择正确
        if [[ "$mode" == "nginx" ]]; then
            # 检查nginx配置是否有效
            local nginx_conf_check
            nginx_conf_check=$(sudo nginx -c /etc/nginx/nginx.conf -t 2>&1)
            if [[ $? -eq 0 ]]; then
                nginx_available=true
                print_status "info" "检测到Nginx和插件，将使用nginx插件"
            else
                print_status "warning" "Nginx配置无效，强制切换到standalone模式"
                mode="standalone"
            fi
        else
            if command -v nginx &> /dev/null; then
                print_status "info" "检测到Nginx但未安装插件或配置无效，使用standalone模式"
            else
                print_status "info" "未检测到Nginx，将使用standalone模式（需要停止Web服务器）"
            fi
        fi
    fi

    # 确认操作
    echo ""
    print_status "title" "证书信息确认"
    echo "=================================================="
    echo "📍 域名: $domain"
    echo "📧 邮箱: $email"
    # 正确显示当前使用的模式
    local mode_display
    if $dns_plugin_mode; then
        mode_display="DNS插件模式 ($dns_plugin_name)"
    elif [[ "$domain" == \*.* ]]; then
        mode_display="Manual模式(DNS验证)"
    elif $nginx_available; then
        mode_display="Nginx插件"
    else
        mode_display="Standalone模式"
    fi
    echo "🔧 模式: $mode_display"
    echo "=================================================="
    echo ""

    confirm_action "确认要创建SSL证书吗？"
    if [[ $? -ne 0 ]]; then
        print_status "info" "操作已取消"
        return 2
    fi

    print_status "info" "开始为域名 $domain 创建SSL证书..."

    local success=false
    local nginx_was_running=false
    
    # 检查nginx是否正在运行
    if check_nginx_status; then
        nginx_was_running=true
    fi
    
    # 处理通配符域名
    if [[ "$domain" == \*.* ]]; then
        if $dns_plugin_mode; then
            print_status "info" "使用 DNS 插件进行验证..."
            local cmd=(certbot certonly --non-interactive --agree-tos --email "$email" -d "$domain" "--dns-${dns_plugin_name}")
            
            if [[ -n "$dns_credentials_file" ]]; then
                cmd+=("--dns-${dns_plugin_name}-credentials" "$dns_credentials_file")
            fi
            
            if check_root; then
                if "${cmd[@]}"; then success=true; fi
            elif command -v sudo &> /dev/null; then
                if sudo "${cmd[@]}"; then success=true; fi
            else
                print_status "error" "需要sudo权限以配置证书"
                return 1
            fi
        else
            print_status "info" "通配符域名需要DNS验证，将使用manual模式"
            print_status "info" "系统将提示您添加DNS记录，请准备好DNS管理界面"
            
            # 通配符域名需要使用DNS验证，使用manual模式
            if check_root; then
                if certbot certonly --manual --preferred-challenges dns --agree-tos --email "$email" -d "$domain"; then success=true; fi
            elif command -v sudo &> /dev/null; then
                if sudo certbot certonly --manual --preferred-challenges dns --agree-tos --email "$email" -d "$domain"; then success=true; fi
            else
                print_status "error" "需要sudo权限以配置证书"
                return 1
            fi
        fi
    elif $nginx_available; then
        # 使用nginx插件模式
        if check_root; then
            if certbot --nginx --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        elif command -v sudo &> /dev/null; then
            if sudo certbot --nginx --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        else
            print_status "error" "需要sudo权限以配置证书"
            return 1
        fi
    else
        # 使用standalone模式，需要停止nginx服务
        if $nginx_was_running; then
            print_status "info" "停止nginx服务以使用standalone模式..."
            stop_nginx
        fi
        
        if check_root; then
            if certbot certonly --standalone --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        elif command -v sudo &> /dev/null; then
            if sudo certbot certonly --standalone --non-interactive --agree-tos --email "$email" -d "$domain"; then success=true; fi
        else
            print_status "error" "需要sudo权限以配置证书"
            return 1
        fi
        
        # 如果nginx之前在运行，重新启动它
        if $nginx_was_running; then
            print_status "info" "重新启动nginx服务..."
            start_nginx
        fi
    fi

    if $success; then
        print_status "success" "SSL证书创建成功！"
        # 修复通配符域名的证书文件位置显示
        local cert_dir=$(sudo certbot certificates 2>/dev/null | grep -A 1 "Certificate Name: ${domain//\*/\*}" | grep "Certificate Path:" | awk '{print $3}' | sed 's/cert.pem$//' || echo "/etc/letsencrypt/live/${domain//\*/\*}/")
        print_status "info" "证书文件位置: $cert_dir"
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
            return 3
        fi

        print_status "info" "已安装的证书："
        for i in "${!domains[@]}"; do
            echo "  $((i+1))) ${domains[i]}"
        done

        echo -n "请输入要卸载的域名或编号: "
        read -r target_domain
        if [[ -z "$target_domain" ]]; then
            print_status "error" "输入不能为空"
            return 2
        fi

        # 如果输入的是编号，转换为域名
        if [[ "$target_domain" =~ ^[0-9]+$ ]]; then
            local index=$((target_domain - 1))
            if [[ $index -ge 0 && $index -lt ${#domains[@]} ]]; then
                target_domain="${domains[$index]}"
            else
                print_status "error" "无效的编号"
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
    confirm_action "确认要卸载域名 $target_domain 的SSL证书吗？"
    if [[ $? -ne 0 ]]; then
        print_status "info" "操作已取消"
        return 2
    fi

    print_status "info" "开始卸载SSL证书..."

    if ! check_root; then
        print_status "error" "需要root权限进行卸载"
        print_status "info" "请运行: sudo $0 delete $target_domain"
        return 2
    fi

    # 删除证书文件
    print_status "info" "删除证书文件..."
    if certbot delete --cert-name "$target_domain" 2>/dev/null; then
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

        rm -rf "$cert_dir" 2>/dev/null || true
        rm -rf "$archive_dir" 2>/dev/null || true
        rm -f "$renewal_file" 2>/dev/null || true

        print_status "success" "SSL证书手动删除完成"
        print_status "warning" "请记得手动更新Nginx配置"
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

    print_status "info" "开始续期证书..."

    local success=false
    if check_root; then
        if certbot renew; then success=true; fi
    elif command -v sudo &> /dev/null; then
        if sudo certbot renew; then success=true; fi
    else
        print_status "warning" "需要sudo权限续期证书"
        print_status "info" "请运行: sudo $0 renew"
        return 1
    fi

    if $success; then
        print_status "success" "证书续期成功！"
    else
        print_status "error" "证书续期失败"
        return 1
    fi
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
    print_status "info" "主配置文件: $(nginx -t 2>&1 | grep 'configuration file' | awk '{print $5}' || echo '/etc/nginx/nginx.conf')"
}
