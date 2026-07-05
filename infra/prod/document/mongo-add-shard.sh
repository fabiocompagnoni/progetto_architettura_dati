#!/bin/bash
# Aggiunge uno shard al cluster a mano (su worker-1, via mongos). Args: nome-RS, IP privato dello shard.
# Serve MONGO_PASSWORD nell'ambiente.
set -euo pipefail
RS=${1:?serve il nome del replica set dello shard}
IP=${2:?serve IP privato dello shard}
docker exec mongos mongosh --quiet -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin \
  --eval "sh.addShard('$RS/$IP:27018'); sh.status()"
