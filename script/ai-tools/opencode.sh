#!/usr/bin/env bash

# OpenCode AI Installation Script
# This script installs OpenCode AI using the official installation method
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

echo "🚀 Installing OpenCode AI..."
echo "================================"

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "❌ Error: curl is required but not installed."
    echo "Please install curl first:"
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install curl"
    echo "  CentOS/RHEL: sudo yum install curl"
    echo "  macOS: curl should be pre-installed"
    exit 1
fi

# Run the official OpenCode AI installation command
echo "📥 Downloading and installing OpenCode AI..."
echo "⚠️  Note: This may prompt to replace existing files. Choose 'y' or 'A' to continue."

# Try to run installation with automatic yes responses
if curl -fsSL https://opencode.ai/install | bash -s -- --yes; then
    echo "✅ Installation completed with automatic responses"
elif curl -fsSL https://opencode.ai/install | bash; then
    echo "✅ Installation completed with manual responses"
else
    echo "❌ Installation failed"
    exit 1
fi

echo ""
echo "✅ OpenCode AI installation completed!"

# Try to verify installation
echo "🔍 Verifying installation..."

# Check if opencode binary exists
if [[ -f "/home/$USER/.opencode/bin/opencode" ]]; then
    echo "✅ OpenCode AI binary found: /home/$USER/.opencode/bin/opencode"
    
    # Try to add to PATH temporarily for verification
    export PATH="/home/$USER/.opencode/bin:$PATH"
    
    if command -v opencode &> /dev/null; then
        echo "✅ OpenCode AI command accessible: $(which opencode)"
        if opencode --version &> /dev/null; then
            echo "✅ OpenCode AI version: $(opencode --version)"
        else
            echo "⚠️  OpenCode AI installed but version check failed"
        fi
    else
        echo "⚠️  OpenCode AI binary exists but not in PATH"
    fi
    
    # Detect shell and configure appropriate config file
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        SHELL_CONFIG="$HOME/.zshrc"
        SHELL_NAME="zsh"
    else
        SHELL_CONFIG="$HOME/.bashrc"
        SHELL_NAME="bash"
    fi
    
    # Check if PATH is configured in shell config
    if grep -q "opencode/bin" "$SHELL_CONFIG" 2>/dev/null; then
        echo "✅ PATH configuration found in $SHELL_CONFIG"
    else
        echo "⚠️  PATH not configured in $SHELL_CONFIG"
        echo "   Adding PATH configuration..."
        echo "" >> "$SHELL_CONFIG"
        echo "# OpenCode AI" >> "$SHELL_CONFIG"
        echo "export PATH=\"/home/$USER/.opencode/bin:\$PATH\"" >> "$SHELL_CONFIG"
        echo "✅ PATH configuration added to $SHELL_CONFIG"
    fi
else
    echo "❌ OpenCode AI binary not found"
    echo "   Installation may have failed"
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
echo "2. Verify installation: opencode --version"
echo "3. Start using OpenCode AI: opencode"
echo "4. For help: opencode --help"
echo ""
echo "🎉 Happy coding with OpenCode AI!"
