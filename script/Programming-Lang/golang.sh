#!/bin/bash

# ==============================================================================
# Skrip Instalasi Go (Golang) - Versi Final Otomatis
#
# Perbaikan v3: Membersihkan karakter kutip dari deteksi versi untuk
#               memastikan nama file unduhan selalu benar.
# ==============================================================================

# 1. Cek hak akses dan minta sudo jika perlu (Logika Otomatis)
if [ "$(id -u)" -ne 0 ]; then
    echo "Skrip ini memerlukan hak akses root (sudo) untuk instalasi."
    echo "Mencoba menjalankan ulang skrip dengan sudo..."
    sudo bash "$0" "$@"
    exit $?
fi

# Mulai dari sini, skrip sudah pasti berjalan dengan hak akses root (sudo)
echo "✅ Hak akses Sudo diterima. Memulai proses instalasi..."
echo ""

# Hentikan eksekusi jika ada perintah yang gagal
set -e

# 2. Cek dependensi yang dibutuhkan (wget atau curl)
echo " Mengecek dependensi (wget atau curl)..."
DOWNLOADER=""
if command -v wget &> /dev/null; then
    DOWNLOADER="wget"
elif command -v curl &> /dev/null; then
    DOWNLOADER="curl"
else
    echo "❌ Error: 'wget' atau 'curl' tidak ditemukan."
    echo "   Silakan install salah satunya. Contoh di Debian/Ubuntu:"
    echo "   sudo apt update && sudo apt install wget"
    exit 1
fi
echo "✅ Siap mengunduh menggunakan '${DOWNLOADER}'."
echo ""

# 3. Dapatkan versi Go terbaru & arsitektur sistem
echo " Mencari versi Go terbaru..."
LATEST_GO_VERSION=$(curl -s "https://go.dev/dl/?mode=json" | grep -oP '"version":\s*"go\K[0-9]+\.[0-9]+(\.[0-9]+)?"' | head -n 1)

# --- PERBAIKAN UTAMA ADA DI SINI ---
# Membersihkan karakter kutip (") yang mungkin terbawa dari perintah di atas
LATEST_GO_VERSION=${LATEST_GO_VERSION//\"/}
# --- AKHIR PERBAIKAN ---

if [ -z "$LATEST_GO_VERSION" ]; then
    echo "❌ Gagal mendapatkan versi Go terbaru. Periksa koneksi internet Anda."
    exit 1
fi
echo "✅ Versi Go terbaru yang ditemukan: ${LATEST_GO_VERSION}"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) GO_ARCH="amd64" ;;
    i686|i386) GO_ARCH="386" ;;
    aarch64) GO_ARCH="arm64" ;;
    *)
        echo "❌ Arsitektur sistem tidak didukung: ${ARCH}"
        exit 1
        ;;
esac
echo "✅ Arsitektur sistem Anda: ${GO_ARCH}"
echo ""

# 4. Proses Unduh dan Instalasi
GO_FILENAME="go${LATEST_GO_VERSION}.linux-${GO_ARCH}.tar.gz"
DOWNLOAD_URL="https://dl.google.com/go/${GO_FILENAME}"

echo "⏬ Mengunduh ${GO_FILENAME}..."
if [ "$DOWNLOADER" = "wget" ]; then
    wget -q --show-progress -O "${GO_FILENAME}" "${DOWNLOAD_URL}"
else # Menggunakan curl
    curl -L --progress-bar -o "${GO_FILENAME}" "${DOWNLOAD_URL}"
fi
echo "✅ Unduhan selesai."
echo ""

echo " Membersihkan instalasi Go lama di /usr/local/go (jika ada)..."
rm -rf /usr/local/go
echo "✅ Direktori lama dibersihkan."
echo ""

echo " Mengekstrak file ke /usr/local..."
tar -C /usr/local -xzf "${GO_FILENAME}"
echo "✅ Ekstraksi selesai."
echo ""

echo "️ Menghapus file arsip yang sudah diunduh..."
rm "${GO_FILENAME}"
echo "✅ File arsip dihapus."
echo ""

# 5. Atur variabel lingkungan (PATH)
REAL_USER=$(logname 2>/dev/null || echo ${SUDO_USER:-${USER}})
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SHELL_PROFILE=""

if [ -f "$USER_HOME/.zshrc" ]; then
    SHELL_PROFILE="$USER_HOME/.zshrc"
elif [ -f "$USER_HOME/.bashrc" ]; then
    SHELL_PROFILE="$USER_HOME/.bashrc"
fi

if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
    echo " Mengkonfigurasi PATH di ${SHELL_PROFILE}"
    sed -i '/# Tambahkan Go ke PATH/d' "$SHELL_PROFILE"
    sed -i '/export PATH=\$PATH:\/usr\/local\/go\/bin/d' "$SHELL_PROFILE"
    echo '' >> "$SHELL_PROFILE"
    echo '# Tambahkan Go ke PATH' >> "$SHELL_PROFILE"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$SHELL_PROFILE"
    chown "$REAL_USER":"$REAL_USER" "$SHELL_PROFILE"
else
    SHELL_PROFILE="/etc/profile.d/go.sh"
    echo 'export PATH=$PATH:/usr/local/go/bin' > "$SHELL_PROFILE"
    echo " Mengkonfigurasi PATH untuk semua pengguna di ${SHELL_PROFILE}"
fi

# 6. Tampilkan pesan akhir
echo "================================================================"
echo "   SELAMAT! INSTALASI GO BERHASIL TERSIMPAN!            "
echo "================================================================"
echo ""
echo "Verifikasi Versi Go:"
/usr/local/go/bin/go version
echo ""
echo "⚠️  TINDAKAN DIPERLUKAN:"
echo "   Untuk mulai menggunakan Go, muat ulang shell Anda dengan:"
echo "   1. Menutup dan membuka kembali terminal, ATAU"
echo "   2. Menjalankan perintah yang sesuai di bawah ini:"
if [[ "$SHELL_PROFILE" == *".zshrc"* ]]; then
    echo "      source $USER_HOME/.zshrc"
elif [[ "$SHELL_PROFILE" == *".bashrc"* ]]; then
    echo "      source $USER_HOME/.bashrc"
else
    echo "      (Silakan logout dan login kembali untuk menerapkan perubahan sistem)"
fi
echo "================================================================"
