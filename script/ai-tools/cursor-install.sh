#!/usr/bin/env bash

# Cursor AI Code Editor Installation Script
# This script installs Cursor using the official installation method
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

echo "🚀 Installing Cursor AI Code Editor..."
echo "====================================="

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "❌ Error: curl is required but not installed."
    echo "Please install curl first:"
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install curl"
    echo "  CentOS/RHEL: sudo yum install curl"
    echo "  macOS: curl should be pre-installed"
    exit 1
fi

# Run the official Cursor installation command
echo "📥 Downloading and installing Cursor..."
echo "⚠️  Note: This will install Cursor AI Code Editor"

# Try to run installation with automatic responses
if curl https://cursor.com/install -fsS | bash; then
    echo "✅ Installation completed successfully"
else
    echo "❌ Installation failed"
    exit 1
fi

echo ""
echo "✅ Cursor AI Code Editor installation completed!"

# Try to verify installation
echo "🔍 Verifying installation..."

# Check if cursor binary exists in common locations
CURSOR_PATHS=(
    "/usr/local/bin/cursor"
    "/opt/cursor/cursor"
    "/home/$USER/.local/bin/cursor"
    "/home/$USER/cursor/cursor"
)

CURSOR_FOUND=false
for path in "${CURSOR_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        echo "✅ Cursor binary found: $path"
        CURSOR_FOUND=true
        
        # Try to add to PATH temporarily for verification
        export PATH="$(dirname "$path"):$PATH"
        
        if command -v cursor &> /dev/null; then
            echo "✅ Cursor command accessible: $(which cursor)"
            if cursor --version &> /dev/null; then
                echo "✅ Cursor version: $(cursor --version)"
            else
                echo "⚠️  Cursor installed but version check failed"
            fi
        else
            echo "⚠️  Cursor binary exists but not in PATH"
        fi
        break
    fi
done

if [[ "$CURSOR_FOUND" == false ]]; then
    echo "⚠️  Cursor binary not found in common locations"
    echo "   Installation may have succeeded but binary location is unknown"
    echo "   Try running 'cursor' command or check your desktop applications"
fi

# Check if cursor is available as a command
if command -v cursor &> /dev/null; then
    echo "✅ Cursor is accessible from command line"
    
    # Detect shell and check appropriate config file
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        SHELL_CONFIG="$HOME/.zshrc"
        SHELL_NAME="zsh"
    else
        SHELL_CONFIG="$HOME/.bashrc"
        SHELL_NAME="bash"
    fi
    
    # Check if PATH is configured in shell config
    if grep -q "cursor" "$SHELL_CONFIG" 2>/dev/null; then
        echo "✅ PATH configuration found in $SHELL_CONFIG"
    else
        echo "⚠️  PATH not configured in $SHELL_CONFIG"
        echo "   This is normal for GUI applications like Cursor"
    fi
else
    echo "⚠️  Cursor not accessible from command line"
    echo "   This is normal for GUI applications - check your applications menu"
fi

echo ""
echo "📋 Next steps:"
echo "1. Refresh your shell session:"
if [[ -n "${ZSH_VERSION:-}" ]]; then
    echo "   source ~/.zshrc"
    echo "   # OR restart your terminal"
    echo "💡 Shell detected: zsh"
else
    echo "   source ~/.bashrc"
    echo "   # OR restart your terminal"
    echo "💡 Shell detected: bash"
fi
echo ""
echo "2. Verify installation: cursor-agent --version"
echo "3. Look for Cursor in your applications menu"
echo "4. Launch Cursor from the desktop environment"
echo "5. Sign in with your account to access AI features"
echo "6. Start coding with AI assistance!"
echo ""
echo "🎉 Happy coding with Cursor AI!"
