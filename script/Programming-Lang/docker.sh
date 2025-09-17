#!/usr/bin/env bash
# needs-sudo
# Universal Docker installer (apt/dnf/pacman/zypper/apk)
# By Hendra’s request

set -euo pipefail

# ============================ Utils ============================
log()  { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31mxx\033[0m %s\n" "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || err "Harap jalankan sebagai root atau gunakan sudo."

# Flags
AUTO_YES="${AUTO_YES:-0}"       # 1 = non-interactive
ADD_USER="${ADD_USER:-0}"       # 1 = auto add current login user to 'docker'
CONFIGURE_DAEMON="${CONFIGURE_DAEMON:-1}"  # 1 = tulis daemon.json
while [[ "${1:-}" =~ ^- ]]; do
  case "$1" in
    -y|--yes|--non-interactive) AUTO_YES=1 ;;
    --add-user) ADD_USER=1 ;;
    --no-daemon-json) CONFIGURE_DAEMON=0 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]
  -y, --yes                Non-interactive (jawab "ya" otomatis)
      --add-user           Tambahkan user aktif ke grup docker
      --no-daemon-json     Jangan tulis /etc/docker/daemon.json
Env:
  AUTO_YES=1, ADD_USER=1, CONFIGURE_DAEMON=0 (sama seperti flags)
EOF
      exit 0
      ;;
    *) err "Unknown option: $1" ;;
  esac
  shift
done

# Detect OS
OS_ID=""; OS_VER_CODENAME=""; OS_VER_ID=""
if [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_ID="${ID:-}"; OS_VER_CODENAME="${VERSION_CODENAME:-}"; OS_VER_ID="${VERSION_ID:-}"
else
  err "Tidak dapat mendeteksi distribusi Linux (tidak ada /etc/os-release)."
fi

PKG_MGR=""
if   need apt-get; then PKG_MGR="apt"
elif need dnf;     then PKG_MGR="dnf"
elif need yum;     then PKG_MGR="yum"
elif need pacman;  then PKG_MGR="pacman"
elif need zypper;  then PKG_MGR="zypper"
elif need apk;     then PKG_MGR="apk"
else err "Package manager tidak didukung."
fi

is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }
can_systemctl() { command -v systemctl >/dev/null 2>&1 && ! is_wsl; }

# ======================= APT (Ubuntu/Debian) ===================
apt_install_docker() {
  log "Mendeteksi sistem berbasis Debian/Ubuntu (APT)"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release

  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # Tentukan codename
  CODENAME="${OS_VER_CODENAME:-}"
  if [ -z "$CODENAME" ]; then
    if need lsb_release; then
      CODENAME="$(lsb_release -cs || true)"
    fi
  fi
  [ -n "$CODENAME" ] || err "Tidak bisa menentukan VERSION_CODENAME untuk APT."

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} ${CODENAME} stable" \
    >/etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# ======== DNF/YUM (RHEL/CentOS/Alma/Rocky/Fedora/SLES) ========
dnf_install_docker() {
  log "Mendeteksi sistem berbasis RHEL/Fedora (DNF/YUM)"
  # Enable repo resmi Docker
  if [ "$OS_ID" = "fedora" ]; then
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  else
    # rhel/centos/alma/rocky
    ${PKG_MGR} -y install dnf-plugins-core || true
    ${PKG_MGR} config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi

  # SELinux policy untuk container (jika tersedia)
  ${PKG_MGR} -y install container-selinux || true

  ${PKG_MGR} -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# ======================== pacman (Arch) ========================
pacman_install_docker() {
  log "Mendeteksi Arch/Manjaro (pacman)"
  pacman -Sy --noconfirm --needed docker docker-compose
}

# ======================= zypper (openSUSE) =====================
zypper_install_docker() {
  log "Mendeteksi openSUSE/SLES (zypper)"
  zypper --non-interactive refresh
  # openSUSE biasanya menyediakan docker langsung dari repo resmi
  zypper --non-interactive install docker docker-compose || zypper --non-interactive install docker
}

# ========================= apk (Alpine) ========================
apk_install_docker() {
  log "Mendeteksi Alpine (apk)"
  apk add --no-cache docker docker-cli-compose docker-buildx
}

# ========================= Common tasks ========================
configure_daemon_json() {
  [ "$CONFIGURE_DAEMON" -eq 1 ] || return 0

  install -d -m 0755 /etc/docker
  DAEMON_JSON='/etc/docker/daemon.json'
  if [ ! -f "$DAEMON_JSON" ]; then
    cat >"$DAEMON_JSON" <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
JSON
    log "Menulis $DAEMON_JSON (log rotation + cgroupdriver=systemd)"
  else
    warn "$DAEMON_JSON sudah ada, tidak diubah."
  fi
}

enable_start_service() {
  if can_systemctl; then
    systemctl daemon-reload || true
    systemctl enable --now docker
  else
    warn "systemd tidak tersedia (mungkin WSL). Lewati enable/start service."
  fi
}

post_check() {
  log "Verifikasi versi:"
  docker --version || true
  if docker compose version >/dev/null 2>&1; then
    docker compose version
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose --version
  else
    warn "Plugin compose tidak terdeteksi."
  fi
}

maybe_add_user() {
  local do_add="$ADD_USER"
  if [ "$AUTO_YES" -eq 0 ] && [ "$ADD_USER" -eq 0 ]; then
    read -rp "Tambah user saat ini ke grup docker agar tidak perlu sudo? (y/n): " ans
    [[ "$ans" =~ ^[Yy]$ ]] && do_add=1
  fi

  if [ "$do_add" -eq 1 ]; then
    # logname bisa gagal di sudo non-tty; fallback ke SUDO_USER/USER
    CURRENT_USER="$(logname 2>/dev/null || echo "${SUDO_USER:-${USER:-}}" )"
    if [ -n "$CURRENT_USER" ]; then
      usermod -aG docker "$CURRENT_USER"
      log "User '$CURRENT_USER' ditambahkan ke grup docker. Logout/login agar efektif."
    else
      warn "Tidak bisa menentukan user aktif; lewati penambahan ke grup docker."
    fi
  fi
}

already_installed() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker sudah terpasang: $(docker --version 2>/dev/null || true)"
    return 0
  fi
  return 1
}

# ============================ Main =============================
log "Distro: ${OS_ID} ${OS_VER_ID} (${OS_VER_CODENAME:-})  | PkgMgr: ${PKG_MGR}"

if already_installed; then
  warn "Lewati instalasi paket inti (sudah ada). Tetap akan konfigurasi service & daemon.json."
else
  case "$PKG_MGR" in
    apt)    apt_install_docker ;;
    dnf|yum) dnf_install_docker ;;
    pacman) pacman_install_docker ;;
    zypper) zypper_install_docker ;;
    apk)    apk_install_docker ;;
    *) err "Pkg mgr tidak didukung: $PKG_MGR" ;;
  esac
fi

# Konfigurasi opsional
configure_daemon_json
enable_start_service
post_check
maybe_add_user

echo
echo "✅ Selesai. Coba: docker run --rm hello-world"
