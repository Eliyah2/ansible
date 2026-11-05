#!/usr/bin/env bash
# Verwijdert de drie VM's van het lab (inclusief schijven).
set -euo pipefail

VBOXMANAGE="${VBOXMANAGE:-VBoxManage}"
if ! command -v "$VBOXMANAGE" >/dev/null 2>&1; then
  VBOXMANAGE="/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
fi

for vm in eliyah-ansible eliyah-web01 eliyah-db01; do
  if "$VBOXMANAGE" list vms | grep -q "\"$vm\""; then
    "$VBOXMANAGE" unregistervm "$vm" --delete >/dev/null
    echo "verwijderd: $vm"
  else
    echo "bestaat niet: $vm"
  fi
done
