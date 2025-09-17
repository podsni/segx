#!/bin/bash

echo -e "\n\e[1;36m Info Jaringan: Interface Aktif, MAC & IP Address\e[0m"
echo -e "---------------------------------------------------------\n"

# Loop semua interface
for iface in $(ls /sys/class/net/); do
  # Lewati loopback
  if [[ "$iface" == "lo" ]]; then
    continue
  fi

  # Cek status interface
  state=$(cat /sys/class/net/$iface/operstate)
  mac=$(cat /sys/class/net/$iface/address)
  ip=$(ip -o -4 addr show $iface | awk '{print $4}')

  # Tampilkan hanya interface aktif (state UP atau IP ada)
  if [[ "$state" == "up" || -n "$ip" ]]; then
    echo -e " \e[1mInterface:\e[0m $iface"
    echo -e "     \e[1;33mStatus :\e[0m ${state^^}"
    echo -e "     \e[1;32mMAC    :\e[0m $mac"

    if [[ -n "$ip" ]]; then
      echo -e "     \e[1;34mIP     :\e[0m $ip"
    else
      echo -e "     \e[1;31mIP     :\e[0m Tidak ada IP (offline)"
    fi

    echo ""
  fi
done