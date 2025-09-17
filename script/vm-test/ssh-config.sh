#!/usr/bin/env bash

# ssh-config.sh — SSH hardening, nonaktif password login, dan opsional OTP (aman & idempotent)
#
# Fitur:
# - Backup otomatis sshd_config dengan timestamp
# - Set: PermitRootLogin no, PubkeyAuthentication yes, PasswordAuthentication no, MaxAuthTries 4, X11Forwarding no
# - Opsi set port SSH
# - Tambah public key ke user tertentu dengan permission yang benar
# - Validasi konfigurasi (sshd -t) lalu restart service (ssh/sshd)
# - Opsional update UFW untuk port SSH yang dipilih
# - Mode interaktif: bantu input port, kunci publik, dan OTP (TOTP) opsional
# - Ringkasan konfigurasi efektif sshd dan daftar kunci yang terdeteksi
# - Validasi format public key, dukungan input dari file, dan mode dry-run
#
# Penggunaan:
#   sudo bash /home/hades/vm-test/ssh-config.sh --force --port 22
#   sudo bash /home/hades/vm-test/ssh-config.sh --user hades --pubkey "ssh-ed25519 AAAA..."
#   sudo bash /home/hades/vm-test/ssh-config.sh --user hades --pubkey "ssh-ed25519 AAAA..." --port 2222 --allow-ufw
#   sudo bash /home/hades/vm-test/ssh-config.sh --otp optional|required
#   sudo bash /home/hades/vm-test/ssh-config.sh --interactive
#   sudo bash /home/hades/vm-test/ssh-config.sh --summary
#   sudo bash /home/hades/vm-test/ssh-config.sh --dry-run --user hades --pubkey-file /path/key.pub --port 2222 --otp optional
#
# Catatan:
# - Default: skrip HANYA menonaktifkan password bila minimal satu authorized_keys ditemukan.
# - Gunakan --force untuk memaksa nonaktif password meski belum ada authorized_keys (BERISIKO LOCKOUT!).

set -euo pipefail

