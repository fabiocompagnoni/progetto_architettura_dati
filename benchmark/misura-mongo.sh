#!/bin/bash
# Misura una query Mongo a carico sostenuto (parallelo a misura-citus.sh). Da eseguire sull'orchestratore (worker-1, dove girano config server + mongos). 
# Carico via mongosh in loop; per-shard CPU/RAM da docker stats e disco da /proc via SSH; opcounters totali da serverStatus su mongos. 
# Uso: ./misura-mongo.sh <file.js> [durata_sec] [csv]
set -euo pipefail
qfile=${1:?serve il file query .js}
dur=${2:-10}
csv=${3:-benchmark/results/mongo.csv}
db=${MONGO_DB:-archdata}
muser=${MONGO_USER:-admin}
mpass=${MONGO_PASSWORD:?imposta MONGO_PASSWORD}
user=$(whoami)
qname=$(basename "$qfile" .js)
mongos() { docker exec -i mongos mongosh --quiet --port 27017 -u "$muser" -p "$mpass" --authenticationDatabase admin "$@"; }
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
snap_disk() { nssh "$1" "awk '\$3~/^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|xvd[a-z]+)\$/{r+=\$6;w+=\$10} END{print r+0, w+0}' /proc/diskstats"; }

# shard attivi: IP privati da config.shards (host tipo "shardN/10.0.1.5:27018")
mapfile -t SHARD < <(mongos --eval "db.getSiblingDB('config').shards.find().toArray().forEach(s=>print(s.host.replace(/^.*\//,'').replace(/:.*/,'')))")

# wrapper: la query in una funzione (const locali ad ogni chiamata) ripetuta per dur secondi
tmp=$(mktemp)
{ echo "function _run(){"; cat "$qfile"; echo "}"; echo "const _e=Date.now()+$dur*1000; let _n=0; while(Date.now()<_e){_run(); _n++;} print('ITER='+_n);"; } > "$tmp"

opc_before=$(mongos "$db" --eval "const o=db.serverStatus().opcounters; print(o.query+o.insert+o.update+o.delete+o.command)")
declare -A DR0 DW0
for ip in "${SHARD[@]}"; do d=$(snap_disk "$ip"); DR0[$ip]=${d%% *}; DW0[$ip]=${d##* }; done
for ip in "${SHARD[@]}"; do
  nssh "$ip" "nohup timeout $((dur+5)) sh -c 'while :; do docker stats --no-stream --format \"{{.CPUPerc}} {{.MemPerc}}\" mongo-shard; done' >/tmp/stats.txt 2>/dev/null &" || true
done

echo "== $qname · ${dur}s · ${#SHARD[@]} shard =="
t0=$(date +%s%3N)
iter=$(mongos "$db" < "$tmp" | sed -n 's/^ITER=//p')
t1=$(date +%s%3N)
rm -f "$tmp"
wall=$((t1-t0))
lat=$(awk "BEGIN{printf \"%.3f\", $wall/$iter}")
tps=$(awk "BEGIN{printf \"%.1f\", $iter*1000/$wall}")
echo "latenza ${lat} ms · throughput ${tps} op/s · iterazioni ${iter}"
sleep 1

opc_after=$(mongos "$db" --eval "const o=db.serverStatus().opcounters; print(o.query+o.insert+o.update+o.delete+o.command)")
declare -A DR1 DW1
for ip in "${SHARD[@]}"; do d=$(snap_disk "$ip"); DR1[$ip]=${d%% *}; DW1[$ip]=${d##* }; done

mkdir -p "$(dirname "$csv")"
[ -f "$csv" ] || echo "query,shard_totali,shard,cpu_pct,mem_pct,disk_read_mb,disk_write_mb,lat_ms,tps,iter,opcounters_delta" > "$csv"

echo; printf '%-10s %6s %6s %10s %10s\n' shard cpu% mem% discoR_MB discoW_MB
for ip in "${SHARD[@]}"; do
  cm=$(nssh "$ip" "awk '{gsub(/%/,\"\"); c+=\$1; m+=\$2; k++} END{if(k)printf \"%.1f %.1f\", c/k, m/k}' /tmp/stats.txt" || true)
  cpu=${cm%% *}; mem=${cm##* }; [ -n "$cpu" ] || { cpu=0; mem=0; }
  drm=$(awk "BEGIN{printf \"%.1f\", (${DR1[$ip]}-${DR0[$ip]})*512/1048576}")
  dwm=$(awk "BEGIN{printf \"%.1f\", (${DW1[$ip]}-${DW0[$ip]})*512/1048576}")
  printf '%-10s %6s %6s %10s %10s\n' "$ip" "$cpu" "$mem" "$drm" "$dwm"
  echo "$qname,${#SHARD[@]},$ip,$cpu,$mem,$drm,$dwm,$lat,$tps,$iter,$((opc_after-opc_before))" >> "$csv"
done
echo "-> $csv"