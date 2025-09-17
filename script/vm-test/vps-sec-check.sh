#!/usr/bin/env bash
# vps-sec-check.sh — Audit keamanan VPS cepat dan komprehensif (read-only, non-intrusif)
#
# Penggunaan:
#   bash vps-sec-check.sh --all
# Opsi:
#   --all | -a        : Jalankan semua cek
#   --install         : Coba install utilitas opsional (tanpa interaksi)
#   --no-color        : Nonaktifkan warna
#   --help | -h       : Bantuan singkat
#
# Catatan:
# - Skrip TIDAK mengubah konfigurasi. Semua cek bersifat baca saja.
# - Beberapa cek memerlukan utilitas opsional (sshd, ss, getenforce, apparmor_status, dll).
#   Gunakan --install untuk mencoba memasang bila belum ada.

set -u

COLOR=1
for arg in "$@"; do [[ "$arg" == "--no-color" ]] && COLOR=0; done
if [[ $COLOR -eq 1 ]]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; NC="\033[0m"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; NC=""
fi

header() { echo -e "${BOLD}$1${NC}"; }
info()   { echo -e "${CYAN}$1${NC}"; }
ok()     { echo -e "${GREEN}$1${NC}"; }
warn()   { echo -e "${YELLOW}$1${NC}"; }
crit()   { echo -e "${RED}$1${NC}"; }

HAS() { command -v "$1" >/dev/null 2>&1; }

ALLOW_INSTALL=0
DO_ALL=0

if [[ $# -eq 0 ]]; then DO_ALL=1; fi

for arg in "$@"; do
  case "$arg" in
    --all|-a) DO_ALL=1 ;;
    --install) ALLOW_INSTALL=1 ;;
    --help|-h)
      sed -n '2,60p' "$0"; exit 0;;
    --no-color) ;; # handled above
    *) warn "Opsi tidak dikenal: $arg" ;;
  esac
done

detect_pkg() {
  if HAS apt-get; then echo apt; return; fi
  if HAS dnf; then echo dnf; return; fi
  if HAS yum; then echo yum; return; fi
  if HAS pacman; then echo pacman; return; fi
  echo ""
}

ensure_pkg() {
  local bin="$1"; local pkg="${2:-$1}"
  if HAS "$bin"; then return 0; fi
  [[ $ALLOW_INSTALL -eq 0 ]] && return 1
  local mgr; mgr=$(detect_pkg)
  [[ -z "$mgr" ]] && return 1
  info "Menginstall $pkg (butuh sudo) ..."
  case "$mgr" in
    apt) sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" ;;
    dnf) sudo dnf install -y "$pkg" ;;
    yum) sudo yum install -y "$pkg" ;;
    pacman) sudo pacman -Sy --noconfirm "$pkg" ;;
  esac
  HAS "$bin"
}

hr() { echo -e "${DIM}------------------------------------------------------------------------${NC}"; }

# Koleksi temuan untuk ringkasan
ISSUES_CRIT=()
ISSUES_WARN=()
add_crit() { ISSUES_CRIT+=("$1"); crit "[CRIT] $1"; }
add_warn() { ISSUES_WARN+=("$1"); warn "[WARN] $1"; }

section_system() {
  header "[1] Informasi Sistem"
  hr
  echo "Tanggal          : $(date -Is)"
  echo "Hostname         : $(hostname)"
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "OS               : ${PRETTY_NAME:-unknown}"
  else
    echo "OS               : $(uname -s)"
  fi
  echo "Kernel           : $(uname -r)"
  echo "Arsitektur       : $(uname -m)"
  if HAS systemd-detect-virt; then
    echo "Virtualisasi     : $(systemd-detect-virt 2>/dev/null || echo unknown)"
  fi
  echo "Uptime           : $(uptime -p 2>/dev/null || true)"
  hr
}

