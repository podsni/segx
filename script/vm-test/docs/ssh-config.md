# SSH Hardening + OTP (TOTP)

Skrip: `/home/hades/vm-test/ssh-config.sh`

## Fitur
- Backup otomatis `sshd_config`
- Hardening: `PermitRootLogin no`, `MaxAuthTries 4`, `X11Forwarding no`, `PubkeyAuthentication yes`
- Nonaktifkan password login (aman; optional paksa)
- Ganti port SSH (opsional) + update UFW (opsional)
- Tampilkan kunci publik yang sudah ada per user
- Tambah kunci publik untuk user tertentu (set ownership & permissions benar)
- OTP (TOTP) via `libpam-google-authenticator`:
  - `--otp optional`: OTP tidak wajib (nullok), kompatibel dengan login kunci saja
  - `--otp required`: OTP wajib bersama kunci (AuthenticationMethods publickey,keyboard-interactive:pam)

## Cara pakai
- Mode interaktif (wizard):
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh --interactive
  ```
- Tampilkan kunci yang sudah ada:
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh --list-keys
  ```
- Tambah kunci + port + UFW + OTP optional:
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh \
    --user hades \
    --pubkey "ssh-ed25519 AAAA..." \
    --port 2222 \
    --allow-ufw \
    --otp optional
  ```
- Nonaktif password secara paksa (hanya jika yakin kunci berfungsi):
  ```bash
  sudo bash /home/hades/vm-test/ssh-config.sh --force
  ```

## Catatan OTP
- Untuk `--otp required`, login membutuhkan kunci + kode TOTP.
- Untuk `--otp optional`, Anda bisa login dengan kunci saja ATAU kunci + TOTP; password tetap dimatikan.
- Wizard dapat mengenerate secret untuk user (file `~/.google_authenticator`). Scan di aplikasi Authenticator.

## Rollback
- File backup: `/etc/ssh/sshd_config.YYYY-MM-DD-HHMMSS.bak`
- Kembalikan:
  ```bash
  sudo cp -a /etc/ssh/sshd_config.YYYY-MM-DD-HHMMSS.bak /etc/ssh/sshd_config
  sudo systemctl restart ssh || sudo systemctl restart sshd
  ```
  Jika butuh, nonaktifkan drop-in policy dan restart:
  ```bash
  sudo mv /etc/ssh/sshd_config.d/00-vibeops-auth.conf /etc/ssh/sshd_config.d/00-vibeops-auth.conf.disabled
  sudo systemctl restart ssh || sudo systemctl restart sshd
  ```


