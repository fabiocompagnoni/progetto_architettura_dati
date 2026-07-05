#!/bin/bash
# Misura una query di scrittura riusando il file pulito di queries/: la ripete N volte su una connessione
# persistente (psql gestisce \if/\gset/:'...') e raccoglie per-nodo WAL/righe/exec + CPU/disco + latenza.
# Da eseguire sull'orchestratore. Uso: ./misura-scrittura-citus.sh <file-query> [N] [csv]
set -euo pipefail
qfile=${1:?serve il file query}
N=${2:-500}
csv=${3:-benchmark/results/citus-scritture.csv}
user=$(whoami)
qname=$(basename "$qfile" .sql)
psql() { docker exec -i citus psql -U postgres -d archdata "$@"; }
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
snap_disk() { nssh "$1" "awk '\$3~/^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|xvd[a-z]+)\$/{r+=\$6;w+=\$10} END{print r+0, w+0}' /proc/diskstats"; }

NODI=(); declare -A RUOLO
while IFS='|' read -r nn gid; do NODI+=("$nn"); RUOLO[$nn]=$([ "$gid" = 0 ] && echo coord || echo worker); done \
  < <(psql -tAF'|' -c "SELECT nodename, groupid FROM pg_dist_node WHERE isactive ORDER BY groupid")
nworker=$(psql -tAc "SELECT count(*) FROM pg_dist_node WHERE isactive AND groupid<>0")

# script = file pulito ripetuto N volte
tmp=$(mktemp)
for ((i=0; i<N; i++)); do cat "$qfile"; echo; done > "$tmp"
psql -qtAc "SELECT run_command_on_all_nodes('SELECT pg_stat_statements_reset()')" >/dev/null

declare -A DR0 DW0
for ip in "${NODI[@]}"; do d=$(snap_disk "$ip"); DR0[$ip]=${d%% *}; DW0[$ip]=${d##* }; done
for ip in "${NODI[@]}"; do
  nssh "$ip" "nohup timeout 120 sh -c 'while :; do docker stats --no-stream --format \"{{.CPUPerc}} {{.MemPerc}}\" citus; done' >/tmp/stats.txt 2>/dev/null &" || true
done

echo "== $qname · N=$N · $nworker worker =="
t0=$(date +%s%3N)
docker exec -i citus psql -U postgres -d archdata -q -v ON_ERROR_STOP=0 -f - < "$tmp" >/dev/null 2>&1
t1=$(date +%s%3N)
rm -f "$tmp"
for ip in "${NODI[@]}"; do nssh "$ip" "pkill -f 'docker stats' 2>/dev/null" || true; done
wall=$((t1 - t0))
lat=$(awk "BEGIN{printf \"%.3f\", $wall/$N}")
tps=$(awk "BEGIN{printf \"%.1f\", $N*1000/$wall}")
echo "latenza ${lat} ms/op · throughput ${tps} op/s · totale ${wall} ms"
sleep 1

declare -A DR1 DW1
for ip in "${NODI[@]}"; do d=$(snap_disk "$ip"); DR1[$ip]=${d%% *}; DW1[$ip]=${d##* }; done
declare -A EX RI WA
while IFS='|' read -r nn ex ri wa; do EX[$nn]=$ex; RI[$nn]=$ri; WA[$nn]=$wa; done < <(psql -tAF'|' -c "
  SELECT n.nodename, r.result::json->>'exec', r.result::json->>'righe', r.result::json->>'wal'
  FROM run_command_on_all_nodes(\$\$
    SELECT json_build_object('exec',round(coalesce(sum(total_exec_time),0)::numeric,1),
      'righe',coalesce(sum(rows),0),'wal',coalesce(sum(wal_bytes),0))
    FROM pg_stat_statements
    WHERE query NOT ILIKE '%pg_stat_statements%' AND query NOT ILIKE '%run_command_on_all_nodes%'
  \$\$) r JOIN pg_dist_node n ON n.nodeid = r.nodeid")

mkdir -p "$(dirname "$csv")"
[ -f "$csv" ] || echo "query,worker,nodo,ruolo,cpu_pct,mem_pct,exec_ms,righe,wal_bytes,disk_write_mb,lat_ms,tps" > "$csv"

echo; printf '%-10s %6s %5s %9s %8s %12s %10s\n' nodo ruolo cpu% exec_ms righe wal_bytes discoW_MB
for ip in "${NODI[@]}"; do
  cm=$(nssh "$ip" "awk '{gsub(/%/,\"\"); c+=\$1; m+=\$2; k++} END{if(k)printf \"%.1f %.1f\", c/k, m/k}' /tmp/stats.txt" || true)
  cpu=${cm%% *}; mem=${cm##* }; [ -n "$cpu" ] || { cpu=0; mem=0; }
  dwm=$(awk "BEGIN{printf \"%.1f\", (${DW1[$ip]}-${DW0[$ip]})*512/1048576}")
  printf '%-10s %6s %5s %9s %8s %12s %10s\n' "$ip" "${RUOLO[$ip]}" "$cpu" "${EX[$ip]:-}" "${RI[$ip]:-}" "${WA[$ip]:-}" "$dwm"
  echo "$qname,$nworker,$ip,${RUOLO[$ip]},$cpu,$mem,${EX[$ip]:-},${RI[$ip]:-},${WA[$ip]:-},$dwm,$lat,$tps" >> "$csv"
done
echo "-> $csv"