log_info() { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
log_ok()   { printf "\033[32m[ OK ]\033[0m %s\n" "$*"; }
log_warn() { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
log_err()  { printf "\033[31m[ERR ]\033[0m %s\n" "$*"; }

SUDO=""
require_root_or_sudo() {
  if [[ $(id -u) -eq 0 ]]; then
    SUDO=""
  else
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    else
      log_err "Butuh hak root/sudo. Jalankan sebagai root atau install sudo."
      exit 1
    fi
  fi
}

print_keys_from_file() {
  local file="$1" label="$2"
  [[ -s "$file" ]] || return 0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local type b64 comment prefix
    type=$(echo "$line" | awk '{print $1}')
    b64=$(echo "$line" | awk '{print $2}')
    comment=$(echo "$line" | cut -d' ' -f3-)
    prefix=$(echo "$b64" | cut -c1-16)
    echo "  - ${label}: [$type] ${comment:-no-comment} (${prefix}...)"
  done < "$file"
}

print_existing_keys() {
  echo "Kunci SSH yang terdeteksi (authorized_keys*):"
  local listed=0
  # Cari semua file authorized_keys* non-kosong di /home/*/.ssh dan /root/.ssh
  while IFS= read -r f; do
    # Tentukan label user dari path
    local user label
    case "$f" in
      /root/*) label="root" ;;
      /home/*) user=$(echo "$f" | awk -F/ '{print $3}'); label="$user" ;;
      *) label="unknown" ;;
    esac
    print_keys_from_file "$f" "$label"
    listed=1
  done < <(find /home /root -maxdepth 3 -type f -name 'authorized_keys*' -size +0c 2>/dev/null)
  [[ $listed -eq 0 ]] && echo "  (tidak ditemukan)"
}

ensure_pkg() {
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$1" >/dev/null 2>&1 || true
  fi
}

prompt() { # $1=message $2=default
  local msg="$1" def="${2:-}"
  if [[ -n "$def" ]]; then
    read -r -p "$msg [$def]: " ans || true
    echo "${ans:-$def}"
  else
    read -r -p "$msg: " ans || true
    echo "$ans"
  fi
}

confirm() { # returns 0 if yes
  local msg="$1"; local def="${2:-y}"
  local prompt_char="y/N"; [[ "$def" == "y" ]] && prompt_char="Y/n"
  read -r -p "$msg ($prompt_char): " ans || true
  ans=${ans:-$def}
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local bak="${f}.$(date +%F-%H%M%S).bak"
    $SUDO cp -a "$f" "$bak"
    log_ok "Backup: $bak"
  fi
}

have_any_authorized_keys() {
  local any
  any=$(find /home /root -maxdepth 3 -type f -name 'authorized_keys*' -size +0c 2>/dev/null | head -n1 || true)
  if [[ -n "$any" ]]; then echo 1; else echo 0; fi
}

add_pubkey() {
  local user="$1"; shift
  local pubkey="$1"
  if ! is_valid_pubkey "$pubkey"; then
    log_err "Public key tidak valid. Harus diawali ssh-ed25519/ssh-rsa/ecdsa-sha2-* dan berisi data base64."
    exit 1
  fi
  local home
  home=$(getent passwd "$user" | awk -F: '{print $6}')
  if [[ -z "$home" || ! -d "$home" ]]; then
    log_err "Home untuk user '$user' tidak ditemukan"; exit 1
  fi
  $SUDO mkdir -p "$home/.ssh"
  $SUDO sh -c "umask 077 && touch '$home/.ssh/authorized_keys'"
  if $SUDO grep -qxF "$pubkey" "$home/.ssh/authorized_keys" 2>/dev/null; then
    log_info "Public key sudah ada untuk $user"
  else
    echo "$pubkey" | $SUDO tee -a "$home/.ssh/authorized_keys" >/dev/null
    log_ok "Public key ditambahkan ke $user"
  fi
  $SUDO chown -R "$user":"$user" "$home/.ssh"
  $SUDO chmod 700 "$home/.ssh"
  $SUDO chmod 600 "$home/.ssh/authorized_keys"
}

set_sshd_option() {
  local key="$1"; shift
  local value="$1"; shift
  local cfg="/etc/ssh/sshd_config"
  if $SUDO grep -qE "^#?${key}([[:space:]]+|=)" "$cfg"; then
    $SUDO sed -ri "s~^#?${key}([[:space:]]+|=).*~${key} ${value}~" "$cfg"
  else
    printf "\n%s %s\n" "$key" "$value" | $SUDO tee -a "$cfg" >/dev/null
  fi
}

restart_ssh_service() {
  if $SUDO sshd -t 2>/dev/null; then
    $SUDO systemctl restart sshd 2>/dev/null || $SUDO systemctl restart ssh 2>/dev/null || true
    log_ok "SSH service direstart"
  else
    log_err "Konfigurasi SSH invalid (sshd -t gagal). Lihat backup lalu perbaiki."
    exit 1
  fi
}

allow_ufw_port() {
  local port="$1"
  if command -v ufw >/dev/null 2>&1; then
    $SUDO ufw allow "$port"/tcp >/dev/null 2>&1 || true
    log_ok "UFW diizinkan untuk port $port/tcp"
  fi
}

limit_ufw_ssh() {
  if command -v ufw >/dev/null 2>&1; then
    $SUDO ufw limit OpenSSH >/dev/null 2>&1 || true
    log_ok "UFW rate-limit untuk OpenSSH diaktifkan"
  fi
}

is_valid_pubkey() {
  local key="$1"
  [[ "$key" =~ ^(ssh\-ed25519|ssh\-rsa|ecdsa\-sha2\-nistp(256|384|521))\s+[A-Za-z0-9\+/=]+(\s+.*)?$ ]]
}

read_pubkey_from_file() {
  local path="$1"
  if [[ ! -r "$path" ]]; then
    log_err "File tidak dapat dibaca: $path"; exit 1
  fi
  awk 'NF {print; exit}' "$path"
}

print_effective_summary() {
  echo "Ringkasan konfigurasi sshd (efektif):"
  if command -v sshd >/dev/null 2>&1; then
    sshd -T 2>/dev/null | awk 'BEGIN{IGNORECASE=1} $1~/^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|x11forwarding|kbdinteractiveauthentication|authenticationmethods)$/ {print "  " toupper($1) ": " $2}'
  else
    echo "  (sshd tidak ditemukan di PATH)"
  fi
}

configure_otp() { # $1 mode: off|optional|required, $2 user (optional)
  local mode="$1"; local user_for_otp="${2:-}"
  local pam_sshd="/etc/pam.d/sshd"
  case "$mode" in
    off)
      # Hapus baris pam_google_authenticator jika ada
      if [[ -f "$pam_sshd" ]]; then
        backup_file "$pam_sshd"
        $SUDO sed -i '/pam_google_authenticator\.so/d' "$pam_sshd"
      fi
      # Nonaktifkan KbdInteractive jika tidak diperlukan oleh hal lain
      set_sshd_option KbdInteractiveAuthentication no
      # Hapus AuthenticationMethods jika kita yang set sebelumnya
      if $SUDO grep -qE '^AuthenticationMethods ' /etc/ssh/sshd_config 2>/dev/null; then
        $SUDO sed -ri 's/^AuthenticationMethods .*/# AuthenticationMethods cleared/' /etc/ssh/sshd_config || true
      fi
      log_ok "OTP dimatikan"
      return 0
      ;;
    optional|required)
      ensure_pkg libpam-google-authenticator
      backup_file "$pam_sshd"
      local pam_line="auth required pam_google_authenticator.so"
      [[ "$mode" == "optional" ]] && pam_line="${pam_line} nullok"
      if $SUDO grep -q 'pam_google_authenticator.so' "$pam_sshd" 2>/dev/null; then
        $SUDO sed -ri "s|^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_google_authenticator\.so.*|${pam_line}|" "$pam_sshd" || true
      else
        # sisipkan di baris pertama
        $SUDO sed -i "1i ${pam_line}" "$pam_sshd"
      fi
      set_sshd_option UsePAM yes
      set_sshd_option KbdInteractiveAuthentication yes
      if [[ "$mode" == "required" ]]; then
        # Wajibkan 2FA: butuh publickey + OTP via PAM
        set_sshd_option AuthenticationMethods "publickey,keyboard-interactive:pam"
      else
        # Optional: izinkan publickey saja ATAU publickey + OTP (tanpa password)
        set_sshd_option AuthenticationMethods "publickey publickey,keyboard-interactive:pam"
      fi

      # Buat secret OTP untuk user bila diminta
      if [[ -n "$user_for_otp" ]]; then
        if getent passwd "$user_for_otp" >/dev/null; then
          log_info "Membuat konfigurasi TOTP untuk user $user_for_otp ..."
          ensure_pkg libpam-google-authenticator
          # Non-interaktif: time-based, disallow multiple-use, rate limit 3/30s, window 3, non-confirm
          $SUDO -u "$user_for_otp" -H google-authenticator -t -d -f -r 3 -R 30 -w 3 >/dev/null 2>&1 || true
          local home
          home=$(getent passwd "$user_for_otp" | awk -F: '{print $6}')
          if [[ -s "$home/.google_authenticator" ]]; then
            local secret uri
            secret=$(head -n1 "$home/.google_authenticator" 2>/dev/null || true)
            # Buat otpauth:// URI (tanpa issuer untuk kesederhanaan); user isi host
            uri="otpauth://totp/${user_for_otp}@$(hostname)?secret=${secret}&digits=6&period=30"
            log_ok "OTP secret untuk $user_for_otp: $secret"
            echo "$uri" | sed 's/^/[OTP-URI] /'
          else
            log_warn "Tidak dapat membuat file ~/.google_authenticator untuk $user_for_otp."
          fi
        else
          log_warn "User $user_for_otp tidak ditemukan, lewati pembuatan OTP."
        fi
      fi
      log_ok "OTP ${mode} dikonfigurasi"
      ;;
    *) log_err "Mode OTP tidak dikenal: $mode"; exit 1 ;;
  esac
}

