#!/bin/bash

# Test script for anti-eneo --save-to functionality
# This script tests the save-to-branch feature including validation and error handling

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANTI_ENEO="$SCRIPT_DIR/../anti-eneo"
TEST_REPO="/tmp/anti-eneo-test-save-$$"
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
    log_test "Setting up test environment for save-to tests..."
    
    # Create test directory and repo
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    
    # Initialize git repo
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit on main
    echo "Initial content" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Set main as default branch
    git branch -M main
    
    # Create additional branches
    git checkout -b develop
    echo "Develop branch" > develop.txt
    git add develop.txt
    git commit -m "Develop branch commit"
    
    git checkout -b feature-test
    echo "Feature branch" > feature.txt
    git add feature.txt
    git commit -m "Feature branch commit"
    
    # Create anti-eneo branch with some commits
    git checkout -b anti-eneo
    echo "Anti-eneo change 1" > anti1.txt
    git add anti1.txt
    git commit -m "Anti-eneo commit 1"
    
    echo "Anti-eneo change 2" > anti2.txt
    git add anti2.txt
    git commit -m "Anti-eneo commit 2"
    
    # Create a bare repo to act as remote
    git init --bare ../test-remote-save-$$.git
    git remote add origin ../test-remote-save-$$.git
    
    # Push all branches
    git push -u origin main
    git push -u origin develop
    git push -u origin feature-test
    git push -u origin anti-eneo
    
    log_success "Test environment setup complete"
}

# Cleanup function
cleanup() {
    log_test "Cleaning up..."
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
    
    # Remove test repos
    rm -rf "$TEST_REPO" "/tmp/test-remote-save-$$.git"
    
    log_success "Cleanup complete"
}

# Test 1: Basic save-to functionality
test_basic_save_to() {
    log_test "Testing basic save-to functionality..."
    
    cd "$TEST_REPO"
    git checkout anti-eneo
    
    # Get commit count on main before save
    main_commits_before=$(git rev-list --count main)
    
    # Run save-to with automated commit message
    echo "Test commit message" | "$ANTI_ENEO" --save-to=main
    
    # Check if we're back on anti-eneo
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "anti-eneo" ]]; then
        log_error "Not returned to anti-eneo branch after save-to"
        return 1
    fi
    
    # Check main branch has new commit
    main_commits_after=$(git rev-list --count main)
    if [[ $main_commits_after -gt $main_commits_before ]]; then
        # Verify the changes were merged
        git checkout main
        if [[ -f "anti1.txt" ]] && [[ -f "anti2.txt" ]]; then
            log_success "Changes successfully saved to main branch"
            git checkout anti-eneo
            return 0
        else
            log_error "Changes not properly merged to main"
            git checkout anti-eneo
            return 1
        fi
    else
        log_error "No new commit on main branch"
        return 1
    fi
}

# Test 2: Save-to validation - wrong branch
test_save_to_wrong_branch() {
    log_test "Testing save-to from wrong branch..."
    
    cd "$TEST_REPO"
    git checkout main
    
    # Try to save-to from main (not anti-eneo)
    output=$(echo "Test" | "$ANTI_ENEO" --save-to=develop 2>&1 || true)
    
    if echo "$output" | grep -q "Must be on.*branch"; then
        log_success "Correctly rejected save-to from wrong branch"
        return 0
    else
        log_error "Failed to validate branch requirement"
        echo "Actual output: $output"
        return 1
    fi
}

# Test 3: Save-to validation - non-existent target
test_save_to_nonexistent_branch() {
    log_test "Testing save-to non-existent branch..."
    
    cd "$TEST_REPO"
    git checkout anti-eneo
    
    # Try to save to non-existent branch
    output=$(echo "Test" | "$ANTI_ENEO" --save-to=nonexistent 2>&1 || true)
    
    if echo "$output" | grep -q "Branch 'nonexistent' does not exist"; then
        log_success "Correctly rejected non-existent target branch"
        return 0
    else
        log_error "Failed to validate target branch existence"
        return 1
    fi
}

