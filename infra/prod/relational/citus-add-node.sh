#!/bin/bash
# Aggiunge un nodo al cluster a mano (sulla VM coordinator). Arg: IP privato del worker da aggiungere.
# Passando l'IP del coordinator stesso lo si rende anche data node (opzione "4 nodi").
set -euo pipefail
WORKER_IP=${1:?serve l'IP privato del nodo da aggiungere}
docker exec citus psql -U postgres -d archdata -v ON_ERROR_STOP=1 \
  -c "SELECT citus_add_node('$WORKER_IP', 5432);"
docker exec citus psql -U postgres -d archdata \
  -c "SELECT nodename, nodeport, isactive, noderole FROM pg_dist_node ORDER BY nodename;"
