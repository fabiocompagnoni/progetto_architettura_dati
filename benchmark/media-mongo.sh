#!/bin/bash
# Media dei run nel CSV Mongo, raggruppando per (query, shard). Sull'orchestratore.
# Uso: ./media-mongo.sh [csv]
csv=${1:-benchmark/results/mongo.csv}
awk -F, 'NR>1 {
  k=$1"|"$3
  q[k]=$1; st[k]=$2; sh[k]=$3
  cpu[k]+=$4; mem[k]+=$5; dr[k]+=$6; dw[k]+=$7; lat[k]+=$8; tps[k]+=$9; it[k]+=$10; op[k]+=$11; ck[k]=$12; n[k]++
}
END{
  print "query,shard_totali,shard,runs,cpu_pct,mem_pct,disk_read_mb,disk_write_mb,lat_ms,tps,iter,opcounters_delta,chunk_mb"
  for (k in n) printf "%s,%s,%s,%d,%.1f,%.1f,%.2f,%.2f,%.3f,%.1f,%.0f,%.0f,%s\n",
    q[k],st[k],sh[k],n[k],cpu[k]/n[k],mem[k]/n[k],dr[k]/n[k],dw[k]/n[k],lat[k]/n[k],tps[k]/n[k],it[k]/n[k],op[k]/n[k],ck[k]
}' "$csv" | sort -t, -k1,1 -k3,3
