#!/usr/bin/env bash
# Installer OCaml + OPAM untuk Linux
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

# ---------- Install deps ----------
install_deps() {
  log "Menginstall dependency dasar..."
  case "$PKG_MGR" in
    pacman) as_root pacman -Sy --noconfirm curl m4 git unzip ;;
    apt) as_root apt-get update -y && as_root apt-get install -y curl m4 git unzip bubblewrap ;;
    dnf) as_root dnf install -y curl m4 git unzip ;;
    yum) as_root yum install -y curl m4 git unzip ;;
    zypper) as_root zypper --non-interactive install curl m4 git unzip ;;
    apk) as_root apk add --no-cache curl m4 git unzip ;;
  esac
}

# ---------- Install opam ----------
install_opam() {
  if need_cmd opam; then
    log "opam sudah terpasang."
    return
  fi
  log "Menginstall opam..."
  case "$PKG_MGR" in
    pacman) as_root pacman -Sy --noconfirm opam ;;
    apt) as_root apt-get install -y opam ;;
    dnf) as_root dnf install -y opam ;;
    yum) as_root yum install -y opam ;;
    zypper) as_root zypper --non-interactive install opam ;;
    apk) 
      log "Membangun opam dari script resmi..."
      sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)
      ;;
  esac
}

# ---------- Init & Install OCaml ----------
install_ocaml() {
  if [ ! -d "$HOME/.opam" ]; then
    log "Inisialisasi opam..."
    opam init -y --disable-sandboxing
  fi

  log "Memasang OCaml stable terbaru..."
  opam switch create default ocaml-base-compiler.latest || true

  eval "$(opam env)"
}

# ---------- Setup PATH ----------
setup_path() {
  if ! grep -qs 'opam env' "$HOME/.bashrc" 2>/dev/null; then
    echo 'eval "$(opam env)"' >> "$HOME/.bashrc"
  fi
}

# ---------- Verifikasi ----------
verify_ocaml() {
  log "Verifikasi instalasi:"
  ocaml -version
  opam --version
}

# ---------- Main ----------
main() {
  detect_pkg_mgr
  install_deps
  install_opam
  install_ocaml
  setup_path
  verify_ocaml
  log "Instalasi OCaml selesai 🎉. Jalankan: ocaml -version"
}

main "$@"
