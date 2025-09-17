#!/usr/bin/env bash
set -euo pipefail

# Set static IPv4 for common Linux network stacks, with discovery helpers:
# - netplan (Ubuntu 18.04+)
# - NetworkManager (nmcli)
# - ifupdown (/etc/network/interfaces)
# - systemd-networkd
#
# Usage:
#   ./set-static-ip.sh -i eth0 -a 192.168.1.10/24 -g 192.168.1.1 -d "1.1.1.1,8.8.8.8" [-m auto|netplan|nmcli|ifupdown|systemd-networkd]
#   ./set-static-ip.sh -s                  # show current network info (auto-detect iface)
#   ./set-static-ip.sh -i eth0 -D          # dry-run: show planned changes using current values
#
# Notes:
# - Requires root to apply changes (not needed for -s or -D)
# - IP must be CIDR (e.g., 192.168.1.10/24)
# - Will back up modified files

print_help() {
  cat <<'EOF'
Usage:
  set-static-ip.sh -i IFACE -a IP/CIDR -g GATEWAY -d "DNS1,DNS2" [-m METHOD]

Options:
  -i   Interface name (e.g., eth0, enp0s3)
  -a   IPv4 with CIDR (e.g., 192.168.1.10/24)
  -g   Gateway IPv4 (e.g., 192.168.1.1)
  -d   DNS servers comma or space separated (e.g., "1.1.1.1,8.8.8.8")
  -m   Method: auto (default), netplan, nmcli, ifupdown, systemd-networkd
  -s   Show current network info and exit
  -D   Dry-run: compute and print planned config, do not apply
  -h   Help

Examples:
  set-static-ip.sh -i eth0 -a 192.168.10.20/24 -g 192.168.10.1 -d "1.1.1.1,8.8.8.8"
  set-static-ip.sh -i enp0s3 -a 10.0.0.10/24 -g 10.0.0.1 -d "9.9.9.9" -m netplan
  set-static-ip.sh -s
  set-static-ip.sh -i eth0 -D
EOF
}

require_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Error: must run as root" >&2
    exit 1
  fi
}

timestamp() { date +"%Y%m%d-%H%M%S"; }
backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp -a -- "$f" "${f}.bak.$(timestamp)"
  fi
}

# Normalize DNS list to space separated
normalize_dns() {
  local raw="$1"
  if [[ -z "$raw" ]]; then echo ""; return; fi
  echo "$raw" | tr ',' ' ' | xargs
}

cidr_to_netmask() {
  local cidr="$1"
  local bits=$(( 0xffffffff ^ ((1 << (32 - cidr)) - 1) ))
  printf "%d.%d.%d.%d" $(( (bits>>24)&255 )) $(( (bits>>16)&255 )) $(( (bits>>8)&255 )) $(( bits&255 ))
}

# ---- Detection helpers ----
get_default_iface() {
  ip route show default 0.0.0.0/0 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

get_iface_ipv4_cidr() {
  local dev="$1"
  ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4}' | head -n1
}

get_iface_gateway() {
  local dev="$1"
  local gw
  gw="$(ip route show default dev "$dev" 2>/dev/null | awk '/default/ {print $3; exit}')"
  if [[ -z "$gw" ]]; then
    gw="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"
  fi
  echo "$gw"
}

get_dns_from_resolvectl() {
  local dev="$1"
  if command -v resolvectl >/dev/null 2>&1; then
    local out
    out="$(resolvectl dns "$dev" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      echo "$out" | awk -F': ' 'NF>1 {print $2}'
      return
    fi
    resolvectl status 2>/dev/null | awk '/DNS Servers:/ {for(i=3;i<=NF;i++) printf("%s ", $i); print ""; exit}'
  fi
}

get_dns_from_resolv_conf() {
  if [[ -r /etc/resolv.conf ]]; then
    awk '/^nameserver / {print $2}' /etc/resolv.conf | xargs
  fi
}

get_current_dns() {
  local dev="$1"
  local dns
  dns="$(get_dns_from_resolvectl "$dev" | xargs || true)"
  if [[ -z "$dns" ]]; then
    dns="$(get_dns_from_resolv_conf | xargs || true)"
  fi
  echo "$dns"
}

