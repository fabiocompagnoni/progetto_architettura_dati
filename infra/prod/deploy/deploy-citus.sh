#!/bin/bash
# Copia e avvia il nodo Citus su coordinator + worker, via ssh/scp (sshpass).
# Ambiente richiesto: SSHPASS (password SSH), PG_PASSWORD (password del DB). NON registra i nodi:
# quello viene fatto a mano con citus-init-coordinator.sh / citus-add-node.sh sul coordinator.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
source "$here/hosts.env"
[ -f "$here/secrets.env" ] && source "$here/secrets.env"
: "${SSHPASS:?imposta SSHPASS in secrets.env}" "${PG_PASSWORD:?imposta PG_PASSWORD in secrets.env}"
REL="$here/../relational"
SSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new"
SCP="sshpass -e scp -o StrictHostKeyChecking=accept-new"

deploy_node() {                       # $1 = IP pubblico
  local ip=$1
  $SSH "$SSH_USER@$ip" "mkdir -p ~/citus"
  $SCP -r "$REL"/. "$SSH_USER@$ip:~/citus/"
  printf 'PG_PASSWORD=%s\n' "$PG_PASSWORD" | $SSH "$SSH_USER@$ip" "cat > ~/citus/.env"
  $SSH "$SSH_USER@$ip" "cd ~/citus && docker compose up -d"
}

echo "== coordinator (worker-1) =="; deploy_node "$COORD_PUB"
for w in "${WORKERS[@]}"; do set -- $w; echo "== worker $1 =="; deploy_node "$1"; done
echo "Nodi su. Registrali a mano dal coordinator: ./citus-init-coordinator.sh e ./citus-add-node.sh <ip privato>."
