#!/bin/bash
# Scalabilita' per volume di dati Mongo a 4 shard FISSI: si spinge il volume MOLTO oltre Postgres per vedere
# il potenziale massimo di MongoDB (a scala grande il balancer distribuisce da solo). Dati a lotti
# (genera->carica->rm); dopo ogni lotto attende il balancer, mostra dimensione+distribuzione, misura a caldo
# mostrando ogni query, e salva. Il collector randomizza tenant/dip/mese (colpisce shard diversi).
# Da eseguire sull'orchestratore (worker-1), da ~/hr. Richiede MONGO_PASSWORD e 4 shard gia' attivi.
# Uso: ./scala-dati-mongo.sh <chunk_mb> <batch1> [batch2 ...]
set -uo pipefail
: "${MONGO_PASSWORD:?imposta MONGO_PASSWORD}"
CHUNK_MB=${1:?serve la chunksize in MB}; shift
BATCHES=("$@"); [ ${#BATCHES[@]} -gt 0 ] || { echo "servono uno o piu' batch di tenant"; exit 1; }
RES=benchmark/results
mongo() { docker exec mongos mongosh --quiet -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin "$@"; }

nshard=$(mongo --eval 'print(db.getSiblingDB("config").shards.countDocuments({}))' | tail -1)
echo "== chunksize = ${CHUNK_MB} MB · shard attivi: ${nshard} =="
mongo config --eval "db.settings.updateOne({_id:'chunksize'},{\$set:{_id:'chunksize',value:$CHUNK_MB}},{upsert:true})" >/dev/null
mongo --eval "sh.startBalancer()" >/dev/null 2>&1 || true

stato() {
  mongo archdata --eval '
    print("   cedolini = "+db.cedolini.countDocuments({})+" doc, "+(db.cedolini.stats().size/1048576).toFixed(1)+" MB");
    const u=db.getSiblingDB("config").collections.findOne({_id:"archdata.cedolini"}).uuid;
    db.getSiblingDB("config").chunks.aggregate([{$match:{uuid:u}},{$group:{_id:"$shard",n:{$sum:1}}},{$sort:{_id:1}}]).forEach(x=>print("     "+x._id+": "+x.n+" chunk"))'
}

wait_distribute() {   # attende che cedolini sia su tutti gli shard, mostrando i progressi ogni 20s
  local t=0 n
  while [ $t -lt 300 ]; do
    n=$(mongo archdata --eval 'const u=db.getSiblingDB("config").collections.findOne({_id:"archdata.cedolini"}).uuid; print(db.getSiblingDB("config").chunks.distinct("shard",{uuid:u}).length)' | tail -1)
    echo "     ...cedolini su ${n:-?}/${nshard} shard (t=${t}s)"
    [ "${n:-1}" -ge "$nshard" ] && { echo "     -> distribuito su tutti gli shard"; return; }
    sleep 20; t=$((t+20))
  done
  echo "     -> timeout: cedolini su ${n:-?}/${nshard} shard (proseguo)"
}

cur=$(mongo archdata --eval "print(db.ditte.countDocuments({}))" | tail -1)
echo "== ditte attuali: $cur =="
for b in "${BATCHES[@]}"; do
  s=$((cur+1)); tot=$((cur+b))
  echo ""
  echo "############################################################"
  echo "# STADIO: +$b tenant ($s..$((tot)))  ->  totale $tot ditte"
  echo "############################################################"
  echo ">> [1/5] genero $b tenant (seed 42)..."
  python3 data/genera.py --tenant-start "$s" --tenant-count "$b" --no-cataloghi --anno 2026 --jobs 8 --seed 42 --out generato_lotto
  echo ">> [2/5] carico nel cluster (mongoimport via mongos)..."
  MONGO_CONTAINER=mongos bash scripts/carica-mongo.sh generato_lotto/mongo 2>&1 | tail -1
  rm -rf generato_lotto
  cur=$tot
  echo ">> [3/5] attendo il balancer (distribuzione cedolini):"
  wait_distribute
  echo ">> [4/5] stato dati e distribuzione per shard:"
  stato
  echo ">> [5/5] misuro le 13 letture a caldo (carico randomizzato):"
  rm -f "$RES/mongo.csv"
  bash esegui-suite-mongo.sh 10 queries/document/letture/*.js 2>&1 | grep -E "^== |latenza"
  cp "$RES/mongo.csv" "$RES/scala_dati_mongo_${cur}ditte.csv"
  bash media-mongo.sh > "$RES/media_dati_mongo_${cur}ditte.csv"
  echo "== salvato: scala_dati_mongo_${cur}ditte.csv + media_dati_mongo_${cur}ditte.csv =="
done
echo ""
echo "########## DATA-SCALING MONGO COMPLETO ##########"