# ---- Method detection and apply helpers ----
detect_method() {
  if [[ "$method" != "auto" ]]; then
    echo "$method"
    return
  fi
  if command -v netplan >/dev/null 2>&1 && [[ -d /etc/netplan ]]; then
    echo "netplan"; return
  fi
  if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager.service; then
    echo "nmcli"; return
  fi
  if [[ -f /etc/network/interfaces ]]; then
    echo "ifupdown"; return
  fi
  if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-networkd\.service'; then
    echo "systemd-networkd"; return
  fi
  if command -v nmcli >/dev/null 2>&1; then echo "nmcli"; return; fi
  if command -v netplan >/dev/null 2>&1; then echo "netplan"; return; fi
  echo "systemd-networkd"
}

apply_netplan() {
  local file="/etc/netplan/99-static-${iface}.yaml"
  mkdir -p /etc/netplan
  backup_file "$file"
  cat > "$file" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${iface}:
      dhcp4: false
      addresses:
        - ${ip_cidr}
      routes:
        - to: 0.0.0.0/0
          via: ${gateway}
$( if [[ -n "$dns_list" ]]; then
     echo "      nameservers:"
     echo "        addresses:"
     for d in $dns_list; do
       echo "          - ${d}"
     done
   fi )
EOF
  netplan generate
  netplan apply
}

apply_nmcli() {
  local conn_name=""
  while IFS= read -r name; do
    local ifn
    ifn="$(nmcli -g connection.interface-name connection show "$name" 2>/dev/null || true)"
    if [[ "$ifn" == "$iface" ]]; then conn_name="$name"; break; fi
  done < <(nmcli -g NAME connection show)

  if [[ -z "$conn_name" ]]; then
    conn_name="static-${iface}"
    nmcli connection add type ethernet ifname "$iface" con-name "$conn_name" ipv4.method manual
  fi

  nmcli connection modify "$conn_name" \
    ipv4.method manual \
    ipv4.addresses "${ip_cidr}" \
    ipv4.gateway "${gateway}" \
    ipv6.method ignore \
    autoconnect yes

  if [[ -n "$dns_list" ]]; then
    nmcli connection modify "$conn_name" ipv4.dns "$(echo "$dns_list" | tr ' ' ',')" ipv4.ignore-auto-dns yes
  else
    nmcli connection modify "$conn_name" -ipv4.dns ipv4.ignore-auto-dns yes
  fi

  nmcli connection down "$conn_name" || true
  nmcli connection up "$conn_name"
}

apply_ifupdown() {
  local file="/etc/network/interfaces"
  backup_file "$file"

  if grep -qE "^[[:space:]]*iface[[:space:]]+${iface}[[:space:]]+inet[[:space:]]+" "$file"; then
    sed -i.bak.$(timestamp) -E "s/^([[:space:]]*iface[[:space:]]+${iface}[[:space:]]+inet[[:space:]]+.*)$/# \1/" "$file" || true
    sed -i -E "s/^([[:space:]]*(address|netmask|gateway|dns-nameservers).*)$/# \1/" "$file" || true
  fi

  {
    echo ""
    echo "# static config added $(timestamp)"
    echo "auto ${iface}"
    echo "iface ${iface} inet static"
    echo "    address ${ip_addr}"
    echo "    netmask ${netmask}"
    echo "    gateway ${gateway}"
    if [[ -n "$dns_list" ]]; then
      echo "    dns-nameservers ${dns_list}"
    fi
  } >> "$file"

  ifdown "$iface" 2>/dev/null || true
  ifup "$iface"
}

apply_systemd_networkd() {
  mkdir -p /etc/systemd/network
  local file="/etc/systemd/network/${iface}-static.network"
  backup_file "$file"
  {
    echo "[Match]"
    echo "Name=${iface}"
    echo ""
    echo "[Network]"
    echo "Address=${ip_cidr}"
    echo "Gateway=${gateway}"
    if [[ -n "$dns_list" ]]; then
      for d in $dns_list; do echo "DNS=${d}"; done
    fi
  } > "$file"
  systemctl enable systemd-networkd.service >/dev/null 2>&1 || true
  systemctl restart systemd-networkd.service
}

# ---- Args ----
iface=""
ip_cidr=""
gateway=""
dns_raw=""
method="auto"
show_only=false
dry_run=false

