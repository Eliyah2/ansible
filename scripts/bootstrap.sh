#!/usr/bin/env bash
# Eenmalige opzet van het hele lab:
#   1. de drie VM's aanmaken en inrichten
#   2. de repo naar de Ansible host kopiëren
#   3. Ansible + collecties op de Ansible host installeren
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
           -o BatchMode=yes -o PreferredAuthentications=publickey)

bash "$LAB_DIR/scripts/create-vms.sh"
bash "$LAB_DIR/scripts/sync.sh"

ssh -i "$LAB_DIR/keys/id_ed25519_eliyah" "${SSH_OPTS[@]}" eliyah@192.168.56.10 \
  'sudo bash -s' < "$LAB_DIR/scripts/setup-controller.sh"

cat <<'EOF'

Lab staat klaar. Log in op de Ansible host en draai de playbook:

  ssh -i ansible-lab/keys/id_ed25519_eliyah eliyah@192.168.56.10
  cd ~/ansible-lab
  ansible all -m ping
  ansible-playbook playbooks/site.yml

Website: http://192.168.56.11/
EOF
