#!/bin/bash

# =======================================
# SETUP SSH untuk GitHub.com langsung
# Menggunakan kunci ~/.ssh/bitwarden_localan
# =======================================

SSH_KEY="$HOME/.ssh/bitwarden_localan"
GITHUB_HOST="github.com"
GITHUB_USER="localan"
GITHUB_EMAIL="localso@proton.me"
SSH_CONFIG_FILE="$HOME/.ssh/config"

echo "==========[ SETUP SSH GITHUB.COM ]=========="
echo "SSH Key     : $SSH_KEY"
echo "GitHub Host : $GITHUB_HOST"
echo "============================================"

# 1. Tambahkan konfigurasi ke ~/.ssh/config
if [ ! -f "$SSH_CONFIG_FILE" ]; then
  touch "$SSH_CONFIG_FILE"
  chmod 600 "$SSH_CONFIG_FILE"
fi

if ! grep -q "Host $GITHUB_HOST" "$SSH_CONFIG_FILE"; then
  echo "[*] Menambahkan konfigurasi SSH ke github.com..."
  cat <<EOF >> "$SSH_CONFIG_FILE"

# Gunakan kunci bitwarden_localan untuk github.com
Host $GITHUB_HOST
  HostName github.com
  User git
  IdentityFile $SSH_KEY
  IdentitiesOnly yes
EOF
else
  echo "[=] Konfigurasi untuk github.com sudah ada, dilewati."
fi

# 2. Pastikan permission key benar
chmod 600 "$SSH_KEY"

# 3. Uji koneksi SSH ke github.com langsung
echo ""
echo "[*] Menguji koneksi SSH ke GitHub..."
echo "    ssh -T git@github.com"
echo "----------------------------------------"
ssh -T git@github.com
echo "----------------------------------------"

# 4. Set Git global config
echo ""
echo "[*] Mengatur Git global user/email..."
git config --global user.name "$GITHUB_USER"
git config --global user.email "$GITHUB_EMAIL"

# 5. Tampilkan Git config
echo "[*] Git global config saat ini:"
git config --global --list

# 6. Contoh clone command
echo ""
echo " Setup selesai!"
echo " Gunakan ini untuk clone repo:"
echo "    git clone git@github.com:$GITHUB_USER/<repo>.git"

