#!/usr/bin/env bash
set -euo pipefail

# Konfigurasi dapat dioverride via variabel lingkungan (contoh: SEG_PACKAGE_NAME=my-cli)
PACKAGE_NAME="${SEG_PACKAGE_NAME:-seg}"
BUN_FALLBACK_PACKAGE="${SEG_BUN_FALLBACK:-seg-bin}"
BREW_FORMULA="${SEG_BREW_FORMULA:-sst/tap/seg}"
POST_INSTALL_NOTE="${SEG_POST_INSTALL_NOTE:-Selesai! Jalankan 'seg' dari terminal kapan saja.}"

info() {
  printf '\033[1;34m[info]\033[0m %s\n' "$1"
}

error() {
  printf '\033[1;31m[error]\033[0m %s\n' "$1" >&2
}

install_with_bun() {
  if ! command -v bun >/dev/null 2>&1; then
    return 1
  fi

  info "Mendeteksi Bun. Menginstal ${PACKAGE_NAME} secara global..."
  if bun install -g "${PACKAGE_NAME}"; then
    return 0
  fi

  info "Instalasi ${PACKAGE_NAME} gagal. Mencoba paket fallback ${BUN_FALLBACK_PACKAGE}..."
  bun install -g "${BUN_FALLBACK_PACKAGE}"
}

install_with_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    return 1
  fi

  info "Mendeteksi npm. Menginstal ${PACKAGE_NAME} secara global..."
  npm install -g "${PACKAGE_NAME}"
}

install_with_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi

  info "Mendeteksi Homebrew. Menginstal ${PACKAGE_NAME} dari ${BREW_FORMULA}..."
  brew install "${BREW_FORMULA}"
}

main() {
  if install_with_bun; then
    info "${POST_INSTALL_NOTE}"
    exit 0
  fi

  if install_with_npm; then
    info "${POST_INSTALL_NOTE}"
    exit 0
  fi

  if install_with_brew; then
    info "${POST_INSTALL_NOTE}"
    exit 0
  fi

  error "Gagal menemukan bun, npm, atau brew. Silakan instal salah satu package manager tersebut terlebih dahulu."
  exit 1
}

main "$@"
