#!/bin/bash
# Esegue misura-scrittura-citus.sh su piu' query di scrittura in sequenza, accodando nel CSV.
# D01 (cancellazione distruttiva) va misurata a parte, con reload dei dati dopo. Sull'orchestratore.
# Uso: ./esegui-scritture-citus.sh <N> <file-query...>
set -euo pipefail
N=${1:?serve il numero di ripetizioni}; shift
for q in "$@"; do
  case "$(basename "$q")" in
    D01_*) echo "salto $(basename "$q") (distruttiva: misurala a parte)"; continue;;
  esac
  bash misura-scrittura-citus.sh "$q" "$N"
  echo
done
echo "risultati in benchmark/results/citus-scritture.csv"
