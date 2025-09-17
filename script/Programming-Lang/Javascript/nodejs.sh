#!/usr/bin/env bash
# Universal Node.js 22 installer dengan fnm + pnpm
# By Hendra's request 😁

set -euo pipefail

need_cmd() { command -v "$1" >/dev/null 2>&1; }
as_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    if need_cmd sudo; then sudo "$@"; else
      echo "Butuh root. Install sudo atau jalankan sebagai root." >&2
      exit 1
    fi
  else
    "$@"
  fi
}

log() { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
err() { printf "\033[1;31mxx\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- Deteksi package manager ----------
PKG_MGR=""
detect_pkg_mgr() {
  if need_cmd pacman; then PKG_MGR="pacman"
  elif need_cmd apt-get; then PKG_MGR="apt"
  elif need_cmd dnf; then PKG_MGR="dnf"
  elif need_cmd yum; then PKG_MGR="yum"
  elif need_cmd zypper; then PKG_MGR="zypper"
  elif need_cmd apk; then PKG_MGR="apk"
  else
    err "Tidak menemukan package manager yang didukung."
  fi
}

# ---------- Install deps dasar ----------
install_deps() {
  case "$PKG_MGR" in
    pacman)
      as_root pacman -Sy --noconfirm --needed curl unzip coreutils
      ;;
    apt)
      as_root apt-get update -y
      as_root apt-get install -y curl unzip ca-certificates
      ;;
    dnf)
      as_root dnf install -y curl unzip
      ;;
    yum)
      as_root yum install -y curl unzip
      ;;
    zypper)
      as_root zypper --non-interactive install curl unzip
      ;;
    apk)
      as_root apk add --no-cache curl unzip
      ;;
  esac
}

# ---------- Install FNM ----------
install_fnm() {
  if ! need_cmd fnm; then
    log "Menginstall fnm (Fast Node Manager)..."
    curl -fsSL https://fnm.vercel.app/install | bash
    # Aktifkan fnm untuk sesi ini
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "`fnm env`"
  else
    log "fnm sudah terpasang."
  fi
}

# ---------- Install Node.js 22 ----------
install_node() {
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "`fnm env`"
  if ! node -v 2>/dev/null | grep -q "v22"; then
    log "Menginstall Node.js v22..."
    fnm install 22
    fnm default 22
  else
    log "Node.js v22 sudah terpasang."
  fi
}

# ---------- Install pnpm ----------
install_pnpm() {
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "`fnm env`"
  if ! need_cmd pnpm; then
    log "Mengaktifkan pnpm via corepack..."
    corepack enable pnpm
  else
    log "pnpm sudah aktif."
  fi
}

# ---------- Verifikasi ----------
verify_install() {
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "`fnm env`"
  log "Versi Node.js:"
  node -v
  log "Versi pnpm:"
  pnpm -v
}

# ---------- Main ----------
main() {
  detect_pkg_mgr
  install_deps
  install_fnm
  install_node
  install_pnpm
  verify_install
  log "Instalasi selesai 🎉"
}

main "$@"
