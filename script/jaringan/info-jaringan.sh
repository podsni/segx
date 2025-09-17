#!/usr/bin/env bash
set -euo pipefail

# Ringkasan info jaringan komprehensif: IPv4/IPv6, gateway, DNS, status link,
# MAC, MTU, kecepatan/SSID, dan uji konektivitas. Tanpa root.
#
# Opsi:
#   -i IFACE   Fokus pada interface tertentu
#   -a         Tampilkan detail semua interface
#   -j         Output JSON ringkas (tanpa warna)
#   -h         Bantuan

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'

trim() { sed -e 's/^\s\+//' -e 's/\s\+$//'; }

default_iface() {
  ip route show default 0.0.0.0/0 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

all_ifaces() {
  ip -brief link show 2>/dev/null | awk '{print $1}' | grep -v '^lo$' || true
}

iface_operstate() {
  local ifn="$1"
  cat "/sys/class/net/${ifn}/operstate" 2>/dev/null || echo unknown
}

iface_mac() {
  local ifn="$1"
  cat "/sys/class/net/${ifn}/address" 2>/dev/null || echo "?"
}

iface_mtu() {
  local ifn="$1"
  cat "/sys/class/net/${ifn}/mtu" 2>/dev/null || echo "?"
}

iface_speed_or_ssid() {
  local ifn="$1"
  if command -v ethtool >/dev/null 2>&1; then
    if out=$(ethtool "$ifn" 2>/dev/null | awk -F': ' '/Speed:/{print $2; exit}'); then
      [[ -n "$out" ]] && { echo "$out"; return; }
    fi
  fi
  # SSID (wifi)
  if command -v iw >/dev/null 2>&1; then
    if ssid=$(iw dev "$ifn" info 2>/dev/null | awk -F': ' '/ssid/{print $2; exit}'); then
      [[ -n "$ssid" ]] && { echo "SSID: $ssid"; return; }
    fi
  fi
  if command -v iwconfig >/dev/null 2>&1; then
    if ssid=$(iwconfig "$ifn" 2>/dev/null | awk -F'ESSID:"' '/ESSID/{split($2,a,"\""); print a[1]; exit}'); then
      [[ -n "$ssid" ]] && { echo "SSID: $ssid"; return; }
    fi
  fi
  echo "-"
}

iface_ipv4_list() {
  local ifn="$1"
  ip -o -4 addr show dev "$ifn" 2>/dev/null | awk '{print $4}' || true
}

iface_ipv6_list() {
  local ifn="$1"
  ip -o -6 addr show dev "$ifn" 2>/dev/null | awk '{print $4}' || true
}

iface_gateway() {
  local ifn="$1"
  local gw
  gw=$(ip route show default dev "$ifn" 2>/dev/null | awk '/default/ {print $3; exit}')
  if [[ -z "$gw" ]]; then
    gw=$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')
  fi
  echo "$gw"
}

dns_from_resolvectl() {
  local ifn="$1"
  if command -v resolvectl >/dev/null 2>&1; then
    local out
    out=$(resolvectl dns "$ifn" 2>/dev/null || true)
    if [[ -n "$out" ]]; then
      echo "$out" | awk -F': ' 'NF>1 {print $2}'
      return
    fi
    resolvectl status 2>/dev/null | awk '/DNS Servers:/ {for(i=3;i<=NF;i++) printf("%s ", $i); print ""; exit}'
  fi
}

dns_from_resolv_conf() {
  if [[ -r /etc/resolv.conf ]]; then
    awk '/^nameserver / {print $2}' /etc/resolv.conf | xargs
  fi
}

iface_dns() {
  local ifn="$1"; local dns
  dns="$(dns_from_resolvectl "$ifn" 2>/dev/null | xargs || true)"
  if [[ -z "$dns" ]]; then dns="$(dns_from_resolv_conf | xargs || true)"; fi
  echo "$dns"
}

public_ip_v4() {
  local eps=(
    "https://api.ipify.org"
    "https://ipv4.icanhazip.com"
    "https://ifconfig.me/ip"
  )
  if command -v curl >/dev/null 2>&1; then
    local ip
    for u in "${eps[@]}"; do
      if ip=$(curl -4 -fsS --max-time 4 "$u" 2>/dev/null | tr -d '\r' | trim); then
        [[ -n "$ip" ]] && { echo "$ip"; return 0; }
      fi
    done
  fi
  if command -v dig >/dev/null 2>&1; then
    if ip=$(dig +short -4 myip.opendns.com @resolver1.opendns.com 2>/dev/null | head -n1 | trim); then
      [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    fi
  fi
  echo ""
}

public_ip_v6() {
  local eps=(
    "https://api6.ipify.org"
    "https://ipv6.icanhazip.com"
  )
  if command -v curl >/dev/null 2>&1; then
    local ip
    for u in "${eps[@]}"; do
      if ip=$(curl -6 -fsS --max-time 4 "$u" 2>/dev/null | tr -d '\r' | trim); then
        [[ -n "$ip" ]] && { echo "$ip"; return 0; }
      fi
    done
  fi
  echo ""
}

test_ping() {
  local target="$1"; shift
  ping -c1 -W1 "$target" >/dev/null 2>&1 && echo ok || echo fail
}

json_escape() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

print_iface_block() {
  local ifn="$1"
  local state mac mtu spd dns gw v4 v6
  state="$(iface_operstate "$ifn")"
  mac="$(iface_mac "$ifn")"
  mtu="$(iface_mtu "$ifn")"
  spd="$(iface_speed_or_ssid "$ifn")"
  dns="$(iface_dns "$ifn")"
  gw="$(iface_gateway "$ifn")"
  v4="$(iface_ipv4_list "$ifn" | xargs)"
  v6="$(iface_ipv6_list "$ifn" | xargs)"

  printf "${C_BOLD}%s${C_RESET}  state=%s  mtu=%s  mac=%s\n" "$ifn" "$state" "$mtu" "$mac"
  [[ -n "$v4" ]] && printf "  IPv4: %s\n" "$v4" || printf "  IPv4: -\n"
  [[ -n "$v6" ]] && printf "  IPv6: %s\n" "$v6" || printf "  IPv6: -\n"
  printf "  GW  : %s\n" "${gw:--}"
  printf "  DNS : %s\n" "${dns:--}"
  printf "  Link: %s\n" "$spd"
}

print_iface_block_json() {
  local ifn="$1"
  local state mac mtu spd dns gw v4 v6
  state="$(iface_operstate "$ifn")"
  mac="$(iface_mac "$ifn")"
  mtu="$(iface_mtu "$ifn")"
  spd="$(iface_speed_or_ssid "$ifn")"
  dns="$(iface_dns "$ifn")"
  gw="$(iface_gateway "$ifn")"
  v4="$(iface_ipv4_list "$ifn" | tr '\n' ' ' | xargs)"
  v6="$(iface_ipv6_list "$ifn" | tr '\n' ' ' | xargs)"
  printf '{"iface":"%s","state":"%s","mtu":"%s","mac":"%s","ipv4":"%s","ipv6":"%s","gw":"%s","dns":"%s","link":"%s"}' \
    "$(echo "$ifn" | json_escape)" "$(echo "$state" | json_escape)" "$(echo "$mtu" | json_escape)" \
    "$(echo "$mac" | json_escape)" "$(echo "$v4" | json_escape)" "$(echo "$v6" | json_escape)" \
    "$(echo "${gw:-}" | json_escape)" "$(echo "${dns:-}" | json_escape)" "$(echo "$spd" | json_escape)"
}

print_help() {
  cat <<'EOF'
Usage:
  info-jaringan.sh [-i IFACE] [-a] [-j]

Options:
  -i IFACE  Show details for specific interface
  -a        Show all interfaces
  -j        JSON output
  -h        Help
EOF
}

main() {
  local sel_iface="" show_all=false json=false
  while getopts ":i:ajh" opt; do
    case "$opt" in
      i) sel_iface="$OPTARG" ;;
      a) show_all=true ;;
      j) json=true ;;
      h) print_help; exit 0 ;;
      \?) print_help; exit 2 ;;
    esac
  done

  local def ifaces
  def="$(default_iface || true)"
  mapfile -t ifaces < <(all_ifaces)

  if [[ -z "$sel_iface" && "$show_all" != true ]]; then
    sel_iface="$def"
  fi

  local pub4 pub6
  pub4="$(public_ip_v4 || true)"
  pub6="$(public_ip_v6 || true)"

  if [[ "$json" == true ]]; then
    # JSON output
    printf '{'
    printf '"public_ipv4":"%s","public_ipv6":"%s"' "$(echo "$pub4" | json_escape)" "$(echo "$pub6" | json_escape)"
    printf ',"interfaces":['
    local first=true
    if [[ "$show_all" == true ]]; then
      for ifn in "${ifaces[@]}"; do
        [[ "$first" == true ]] || printf ','; first=false
        print_iface_block_json "$ifn"
      done
    else
      if [[ -n "$sel_iface" ]]; then print_iface_block_json "$sel_iface"; fi
    fi
    printf ']}'
    echo
    exit 0
  fi

  # Pretty output
  printf "${C_BOLD}${C_BLUE}===== Info Jaringan =====${C_RESET}\n"
  if [[ -n "$pub4" || -n "$pub6" ]]; then
    printf "Publik IPv4: %s\n" "${pub4:--}"
    printf "Publik IPv6: %s\n" "${pub6:--}"
  fi

  if [[ "$show_all" == true ]]; then
    for ifn in "${ifaces[@]}"; do
      echo
      print_iface_block "$ifn"
    done
  else
    if [[ -n "$sel_iface" ]]; then
      print_iface_block "$sel_iface"
    else
      printf "Tidak ada interface terdeteksi.\n"
    fi
  fi

  # Uji konektivitas dasar
  local test_gw test_ip test_dns domain
  domain="example.com"
  if [[ -n "$sel_iface" ]]; then
    gw="$(iface_gateway "$sel_iface")"
  fi
  test_gw=$(test_ping "${gw:-127.0.0.1}" || true)
  test_ip=$(test_ping "1.1.1.1" || true)
  if command -v getent >/dev/null 2>&1; then
    # Hanya tes DNS resolve
    if getent hosts "$domain" >/dev/null 2>&1; then test_dns=ok; else test_dns=fail; fi
  else
    test_dns="-"
  fi
  echo
  printf "${C_BOLD}Connectivity:${C_RESET} GW=%s ICMP=%s DNS=%s\n" "${test_gw}" "${test_ip}" "${test_dns}"
}

main "$@"