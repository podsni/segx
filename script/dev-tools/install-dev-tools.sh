#!/bin/bash

# Skrip Instalasi Cerdas untuk Development Tools (fnm, Node, pnpm, Bun)
# Versi: 1.6
# Fitur:
# - Deteksi otomatis & instalasi dependensi (curl, unzip).
# - Melewatkan instalasi jika perangkat sudah ada.
# - Konfigurasi shell otomatis (.bashrc/.zshrc).
# - Metode instalasi fnm yang lebih aman untuk menghindari error.
# - Memuat ulang shell secara otomatis di akhir untuk menerapkan perubahan.
# - Output berwarna yang informatif.

# Hentikan skrip jika terjadi kesalahan
set -e

# --- Definisi Variabel & Fungsi Bantuan ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

print_header() {
    echo -e "\n${C_BOLD}${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE} $1${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}===================================================${C_RESET}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- FUNGSI UTAMA ---

check_dependencies() {
    print_header "Langkah 0: Memeriksa Dependensi Sistem"
    DEPS=("curl" "unzip")
    
    for dep in "${DEPS[@]}"; do
        if command_exists "$dep"; then
            echo -e "${C_GREEN}âœ… Dependensi '$dep' sudah terinstal.${C_RESET}"
        else
            echo -e "${C_RED}âŒ Dependensi '$dep' tidak ditemukan.${C_RESET}"
            
            # Deteksi manajer paket dan coba instal
            local PKG_MANAGER=""
            if command_exists apt-get; then PKG_MANAGER="apt-get"; fi
            if command_exists dnf; then PKG_MANAGER="dnf"; fi
            if command_exists yum; then PKG_MANAGER="yum"; fi

            if [ -n "$PKG_MANAGER" ]; then
                echo -e "${C_YELLOW}í´§ Mencoba menginstal '$dep' via '$PKG_MANAGER'... (Mungkin memerlukan password sudo)${C_RESET}"
                if [ "$PKG_MANAGER" = "apt-get" ]; then
                    sudo apt-get update > /dev/null
                    sudo apt-get install -y "$dep"
                else
                    sudo "$PKG_MANAGER" install -y "$dep"
                fi
                echo -e "${C_GREEN}í± Dependensi '$dep' berhasil diinstal.${C_RESET}"
            else
                echo -e "${C_RED}âš ï¸ Manajer paket tidak dikenal. Harap instal '$dep' secara manual dan jalankan kembali skrip ini.${C_RESET}"
                exit 1
            fi
        fi
    done
}

install_fnm_and_node() {
    print_header "Langkah 1: Instalasi fnm, Node.js & pnpm"

    # Instal fnm jika belum ada
    if command_exists fnm; then
        echo -e "${C_GREEN}âœ… fnm sudah terinstal. Melewati instalasi.${C_RESET}"
    else
        echo -e "${C_YELLOW}íº€ Menginstal fnm (Fast Node Manager)...${C_RESET}"
        # Metode instalasi yang lebih aman: unduh lalu jalankan.
        curl -fsSL https://fnm.vercel.app/install -o fnm_install_script.sh
        sh ./fnm_install_script.sh
        rm ./fnm_install_script.sh
        echo -e "${C_GREEN}í± Instalasi fnm selesai.${C_RESET}"
    fi

    # Menyiapkan lingkungan fnm untuk sesi ini
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"

    # Instal Node.js v22 jika belum ada
    if fnm list | grep -q "v22"; then
        echo -e "${C_GREEN}âœ… Node.js v22 sudah terinstal via fnm. Melewati instalasi.${C_RESET}"
    else
        echo -e "${C_YELLOW}íº€ Menginstal Node.js v22...${C_RESET}"
        fnm install 22
    fi
    
    fnm use 22 > /dev/null
    echo -e "${C_YELLOW}í´ Verifikasi versi Node.js...${C_RESET}"
    echo -e "${C_GREEN}   -> $(node -v)${C_RESET}"

    # Aktifkan pnpm
    echo -e "${C_YELLOW}íº€ Mengaktifkan pnpm via corepack...${C_RESET}"
    corepack enable pnpm
    echo -e "${C_YELLOW}í´ Verifikasi versi pnpm...${C_RESET}"
    echo -e "${C_GREEN}   -> $(pnpm -v)${C_RESET}"
}

install_bun() {
    print_header "Langkah 2: Instalasi Bun.js"

    # Instal Bun jika belum ada
    if command_exists bun; then
        echo -e "${C_GREEN}âœ… Bun sudah terinstal. Melewati instalasi.${C_RESET}"
    else
        echo -e "${C_YELLOW}íº€ Menginstal Bun.js...${C_RESET}"
        curl -fsSL https://bun.sh/install | bash
        echo -e "${C_GREEN}í± Instalasi Bun selesai.${C_RESET}"
    fi

    # Menyiapkan lingkungan Bun untuk sesi ini
    export PATH="$HOME/.bun/bin:$PATH"
    echo -e "${C_YELLOW}í´ Verifikasi versi Bun...${C_RESET}"
    echo -e "${C_GREEN}   -> $(bun -v)${C_RESET}"
}

configure_shell() {
    print_header "Langkah 3: Konfigurasi Shell Otomatis"
    
    # Deteksi profil shell
    local SHELL_PROFILE=""
    if [ -n "$BASH_VERSION" ]; then SHELL_PROFILE="$HOME/.bashrc"; fi
    if [ -n "$ZSH_VERSION" ]; then SHELL_PROFILE="$HOME/.zshrc"; fi

    if [ -z "$SHELL_PROFILE" ]; then
        echo -e "${C_YELLOW}âš ï¸ Tidak dapat mendeteksi file profil shell (.bashrc atau .zshrc). Harap konfigurasi PATH secara manual.${C_RESET}"
        return
    fi
    
    echo -e "File profil shell terdeteksi: ${C_BOLD}${SHELL_PROFILE}${C_RESET}"

    # Tambahkan konfigurasi fnm jika belum ada
    if ! grep -q 'fnm env' "$SHELL_PROFILE"; then
        echo -e "${C_YELLOW}í´§ Menambahkan konfigurasi fnm ke ${SHELL_PROFILE}...${C_RESET}"
        echo -e '\n# Konfigurasi untuk fnm (Fast Node Manager)\nexport PATH="$HOME/.local/share/fnm:$PATH"\neval "$(fnm env)"' >> "$SHELL_PROFILE"
    else
        echo -e "${C_GREEN}âœ… Konfigurasi fnm sudah ada di ${SHELL_PROFILE}.${C_RESET}"
    fi

    # Tambahkan konfigurasi Bun jika belum ada
    if ! grep -q '.bun/bin' "$SHELL_PROFILE"; then
        echo -e "${C_YELLOW}í´§ Menambahkan konfigurasi Bun ke ${SHELL_PROFILE}...${C_RESET}"
        echo -e '\n# Konfigurasi untuk Bun.js\nexport PATH="$HOME/.bun/bin:$PATH"' >> "$SHELL_PROFILE"
    else
        echo -e "${C_GREEN}âœ… Konfigurasi Bun sudah ada di ${SHELL_PROFILE}.${C_RESET}"
    fi
}

# --- EKSEKUSI SKRIP UTAMA ---
main() {
    check_dependencies
    install_fnm_and_node
    install_bun
    configure_shell

    print_header "í¾‰ Instalasi Selesai! í¾‰"
    echo -e "${C_GREEN}Semua alat pengembangan telah berhasil diinstal dan dikonfigurasi.${C_RESET}"
    
    # --- Langkah Terakhir: Muat Ulang Shell ---
    local CURRENT_SHELL_NAME=""
    local SHELL_PROFILE=""
    if [ -n "$BASH_VERSION" ]; then 
        CURRENT_SHELL_NAME="bash"
        SHELL_PROFILE="$HOME/.bashrc"
    fi
    if [ -n "$ZSH_VERSION" ]; then 
        CURRENT_SHELL_NAME="zsh"
        SHELL_PROFILE="$HOME/.zshrc"
    fi
    
    if [ -n "$CURRENT_SHELL_NAME" ]; then
        echo -e "${C_YELLOW}í±‰ PENTING: Shell akan dimuat ulang sekarang untuk menerapkan semua perubahan.${C_RESET}"
        echo -e "${C_YELLOW}   Silakan tunggu...${C_RESET}"
        # 'exec' akan menggantikan proses skrip saat ini dengan shell baru,
        # yang akan memuat file .bashrc/.zshrc yang telah diperbarui.
        exec "$CURRENT_SHELL_NAME"
    else
        # Fallback jika shell tidak terdeteksi
        echo -e "${C_YELLOW}í±‰ PENTING: Untuk menerapkan perubahan secara permanen, silakan BUKA TERMINAL BARU,"
        echo -e "${C_YELLOW}   atau jalankan perintah berikut di terminal Anda saat ini:${C_RESET}"
        echo -e "   ${C_BOLD}source ${SHELL_PROFILE:-"$HOME/.bashrc atau $HOME/.zshrc"}${C_RESET}"
    fi
}

# Jalankan fungsi utama
main

