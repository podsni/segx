# SSH MFA (TOTP)

## Ringkas
- Generate OTP + QR untuk user Anda, lalu aktifkan MFA (pubkey + OTP):
  ```bash
  sudo bash /home/hades/vm-test/aktif-otp.sh --mode required --user hades --show-qr hades
  ```
- Login (akan diminta kode OTP):
  ```bash
  ssh -o PreferredAuthentications=publickey,keyboard-interactive hades@HOST
  ```

## Penjelasan
- OTP berbasis TOTP (Google Authenticator kompatibel, bisa pakai aplikasi bebas/open-source).
- Sistem meminta faktor kedua via PAM (keyboard-interactive) setelah kunci SSH diverifikasi.
- Recovery codes tersimpan di `~/.google_authenticator` saat pertama kali generate.

## Opsi lain
- Password + OTP (tidak disarankan, tapi didukung):
  - Terapkan profil MFA (menu): `bash /home/hades/vm-test/aktif-otp.sh --interactive` → 7)
  - Login: `ssh -o PreferredAuthentications=password,keyboard-interactive user@HOST`

## Perintah berguna
- Status OTP & SSH:
  ```bash
  sudo bash /home/hades/vm-test/aktif-otp.sh --status
  ```
- Tampilkan ulang QR & kode OTP saat ini:
  ```bash
  sudo bash /home/hades/vm-test/aktif-otp.sh --show-qr hades
  ```
- Nonaktifkan MFA:
  ```bash
  bash /home/hades/vm-test/aktif-otp.sh --interactive  # pilih 8)
  ```

## Catatan
- Uji login di terminal baru sebelum menutup sesi aktif untuk mencegah lockout.
- Jika SSH agent/desktop men-cache passphrase, Anda mungkin hanya diminta OTP saja.


