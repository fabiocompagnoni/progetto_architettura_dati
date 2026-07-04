#!/bin/bash
# Copia e avvia config+mongos (worker-1) e gli shard (VM-2/3/4), via ssh/scp (sshpass).
# Credenziali in secrets.env: SSHPASS (password SSH), MONGO_PASSWORD (password admin del cluster).
# NON registra gli shard: quello viene fatto a mano con init-config.sh / init-shard.sh / mongo-add-shard.sh.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
source "$here/hosts.env"
[ -f "$here/secrets.env" ] && source "$here/secrets.env"
: "${SSHPASS:?imposta SSHPASS in secrets.env}" "${MONGO_PASSWORD:?imposta MONGO_PASSWORD in secrets.env}"
DOC="$here/../document"
SSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new"
SCP="sshpass -e scp -o StrictHostKeyChecking=accept-new"

# keyfile condiviso: generato una volta, mai committato
KEY="$DOC/keyfile"
[ -f "$KEY" ] || { openssl rand -base64 756 > "$KEY"; chmod 600 "$KEY"; }

deploy() {                            # $1 = IP pubblico, $2 = sottocartella, $3 = eventuale riga .env
  local ip=$1 sub=$2 envline=${3:-}
  $SSH "$SSH_USER@$ip" "mkdir -p ~/mongo"
  $SCP -r "$DOC/$sub"/. "$KEY" "$SSH_USER@$ip:~/mongo/"
  # il keyfile dev'essere di proprieta' dell'utente mongodb del container (uid 999) e perm 400
  $SSH "$SSH_USER@$ip" "sudo chown 999:999 ~/mongo/keyfile && sudo chmod 400 ~/mongo/keyfile"
  [ -n "$envline" ] && printf '%s\n' "$envline" | $SSH "$SSH_USER@$ip" "cat > ~/mongo/.env" || true
  $SSH "$SSH_USER@$ip" "cd ~/mongo && docker compose up -d"
}

echo "== config+mongos (worker-1) =="; deploy "$COORD_PUB" config-mongos
i=1
for w in "${WORKERS[@]}"; do set -- $w; echo "== shard$i ($1) =="; deploy "$1" shard "MONGO_RS=shard$i"; i=$((i+1)); done
echo "Nodi su. Poi a mano: init-config.sh sul coordinator, init-shard.sh <rs> <ip> su ogni shard, mongo-add-shard.sh <rs> <ip>."