# Ensure a deterministic drop-in that enforces auth policy early in Include order
write_sshd_dropin() {
  # Args: $1=otp_mode(off|optional|required) $2=password_mode(on|off|"")
  local otp_mode="$1"; local pw_mode="${2:-}"
  # Use a highest precedence drop-in to override others
  local dropin="/etc/ssh/sshd_config.d/zz-vibeops-auth.conf"
  backup_file "$dropin"
  local pwline="PasswordAuthentication no"
  local kbd="KbdInteractiveAuthentication no"
  local authm=""
  case "$otp_mode" in
    required)
      kbd="KbdInteractiveAuthentication yes"
      authm='AuthenticationMethods publickey,keyboard-interactive:pam'
      ;;
    optional)
      kbd="KbdInteractiveAuthentication yes"
      authm='AuthenticationMethods publickey publickey,keyboard-interactive:pam'
      ;;
    off)
      : ;;
  esac
  if [[ "$pw_mode" == "on" ]]; then
    pwline="PasswordAuthentication yes"
    # Allow passwords; do not force AuthenticationMethods combos
    authm=""
    # If OTP is off, keep keyboard-interactive off; otherwise leave as set
    [[ "$otp_mode" == "off" ]] && kbd="KbdInteractiveAuthentication no"
  elif [[ "$pw_mode" == "off" ]]; then
    pwline="PasswordAuthentication no"
  fi
  $SUDO bash -lc "cat > '$dropin' <<EOF
