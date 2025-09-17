#!/usr/bin/env bash

# aktif-otp.sh — Aktif/nonaktif OTP (TOTP) untuk SSH + tampilkan QR/URI (Ubuntu/Debian)
#
# Fitur:
# - Mode OTP: off | optional | required
# - Generate OTP secret untuk user (non-interaktif)
# - Tampilkan OTP (secret + otpauth URI) dan QR di terminal (butuh qrencode)
# - Status ringkas (PAM OTP & sshd -T)
# - Mode interaktif (menu)
#
# Catatan:
# - Menggunakan skrip utama: /home/hades/vm-test/ssh-config.sh untuk penerapan kebijakan secara konsisten
# - Paket yang dibutuhkan: libpam-google-authenticator, qrencode (akan dipasang otomatis bila perlu)

set -euo pipefail

SSHCFG="/home/hades/vm-test/ssh-config.sh"
SUDO=""
if [[ $(id -u) -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
fi

log_info(){ printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
log_ok(){   printf "\033[32m[ OK ]\033[0m %s\n" "$*"; }
log_warn(){ printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
log_err(){  printf "\033[31m[ERR ]\033[0m %s\n" "$*"; }

backup_file(){
  local f="$1"
  if [[ -f "$f" ]]; then
    $SUDO cp -a "$f" "$f.$(date +%F-%H%M%S).bak"
  fi
}

ensure_pkg(){
  local pkg
  for pkg in "$@"; do
    if command -v apt-get >/dev/null 2>&1; then
      $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
      $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1 || true
    fi
  done
}

get_home(){ getent passwd "$1" | awk -F: '{print $6}'; }

ensure_user_secret(){
  # $1 = username; generates ~/.google_authenticator if missing
  local user="$1" home
  home=$(get_home "$user")
  [[ -z "$home" ]] && { log_err "User $user tidak ditemukan"; return 1; }
  if [[ ! -s "$home/.google_authenticator" ]]; then
    ensure_pkg libpam-google-authenticator
    log_info "Membuat secret OTP baru untuk $user ..."
    $SUDO -u "$user" -H google-authenticator -t -d -f -r 3 -R 30 -w 3 >/dev/null 2>&1 || true
  fi
  [[ -s "$home/.google_authenticator" ]]
}

get_secret(){
  local user="$1"
  local home; home=$(get_home "$user")
  [[ -z "$home" ]] && return 1
  [[ -s "$home/.google_authenticator" ]] || return 1
  head -n1 "$home/.google_authenticator" 2>/dev/null || true
}

print_uri(){
  local user="$1"
  ensure_user_secret "$user" || return 1
  local secret; secret=$(get_secret "$user")
  if [[ -z "$secret" ]]; then
    log_warn "Secret OTP untuk $user tidak ditemukan."
    return 1
  fi
  local host; host=$(hostname)
  local uri="otpauth://totp/${user}@${host}?secret=${secret}&issuer=${host}&digits=6&period=30"
  echo "$secret"
  echo "$uri"
}

current_code(){
  local user="$1"
  local secret; secret=$(get_secret "$user")
  if [[ -z "$secret" ]]; then
    log_warn "Secret OTP untuk $user tidak ditemukan."
    return 1
  fi
  if ! command -v oathtool >/dev/null 2>&1; then
    log_warn "oathtool tidak terpasang; mencoba memasang..."; ensure_pkg oathtool
  fi
  if command -v oathtool >/dev/null 2>&1; then
    oathtool --totp -b "$secret"
  else
    log_err "Tidak bisa menghasilkan kode TOTP (oathtool tidak tersedia)."
    return 1
  fi
}

show_qr(){
  local user="$1"
  local secret uri
  mapfile -t __arr < <(print_uri "$user") || { log_warn "Gagal mengambil secret/URI untuk $user"; return 1; }
  secret="${__arr[0]:-}"
  uri="${__arr[1]:-}"
  [[ -z "$secret" || -z "$uri" ]] && { log_warn "Secret/URI tidak ditemukan untuk $user"; return 1; }
  if command -v qrencode >/dev/null 2>&1; then
    echo
    echo "QR (scan di aplikasi Authenticator):"
    echo "$uri" | qrencode -t ANSIUTF8
    echo
  else
    log_warn "qrencode tidak terpasang; mencoba memasang..."; ensure_pkg qrencode
    if command -v qrencode >/dev/null 2>&1; then
      echo "$uri" | qrencode -t ANSIUTF8
    else
      log_warn "Gagal memasang qrencode. Menyimpan PNG ke /tmp."
      local png="/tmp/otp-${user}.png"
      if command -v base32 >/dev/null 2>&1; then :; fi
      echo "$uri" | sed 's/.*/&/;q' >"${png%.png}.uri.txt"
      log_info "Simpan URI di: ${png%.png}.uri.txt (gunakan generator QR di perangkat lain)"
    fi
  fi
  # Tampilkan kode TOTP saat ini jika memungkinkan
  local code
  code=$(current_code "$user" 2>/dev/null || true)
  if [[ -n "$code" ]]; then
    echo "Kode TOTP saat ini: $code (berlaku ~30 detik)"
  fi
}

apply_mode(){
  local mode="$1" user_gen="${2:-}"
  case "$mode" in
    off|optional|required) : ;;
    *) log_err "Mode tidak valid: $mode (gunakan: off|optional|required)"; exit 1 ;;
  esac
  if [[ -n "$user_gen" ]]; then
    $SUDO bash "$SSHCFG" --otp "$mode" --otp-user "$user_gen"
  else
    $SUDO bash "$SSHCFG" --otp "$mode"
  fi
}

status(){
  echo "Status OTP & SSH (ringkas):"
  if grep -q 'pam_google_authenticator\.so' /etc/pam.d/sshd 2>/dev/null; then
    echo "  OTP (PAM): ENABLED"
  else
    echo "  OTP (PAM): DISABLED"
  fi
  if command -v sshd >/dev/null 2>&1; then
    sshd -T 2>/dev/null | awk 'BEGIN{IGNORECASE=1} $1~/^(passwordauthentication|kbdinteractiveauthentication|authenticationmethods|port|permitrootlogin)$/ {printf "  %-28s : %s\n", toupper($1), $2}'
  fi
}

apply_mfa_profile(){ # enable described MFA profile
  # PAM: comment out @include common-auth and add pam_google_authenticator
  local pam="/etc/pam.d/sshd"
  backup_file "$pam"
  ensure_pkg libpam-google-authenticator
  if grep -qE '^@include\s+common-auth' "$pam"; then
    $SUDO sed -ri 's/^@include\s+common-auth/# @include common-auth (disabled for MFA)/' "$pam"
  fi
  if grep -q 'pam_google_authenticator\.so' "$pam"; then
    $SUDO sed -ri 's|^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_google_authenticator\.so.*|auth required pam_google_authenticator.so|' "$pam"
  else
    $SUDO sed -i '1i auth required pam_google_authenticator.so' "$pam"
  fi

  # SSHD: enforce UsePAM, ChallengeResponse, and AuthenticationMethods per spec
  local dropin="/etc/ssh/sshd_config.d/zz-vibeops-auth.conf"
  backup_file "$dropin"
  # Ensure main config disables password auth to avoid precedence issues
  if command -v bash >/dev/null 2>&1; then
    $SUDO bash "/home/hades/vm-test/ssh-config.sh" --password off >/dev/null 2>&1 || true
  fi
  $SUDO bash -lc "cat > '$dropin' <<'EOF'
# Managed by VibeOps (MFA profile)
ChallengeResponseAuthentication yes
UsePAM yes
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey,keyboard-interactive:pam
EOF"
  $SUDO systemctl restart ssh || $SUDO systemctl restart sshd || true
}

disable_mfa_profile(){
  local pam="/etc/pam.d/sshd"
  backup_file "$pam"
  # Uncomment common-auth if commented by us
  $SUDO sed -ri 's/^#\s*@include\s+common-auth/@include common-auth/' "$pam" || true
  # Remove google_authenticator line
  $SUDO sed -ri '/pam_google_authenticator\.so/d' "$pam" || true
  # Relax sshd drop-in to default optional OTP off
  local dropin="/etc/ssh/sshd_config.d/zz-vibeops-auth.conf"
  backup_file "$dropin"
  $SUDO bash -lc "cat > '$dropin' <<'EOF'
# Managed by VibeOps (MFA disabled)
ChallengeResponseAuthentication no
UsePAM yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthenticationMethods any
EOF"
  $SUDO systemctl restart ssh || $SUDO systemctl restart sshd || true
}

interactive(){
  while true; do
    clear || true
    echo "=== OTP / 2FA (TOTP) Menu ==="
    status
    echo
    echo "Pilih aksi:"
    echo "  1) OTP required (kunci + OTP wajib)"
    echo "  2) OTP optional (kunci saja ATAU kunci + OTP)"
    echo "  3) Matikan OTP"
    echo "  4) Generate OTP untuk user + tampilkan QR & kode"
    echo "  5) Tampilkan QR & kode untuk user (tanpa generate)"
    echo "  6) Tampilkan kode TOTP saat ini untuk user"
    echo "  7) Terapkan MFA profile (sesuai panduan)"
    echo "  8) Nonaktifkan MFA profile"
    echo "  9) Status"
    echo "  0) Keluar"
    echo
    read -r -p "Pilihan [0-6]: " ch || true
    case "${ch:-}" in
      1) read -r -p "User (enter lewati generate): " u || true; apply_mode required "${u:-}"; [[ -n "${u:-}" ]] && show_qr "$u"; read -r -p "Enter..." _ ;;
      2) read -r -p "User (enter lewati generate): " u || true; apply_mode optional "${u:-}"; [[ -n "${u:-}" ]] && show_qr "$u"; read -r -p "Enter..." _ ;;
      3) apply_mode off; read -r -p "Enter..." _ ;;
    4) read -r -p "User: " u || true; [[ -z "${u:-}" ]] && { echo "User kosong"; read -r -p "Enter..." _; continue; }; ensure_user_secret "$u" || true; show_qr "$u"; read -r -p "Enter..." _ ;;
      5) read -r -p "User: " u || true; [[ -z "${u:-}" ]] && { echo "User kosong"; read -r -p "Enter..." _; continue; }; show_qr "$u"; read -r -p "Enter..." _ ;;
      6) read -r -p "User: " u || true; [[ -z "${u:-}" ]] && { echo "User kosong"; read -r -p "Enter..." _; continue; }; ensure_pkg oathtool; code=$(current_code "$u" || true); [[ -n "$code" ]] && echo "Kode TOTP: $code" || echo "Gagal menghasilkan kode"; read -r -p "Enter..." _ ;;
      7) apply_mfa_profile; status; read -r -p "Enter..." _ ;;
      8) disable_mfa_profile; status; read -r -p "Enter..." _ ;;
      9) status; read -r -p "Enter..." _ ;;
      0) break ;;
      *) echo "Pilihan tidak dikenal"; sleep 0.7 ;;
    esac
  done
}

MODE=""
USER_GEN=""
SHOWQR_USER=""
SHOWURI_USER=""
DO_STATUS=0
DO_INTERACTIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --user) USER_GEN="$2"; shift 2 ;;
    --show-qr) SHOWQR_USER="$2"; shift 2 ;;
    --show-uri) SHOWURI_USER="$2"; shift 2 ;;
    --status) DO_STATUS=1; shift ;;
    --interactive) DO_INTERACTIVE=1; shift ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# //'; exit 0 ;;
    *) log_warn "Argumen tidak dikenal: $1"; shift ;;
  esac
done

if [[ $DO_INTERACTIVE -eq 1 ]]; then
  interactive; exit 0
fi

[[ -n "$MODE" ]] && apply_mode "$MODE" "${USER_GEN:-}"
[[ -n "$SHOWQR_USER" ]] && show_qr "$SHOWQR_USER"
[[ -n "$SHOWURI_USER" ]] && print_uri "$SHOWURI_USER"
[[ $DO_STATUS -eq 1 ]] && status

if [[ -z "${MODE}${SHOWQR_USER}${SHOWURI_USER}" && $DO_STATUS -eq 0 ]]; then
  log_info "Tidak ada aksi. Gunakan --interactive untuk menu."
fi