section_updates() {
  header "[2] Status Pembaruan Keamanan"
  hr
  local mgr; mgr=$(detect_pkg)
  case "$mgr" in
    apt)
      if HAS apt; then
        local upg security_count all_count
        upg=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." || true)
        all_count=$(echo "$upg" | sed '/^$/d' | wc -l | tr -d ' ')
        security_count=$(echo "$upg" | grep -i security | wc -l | tr -d ' ')
        echo "Paket dapat diupgrade: $all_count (keamanan: $security_count)"
        if [[ "$all_count" -gt 0 ]]; then add_warn "Ada paket yang belum diupgrade ($all_count)."; fi
        if [[ "$security_count" -gt 0 ]]; then add_crit "Ada pembaruan keamanan yang tertunda ($security_count)."; fi
      fi
      ;;
    dnf|yum)
      if HAS yum || HAS dnf; then
        local count
        count=$( (yum check-update -q || dnf check-update -q || true) | sed -n '/^Obsoleting/,$d; /^[A-Za-z0-9].*\.[a-z]/p' | wc -l | tr -d ' ')
        echo "Paket dapat diupgrade: $count"
        [[ "$count" -gt 0 ]] && add_warn "Ada paket yang belum diupgrade ($count)."
      fi
      ;;
    pacman)
      if HAS checkupdates; then
        local count
        count=$(checkupdates 2>/dev/null | wc -l | tr -d ' ')
        echo "Paket dapat diupgrade: $count"
        [[ "$count" -gt 0 ]] && add_warn "Ada paket yang belum diupgrade ($count)."
      else
        warn "checkupdates tidak tersedia (pacman-contrib)."
      fi
      ;;
    *)
      warn "Manajer paket tidak dikenali; lewati."
      ;;
  esac
  hr
}

section_firewall() {
  header "[3] Firewall"
  hr
  local any=0
  if HAS ufw; then
    any=1
    echo "UFW status:"
    ufw status verbose 2>/dev/null | sed 's/^/  /'
    ufw status | grep -qi inactive && add_warn "UFW tidak aktif."
  fi
  if HAS firewall-cmd; then
    any=1
    echo "firewalld: $(firewall-cmd --state 2>/dev/null || echo unknown)"
    firewall-cmd --list-all 2>/dev/null | sed 's/^/  /'
  fi
  if HAS iptables; then
    any=1
    echo "iptables (filter):"
    iptables -S 2>/dev/null | sed 's/^/  /'
  fi
  if [[ $any -eq 0 ]]; then
    add_warn "Tidak ada firewall terdeteksi (ufw/firewalld/iptables). Pertimbangkan mengaktifkan firewall."
  fi
  hr
}

section_ssh() {
  header "[4] Konfigurasi SSHD"
  hr
  local has_sshd=0
  if HAS sshd || ensure_pkg ssh; then has_sshd=1; fi

  if [[ $has_sshd -eq 1 ]]; then
    local cfg
    cfg=$( (sshd -T 2>/dev/null) || true )
    if [[ -n "$cfg" ]]; then
      echo "$cfg" | sed 's/^/  /' | head -n 20 >/dev/null # quiet linter; real check below
      local port prl paw pka maxtry x11
      port=$(echo "$cfg" | sed -n 's/^port //p' | head -1)
      prl=$(echo "$cfg" | sed -n 's/^permitrootlogin //p' | head -1)
      paw=$(echo "$cfg" | sed -n 's/^passwordauthentication //p' | head -1)
      pka=$(echo "$cfg" | sed -n 's/^pubkeyauthentication //p' | head -1)
      maxtry=$(echo "$cfg" | sed -n 's/^maxauthtries //p' | head -1)
      x11=$(echo "$cfg" | sed -n 's/^x11forwarding //p' | head -1)
      echo "Port                 : ${port:-unknown}"
      echo "PermitRootLogin      : ${prl:-unknown}"
      echo "PasswordAuthentication: ${paw:-unknown}"
      echo "PubkeyAuthentication : ${pka:-unknown}"
      echo "MaxAuthTries         : ${maxtry:-unknown}"
      echo "X11Forwarding        : ${x11:-unknown}"
      [[ "${prl,,}" == "yes" ]] && add_crit "PermitRootLogin yes (disarankan nonaktif)."
      [[ "${paw,,}" == "yes" ]] && add_warn "PasswordAuthentication yes (disarankan pakai kunci)."
      [[ -n "$maxtry" && "$maxtry" -gt 6 ]] && add_warn "MaxAuthTries terlalu tinggi ($maxtry)."
      [[ "${x11,,}" == "yes" ]] && add_warn "X11Forwarding aktif (nonaktif jika tidak perlu)."
      [[ -n "$port" && "$port" == "22" ]] && warn "SSH di port default 22 (opsional ubah)."
    else
      warn "Tidak bisa membaca konfigurasi efektif dengan 'sshd -T'."
    fi
  else
    warn "sshd tidak ditemukan."
  fi
  hr
}

