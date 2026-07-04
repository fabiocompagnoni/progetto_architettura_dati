#!/bin/bash
# Abilita lo sharding su archdata e distribuisce le collezioni per tenant_id (hashed, come Citus).
# Da eseguire su worker-1 (via mongos). Serve MONGO_PASSWORD nell'ambiente.
set -euo pipefail
docker exec mongos mongosh --quiet -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin archdata --eval '
  sh.enableSharding("archdata");
  ["ditte", "dipendenti", "cedolini"].forEach(c => {
    db[c].createIndex({ tenant_id: "hashed" });
    sh.shardCollection("archdata." + c, { tenant_id: "hashed" });
  });
  sh.status();
'
