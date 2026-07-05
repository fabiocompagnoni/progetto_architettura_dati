# Architetture Dati: PostgreSQL/Citus vs MongoDB

Elaborato per l'esame di Architetture Dati. Valuta empiricamente se e quando un DBMS distribuito sia adatto a
un carico applicativo reale di tipo **HR/retributivo** (ditte, dipendenti, contratti, presenze e cedolini
paga, in regime multitenant), confrontando un relazionale realmente distribuito (**PostgreSQL + Citus**) e un
document store (**MongoDB**) su: modello dei dati, linguaggio di interrogazione, scalabilità, scritture
concorrenti (transazioni) e comportamento in presenza di guasti.

## Metodo

Entrambi i sistemi sono installati su un cluster di 5 VM Azure (coordinator / config server + mongos su una
macchina, 4 nodi-dati simmetrici sulle altre), alimentati con lo **stesso dataset sintetico** (calibrato
sulla forma di cedolini reali e generato in modo riproducibile con un seed fisso) e sollecitati con una
**suite di query speculare** (13 letture + 7 scritture, con versione `.sql` per Citus e `.js` per Mongo).

Per ogni prova si misurano latenza, throughput e uso di risorse **per singolo nodo**, con strumenti nativi:
`pgbench` + `pg_stat_statements` (via `run_command_on_all_nodes`) per Citus; loop `mongosh` + `serverStatus`
per Mongo; `docker stats` e `/proc` per CPU/RAM/IO a livello di sistema. I risultati sono raccolti in CSV e
analizzati in tabelle e grafici. Gli esperimenti coprono: scalabilità per numero di nodi (dati fissi),
scalabilità per volume di dati (nodi fissi), scritture distribuite e comportamento in presenza di guasti.

## Struttura

| Cartella | Contenuto |
|----------|-----------|
| `infra/local` | Stack Docker per lo sviluppo locale (Citus 1+2, Mongo single-node) |
| `infra/prod`  | Deploy sulle VM Azure (Citus coordinator + 4 worker; Mongo config+mongos + 4 shard) |
| `schema/`     | Schemi nei due modelli: DDL relazionale (reference/distribuite), collezioni documentali |
| `data/`       | Generatore del dataset sintetico, parametrico e riproducibile (seed fisso) |
| `queries/`    | Suite di query speculare relazionale ↔ documentale (letture e scritture) |
| `benchmark/`  | Collector e runner di misura per-nodo, documenti degli esperimenti e CSV dei risultati |
| `report/`     | Documento LaTeX consegnato all'esame |
| `scripts/`    | Script di supporto (caricamento dati, smoke test) |

## Avvio locale

```sh
docker compose -f infra/local/relational/docker-compose.yml up -d
docker compose -f infra/local/document/docker-compose.yml up -d

./scripts/smoke-citus.sh
./scripts/smoke-mongo.sh
```

Coordinator Citus su `localhost:5432`, MongoDB su `localhost:27017`. Per fermare gli stack sostituire `up -d`
con `down` (aggiungere `-v` per azzerare anche i dati). Il deploy sulle VM e la conduzione delle misure sono
descritti in `infra/prod/` e `benchmark/`.