while getopts ":i:a:g:d:m:sDh" opt; do
  case "$opt" in
    i) iface="$OPTARG" ;;
    a) ip_cidr="$OPTARG" ;;
    g) gateway="$OPTARG" ;;
    d) dns_raw="$OPTARG" ;;
    m) method="$OPTARG" ;;
    s) show_only=true ;;
    D) dry_run=true ;;
    h) print_help; exit 0 ;;
    \?) echo "Invalid option -$OPTARG" >&2; print_help; exit 2 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; print_help; exit 2 ;;
  esac
done

# Auto-select interface if not provided
if [[ -z "$iface" ]]; then
  iface="$(get_default_iface || true)"
fi

if [[ -z "$iface" ]]; then
  echo "Error: interface not specified and could not auto-detect default interface." >&2
  echo "Hint: pass -i IFACE. Available interfaces:" >&2
  ip -brief link show || true
  exit 2
fi

if ! ip link show "$iface" >/dev/null 2>&1; then
  echo "Error: interface '$iface' not found." >&2
  ip -brief link show || true
  exit 1
fi

# Derive current values from system when missing
current_ip_cidr="$(get_iface_ipv4_cidr "$iface" || true)"
current_gateway="$(get_iface_gateway "$iface" || true)"
current_dns="$(get_current_dns "$iface" || true)"

if [[ -z "$ip_cidr" && -n "$current_ip_cidr" ]]; then ip_cidr="$current_ip_cidr"; fi
if [[ -z "$gateway" && -n "$current_gateway" ]]; then gateway="$current_gateway"; fi

dns_list="$(normalize_dns "${dns_raw:-}")"
if [[ -z "$dns_list" && -n "$current_dns" ]]; then dns_list="$current_dns"; fi

# Show-only mode
if [[ "$show_only" == true ]]; then
  chosen_show="$(detect_method)"
  mac_addr=""
  if [[ -r "/sys/class/net/${iface}/address" ]]; then
    mac_addr="$(cat "/sys/class/net/${iface}/address" 2>/dev/null || true)"
  fi
  echo "Interface : $iface"
  echo "State     : $(cat /sys/class/net/${iface}/operstate 2>/dev/null || echo unknown)"
  echo "IPv4/CIDR : ${ip_cidr:-none}"
  echo "Gateway   : ${gateway:-none}"
  echo "DNS       : ${dns_list:-none}"
  echo "MAC       : ${mac_addr:-unknown}"
  echo "Method    : ${chosen_show}"
  exit 0
fi

# Ensure we have required values after inference
if [[ -z "$ip_cidr" || -z "$gateway" ]]; then
  echo "Error: missing -a or -g and could not infer from current network." >&2
  echo "Got: iface=$iface, ip_cidr='${ip_cidr:-}', gateway='${gateway:-}'" >&2
  exit 2
fi

# Validate formats
if [[ ! "$ip_cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]]; then
  echo "Error: -a must be IPv4/CIDR, e.g., 192.168.1.10/24" >&2
  exit 2
fi
if [[ ! "$gateway" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Error: -g must be IPv4, e.g., 192.168.1.1" >&2
  exit 2
fi

ip_addr="${ip_cidr%/*}"
prefix="${ip_cidr#*/}"
netmask="$(cidr_to_netmask "$prefix")"

chosen="$(detect_method)"
echo "Using method: ${chosen}"

# Dry-run mode
if [[ "$dry_run" == true ]]; then
  echo "Planned configuration:"
  echo "  Interface : $iface"
  echo "  IPv4/CIDR : $ip_cidr"
  echo "  Netmask   : $netmask (/${prefix})"
  echo "  Gateway   : $gateway"
  echo "  DNS       : ${dns_list:-none}"
  echo "  Method    : $chosen"
  exit 0
fi

# Apply requires root
require_root

case "$chosen" in
  netplan) apply_netplan ;;
  nmcli) apply_nmcli ;;
  ifupdown) apply_ifupdown ;;
  systemd-networkd) apply_systemd_networkd ;;
  *) echo "Unknown method '${chosen}'"; exit 1 ;;

esac

echo "Static IP configured on ${iface} -> ${ip_cidr}, gateway ${gateway}${dns_list:+, DNS: ${dns_list}}"