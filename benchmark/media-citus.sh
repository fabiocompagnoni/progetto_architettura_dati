#!/bin/bash
# Media dei run nel CSV, raggruppando per (query, worker, ruolo). Sull'orchestratore.
# Uso: ./media-citus.sh [csv]
csv=${1:-benchmark/results/citus.csv}
awk -F, 'NR>1 {
  k=$1"|"$2"|"$4
  q[k]=$1; w[k]=$2; r[k]=$4
  cpu[k]+=$5; mem[k]+=$6; ex[k]+=$7; ri[k]+=$8; br[k]+=$9; dr[k]+=$10; dw[k]+=$11; wal[k]+=$12; lat[k]+=$13; tps[k]+=$14; n[k]++
}
END{
  print "query,worker,ruolo,runs,cpu%,mem%,exec_ms,righe,blk_read,disk_r_mb,disk_w_mb,wal,lat_ms,tps"
  for (k in n) printf "%s,%s,%s,%d,%.1f,%.1f,%.1f,%.0f,%.0f,%.2f,%.2f,%.0f,%.3f,%.1f\n",
    q[k],w[k],r[k],n[k],cpu[k]/n[k],mem[k]/n[k],ex[k]/n[k],ri[k]/n[k],br[k]/n[k],dr[k]/n[k],dw[k]/n[k],wal[k]/n[k],lat[k]/n[k],tps[k]/n[k]
}' "$csv" | sort -t, -k1,1 -k2,2n -k3,3
