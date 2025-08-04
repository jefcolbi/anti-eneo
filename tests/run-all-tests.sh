#!/bin/bash

# Master test runner for anti-eneo
# This script runs all test suites and provides a comprehensive report

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="/tmp/anti-eneo-test-log-$$.txt"

# Test suite files
TEST_SUITES=(
    "test-basic.sh"
    "test-save-to.sh"
    "test-graceful-shutdown.sh"
    "test-watch-mode.sh"
)

# Timing
START_TIME=$(date +%s)

# Results tracking
declare -A SUITE_RESULTS
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Logging functions
log_header() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_suite_start() {
    echo -e "\n${YELLOW}▶ Running test suite: $1${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
}

log_suite_pass() {
    echo -e "${GREEN}✓ Test suite PASSED: $1${NC}\n"
}

log_suite_fail() {
    echo -e "${RED}✗ Test suite FAILED: $1${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check if anti-eneo exists and is executable
    if [[ ! -x "$SCRIPT_DIR/../anti-eneo" ]]; then
        echo -e "${RED}Error: anti-eneo script not found or not executable${NC}"
        echo "Expected location: $SCRIPT_DIR/../anti-eneo"
        exit 1
    fi
    
    # Check if all test scripts exist
    for suite in "${TEST_SUITES[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$suite" ]]; then
            echo -e "${RED}Error: Test suite not found: $suite${NC}"
            exit 1
        fi
        if [[ ! -x "$SCRIPT_DIR/$suite" ]]; then
            echo -e "${RED}Error: Test suite not executable: $suite${NC}"
            echo "Run: chmod +x $SCRIPT_DIR/$suite"
            exit 1
        fi
    done
    
    # Check git is available
    if ! command -v git &>/dev/null; then
        echo -e "${RED}Error: git command not found${NC}"
        exit 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Run a single test suite
run_test_suite() {
    local suite="$1"
    local suite_name="${suite%.sh}"
    
    log_suite_start "$suite_name"
    
    # Run the test suite and capture output
    if "$SCRIPT_DIR/$suite" > >(tee -a "$LOGFILE") 2>&1; then
        SUITE_RESULTS[$suite]="PASSED"
        ((PASSED_SUITES++))
        log_suite_pass "$suite_name"
    else
        SUITE_RESULTS[$suite]="FAILED"
        ((FAILED_SUITES++))
        log_suite_fail "$suite_name"
    fi
    
    ((TOTAL_SUITES++))
}

# Generate summary report
generate_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    log_header "Test Summary Report"
    
    echo -e "${BLUE}Test Execution Summary:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total test suites run: $TOTAL_SUITES"
    echo -e "Passed: ${GREEN}$PASSED_SUITES${NC}"
    echo -e "Failed: ${RED}$FAILED_SUITES${NC}"
    echo "Duration: ${duration} seconds"
    echo
    
    echo -e "${BLUE}Individual Suite Results:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for suite in "${TEST_SUITES[@]}"; do
        local result="${SUITE_RESULTS[$suite]}"
        local suite_name="${suite%.sh}"
        if [[ "$result" == "PASSED" ]]; then
            echo -e "  ${GREEN}✓${NC} $suite_name"
        else
            echo -e "  ${RED}✗${NC} $suite_name"
        fi
    done
    
    echo
    echo "Full test log saved to: $LOGFILE"
    
    # Overall result
    echo
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║       ALL TESTS PASSED! 🎉            ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        return 0
    else
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║    SOME TESTS FAILED! ❌              ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    # Kill any lingering anti-eneo processes from tests
    pkill -f "anti-eneo" 2>/dev/null || true
    
    # Clean up any test repositories
    rm -rf /tmp/anti-eneo-test-* 2>/dev/null || true
    rm -rf /tmp/test-remote-* 2>/dev/null || true
}

# Main execution
main() {
    log_header "Anti-Eneo Comprehensive Test Suite"
    echo -e "${BLUE}Date:${NC} $(date)"
    echo -e "${BLUE}User:${NC} $(whoami)"
    echo -e "${BLUE}Working Directory:${NC} $(pwd)"
    echo
    
    # Initial cleanup
    cleanup
    
    # Check prerequisites
    check_prerequisites
    
    # Run all test suites
    for suite in "${TEST_SUITES[@]}"; do
        run_test_suite "$suite"
    done
    
    # Generate summary
    generate_summary
    local exit_code=$?
    
    # Final cleanup
    cleanup
    
    exit $exit_code
}

# Handle script termination
trap cleanup EXIT INT TERM

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --suite=*)
            # Run only specific suite
            SUITE="${1#*=}"
            if [[ " ${TEST_SUITES[@]} " =~ " ${SUITE} " ]]; then
                TEST_SUITES=("$SUITE")
            else
                echo -e "${RED}Error: Unknown test suite: $SUITE${NC}"
                echo "Available suites: ${TEST_SUITES[@]}"
                exit 1
            fi
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Run all anti-eneo test suites"
            echo
            echo "Options:"
            echo "  --suite=NAME    Run only the specified test suite"
            echo "  --help, -h      Show this help message"
            echo
            echo "Available test suites:"
            for suite in "${TEST_SUITES[@]}"; do
                echo "  - ${suite%.sh}"
            done
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run the main function
main