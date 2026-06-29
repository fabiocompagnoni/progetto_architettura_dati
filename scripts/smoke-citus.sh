#!/usr/bin/env bash
set -euo pipefail

# Verifica che il cluster Citus locale sia su e che i worker siano registrati e attivi.
psql="docker exec -i citus-coordinator psql -U postgres -d archdata -v ON_ERROR_STOP=1"

echo "Versione Citus:"
$psql -tAc "SELECT extversion FROM pg_extension WHERE extname = 'citus'"

echo "Nodi nel cluster:"
$psql -c "SELECT nodename, nodeport, isactive FROM pg_dist_node ORDER BY nodename"

active_workers=$($psql -tAc "SELECT count(*) FROM pg_dist_node WHERE noderole = 'primary' AND isactive AND nodename LIKE 'citus-worker%'")
if [[ "$active_workers" -ne 2 ]]; then
  echo "Attesi 2 worker attivi, trovati $active_workers" >&2
  exit 1
fi
echo "OK: 2 worker attivi."
