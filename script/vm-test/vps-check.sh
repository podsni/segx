#!/usr/bin/env bash
# vps-check.sh — sederhana dan aman untuk tes VPS
# Penggunaan:
#   bash vps-check.sh --all
#   bash vps-check.sh --sys --cpu --disk --net --ports
# Opsi:
#   --all | -a        : Jalankan semua tes
#   --sys             : Info sistem
#   --cpu             : Benchmark CPU (gunakan sysbench jika ada)
#   --disk            : Tes disk I/O (dd)
#   --net             : Tes jaringan (IP publik, ping, download via curl, speedtest jika ada)
#   --ports           : Cek konektivitas keluar port umum
#   --size=MB         : Ukuran file tes disk (default 256)
#   --install         : Coba install utilitas opsional (sysbench, speedtest-cli, traceroute) jika tidak ada
#   --no-color        : Nonaktifkan warna
#   --help | -h       : Bantuan

COLOR=1
for arg in "$@"; do [[ "$arg" == "--no-color" ]] && COLOR=0; done
if [[ $COLOR -eq 1 ]]; then
  BOLD="\033[1m"; DIM="\033[2m"; RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; NC="\033[0m"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; NC=""
fi

header() { echo -e "${BOLD}$1${NC}"; }
info()   { echo -e "${CYAN}$1${NC}"; }
ok()     { echo -e "${GREEN}$1${NC}"; }
warn()   { echo -e "${YELLOW}$1${NC}"; }
err()    { echo -e "${RED}$1${NC}" 1>&2; }

HAS() { command -v "$1" >/dev/null 2>&1; }

ALLOW_INSTALL=0
DISK_SIZE_MB=256
DO_SYS=0; DO_CPU=0; DO_DISK=0; DO_NET=0; DO_PORTS=0; RUN_ALL=0

if [[ $# -eq 0 ]]; then RUN_ALL=1; fi

for arg in "$@"; do
  case "$arg" in
    --all|-a) RUN_ALL=1 ;;
    --sys) DO_SYS=1 ;;
    --cpu) DO_CPU=1 ;;
    --disk) DO_DISK=1 ;;
    --net) DO_NET=1 ;;
    --ports) DO_PORTS=1 ;;
    --install) ALLOW_INSTALL=1 ;;
    --size=*) DISK_SIZE_MB="${arg#*=}";;
    --help|-h)
      sed -n '2,50p' "$0"; exit 0;;
    --no-color) ;; # handled earlier
    *) warn "Opsi tidak dikenal: $arg";;
  esac
done

if [[ $RUN_ALL -eq 1 ]]; then DO_SYS=1; DO_CPU=1; DO_DISK=1; DO_NET=1; DO_PORTS=1; fi

detect_pkg() {
  if HAS apt-get; then echo "apt"; return; fi
  if HAS dnf; then echo "dnf"; return; fi
  if HAS yum; then echo "yum"; return; fi
  if HAS pacman; then echo "pacman"; return; fi
  echo ""
}

ensure_pkg() {
  local name="$1"; local aptname="${2:-$1}"
  if HAS "$name"; then return 0; fi
  [[ $ALLOW_INSTALL -eq 0 ]] && return 1
  local mgr; mgr=$(detect_pkg)
  [[ -z "$mgr" ]] && return 1
  info "Menginstall $aptname (butuh sudo) ..."
  case "$mgr" in
    apt) sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$aptname" ;;
    dnf) sudo dnf install -y "$aptname" ;;
    yum) sudo yum install -y "$aptname" ;;
    pacman) sudo pacman -Sy --noconfirm "$aptname" ;;
  esac
  HAS "$name"
}

hr() { echo -e "${DIM}----------------------------------------------------------------${NC}"; }

sys_info() {
  header "[1] Info Sistem"
  hr
  echo "Tanggal        : $(date -Is)"
  echo "Uptime         : $(uptime -p 2>/dev/null || true)"
  echo "Kernel         : $(uname -r)"
  echo "Arsitektur     : $(uname -m)"
  echo "Hostname       : $(hostname)"
  if HAS hostnamectl; then echo "OS             : $(hostnamectl 2>/dev/null | sed -n 's/.*Operating System: //p')"; fi
  if HAS systemd-detect-virt; then echo "Virtualisasi   : $(systemd-detect-virt 2>/dev/null || echo 'unknown')"; fi
  if HAS lscpu; then echo "CPU            : $(lscpu | sed -n 's/^Model name:\\s*//p' | head -1)"; fi
  echo "vCPU           : $(nproc 2>/dev/null || echo '?')"
  echo "Memori         :"; free -h || true
  echo "Disk           :"; df -hT --total | sed 's/^/  /'
  if HAS lsblk; then echo "Block Devices  :"; lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINTS | sed 's/^/  /'; fi
  hr
}

