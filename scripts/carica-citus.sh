#!/usr/bin/env bash
# Carica i file COPY generati nel cluster Citus, rispettando l'ordine delle foreign key
# (prima i cataloghi/reference, poi i dati del tenant dai genitori ai figli).
set -euo pipefail

dir=${1:-data/generato/citus}
psql="docker exec -i citus-coordinator psql -U postgres -d archdata -q -v ON_ERROR_STOP=1"

ordine=(
  settore_ccnl ccnl suddivisione livello comune ateco tipo_voce tipo_contributo causale_assenza
  ditta persona_giuridica persona_fisica indirizzo centro_di_costo unita_appartenenza ditta_ateco ditta_ccnl
  dipendente contratto cedolino voce_cedolino rateo contributo addizionale giorno timbratura assenza
)

for t in "${ordine[@]}"; do
  for f in "$dir/${t}_p"*.sql "$dir/${t}_cat.sql"; do
    [ -e "$f" ] || continue
    $psql < "$f"
  done
done
echo "caricamento Citus completato da $dir"
