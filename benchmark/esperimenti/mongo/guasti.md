# Comportamento in presenza di guasti — MongoDB

Con il cluster a più shard (VM-1/2/3/4, config server e `mongos` su worker-1), durante un carico di lettura e di scrittura si arresta uno shard(il container `mongo-shard` sul nodo) e si misurano finestra di indisponibilità, tasso di errore e recupero al rientro. Si considerano anche l'arresto del `mongos` e del config server.

Obiettivo (req.): caratterizzare il comportamento distribuito in presenza di guasti sul modello documentale.

## Metriche raccolte
- Finestra di indisponibilità: dall'arresto del nodo a quando le operazioni tornano a completare.
- Tasso di errore: operazioni fallite / totali durante il guasto.
- Tempo di recupero al rientro del nodo.
- Distribuzione: quali operazioni proseguono (chunk sugli altri shard) e quali falliscono (chunk sullo shard giù).

## Risultati attesi
Ogni shard è un replica set a 1 membro (copia singola): l'arresto di uno shard rende indisponibili le chunk che ospita → le operazioni che le toccano falliscono finché il nodo non rientra; quelle su altri shard proseguono. Al rientro, ripresa. L'arresto del `mongos` toglie l'entry point (l'accesso si interrompe finché non riparte, ma i dati restano); il config server, essendo replica set, va valutato a parte. Comportamento CP analogo a Citus, per un confronto diretto.

## Risultati ottenuti

Misurato con `test-guasto-mongo.sh`: **L04 (gender gap, cross-tenant)** eseguita in loop mentre lo shard che
ospita i dati (`10.0.1.4` — a questa scala il balancer non ha distribuito, tutti i cedolini sono lì) viene
spento a 10s e riavviato a 25s (giù per 15s), su 45s totali. **10 run**; per ogni operazione si registra
esito, righe restituite e latenza. CSV in `benchmark/results/mongo/guasti/`.

| shard spento | run | error-rate medio | finestra indisp. | recupero | righe (su → giù → su) |
|--------------|----:|-----------------:|------------------|----------|-----------------------|
| 10.0.1.4 (con i dati) | 10 | 7.0% | 10.1s → 25.2s (~15.0s) | ~0.25s dopo il riavvio | 59299 → **0** → 59299 |

Osservazioni:
- **CP confermato**: mentre lo shard con i dati è giù, la query fallisce e le righe crollano da 59299 a
  **0** (nessun risultato parziale); tornano a 59299 al rientro. Come Citus, MongoDB preferisce la
  **consistenza** alla disponibilità.
- **Finestra di indisponibilità ≈ 15s**, esattamente il tempo di down: gli errori vanno dal primo a 10.1s
  fino al primo `ok` a ~25.2s.
- **Recupero automatico e rapido**: primo `ok` a ~25.2s, cioè ~**0.25s** dopo `docker start`; il `mongos`
  riaggancia lo shard senza intervento manuale.
- **Differenza netta con Citus nel *modo* di fallire** (finding). L'error-rate è solo ~**7%** (contro ~51%
  di Citus) perché **mongos non fallisce subito**: resta **bloccato in attesa** dello shard irraggiungibile
  fino al timeout del client (5s per operazione), quindi nella finestra di down passano **poche operazioni
  lunghe** (3 errori da ~5s) invece di tanti rifiuti immediati. Citus invece rifiuta la connessione
  *all'istante* (fail-fast) → molte più operazioni-errore al secondo e error-rate più alto. Stessa
  indisponibilità reale (15s), manifestata in modo opposto: **timeout lunghi (Mongo) vs errori rapidi
  (Citus)**. Da dichiarare nel confronto: l'error-rate grezzo non è comparabile tra i due senza tenere conto
  del comportamento del client di fronte a un nodo giù.

### Scenari ancora da eseguire
- **Guasto sotto carico di scrittura** (`I01_insert_timbratura.js` su `10.0.1.4`): stessa struttura,
  verifica che le scritture verso lo shard giù falliscano e riprendano al rientro.
- **Shard vuoto (isolamento)**: spegnere uno shard *senza* dati (es. `10.0.1.5`) → atteso **0 errori**, le
  operazioni proseguono (il guasto è isolato allo shard colpito).
- **Arresto del `mongos`** (entry point unico): `docker stop mongos` → l'accesso si interrompe del tutto
  finché non riparte, ma i dati restano integri; qualitativo (lo script passa dal `mongos`, quindi va fatto
  a mano).

## Note
Il guasto si induce con `docker stop mongo-shard` sul nodo bersaglio, il rientro con `docker start mongo-shard`. Cfr. `scelte_progetto` §7 (copia singola, principio anti-trucco).