# Managed by VibeOps (auth policy)
$pwline
$kbd
ChallengeResponseAuthentication no
UsePAM yes
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 4
X11Forwarding no
$authm
EOF"
}

# Remove conflicting VibeOps drop-ins and any AuthenticationMethods across configs
purge_conflicting_dropins() {
  local f
  for f in /etc/ssh/sshd_config.d/00-vibeops-auth.conf /etc/ssh/sshd_config.d/99-vibeops-auth.conf /etc/ssh/sshd_config.d/99-vibeops-hardening.conf; do
    if [[ -f "$f" ]]; then
      backup_file "$f"
      $SUDO rm -f "$f"
    fi
  done
}

clean_auth_methods_globally() {
  local f
  for f in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
    [[ -f "$f" ]] || continue
    if grep -qE '^[[:space:]]*AuthenticationMethods[[:space:]]' "$f" 2>/dev/null; then
      backup_file "$f"
      $SUDO sed -ri 's/^[[:space:]]*AuthenticationMethods.*/# AuthenticationMethods removed by VibeOps/' "$f"
    fi
  done
}

# Arg parsing
PORT=""
FORCE_DISABLE_PW=0
TARGET_USER=""
TARGET_PUBKEY=""
ALLOW_UFW=0
OTP_MODE="off" # off|optional|required
INTERACTIVE=0
LIST_KEYS=0
SUMMARY_ONLY=0
DRY_RUN=0
PUBKEY_FILE=""
PASSWORD_MODE="" # on|off|empty (no override)
OTP_USER=""
OTP_STATUS_ONLY=0
SHOW_OTP_USER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="$2"; shift 2 ;;
    --force)
      FORCE_DISABLE_PW=1; shift ;;
    --user)
      TARGET_USER="$2"; shift 2 ;;
    --pubkey)
      TARGET_PUBKEY="$2"; shift 2 ;;
    --allow-ufw)
      ALLOW_UFW=1; shift ;;
    --otp)
      OTP_MODE="$2"; shift 2 ;;
    --interactive)
      INTERACTIVE=1; shift ;;
    --list-keys)
      LIST_KEYS=1; shift ;;
    --summary)
      SUMMARY_ONLY=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --pubkey-file)
      PUBKEY_FILE="$2"; shift 2 ;;
    --password)
      PASSWORD_MODE="$2"; shift 2 ;;
    --otp-user)
      OTP_USER="$2"; shift 2 ;;
    --otp-status)
      OTP_STATUS_ONLY=1; shift ;;
    --show-otp)
      SHOW_OTP_USER="$2"; shift 2 ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# //'; exit 0 ;;
    *) log_warn "Argumen tidak dikenali: $1"; shift ;;
  esac
