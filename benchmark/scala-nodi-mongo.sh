#!/bin/bash
# Scaling per numero di shard di MongoDB, in sequenza dal numero di shard ATTUALE fino a 4. Per ogni passo
# (dal secondo in poi) aggiunge lo shard successivo e attende il balancer, poi fa 3 run a freddo delle
# letture e salva il grezzo in test_N_nodi_mongo.csv e le medie in media_N_nodi_mongo.csv (con la colonna
# chunk_mb dal collector). Da eseguire sull'orchestratore (worker-1), da ~/hr. Richiede MONGO_PASSWORD.
# Uso: ./scala-nodi-mongo.sh <chunk_mb> [reset]
#   <chunk_mb> : chunksize da impostare (deve stare sotto ~13 MB perche' cedolini ~41 MB si distribuisca)
#   reset      : (opzionale) a fine run ripristina la chunksize a 128 MB
# NB: parti dal numero di shard voluto (rimuovi a mano gli shard extra per iniziare da 1).
set -uo pipefail
: "${MONGO_PASSWORD:?imposta MONGO_PASSWORD}"
CHUNK_MB=${1:?serve la chunksize in MB (es. 4)}
RESET=${2:-}
RES=benchmark/results
user=$(whoami)
mongo() { docker exec mongos mongosh --quiet -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin "$@"; }
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
declare -A IP=( [1]=10.0.1.4 [2]=10.0.1.5 [3]=10.0.1.7 [4]=10.0.1.6 )
present() { mongo --eval "print(db.getSiblingDB('config').shards.countDocuments({_id:'shard$1'}))" | tail -1; }
nshard()  { mongo --eval "print(db.getSiblingDB('config').shards.countDocuments({}))" | tail -1; }

echo "== chunksize = ${CHUNK_MB} MB + balancer on =="
mongo config --eval "db.settings.updateOne({_id:'chunksize'},{\$set:{_id:'chunksize',value:$CHUNK_MB}},{upsert:true})" >/dev/null
mongo --eval "sh.startBalancer()" >/dev/null 2>&1 || true

add_shard() {
  local n=$1 ip=${IP[$1]}
  [ "$(present "$n")" = "1" ] && return
  echo "aggiungo shard$n ($ip)"
  nssh "$ip" "cd ~/mongo && printf 'MONGO_RS=shard$n\n' > .env && docker compose up -d" >/dev/null 2>&1
  sleep 6
  nssh "$ip" "cd ~/mongo && bash init-shard.sh shard$n $ip" >/dev/null 2>&1
  sleep 3
  mongo --eval "sh.addShard('shard$n/$ip:27018')" >/dev/null 2>&1
}

wait_balance() {   # attende che i chunk siano su $1 shard (cedolini distribuito), o timeout 240s
  local target=$1 t=0 n=0
  while [ $t -lt 240 ]; do
    n=$(mongo --eval "print(db.getSiblingDB('config').chunks.distinct('shard').length)" 2>/dev/null | tail -1)
    [ "${n:-0}" -ge "$target" ] && { echo "balancer ok: chunk su $n shard"; return; }
    sleep 15; t=$((t+15))
  done
  echo "balancer: timeout, chunk su ${n} shard (proseguo comunque)"
}

misura() {
  local N=$1
  rm -f "$RES/mongo.csv"
  for i in 1 2 3; do
    bash azzera-cache-mongo.sh >/dev/null 2>&1
    bash esegui-suite-mongo.sh 10 queries/document/letture/*.js >/dev/null 2>&1
  done
  cp "$RES/mongo.csv" "$RES/test_${N}_nodi_mongo.csv"
  bash media-mongo.sh > "$RES/media_${N}_nodi_mongo.csv"
  echo "-> test_${N}_nodi_mongo.csv + media_${N}_nodi_mongo.csv"
}

start=$(nshard)
echo "== parto da ${start} shard, fino a 4 =="
for N in $(seq "$start" 4); do
  echo "========== $N SHARD =========="
  if [ "$N" -gt "$start" ]; then add_shard "$N"; wait_balance "$N"; fi
  misura "$N"
done
[ "$RESET" = reset ] && { echo "== ripristino chunksize 128 MB =="; mongo config --eval "db.settings.updateOne({_id:'chunksize'},{\$set:{value:128}})" >/dev/null; }
echo "========== SCALING MONGO COMPLETO =========="
