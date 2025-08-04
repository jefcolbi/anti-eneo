#!/bin/bash

# Test script for anti-eneo graceful shutdown functionality
# This script tests that pending changes are committed when anti-eneo is stopped

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANTI_ENEO="$SCRIPT_DIR/../anti-eneo"
TEST_REPO="/tmp/anti-eneo-test-shutdown-$$"
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
    log_test "Setting up test environment for graceful shutdown tests..."
    
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
    git init --bare ../test-remote-shutdown-$$.git
    git remote add origin ../test-remote-shutdown-$$.git
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
    rm -rf "$TEST_REPO" "/tmp/test-remote-shutdown-$$.git"
    
    log_success "Cleanup complete"
}

# Test 1: Graceful shutdown with pending changes (SIGINT)
test_shutdown_with_changes_sigint() {
    log_test "Testing graceful shutdown with pending changes (SIGINT)..."
    
    cd "$TEST_REPO"
    
    # Start anti-eneo with long interval
    "$ANTI_ENEO" --interval=300  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 3
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Create pending changes
    echo "Pending change 1" > pending1.txt
    echo "Pending change 2" > pending2.txt
    git add .
    
    # Send SIGINT (Ctrl+C)
    kill -INT $ANTI_PID
    
    # Wait for graceful shutdown
    wait $ANTI_PID 2>/dev/null || true
    
    # Check if changes were committed
    final_commits=$(git rev-list --count HEAD)
    
    if [[ $final_commits -gt $initial_commits ]]; then
        # Verify files were committed
        if git ls-tree -r HEAD --name-only | grep -q "pending1.txt" && \
           git ls-tree -r HEAD --name-only | grep -q "pending2.txt"; then
            log_success "Pending changes were committed on SIGINT"
            return 0
        else
            log_error "Commit was made but files are missing"
            return 1
        fi
    else
        log_error "No commit was made for pending changes"
        return 1
    fi
}

# Test 2: Graceful shutdown with pending changes (SIGTERM)
test_shutdown_with_changes_sigterm() {
    log_test "Testing graceful shutdown with pending changes (SIGTERM)..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Start anti-eneo
    "$ANTI_ENEO" --interval=300  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 3
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Create pending changes
    echo "SIGTERM test" > sigterm.txt
    
    # Send SIGTERM
    kill -TERM $ANTI_PID
    
    # Wait for graceful shutdown
    wait $ANTI_PID 2>/dev/null || true
    
    # Check if changes were committed
    final_commits=$(git rev-list --count HEAD)
    
    if [[ $final_commits -gt $initial_commits ]]; then
        if git ls-tree -r HEAD --name-only | grep -q "sigterm.txt"; then
            log_success "Pending changes were committed on SIGTERM"
            return 0
        else
            log_error "Commit was made but file is missing"
            return 1
        fi
    else
        log_error "No commit was made for pending changes on SIGTERM"
        return 1
    fi
}

# Test 3: Graceful shutdown with no pending changes
test_shutdown_no_changes() {
    log_test "Testing graceful shutdown with no pending changes..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Start anti-eneo
    "$ANTI_ENEO" --interval=300  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 3
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Send SIGINT without making changes
    kill -INT $ANTI_PID
    
    # Wait for graceful shutdown
    wait $ANTI_PID 2>/dev/null || true
    
    # Check commit count remains the same
    final_commits=$(git rev-list --count HEAD)
    
    if [[ $final_commits -eq $initial_commits ]]; then
        log_success "No unnecessary commit on clean shutdown"
        return 0
    else
        log_error "Unexpected commit on clean shutdown"
        return 1
    fi
}

# Test 4: Graceful shutdown in watch mode
test_shutdown_watch_mode() {
    log_test "Testing graceful shutdown in watch mode..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Start anti-eneo in watch mode
    "$ANTI_ENEO" --watch --debounce=5  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 3
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Create pending changes
    echo "Watch mode shutdown test" > watch-shutdown.txt
    
    # Wait a bit but less than debounce time
    sleep 2
    
    # Send SIGINT
    kill -INT $ANTI_PID
    
    # Wait for graceful shutdown
    wait $ANTI_PID 2>/dev/null || true
    
    # Check if changes were committed
    final_commits=$(git rev-list --count HEAD)
    
    if [[ $final_commits -gt $initial_commits ]]; then
        if git ls-tree -r HEAD --name-only | grep -q "watch-shutdown.txt"; then
            log_success "Watch mode graceful shutdown committed pending changes"
            return 0
        else
            log_error "Commit was made but file is missing in watch mode"
            return 1
        fi
    else
        log_error "No commit was made in watch mode shutdown"
        return 1
    fi
}

# Test 5: Multiple pending files during shutdown
test_shutdown_multiple_files() {
    log_test "Testing shutdown with multiple pending files..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Start anti-eneo
    "$ANTI_ENEO" --interval=300  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 3
    
    # Create multiple pending changes
    mkdir -p subdir
    echo "File 1" > file1.txt
    echo "File 2" > subdir/file2.txt
    echo "File 3" > file3.txt
    rm -f README.md  # Also test deletion
    
    # Send SIGINT
    kill -INT $ANTI_PID
    
    # Wait for graceful shutdown
    wait $ANTI_PID 2>/dev/null || true
    
    # Verify all changes were committed
    if git ls-tree -r HEAD --name-only | grep -q "file1.txt" && \
       git ls-tree -r HEAD --name-only | grep -q "subdir/file2.txt" && \
       git ls-tree -r HEAD --name-only | grep -q "file3.txt" && \
       ! git ls-tree -r HEAD --name-only | grep -q "README.md"; then
        log_success "All file changes committed on shutdown"
        return 0
    else
        log_error "Not all file changes were committed"
        return 1
    fi
}

# Test 6: Rapid shutdown after start
test_rapid_shutdown() {
    log_test "Testing rapid shutdown after start..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Start anti-eneo and immediately create changes and shutdown
    "$ANTI_ENEO" --interval=300  &
    ANTI_PID=$!
    
    # Rapidly create change and shutdown
    sleep 1
    echo "Rapid change" > rapid.txt
    kill -INT $ANTI_PID
    
    # Wait for shutdown
    wait $ANTI_PID 2>/dev/null || true
    
    # Check if change was captured
    if git ls-tree -r HEAD --name-only | grep -q "rapid.txt"; then
        log_success "Rapid shutdown still captured changes"
        return 0
    else
        log_error "Rapid shutdown missed changes"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    local failed=0
    
    echo "================================"
    echo "Anti-Eneo Graceful Shutdown Tests"
    echo "================================"
    echo
    
    # Setup
    setup_test_env
    
    # Run tests
    test_shutdown_with_changes_sigint || ((failed++))
    echo
    
    test_shutdown_with_changes_sigterm || ((failed++))
    echo
    
    test_shutdown_no_changes || ((failed++))
    echo
    
    test_shutdown_watch_mode || ((failed++))
    echo
    
    test_shutdown_multiple_files || ((failed++))
    echo
    
    test_rapid_shutdown || ((failed++))
    echo
    
    # Summary
    echo "================================"
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All graceful shutdown tests passed!${NC}"
    else
        echo -e "${RED}$failed graceful shutdown tests failed${NC}"
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