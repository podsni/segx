# VPS Security Menu (Ubuntu/Debian)

Skrip antarmuka interaktif untuk audit dan hardening VPS Anda. Menggabungkan audit, baseline hardening, konfigurasi SSH/OTP, firewall (UFW), dan Fail2ban dalam satu menu yang mudah dipakai.

## Lokasi skrip
- Menu utama: `/home/hades/vm-test/vps-securty.sh`
- Komponen:
  - Audit keamanan: `/home/hades/vm-test/vps-sec-check.sh`
  - Cek VPS (CPU/Disk/Net): `/home/hades/vm-test/vps-check.sh`
  - Hardening baseline: `/home/hades/vm-test/harden-server.sh`
  - Wizard SSH/OTP: `/home/hades/vm-test/ssh-config.sh`

## Fitur
- Audit keamanan read-only (tidak mengubah sistem)
- Cek kapabilitas (CPU, Disk I/O, Network, Ports)
- Hardening baseline (unattended-upgrades, UFW, SSH hardening, Fail2ban, sysctl)
- Wizard SSH: tambah kunci publik, port, OTP (TOTP) optional/required
- Toggle password login (on/off) secara aman (via drop-in `sshd_config.d`)
- UFW: buka port dan cek status
- Fail2ban: cek status global dan jail `sshd`
- Ringkasan konfigurasi SSH efektif (sshd -T)

## Prasyarat
- Akses `sudo`/root
- Disarankan: sudah menambahkan minimal satu kunci SSH ke user Anda (`~/.ssh/authorized_keys`)

## Cara menjalankan
```bash
chmod +x /home/hades/vm-test/vps-securty.sh
bash /home/hades/vm-test/vps-securty.sh
```
Ikuti menu pada layar. Semua aksi yang dimodifikasi akan meminta konfirmasi.

## Menu dan aksi
- Audit keamanan (read-only): menjalankan `vps-sec-check.sh --all` dan menampilkan temuan (UFW, SSH, sysctl, auth log, dll.)
- Cek VPS (CPU/Disk/Net): informasi sistem, benchmark singkat, ping, traceroute/speedtest (bila ada), dan konektivitas port umum
- Baseline hardening (otomatis):
  - Update & aktifkan `unattended-upgrades` (reboot otomatis 03:30 bila perlu)
  - UFW: default deny incoming; allow `OpenSSH` + `80,443/tcp`
  - SSH hardening: `PermitRootLogin no`, `MaxAuthTries 4`, `X11Forwarding no`, matikan password bila kunci terdeteksi
  - Fail2ban: jail `sshd` aktif + banaction UFW
  - Sysctl konservatif: matikan `send_redirects`, aktifkan `rp_filter`, tolak IPv6 RA di server
- Wizard SSH/OTP:
  - Tampilkan kunci yang ada (authorized_keys*) untuk semua user
  - Tambahkan kunci dari clipboard/file `.pub`
  - Ubah port (opsional) dan buka di UFW (opsional)
  - OTP (TOTP):
    - optional: login bisa kunci saja ATAU kunci+OTP; password tetap dimatikan
    - required: wajib kunci+OTP
  - Manager OTP terpisah dengan QR: `/home/hades/vm-test/aktif-otp.sh` (menu interaktif)
- Toggle password login:
  - off (disarankan): password dimatikan via drop-in `sshd_config.d/99-vibeops-auth.conf`
  - on (darurat): password diizinkan kembali
- UFW: buka port sesuai kebutuhan (mis. `5432/tcp`, `8080/tcp`)
- Fail2ban: status global dan jail `sshd`
- SSH: ringkasan konfigurasi efektif (hasil `sshd -T`)

## Perintah langsung (tanpa menu)
- Ringkasan SSH:
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh --summary
  ```
- Matikan password + OTP optional:
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh --otp optional --password off
  ```
- Aktifkan password (darurat):
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh --otp off --password on
  ```
- Tambah kunci dari file `.pub`:
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh --user hades --pubkey-file /home/hades/.ssh/my-server.pub
  ```

### OTP manager (QR/URI)
- Menu interaktif OTP/QR:
  ```bash
  bash /home/hades/vm-test/aktif-otp.sh --interactive
  ```
- OTP required:
  ```bash
  sudo bash /home/hades/vm-test/aktif-otp.sh --mode required
  ```
- OTP optional + generate untuk user hades + tampilkan QR:
  ```bash
  sudo bash /home/hades/vm-test/aktif-otp.sh --mode optional --user hades --show-qr hades
  ```
- Matikan OTP:
  ```bash
  sudo bash /home/hades/vm-test/aktif-otp.sh --mode off
  ```

### MFA profile (sesuai panduan)
Profil MFA ini menyiapkan SSH agar meminta faktor tambahan (OTP) selain kunci/pasword sesuai konfigurasi.

- Terapkan profil MFA (komentari `@include common-auth`, aktifkan PAM OTP, set metode auth SSH):
  ```bash
  bash /home/hades/vm-test/aktif-otp.sh --interactive   # pilih 7) Terapkan MFA profile
  ```
  Atau non-interaktif:
  ```bash
  sudo bash /home/hades/vm-test/aktif-otp.sh --mode optional --user hades --show-qr hades
  # lalu masih di menu, pilih 7) untuk menegakkan profil MFA
  ```

- Nonaktifkan profil MFA (kembalikan default, hapus pam_google_authenticator dari PAM, longgarkan AuthenticationMethods):
  ```bash
  bash /home/hades/vm-test/aktif-otp.sh --interactive   # pilih 8) Nonaktifkan MFA profile
  ```

- Contoh login:
  - Kunci + OTP (disarankan):
    ```bash
    ssh -o PreferredAuthentications=publickey,keyboard-interactive user@host
    ```
  - Password + OTP (opsional, jika PasswordAuthentication diaktifkan):
    ```bash
    ssh -o PreferredAuthentications=password,keyboard-interactive user@host
    ```

## Rollback cepat
- SSH config backup: `/etc/ssh/sshd_config.YYYY-MM-DD-HHMMSS.bak`
- Drop-in kebijakan auth: `/etc/ssh/sshd_config.d/99-vibeops-auth.conf`
- Kembalikan atau nonaktifkan drop-in, lalu restart SSH:
  ```bash
  sudo mv /etc/ssh/sshd_config.d/99-vibeops-auth.conf /etc/ssh/sshd_config.d/99-vibeops-auth.conf.disabled
  sudo systemctl restart ssh || sudo systemctl restart sshd
  ```

## Troubleshooting
- Tidak bisa login setelah perubahan SSH: jangan tutup sesi aktif sebelum uji login baru berhasil.
- `PasswordAuthentication` masih terbaca `yes`:
  - Jalankan: `sudo sshd -T | egrep '^(passwordauthentication|authenticationmethods|kbdinteractiveauthentication)'`
  - Pastikan drop-in `99-vibeops-auth.conf` ada dan memuat `PasswordAuthentication no`
- OTP tidak diminta pada mode required:
  - Pastikan `AuthenticationMethods publickey,keyboard-interactive:pam` dan `KbdInteractiveAuthentication yes`
- UFW belum aktif:
  - Jalankan: `sudo ufw enable`; status: `sudo ufw status verbose`

## Catatan keamanan
- Password login meningkatkan risiko; gunakan `--password off` + kunci SSH + OTP optional/required.
- Aktifkan rate-limit UFW untuk `OpenSSH` (menu wizard akan menawarkan ini) untuk mengurangi brute-force.


