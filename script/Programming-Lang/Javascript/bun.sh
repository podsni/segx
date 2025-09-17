#!/usr/bin/env bash
# Installer Bun untuk Linux
# By Hendra 😎

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

# ---------- Install curl jika belum ada ----------
install_curl() {
  if need_cmd curl; then
    log "curl sudah terpasang."
    return
  fi
  log "Menginstall curl..."
  case "$PKG_MGR" in
    pacman) as_root pacman -Sy --noconfirm curl ;;
    apt) as_root apt-get update -y && as_root apt-get install -y curl ;;
    dnf) as_root dnf install -y curl ;;
    yum) as_root yum install -y curl ;;
    zypper) as_root zypper --non-interactive install curl ;;
    apk) as_root apk add --no-cache curl ;;
  esac
}

# ---------- Install Bun ----------
install_bun() {
  log "Menginstall Bun..."
  curl -fsSL https://bun.sh/install | bash
}

# ---------- Load PATH & verifikasi ----------
verify_bun() {
  # PATH bun biasanya disimpan di ~/.bun/bin
  export PATH="$HOME/.bun/bin:$PATH"
  if ! grep -qs '.bun/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.bashrc"
  fi
  log "Verifikasi instalasi Bun:"
  bun --version
}

# ---------- Main ----------
main() {
  detect_pkg_mgr
  install_curl
  install_bun
  verify_bun
  log "Instalasi Bun selesai 🎉. Jalankan: bun --version"
}

main "$@"
