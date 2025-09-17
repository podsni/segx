#!/bin/bash
# ===================================================================================
#         SKRIP INSTALASI LENGKAP: Tmux + Oh My Zsh + Konfigurasi
#
# FITUR:
# - Menginstal Tmux & Oh My Zsh.
# - Cek dependensi (tmux, git, zsh, curl) & hanya instal yang belum ada.
# - Menginstal plugin Oh My Zsh (termasuk eksternal seperti auto-suggestions).
# - Membuat file .tmux.conf dan .zshrc kustom secara otomatis.
# - Output berwarna dan informatif untuk setiap langkah.
# - Backup otomatis konfigurasi lama.
# ===================================================================================

# Hentikan eksekusi jika terjadi error
set -e

# Definisi Warna untuk output
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}  Memulai Setup Terminal Lengkap (Tmux + Oh My Zsh)  ${NC}"
echo -e "${BLUE}=====================================================${NC}"


# --- LANGKAH 1: PENGECEKAN & INSTALASI DEPENDENSI ---
echo -e "\n${BLUE}▶️  Langkah 1: Memeriksa dependensi utama...${NC}"

if command -v apt-get &> /dev/null; then
    INSTALL_CMD="sudo apt-get install -y"
elif command -v dnf &> /dev/null; then
    INSTALL_CMD="sudo dnf install -y"
elif command -v pacman &> /dev/null; then
    INSTALL_CMD="sudo pacman -S --noconfirm"
else
    echo -e "\033[1;31mError: Package manager tidak didukung (hanya apt, dnf, pacman).\033[0m"
    exit 1
fi

REQUIRED_PKGS="tmux git zsh curl"
PACKAGES_TO_INSTALL=""
for pkg in $REQUIRED_PKGS; do
    if ! command -v $pkg &> /dev/null; then
        PACKAGES_TO_INSTALL+="$pkg "
    else
        echo -e "${GREEN}  ✅ $pkg sudah terinstal.${NC}"
    fi
done

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo -e "${YELLOW}Menginstal paket yang dibutuhkan: $PACKAGES_TO_INSTALL...${NC}"
    $INSTALL_CMD $PACKAGES_TO_INSTALL
else
    echo -e "${GREEN}Semua dependensi utama sudah terpenuhi.${NC}"
fi


# --- LANGKAH 2: SETUP TMUX (TPM & Konfigurasi) ---
echo -e "\n${BLUE}▶️  Langkah 2: Menyiapkan Tmux...${NC}"

# Instalasi TPM
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
    echo -e "${GREEN}  ✅ Tmux Plugin Manager (TPM) sudah ada.${NC}"
else
    echo -e "${YELLOW}  - Menginstal TPM...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Konfigurasi .tmux.conf
TMUX_CONF="$HOME/.tmux.conf"
if [ -f "$TMUX_CONF" ]; then
    echo -e "${YELLOW}⚠️  File .tmux.conf lama ditemukan. Membuat backup...${NC}"
    mv "$TMUX_CONF" "$TMUX_CONF.bak.$(date +%F-%T)"
fi
echo -e "${BLUE}  - Membuat file .tmux.conf baru...${NC}"
cat > "$TMUX_CONF" << "EOL"
unbind C-b
set -g prefix `
set -g base-index 1
set -g pane-base-index 1
bind-key ` last-window
bind-key e send-prefix
set -g mouse on
set -g status-position bottom
set -g status-bg colour234
set -g status-fg colour137
set -g status-left ''
set -g status-right '#[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '
set -g status-right-length 50
set -g status-left-length 20
setw -g mode-keys vi
setw -g mouse on
setw -g window-status-current-format ' #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F '
setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '
set-option -g history-limit 5000
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-pain-control'
set-option -g default-shell /bin/zsh
run -b '~/.tmux/plugins/tpm/tpm'
EOL


# --- LANGKAH 3: SETUP OH MY ZSH & PLUGINS ---
echo -e "\n${BLUE}▶️  Langkah 3: Menyiapkan Oh My Zsh...${NC}"

