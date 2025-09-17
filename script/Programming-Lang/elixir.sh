#!/usr/bin/env bash
# Installer Elixir + Erlang untuk Linux
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
  else
    err "Tidak menemukan package manager yang didukung."
  fi
}

# ---------- Install Elixir + Erlang ----------
install_elixir() {
  case "$PKG_MGR" in
    pacman)
      log "Menginstall Elixir + Erlang (Arch/Manjaro)..."
      as_root pacman -Sy --noconfirm elixir erlang
      ;;
    apt)
      log "Menginstall Erlang/Elixir (Debian/Ubuntu)..."
      as_root apt-get update -y
      as_root apt-get install -y curl gnupg
      curl -fsSL https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb -o esl.deb
      as_root dpkg -i esl.deb
      rm esl.deb
      as_root apt-get update -y
      as_root apt-get install -y esl-erlang elixir
      ;;
    dnf)
      log "Menginstall Erlang/Elixir (Fedora/RHEL)..."
      as_root dnf install -y erlang elixir
      ;;
    yum)
      log "Menginstall Erlang/Elixir (CentOS)..."
      as_root yum install -y erlang elixir
      ;;
    zypper)
      log "Menginstall Erlang/Elixir (openSUSE)..."
      as_root zypper --non-interactive install erlang elixir
      ;;
    *)
      err "Tidak ada metode instalasi untuk package manager: $PKG_MGR"
      ;;
  esac
}

# ---------- Verifikasi ----------
verify_elixir() {
  log "Verifikasi instalasi:"
  elixir --version
}

# ---------- Main ----------
main() {
  detect_pkg_mgr
  install_elixir
  verify_elixir
  log "Instalasi Elixir selesai 🎉. Jalankan: elixir --version"
}

main "$@"
