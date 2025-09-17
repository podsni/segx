## VPS Hardening (Debian/Ubuntu)

Skrip ini mengamankan server Debian/Ubuntu dengan langkah baseline yang aman, non-interaktif, dan idempotent.

### Fitur
- Deteksi OS (Debian/Ubuntu + apt)
- Update & upgrade + aktifkan unattended-upgrades (reboot otomatis 03:30)
- UFW: default deny incoming; allow OpenSSH + 80/tcp + 443/tcp
- SSH hardening: PermitRootLogin no, MaxAuthTries 4, X11Forwarding no, auto nonaktif PasswordAuthentication bila ada authorized_keys
- Fail2ban (jail sshd, banaction=ufw)
- Sysctl hardening konservatif
- NTP via systemd-timesyncd
- Verifikasi akhir + audit

### Prasyarat
- Akses sudo/root ke server
- Kunci SSH sudah diunggah ke user Anda (`~/.ssh/authorized_keys`) agar login password bisa dimatikan dengan aman (skrip akan cek otomatis; jika tidak ada, password login dibiarkan aktif agar tidak lockout)

### Audit (opsional, rekomendasi)
Jalankan audit keamanan read-only:

```bash
bash /home/hades/vm-test/vps-sec-check.sh --all --no-color | cat
```

### Eksekusi hardening

```bash
chmod +x /home/hades/vm-test/harden-server.sh
sudo /home/hades/vm-test/harden-server.sh
```

Skrip ini aman untuk dijalankan berulang kali (idempotent).

### Verifikasi cepat
- UFW:
  ```bash
  sudo ufw status verbose | cat
  ```
- Fail2ban (semua jail dan sshd):
  ```bash
  sudo fail2ban-client status | cat
  sudo fail2ban-client status sshd | cat
  ```
- Audit ulang:
  ```bash
  bash /home/hades/vm-test/vps-sec-check.sh --all --no-color | cat
  ```

### Kustomisasi umum
- Buka port tambahan (contoh 5432 dan 8080):
  ```bash
  sudo ufw allow 5432/tcp
  sudo ufw allow 8080/tcp
  ```
- Atur kebijakan Fail2ban (durasi ban, dll) di `/etc/fail2ban/jail.local`:
  ```ini
  [sshd]
  enabled = true
  port = ssh
  filter = sshd
  maxretry = 5
  findtime = 10m
  bantime = 1h
  banaction = ufw
  ```
  Terapkan ulang: `sudo fail2ban-client reload`
- Jadwal & reboot unattended-upgrades di `/etc/apt/apt.conf.d/20auto-upgrades`:
  ```
  APT::Periodic::Update-Package-Lists "1";
  APT::Periodic::Unattended-Upgrade "1";
  Unattended-Upgrade::Automatic-Reboot "true";
  Unattended-Upgrade::Automatic-Reboot-Time "03:30";
  ```

### Rollback cepat
- SSH config dibackup saat skrip jalan, contoh:
  - `/etc/ssh/sshd_config.YYYY-MM-DD-HHMMSS.bak`
  Untuk mengembalikan:
  ```bash
  sudo cp -a /etc/ssh/sshd_config.YYYY-MM-DD-HHMMSS.bak /etc/ssh/sshd_config
  sudo systemctl restart ssh || sudo systemctl restart sshd
  ```
- UFW dapat dinonaktifkan sementara:
  ```bash
  sudo ufw disable
  ```

### Catatan
- Pada Ubuntu, nama unit layanan biasanya `ssh` (bukan `sshd`). Skrip sudah menangani hal ini otomatis.
- Skrip akan mematikan password login hanya jika ditemukan kunci SSH agar Anda tidak terkunci dari server.
- Beberapa layanan mungkin restart saat upgrade; ini normal.

### Diagnostik berguna
- Port yang listen: `ss -tulpen | cat`
- Log Fail2ban: `sudo tail -n 200 /var/log/fail2ban.log`
- Status layanan: `systemctl status <svc> | cat`
- Log layanan: `sudo journalctl -u <svc> -n 100 --no-pager | cat`



