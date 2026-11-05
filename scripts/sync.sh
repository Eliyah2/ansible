#!/usr/bin/env bash
# Kopieert deze repo naar de Ansible host (eliyah-ansible), zodat je daar
# de playbooks kunt draaien. De privésleutel en de boxen gaan niet mee.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTROLLER="${CONTROLLER:-eliyah@192.168.56.10}"
DEST="${DEST:-ansible-lab}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
           -o BatchMode=yes -o PreferredAuthentications=publickey)

ssh -i "$LAB_DIR/keys/id_ed25519_eliyah" "${SSH_OPTS[@]}" "$CONTROLLER" "mkdir -p ~/$DEST"

tar -czf - -C "$LAB_DIR" \
  --exclude=./.git \
  --exclude=./.build \
  --exclude=./keys/id_ed25519_eliyah \
  --exclude=./keys/vagrant_insecure_key \
  . | ssh -i "$LAB_DIR/keys/id_ed25519_eliyah" "${SSH_OPTS[@]}" "$CONTROLLER" "tar -xzf - -C ~/$DEST"

echo "Repo gekopieerd naar $CONTROLLER:~/$DEST"

# Privésleutel naar de Ansible host, met rechten 0600.
ssh -i "$LAB_DIR/keys/id_ed25519_eliyah" "${SSH_OPTS[@]}" "$CONTROLLER" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
ssh -i "$LAB_DIR/keys/id_ed25519_eliyah" "${SSH_OPTS[@]}" "$CONTROLLER" \
  "cat > ~/.ssh/id_ed25519_eliyah && chmod 600 ~/.ssh/id_ed25519_eliyah" < "$LAB_DIR/keys/id_ed25519_eliyah"
echo "SSH-sleutel geplaatst op $CONTROLLER:~/.ssh/id_ed25519_eliyah (0600)"
