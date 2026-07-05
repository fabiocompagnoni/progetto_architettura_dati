#!/bin/bash
# Ridistribuisce gli shard sui nodi correnti dopo aver aggiunto un worker (regime "stessi dati + piu'
# nodi"). Sincrono e in modalita' block_writes: sposta gli shard con COPY invece della logical replication,
# quindi funziona con wal_level=replica (il nostro default). Da eseguire sulla VM coordinator.
set -euo pipefail
docker exec citus psql -U postgres -d archdata -v ON_ERROR_STOP=1 \
  -c "SELECT rebalance_table_shards(shard_transfer_mode := 'block_writes');"
docker exec citus psql -U postgres -d archdata \
  -c "SELECT nodename, count(*) AS shard FROM citus_shards GROUP BY nodename ORDER BY nodename;"
