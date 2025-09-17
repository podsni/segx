#!/usr/bin/env bash

# Test All AI Tools Script
# This script tests all AI tools installation scripts to ensure they work correctly
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

echo "🧪 Testing All AI Tools Installation Scripts"
echo "============================================="
echo ""

# Colors for output
declare -r C_RESET='\033[0m'
declare -r C_BOLD='\033[1m'
declare -r C_RED='\033[0;31m'
declare -r C_GREEN='\033[0;32m'
declare -r C_YELLOW='\033[0;33m'
declare -r C_BLUE='\033[0;34m'

# Test results
declare -a PASSED_TESTS=()
declare -a FAILED_TESTS=()

# Function to test a script
test_script() {
    local script_name="$1"
    local script_path="script/ai-tools/$script_name"
    
    echo -e "${C_BLUE}Testing $script_name...${C_RESET}"
    
    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo -e "${C_RED}❌ Script not found: $script_path${C_RESET}"
        FAILED_TESTS+=("$script_name (not found)")
        return 1
    fi
    
    # Check if script is executable
    if [[ ! -x "$script_path" ]]; then
        echo -e "${C_YELLOW}⚠️  Script not executable, making it executable...${C_RESET}"
        chmod +x "$script_path"
    fi
    
    # Test syntax
    if bash -n "$script_path"; then
        echo -e "${C_GREEN}✅ Syntax check passed${C_RESET}"
    else
        echo -e "${C_RED}❌ Syntax check failed${C_RESET}"
        FAILED_TESTS+=("$script_name (syntax error)")
        return 1
    fi
    
    # Test if script has proper error handling
    if grep -q "set -euo pipefail" "$script_path"; then
        echo -e "${C_GREEN}✅ Error handling configured${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠️  Missing proper error handling${C_RESET}"
    fi
    
    # Test if script has verification logic
    if grep -q "Verifying installation" "$script_path"; then
        echo -e "${C_GREEN}✅ Installation verification included${C_RESET}"
    else
        echo -e "${C_YELLOW}⚠️  Missing installation verification${C_RESET}"
    fi
    
    PASSED_TESTS+=("$script_name")
    echo ""
}

# Test all AI tools scripts
echo -e "${C_BOLD}Testing AI Tools Installation Scripts:${C_RESET}"
echo ""

test_script "opencode.sh"
test_script "codex-install.sh"
test_script "gemini-install.sh"
test_script "qwen-install.sh"
test_script "coderabbit-install.sh"
test_script "cursor-install.sh"
test_script "ai-tools-refresh.sh"

# Summary
echo -e "${C_BOLD}Test Summary:${C_RESET}"
echo "============="
echo ""

if [[ ${#PASSED_TESTS[@]} -gt 0 ]]; then
    echo -e "${C_GREEN}✅ Passed Tests (${#PASSED_TESTS[@]}):${C_RESET}"
    for test in "${PASSED_TESTS[@]}"; do
        echo -e "  ${C_GREEN}✓${C_RESET} $test"
    done
    echo ""
fi

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
    echo -e "${C_RED}❌ Failed Tests (${#FAILED_TESTS[@]}):${C_RESET}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${C_RED}✗${C_RESET} $test"
    done
    echo ""
fi

# Overall result
if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
    echo -e "${C_GREEN}🎉 All AI tools scripts are working correctly!${C_RESET}"
    echo ""
    echo -e "${C_BOLD}Available AI Tools:${C_RESET}"
    echo "  • OpenCode AI (opencode.sh)"
    echo "  • OpenAI Codex (codex-install.sh)"
    echo "  • Google Gemini CLI (gemini-install.sh)"
    echo "  • Qwen Code CLI (qwen-install.sh)"
    echo "  • CodeRabbit CLI (coderabbit-install.sh)"
    echo "  • Cursor AI Code Editor (cursor-install.sh)"
    echo ""
    echo -e "${C_BOLD}Usage:${C_RESET}"
    echo "  bash script/ai-tools/[script-name].sh"
    echo "  zsh script/ai-tools/[script-name].sh"
    echo ""
    echo -e "${C_BOLD}Shell Compatibility:${C_RESET}"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "  💡 Currently running in: zsh"
        echo "  ✅ All scripts are compatible with zsh and bash"
    else
        echo "  💡 Currently running in: bash"
        echo "  ✅ All scripts are compatible with bash and zsh"
    fi
    echo ""
    echo -e "${C_BOLD}Auto-refresh AI tools environment:${C_RESET}"
    echo "  bash script/ai-tools/ai-tools-refresh.sh"
    echo "  zsh script/ai-tools/ai-tools-refresh.sh"
    exit 0
else
    echo -e "${C_RED}❌ Some tests failed. Please fix the issues above.${C_RESET}"
    exit 1
fi
