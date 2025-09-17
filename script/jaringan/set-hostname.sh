#!/usr/bin/env bash
set -euo pipefail

# Change system hostname safely across common Linux distros.
# - Uses hostnamectl when available (systemd)
# - Fallback: write /etc/hostname and call `hostname`
# - Updates /etc/hosts in a managed block (with backup)
#
# Usage examples:
#   sudo ./set-hostname.sh -n server1 -d example.local
#   sudo ./set-hostname.sh -n server1.example.local
#   sudo ./set-hostname.sh -n server1 -d example.local -p "Server One" -I 192.168.1.10
#
# If you run without -n in an interactive terminal, a guided wizard will start.
#
# Options:
#   -n  New hostname (short or FQDN)
#   -d  Domain (optional; used if -n is short)
#   -p  Pretty hostname (optional)
#   -I  IP for /etc/hosts mapping (optional; default: 127.0.1.1 on Debian, else 127.0.0.1)
#   -m  Method: auto (default), hostnamectl, etc (write files)
#   -h  Help

print_help() {
  cat <<'EOF'
Usage:
  set-hostname.sh -n HOSTNAME [-d DOMAIN] [-p PRETTY] [-I IP] [-m METHOD]

Options:
  -n   New hostname (short or FQDN)
  -d   Domain name to form FQDN if -n is short
  -p   Pretty hostname
  -I   IP address to map in /etc/hosts (FQDN and short)
  -m   Method: auto (default), hostnamectl, etc
  -h   Show this help

Examples:
  set-hostname.sh -n server1 -d example.local
  set-hostname.sh -n server1.example.local
  set-hostname.sh -n server1 -d example.local -p "Server One" -I 192.168.1.10

Interactive:
  If -n is omitted and you're in a TTY, an interactive wizard will ask:
  hostname, domain (optional), pretty name (optional), mapping IP, and method.
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

# RFC-1123 hostname validation: labels 1-63 chars, [A-Za-z0-9-], not starting/ending with '-'
validate_hostname() {
  local hn="$1"
  # Total length <= 253
  if (( ${#hn} < 1 || ${#hn} > 253 )); then
    return 1
  fi
  IFS='.' read -r -a labels <<< "$hn"
  for lbl in "${labels[@]}"; do
    if (( ${#lbl} < 1 || ${#lbl} > 63 )); then return 1; fi
    if [[ ! "$lbl" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then return 1; fi
  done
  return 0
}

get_os_like() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID_LIKE:-${ID:-}}"
  fi
}

choose_default_hosts_ip() {
  local like
  like="$(get_os_like || true)"
  if [[ "$like" == *debian* ]]; then
    echo "127.0.1.1"
  else
    echo "127.0.0.1"
  fi
}

update_hosts_block() {
  local fqdn="$1"; shift
  local short="$1"; shift
  local ip_map="$1"; shift
  local hosts_file="/etc/hosts"
  local begin="# set-hostname.sh managed block start"
  local end="# set-hostname.sh managed block end"

  backup_file "$hosts_file"
  # Remove existing managed block
  if grep -qF "$begin" "$hosts_file" 2>/dev/null; then
    awk -v b="$begin" -v e="$end" 'BEGIN{skip=0} {
      if ($0==b) {skip=1; next}
      if ($0==e) {skip=0; next}
      if (!skip) print $0
    }' "$hosts_file" > "${hosts_file}.tmp"
    mv "${hosts_file}.tmp" "$hosts_file"
  fi

  {
    echo "$begin"
    printf "%s\t%s %s\n" "$ip_map" "$fqdn" "$short"
    echo "$end"
  } >> "$hosts_file"
}

apply_with_hostnamectl() {
  local fqdn="$1"; shift
  local pretty="${1:-}"
  if [[ -n "$pretty" ]]; then
    hostnamectl set-hostname "$fqdn" --static
    hostnamectl set-hostname "$pretty" --pretty
  else
    hostnamectl set-hostname "$fqdn"
  fi
}

apply_with_etc() {
  local fqdn="$1"; shift
  local short="$1"; shift
  echo "$short" > /etc/hostname
  hostname "$fqdn" || true
}

name=""
domain=""
pretty=""
map_ip=""
method="auto"

# Helpers for interactive mode
is_tty() { [[ -t 0 && -t 1 ]]; }
prompt_default() {
  local prompt="$1"; shift
  local default_val="$1"; shift || true
  local var
  if [[ -n "$default_val" ]]; then
    read -rp "$prompt [$default_val]: " var
    echo "${var:-$default_val}"
  else
    read -rp "$prompt: " var
    echo "$var"
  fi
}
prompt_yes_no() {
  local prompt="$1"; shift
  local def="$1"; shift || true
  local ans
  if [[ "$def" =~ ^[Yy]$ ]]; then
    read -rp "$prompt [Y/n]: " ans; ans=${ans:-y}
  else
    read -rp "$prompt [y/N]: " ans; ans=${ans:-n}
  fi
  [[ "$ans" =~ ^[Yy]$ ]]
}

run_wizard() {
  local cur_hn
  cur_hn=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "")
  echo "Interactive hostname setup"
  echo "Current hostname: ${cur_hn}"

  # Ask hostname or FQDN
  local input_hn
  input_hn=$(prompt_default "Enter new hostname (short or FQDN)" "${cur_hn}")
  while ! validate_hostname "$input_hn"; do
    echo "Invalid hostname format. Please follow RFC-1123 (letters, digits, hyphens)."
    input_hn=$(prompt_default "Enter new hostname (short or FQDN)" "")
  done

  # If short without dot, optionally ask domain
  local input_domain=""
  if [[ "$input_hn" != *.* ]]; then
    input_domain=$(prompt_default "Enter domain (optional, to form FQDN)" "")
    if [[ -n "$input_domain" ]]; then
      local combined="${input_hn}.${input_domain}"
      if validate_hostname "$combined"; then
        input_hn="$combined"
      else
        echo "Warning: domain ignored because resulting FQDN is invalid."
      fi
    fi
  fi

  # Pretty hostname
  local suggested_pretty
  suggested_pretty="${input_hn%%.*}"
  suggested_pretty="${suggested_pretty//-/ }"
  suggested_pretty="${suggested_pretty^}"
  local input_pretty
  input_pretty=$(prompt_default "Pretty hostname (optional)" "$suggested_pretty")
  if [[ -z "$input_pretty" ]]; then input_pretty=""; fi

  # Mapping IP
  local suggested_ip
  suggested_ip=$(choose_default_hosts_ip)
  local input_ip
  input_ip=$(prompt_default "IP to map in /etc/hosts" "$suggested_ip")

  # Method
  local default_method="auto"
  if command -v hostnamectl >/dev/null 2>&1; then
    default_method="hostnamectl"
  else
    default_method="etc"
  fi
  local input_method
  input_method=$(prompt_default "Method [auto/hostnamectl/etc]" "$default_method")
  case "$input_method" in
    auto|hostnamectl|etc) ;;
    *) echo "Unknown method, using 'auto'."; input_method="auto" ;;
  esac

  # Summary
  echo
  echo "Summary:"
  echo "  FQDN        : $input_hn"
  echo "  Pretty      : ${input_pretty:-<none>}"
  echo "  /etc/hosts IP: $input_ip"
  echo "  Method      : $input_method"
  echo
  if prompt_yes_no "Proceed?" y; then
    name="$input_hn"
    # domain stays blank because name may already be FQDN
    pretty="$input_pretty"
    map_ip="$input_ip"
    method="$input_method"
  else
    echo "Aborted by user."; exit 0
  fi
}

while getopts ":n:d:p:I:m:h" opt; do
  case "$opt" in
    n) name="$OPTARG" ;;
    d) domain="$OPTARG" ;;
    p) pretty="$OPTARG" ;;
    I) map_ip="$OPTARG" ;;
    m) method="$OPTARG" ;;
    h) print_help; exit 0 ;;
    \?) echo "Invalid option -$OPTARG" >&2; print_help; exit 2 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; print_help; exit 2 ;;
  esac
