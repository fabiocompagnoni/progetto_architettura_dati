#!/bin/bash
# Registra l'host del coordinator (una volta sola, sulla VM coordinator). Arg: IP privato del coordinator.
set -euo pipefail
COORD_IP=${1:-10.0.1.8}
docker exec citus psql -U postgres -d archdata -v ON_ERROR_STOP=1 \
  -c "SELECT citus_set_coordinator_host('$COORD_IP', 5432);"
