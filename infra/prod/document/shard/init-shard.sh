#!/bin/bash
# Inizializza lo shard come replica set a 1 membro (localhost exception). Args: nome-RS, IP privato dello shard.
set -euo pipefail
RS=${1:?serve il nome del replica set dello shard}
IP=${2:?serve l'IP privato dello shard}
docker exec mongo-shard mongosh --quiet --port 27018 --eval \
  "rs.initiate({_id:'$RS', members:[{_id:0, host:'$IP:27018'}]})"
