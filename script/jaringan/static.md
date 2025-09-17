## Utilities: set-static-ip.sh & set-hostname.sh

Dokumentasi singkat untuk dua utilitas yang tersedia:
- `set-static-ip.sh`: Mengatur IP statis lintas distro Linux (Netplan, NetworkManager/nmcli, ifupdown, systemd-networkd) + menampilkan info jaringan saat ini.
- `set-hostname.sh`: Mengatur hostname (static/pretty) dan memperbarui pemetaan di `/etc/hosts` secara aman.

Catatan umum
- Jalankan perintah dengan `sudo` saat menerapkan perubahan (apply). Mode `-s` (show) dan `-D` (dry run) tidak membutuhkan root.
- Menerapkan perubahan jaringan saat terhubung via SSH dapat memutus koneksi. Gunakan `-D` terlebih dahulu untuk memastikan konfigurasi benar sebelum apply.

---

### set-static-ip.sh

Fitur
- Deteksi metode konfigurasi jaringan otomatis: netplan / nmcli / ifupdown / systemd-networkd.
- Tampilkan informasi jaringan saat ini (`-s`).
- Isi otomatis nilai yang tidak diberikan dari konfigurasi aktif (IP/CIDR, gateway, DNS, interface default).
- Dry-run (`-D`) untuk melihat rencana perubahan tanpa menerapkan.
- Membuat backup file konfigurasi terkait sebelum mengubah.

Penggunaan
- Tampilkan bantuan:
  - `./set-static-ip.sh -h`
- Tampilkan info jaringan saat ini (auto-detect interface default):
  - `./set-static-ip.sh -s`
- Dry-run (gunakan nilai dari jaringan aktif untuk `eth0`):
  - `./set-static-ip.sh -i eth0 -D`
- Terapkan IP statis (contoh):
  - `sudo ./set-static-ip.sh -i eth0 -a 192.168.1.10/24 -g 192.168.1.1 -d "1.1.1.1,8.8.8.8"`

Opsi
- `-i IFACE`: Nama interface, mis. `eth0`, `enp0s3`. Jika tidak diisi, script mencoba memilih dari default route.
- `-a IP/CIDR`: IP dengan CIDR, mis. `192.168.1.10/24`.
- `-g GATEWAY`: Gateway IPv4, mis. `192.168.1.1`.
- `-d DNS1,DNS2`: Daftar DNS (pisahkan dengan koma atau spasi). Jika tidak diisi, diambil dari sistem saat ini.
- `-m METHOD`: `auto` (default) atau salah satu `netplan|nmcli|ifupdown|systemd-networkd`.
- `-s`: Hanya tampilkan info jaringan dan keluar.
- `-D`: Dry-run; tampilkan rencana konfigurasi, tidak menerapkan.

Contoh tambahan
- Paksa pakai Netplan:
  - `sudo ./set-static-ip.sh -i ens160 -a 10.0.0.10/24 -g 10.0.0.1 -d 9.9.9.9 -m netplan`
- Paksa pakai NetworkManager (nmcli):
  - `sudo ./set-static-ip.sh -i enp3s0 -a 172.16.1.20/24 -g 172.16.1.1 -d "1.1.1.1,8.8.8.8" -m nmcli`

Informasi yang ditampilkan oleh `-s`
- Interface, state (UP/DOWN), IPv4/CIDR, Gateway, DNS, MAC address, dan metode konfigurasi yang terdeteksi.

Catatan metode
- Netplan: file dibuat/diubah di `/etc/netplan/99-static-<iface>.yaml`, kemudian `netplan apply`.
- NetworkManager (nmcli): koneksi profil baru bernama `static-<iface>` (atau gunakan yang sudah terkait interface), lalu koneksi di-restart.
- ifupdown: menambahkan stanza statis ke `/etc/network/interfaces`, lalu `ifdown`/`ifup` interface.
- systemd-networkd: membuat file `/etc/systemd/network/<iface>-static.network`, lalu restart service.

Troubleshooting cepat
- Lihat daftar interface: `ip -brief link show`
- Lihat route default: `ip route | grep default`
- Lihat IP dan CIDR interface: `ip -4 -o addr show dev <iface>`
- Cek DNS yang aktif (systemd-resolved): `resolvectl status`
- Cek koneksi nmcli: `nmcli connection show`

---

### set-hostname.sh

Fitur
- Mengatur hostname melalui `hostnamectl` (jika tersedia), atau fallback edit `/etc/hostname` + panggil `hostname`.
- Memperbarui `/etc/hosts` dalam blok yang dikelola (managed block) dengan backup otomatis.
- Validasi hostname sesuai RFC-1123.

Penggunaan
- Set FQDN langsung:
  - `sudo ./set-hostname.sh -n server1.example.local`
- Set short hostname + domain, sertakan pretty hostname dan IP mapping khusus:
  - `sudo ./set-hostname.sh -n server1 -d example.local -p "Server One" -I 192.168.1.10`

Opsi
- `-n HOSTNAME`: Hostname baru (short atau FQDN).
- `-d DOMAIN`: Domain untuk membentuk FQDN jika `-n` adalah short hostname.
- `-p PRETTY`: Pretty hostname (bebas spasi, ditampilkan oleh `hostnamectl`).
- `-I IP`: IP untuk pemetaan di `/etc/hosts` (default: `127.0.1.1` pada Debian-like, selain itu `127.0.0.1`).
- `-m METHOD`: `auto` (default), `hostnamectl`, atau `etc` (tulis file langsung).
- `-h`: Tampilkan bantuan.

Catatan
- Blok yang dikelola di `/etc/hosts` ditandai dengan:
  - `# set-hostname.sh managed block start` … `# set-hostname.sh managed block end`
- Jalankan dengan `sudo` untuk menerapkan perubahan.