cpu_bench() {
  header "[2] Benchmark CPU"
  hr
  if HAS sysbench || ensure_pkg sysbench; then
    local threads seconds
    threads=$(nproc)
    seconds=10
    info "Menjalankan sysbench CPU ${seconds}s dengan ${threads} thread..."
    sysbench cpu --threads="$threads" --time="$seconds" run | sed 's/^/  /'
  else
    warn "sysbench tidak tersedia. Jalankan dengan --install untuk memasang."
  fi
  hr
}

disk_io() {
  header "[3] Tes Disk I/O (dd)"
  hr
  local tmpfile count
  count="$DISK_SIZE_MB"
  tmpfile="$(mktemp /tmp/vps_io.XXXXXX)"
  info "Menulis ${DISK_SIZE_MB} MB ke $tmpfile ..."
  dd if=/dev/zero of="$tmpfile" bs=1M count="$count" conv=fdatasync status=progress 2>&1 | tail -1
  info "Membaca kembali ${DISK_SIZE_MB} MB ..."
  dd if="$tmpfile" of=/dev/null bs=1M status=progress 2>&1 | tail -1
  rm -f "$tmpfile"
  hr
}

net_tests() {
  header "[4] Tes Jaringan"
  hr
  echo "IP Publik v4   : $(curl -4 -s --max-time 5 https://ifconfig.co 2>/dev/null || echo '-')"
  echo "IP Publik v6   : $(curl -6 -s --max-time 5 https://ifconfig.co 2>/dev/null || echo '-')"
  echo
  info "Ping (ICMP) ke 1.1.1.1 dan 8.8.8.8 (4 paket)..."
  if HAS ping; then
    ping -c 4 -W 2 1.1.1.1 | sed 's/^/  /'
    ping -c 4 -W 2 8.8.8.8 | sed 's/^/  /'
  else
    warn "ping tidak tersedia."
  fi
  echo
  if HAS traceroute || ensure_pkg traceroute; then
    info "Traceroute singkat (maks 10 hop) ke 1.1.1.1..."
    traceroute -m 10 -q 1 1.1.1.1 | sed 's/^/  /'
  else
    warn "traceroute tidak tersedia."
  fi
  echo
  if HAS speedtest || HAS speedtest-cli || ensure_pkg speedtest-cli; then
    local stbin
    stbin="$(command -v speedtest || command -v speedtest-cli)"
    info "Speedtest (server otomatis)..."
    "$stbin" --secure --accept-license --accept-gdpr 2>/dev/null | sed 's/^/  /'
  else
    warn "speedtest-cli tidak tersedia. Pakai --install atau lihat tes unduh curl di bawah."
  fi
  echo
  info "Tes unduh via curl (ke beberapa region, 100MB file):"
  local urls=(
    "https://speed.hetzner.de/100MB.bin"
    "https://mirror.sg.gs/100MB.bin"
    "https://speedtest.tele2.net/100MB.zip"
    "https://cachefly.cachefly.net/100mb.test"
  )
  for u in "${urls[@]}"; do
    printf "%s\n" "  URL: $u"
    # keluarkan ke /dev/null, tampilkan kecepatan rata-rata MB/s dan waktu
    curl -L --fail --silent --output /dev/null --write-out "    Kecepatan: %{speed_download} B/s  Waktu: %{time_total}s  Resolusi IP: %{remote_ip}\n" "$u" \
      | awk '{
        bytes=$3; time=$6; ip=$9;
        mbs=(bytes/1048576);
        printf "    Kecepatan: %.2f MB/s (%.2f Mbps) | Waktu: %s s | IP: %s\n", mbs, mbs*8, time, ip
      }' || printf "    Gagal mengunduh.\n"
  done
  hr
}

port_checks() {
  header "[5] Cek Port Keluar"
  hr
  # gunakan bash /dev/tcp dengan timeout
  check_port() {
    local host="$1" port="$2" label="$3"
    timeout 3 bash -c ">/dev/tcp/$host/$port" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      ok "  OK  - $label ($host:$port) dapat dijangkau"
    else
      warn "  FAIL- $label ($host:$port) tidak bisa dijangkau"
    fi
  }
  check_port 1.1.1.1 53  "DNS (UDP/TCP 53) — TCP check"
  check_port 8.8.8.8 53  "DNS (UDP/TCP 53) — TCP check"
  check_port google.com 80  "HTTP 80"
  check_port google.com 443 "HTTPS 443"
  check_port github.com 443 "GitHub 443"
  check_port ssh.github.com 443 "SSH over 443"
  check_port github.com 22  "SSH 22"
  hr
}

main() {
  [[ $DO_SYS -eq 1 ]] && sys_info
  [[ $DO_CPU -eq 1 ]] && cpu_bench
  [[ $DO_DISK -eq 1 ]] && disk_io
  [[ $DO_NET -eq 1 ]] && net_tests
  [[ $DO_PORTS -eq 1 ]] && port_checks
  info "Selesai."
}

main