# seg

Seg adalah CLI interaktif untuk menavigasi, memilih, dan menjalankan sekumpulan shell script dengan pengalaman yang rapi dan cepat. Tool ini dibangun di atas Bun dan TypeScript, tetapi dapat dijalankan dari mana saja setelah dipaketkan ke npm.

## Instalasi Cepat

Pilih salah satu metode distribusi berikut (semuanya menyiapkan perintah global `seg`):

```bash
# npm
npm install -g seg

# Bun (paket utama)
bun install -g seg

# Bun (opsi fallback binary)
bun install -g seg-bin

# Homebrew (formula kustom)
brew install sst/tap/seg

# Skrip curl (repositori resmi podsni/seg)
curl -fsSL https://raw.githubusercontent.com/podsni/seg/main/install.sh | bash
```

> Pastikan token publikasi npm (`NPM_TOKEN`) sudah dipasang di GitHub Secret agar workflow rilis dapat mem-publish ke registry.

## Pengembangan Lokal

```bash
# Instal seluruh dependensi
bun install

# Jalankan CLI dalam mode pengembangan
bun run dev

# Bangun paket untuk distribusi
bun run build

# Pemeriksaan tipe (opsional)
bun run check
```

## Variabel Lingkungan
- `MY_SCRIPT_DIR`: ganti lokasi direktori script (default `./script`).
- `MY_SCRIPT_REPO_URL`: URL repositori yang ditampilkan pada header antarmuka (default `https://github.com/podsni/seg`).
- `SEG_PACKAGE_NAME`, `SEG_BUN_FALLBACK`, `SEG_BREW_FORMULA`, `SEG_POST_INSTALL_NOTE`: override dinamis untuk skrip `install.sh` bila Anda melakukan fork/clone dan ingin mengganti identitas paket tanpa mengedit file.

Contoh menjalankan CLI dengan konfigurasi khusus:

```bash
MY_SCRIPT_DIR=/opt/scripts \
MY_SCRIPT_REPO_URL=https://github.com/podsni/seg \
bun run dev
```

## Arsitektur Singkat
- `src/cli.ts`: titik masuk utama yang mengatur alur CLI.
- `src/ui.ts`: interaksi terminal berbasis `@clack/prompts`.
- `src/script-manager.ts`: logika pemindaian skrip (termasuk dukungan sub-folder).
- `install.sh`: skrip instalasi universal untuk penggunaan via `curl | bash`.

## Rilis Otomatis

Repositori ini menyertakan workflow GitHub Actions (`.github/workflows/release.yml`) yang akan:

- Menginstal dependensi dengan Bun.
- Membangun paket menggunakan `tsup`.
- Mem-publish ke npm (`npm publish --provenance --access public`).

Workflow dipicu saat rilis GitHub dipublikasikan atau dijalankan secara manual (`workflow_dispatch`). Jangan lupa menambahkan secret `NPM_TOKEN` dengan hak publish ke registry npm Anda.

Selamat menggunakan Seg! 🎉
