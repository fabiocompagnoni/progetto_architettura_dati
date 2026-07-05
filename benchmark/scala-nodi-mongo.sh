#!/bin/bash
# Scaling per numero di shard di MongoDB, dal numero di shard ATTUALE fino a 4. Per ogni passo (dal secondo
# in poi) aggiunge lo shard successivo, poi fa 3 run a freddo delle letture MOSTRANDO a schermo la query in
# corso, e salva grezzo in test_N_nodi_mongo.csv e medie in media_N_nodi_mongo.csv (con colonna chunk_mb).
# NB: a scala piccola il balancer Mongo non distribuisce (finding documentato), quindi NON si attende il
# balancer: i dati restano su shard1 e i risultati servono solo come confronto in tabella.
# Da eseguire sull'orchestratore (worker-1), da ~/hr. Uso: ./scala-nodi-mongo.sh <chunk_mb> [reset]
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

echo "== chunksize = ${CHUNK_MB} MB =="
mongo config --eval "db.settings.updateOne({_id:'chunksize'},{\$set:{_id:'chunksize',value:$CHUNK_MB}},{upsert:true})" >/dev/null

add_shard() {
  local n=$1 ip=${IP[$1]}
  [ "$(present "$n")" = "1" ] && return
  echo ">> aggiungo shard$n ($ip)"
  nssh "$ip" "cd ~/mongo && printf 'MONGO_RS=shard$n\n' > .env && docker compose up -d" >/dev/null 2>&1
  sleep 6
  nssh "$ip" "cd ~/mongo && bash init-shard.sh shard$n $ip" >/dev/null 2>&1
  sleep 3
  mongo --eval "sh.addShard('shard$n/$ip:27018')" >/dev/null 2>&1
  sleep 5
}

misura() {
  local N=$1
  rm -f "$RES/mongo.csv"
  for i in 1 2 3; do
    echo "--- run $i/3 (shard=$N) ---"
    bash azzera-cache-mongo.sh >/dev/null 2>&1
    bash esegui-suite-mongo.sh 10 queries/document/letture/*.js 2>&1 | grep -E "^== |latenza"
  done
  cp "$RES/mongo.csv" "$RES/test_${N}_nodi_mongo.csv"
  bash media-mongo.sh > "$RES/media_${N}_nodi_mongo.csv"
  echo "-> $RES/test_${N}_nodi_mongo.csv  +  $RES/media_${N}_nodi_mongo.csv"
}

start=$(nshard)
echo "== parto da ${start} shard, fino a 4 =="
for N in $(seq "$start" 4); do
  echo "========== $N SHARD =========="
  [ "$N" -gt "$start" ] && add_shard "$N"
  misura "$N"
done
[ "$RESET" = reset ] && { echo "== ripristino chunksize 128 MB =="; mongo config --eval "db.settings.updateOne({_id:'chunksize'},{\$set:{value:128}})" >/dev/null; }
echo "========== FINITO =========="
