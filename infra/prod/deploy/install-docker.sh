#!/bin/bash
# Installa Docker (engine + compose plugin) sui nodi DB via SSH e aggiunge l'utente al gruppo docker.
# Ubuntu 22.04. Credenziali in secrets.env (SSHPASS vale anche come password sudo).
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
source "$here/hosts.env"
[ -f "$here/secrets.env" ] && source "$here/secrets.env"
: "${SSHPASS:?imposta SSHPASS in secrets.env}"
SSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new"

install_on() {                        # $1 = IP pubblico
  local ip=$1
  echo "== Docker su $ip =="
  $SSH "$SSH_USER@$ip" "command -v docker >/dev/null 2>&1 && echo 'gia presente' || {
      echo '$SSHPASS' | sudo -S sh -c 'curl -fsSL https://get.docker.com | sh'
      echo '$SSHPASS' | sudo -S usermod -aG docker '$SSH_USER'
    }"
}

install_on "$COORD_PUB"
for w in "${WORKERS[@]}"; do set -- $w; install_on "$1"; done
echo "Fatto. L'appartenenza al gruppo docker vale dalla prossima sessione SSH."