section_listen() {
  header "[5] Layanan Mendengarkan (Open Ports)"
  hr
  if HAS ss || ensure_pkg iproute2 iproute2; then
    ss -tulpen 2>/dev/null | sed 's/^/  /'
    local wide
    wide=$(ss -tulpen 2>/dev/null | awk '$1 ~ /LISTEN|UNCONN/ {print $5}' | grep -E "(^|\[::\]|0.0.0.0):" || true)
    if [[ -n "$wide" ]]; then
      add_warn "Ada layanan listen pada semua interface (0.0.0.0/[::]). Pastikan memang diperlukan."
    fi
  else
    warn "Perintah ss tidak tersedia."
  fi
  hr
}

section_fail2ban() {
  header "[6] Proteksi Brute-force (fail2ban)"
  hr
  if HAS fail2ban-client; then
    fail2ban-client status 2>/dev/null | sed 's/^/  /'
  else
    warn "fail2ban tidak terpasang."
  fi
  hr
}

section_authlog() {
  header "[7] Aktivitas Login Mencurigakan (auth log)"
  hr
  local file=""
  if [[ -r /var/log/auth.log ]]; then file=/var/log/auth.log; fi
  if [[ -z "$file" && -r /var/log/secure ]]; then file=/var/log/secure; fi
  if [[ -z "$file" ]]; then warn "auth.log/secure tidak dapat dibaca."; hr; return; fi
  echo "Sumber data: $file"
  local fails top
  fails=$(grep -E "Failed password|Invalid user|authentication failure" "$file" 2>/dev/null | tail -n 200 || true)
  if [[ -n "$fails" ]]; then
    echo "$fails" | tail -n 5 | sed 's/^/  ... /'
    top=$(echo "$fails" | grep -oE "from ([0-9]{1,3}\.){3}[0-9]{1,3}" | awk '{print $2}' | sort | uniq -c | sort -nr | head -5)
    if [[ -n "$top" ]]; then
      echo "IP gagal tersering (recent):"
      echo "$top" | sed 's/^/  /'
      add_warn "Terdeteksi percobaan brute-force SSH pada log."
    fi
  else
    ok "Tidak ada entri gagal login terbaru yang mencolok."
  fi
  hr
}

section_users() {
  header "[8] Akun & Privilege"
  hr
  echo "Akun UID 0:"
  awk -F: '($3==0){print "  "$1" : "$7}' /etc/passwd
  local uid0_count
  uid0_count=$(awk -F: '($3==0){print $1}' /etc/passwd | wc -l | tr -d ' ')
  [[ "$uid0_count" -gt 1 ]] && add_warn "Lebih dari satu akun dengan UID 0."

  echo "Akun login interaktif (shell bukan nologin/false):"
  awk -F: '($7!~/nologin|false/){printf "  %-20s %s\n", $1,$7}' /etc/passwd | sed 's/^/ /'

  echo "Grup sudo/wheel/admin:"
  for g in sudo wheel admin; do getent group "$g" 2>/dev/null; done | sed 's/^/  /'

  echo "Sudoers NOPASSWD:"
  grep -R "NOPASSWD" /etc/sudoers /etc/sudoers.d 2>/dev/null | sed 's/^/  /' || true
  grep -R "NOPASSWD" /etc/sudoers /etc/sudoers.d >/dev/null 2>&1 && add_warn "Ada aturan sudo NOPASSWD."
  hr
}

section_filesystems() {
  header "[9] Keamanan Filesystem"
  hr
  if HAS findmnt; then
    for m in / /tmp /var/tmp /home; do
      if mountpoint -q "$m"; then
        local opt
        opt=$(findmnt -no OPTIONS "$m" 2>/dev/null)
        printf "Mount %s: %s\n" "$m" "$opt"
        [[ "$m" =~ /tmp && "$opt" != *noexec* ]] && add_warn "/tmp tanpa noexec."
        [[ "$opt" != *nodev* ]] && warn "$m tanpa nodev."
        [[ "$opt" != *nosuid* ]] && warn "$m tanpa nosuid."
      fi
    done
  else
    warn "findmnt tidak tersedia."
  fi
  echo "Direktori world-writable berisiko (subset):"
  for d in /tmp /var/tmp; do
    echo "  $d:"
    find "$d" -xdev -type d -perm -0002 -printf '    %p\n' 2>/dev/null | head -n 10
  done
  hr
}

