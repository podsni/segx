#!/usr/bin/env bash

# Install All AI Tools Script
# This script installs all available AI tools in one go
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

echo "🚀 Installing All AI Tools"
echo "========================="
echo ""

# Colors for output
declare -r C_RESET='\033[0m'
declare -r C_BOLD='\033[1m'
declare -r C_RED='\033[0;31m'
declare -r C_GREEN='\033[0;32m'
declare -r C_YELLOW='\033[0;33m'
declare -r C_BLUE='\033[0;34m'

# Installation results
declare -a INSTALLED_TOOLS=()
declare -a FAILED_TOOLS=()

# Function to install a tool
install_tool() {
    local tool_name="$1"
    local script_path="script/ai-tools/$tool_name"
    
    echo -e "${C_BLUE}Installing $tool_name...${C_RESET}"
    echo "----------------------------------------"
    
    if [[ -f "$script_path" ]]; then
        if bash "$script_path"; then
            echo -e "${C_GREEN}✅ $tool_name installed successfully${C_RESET}"
            INSTALLED_TOOLS+=("$tool_name")
        else
            echo -e "${C_RED}❌ $tool_name installation failed${C_RESET}"
            FAILED_TOOLS+=("$tool_name")
        fi
    else
        echo -e "${C_RED}❌ Script not found: $script_path${C_RESET}"
        FAILED_TOOLS+=("$tool_name (script not found)")
    fi
    
    echo ""
}

# Check prerequisites
echo -e "${C_BOLD}Checking Prerequisites:${C_RESET}"

# Check Node.js (required for most tools)
if command -v node &> /dev/null; then
    echo -e "${C_GREEN}✅ Node.js: $(node --version)${C_RESET}"
else
    echo -e "${C_YELLOW}⚠️  Node.js not found - some tools may not work${C_RESET}"
fi

# Check npm
if command -v npm &> /dev/null; then
    echo -e "${C_GREEN}✅ npm: $(npm --version)${C_RESET}"
else
    echo -e "${C_YELLOW}⚠️  npm not found - some tools may not work${C_RESET}"
fi

# Check curl
if command -v curl &> /dev/null; then
    echo -e "${C_GREEN}✅ curl: available${C_RESET}"
else
    echo -e "${C_YELLOW}⚠️  curl not found - some tools may not work${C_RESET}"
fi

echo ""
echo -e "${C_BOLD}Starting Installation:${C_RESET}"
echo ""

# Install all AI tools
install_tool "opencode.sh"
install_tool "codex-install.sh"
install_tool "gemini-install.sh"
install_tool "qwen-install.sh"
install_tool "coderabbit-install.sh"
install_tool "cursor-install.sh"

# Auto-refresh AI tools environment
echo -e "${C_BLUE}Auto-refreshing AI tools environment...${C_RESET}"
if bash script/ai-tools/ai-tools-refresh.sh; then
    echo -e "${C_GREEN}✅ AI tools environment refreshed${C_RESET}"
else
    echo -e "${C_YELLOW}⚠️  AI tools environment refresh failed${C_RESET}"
fi

echo ""

# Summary
echo -e "${C_BOLD}Installation Summary:${C_RESET}"
echo "====================="
echo ""

if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
    echo -e "${C_GREEN}✅ Successfully Installed (${#INSTALLED_TOOLS[@]}):${C_RESET}"
    for tool in "${INSTALLED_TOOLS[@]}"; do
        echo -e "  ${C_GREEN}✓${C_RESET} $tool"
    done
    echo ""
fi

if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
    echo -e "${C_RED}❌ Failed Installations (${#FAILED_TOOLS[@]}):${C_RESET}"
    for tool in "${FAILED_TOOLS[@]}"; do
        echo -e "  ${C_RED}✗${C_RESET} $tool"
    done
    echo ""
fi

# Next steps
echo -e "${C_BOLD}Next Steps:${C_RESET}"
echo "==========="
echo ""
if [[ -n "${ZSH_VERSION:-}" ]]; then
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "💡 Shell detected: zsh"
else
    echo "1. Restart your terminal or run: source ~/.bashrc"
    echo "💡 Shell detected: bash"
fi
echo "2. Verify installations:"
echo "   • opencode --version"
echo "   • codex --version"
echo "   • gemini --version"
echo "   • qwen-code --version"
echo "   • coderabbit --version"
echo "   • cursor (check applications menu)"
echo ""
echo "3. Configure API keys as needed:"
echo "   • OpenAI: https://platform.openai.com/api-keys"
echo "   • Google: https://aistudio.google.com/app/apikey"
echo "   • CodeRabbit: https://coderabbit.ai"
echo ""
echo "4. Start using your AI tools!"
echo ""

if [[ ${#FAILED_TOOLS[@]} -eq 0 ]]; then
    echo -e "${C_GREEN}🎉 All AI tools installed successfully!${C_RESET}"
    exit 0
else
    echo -e "${C_YELLOW}⚠️  Some installations failed. Check the errors above.${C_RESET}"
    exit 1
fi
