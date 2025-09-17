#!/bin/bash

echo "=== 🔐 Keyfile & Password Generator Interaktif ==="

# === Pilihan utama ===
echo "Pilih opsi:"
echo "1) Buat Keyfile"
echo "2) Buat Password"
echo "3) Keduanya"
read -rp "Masukkan pilihan [1/2/3]: " mode

# ======== 🔑 Fungsi: Generate Keyfile ========
generate_keyfile() {
  echo ""
  echo "=== 🛠️ Membuat Keyfile ==="
  read -rp "📁 Lokasi folder keyfile (default: ~/.vault-keys): " input_folder
  KEYDIR="${input_folder:-$HOME/.vault-keys}"

  read -rp "📄 Nama file keyfile (default: argon.key): " input_name
  KEYNAME="${input_name:-argon.key}"

  read -rp "🔢 Ukuran keyfile dalam byte (default: 64): " input_size
  KEYSIZE="${input_size:-64}"

  KEYFILE="$KEYDIR/$KEYNAME"
  echo ""
  echo "📌 Keyfile akan dibuat di: $KEYFILE"
  echo "📦 Ukuran: $KEYSIZE byte"
  read -rp "Lanjutkan? (y/n): " confirm
  [[ "$confirm" != "y" ]] && echo "❌ Dibatalkan." && return

  mkdir -p "$KEYDIR"

  if [[ -f "$KEYFILE" ]]; then
    read -rp "⚠️ File sudah ada. Overwrite? (y/n): " overwrite
    [[ "$overwrite" != "y" ]] && echo "❌ Tidak jadi menimpa file yang ada." && return
  fi

  openssl rand -out "$KEYFILE" "$KEYSIZE"
  chmod 600 "$KEYFILE"
  echo "✅ Keyfile berhasil dibuat!"
  ls -lh "$KEYFILE"
}

# ======== 🔐 Fungsi: Generate Password ========
generate_password() {
  echo ""
  echo "=== 🛠️ Membuat Password ==="
  read -rp "🔢 Panjang password (default: 32): " pass_len
  pass_len="${pass_len:-32}"

  read -rp "Gunakan simbol? (y/n, default: y): " use_symbols
  use_symbols="${use_symbols:-y}"

  if [[ "$use_symbols" == "y" ]]; then
    charset='A-Za-z0-9!@#$%^&*()_+'
  else
    charset='A-Za-z0-9'
  fi

  PASSWORD=$(< /dev/urandom tr -dc "$charset" | head -c"$pass_len")

  echo ""
  echo "🔐 Password kamu:"
  echo "$PASSWORD"
  echo ""

  read -rp "Simpan ke file? (y/n): " save_pw
  if [[ "$save_pw" == "y" ]]; then
    read -rp "📄 Nama file (default: password.txt): " pwfile
    pwfile="${pwfile:-password.txt}"
    echo "$PASSWORD" > "$pwfile"
    chmod 600 "$pwfile"
    echo "✅ Disimpan ke $pwfile"
  fi
}

# ======== Jalankan Sesuai Pilihan ========
case "$mode" in
  1)
    generate_keyfile
    ;;
  2)
    generate_password
    ;;
  3)
    generate_keyfile
    generate_password
    ;;
  *)
    echo "❌ Pilihan tidak valid."
    ;;
esac
