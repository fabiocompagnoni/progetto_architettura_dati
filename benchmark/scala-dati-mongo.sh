#!/bin/bash
# Scalabilita' per volume di dati Mongo (shard fissi), parallelo a scala-dati-citus.sh: genera e carica un lotto di nuovi tenant, poi misura le letture a caldo (cache piena = capacita' massima) e salva le medie.
# Da eseguire sull'orchestratore (worker-1), da ~/hr. Uso: ./scala-dati-mongo.sh <tenant-start> <tenant-count> <label>
set -euo pipefail
start=${1:?serve tenant-start}
count=${2:?serve quanti nuovi tenant generare}
label=${3:?serve un label per il CSV (es. 60ditte)}
muser=${MONGO_USER:-admin}; mpass=${MONGO_PASSWORD:?imposta MONGO_PASSWORD}
out=generato_lotto_$label

echo "== genero tenant $start..$((start+count-1)) (no cataloghi, seed 42) =="
python3 data/genera.py --tenant-start "$start" --tenant-count "$count" --no-cataloghi --anno 2026 --jobs 8 --seed 42 --out "$out"
echo "== carico il lotto (mongoimport) =="
bash scripts/carica-mongo.sh "$out/mongo"
rm -rf "$out"

echo "== distribuzione chunk / conteggi =="
docker exec mongos mongosh --quiet --port 27017 -u "$muser" -p "$mpass" --authenticationDatabase admin archdata \
  --eval "print('cedolini='+db.cedolini.countDocuments({})); print('dipendenti='+db.dipendenti.countDocuments({}))"

echo "== misura a caldo =="
rm -f benchmark/results/mongo.csv
bash esegui-suite-mongo.sh 10 queries/document/letture/*.js >/dev/null
cp benchmark/results/mongo.csv "benchmark/results/scala_dati_mongo_${label}.csv"
echo "-> benchmark/results/scala_dati_mongo_${label}.csv"