done

# Interactive wizard when no -n provided and running in TTY
if [[ -z "$name" ]]; then
  if is_tty; then
    run_wizard
  else
    echo "Error: -n HOSTNAME is required (non-interactive)." >&2
    print_help
    exit 2
  fi
fi

# Derive FQDN and short host
fqdn="$name"
if [[ -n "$domain" && "$name" != *.* ]]; then
  fqdn="$name.$domain"
fi

# Validate
if ! validate_hostname "$fqdn"; then
  echo "Error: invalid hostname '$fqdn' (RFC-1123)." >&2
  exit 2
fi

short_host="${fqdn%%.*}"

# Choose mapping IP for /etc/hosts
if [[ -z "$map_ip" ]]; then
  map_ip="$(choose_default_hosts_ip)"
fi

# Detect method
chosen_method=""
if [[ "$method" != "auto" ]]; then
  chosen_method="$method"
else
  if command -v hostnamectl >/dev/null 2>&1; then
    chosen_method="hostnamectl"
  else
    chosen_method="etc"
  fi
fi

ensure_root_or_reexec() {
  if [[ ${EUID} -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      echo "Error: must run as root (sudo not available)" >&2
      exit 1
    fi
    echo "Elevating privileges with sudo..."
    # Re-exec this script with the resolved parameters so we skip the wizard
    argv=("-n" "$fqdn")
    [[ -n "$pretty" ]] && argv+=("-p" "$pretty")
    [[ -n "$map_ip" ]] && argv+=("-I" "$map_ip")
    [[ -n "$method" ]] && argv+=("-m" "$method")
    exec sudo -E bash "$0" "${argv[@]}"
  fi
}

echo "Using method: ${chosen_method}; hosts mapping IP: ${map_ip}"

ensure_root_or_reexec

case "$chosen_method" in
  hostnamectl)
    apply_with_hostnamectl "$fqdn" "$pretty"
    ;;
  etc)
    apply_with_etc "$fqdn" "$short_host"
    ;;
  *)
    echo "Unknown method '$chosen_method'" >&2
    exit 1
    ;;
esac

update_hosts_block "$fqdn" "$short_host" "$map_ip"

echo "Hostname set to: ${fqdn}${pretty:+ (pretty: $pretty)}"
