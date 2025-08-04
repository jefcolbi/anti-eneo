#!/bin/bash

# Test script for anti-eneo watch mode functionality
# This script tests file change detection and debounce behavior

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANTI_ENEO="$SCRIPT_DIR/../anti-eneo"
TEST_REPO="/tmp/anti-eneo-test-watch-$$"
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
    log_test "Setting up test environment for watch mode tests..."
    
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
    git init --bare ../test-remote-watch-$$.git
    git remote add origin ../test-remote-watch-$$.git
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
    rm -rf "$TEST_REPO" "/tmp/test-remote-watch-$$.git"
    
    log_success "Cleanup complete"
}

# Test 1: Basic watch mode file detection
test_basic_watch_detection() {
    log_test "Testing basic watch mode file detection..."
    
    cd "$TEST_REPO"
    
    # Start anti-eneo in watch mode with short debounce
    "$ANTI_ENEO" --watch --debounce=3  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 2
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Make a change
    echo "Watch mode test 1" > watch1.txt
    
    # Wait for debounce + processing
    sleep 5
    
    # Check if commit was made
    current_commits=$(git rev-list --count HEAD)
    
    if [[ $current_commits -gt $initial_commits ]]; then
        if git ls-tree -r HEAD --name-only | grep -q "watch1.txt"; then
            log_success "Watch mode detected and committed file change"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 0
        else
            log_error "Commit made but file not found"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 1
        fi
    else
        log_error "Watch mode failed to commit change"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 1
    fi
}

# Test 2: Debounce behavior
test_debounce_behavior() {
    log_test "Testing debounce behavior..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Start with longer debounce
    "$ANTI_ENEO" --watch --debounce=5  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 2
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Make rapid changes within debounce window
    echo "Rapid 1" > rapid1.txt
    sleep 1
    echo "Rapid 2" > rapid2.txt
    sleep 1
    echo "Rapid 3" > rapid3.txt
    
    # Wait for debounce to complete
    sleep 5
    
    # Should have only one commit for all changes
    current_commits=$(git rev-list --count HEAD)
    commits_added=$((current_commits - initial_commits))
    
    if [[ $commits_added -eq 1 ]]; then
        # Verify all files are in the single commit
        if git ls-tree -r HEAD --name-only | grep -q "rapid1.txt" && \
           git ls-tree -r HEAD --name-only | grep -q "rapid2.txt" && \
           git ls-tree -r HEAD --name-only | grep -q "rapid3.txt"; then
            log_success "Debounce correctly batched rapid changes"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 0
        else
            log_error "Not all files were included in debounced commit"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 1
        fi
    else
        log_error "Expected 1 commit, got $commits_added"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 1
    fi
}

# Test 3: Multiple separate changes
test_multiple_separate_changes() {
    log_test "Testing multiple separate changes..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Start with short debounce
    "$ANTI_ENEO" --watch --debounce=3  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 2
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Make first change
    echo "Separate 1" > separate1.txt
    sleep 5  # Wait for commit
    
    # Make second change
    echo "Separate 2" > separate2.txt
    sleep 5  # Wait for commit
    
    # Check we have 2 separate commits
    current_commits=$(git rev-list --count HEAD)
    commits_added=$((current_commits - initial_commits))
    
    if [[ $commits_added -eq 2 ]]; then
        log_success "Multiple separate changes created separate commits"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 0
    else
        log_error "Expected 2 commits, got $commits_added"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 1
    fi
}

# Test 4: File modifications vs additions
test_file_modifications() {
    log_test "Testing file modifications detection..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Create a file first
    echo "Original content" > modify.txt
    git add modify.txt
    git commit -m "Add file to modify"
    
    # Start watch mode
    "$ANTI_ENEO" --watch --debounce=3  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 2
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Modify the file
    echo "Modified content" > modify.txt
    
    # Wait for commit
    sleep 5
    
    # Check if modification was detected
    current_commits=$(git rev-list --count HEAD)
    
    if [[ $current_commits -gt $initial_commits ]]; then
        # Check if the file has new content
        if git show HEAD:modify.txt | grep -q "Modified content"; then
            log_success "File modification detected and committed"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 0
        else
            log_error "Commit made but modification not captured"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 1
        fi
    else
        log_error "File modification not detected"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 1
    fi
}

