#!/bin/bash
# Esegue misura-scrittura-mongo.sh su piu' query di scrittura in sequenza. D01 (distruttiva) va a parte.
# Sull'orchestratore. Uso: ./esegui-scritture-mongo.sh <N> <file-query...>
set -euo pipefail
N=${1:?serve il numero di ripetizioni}; shift
for q in "$@"; do
  case "$(basename "$q")" in
    D01_*) echo "salto $(basename "$q") (distruttiva: misurala a parte)"; continue;;
  esac
  bash misura-scrittura-mongo.sh "$q" "$N"
  echo
done
echo "risultati in benchmark/results/mongo-scritture.csv"
