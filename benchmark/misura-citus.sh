#!/bin/bash
# Misura una query Citus a carico sostenuto e accoda i risultati per-nodo in un CSV. Sull'orchestratore.
# Uso: ./misura-citus.sh <file-query> [durata_sec] [csv]
set -euo pipefail
qfile=${1:?serve il file query}
dur=${2:-10}
csv=${3:-benchmark/results/citus.csv}
user=$(whoami)
qname=$(basename "$qfile" .sql)
psql() { docker exec -i citus psql -U postgres -d archdata "$@"; }
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
# settori letti/scritti dai soli dischi interi (esclude le partizioni)
snap_disk() { nssh "$1" "awk '\$3~/^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|xvd[a-z]+)\$/{r+=\$6;w+=\$10} END{print r+0, w+0}' /proc/diskstats"; }

NODI=(); declare -A RUOLO
while IFS='|' read -r nn gid; do NODI+=("$nn"); RUOLO[$nn]=$([ "$gid" = 0 ] && echo coord || echo worker); done \
  < <(psql -tAF'|' -c "SELECT nodename, groupid FROM pg_dist_node WHERE isactive ORDER BY groupid")
nworker=$(psql -tAc "SELECT count(*) FROM pg_dist_node WHERE isactive AND groupid<>0")

grep -vE '^\\(if|else|endif|set|gset)' "$qfile" | docker exec -i citus bash -c 'cat > /tmp/q.sql'
psql -qtAc "SELECT run_command_on_all_nodes('SELECT pg_stat_statements_reset()')" >/dev/null

declare -A DR0 DW0
for ip in "${NODI[@]}"; do d=$(snap_disk "$ip"); DR0[$ip]=${d%% *}; DW0[$ip]=${d##* }; done
for ip in "${NODI[@]}"; do
  nssh "$ip" "nohup timeout $dur sh -c 'while :; do docker stats --no-stream --format \"{{.CPUPerc}} {{.MemPerc}}\" citus; done' >/tmp/stats.txt 2>/dev/null &" || true
done

echo "== $qname · ${dur}s · $nworker worker =="
pgout=$(docker exec citus pgbench -n -T "$dur" -c 1 -f /tmp/q.sql \
  -D tenant=1 -D dip=1 -D anno=2026 -D mese=6 -D n=20 -D cid=900001 -U postgres archdata 2>&1)
lat=$(echo "$pgout" | awk -F'= ' '/latency average/{print $2+0}')
tps=$(echo "$pgout" | awk -F'= ' '/tps/{print $2+0; exit}')
echo "latenza ${lat} ms · tps ${tps}"
sleep 1

declare -A DR1 DW1
for ip in "${NODI[@]}"; do d=$(snap_disk "$ip"); DR1[$ip]=${d%% *}; DW1[$ip]=${d##* }; done
declare -A EX RI BR WA
while IFS='|' read -r nn ex ri br wa; do EX[$nn]=$ex; RI[$nn]=$ri; BR[$nn]=$br; WA[$nn]=$wa; done < <(psql -tAF'|' -c "
  SELECT n.nodename, r.result::json->>'exec', r.result::json->>'righe', r.result::json->>'br', r.result::json->>'wal'
  FROM run_command_on_all_nodes(\$\$
    SELECT json_build_object('exec',round(coalesce(sum(total_exec_time),0)::numeric,1),
      'righe',coalesce(sum(rows),0),'br',coalesce(sum(shared_blks_read),0),'wal',coalesce(sum(wal_bytes),0))
    FROM pg_stat_statements
    WHERE query NOT ILIKE '%pg_stat_statements%' AND query NOT ILIKE '%run_command_on_all_nodes%'
  \$\$) r JOIN pg_dist_node n ON n.nodeid = r.nodeid")

mkdir -p "$(dirname "$csv")"
[ -f "$csv" ] || echo "query,worker,nodo,ruolo,cpu_pct,mem_pct,exec_ms,righe,blk_read,disk_read_mb,disk_write_mb,wal_bytes,lat_ms,tps" > "$csv"

echo; printf '%-10s %6s %5s %5s %9s %8s %8s %9s %9s %9s\n' nodo ruolo cpu% mem% exec_ms righe blk_read discoR_MB discoW_MB wal
for ip in "${NODI[@]}"; do
  cm=$(nssh "$ip" "awk '{gsub(/%/,\"\"); c+=\$1; m+=\$2; k++} END{if(k)printf \"%.1f %.1f\", c/k, m/k}' /tmp/stats.txt" || true)
  cpu=${cm%% *}; mem=${cm##* }; [ -n "$cpu" ] || { cpu=0; mem=0; }
  drm=$(awk "BEGIN{printf \"%.1f\", (${DR1[$ip]}-${DR0[$ip]})*512/1048576}")
  dwm=$(awk "BEGIN{printf \"%.1f\", (${DW1[$ip]}-${DW0[$ip]})*512/1048576}")
  printf '%-10s %6s %5s %5s %9s %8s %8s %9s %9s %9s\n' "$ip" "${RUOLO[$ip]}" "$cpu" "$mem" "${EX[$ip]:-}" "${RI[$ip]:-}" "${BR[$ip]:-}" "$drm" "$dwm" "${WA[$ip]:-}"
  echo "$qname,$nworker,$ip,${RUOLO[$ip]},$cpu,$mem,${EX[$ip]:-},${RI[$ip]:-},${BR[$ip]:-},$drm,$dwm,${WA[$ip]:-},$lat,$tps" >> "$csv"
done
echo "-> $csv"
