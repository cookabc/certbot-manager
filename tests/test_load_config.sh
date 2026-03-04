#!/bin/bash

# 加载基础模块和测试助手
source modules/base.sh
source tests/test_helper.sh

echo "🚀 开始测试 load_config 函数..."

# 测试用例 1: 基本加载
test_basic_loading() {
    local config_content="[certbot]
email=admin@example.com
domains=example.com"
    local config_file=$(setup_test_config "$config_content")

    # 确保变量未设置
    unset CERTBOT_EMAIL
    unset CERTBOT_DOMAINS

    load_config "$config_file"

    assert_equals "admin@example.com" "$CERTBOT_EMAIL" "应该加载 [certbot] section 的 email"
    assert_equals "example.com" "$CERTBOT_DOMAINS" "应该加载 [certbot] section 的 domains"

    teardown_test_config "$config_file"
    unset CERTBOT_EMAIL
    unset CERTBOT_DOMAINS
}

# 测试用例 2: 注释和空行
test_comments_and_empty_lines() {
    local config_content="
[nginx]
# 这是一个注释
config_path=/etc/nginx/conf.d/

[renewal]
method=systemd
"
    local config_file=$(setup_test_config "$config_content")

    unset NGINX_CONFIG_PATH
    unset RENEWAL_METHOD

    load_config "$config_file"

    assert_equals "/etc/nginx/conf.d/" "$NGINX_CONFIG_PATH" "应该忽略注释并加载正确的值"
    assert_equals "systemd" "$RENEWAL_METHOD" "应该跨越空行加载值"

    teardown_test_config "$config_file"
    unset NGINX_CONFIG_PATH
    unset RENEWAL_METHOD
}

# 测试用例 3: 行内注释和空格
test_inline_comments_and_whitespace() {
    local config_content="
[logging]
level = info # 这是一行内注释
file =  /var/log/certbot.log
"
    local config_file=$(setup_test_config "$config_content")

    unset LOGGING_LEVEL
    unset LOGGING_FILE

    load_config "$config_file"

    assert_equals "info" "$LOGGING_LEVEL" "应该移除行内注释并修剪空格"
    assert_equals "/var/log/certbot.log" "$LOGGING_FILE" "应该修剪首尾空格"

    teardown_test_config "$config_file"
    unset LOGGING_LEVEL
    unset LOGGING_FILE
}

# 测试用例 4: 边界情况
test_edge_cases() {
    # 1. 不存在的文件
    load_config "non_existent.conf"
    assert_equals "" "${NON_EXISTENT_VAR:-}" "不应该加载不存在的文件"

    # 2. Section 之外的键
    local config_content="
global_key=value
[dns]
local_key=value
"
    local config_file=$(setup_test_config "$config_content")

    # 清除可能存在的变量
    unset GLOBAL_KEY
    unset DNS_LOCAL_KEY

    load_config "$config_file"

    assert_equals "" "${GLOBAL_KEY:-}" "应该忽略 section 之外的键"
    assert_equals "value" "$DNS_LOCAL_KEY" "应该加载 section 之内的键"

    teardown_test_config "$config_file"
    unset GLOBAL_KEY
    unset DNS_LOCAL_KEY
}

# 运行测试
test_basic_loading
test_comments_and_empty_lines
test_inline_comments_and_whitespace
test_edge_cases

# 总结并退出
summarize_tests
exit $?
