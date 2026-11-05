#!/usr/bin/env bash
# Richt een gast in: hostname, beheeraccount eliyah met SSH-sleutel en sudo,
# en een statisch IP op de host-only netwerkkaart.
#
# Wordt door scripts/create-vms.sh als root in de gast uitgevoerd:
#   sudo bash -s -- <hostname> <ip>
set -euo pipefail

NEW_HOSTNAME="${1:?hostname ontbreekt}"
STATIC_IP="${2:?ip ontbreekt}"
LAB_USER="eliyah"
KEY_FILE="/tmp/eliyah-key.pub"

# --- hostname ---
hostnamectl set-hostname "$NEW_HOSTNAME"
if ! grep -q "$NEW_HOSTNAME" /etc/hosts; then
  echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
fi

# --- beheeraccount met publieke sleutel en wachtwoordloos sudo ---
if ! id "$LAB_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$LAB_USER"
fi
echo "$LAB_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${LAB_USER}"
chmod 0440 "/etc/sudoers.d/90-${LAB_USER}"
install -d -m 0700 -o "$LAB_USER" -g "$LAB_USER" "/home/${LAB_USER}/.ssh"
install -m 0600 -o "$LAB_USER" -g "$LAB_USER" "$KEY_FILE" "/home/${LAB_USER}/.ssh/authorized_keys"
if command -v restorecon >/dev/null 2>&1; then
  restorecon -R "/home/${LAB_USER}/.ssh" || true
fi

# --- host-only netwerkkaart bepalen ( alles behalve loopback en de NAT-kaart ) ---
NAT_IF="$(ip route show default | awk '{print $5; exit}')"
LAB_IF=""
for iface in /sys/class/net/*; do
  iface="$(basename "$iface")"
  [ "$iface" = "lo" ] && continue
  [ "$iface" = "$NAT_IF" ] && continue
  LAB_IF="$iface"
done
if [ -z "$LAB_IF" ]; then
  echo "FOUT: geen host-only interface gevonden" >&2
  exit 1
fi

# --- statisch IP configureren, per distro ---
if [ -d /etc/netplan ] && command -v netplan >/dev/null 2>&1; then
  # Ubuntu
  cat > /etc/netplan/99-eliyah-lab.yaml <<EOF
network:
  version: 2
  ethernets:
    ${LAB_IF}:
      dhcp4: false
      dhcp6: false
      addresses: [${STATIC_IP}/24]
EOF
  chmod 600 /etc/netplan/99-eliyah-lab.yaml
  netplan apply
elif [ -f /etc/network/interfaces ]; then
  # Debian (ifupdown)
  cat > /etc/network/interfaces.d/50-eliyah-lab <<EOF
auto ${LAB_IF}
iface ${LAB_IF} inet static
    address ${STATIC_IP}
    netmask 255.255.255.0
EOF
  ip link set "$LAB_IF" up
  ifdown "$LAB_IF" 2>/dev/null || true
  ifup "$LAB_IF"
else
  # RHEL-family (NetworkManager)
  for con in $(nmcli -t -f NAME,DEVICE connection show | awk -F: -v d="$LAB_IF" '$2==d{print $1}'); do
    nmcli connection delete "$con" >/dev/null 2>&1 || true
  done
  nmcli connection delete "eliyah-lab" >/dev/null 2>&1 || true
  nmcli connection add type ethernet ifname "$LAB_IF" con-name "eliyah-lab" \
    ipv4.method manual ipv4.addresses "${STATIC_IP}/24" ipv6.method ignore >/dev/null
  nmcli connection up "eliyah-lab" >/dev/null
fi

if ip -4 addr show "$LAB_IF" | grep -q "$STATIC_IP"; then
  echo "OK: ${NEW_HOSTNAME} heeft ${STATIC_IP} op ${LAB_IF}"
else
  echo "FOUT: ${STATIC_IP} niet actief op ${LAB_IF}" >&2
  exit 1
fi
