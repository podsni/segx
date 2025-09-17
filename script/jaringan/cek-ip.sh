#!/bin/bash

set -euo pipefail

# Warna
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'

print_header() {
  printf "${C_BOLD}${C_BLUE}===== Cek IP Sekarang =====${C_RESET}\n"
}

trim() { sed -e 's/^\s\+//' -e 's/\s\+$//'; }

get_public_ip() {
  # Urutan layanan (IPv4). Gunakan timeout kecil agar cepat fallback
  local endpoints=(
    "https://api.ipify.org"
    "https://ipv4.icanhazip.com"
    "https://ifconfig.me/ip"
  )

  if command -v curl >/dev/null 2>&1; then
    for url in "${endpoints[@]}"; do
      if ip=$(curl -4 -fsS --max-time 4 "$url" 2>/dev/null | tr -d '\r' | trim); then
        if [[ -n "$ip" ]]; then echo "$ip"; return 0; fi
      fi
    done
  fi

  # Fallback ke dig (OpenDNS) jika curl gagal/tdk ada
  if command -v dig >/dev/null 2>&1; then
    if ip=$(dig +short -4 myip.opendns.com @resolver1.opendns.com 2>/dev/null | head -n1 | trim); then
      if [[ -n "$ip" ]]; then echo "$ip"; return 0; fi
    fi
  fi

  echo "" # kosong jika gagal
  return 1
}

get_primary_local_ip() {
  # Ambil IP sumber default route
  if command -v ip >/dev/null 2>&1; then
    local line
    if line=$(ip -4 route get 1.1.1.1 2>/dev/null | head -n1); then
      # contoh: "1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.10 uid 1000"
      local src ip_iface
      src=$(awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}' <<<"$line")
      ip_iface=$(awk '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}' <<<"$line")
      if [[ -n "$src" ]]; then
        printf "%s|%s\n" "$src" "${ip_iface:-?}"
        return 0
      fi
    fi
  fi
  echo "|" # kosong jika gagal
  return 1
}

list_all_local_ipv4() {
  if command -v ip >/dev/null 2>&1; then
    ip -o -4 addr show 2>/dev/null | awk '{print $2, $4}' | sed 's/\/[0-9]\+$//' || true
  else
    hostname -I 2>/dev/null | tr ' ' '\n' || true
  fi
}

main() {
  print_header

  # IP publik
  local pub_ip
  if pub_ip=$(get_public_ip); then
    if [[ -n "$pub_ip" ]]; then
      printf "${C_BOLD}IP Publik:${C_RESET} ${C_GREEN}%s${C_RESET}\n" "$pub_ip"
    else
      printf "${C_BOLD}IP Publik:${C_RESET} ${C_YELLOW}Tidak terdeteksi${C_RESET}\n"
    fi
  else
    printf "${C_BOLD}IP Publik:${C_RESET} ${C_YELLOW}Tidak terdeteksi${C_RESET}\n"
  fi

  # IP lokal utama (default route)
  local primary local_iface pair
  pair=$(get_primary_local_ip || true)
  primary="${pair%%|*}"
  local_iface="${pair#*|}"
  if [[ -n "$primary" ]]; then
    if [[ -n "$local_iface" && "$local_iface" != "$primary" ]]; then
      printf "${C_BOLD}IP Lokal Utama:${C_RESET} ${C_GREEN}%s${C_RESET} (iface: %s)\n" "$primary" "$local_iface"
    else
      printf "${C_BOLD}IP Lokal Utama:${C_RESET} ${C_GREEN}%s${C_RESET}\n" "$primary"
    fi
  else
    printf "${C_BOLD}IP Lokal Utama:${C_RESET} ${C_YELLOW}Tidak terdeteksi${C_RESET}\n"
  fi

  # Daftar semua IPv4 lokal
  printf "${C_BOLD}Daftar IP Lokal:${C_RESET}\n"
  if list=$(list_all_local_ipv4); then
    if [[ -n "$list" ]]; then
      while IFS= read -r row; do
        [[ -z "$row" ]] && continue
        # row bisa berupa: "eth0 192.168.1.10" atau hanya IP
        printf "  - %s\n" "$row"
      done <<<"$list"
    else
      printf "  ${C_YELLOW}(kosong)${C_RESET}\n"
    fi
  else
    printf "  ${C_YELLOW}(gagal membaca antarmuka)${C_RESET}\n"
  fi
}

main "$@"


