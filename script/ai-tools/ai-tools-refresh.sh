#!/usr/bin/env bash

# AI Tools Auto-Refresh Script
# This script automatically refreshes shell environment and fixes PATH issues
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

echo "🔄 AI Tools Auto-Refresh Script"
echo "==============================="

# Detect shell
if [[ -n "${ZSH_VERSION:-}" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
    SHELL_NAME="zsh"
else
    SHELL_CONFIG="$HOME/.bashrc"
    SHELL_NAME="bash"
fi

echo "💡 Shell detected: $SHELL_NAME"
echo "📁 Config file: $SHELL_CONFIG"
echo ""

# Function to add PATH if not exists
add_path_if_missing() {
    local path_to_add="$1"
    local tool_name="$2"
    
    if grep -q "$path_to_add" "$SHELL_CONFIG" 2>/dev/null; then
        echo "✅ $tool_name PATH already configured"
    else
        echo "➕ Adding $tool_name PATH configuration..."
        echo "" >> "$SHELL_CONFIG"
        echo "# $tool_name" >> "$SHELL_CONFIG"
        echo "export PATH=\"$path_to_add:\$PATH\"" >> "$SHELL_CONFIG"
        echo "✅ $tool_name PATH added to $SHELL_CONFIG"
    fi
}

# Check and configure common AI tools paths
echo "🔍 Checking AI tools installations..."

# OpenCode AI
if [[ -f "$HOME/.opencode/bin/opencode" ]]; then
    echo "✅ OpenCode AI found"
    add_path_if_missing "$HOME/.opencode/bin" "OpenCode AI"
    export PATH="$HOME/.opencode/bin:$PATH"
else
    echo "⚠️  OpenCode AI not found"
fi

# Cursor Agent
if [[ -f "$HOME/.local/bin/cursor-agent" ]]; then
    echo "✅ Cursor Agent found"
    add_path_if_missing "$HOME/.local/bin" "Cursor Agent"
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "⚠️  Cursor Agent not found"
fi

# Node.js global packages (for npm-based tools)
if command -v npm &> /dev/null; then
    NPM_GLOBAL_BIN=$(npm config get prefix)/bin
    if [[ -d "$NPM_GLOBAL_BIN" ]]; then
        echo "✅ Node.js global packages found"
        add_path_if_missing "$NPM_GLOBAL_BIN" "Node.js Global Packages"
        export PATH="$NPM_GLOBAL_BIN:$PATH"
    fi
fi

echo ""
echo "🔄 Refreshing shell environment..."

# Refresh shell environment
if [[ -n "${ZSH_VERSION:-}" ]]; then
    # For zsh
    if [[ -f "$HOME/.zshrc" ]]; then
        source "$HOME/.zshrc"
        echo "✅ Zsh environment refreshed"
    fi
else
    # For bash
    if [[ -f "$HOME/.bashrc" ]]; then
        source "$HOME/.bashrc"
        echo "✅ Bash environment refreshed"
    fi
fi

echo ""
echo "🔍 Verifying AI tools..."

# Verify tools
declare -a TOOLS=(
    "opencode:OpenCode AI"
    "cursor-agent:Cursor Agent"
    "codex:OpenAI Codex"
    "gemini:Google Gemini"
    "qwen-code:Qwen Code"
    "coderabbit:CodeRabbit"
)

VERIFIED_COUNT=0
TOTAL_COUNT=${#TOOLS[@]}

for tool_info in "${TOOLS[@]}"; do
    IFS=':' read -r command tool_name <<< "$tool_info"
    
    if command -v "$command" &> /dev/null; then
        echo "✅ $tool_name: $(which $command)"
        ((VERIFIED_COUNT++))
    else
        echo "⚠️  $tool_name: not accessible"
    fi
done

echo ""
echo "📊 Summary:"
echo "  Verified: $VERIFIED_COUNT/$TOTAL_COUNT tools"
echo "  Shell: $SHELL_NAME"
echo "  Config: $SHELL_CONFIG"

if [[ $VERIFIED_COUNT -eq $TOTAL_COUNT ]]; then
    echo ""
    echo "🎉 All AI tools are ready to use!"
    echo ""
    echo "📋 Quick commands:"
    echo "  opencode --version     # OpenCode AI"
    echo "  cursor-agent --version # Cursor Agent"
    echo "  codex --version        # OpenAI Codex"
    echo "  gemini --version       # Google Gemini"
    echo "  qwen-code --version    # Qwen Code"
    echo "  coderabbit --version   # CodeRabbit"
else
    echo ""
    echo "⚠️  Some tools are not accessible. You may need to:"
    echo "  1. Install missing tools: bash script/ai-tools/install-all-ai-tools.sh"
    echo "  2. Restart your terminal"
    echo "  3. Run this script again: bash script/ai-tools/ai-tools-refresh.sh"
fi

echo ""
echo "✅ Auto-refresh completed!"
echo "💡 Tip: Run this script anytime to refresh your AI tools environment"
