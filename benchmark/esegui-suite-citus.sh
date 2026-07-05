#!/bin/bash
# Esegue misura-citus.sh su piu' query in sequenza, accodando i risultati nel CSV. Sull'orchestratore.
# Uso: ./esegui-suite-citus.sh <durata_sec> <file-query...>
set -euo pipefail
dur=${1:?serve la durata in secondi}; shift
for q in "$@"; do
  bash misura-citus.sh "$q" "$dur"
  echo
done
echo "risultati in benchmark/results/citus.csv"
