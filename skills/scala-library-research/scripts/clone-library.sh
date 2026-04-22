#!/bin/bash

# Library Learning Helper Script
# This script helps clone and analyze library repositories for learning purposes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
REPO_NAME=""
OWNER=""
BRANCH=""
TARGET_DIR=""

print_usage() {
    echo "Usage: $0 --repo <repository> [--owner <owner>] [--branch <branch>] [--target <directory>]"
    echo ""
    echo "Example:"
    echo "  $0 --repo cats-effect --owner typelevel --branch main"
    echo "  $0 --repo scala-util --owner lihaoyi --target tmp-lib"
    echo ""
    echo "If --target is not specified, the repo name will be used"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO_NAME="$2"
            shift 2
            ;;
        --owner)
            OWNER="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$REPO_NAME" ]]; then
    echo -e "${RED}Error: --repo is required${NC}"
    print_usage
    exit 1
fi

# Set default values
if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="$REPO_NAME"
fi

if [[ -z "$BRANCH" ]]; then
    BRANCH="main"
fi

# Full repository path
REPO_URL="https://github.com/${OWNER}/${REPO_NAME}.git"

echo -e "${BLUE}=== Library Learning Helper ===${NC}"
echo ""
echo "Repository: $REPO_URL"
echo "Target directory: $TARGET_DIR"
echo "Branch: $BRANCH"
echo ""

# Check if directory already exists
if [[ -d "$TARGET_DIR" ]]; then
    echo -e "${YELLOW}Warning: Directory '$TARGET_DIR' already exists${NC}"
    read -p "Do you want to clone to '$TARGET_DIR' (overwrites existing files)? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    rm -rf "$TARGET_DIR"
fi

# Create directory
mkdir -p "$TARGET_DIR"

# Clone repository
echo -e "${GREEN}Cloning repository...${NC}"
git clone -b "$BRANCH" --depth 1 "$REPO_URL" "$TARGET_DIR" || {
    echo -e "${RED}Failed to clone repository${NC}"
    rm -rf "$TARGET_DIR"
    exit 1
}

echo ""
echo -e "${GREEN}Success! Repository cloned to '$TARGET_DIR'${NC}"
echo ""
echo "Useful commands:"
echo "  cd '$TARGET_DIR'"
echo "  find . -name '*.md' | head -20       # Find documentation files"
echo "  find . -name '*.scala' | grep test  # Find test files"
echo "  grep -r 'def ' --include='*.scala' | head -20  # Find public methods"
echo "  git log --oneline -10                 # Recent commits"
echo ""
echo "Available tools:"
echo "  - read: Read source files from '$TARGET_DIR'"
echo "  - grep: Search for patterns in the cloned code"
echo "  - glob: Find files in the cloned repository"
echo ""
