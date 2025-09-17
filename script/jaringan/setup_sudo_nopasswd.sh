#!/bin/bash

# Cek apakah dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Script ini harus dijalankan sebagai root."
    exit 1
fi

# Deteksi user aktif (non-root)
active_user=$(logname 2>/dev/null || echo $SUDO_USER)
default_user=${active_user:-$(whoami)}

echo "🧑  User terdeteksi: $default_user"
read -p "Masukkan username yang ingin diberikan akses sudo tanpa password [$default_user]: " input_user
username=${input_user:-$default_user}

# Cek apakah user valid
if ! id "$username" &>/dev/null; then
    echo "❌ User '$username' tidak ditemukan!"
    exit 2
fi

# Lokasi file sudoers
sudoers_file="/etc/sudoers.d/$username"

# Konfirmasi
echo ""
echo "⚠️  Ini akan memberikan akses sudo penuh tanpa password ke user '$username'"
read -p "Lanjutkan? [y/N]: " confirm
confirm=${confirm,,} # lowercase

if [[ "$confirm" != "y" ]]; then
    echo "❌ Operasi dibatalkan."
    exit 3
fi

# Tulis file sudoers
echo "$username ALL=(ALL) NOPASSWD:ALL" > "$sudoers_file"

# Set permission sesuai standar sudoers
chmod 0440 "$sudoers_file"

# Validasi file sudoers
if visudo -cf "$sudoers_file"; then
    echo "✅ Sukses: User '$username' sekarang bisa menggunakan sudo tanpa password."
    echo "🔍 Gunakan 'sudo -l -U $username' untuk memverifikasi."
else
    echo "❌ Gagal validasi sudoers. Menghapus file."
    rm -f "$sudoers_file"
    exit 4
fi
