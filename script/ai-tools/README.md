# AI Tools Collection

Koleksi script untuk menginstall berbagai AI development tools yang berguna untuk coding dan development.

## 🛠️ Available AI Tools

### 1. OpenCode AI
- **Script**: `opencode.sh`
- **Description**: AI-powered code editor and assistant
- **Command**: `opencode`
- **Website**: https://opencode.ai
- **Installation**: `bash script/ai-tools/opencode.sh`

### 2. OpenAI Codex
- **Script**: `codex-install.sh`
- **Description**: OpenAI's code generation and completion tool
- **Command**: `codex`
- **Website**: https://platform.openai.com
- **Installation**: `bash script/ai-tools/codex-install.sh`
- **API Key**: https://platform.openai.com/api-keys

### 3. Google Gemini CLI
- **Script**: `gemini-install.sh`
- **Description**: Google's Gemini AI model CLI interface
- **Command**: `gemini`
- **Website**: https://aistudio.google.com
- **Installation**: `bash script/ai-tools/gemini-install.sh`
- **API Key**: https://aistudio.google.com/app/apikey

### 4. Qwen Code CLI
- **Script**: `qwen-install.sh`
- **Description**: Qwen Code model for code generation and analysis
- **Command**: `qwen-code`
- **Website**: https://github.com/QwenLM/Qwen-Code
- **Installation**: `bash script/ai-tools/qwen-install.sh`

### 5. CodeRabbit CLI
- **Script**: `coderabbit-install.sh`
- **Description**: AI-powered code review and analysis tool
- **Command**: `coderabbit`
- **Website**: https://coderabbit.ai
- **Installation**: `bash script/ai-tools/coderabbit-install.sh`

### 6. Cursor AI Code Editor
- **Script**: `cursor-install.sh`
- **Description**: AI-powered code editor with intelligent assistance
- **Command**: `cursor-agent` (CLI), `cursor` (GUI application)
- **Website**: https://cursor.com
- **Installation**: `bash script/ai-tools/cursor-install.sh`

## 🚀 Quick Installation

### Install All AI Tools
```bash
bash script/ai-tools/install-all-ai-tools.sh
```

### Install Individual Tools
```bash
# OpenCode AI
bash script/ai-tools/opencode.sh

# OpenAI Codex
bash script/ai-tools/codex-install.sh

# Google Gemini CLI
bash script/ai-tools/gemini-install.sh

# Qwen Code CLI
bash script/ai-tools/qwen-install.sh

# CodeRabbit CLI
bash script/ai-tools/coderabbit-install.sh

# Cursor AI Code Editor
bash script/ai-tools/cursor-install.sh
```

### Auto-Refresh Environment
```bash
# Refresh all AI tools environment automatically
bash script/ai-tools/ai-tools-refresh.sh
```

## 🧪 Testing

### Test All Scripts
```bash
bash script/ai-tools/test-all-ai-tools.sh
```

### Test Individual Scripts
```bash
bash -n script/ai-tools/[script-name].sh
```

## 🔧 Troubleshooting

### Auto-Refresh Environment
If any AI tools are not accessible after installation:
```bash
bash script/ai-tools/ai-tools-refresh.sh
```

This script will:
- ✅ Automatically detect your shell (bash/zsh)
- ✅ Configure PATH for all AI tools
- ✅ Refresh your shell environment
- ✅ Verify all installations
- ✅ Show usage examples

### Common Issues

1. **Command not found**: Restart terminal or run `source ~/.bashrc`
2. **Permission denied**: Make script executable with `chmod +x script/ai-tools/[script-name].sh`
3. **Node.js required**: Install Node.js first for npm-based tools
4. **API key needed**: Configure API keys for tools that require authentication

## 📋 Prerequisites

- **Node.js** (for npm-based tools)
- **npm** (comes with Node.js)
- **curl** (for downloading installers)
- **bash** (for running scripts)

## 🔑 API Configuration

Most AI tools require API keys for full functionality:

1. **OpenAI Codex**: Get API key from https://platform.openai.com/api-keys
2. **Google Gemini**: Get API key from https://aistudio.google.com/app/apikey
3. **CodeRabbit**: Sign up at https://coderabbit.ai

## 📚 Usage Examples

### OpenCode AI
```bash
opencode                    # Start TUI
opencode --help            # Show help
opencode run 'hello world'  # Run with message
opencode auth              # Manage credentials
```

### OpenAI Codex
```bash
codex --version            # Check version
codex config              # Configure API key
codex                     # Start interactive mode
```

### Google Gemini CLI
```bash
gemini --version          # Check version
gemini config             # Configure API key
gemini                    # Start interactive mode
```

### Qwen Code CLI
```bash
qwen-code --version       # Check version
qwen-code config          # Configure settings
qwen-code                 # Start interactive mode
```

### CodeRabbit CLI
```bash
coderabbit --version     # Check version
coderabbit auth          # Authenticate
coderabbit               # Start interactive mode
```

### Cursor AI Code Editor
```bash
cursor-agent --version  # Check version
cursor-agent --help     # Show help
cursor-agent            # Start Cursor Agent (CLI)
# Note: Cursor GUI application launches from desktop
```

## 🎯 Features

- ✅ **Error Handling**: All scripts use `set -euo pipefail`
- ✅ **Installation Verification**: Automatic verification after installation
- ✅ **PATH Configuration**: Automatic PATH setup where needed
- ✅ **Prerequisites Check**: Validates required tools before installation
- ✅ **Clear Feedback**: Detailed progress and error messages
- ✅ **Idempotent**: Safe to run multiple times

## 📝 Script Standards

All AI tools scripts follow these standards:

1. **Error Handling**: `set -euo pipefail`
2. **Prerequisites Check**: Validate required tools
3. **Installation Verification**: Check if installation succeeded
4. **Clear Output**: Informative messages with emojis
5. **Next Steps**: Provide usage instructions
6. **Error Recovery**: Graceful failure handling

## 🤝 Contributing

To add new AI tools:

1. Create new script in `script/ai-tools/`
2. Follow existing script standards
3. Add to `install-all-ai-tools.sh`
4. Update this README
5. Test with `test-all-ai-tools.sh`

## 📄 License

This collection is part of the HADES Script Collection Management System.