# Test 5: File deletions
test_file_deletions() {
    log_test "Testing file deletion detection..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Create files first
    echo "File to delete 1" > delete1.txt
    echo "File to delete 2" > delete2.txt
    git add .
    git commit -m "Add files to delete"
    
    # Start watch mode
    "$ANTI_ENEO" --watch --debounce=3  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 2
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Delete files
    rm delete1.txt delete2.txt
    
    # Wait for commit
    sleep 5
    
    # Check if deletions were detected
    current_commits=$(git rev-list --count HEAD)
    
    if [[ $current_commits -gt $initial_commits ]]; then
        # Check if files are gone
        if ! git ls-tree -r HEAD --name-only | grep -q "delete1.txt" && \
           ! git ls-tree -r HEAD --name-only | grep -q "delete2.txt"; then
            log_success "File deletions detected and committed"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 0
        else
            log_error "Commit made but deletions not captured"
            kill $ANTI_PID 2>/dev/null || true
            wait $ANTI_PID 2>/dev/null || true
            return 1
        fi
    else
        log_error "File deletions not detected"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 1
    fi
}

# Test 6: Complex file operations
test_complex_operations() {
    log_test "Testing complex file operations..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Setup initial state
    mkdir -p dir1/subdir
    echo "Existing" > existing.txt
    echo "To modify" > dir1/modify.txt
    echo "To delete" > dir1/subdir/delete.txt
    git add .
    git commit -m "Initial complex state"
    
    # Start watch mode
    "$ANTI_ENEO" --watch --debounce=4  &
    ANTI_PID=$!
    
    # Wait for initialization
    sleep 2
    
    # Get initial commit count
    initial_commits=$(git rev-list --count HEAD)
    
    # Perform complex operations
    echo "New file" > new.txt                    # Add
    echo "Modified" > dir1/modify.txt            # Modify
    rm dir1/subdir/delete.txt                    # Delete
    mkdir -p dir2                                # New directory
    echo "In new dir" > dir2/file.txt           # Add in new dir
    mv existing.txt renamed.txt                  # Rename
    
    # Wait for commit
    sleep 6
    
    # Verify all operations were captured
    if git ls-tree -r HEAD --name-only | grep -q "new.txt" && \
       git show HEAD:dir1/modify.txt | grep -q "Modified" && \
       ! git ls-tree -r HEAD --name-only | grep -q "dir1/subdir/delete.txt" && \
       git ls-tree -r HEAD --name-only | grep -q "dir2/file.txt" && \
       ! git ls-tree -r HEAD --name-only | grep -q "existing.txt" && \
       git ls-tree -r HEAD --name-only | grep -q "renamed.txt"; then
        log_success "Complex file operations all captured correctly"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 0
    else
        log_error "Some complex operations were not captured correctly"
        kill $ANTI_PID 2>/dev/null || true
        wait $ANTI_PID 2>/dev/null || true
        return 1
    fi
}

# Run all tests
run_all_tests() {
    local failed=0
    
    echo "================================"
    echo "Anti-Eneo Watch Mode Tests"
    echo "================================"
    echo
    
    # Setup
    setup_test_env
    
    # Run tests
    test_basic_watch_detection || ((failed++))
    echo
    
    test_debounce_behavior || ((failed++))
    echo
    
    test_multiple_separate_changes || ((failed++))
    echo
    
    test_file_modifications || ((failed++))
    echo
    
    test_file_deletions || ((failed++))
    echo
    
    test_complex_operations || ((failed++))
    echo
    
    # Summary
    echo "================================"
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All watch mode tests passed!${NC}"
    else
        echo -e "${RED}$failed watch mode tests failed${NC}"
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