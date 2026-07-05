#!/bin/bash
# Scalabilita' per volume di dati (nodi fissi): genera e carica un lotto di nuovi tenant sul cluster a 4 nodi, poi misura la suite di letture e salva le medie etichettate. 
# Il numero di nodi NON cambia: i nuovi tenant si distribuiscono sugli shard esistenti (hash di tenant_id), quindi cresce il dato per nodo.
# Da eseguire sull'orchestratore (worker-1), da ~/hr. Uso: ./scala-dati-citus.sh <tenant-start> <tenant-count> <label>
set -euo pipefail
start=${1:?serve tenant-start (primo id nuovo tenant)}
count=${2:?serve quanti nuovi tenant generare}
label=${3:?serve un label per il CSV (es. 60ditte)}
out=generato_lotto_$label

echo "== genero tenant $start..$((start+count-1)) (no cataloghi, seed 42) =="
python3 data/genera.py --tenant-start "$start" --tenant-count "$count" --no-cataloghi --anno 2026 --jobs 8 --seed 42 --out "$out"
echo "== carico il lotto =="
CITUS_CONTAINER=citus bash scripts/carica-citus.sh "$out/citus"
rm -rf "$out"

echo "== dimensione dati per nodo e conteggi =="
docker exec citus psql -U postgres -d archdata -c "SELECT nodename, pg_size_pretty(sum(shard_size)) AS dati FROM citus_shards GROUP BY nodename ORDER BY nodename"
docker exec citus psql -U postgres -d archdata -tAc "SELECT 'ditte='||count(*) FROM ditta; SELECT 'dipendenti='||count(*) FROM dipendente"

echo "== misura a caldo =="
rm -f benchmark/results/citus.csv
bash esegui-suite-citus.sh 10 queries/relational/letture/*.sql >/dev/null
cp benchmark/results/citus.csv "benchmark/results/scala_dati_${label}.csv"
echo "-> benchmark/results/scala_dati_${label}.csv"