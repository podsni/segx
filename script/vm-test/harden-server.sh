#!/usr/bin/env bash

# harden-server.sh — Baseline hardening untuk Debian/Ubuntu (idempotent, non-interaktif)
#
# Fitur:
# - Deteksi OS (Debian/Ubuntu) & apt
# - Update, upgrade, dan aktifkan unattended-upgrades (reboot otomatis jam 03:30)
# - Firewall UFW (default deny incoming; allow OpenSSH, 80/tcp, 443/tcp)
# - SSH hardening (PermitRootLogin no; MaxAuthTries 4; X11Forwarding no; PasswordAuthentication no jika ada authorized_keys)
# - Fail2ban (jail sshd dasar)
# - Sysctl hardening konservatif
# - NTP (systemd-timesyncd)
# - Verifikasi akhir
#
# Penggunaan (disarankan uji dulu via audit):
#   bash /home/hades/vm-test/vps-sec-check.sh --all --no-color | cat
#   sudo bash /home/hades/vm-test/harden-server.sh
#
set -euo pipefail

log_info()  { printf "\033[36m[INFO]\033[0m %s\n" "$*"; }
log_warn()  { printf "\033[33m[WARN]\033[0m %s\n" "$*"; }
log_ok()    { printf "\033[32m[ OK ]\033[0m %s\n" "$*"; }
log_crit()  { printf "\033[31m[CRIT]\033[0m %s\n" "$*"; }

require_root_or_sudo() {
  if [[ $(id -u) -eq 0 ]]; then
    SUDO=""
  else
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    else
      log_crit "Skrip butuh hak root. Install sudo atau jalankan sebagai root."
      exit 1
    fi
  fi
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID=${ID:-}
    OS_LIKE=${ID_LIKE:-}
  else
    OS_ID=""; OS_LIKE=""
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    log_crit "apt-get tidak ditemukan. Skrip ini ditujukan untuk Debian/Ubuntu."
    exit 1
  fi
  case "$OS_ID" in
    ubuntu|debian) : ;; # ok
    *)
      if [[ "$OS_LIKE" == *debian* ]]; then
        :
      else
        log_warn "OS tidak terdeteksi sebagai Debian/Ubuntu. Melanjutkan dengan asumsi kompatibel apt."
      fi
      ;;
  esac
  log_ok "OS: ${PRETTY_NAME:-$OS_ID} (apt)"
}

