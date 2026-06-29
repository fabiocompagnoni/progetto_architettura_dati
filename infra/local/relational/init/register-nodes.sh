#!/usr/bin/env bash
set -euo pipefail

coordinator=citus-coordinator
workers=(citus-worker-1 citus-worker-2)

run() { psql -h "$coordinator" -U postgres -d archdata -v ON_ERROR_STOP=1 -tAc "$1"; }

run "SELECT citus_set_coordinator_host('$coordinator', 5432)"

for w in "${workers[@]}"; do
  # citus_add_node è idempotente: se il nodo c'è già torna il suo id senza errori.
  run "SELECT citus_add_node('$w', 5432)"
done

run "SELECT nodename, nodeport, isactive FROM pg_dist_node ORDER BY nodename"
