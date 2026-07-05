#!/bin/bash
# Esegue misura-mongo.sh su piu' query in sequenza, accodando nel CSV. Sull'orchestratore.
# Uso: ./esegui-suite-mongo.sh <durata_sec> <file-query...>
set -euo pipefail
dur=${1:?serve la durata in secondi}; shift
for q in "$@"; do
  bash misura-mongo.sh "$q" "$dur"
  echo
done
echo "risultati in benchmark/results/mongo.csv"
