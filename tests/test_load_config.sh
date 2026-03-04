#!/bin/bash

# Load base module and test helper
source modules/base.sh
source tests/test_helper.sh

echo "🚀 Starting load_config function tests..."

# Test case 1: Basic loading
test_basic_loading() {
    local config_content="[certbot]
email=admin@example.com
domains=example.com"
    local config_file=$(setup_test_config "$config_content")

    # Ensure variables are unset
    unset CERTBOT_EMAIL
    unset CERTBOT_DOMAINS

    load_config "$config_file"

    assert_equals "admin@example.com" "$CERTBOT_EMAIL" "Should load email from [certbot] section"
    assert_equals "example.com" "$CERTBOT_DOMAINS" "Should load domains from [certbot] section"

    teardown_test_config "$config_file"
    unset CERTBOT_EMAIL
    unset CERTBOT_DOMAINS
}

# Test case 2: Comments and empty lines
test_comments_and_empty_lines() {
    local config_content="
[nginx]
# This is a comment
config_path=/etc/nginx/conf.d/

[renewal]
method=systemd
"
    local config_file=$(setup_test_config "$config_content")

    unset NGINX_CONFIG_PATH
    unset RENEWAL_METHOD

    load_config "$config_file"

    assert_equals "/etc/nginx/conf.d/" "$NGINX_CONFIG_PATH" "Should ignore comments and load correct value"
    assert_equals "systemd" "$RENEWAL_METHOD" "Should load value across empty lines"

    teardown_test_config "$config_file"
    unset NGINX_CONFIG_PATH
    unset RENEWAL_METHOD
}

# Test case 3: Inline comments and whitespace
test_inline_comments_and_whitespace() {
    local config_content="
[logging]
level = info # This is an inline comment
file =  /var/log/certbot.log
"
    local config_file=$(setup_test_config "$config_content")

    unset LOGGING_LEVEL
    unset LOGGING_FILE

    load_config "$config_file"

    assert_equals "info" "$LOGGING_LEVEL" "Should remove inline comments and trim whitespace"
    assert_equals "/var/log/certbot.log" "$LOGGING_FILE" "Should trim leading/trailing whitespace"

    teardown_test_config "$config_file"
    unset LOGGING_LEVEL
    unset LOGGING_FILE
}

# Test case 4: Edge cases
test_edge_cases() {
    # 1. Non-existent file
    load_config "non_existent.conf"
    assert_equals "" "${NON_EXISTENT_VAR:-}" "Should not load non-existent file"

    # 2. Keys outside of section
    local config_content="
global_key=value
[dns]
local_key=value
"
    local config_file=$(setup_test_config "$config_content")

    # Clear possibly existing variables
    unset GLOBAL_KEY
    unset DNS_LOCAL_KEY

    load_config "$config_file"

    assert_equals "" "${GLOBAL_KEY:-}" "Should ignore keys outside of section"
    assert_equals "value" "$DNS_LOCAL_KEY" "Should load keys inside section"

    teardown_test_config "$config_file"
    unset GLOBAL_KEY
    unset DNS_LOCAL_KEY
}

# Run tests
test_basic_loading
test_comments_and_empty_lines
test_inline_comments_and_whitespace
test_edge_cases

# Summarize and exit
summarize_tests
exit $?
