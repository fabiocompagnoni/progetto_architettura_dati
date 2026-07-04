#!/bin/bash
# Inizializza il config server (RS a 1 membro) e crea l'utente admin (localhost exception, una volta).
# Da eseguire su worker-1. Arg: IP privato del coordinator. Serve MONGO_PASSWORD nell'ambiente.
set -euo pipefail
IP=${1:-10.0.1.8}
docker exec mongo-configsvr mongosh --quiet --port 27019 --eval \
  "rs.initiate({_id:'cfgrs', configsvr:true, members:[{_id:0, host:'$IP:27019'}]})"
sleep 5
docker exec mongo-configsvr mongosh --quiet --port 27019 --eval \
  "db.getSiblingDB('admin').createUser({user:'admin', pwd:'$MONGO_PASSWORD', roles:['root']})"
