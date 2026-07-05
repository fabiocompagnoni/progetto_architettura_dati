#!/bin/bash
# Test di guasto Mongo (CP), parallelo a test-guasto-citus.sh: query in loop mentre uno shard viene spento e riacceso. Per ogni operazione registra tempo, shard spento, esito, righe, durata.
# Uso: ./test-guasto-mongo.sh <file-query.js> <ip-shard|random> [giu_dopo_s] [giu_per_s] [totale_s]
set -uo pipefail
qfile=${1:?serve il file query .js}
nodeip=${2:?serve l IP dello shard da spegnere (oppure 'random')}
downafter=${3:-10}; downfor=${4:-15}; total=${5:-45}
muser=${MONGO_USER:-admin}; mpass=${MONGO_PASSWORD:?imposta MONGO_PASSWORD}; db=${MONGO_DB:-archdata}; user=$(whoami)
mongos() { docker exec -i mongos mongosh --quiet --port 27017 -u "$muser" -p "$mpass" --authenticationDatabase admin "$@"; }
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
if [ "$nodeip" = random ]; then
  nodeip=$(mongos --eval "db.getSiblingDB('config').shards.find().toArray().forEach(s=>print(s.host.replace(/^.*\//,'').replace(/:.*/,'')))" | shuf -n1)
  echo "shard scelto a caso: $nodeip"
fi
qname=$(basename "$qfile" .js)
log=benchmark/results/guasto_mongo_${qname}_${nodeip//./-}_$(date +%H%M%S).csv
mkdir -p benchmark/results
echo "t_s,shard_giu,esito,righe,ms" > "$log"

echo "== guasto su $nodeip · query $qname · spengo a ${downafter}s, giu per ${downfor}s, totale ${total}s =="
start=$(date +%s%3N); killed=0; restarted=0
while :; do
  now=$(date +%s%3N); el=$(( now - start )); els=$(awk "BEGIN{printf \"%.1f\", $el/1000}")
  [ "$el" -ge $((total*1000)) ] && break
  if [ "$killed" = 0 ] && [ "$el" -ge $((downafter*1000)) ]; then
    nssh "$nodeip" "docker stop mongo-shard >/dev/null 2>&1" & killed=1; echo ">>> ${els}s: SPENGO $nodeip"
  fi
  if [ "$restarted" = 0 ] && [ "$el" -ge $(((downafter+downfor)*1000)) ]; then
    nssh "$nodeip" "docker start mongo-shard >/dev/null 2>&1" & restarted=1; echo ">>> ${els}s: RIACCENDO $nodeip"
  fi
  down="-"; [ "$killed" = 1 ] && [ "$restarted" = 0 ] && down="$nodeip"
  q0=$(date +%s%3N)
  out=$(timeout 5 docker exec -i mongos mongosh --quiet --port 27017 -u "$muser" -p "$mpass" --authenticationDatabase admin "$db" < "$qfile" 2>/dev/null); rc=$?
  q1=$(date +%s%3N)
  if [ "$rc" -eq 0 ] && [ -n "$out" ]; then esito=ok; righe=$(printf '%s' "$out" | grep -c .); else esito=err; righe=0; fi
  echo "$els,$down,$esito,$righe,$(( q1 - q0 ))" >> "$log"
  hb=$(( el / 2000 )); if [ "$hb" != "${lasthb:-x}" ]; then lasthb=$hb; echo "  t=${els}s  esito=$esito  righe=$righe  shard_giu=$down"; fi
done

awk -F, 'NR>1{n++; if($3=="err"){e++; if(!f)f=$1; l=$1}}
  END{printf "\noperazioni=%d  errori=%d (%.1f%%)\n", n, e, e?100*e/n:0;
      if(e) printf "finestra di errori: %.1fs -> %.1fs (durata ~%.1fs)\n", f, l, l-f}' "$log"
echo "timeline -> $log"