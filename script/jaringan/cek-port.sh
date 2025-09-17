#!/bin/bash

# ==============================================
# Cek apakah port sedang digunakan & oleh siapa
# Support: TCP/UDP | Output proses lengkap
# ==============================================

PORT=$1
PROTOCOL=${2:-tcp} # default tcp

# Fungsi untuk menampilkan bantuan
show_help() {
  echo "Penggunaan: $0 <port> [protocol]"
  echo "Contoh: $0 8080"
  echo "        $0 53 udp"
  exit 1
}

# Validasi input
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "❌ Port harus berupa angka."
  show_help
fi

if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
  echo "❌ Protocol hanya boleh 'tcp' atau 'udp'."
  show_help
fi

echo " Mengecek port $PORT ($PROTOCOL)..."
found=0

# Cek menggunakan ss (lebih modern)
if command -v ss >/dev/null; then
  OUTPUT=$(ss -lpun | grep -w ":$PORT ")
  if [[ -n "$OUTPUT" ]]; then
    echo " Port $PORT sedang digunakan:"
    echo "$OUTPUT" | awk '{print "  ➤ " $0}'
    found=1
  fi
fi

# Jika belum ketemu, cek dengan lsof
if [[ $found -eq 0 && $(command -v lsof) ]]; then
  OUTPUT=$(lsof -nP -i$PROTOCOL:$PORT 2>/dev/null)
  if [[ -n "$OUTPUT" ]]; then
    echo " Port $PORT sedang digunakan:"
    echo "$OUTPUT" | awk 'NR==1{print "  ➤ " $0} NR>1{print "  • PID: "$2", USER: "$3", COMMAND: "$1}'
    found=1
  fi
fi

# Jika belum ketemu, cek dengan netstat (opsional legacy)
if [[ $found -eq 0 && $(command -v netstat) ]]; then
  OUTPUT=$(netstat -tunlp 2>/dev/null | grep -w ":$PORT")
  if [[ -n "$OUTPUT" ]]; then
    echo " Port $PORT sedang digunakan:"
    echo "$OUTPUT" | awk '{print "  ➤ " $0}'
    found=1
  fi
fi

if [[ $found -eq 0 ]]; then
  echo "✅ Port $PORT tersedia & tidak sedang digunakan."
fi