done

require_root_or_sudo
ensure_pkg openssh-server

# Summary only
if [[ $SUMMARY_ONLY -eq 1 ]]; then
  print_existing_keys
  echo
  print_effective_summary
  # OTP status quick check
  if grep -q 'pam_google_authenticator\.so' /etc/pam.d/sshd 2>/dev/null; then
    echo "  OTP (PAM): ENABLED"
  else
    echo "  OTP (PAM): DISABLED"
  fi
  exit 0
fi

# Interactive wizard
if [[ $INTERACTIVE -eq 1 ]]; then
  echo "-- Mode interaktif --"
  echo
print_existing_keys
echo
echo "Rekomendasi: tambahkan minimal satu public key sebelum mematikan password login."
echo "Anda dapat menempelkan key langsung atau memilih file .pub yang sudah ada."
  if confirm "Tambah public key sekarang?" y; then
    TARGET_USER=$(prompt "Username" "hades")
    if confirm "Ambil dari file .pub?" n; then
      PUBKEY_FILE=$(prompt "Path file public key" "")
      [[ -n "$PUBKEY_FILE" ]] && TARGET_PUBKEY=$(read_pubkey_from_file "$PUBKEY_FILE")
    else
      TARGET_PUBKEY=$(prompt "Tempel public key (ssh-ed25519/ssh-rsa/ecdsa-sha2-*)" "")
    fi
    if ! is_valid_pubkey "${TARGET_PUBKEY:-}"; then
      log_err "Public key tidak valid. Ulangi dengan key yang benar."; exit 1
    fi
  fi
  if confirm "Ganti port SSH? (disarankan hanya jika Anda sudah mengizinkan port baru di firewall)" n; then
    PORT=$(prompt "Port SSH" "22")
  else
    PORT=""
  fi
  echo "Aktifkan OTP (TOTP) untuk SSH? Pilih: 0=off, 1=optional (nullok), 2=required"
  sel=$(prompt "Pilihan" "1")
  case "$sel" in
    0) OTP_MODE="off" ;;
    1) OTP_MODE="optional" ;;
    2) OTP_MODE="required" ;;
    *) OTP_MODE="optional" ;;
  esac
  if [[ "$OTP_MODE" != "off" ]] && confirm "Generate OTP untuk user tertentu sekarang? (siapkan aplikasi Authenticator)" y; then
    TARGET_USER=${TARGET_USER:-$(prompt "Username untuk OTP" "hades")}
  fi
  if confirm "Izinkan port di UFW (jika diubah)?" y; then
    ALLOW_UFW=1
  fi
  if [[ -z "$PORT" || "$PORT" == "22" ]]; then
    confirm "Aktifkan rate-limit UFW untuk OpenSSH? (mengurangi brute-force)" y && limit_ufw_ssh || true
  fi
fi

if [[ $LIST_KEYS -eq 1 ]]; then
  print_existing_keys
fi

if [[ -n "$PUBKEY_FILE" && -z "$TARGET_PUBKEY" ]]; then
  TARGET_PUBKEY=$(read_pubkey_from_file "$PUBKEY_FILE")
fi

