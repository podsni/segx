#!/usr/bin/env bash
# Installer Zig untuk Linux
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

# ---------- Install deps dasar ----------
install_deps() {
  for dep in curl tar; do
    if ! need_cmd "$dep"; then
      log "Menginstall $dep..."
      case "$PKG_MGR" in
        pacman) as_root pacman -Sy --noconfirm "$dep" ;;
        apt) as_root apt-get update -y && as_root apt-get install -y "$dep" ;;
        dnf) as_root dnf install -y "$dep" ;;
        yum) as_root yum install -y "$dep" ;;
        zypper) as_root zypper --non-interactive install "$dep" ;;
        apk) as_root apk add --no-cache "$dep" ;;
      esac
    fi
  done
}

# ---------- Install Zig ----------
install_zig() {
  log "Mengambil versi terbaru Zig dari GitHub..."
  LATEST_URL=$(curl -s https://ziglang.org/download/index.json | grep -Po '"tarball":.*?linux-x86_64.*?\.tar\.xz"' | head -n1 | cut -d'"' -f4)
  [ -n "$LATEST_URL" ] || err "Tidak bisa menemukan URL release Zig."

  mkdir -p "$HOME/.local/zig"
  log "Mengunduh Zig..."
  curl -L "$LATEST_URL" -o /tmp/zig.tar.xz

  log "Mengekstrak Zig..."
  tar -xf /tmp/zig.tar.xz -C "$HOME/.local/zig" --strip-components=1

  rm /tmp/zig.tar.xz
}

# ---------- Konfigurasi PATH ----------
setup_path() {
  if ! grep -qs '.local/zig' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/zig:$PATH"' >> "$HOME/.bashrc"
  fi
  export PATH="$HOME/.local/zig:$PATH"
}

# ---------- Verifikasi ----------
verify_zig() {
  log "Verifikasi instalasi Zig:"
  zig version
}

# ---------- Main ----------
main() {
  detect_pkg_mgr
  install_deps
  install_zig
  setup_path
  verify_zig
  log "Instalasi Zig selesai 🎉. Jalankan: zig version"
}

main "$@"