# Instalasi Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${GREEN}  ✅ Oh My Zsh sudah terinstal.${NC}"
else
    echo -e "${YELLOW}  - Menginstal Oh My Zsh...${NC}"
    # Menggunakan flag --unattended agar skrip tidak berhenti
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Instalasi Plugin Eksternal Oh My Zsh
ZSH_CUSTOM_PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"
echo -e "${BLUE}  - Menginstal plugin kustom Oh My Zsh...${NC}"
# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM_PLUGINS_DIR}/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM_PLUGINS_DIR}/zsh-autosuggestions
else
    echo -e "${GREEN}    ✅ Plugin zsh-autosuggestions sudah ada.${NC}"
fi
# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM_PLUGINS_DIR}/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM_PLUGINS_DIR}/zsh-syntax-highlighting
else
    echo -e "${GREEN}    ✅ Plugin zsh-syntax-highlighting sudah ada.${NC}"
fi

# --- LANGKAH 4: MEMBUAT KONFIGURASI .zshrc ---
echo -e "\n${BLUE}▶️  Langkah 4: Membuat file konfigurasi .zshrc...${NC}"
ZSHRC_FILE="$HOME/.zshrc"

if [ -f "$ZSHRC_FILE" ]; then
    echo -e "${YELLOW}⚠️  File .zshrc lama ditemukan. Membuat backup...${NC}"
    mv "$ZSHRC_FILE" "$ZSHRC_FILE.bak.$(date +%F-%T)"
fi
echo -e "${BLUE}  - Membuat file .zshrc baru dengan plugin pilihan Anda...${NC}"
cat > "$ZSHRC_FILE" << 'EOL'
# Path ke instalasi Oh My Zsh Anda.
export ZSH="$HOME/.oh-my-zsh"

# Tema ZSH. "robbyrussell" adalah default, "agnoster" juga populer.
ZSH_THEME="robbyrussell"

# Daftar plugin yang akan dimuat.
# Plugin kustom (non-bundel) harus di-clone secara manual.
# Skrip ini sudah melakukannya untuk zsh-autosuggestions dan zsh-syntax-highlighting.
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  sudo
  vi-mode
  z
)

# Memuat Oh My Zsh.
source $ZSH/oh-my-zsh.sh

# User configuration
# Contoh alias
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias update='sudo apt update && sudo apt upgrade -y' # Ganti 'apt' jika perlu
# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Key binding untuk vi-mode
bindkey -v
export KEYTIMEOUT=1

# shove: git add, commit with message, confirm before push
shove() {
  git add .
  git commit -m "$*"
  echo -n "Push to origin? (y/n): "
  read confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git push origin
  else
    echo "❌ Push cancelled."
  fi
}

# shovenc: commit tanpa pesan, konfirmasi sebelum push
shovenc() {
  git add .
  git commit --allow-empty-message -m ""
  echo -n "Push to origin? (y/n): "
  read confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git push origin
  else
    echo "❌ Push cancelled."
  fi
}

EOL

# --- SELESAI ---
echo -e "\n\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}          ✨ SEMUA INSTALASI SELESAI! ✨          ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo -e "Dua langkah terakhir yang ${YELLOW}WAJIB${NC} Anda lakukan:"
echo ""
echo -e "1. ${YELLOW}TUTUP dan BUKA KEMBALI TERMINAL ANDA${NC}."
echo "   Ini penting agar Zsh menjadi shell default Anda dan semua pengaturan baru dimuat."
echo ""
echo -e "2. Setelah terminal dibuka kembali (Anda akan melihat shell Zsh yang baru), ${YELLOW}JALANKAN TMUX${NC}:"
echo "   > tmux"
echo ""
echo -e "3. Di dalam sesi tmux, ${YELLOW}INSTAL PLUGIN TMUX${NC} dengan menekan:"
echo -e "   > Prefix + I (yaitu, tekan \` lalu lepas, kemudian tekan I kapital)"
echo ""
echo "------------------------------------------------------------------"
echo "Nikmati terminal Anda yang baru dan lebih powerful!"
echo "------------------------------------------------------------------"
