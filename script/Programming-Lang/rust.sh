#!/usr/bin/env bash
# Installer Rust otomatis + auto-deps untuk Linux
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

# ---------- Install Rust ----------
install_rust() {
  log "Menginstall Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

# ---------- Load PATH & verifikasi ----------
verify_rust() {
  # shellcheck disable=SC1090
  [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
  log "Verifikasi Rust:"
  rustc --version
  cargo --version
}

# ---------- Main ----------
main() {
  detect_pkg_mgr
  install_curl
  install_rust
  verify_rust
  log "Instalasi selesai 🎉. Jalankan 'source ~/.cargo/env' jika PATH belum aktif."
}

main "$@"
