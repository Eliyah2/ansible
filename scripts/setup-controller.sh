#!/usr/bin/env bash
# Installeert Ansible en de benodigde collecties op de Ansible host.
# Draaien vanaf je eigen pc:  ssh eliyah@192.168.56.10 'sudo bash -s' < scripts/setup-controller.sh
set -euo pipefail

LAB_USER="eliyah"
LAB_DIR="/home/${LAB_USER}/ansible-lab"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ansible

if [ -f "$LAB_DIR/requirements.yml" ]; then
  sudo -u "$LAB_USER" -H ansible-galaxy collection install -r "$LAB_DIR/requirements.yml"
else
  echo "Let op: $LAB_DIR/requirements.yml ontbreekt, draai eerst scripts/sync.sh" >&2
fi

sudo -u "$LAB_USER" -H bash -lc 'ansible --version | head -1'
