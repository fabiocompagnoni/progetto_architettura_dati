#!/bin/bash
# Setup PULITO del cluster MongoDB a 4 shard da zero (wipe totale -> deploy -> init -> add -> shard -> load).
# Da eseguire sull'orchestratore (worker-1). Richiede MONGO_PASSWORD e la chiave SSH verso i nodi.
# config server + mongos sono locali (worker-1); i 4 shard sono su VM-1/2/3/4 (via SSH con chiave).
set -uo pipefail
: "${MONGO_PASSWORD:?imposta MONGO_PASSWORD}"
user=$(whoami)
nssh() { ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "$user@$1" "$2"; }
mongo() { docker exec mongos mongosh --quiet -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin "$@"; }
declare -A IP=( [1]=10.0.1.4 [2]=10.0.1.5 [3]=10.0.1.7 [4]=10.0.1.6 )

echo "### 1/7 WIPE totale ###"
echo " - config+mongos (locale)"; ( cd ~/mongo && docker compose down -v ) >/dev/null 2>&1
for n in 1 2 3 4; do echo " - wipe shard$n (${IP[$n]})"; nssh "${IP[$n]}" "cd ~/mongo && docker compose down -v" >/dev/null 2>&1; done

echo "### 2/7 DEPLOY config+mongos + 4 shard ###"
echo " - config+mongos (locale)"; ( cd ~/mongo && docker compose up -d ) >/dev/null 2>&1
for n in 1 2 3 4; do echo " - up shard$n"; nssh "${IP[$n]}" "cd ~/mongo && printf 'MONGO_RS=shard$n\n' > .env && docker compose up -d" >/dev/null 2>&1; done
echo " - attendo avvio (15s)"; sleep 15

echo "### 3/7 INIT config server RS + admin ###"
( cd ~/mongo && MONGO_PASSWORD="$MONGO_PASSWORD" bash init-config.sh 10.0.1.8 ) >/dev/null 2>&1 && echo " - ok" || echo " - ERRORE init-config"

echo "### 4/7 INIT RS dei 4 shard ###"
for n in 1 2 3 4; do echo -n " - shard$n: "; nssh "${IP[$n]}" "cd ~/mongo && bash init-shard.sh shard$n ${IP[$n]}" 2>&1 | grep -oE "ok: [01]" | head -1; done
sleep 3

echo "### 5/7 ADD dei 4 shard ###"
for n in 1 2 3 4; do echo -n " - shard$n: "; mongo --eval "sh.addShard('shard$n/${IP[$n]}:27018')" 2>&1 | grep -oE "shardAdded[^,}]*|errmsg[^,}]*" | head -1; done
echo " - shard registrati:"; mongo --eval "db.getSiblingDB('config').shards.find().toArray().forEach(s=>print('   '+s._id+' '+s.host))"

echo "### 6/7 SHARDING collezioni (tenant_id hashed) ###"
( cd ~/mongo && MONGO_PASSWORD="$MONGO_PASSWORD" bash mongo-shard-collections.sh ) >/dev/null 2>&1 && echo " - ok" || echo " - ERRORE sharding"

echo "### 7/7 LOAD dati base (30 ditte / 554 dip) ###"
cd ~/hr && rm -rf generato && python3 data/genera.py --tenant-count 30 --dip-min 10 --dip-max 25 --anno 2026 --jobs 8 --seed 42 --out generato 2>&1 | tail -1
MONGO_CONTAINER=mongos bash scripts/carica-mongo.sh generato/mongo >/dev/null 2>&1
mongo archdata --eval "print(' - ditte='+db.ditte.countDocuments({})+'  dipendenti='+db.dipendenti.countDocuments({})+'  cedolini='+db.cedolini.countDocuments({}))"
echo "### CLUSTER 4-SHARD PRONTO ###"
