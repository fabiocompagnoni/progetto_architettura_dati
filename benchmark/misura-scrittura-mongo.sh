#!/bin/bash
# Misura una scrittura Mongo (parallelo a misura-scrittura-citus.sh): ripete la query N volte in una sessione mongosh; per-shard CPU/disco + opcounters totali. 
# Uso: ./misura-scrittura-mongo.sh <file.js> [N] [csv]
set -euo pipefail
qfile=${1:?serve il file query .js}
N=${2:-500}
csv=${3:-benchmark/results/mongo-scritture.csv}
db=${MONGO_DB:-archdata}; muser=${MONGO_USER:-admin}; mpass=${MONGO_PASSWORD:?imposta MONGO_PASSWORD}; user=$(whoami)
qname=$(basename "$qfile" .js)
mongos() { docker exec -i mongos mongosh --quiet --port 27017 -u "$muser" -p "$mpass" --authenticationDatabase admin "$@"; }
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
snap_disk() { nssh "$1" "awk '\$3~/^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|xvd[a-z]+)\$/{r+=\$6;w+=\$10} END{print r+0, w+0}' /proc/diskstats"; }
mapfile -t SHARD < <(mongos --eval "db.getSiblingDB('config').shards.find().toArray().forEach(s=>print(s.host.replace(/^.*\//,'').replace(/:.*/,'')))")

# script = query in una funzione, ripetuta N volte a tenant FISSO (parallelo a Citus): la scrittura di un
# tenant colpisce un solo shard -> mostra la co-locazione, coerente col finding sulle scritture di Citus.
tmp=$(mktemp)
{ echo "function _run(){"; cat "$qfile"; echo "}"; echo "for(let i=0;i<$N;i++){_run();} print('DONE');"; } > "$tmp"
opc0=$(mongos "$db" --eval "const o=db.serverStatus().opcounters; print(o.insert+o.update+o.delete)")
declare -A DR0 DW0
for ip in "${SHARD[@]}"; do d=$(snap_disk "$ip"); DR0[$ip]=${d%% *}; DW0[$ip]=${d##* }; done
for ip in "${SHARD[@]}"; do
  nssh "$ip" "nohup timeout 120 sh -c 'while :; do docker stats --no-stream --format \"{{.CPUPerc}} {{.MemPerc}}\" mongo-shard; done' >/tmp/stats.txt 2>/dev/null &" || true
done

echo "== $qname · N=$N · ${#SHARD[@]} shard =="
t0=$(date +%s%3N)
mongos "$db" < "$tmp" >/dev/null 2>&1
t1=$(date +%s%3N)
rm -f "$tmp"
for ip in "${SHARD[@]}"; do nssh "$ip" "pkill -f 'docker stats' 2>/dev/null" || true; done
wall=$((t1 - t0)); lat=$(awk "BEGIN{printf \"%.3f\", $wall/$N}"); tps=$(awk "BEGIN{printf \"%.1f\", $N*1000/$wall}")
echo "latenza ${lat} ms/op · throughput ${tps} op/s"
sleep 1
opc1=$(mongos "$db" --eval "const o=db.serverStatus().opcounters; print(o.insert+o.update+o.delete)")
declare -A DR1 DW1
for ip in "${SHARD[@]}"; do d=$(snap_disk "$ip"); DR1[$ip]=${d%% *}; DW1[$ip]=${d##* }; done

mkdir -p "$(dirname "$csv")"
[ -f "$csv" ] || echo "query,shard_totali,shard,cpu_pct,mem_pct,disk_write_mb,lat_ms,tps,writes_delta" > "$csv"

echo; printf '%-10s %6s %6s %10s\n' shard cpu% mem% discoW_MB
for ip in "${SHARD[@]}"; do
  cm=$(nssh "$ip" "awk '{gsub(/%/,\"\"); c+=\$1; m+=\$2; k++} END{if(k)printf \"%.1f %.1f\", c/k, m/k}' /tmp/stats.txt" || true)
  cpu=${cm%% *}; mem=${cm##* }; [ -n "$cpu" ] || { cpu=0; mem=0; }
  dwm=$(awk "BEGIN{printf \"%.1f\", (${DW1[$ip]}-${DW0[$ip]})*512/1048576}")
  printf '%-10s %6s %6s %10s\n' "$ip" "$cpu" "$mem" "$dwm"
  echo "$qname,${#SHARD[@]},$ip,$cpu,$mem,$dwm,$lat,$tps,$((opc1-opc0))" >> "$csv"
done
echo "-> $csv"