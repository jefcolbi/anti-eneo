#!/bin/bash

# Test script for anti-eneo basic functionality
# This script tests periodic commits, custom intervals, and rolling window behavior

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANTI_ENEO="$SCRIPT_DIR/../anti-eneo"
TEST_REPO="/tmp/anti-eneo-test-$$"
ORIGINAL_DIR=$(pwd)

# Logging functions
log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Setup test environment
setup_test_env() {
    log_test "Setting up test environment..."
    
    # Create test directory and repo
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    
    # Initialize git repo
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit
    echo "Initial content" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Set main as default branch
    git branch -M main
    
    # Create a bare repo to act as remote
    git init --bare ../test-remote-$$.git
    git remote add origin ../test-remote-$$.git
    git push -u origin main
    
    log_success "Test environment setup complete"
}

# Cleanup function
cleanup() {
    log_test "Cleaning up..."
    
    # Kill any running anti-eneo processes
    pkill -f "anti-eneo" 2>/dev/null || true
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
    
    # Remove test repos
    rm -rf "$TEST_REPO" "/tmp/test-remote-$$.git"
    
    log_success "Cleanup complete"
}

# Test 1: Default periodic commit mode (using shorter interval for testing)
test_default_periodic() {
    log_test "Testing default periodic commit mode..."
    
    cd "$TEST_REPO"
    
    # Start anti-eneo with short interval for testing
    "$ANTI_ENEO" --interval=5 --quiet &
    ANTI_PID=$!
    
    # Wait for branch switch
    sleep 2
    
    # Verify we're on anti-eneo branch
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "anti-eneo" ]]; then
        kill $ANTI_PID 2>/dev/null || true
        log_error "Failed to switch to anti-eneo branch"
        return 1
    fi
    
    # Make first change
    echo "Change 1" > test1.txt
    
    # Wait for first commit
    sleep 7
    
    # Make second change
    echo "Change 2" > test2.txt
    
    # Wait for second commit
    sleep 7
    
    # Stop anti-eneo
    kill $ANTI_PID 2>/dev/null || true
    wait $ANTI_PID 2>/dev/null || true
    
    # Verify commits were made
    commit_count=$(git rev-list --count HEAD)
    if [[ $commit_count -ge 2 ]]; then
        log_success "Periodic commits working correctly"
        return 0
    else
        log_error "Expected at least 2 commits, found $commit_count"
        return 1
    fi
}

# Test 2: Custom interval
test_custom_interval() {
    log_test "Testing custom interval..."
    
    cd "$TEST_REPO"
    git checkout main 2>/dev/null || true
    
    # Start anti-eneo with 3 second interval
    "$ANTI_ENEO" --interval=3 --quiet &
    ANTI_PID=$!
    
    sleep 2
    
    # Record start time
    start_time=$(date +%s)
    
    # Make changes
    echo "Fast change 1" > fast1.txt
    sleep 4
    echo "Fast change 2" > fast2.txt
    sleep 4
    
    # Stop anti-eneo
    kill $ANTI_PID 2>/dev/null || true
    wait $ANTI_PID 2>/dev/null || true
    
    # Calculate elapsed time
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    # Should have at least 2 commits in ~8 seconds with 3 second interval
    commit_count=$(git rev-list --count HEAD)
    if [[ $commit_count -ge 2 ]] && [[ $elapsed -lt 15 ]]; then
        log_success "Custom interval working correctly"
        return 0
    else
        log_error "Custom interval test failed (commits: $commit_count, time: ${elapsed}s)"
        return 1
    fi
}

# Test 3: Rolling window behavior
test_rolling_window() {
    log_test "Testing rolling window behavior..."
    
    cd "$TEST_REPO"
    git checkout main 2>/dev/null || true
    
    # Get base commit count
    base_count=$(git rev-list --count HEAD)
    
    # Start anti-eneo with very short interval
    "$ANTI_ENEO" --interval=2 --quiet &
    ANTI_PID=$!
    
    sleep 2
    
    # Create 5 changes to trigger 5 commits
    for i in {1..5}; do
        echo "Rolling change $i" > "rolling$i.txt"
        sleep 3
    done
    
    # Stop anti-eneo
    kill $ANTI_PID 2>/dev/null || true
    wait $ANTI_PID 2>/dev/null || true
    
    # Check commit count on anti-eneo branch
    anti_eneo_commits=$(git rev-list --count HEAD "^$(git merge-base HEAD main 2>/dev/null || echo '')" 2>/dev/null || echo "0")
    
    # Should have exactly 2 commits due to rolling window
    if [[ $anti_eneo_commits -eq 2 ]]; then
        log_success "Rolling window maintaining 2 commits correctly"
        return 0
    else
        log_error "Expected 2 commits in rolling window, found $anti_eneo_commits"
        return 1
    fi
}

# Test 4: Branch creation
test_branch_creation() {
    log_test "Testing branch creation..."
    
    cd "$TEST_REPO"
    
    # Ensure we're on main and anti-eneo branch doesn't exist
    git checkout main
    git branch -D anti-eneo 2>/dev/null || true
    
    # Start anti-eneo
    "$ANTI_ENEO" --interval=30 --quiet &
    ANTI_PID=$!
    
    sleep 2
    
    # Check if branch was created
    if git rev-parse --verify anti-eneo >/dev/null 2>&1; then
        current_branch=$(git branch --show-current)
        if [[ "$current_branch" == "anti-eneo" ]]; then
            log_success "Branch created and switched successfully"
            result=0
        else
            log_error "Branch created but not switched to"
            result=1
        fi
    else
        log_error "Branch was not created"
        result=1
    fi
    
    # Cleanup
    kill $ANTI_PID 2>/dev/null || true
    wait $ANTI_PID 2>/dev/null || true
    
    return $result
}

# Test 5: Existing branch handling
test_existing_branch() {
    log_test "Testing existing branch handling..."
    
    cd "$TEST_REPO"
    
    # Create anti-eneo branch
    git checkout -b anti-eneo 2>/dev/null || git checkout anti-eneo
    echo "Existing branch content" > existing.txt
    git add existing.txt
    git commit -m "Existing commit"
    
    # Switch back to main
    git checkout main
    
    # Start anti-eneo
    "$ANTI_ENEO" --interval=30 --quiet &
    ANTI_PID=$!
    
    sleep 2
    
    # Verify switched to existing branch and content is preserved
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" == "anti-eneo" ]] && [[ -f "existing.txt" ]]; then
        log_success "Existing branch handled correctly"
        result=0
    else
        log_error "Failed to handle existing branch properly"
        result=1
    fi
    
    # Cleanup
    kill $ANTI_PID 2>/dev/null || true
    wait $ANTI_PID 2>/dev/null || true
    
    return $result
}

# Run all tests
run_all_tests() {
    local failed=0
    
    echo "================================"
    echo "Anti-Eneo Basic Functionality Tests"
    echo "================================"
    echo
    
    # Setup
    setup_test_env
    
    # Run tests
    test_default_periodic || ((failed++))
    echo
    
    test_custom_interval || ((failed++))
    echo
    
    test_rolling_window || ((failed++))
    echo
    
    test_branch_creation || ((failed++))
    echo
    
    test_existing_branch || ((failed++))
    echo
    
    # Summary
    echo "================================"
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}$failed tests failed${NC}"
    fi
    echo "================================"
    
    # Cleanup
    cleanup
    
    return $failed
}

# Handle script termination
trap cleanup EXIT INT TERM

# Run tests
run_all_tests