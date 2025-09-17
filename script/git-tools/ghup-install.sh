#!/bin/bash

# Ghup CLI Installation Script
# This script installs Ghup CLI tool globally using npm

set -euo pipefail  # Exit on any error, undefined vars, pipe failures

echo "🚀 Installing Ghup CLI..."
echo "========================="

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

# Install Ghup CLI globally
echo "📥 Installing ghup globally..."
npm install -g ghup

echo ""
echo "✅ Ghup CLI installation completed!"
echo ""
echo "📋 Next steps:"
echo "1. Verify installation: ghup --version"
echo "2. Configure your settings: ghup config"
echo "3. Start using Ghup: ghup"
echo ""
echo "🔑 Don't forget to configure your settings!"
echo "   Visit: https://github.com/ghup for more information"
echo ""
echo "🎉 Happy coding with Ghup!"
