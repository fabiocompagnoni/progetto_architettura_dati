# Comportamento in presenza di guasti — Citus

Con il cluster a più nodi-dati (VM-1/2/3/4, coordinator worker-1), durante un carico di lettura **e** di scrittura si arresta un worker (il container `citus` sul nodo) e si misurano finestra di indisponibilità, tasso di errore e recupero al rientro. Si considera anche l'arresto del coordinator (worker-1), unico entry point.

Obiettivo (req.): caratterizzare il comportamento distribuito in presenza di guasti — il modello CP.

## Metriche raccolte
- Finestra di indisponibilità: dall'arresto del nodo a quando le operazioni tornano a completare.
- Tasso di errore: operazioni fallite / totali durante il guasto.
- Tempo di recupero al rientro del nodo.
- Distribuzione: quali operazioni proseguono (shard sugli altri nodi) e quali falliscono (shard sul nodo giù).

## Risultati attesi
Comportamento CP. Con `shard_replication_factor=1` non c'è replica: gli shard sul nodo caduto sono indisponibili → le operazioni che li toccano falliscono finché il nodo non rientra; quelle sugli altri shard proseguono. Al rientro, ripresa senza intervento manuale. L'arresto del coordinator blocca invece tutto l'accesso (entry point unico), pur restando i dati integri sui worker.

## Risultati ottenuti

Misurato con `test-guasto-citus.sh`: **L04 (cross-shard)** eseguita in loop mentre un worker scelto a caso viene spento a 10s e riavviato a 25s (giù per 15s), su 45s totali. **11 run**, ogni worker colpito più volte; per ogni operazione si registra esito e righe restituite. CSV in `benchmark/results/citus/guasti/`.

| worker spento | run | error-rate medio | finestra errori | recupero | righe (su → giù → su) |
|---------------|----:|-----------------:|-----------------|----------|-----------------------|
| 10.0.1.4 | 2 | 51.4% | 10.0s → 25.0s (15s) | ~25.5s (~0.5s dopo il riavvio) | N → **0** → N |
| 10.0.1.5 | 1 | 50.7% | 10.0s → 25.0s (15s) | ~25.5s | N → **0** → N |
| 10.0.1.6 | 5 | 51.6% | 10.0s → 25.0s (15s) | ~25.5s | N → **0** → N |
| 10.0.1.7 | 2 | 51.8% | 10.0s → 25.0s (15s) | ~25.6s | N → **0** → N |

Osservazioni:
- **CP confermato**: spegnendo **qualsiasi** worker, la query cross-shard fallisce per **tutta** la finestra di down (15s) — le serve lo shard di ogni nodo, quindi manca sempre qualcosa. 
**Nessun risultato parziale**:
  le righe crollano da N a **0** durante il down e tornano a N al rientro. Citus preferisce la **consistenza** alla disponibilità.
- **Simmetria dei nodi**: i 4 worker danno lo stesso error-rate (~51%) → ognuno è essenziale, nessuno ridondante (copia singola, `shard_replication_factor=1`).
- **Recupero automatico e rapido**: primo `ok` a ~25.5s, cioè ~0.5s dopo `docker start`; Citus riconnette il worker **senza intervento manuale**. L'indisponibilità dura **esattamente** il tempo di down, senza strascichi.
- L'error-rate (~51%) supera la quota di tempo down (15/45 ≈ 33%) perché durante il down le query **falliscono in fretta** (connessione rifiutata) e ne passano di più al secondo rispetto alle letture riuscite.

Scenari controllati da completare: **single-shard L01** (dovrebbe **isolare** il guasto — falliscono solo i tenant sul nodo giù, gli altri proseguono); **arresto del coordinator** (blocca tutto l'accesso, entry point
unico); guasto **sotto carico di scrittura**.

## Note
Il guasto si induce con `docker stop citus` sul nodo bersaglio, il rientro con `docker start citus`.
Richiede almeno 2 nodi-dati. Cfr. `scelte_progetto` §7 (copia singola, principio anti-trucco).