apt_update_upgrade() {
  log_info "Update & upgrade paket (non-interaktif) ..."
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update -y
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

ensure_pkgs() {
  local pkgs=("$@")
  log_info "Memastikan paket terpasang: ${pkgs[*]}"
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local bak="${f}.$(date +%F-%H%M%S).bak"
    $SUDO cp -a "$f" "$bak"
    log_ok "Backup: $bak"
  fi
}

configure_unattended_upgrades() {
  log_info "Mengaktifkan unattended-upgrades ..."
  ensure_pkgs unattended-upgrades apt-listchanges update-notifier-common
  # aktifkan unattended upgrades via dpkg-reconfigure
  $SUDO dpkg-reconfigure -f noninteractive unattended-upgrades || true
  # jadwal dan reboot otomatis
  local cfg="/etc/apt/apt.conf.d/20auto-upgrades"
  backup_file "$cfg"
  $SUDO bash -lc 'cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:30";
EOF'
  log_ok "Unattended upgrades dikonfigurasi"
}

configure_ufw() {
  log_info "Mengkonfigurasi UFW ..."
  ensure_pkgs ufw
  # Kebijakan dasar
  $SUDO ufw --force reset >/dev/null 2>&1 || true
  $SUDO ufw default deny incoming
  $SUDO ufw default allow outgoing
  # Izinkan layanan umum
  $SUDO ufw allow OpenSSH
  $SUDO ufw allow 80,443/tcp
  # Aktifkan tanpa prompt
  $SUDO ufw --force enable
  log_ok "UFW aktif dengan kebijakan minimal"
}

configure_ssh_hardening() {
  log_info "SSH hardening ..."
  ensure_pkgs openssh-server
  local cfg="/etc/ssh/sshd_config"
  backup_file "$cfg"
  # Set nilai default yang aman
  $SUDO bash -lc 'cfg=/etc/ssh/sshd_config;
    if grep -qE "^#?PermitRootLogin" "$cfg"; then sed -ri "s/^#?PermitRootLogin.*/PermitRootLogin no/" "$cfg"; else echo "PermitRootLogin no" | tee -a "$cfg" >/dev/null; fi
    if grep -qE "^#?MaxAuthTries" "$cfg"; then sed -ri "s/^#?MaxAuthTries.*/MaxAuthTries 4/" "$cfg"; else echo "MaxAuthTries 4" | tee -a "$cfg" >/dev/null; fi
    if grep -qE "^#?X11Forwarding" "$cfg"; then sed -ri "s/^#?X11Forwarding.*/X11Forwarding no/" "$cfg"; else echo "X11Forwarding no" | tee -a "$cfg" >/dev/null; fi'

  # Nonaktifkan password auth hanya jika ditemukan authorized_keys non-kosong
  local have_keys=0
  if [[ -s /root/.ssh/authorized_keys ]]; then have_keys=1; fi
  # Cari pada seluruh home user
  while IFS=: read -r user _ uid _ _ home shell; do
    [[ "$uid" -ge 1000 ]] || continue
    [[ -d "$home/.ssh" && -s "$home/.ssh/authorized_keys" ]] && have_keys=1
  done < /etc/passwd

  if [[ $have_keys -eq 1 ]]; then
    log_info "Authorized keys terdeteksi — menonaktifkan PasswordAuthentication."
    $SUDO bash -lc 'cfg=/etc/ssh/sshd_config; if grep -qE "^#?PasswordAuthentication" "$cfg"; then sed -ri "s/^#?PasswordAuthentication.*/PasswordAuthentication no/" "$cfg"; else echo "PasswordAuthentication no" | tee -a "$cfg" >/dev/null; fi'
  else
    log_warn "Tidak menemukan authorized_keys. PasswordAuthentication tetap diaktifkan untuk mencegah lockout."
  fi

  # Validasi & restart
  if $SUDO sshd -t 2>/dev/null; then
    $SUDO systemctl restart sshd || $SUDO systemctl restart ssh || true
    log_ok "Konfigurasi SSH diterapkan"
  else
    log_crit "Konfigurasi SSH tidak valid. Mengembalikan dari backup."
    $SUDO cp -a "$cfg".bak "$cfg" || true
    exit 1
  fi
}

configure_fail2ban() {
  log_info "Mengkonfigurasi fail2ban ..."
  ensure_pkgs fail2ban
  local jail="/etc/fail2ban/jail.local"
  backup_file "$jail"
  $SUDO bash -lc 'cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 5
findtime = 10m
bantime = 1h
banaction = ufw
EOF'
  $SUDO systemctl enable --now fail2ban
  log_ok "fail2ban aktif"
}

configure_sysctl() {
  log_info "Menerapkan sysctl hardening ..."
  local f="/etc/sysctl.d/99-vibeops.conf"
  backup_file "$f"
  $SUDO bash -lc 'cat > /etc/sysctl.d/99-vibeops.conf <<EOF
net.ipv4.ip_forward=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
net.ipv6.conf.all.accept_ra=0
EOF'
  $SUDO sysctl --system >/dev/null
  log_ok "sysctl diterapkan"
}

enable_timesync() {
  log_info "Memastikan sinkronisasi waktu aktif ..."
  $SUDO systemctl enable --now systemd-timesyncd || true
}

verify_summary() {
  echo
  log_info "Verifikasi ringkas:"
  $SUDO ufw status verbose | sed 's/^/[UFW] /' || true
  $SUDO fail2ban-client status 2>/dev/null | sed 's/^/[F2B] /' || true
  $SUDO fail2ban-client status sshd 2>/dev/null | sed 's/^/[F2B] /' || true
  bash /home/hades/vm-test/vps-sec-check.sh --all --no-color | sed 's/^/[AUDIT] /' || true
}

main() {
  require_root_or_sudo
  detect_os
  apt_update_upgrade
  configure_unattended_upgrades
  configure_ufw
  configure_ssh_hardening
  configure_fail2ban
  configure_sysctl
  enable_timesync
  verify_summary
  log_ok "Hardening selesai."
}

main "$@"


