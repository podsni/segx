#!/bin/bash

# ---------------------------
# Konfigurasi pengguna
# ---------------------------
SSH_KEY="$HOME/.ssh/bitwarden_localan"
SSH_ALIAS="github-localan"
GITHUB_USER="localan"
GITHUB_EMAIL="localso@proton.me"
SSH_CONFIG_FILE="$HOME/.ssh/config"

echo "==========[ SETUP GITHUB SSH ]=========="
echo "Akun GitHub : $GITHUB_USER"
echo "SSH Key     : $SSH_KEY"
echo "Alias Host  : $SSH_ALIAS"
echo "========================================"

# 1. Tambah SSH config jika belum ada
if [ ! -f "$SSH_CONFIG_FILE" ]; then
  touch "$SSH_CONFIG_FILE"
  chmod 600 "$SSH_CONFIG_FILE"
fi

if ! grep -q "$SSH_ALIAS" "$SSH_CONFIG_FILE"; then
  echo "[*] Menambahkan alias SSH ke $SSH_CONFIG_FILE..."
  cat <<EOF >> "$SSH_CONFIG_FILE"

# GitHub SSH config for $GITHUB_USER
Host $SSH_ALIAS
  HostName github.com
  User git
  IdentityFile $SSH_KEY
  IdentitiesOnly yes
EOF
else
  echo "[=] SSH config '$SSH_ALIAS' sudah ada, dilewati."
fi

# 2. Perbaiki permission key
chmod 600 "$SSH_KEY"

# 3. Cek koneksi SSH (langsung tampilkan hasil)
echo ""
echo "[*] Menguji koneksi SSH ke GitHub..."
echo "    ssh -T $SSH_ALIAS"
echo "----------------------------------------"
ssh -T $SSH_ALIAS
echo "----------------------------------------"

# 4. Konfigurasi Git global
echo ""
echo "[*] Mengatur Git global user & email..."
git config --global user.name "$GITHUB_USER"
git config --global user.email "$GITHUB_EMAIL"

# 5. Tampilkan hasil konfigurasi Git
echo "[*] Konfigurasi Git saat ini:"
git config --global --list

echo ""
echo "í¾‰ Setup selesai!"
echo "í±‰ Gunakan ini untuk clone repo:"
echo "    git clone git@$SSH_ALIAS:$GITHUB_USER/<repo>.git"

