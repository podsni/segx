#!/usr/bin/env bash

# vps-securty.sh — Menu interaktif untuk audit & hardening VPS (Ubuntu/Debian)
#
# Fitur:
# - Audit keamanan (read-only)
# - Cek kapabilitas VPS (CPU, disk, network)
# - Baseline hardening (unattended-upgrades, UFW, SSH hardening, fail2ban, sysctl)
# - Konfigurasi SSH/OTP (wizard interaktif)
# - Toggle password login (on/off)
# - Manajemen UFW: buka port, lihat status
# - Status Fail2ban
# - Ringkasan konfigurasi SSH efektif
#
# Catatan: Aksi yang mengubah sistem membutuhkan sudo. Semua perintah idempotent.

set -euo pipefail

BASE="/home/hades/vm-test"
AUDIT_SCRIPT="$BASE/vps-sec-check.sh"
CHECK_SCRIPT="$BASE/vps-check.sh"
HARDEN_SCRIPT="$BASE/harden-server.sh"
SSHCFG_SCRIPT="$BASE/ssh-config.sh"
AKTIF_OTP_SCRIPT="$BASE/aktif-otp.sh"

COLOR=1
if [[ -t 1 ]]; then :; else COLOR=0; fi
if [[ ${NO_COLOR:-0} -eq 1 ]]; then COLOR=0; fi
if [[ $COLOR -eq 1 ]]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; NC="\033[0m"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; NC=""
fi

SUDO=""
if [[ $(id -u) -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
fi

header() {
  clear || true
  echo -e "${BOLD}${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}${CYAN}│${NC}           ${BOLD}VPS Security Menu — VibeOps${NC}                 ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"
  echo -e "${DIM}OS: $(. /etc/os-release 2>/dev/null; echo ${PRETTY_NAME:-unknown})  Kernel: $(uname -r)  Host: $(hostname)${NC}"
  echo
}

ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR ]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

pause() { echo; read -r -p "Tekan Enter untuk kembali ke menu..." _ || true; }

need_file() {
  local f="$1" label="$2"
  [[ -x "$f" || -f "$f" ]] || { err "$label tidak ditemukan: $f"; return 1; }
}

run_audit() {
  header
  info "Menjalankan audit keamanan (read-only)..."
  need_file "$AUDIT_SCRIPT" "Audit script" || { pause; return; }
  bash "$AUDIT_SCRIPT" --all --no-color | sed 's/^/  /'
  pause
}

run_vps_check() {
  header
  info "Menjalankan cek kapabilitas VPS..."
  need_file "$CHECK_SCRIPT" "VPS check script" || { pause; return; }
  bash "$CHECK_SCRIPT" --all --no-color | sed 's/^/  /'
  pause
}

run_hardening() {
  header
  info "Baseline hardening akan mengaktifkan: unattended-upgrades, UFW, SSH hardening, fail2ban, sysctl"
  read -r -p "Lanjutkan? (Y/n): " ans || true; ans=${ans:-Y}
  [[ "$ans" =~ ^[Yy]$ ]] || { warn "Dibatalkan."; pause; return; }
  need_file "$HARDEN_SCRIPT" "Hardening script" || { pause; return; }
  $SUDO bash "$HARDEN_SCRIPT" | sed 's/^/  /'
  pause
}

run_ssh_wizard() {
  header
  info "Membuka wizard konfigurasi SSH/OTP..."
  need_file "$SSHCFG_SCRIPT" "SSH config script" || { pause; return; }
  $SUDO bash "$SSHCFG_SCRIPT" --interactive
  pause
}

toggle_password() {
  header
  echo "Mode password login:"
  echo "  1) Matikan password (disarankan)"
  echo "  2) Aktifkan password (darurat)"
  echo
  read -r -p "Pilih [1-2]: " c || true
  case "$c" in
    1)
      need_file "$SSHCFG_SCRIPT" "SSH config script" || { pause; return; }
      $SUDO bash "$SSHCFG_SCRIPT" --otp optional --password off | sed 's/^/  /'
      ;;
    2)
      need_file "$SSHCFG_SCRIPT" "SSH config script" || { pause; return; }
      $SUDO bash "$SSHCFG_SCRIPT" --otp off --password on | sed 's/^/  /'
      warn "PERINGATAN: Password login aktif. Pertimbangkan OTP required untuk keamanan ekstra."
      ;;
    *) warn "Tidak ada perubahan." ;;
  esac
  pause
}

open_ufw_port() {
  header
  info "Buka port di UFW (contoh: 5432/tcp atau 8080)"
  read -r -p "Masukkan port (format: 80 atau 8080/tcp): " p || true
  [[ -z "${p:-}" ]] && { warn "Tidak ada input."; pause; return; }
  $SUDO ufw allow "$p" && ok "UFW: allow $p" || err "Gagal menambah aturan UFW"
  pause
}

show_ufw_status() {
  header
  info "Status UFW:"
  $SUDO ufw status verbose | sed 's/^/  /' || true
  pause
}

show_fail2ban_status() {
  header
  info "Status Fail2ban:"
  if command -v fail2ban-client >/dev/null 2>&1; then
    $SUDO fail2ban-client status | sed 's/^/  /'
    echo
    $SUDO fail2ban-client status sshd 2>/dev/null | sed 's/^/  /' || true
  else
    warn "fail2ban tidak terpasang. Jalankan hardening untuk memasang."
  fi
  pause
}

show_sshd_summary() {
  header
  info "Ringkasan konfigurasi SSH efektif:"
  if command -v sshd >/dev/null 2>&1; then
    sshd -T 2>/dev/null | awk 'BEGIN{IGNORECASE=1} $1~/^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|x11forwarding|kbdinteractiveauthentication|authenticationmethods)$/ {printf "  %-30s : %s\n", toupper($1), $2}'
    if grep -q 'pam_google_authenticator\.so' /etc/pam.d/sshd 2>/dev/null; then
      echo "  OTP (PAM)                     : ENABLED"
    else
      echo "  OTP (PAM)                     : DISABLED"
    fi
  else
    warn "sshd tidak ditemukan."
  fi
  pause
}

otp_menu() {
  header
  info "Membuka OTP/2FA manager (QR + setup) ..."
  need_file "$AKTIF_OTP_SCRIPT" "OTP manager" || { pause; return; }
  $SUDO bash "$AKTIF_OTP_SCRIPT" --interactive
}

main_menu() {
  while true; do
    header
    echo -e "${BOLD}Pilih aksi:${NC}"
    echo "  1) Audit keamanan (read-only)"
    echo "  2) Cek VPS (CPU/Disk/Net)"
    echo "  3) Baseline hardening (otomatis)"
    echo "  4) Konfigurasi SSH/OTP (wizard)"
    echo "  5) Toggle password login (on/off)"
    echo "  6) UFW: buka port"
    echo "  7) UFW: status"
    echo "  8) Fail2ban: status"
    echo "  9) SSH: ringkasan konfigurasi"
    echo " 10) SSH: OTP/2FA (menu)"
    echo "  0) Keluar"
    echo
    read -r -p "Pilihan [0-9]: " choice || true
    case "${choice:-}" in
      1) run_audit ;;
      2) run_vps_check ;;
      3) run_hardening ;;
      4) run_ssh_wizard ;;
      5) toggle_password ;;
      6) open_ufw_port ;;
      7) show_ufw_status ;;
      8) show_fail2ban_status ;;
      9) show_sshd_summary ;;
      10) otp_menu ;;
      0) echo; ok "Selesai."; exit 0 ;;
      *) warn "Pilihan tidak dikenal."; sleep 0.8 ;;
    esac
  done
}

main_menu


