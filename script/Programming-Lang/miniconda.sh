#!/bin/bash

# Cek apakah Miniconda sudah terinstall
if command -v conda &>/dev/null; then
	echo "Miniconda sudah terinstall. Instalasi dibatalkan."
	exit 0
fi

# URL Miniconda
miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"

# Nama file untuk penyimpanan
installer_script="Miniconda3-latest-Linux-x86_64.sh"

# Unduh skrip instalasi Miniconda
wget "$miniconda_url" -O "$installer_script"

# Berikan izin eksekusi pada skrip
chmod +x "$installer_script"

# Jalankan instalasi secara interaktif
./"$installer_script"

# Hapus skrip instalasi setelah selesai
rm "$installer_script"