section_sysctl() {
  header "[10] Hardening Kernel (sysctl)"
  hr
  read_k() { sysctl -n "$1" 2>/dev/null || echo "?"; }
  check_val() {
    local key="$1" expected="$2" desc="$3"
    local v; v=$(read_k "$key")
    printf "%-40s : %s (disarankan: %s)\n" "$key" "$v" "$expected"
    [[ "$v" == "$expected" ]] || add_warn "$desc -> $key=$v (disarankan $expected)"
  }
  check_val net.ipv4.ip_forward 0 "IP forward IPv4 nonaktif kecuali router"
  check_val net.ipv4.conf.all.accept_source_route 0 "Tolak source routing"
  check_val net.ipv4.conf.all.send_redirects 0 "Tolak ICMP redirects"
  check_val net.ipv4.icmp_echo_ignore_broadcasts 1 "Abaikan ICMP broadcast"
  check_val net.ipv4.tcp_syncookies 1 "Aktifkan TCP SYN cookies"
  check_val net.ipv4.conf.all.rp_filter 1 "Aktifkan reverse path filtering"
  if sysctl -a 2>/dev/null | grep -q net.ipv6; then
    check_val net.ipv6.conf.all.accept_ra 0 "Tolak Router Advertisements (server)"
  fi
  hr
}

section_mandatory_access() {
  header "[11] Mandatory Access Control (SELinux/AppArmor)"
  hr
  local any=0
  if HAS getenforce; then
    any=1
    echo "SELinux: $(getenforce 2>/dev/null)"
  fi
  if HAS sestatus; then
    any=1
    sestatus 2>/dev/null | sed 's/^/  /'
  fi
  if HAS apparmor_status; then
    any=1
    apparmor_status 2>/dev/null | sed 's/^/  /'
  fi
  if [[ $any -eq 0 ]]; then
    warn "SELinux/AppArmor tidak terdeteksi atau nonaktif."
  fi
  hr
}

section_time_sync() {
  header "[12] Sinkronisasi Waktu"
  hr
  local ok_any=0
  if HAS timedatectl; then
    timedatectl 2>/dev/null | sed 's/^/  /'
  fi
  if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then ok_any=1; echo "systemd-timesyncd aktif"; fi
  if systemctl is-active --quiet chronyd 2>/dev/null; then ok_any=1; echo "chronyd aktif"; fi
  if systemctl is-active --quiet ntp 2>/dev/null; then ok_any=1; echo "ntpd aktif"; fi
  [[ $ok_any -eq 0 ]] && add_warn "Layanan sinkronisasi waktu tidak terdeteksi aktif."
  hr
}

section_docker() {
  header "[13] Docker & Kontainer"
  hr
  if HAS docker; then
    docker info 2>/dev/null | sed -n '1,10p' | sed 's/^/  /'
    echo "Kontainer berjalan (ringkas):"
    docker ps --format '  {{.Names}} -> {{.Ports}}' 2>/dev/null || true
    if [[ -S /var/run/docker.sock ]]; then
      local perm owner
      perm=$(stat -c %a /var/run/docker.sock 2>/dev/null || echo '?')
      owner=$(stat -c %U:%G /var/run/docker.sock 2>/dev/null || echo '?')
      echo "docker.sock: $owner perm $perm"
      [[ "$perm" -gt 660 ]] && add_warn "Permission docker.sock longgar ($perm)."
    fi
  else
    info "Docker tidak terpasang."
  fi
  hr
}

section_services_autostart() {
  header "[14] Layanan Otomatis (Enabled)"
  hr
  if HAS systemctl; then
    systemctl list-unit-files --type=service --state=enabled 2>/dev/null | sed 's/^/  /'
  else
    warn "systemctl tidak tersedia."
  fi
  hr
}

summary_report() {
  header "Ringkasan Temuan"
  hr
  echo "Kritis : ${#ISSUES_CRIT[@]}"
  for i in "${ISSUES_CRIT[@]}"; do echo "  - $i"; done
  echo "Peringatan : ${#ISSUES_WARN[@]}"
  for i in "${ISSUES_WARN[@]}"; do echo "  - $i"; done

  echo
  if [[ ${#ISSUES_CRIT[@]} -eq 0 && ${#ISSUES_WARN[@]} -eq 0 ]]; then
    ok "Tidak ada temuan berarti. VPS Anda tampak terkonfigurasi cukup aman."
  else
    warn "Tinjau rekomendasi di atas untuk meningkatkan keamanan."
  fi
}

main() {
  section_system
  section_updates
  section_firewall
  section_ssh
  section_listen
  section_fail2ban
  section_authlog
  section_users
  section_filesystems
  section_sysctl
  section_mandatory_access
  section_time_sync
  section_docker
  section_services_autostart
  summary_report
}

main


