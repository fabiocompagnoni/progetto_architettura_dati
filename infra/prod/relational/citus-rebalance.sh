#!/bin/bash
# Ridistribuisce gli shard sui nodi correnti (dopo aver aggiunto un worker, per il regime "stessi
# dati + piu' nodi"). Da eseguire sulla VM coordinator.
set -euo pipefail
docker exec citus psql -U postgres -d archdata -v ON_ERROR_STOP=1 \
  -c "SELECT citus_rebalance_start();"
echo "rebalance avviato; stato con: SELECT * FROM citus_rebalance_status();"
