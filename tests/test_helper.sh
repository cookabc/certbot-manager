#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Failed test counter
FAILED_TESTS=0

# Assert equals
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

# Create temporary config file
setup_test_config() {
    local content="$1"
    local temp_file=$(mktemp)
    echo "$content" > "$temp_file"
    echo "$temp_file"
}

# Clean up temporary config file
teardown_test_config() {
    local file="$1"
    rm -f "$file"
}

# Summarize test results
summarize_tests() {
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}✨ All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ $FAILED_TESTS test(s) failed!${NC}"
        return 1
    fi
}
