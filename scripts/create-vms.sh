#!/usr/bin/env bash
# Maakt de drie virtuele machines van het Ansible-lab in VirtualBox.
#
#   1. de box (OVF + schijf) wordt gedownload en geïmporteerd
#   2. NAT (internet) + host-only netwerkkaart (192.168.56.0/24)
#   3. de gast wordt via SSH klaargezet met scripts/vm-setup.sh
#
# Gebruik: bash scripts/create-vms.sh
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$LAB_DIR/.build"
INSECURE_KEY="$LAB_DIR/keys/vagrant_insecure_key"
ELIYAH_KEY="$LAB_DIR/keys/id_ed25519_eliyah"
HOSTONLY_IF="${HOSTONLY_IF:-VirtualBox Host-Only Ethernet Adapter}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
           -o BatchMode=yes -o PreferredAuthentications=publickey)

VBOXMANAGE="${VBOXMANAGE:-VBoxManage}"
if ! command -v "$VBOXMANAGE" >/dev/null 2>&1; then
  VBOXMANAGE="/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
fi
if [ ! -x "$VBOXMANAGE" ]; then
  echo "FOUT: VBoxManage niet gevonden" >&2
  exit 1
fi

# naam|box|ip|ram-mb|cpus|ssh-poort-op-de-host
VMS=(
  "eliyah-ansible|bento/ubuntu-24.04|192.168.56.10|1024|2|2222"
  "eliyah-web01|bento/debian-12|192.168.56.11|768|1|2223"
  "eliyah-db01|generic/rocky9|192.168.56.12|896|1|2224"
)

ensure_keys() {
  mkdir -p "$LAB_DIR/keys"
  if [ ! -f "$ELIYAH_KEY" ]; then
    echo "  SSH-sleutel genereren: id_ed25519_eliyah"
    ssh-keygen -t ed25519 -C "eliyah@eliyah-ansible" -f "$ELIYAH_KEY" -N "" >/dev/null
  fi
  if [ ! -f "$INSECURE_KEY" ]; then
    # Publiek bekende sleutel waarmee de boxen standaard klaarstaan.
    curl -sL --fail -o "$INSECURE_KEY" \
      https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant
    chmod 600 "$INSECURE_KEY"
  fi
}

ensure_box() {
  local box="$1" slug box_file version url
  slug="$(echo "$box" | tr '/' '_')"
  box_file="$BUILD_DIR/$slug.box"
  [ -s "$box_file" ] && return 0

  version="$(curl -s "https://app.vagrantup.com/api/v1/box/$box" \
    | sed -E 's/.*"current_version":\{"version":"([^"]+)".*/\1/')"
  # Let op: het architectuur-segment is verplicht, anders krijg je de ARM-box.
  url="https://vagrantcloud.com/${box%%/*}/boxes/${box##*/}/versions/${version}/providers/virtualbox/amd64/vagrant.box"

  mkdir -p "$BUILD_DIR"
  echo "  box downloaden: $box ($version, amd64)"
  curl -L --fail --progress-bar -o "$box_file" "$url"

  if tar -tzf "$box_file" | grep -qiE 'aarch64|arm64'; then
    echo "FOUT: $box is geen amd64-box" >&2
    rm -f "$box_file"
    exit 1
  fi
}

vm_exists() { "$VBOXMANAGE" list vms | grep -q "\"$1\""; }
vm_running() { "$VBOXMANAGE" list runningvms | grep -q "\"$1\""; }

import_box() {
  local vm="$1" box="$2" ram="$3" cpus="$4" port="$5"
  local slug box_dir ovf
  slug="$(echo "$box" | tr '/' '_')"
  box_dir="$BUILD_DIR/$slug"

  ensure_box "$box"
  if ! ls "$box_dir"/*.ovf >/dev/null 2>&1; then
    mkdir -p "$box_dir"
    tar -xzf "$BUILD_DIR/$slug.box" -C "$box_dir"
  fi
  ovf="$(ls "$box_dir"/*.ovf | head -1)"

  if vm_exists "$vm"; then
    echo "  VM $vm bestaat al"
    if vm_running "$vm"; then
      echo "  VM draait al, instellingen blijven ongewijzigd"
      return 0
    fi
  else
    echo "  VM $vm importeren uit $box"
    "$VBOXMANAGE" import "$ovf" --vsys 0 --vmname "$vm" --memory "$ram" --cpus "$cpus" >/dev/null
  fi

  "$VBOXMANAGE" modifyvm "$vm" \
    --memory "$ram" --cpus "$cpus" \
    --nic1 nat --nic2 hostonly --hostonlyadapter2 "$HOSTONLY_IF" \
    --natpf1 "ssh,tcp,127.0.0.1,$port,,22" \
    --audio none --usb off >/dev/null
}

start_vm() {
  local vm="$1"
  if vm_running "$vm"; then
    echo "  VM $vm draait al"
  else
    echo "  VM $vm starten (headless)"
    "$VBOXMANAGE" startvm "$vm" --type headless >/dev/null
  fi
}

wait_ssh() {
  local port="$1" i=0
  while [ "$i" -lt 60 ]; do
    if ssh -i "$INSECURE_KEY" -p "$port" "${SSH_OPTS[@]}" -o ConnectTimeout=5 \
         -o BatchMode=yes vagrant@127.0.0.1 true >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
    i=$((i + 1))
  done
  return 1
}

provision_vm() {
  local vm="$1" ip="$2" port="$3"
  echo "  account eliyah en netwerk instellen"
  ssh -i "$INSECURE_KEY" -p "$port" "${SSH_OPTS[@]}" vagrant@127.0.0.1 \
    "cat > /tmp/eliyah-key.pub" < "$LAB_DIR/keys/id_ed25519_eliyah.pub"
  ssh -i "$INSECURE_KEY" -p "$port" "${SSH_OPTS[@]}" vagrant@127.0.0.1 \
    "sudo bash -s -- '$vm' '$ip'" < "$LAB_DIR/scripts/vm-setup.sh"
  echo "  controle via eliyah@$ip:"
  if ! ssh -i "$ELIYAH_KEY" "${SSH_OPTS[@]}" "eliyah@$ip" \
       "hostname; . /etc/os-release && echo \"\$PRETTY_NAME\"; ip -4 -o addr show | awk '{print \$2, \$4}'"; then
    echo "FOUT: inloggen als eliyah@$ip met id_ed25519_eliyah lukt niet" >&2
    exit 1
  fi
}

main() {
  echo "Host-only netwerk: $HOSTONLY_IF"
  ensure_keys
  for entry in "${VMS[@]}"; do
    IFS='|' read -r vm box ip ram cpus port <<< "$entry"
    echo "== $vm ($box, $ip) =="
    import_box "$vm" "$box" "$ram" "$cpus" "$port"
    start_vm "$vm"
    echo "  wachten op SSH (poort $port)"
    if ! wait_ssh "$port"; then
      echo "FOUT: SSH op poort $port kwam niet op" >&2
      exit 1
    fi
    provision_vm "$vm" "$ip" "$port"
  done
  echo "KLAAR: drie VM's draaien."
}

main "$@"
