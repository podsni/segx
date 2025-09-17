# scrix-beta

Manajer skrip interaktif untuk mengelola koleksi shell script dari satu terminal.

## Fitur
- Navigasi kategori skrip dengan antarmuka interaktif yang rapi (powered by `@clack/prompts`).
- Mode pemilihan ganda dengan ingatan pilihan sebelumnya.
- Mode acak untuk mengeksekusi skrip secara cepat.
- Ringkasan eksekusi lengkap berikut informasi akses sudo.

## Prasyarat
- [Bun](https://bun.com) v1.2.22 atau lebih baru.
- Shell Unix dengan akses ke perintah `bash` dan (opsional) `sudo` untuk skrip yang memerlukannya.

## Instalasi
Pasang seluruh dependensi:

```bash
bun install
```

## Konfigurasi Opsional
- `MY_SCRIPT_DIR`: direktori instalasi skrip (default `./script`).
- `MY_SCRIPT_REPO_URL`: URL repositori untuk ditampilkan di header.

Contoh menjalankan CLI dengan variabel lingkungan khusus:

```bash
MY_SCRIPT_DIR=/opt/scripts \
MY_SCRIPT_REPO_URL=https://github.com/user/scripts \
bun run index.ts
```

## Cara Menggunakan
1. Jalankan aplikasi:
   ```bash
   bun run index.ts
   ```
2. Pilih kategori atau mode (Semua, Random, Skrip Root, atau kategori tertentu).
3. Gunakan menu multiselect untuk memilih skrip (bisa pilih ulang kapan saja).
4. Konfirmasi aksi: jalankan sekarang, pilih ulang, kembali ke kategori, atau keluar.
5. Ikuti ringkasan eksekusi untuk melihat hasil, durasi, dan status setiap skrip.

Setelah selesai, Anda dapat menjalankan ulang aplikasi kapan saja untuk mengelola skrip lainnya.

---

Proyek ini dibuat menggunakan `bun init` pada Bun v1.2.22.
