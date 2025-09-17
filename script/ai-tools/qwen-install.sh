#!/usr/bin/env bash

# Qwen Code CLI Installation Script
# This script installs Qwen Code CLI tool globally using npm
# Compatible with both bash and zsh shells

# Detect shell and set compatibility
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # Zsh compatibility
    setopt shwordsplit
    setopt pipefail
    setopt errexit
    setopt nounset
else
    # Bash compatibility
    set -euo pipefail
fi

echo "🤖 Installing Qwen Code CLI..."
echo "==============================="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is required but not installed."
    echo "Please install Node.js first:"
    echo "  Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs"
    echo "  CentOS/RHEL: curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo -E bash - && sudo yum install -y nodejs"
    echo "  macOS: brew install node"
    echo "  Or visit: https://nodejs.org/"
    exit 1
fi

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is required but not installed."
    echo "npm should come with Node.js installation."
    exit 1
fi

# Display current Node.js and npm versions
echo "📋 Current versions:"
echo "  Node.js: $(node --version)"
echo "  npm: $(npm --version)"
echo ""

# Install Qwen Code CLI globally
echo "📥 Installing @qwen-code/qwen-code@latest globally..."
if npm install -g @qwen-code/qwen-code@latest; then
    echo ""
    echo "✅ Qwen Code CLI installation completed!"
    
    # Try to verify installation
    echo "🔍 Verifying installation..."
    if command -v qwen-code &> /dev/null; then
        echo "✅ Qwen Code command found: $(which qwen-code)"
        if qwen-code --version &> /dev/null; then
            echo "✅ Qwen Code version: $(qwen-code --version)"
        else
            echo "⚠️  Qwen Code installed but version check failed"
        fi
    else
        echo "⚠️  Qwen Code installed but command not found in PATH"
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            echo "   You may need to restart your terminal or run: source ~/.zshrc"
        else
            echo "   You may need to restart your terminal or run: source ~/.bashrc"
        fi
    fi
    
    echo ""
    echo "📋 Next steps:"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "1. Restart your terminal or run: source ~/.zshrc"
        echo "💡 Shell detected: zsh"
    else
        echo "1. Restart your terminal or run: source ~/.bashrc"
        echo "💡 Shell detected: bash"
    fi
echo "2. Verify installation: qwen-code --version"
echo "3. Configure your API settings: qwen-code config"
echo "4. Start using Qwen Code: qwen-code"
echo ""
echo "🔑 Don't forget to set up your API configuration!"
echo "   Visit: https://github.com/QwenLM/Qwen-Code for more information"
echo ""
echo "🎉 Happy coding with Qwen Code!"
else
    echo ""
    echo "❌ Qwen Code CLI installation failed!"
    echo "Please check your internet connection and npm configuration."
    echo "You can also try: npm install -g @qwen-code/qwen-code@latest"
    exit 1
fi