# Test 4: Save-to with no changes
test_save_to_no_changes() {
    log_test "Testing save-to with no changes..."
    
    cd "$TEST_REPO"
    
    # Reset anti-eneo to match main
    git checkout main
    git branch -D anti-eneo
    git checkout -b anti-eneo
    
    # Try to save (no changes)
    output=$(echo "Test" | "$ANTI_ENEO" --save-to=main 2>&1 || true)
    
    if echo "$output" | grep -q "No changes to save"; then
        log_success "Correctly handled no changes scenario"
        return 0
    else
        log_error "Failed to detect no changes condition"
        return 1
    fi
}

# Test 5: Save-to with empty commit message
test_save_to_empty_message() {
    log_test "Testing save-to with empty commit message..."
    
    cd "$TEST_REPO"
    git checkout anti-eneo
    
    # Make a new change
    echo "New change" > new.txt
    git add new.txt
    git commit -m "New change"
    
    # Try save-to with empty message (just press enter)
    output=$(echo "" | "$ANTI_ENEO" --save-to=develop 2>&1 || true)
    
    if echo "$output" | grep -q "Commit message cannot be empty"; then
        log_success "Correctly rejected empty commit message"
        # Cleanup staged changes
        git checkout develop
        git reset --hard
        git checkout anti-eneo
        return 0
    else
        log_error "Failed to validate commit message"
        return 1
    fi
}

# Test 6: Save-to with merge conflicts
test_save_to_conflicts() {
    log_test "Testing save-to with merge conflicts..."
    
    cd "$TEST_REPO"
    
    # Create conflicting changes
    git checkout main
    echo "Main version" > conflict.txt
    git add conflict.txt
    git commit -m "Main conflict"
    
    git checkout anti-eneo
    echo "Anti-eneo version" > conflict.txt
    git add conflict.txt
    git commit -m "Anti-eneo conflict"
    
    # Try save-to (will have conflicts)
    output=$(echo "Test" | "$ANTI_ENEO" --save-to=main 2>&1 || true)
    
    if echo "$output" | grep -q "Merge conflicts detected"; then
        log_success "Correctly handled merge conflicts"
        # Cleanup
        git merge --abort 2>/dev/null || true
        git checkout anti-eneo
        return 0
    else
        log_error "Failed to handle merge conflicts properly"
        return 1
    fi
}

# Test 7: Save-to different branches
test_save_to_multiple_branches() {
    log_test "Testing save-to multiple different branches..."
    
    cd "$TEST_REPO"
    git checkout anti-eneo
    
    # Add unique change
    echo "Multi-branch test" > multi.txt
    git add multi.txt
    git commit -m "Multi-branch change"
    
    # Save to develop
    echo "Save to develop" | "$ANTI_ENEO" --save-to=develop
    
    # Verify change in develop
    git checkout develop
    if [[ ! -f "multi.txt" ]]; then
        log_error "Failed to save to develop branch"
        return 1
    fi
    
    # Go back and save to feature-test
    git checkout anti-eneo
    echo "Another change" > another.txt
    git add another.txt
    git commit -m "Another change"
    
    echo "Save to feature" | "$ANTI_ENEO" --save-to=feature-test
    
    # Verify change in feature-test
    git checkout feature-test
    if [[ ! -f "another.txt" ]]; then
        log_error "Failed to save to feature-test branch"
        return 1
    fi
    
    log_success "Successfully saved to multiple branches"
    git checkout anti-eneo
    return 0
}

# Run all tests
run_all_tests() {
    local failed=0
    
    echo "================================"
    echo "Anti-Eneo Save-To Functionality Tests"
    echo "================================"
    echo
    
    # Setup
    setup_test_env
    
    # Run tests
    test_basic_save_to || ((failed++))
    echo
    
    test_save_to_wrong_branch || ((failed++))
    echo
    
    test_save_to_nonexistent_branch || ((failed++))
    echo
    
    test_save_to_no_changes || ((failed++))
    echo
    
    test_save_to_empty_message || ((failed++))
    echo
    
    test_save_to_conflicts || ((failed++))
    echo
    
    test_save_to_multiple_branches || ((failed++))
    echo
    
    # Summary
    echo "================================"
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All save-to tests passed!${NC}"
    else
        echo -e "${RED}$failed save-to tests failed${NC}"
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