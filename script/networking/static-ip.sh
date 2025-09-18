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
#   ./set-static-ip.sh -L                  # list stored templates
#   ./set-static-ip.sh -T kantor -D        # dry-run using template 'kantor'
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
  -T   Load template by name (prefill values)
  -W   Save current values as template name
  -L   List stored templates
  -R   Remove stored template by name
  -E   Edit template using \$EDITOR/\$VISUAL (creates if missing)
  -h   Help

Examples:
  set-static-ip.sh -i eth0 -a 192.168.10.20/24 -g 192.168.10.1 -d "1.1.1.1,8.8.8.8"
  set-static-ip.sh -i enp0s3 -a 10.0.0.10/24 -g 10.0.0.1 -d "9.9.9.9" -m netplan
  set-static-ip.sh -T kantor -i eth0 -D   # load template, override iface, dry run
  set-static-ip.sh -W kantor               # start wizard, then save as template 'kantor'
  set-static-ip.sh -s
  set-static-ip.sh -i eth0 -D

Interactive:
  If mandatory flags are omitted and you're in a TTY, a guided wizard will start
  to choose interface, fill IP/CIDR, gateway, DNS, and method; then confirm.
EOF
}

require_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Error: must run as root" >&2
    exit 1
  fi
}

ensure_root_or_reexec() {
  if [[ ${EUID} -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      echo "Error: must run as root (sudo not available)" >&2
      exit 1
    fi
    echo "Elevating privileges with sudo..."
    argv=("-i" "$iface" "-a" "$ip_cidr" "-g" "$gateway")
    if [[ -n "${dns_list:-}" ]]; then
      argv+=("-d" "$(printf '%s' "$dns_list" | tr ' ' ',' | xargs)")
    fi
    if [[ -n "${method:-}" ]]; then
      argv+=("-m" "$method")
    fi
    exec sudo -E bash "$0" "${argv[@]}"
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

get_templates_dir() {
  local base=""
  if [[ ${EUID} -eq 0 && -n "${SUDO_USER:-}" ]]; then
    local sudo_home=""
    if command -v getent >/dev/null 2>&1; then
      sudo_home="$(getent passwd "$SUDO_USER" 2>/dev/null | awk -F: '{print $6}' | head -n1 || true)"
    fi
    if [[ -z "$sudo_home" ]]; then
      sudo_home="/home/${SUDO_USER}"
    fi
    base="${XDG_CONFIG_HOME:-${sudo_home}/.config}"
  else
    base="${XDG_CONFIG_HOME:-${HOME}/.config}"
  fi
  printf '%s\n' "${base}/set-static-ip/templates"
}

ensure_templates_dir() {
  local dir
  dir="$(get_templates_dir)"
  mkdir -p -- "$dir"
  printf '%s\n' "$dir"
}

template_file_path() {
  local name="$1"
  local dir
  dir="$(get_templates_dir)"
  printf '%s/%s.conf\n' "$dir" "$name"
}

save_template() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: template name cannot be empty." >&2
    exit 2
  fi
  if [[ -z "${iface:-}" || -z "${ip_cidr:-}" || -z "${gateway:-}" ]]; then
    echo "Error: cannot save template '$name' without iface, IP/CIDR, and gateway." >&2
    exit 2
  fi
  local dir file dns_store
  dir="$(ensure_templates_dir)"
  file="${dir}/${name}.conf"
  dns_store="$(echo "${dns_list:-}" | tr ' ' ',' | xargs)"
  {
    echo "# set-static-ip template"
    echo "iface=${iface}"
    echo "ip_cidr=${ip_cidr}"
    echo "gateway=${gateway}"
    echo "dns=${dns_store}"
    echo "method=${method:-auto}"
  } > "$file"
  echo "Template '$name' saved at $file"
}

delete_template() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: template name cannot be empty." >&2
    exit 2
  fi
  local file
  file="$(template_file_path "$name")"
  if [[ ! -f "$file" ]]; then
    echo "Template '$name' not found (searched: $file)" >&2
    exit 2
  fi
  rm -f -- "$file"
  echo "Template '$name' removed."
}

list_templates() {
  local dir
  dir="$(get_templates_dir)"
  if [[ ! -d "$dir" ]]; then
    echo "No templates stored yet. Use -W NAME after configuring to save one."
    return
  fi
  shopt -s nullglob
  local entries=("$dir"/*.conf)
  shopt -u nullglob
  if (( ${#entries[@]} == 0 )); then
    echo "No templates stored yet. Use -W NAME after configuring to save one."
    return
  fi
  echo "Templates stored under $dir:"
  local file name iface_val ip_val
  for file in "${entries[@]}"; do
    name="$(basename "$file" .conf)"
    iface_val="$(awk -F'=' '$1=="iface" {print $2}' "$file" 2>/dev/null | head -n1)"
    ip_val="$(awk -F'=' '$1=="ip_cidr" {print $2}' "$file" 2>/dev/null | head -n1)"
    echo "  - ${name} (iface=${iface_val:-?}, ip=${ip_val:-?})"
  done
}

edit_template() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: template name cannot be empty." >&2
    exit 2
  fi
  local dir file editor candidate
  dir="$(ensure_templates_dir)"
  file="${dir}/${name}.conf"
  if [[ ! -f "$file" ]]; then
    {
      echo "# set-static-ip template"
      echo "iface="
      echo "ip_cidr="
      echo "gateway="
      echo "dns="
      echo "method=auto"
    } > "$file"
  fi
  editor="${VISUAL:-${EDITOR:-}}"
  if [[ -z "$editor" ]]; then
    for candidate in nano vim vi; do
      if command -v "$candidate" >/dev/null 2>&1; then
        editor="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$editor" ]]; then
    echo "No editor found. Set \$EDITOR or \$VISUAL, or edit $file manually." >&2
    exit 2
  fi
  "$editor" "$file"
  echo "Template '$name' edited at $file"
}

load_template() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: template name cannot be empty." >&2
    exit 2
  fi
  local file template_iface="" template_ip="" template_gateway="" template_dns="" template_method=""
  file="$(template_file_path "$name")"
  if [[ ! -f "$file" ]]; then
    echo "Template '$name' not found (searched: $file)" >&2
    exit 2
  fi
  while IFS='=' read -r key value; do
    key="$(printf '%s' "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    value="$(printf '%s' "${value%%$'\r'}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$key" in
      ''|'#'*) continue ;;
      iface) template_iface="$value" ;;
      ip_cidr) template_ip="$value" ;;
      gateway) template_gateway="$value" ;;
      dns) template_dns="$value" ;;
      method) template_method="$value" ;;
    esac
  done < "$file"

  if [[ "$iface_arg_set" != true && -n "$template_iface" ]]; then iface="$template_iface"; fi
  if [[ "$ip_arg_set" != true && -n "$template_ip" ]]; then ip_cidr="$template_ip"; fi
  if [[ "$gateway_arg_set" != true && -n "$template_gateway" ]]; then gateway="$template_gateway"; fi
  if [[ "$dns_arg_set" != true && -n "$template_dns" ]]; then dns_raw="$template_dns"; fi
  if [[ "$method_arg_set" != true && -n "$template_method" ]]; then method="$template_method"; fi

  echo "Loaded template '$name'."
}

cidr_to_netmask() {
  local cidr="$1"
  local bits=$(( 0xffffffff ^ ((1 << (32 - cidr)) - 1) ))
  printf "%d.%d.%d.%d" $(( (bits>>24)&255 )) $(( (bits>>16)&255 )) $(( (bits>>8)&255 )) $(( bits&255 ))
}

# ---- Detection helpers ----
get_first_non_loop_iface() {
  ip -brief link show 2>/dev/null | awk '$1!="lo" {sub(/@.*/, "", $1); print $1; exit}'
}

