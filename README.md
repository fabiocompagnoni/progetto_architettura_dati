# Architetture Dati — PostgreSQL/Citus vs MongoDB

Elaborato per l'esame di Architetture Dati. Lo scopo è valutare empiricamente se un
DBMS distribuito è adatto a un determinato carico applicativo, mettendo a confronto un
relazionale realmente distribuito (PostgreSQL + Citus) e un document store (MongoDB)
su modello dei dati, linguaggio di interrogazione, scalabilità, scritture concorrenti e comportamento in presenza di guasti.

Il dominio del dataset non è ancora fissato: viene definito nel blocco "schema".

## Misura su due livelli

Le performance del DBMS e quelle dell'applicazione si misurano separatamente per non confondere l'overhead applicativo con quello del database.

- **Livello 1 — DB diretto.** YCSB e driver nativi colpiscono direttamente il database.
  È il confronto rigoroso e isolato tra i due sistemi.
- **Livello 2 — end-to-end.** Una API REST simmetrica davanti a entrambi i DB, con
  generazione di carico distribuita su più macchine, per lo scenario realistico
  multi-utente e i test di fault tolerance. Misurato a parte ed etichettato come tale.

## Struttura

| Cartella | Contenuto |
|----------|-----------|
| `infra/local`  | Stack Docker per lo sviluppo locale (Citus 1+2, Mongo replica set single-node) |
| `infra/prod`   | Deployment sulle VM Azure (Citus 1+4, Mongo) |
| `schema/`      | Schemi nei due modelli: DDL relazionale, validator/collezioni documentali |
| `data/`        | Generatore del dataset sintetico e scalabile |
| `queries/`     | Query a complessità variabile, per sistema |
| `api/`         | API REST simmetrica sopra i due DB (Livello 2) |
| `loadgen/`     | Generazione di carico distribuita che emula molti utenti (Livello 2) |
| `benchmark/`   | Workload e configurazioni YCSB, raccolta risultati (Livello 1) |
| `monitoring/`  | Stack di osservabilità (Prometheus, Grafana, exporter) |
| `report/`      | Documento LaTeX consegnato all'esame |
| `scripts/`     | Script di supporto (avvio, smoke test, seeding) |

## Avvio locale

```sh
docker compose -f infra/local/relational/docker-compose.yml up -d
docker compose -f infra/local/document/docker-compose.yml up -d

./scripts/smoke-citus.sh
./scripts/smoke-mongo.sh
```

Coordinator Citus su `localhost:5432`, MongoDB su `localhost:27017`. Per fermare gli
stack sostituire `up -d` con `down` (aggiungere `-v` per azzerare anche i dati).