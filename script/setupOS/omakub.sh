#!/usr/bin/env bash
#Omakub is only tested on fresh installations of Ubuntu 24.04 and 25.04. If you already have an installation, use a different version, or even a different distribution, you'll be on your own.)
set -euo pipefail

URL="https://omakub.org/install"

# Simpan sementara file sebelum eval (supaya bisa diperiksa kalau mau)
TMP_FILE=$(mktemp)
wget -qO- "$TMP_FILE" "$URL"

echo "[INFO] Script berhasil diunduh ke $TMP_FILE"
echo "[INFO] Menjalankan script..."

# Jalankan script
eval "$(cat "$TMP_FILE")"

# Hapus file sementara
rm -f "$TMP_FILE"