get_default_iface() {
  local via
  via="$(ip route show default 0.0.0.0/0 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
  if [[ -n "$via" ]]; then
    echo "$via"
    return
  fi
  via="$(ip -brief link show up 2>/dev/null | awk '$1!="lo" {sub(/@.*/, "", $1); print $1; exit}' || true)"
  if [[ -n "$via" ]]; then
    echo "$via"
    return
  fi
  get_first_non_loop_iface || true
}

get_iface_ipv4_cidr() {
  local dev="$1"
  ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4}' | head -n1
}

get_primary_src_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
}

suggest_ipv4_cidr_for_iface() {
  local dev="$1"
  local cidr
  cidr="$(get_iface_ipv4_cidr "$dev" || true)"
  if [[ -n "$cidr" ]]; then echo "$cidr"; return; fi
  local src
  src="$(get_primary_src_ip || true)"
  if [[ -n "$src" ]]; then
    # Fallback guess: /24
    echo "${src}/24"; return
  fi
  echo ""
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

# ---- Interactive helpers ----
is_tty() { [[ -t 0 && -t 1 ]]; }

prompt_default() {
  local prompt="$1"; shift
  local default_val="${1:-}"; shift || true
  local var
  if [[ -n "$default_val" ]]; then
    read -rp "$prompt [$default_val]: " var
    echo "${var:-$default_val}"
  else
    read -rp "$prompt: " var
    echo "$var"
  fi
}

choose_interface_interactive() {
  local candidates=()
  local states=()
  while IFS= read -r line; do
    # Format: <ifname> <state> <rest>
    local ifn state
    ifn="$(awk '{print $1}' <<<"$line")"
    ifn="${ifn%@*}"
    state="$(awk '{print $2}' <<<"$line")"
    if [[ "$ifn" == "lo" ]]; then continue; fi
    candidates+=("$ifn"); states+=("$state")
  done < <(ip -brief link show 2>/dev/null)

  local def
  def="$(get_default_iface || true)"
  echo "Available interfaces:"
  local i
  for i in "${!candidates[@]}"; do
    printf "  %2d) %-15s (%s)\n" "$((i+1))" "${candidates[$i]}" "${states[$i]}"
  done
  if [[ -n "$def" ]]; then echo "Default route via: $def"; fi

  if (( ${#candidates[@]} == 0 )); then
    echo "No non-loopback interfaces detected." >&2
    exit 2
  fi

  local choice
  while true; do
    choice=$(prompt_default "Select interface by number or name" "$def")
    if [[ -z "$choice" ]]; then continue; fi
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      local idx=$((choice-1))
      if (( idx>=0 && idx<${#candidates[@]} )); then
        echo "${candidates[$idx]}"; return 0
      fi
    else
      if ip link show "$choice" >/dev/null 2>&1; then echo "$choice"; return 0; fi
    fi
    echo "Invalid selection."
  done
}

run_wizard() {
  echo "Interactive static IP setup"
  # Interface
  local sel_if
  if [[ -n "${iface:-}" ]]; then
    sel_if="$iface"
  else
    sel_if="$(choose_interface_interactive)"
  fi

  # Current values
  local cur_ip cur_gw cur_dns
  cur_ip="$(suggest_ipv4_cidr_for_iface "$sel_if" || true)"
  cur_gw="$(get_iface_gateway "$sel_if" || true)"
  cur_dns="$(get_current_dns "$sel_if" || true)"

  echo
  echo "Detected (may be empty):"
  echo "  Interface : $sel_if"
  echo "  IPv4/CIDR : ${cur_ip:-<none>}"
  echo "  Gateway   : ${cur_gw:-<none>}"
  echo "  DNS       : ${cur_dns:-<none>}"

  # Ask IP/CIDR, Gateway, DNS
  local input_ip input_gw input_dns
  input_ip="$(prompt_default "IPv4 with CIDR (e.g., 192.168.1.10/24)" "$cur_ip")"
  input_gw="$(prompt_default "Gateway IPv4" "$cur_gw")"
  input_dns="$(prompt_default "DNS servers (comma or space)" "$cur_dns")"

  # Normalize DNS
  local normalized_dns
  normalized_dns="$(echo "$input_dns" | tr ',' ' ' | xargs)"

  # Method
  local suggested_method
  method="${method:-auto}"
  suggested_method="$(detect_method)"
  local input_method
  input_method="$(prompt_default "Method [auto/netplan/nmcli/ifupdown/systemd-networkd]" "$suggested_method")"
  case "$input_method" in
    auto|netplan|nmcli|ifupdown|systemd-networkd) ;;
    *) echo "Unknown method, using '$suggested_method'."; input_method="$suggested_method" ;;
  esac

  # Summary
  echo
  echo "Summary:"
  echo "  Interface : $sel_if"
  echo "  IPv4/CIDR : $input_ip"
  echo "  Gateway   : $input_gw"
  echo "  DNS       : ${normalized_dns:-<none>}"
  echo "  Method    : $input_method"
  echo
  local proceed
  read -rp $'Proceed? [Y/n]: ' proceed; proceed=${proceed:-y}
  if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."; exit 0
  fi

  iface="$sel_if"
  ip_cidr="$input_ip"
  gateway="$input_gw"
  dns_list="$normalized_dns"
  method="$input_method"
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
dns_list=""
method="auto"
show_only=false
dry_run=false
list_templates_flag=false
template_load_name=""
template_save_name=""
template_delete_name=""
template_edit_name=""

iface_arg_set=false
ip_arg_set=false
gateway_arg_set=false
dns_arg_set=false
method_arg_set=false

while getopts ":i:a:g:d:m:T:W:R:E:LsDh" opt; do
  case "$opt" in
    i) iface="$OPTARG"; iface_arg_set=true ;;
    a) ip_cidr="$OPTARG"; ip_arg_set=true ;;
    g) gateway="$OPTARG"; gateway_arg_set=true ;;
    d) dns_raw="$OPTARG"; dns_arg_set=true ;;
    m) method="$OPTARG"; method_arg_set=true ;;
    T) template_load_name="$OPTARG" ;;
    W) template_save_name="$OPTARG" ;;
    R) template_delete_name="$OPTARG" ;;
    E) template_edit_name="$OPTARG" ;;
    L) list_templates_flag=true ;;
    s) show_only=true ;;
    D) dry_run=true ;;
    h) print_help; exit 0 ;;
    \?) echo "Invalid option -$OPTARG" >&2; print_help; exit 2 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; print_help; exit 2 ;;
  esac
