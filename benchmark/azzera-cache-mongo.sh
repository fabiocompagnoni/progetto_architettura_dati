#!/bin/bash
# Svuota la cache (WiredTiger) riavviando i container mongo-shard sui nodi attivi.
set -euo pipefail
muser=${MONGO_USER:-admin}; mpass=${MONGO_PASSWORD:?imposta MONGO_PASSWORD}; user=$(whoami)
mongos() { docker exec -i mongos mongosh --quiet --port 27017 -u "$muser" -p "$mpass" --authenticationDatabase admin "$@"; }
mapfile -t SHARD < <(mongos --eval "db.getSiblingDB('config').shards.find().toArray().forEach(s=>print(s.host.replace(/^.*\//,'').replace(/:.*/,'')))")
for ip in "${SHARD[@]}"; do
  ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$ip" "docker restart mongo-shard >/dev/null" && echo "riavviato $ip"
done
until mongos --eval "sh.status()" >/dev/null 2>&1; do sleep 1; done
echo "cache svuotata, cluster pronto"