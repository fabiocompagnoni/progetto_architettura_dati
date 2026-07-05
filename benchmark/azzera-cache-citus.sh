#!/bin/bash
# Svuota la cache di Postgres riavviando i container Citus su tutti i nodi attivi. Sull'orchestratore.
set -euo pipefail
user=$(whoami)
mapfile -t NODI < <(docker exec -i citus psql -U postgres -d archdata -tAc "SELECT nodename FROM pg_dist_node WHERE isactive ORDER BY groupid")
for ip in "${NODI[@]}"; do
  ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$ip" "docker restart citus >/dev/null" && echo "riavviato $ip"
done
until docker exec citus pg_isready -U postgres -d archdata >/dev/null 2>&1; do sleep 1; done
echo "cache svuotata, cluster pronto"