if [[ -n "$TARGET_USER" && -n "$TARGET_PUBKEY" ]]; then
  log_info "Menambahkan public key untuk user $TARGET_USER ..."
  add_pubkey "$TARGET_USER" "$TARGET_PUBKEY"
fi

local_have_keys=$(have_any_authorized_keys)
if [[ $local_have_keys -eq 0 && $FORCE_DISABLE_PW -eq 0 ]]; then
  log_warn "Tidak ada authorized_keys terdeteksi. Gunakan --user/--pubkey untuk menambahkan, atau --force untuk menonaktifkan password (BERISIKO)."
fi

CFG="/etc/ssh/sshd_config"
backup_file "$CFG"

# Set opsi aman
set_sshd_option PermitRootLogin no
set_sshd_option PubkeyAuthentication yes
set_sshd_option MaxAuthTries 4
set_sshd_option X11Forwarding no
set_sshd_option ChallengeResponseAuthentication no
set_sshd_option UsePAM yes

# Port jika diminta
if [[ -n "$PORT" ]]; then
  set_sshd_option Port "$PORT"
fi

# PasswordAuthentication
if [[ -n "$PASSWORD_MODE" ]]; then
  if [[ "$PASSWORD_MODE" == "on" ]]; then
    set_sshd_option PasswordAuthentication yes
    log_ok "PasswordAuthentication enabled (ON)"
  else
    set_sshd_option PasswordAuthentication no
    log_ok "PasswordAuthentication disabled (OFF)"
  fi
else
  if [[ $local_have_keys -eq 1 || $FORCE_DISABLE_PW -eq 1 ]]; then
    set_sshd_option PasswordAuthentication no
    log_ok "PasswordAuthentication disabled"
  else
    log_warn "PasswordAuthentication tetap AKTIF (untuk mencegah lockout). Tambahkan key lalu jalankan ulang skrip dengan --force."
  fi
fi

# OTP configuration if requested
configure_otp "$OTP_MODE" "${TARGET_USER:-}"

# Enforce via highest precedence drop-in and purge conflicting settings
purge_conflicting_dropins
clean_auth_methods_globally
write_sshd_dropin "$OTP_MODE" "$PASSWORD_MODE"

# Dry-run exit before applying restart
if [[ $DRY_RUN -eq 1 ]]; then
  echo
  log_info "Dry-run: perubahan konfigurasi telah disiapkan tetapi layanan tidak direstart."
  print_effective_summary
  exit 0
fi

restart_ssh_service

if [[ -n "$PORT" && $ALLOW_UFW -eq 1 ]]; then
  allow_ufw_port "$PORT"
fi

log_info "Konfigurasi efektif (ringkas):"
sshd -T 2>/dev/null | sed -n 's/^\(port\|permitrootlogin\|passwordauthentication\|pubkeyauthentication\|maxauthtries\|x11forwarding\|kbdinteractiveauthentication\|authenticationmethods\) /\U&/p' | sort
echo
if [[ -n "$SHOW_OTP_USER" ]]; then
  home=$(getent passwd "$SHOW_OTP_USER" | awk -F: '{print $6}')
  if [[ -s "$home/.google_authenticator" ]]; then
    secret=$(head -n1 "$home/.google_authenticator" 2>/dev/null || true)
    echo "OTP untuk $SHOW_OTP_USER: $secret"
    echo "otpauth://totp/${SHOW_OTP_USER}@$(hostname)?secret=${secret}&digits=6&period=30"
  else
    echo "OTP untuk $SHOW_OTP_USER tidak ditemukan."
  fi
fi
echo "Tips berikutnya:"
echo "- Pastikan Anda bisa login via kunci SSH sebelum memutus sesi saat ini."
echo "- Simpan backup: /etc/ssh/sshd_config.*.bak untuk rollback cepat."
echo "- Lihat docs: /home/hades/vm-test/docs/ssh-config.md"

log_ok "Selesai."


