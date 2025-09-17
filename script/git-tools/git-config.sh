#!/bin/bash

# Git Configuration Script
# This script configures Git with user name and email globally

set -euo pipefail  # Exit on any error, undefined vars, pipe failures

echo "⚙️  Git Configuration Setup"
echo "=========================="

# Function to get user input with default value
get_input() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " value
        echo "${value:-$default}"
    else
        read -p "$prompt: " value
        echo "$value"
    fi
}

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get current Git configuration
current_name=$(git config --global user.name 2>/dev/null || echo "")
current_email=$(git config --global user.email 2>/dev/null || echo "")

echo "📋 Current Git Configuration:"
echo "  Name: ${current_name:-'Not set'}"
echo "  Email: ${current_email:-'Not set'}"
echo ""

# Get user input for name
echo "🔧 Configure Git User Information"
echo "---------------------------------"

name=$(get_input "Enter your full name (for commit history)" "$current_name")

if [[ -z "$name" ]]; then
    echo "❌ Error: Name cannot be empty"
    exit 1
fi

# Get user input for email
email=$(get_input "Enter your email address" "$current_email")

if [[ -z "$email" ]]; then
    echo "❌ Error: Email cannot be empty"
    exit 1
fi

# Validate email format
if ! validate_email "$email"; then
    echo "❌ Error: Invalid email format"
    exit 1
fi

# Confirm configuration
echo ""
echo "📝 Configuration Summary:"
echo "  Name: $name"
echo "  Email: $email"
echo ""

read -p "Do you want to apply this configuration? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Configuration cancelled"
    exit 0
fi

# Apply Git configuration
echo ""
echo "🔧 Applying Git configuration..."

git config --global user.name "$name"
git config --global user.email "$email"

# Set additional useful Git configurations
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global push.default simple
git config --global core.editor nano

echo ""
echo "✅ Git configuration completed successfully!"
echo ""
echo "📋 Applied Configuration:"
echo "  Name: $(git config --global user.name)"
echo "  Email: $(git config --global user.email)"
echo "  Default Branch: $(git config --global init.defaultBranch)"
echo "  Core Editor: $(git config --global core.editor)"
echo ""
echo "🎉 Git is now configured and ready to use!"
echo ""
echo "💡 Next steps:"
echo "1. Test your configuration: git config --list --global"
echo "2. Create your first repository: git init"
echo "3. Make your first commit: git add . && git commit -m 'Initial commit'"
