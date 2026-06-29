#!/usr/bin/env bash
set -euo pipefail

# Verifica che il replica set sia inizializzato e che le transazioni siano usabili.
echo "Stato replica set:"
docker exec -i mongo mongosh --quiet --eval \
  'const s = rs.status(); print(s.set + " / " + s.members[0].stateStr)'

echo "Test transazione:"
docker exec -i mongo mongosh --quiet --eval '
  const session = db.getMongo().startSession();
  session.startTransaction();
  session.getDatabase("archdata").smoke.insertOne({ ts: new Date() });
  session.commitTransaction();
  print("commit OK");
  session.endSession();
'
