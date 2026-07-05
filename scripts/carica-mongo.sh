#!/usr/bin/env bash
# Carica i file JSONL generati nelle collezioni MongoDB via mongoimport, attraverso mongos (con auth).
set -euo pipefail

dir=${1:-data/generato/mongo}
container=${MONGO_CONTAINER:-mongos}
: "${MONGO_PASSWORD:?imposta MONGO_PASSWORD}"

for coll in comuni ateco tipi_voce tipi_contributo causali ditte dipendenti cedolini; do
  for f in "$dir/${coll}_p"*.jsonl "$dir/${coll}_cat.jsonl"; do
    [ -e "$f" ] || continue
    docker exec -i "$container" mongoimport --host localhost:27017 \
      -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin \
      --db archdata --collection "$coll" --type json --numInsertionWorkers 4 --quiet < "$f"
  done
done
echo "caricamento Mongo completato da $dir"
