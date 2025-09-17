#!/bin/bash
# ===================================================================================
# Skrip Instalasi Cerdas untuk Tmux, TPM, dan Konfigurasi Kustom.
#
# FITUR:
# - Cek dependensi (tmux, git, zsh) & hanya instal yang belum ada.
# - Output berwarna dan informatif untuk setiap langkah.
# - Backup otomatis konfigurasi lama.
# - Menggunakan persis konfigurasi .tmux.conf yang Anda berikan.
# ===================================================================================

# Hentikan eksekusi jika terjadi error
set -e

# Definisi Warna untuk output
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# --- LANGKAH 1: PENGECEKAN & INSTALASI DEPENDENSI ---
echo -e "${BLUE}▶️  Langkah 1: Memeriksa dependensi...${NC}"

# Deteksi Package Manager
if command -v apt-get &> /dev/null; then
    INSTALL_CMD="sudo apt-get install -y"
    PKG_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    INSTALL_CMD="sudo dnf install -y"
    PKG_MANAGER="dnf"
elif command -v pacman &> /dev/null; then
    INSTALL_CMD="sudo pacman -S --noconfirm"
    PKG_MANAGER="pacman"
else
    echo -e "\033[1;31mError: Package manager tidak didukung (hanya apt, dnf, pacman).\033[0m"
    exit 1
fi

REQUIRED_PKGS="tmux git zsh"
PACKAGES_TO_INSTALL=""

for pkg in $REQUIRED_PKGS; do
    if ! command -v $pkg &> /dev/null; then
        echo -e "${YELLOW}  - $pkg belum terinstal. Menambahkan ke daftar instalasi.${NC}"
        PACKAGES_TO_INSTALL+="$pkg "
    else
        echo -e "${GREEN}  ✅ $pkg sudah terinstal.${NC}"
    fi
done

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo -e "${BLUE}Menginstal paket yang dibutuhkan: $PACKAGES_TO_INSTALL...${NC}"
    $INSTALL_CMD $PACKAGES_TO_INSTALL
    echo -e "${GREEN}Instalasi dependensi selesai.${NC}"
else
    echo -e "${GREEN}Semua dependensi sudah terpenuhi.${NC}"
fi

# --- LANGKAH 2: INSTALASI TMUX PLUGIN MANAGER (TPM) ---
echo -e "\n${BLUE}▶️  Langkah 2: Memeriksa Tmux Plugin Manager (TPM)...${NC}"
TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ -d "$TPM_DIR" ]; then
    echo -e "${GREEN}  ✅ TPM sudah terinstal di $TPM_DIR${NC}"
else
    echo -e "${YELLOW}  - TPM belum ada. Menginstal...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    echo -e "${GREEN}  ✅ TPM berhasil diinstal.${NC}"
fi

# --- LANGKAH 3: MEMBUAT FILE KONFIGURASI .tmux.conf ---
echo -e "\n${BLUE}▶️  Langkah 3: Menyiapkan file konfigurasi ~/.tmux.conf...${NC}"
TMUX_CONF="$HOME/.tmux.conf"

# Backup konfigurasi yang sudah ada
if [ -f "$TMUX_CONF" ]; then
    echo -e "${YELLOW}⚠️  File .tmux.conf sudah ada. Membuat backup ke ~/.tmux.conf.bak.$(date +%F-%T)${NC}"
    mv "$TMUX_CONF" "$TMUX_CONF.bak.$(date +%F-%T)"
fi

# Membuat file .tmux.conf baru dengan konten yang Anda berikan
# Menggunakan "EOL" untuk memastikan konten disalin persis seperti aslinya
cat > "$TMUX_CONF" << "EOL"
# Konfigurasi Kustom
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


# Daftar Plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-pain-control'
set-option -g default-shell /bin/zsh


# Pastikan selalu dibaris bawah
run -b '~/.tmux/plugins/tpm/tpm'
EOL

echo -e "${GREEN}  ✅ File ~/.tmux.conf berhasil dibuat dengan konfigurasi Anda.${NC}"

# --- SELESAI ---
echo -e "\n${GREEN}✨ Instalasi Selesai! ✨${NC}"
echo "------------------------------------------------------------------"
echo -e "Langkah terakhir yang SANGAT PENTING:"
echo ""
echo -e "1. Buka tmux dengan mengetikkan: ${YELLOW}tmux${NC}"
echo ""
echo -e "2. Di dalam sesi tmux, instal plugin dengan menekan:"
echo -e "   ${YELLOW}Prefix + I${NC} (Tekan tombol \` lalu lepas, kemudian tekan I kapital)"
echo ""
echo -e "INGAT: ${YELLOW}Prefix${NC} Anda sekarang adalah tombol backtick ( \` ), bukan Ctrl+b."
echo "------------------------------------------------------------------"