done

shift $((OPTIND - 1))

if [[ "$list_templates_flag" == true ]]; then
  list_templates
  exit 0
fi

if [[ -n "$template_delete_name" ]]; then
  delete_template "$template_delete_name"
  exit 0
fi

if [[ -n "$template_edit_name" ]]; then
  edit_template "$template_edit_name"
  exit 0
fi

if [[ -n "$template_load_name" ]]; then
  load_template "$template_load_name"
fi

# If required values are missing and in TTY, start wizard
if [[ ( -z "${ip_cidr:-}" || -z "${gateway:-}" ) && "${show_only}" != true && "${dry_run}" != true ]]; then
  if is_tty; then
    run_wizard
  fi
fi

# Auto-select interface if still not provided
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

dns_from_args="$(normalize_dns "${dns_raw:-}")"
if [[ -n "$dns_from_args" ]]; then
  dns_list="$dns_from_args"
elif [[ -z "$dns_list" && -n "$current_dns" ]]; then
  dns_list="$current_dns"
fi

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

if [[ -n "$template_save_name" ]]; then
  save_template "$template_save_name"
fi

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

# Apply requires root; auto elevate if needed
ensure_root_or_reexec

case "$chosen" in
  netplan) apply_netplan ;;
  nmcli) apply_nmcli ;;
  ifupdown) apply_ifupdown ;;
  systemd-networkd) apply_systemd_networkd ;;
  *) echo "Unknown method '${chosen}'"; exit 1 ;;

esac

echo "Static IP configured on ${iface} -> ${ip_cidr}, gateway ${gateway}${dns_list:+, DNS: ${dns_list}}"
