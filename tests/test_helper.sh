#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 失败计数器
FAILED_TESTS=0

# 断言相等
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $message"
        echo "       Expected: '$expected'"
        echo "       Actual:   '$actual'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 创建临时配置文件
setup_test_config() {
    local content="$1"
    local temp_file=$(mktemp)
    echo "$content" > "$temp_file"
    echo "$temp_file"
}

# 清理临时配置文件
teardown_test_config() {
    local file="$1"
    rm -f "$file"
}

# 总结测试结果
summarize_tests() {
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}✨ 所有测试通过!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ $FAILED_TESTS 个测试失败!${NC}"
        return 1
    fi
}
