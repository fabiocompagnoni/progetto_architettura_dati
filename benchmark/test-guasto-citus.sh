#!/bin/bash
# Test di guasto (comportamento CP): esegue una query in loop mentre un nodo viene spento e poi riacceso.
# Per ogni operazione registra nel CSV: tempo, nodo spento in quel momento, esito, righe restituite, durata.
# Cosi' si vede se/quando la query fallisce e come cambia il risultato (righe) col nodo giu' e al recupero.
# Da eseguire sull'orchestratore. Uso: ./test-guasto-citus.sh <file-query> <ip-nodo> [giu_dopo_s] [giu_per_s] [totale_s]
set -uo pipefail   # NON -e: durante il guasto le query falliscono di proposito
qfile=${1:?serve il file query}
nodeip=${2:?serve l IP del nodo da spegnere (oppure 'random' per un worker a caso)}
downafter=${3:-10}; downfor=${4:-15}; total=${5:-45}
user=$(whoami)
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
# 'random' -> sceglie un worker attivo a caso dal catalogo
if [ "$nodeip" = random ]; then
  nodeip=$(docker exec -i citus psql -U postgres -d archdata -tAc \
    "SELECT nodename FROM pg_dist_node WHERE isactive AND groupid<>0" | shuf -n1)
  echo "nodo scelto a caso: $nodeip"
fi
qname=$(basename "$qfile" .sql)
sql=$(grep -vE '^\\' "$qfile")            # toglie i meta psql, lascia la SQL
log=benchmark/results/guasto_${qname}.csv
mkdir -p benchmark/results
echo "t_s,nodo_giu,esito,righe,ms" > "$log"

echo "== guasto su $nodeip · query $qname · spengo a ${downafter}s, giu per ${downfor}s, totale ${total}s =="
start=$(date +%s%3N); killed=0; restarted=0
while :; do
  now=$(date +%s%3N); el=$(( now - start )); els=$(awk "BEGIN{printf \"%.1f\", $el/1000}")
  [ "$el" -ge $((total*1000)) ] && break
  if [ "$killed" = 0 ] && [ "$el" -ge $((downafter*1000)) ]; then
    nssh "$nodeip" "docker stop citus >/dev/null 2>&1" & killed=1; echo ">>> ${els}s: SPENGO $nodeip"
  fi
  if [ "$restarted" = 0 ] && [ "$el" -ge $(((downafter+downfor)*1000)) ]; then
    nssh "$nodeip" "docker start citus >/dev/null 2>&1" & restarted=1; echo ">>> ${els}s: RIACCENDO $nodeip"
  fi
  # nodo segnato "giu" tra spegnimento e riaccensione (il recupero effettivo si legge dagli esiti err successivi)
  down="-"; [ "$killed" = 1 ] && [ "$restarted" = 0 ] && down="$nodeip"
  q0=$(date +%s%3N)
  out=$(timeout 3 docker exec -i citus psql -U postgres -d archdata -qtAc "$sql" 2>/dev/null); rc=$?
  q1=$(date +%s%3N)
  if [ "$rc" -eq 0 ]; then esito=ok; righe=$(printf '%s' "$out" | grep -c .); else esito=err; righe=0; fi
  echo "$els,$down,$esito,$righe,$(( q1 - q0 ))" >> "$log"
done

awk -F, 'NR>1{n++; if($3=="err"){e++; if(!f)f=$1; l=$1}}
  END{printf "\noperazioni=%d  errori=%d (%.1f%%)\n", n, e, e?100*e/n:0;
      if(e) printf "finestra di errori: %.1fs -> %.1fs (durata ~%.1fs)\n", f, l, l-f}' "$log"
echo "timeline -> $log"
