# Scalabilità per numero di nodi — MongoDB (dati fissi)

Regime a parità di dati (stesso dataset di Citus: 30 ditte, 554 dipendenti, seed 42, importato nelle collezioni). Si parte da uno shard e se ne aggiunge uno alla volta fino a quattro, misurando lettura e scrittura a ogni passo. Sequenza degli shard: VM-1 (`10.0.1.4`) → +VM-2 (`10.0.1.5`) → +VM-3 (`10.0.1.7`) → +VM-4 (`10.0.1.6`), tutti 4c e simmetrici. Config server e `mongos` su worker-1 (`10.0.1.8`). Dopo ogni `sh.addShard` il balancer redistribuisce le chunk (shard key `tenant_id` hashed).

Obiettivo (req. 5a): come per Citus, sul modello documentale.

## Metriche raccolte (per shard, durante ogni run)
- `serverStatus()` per shard: `opcounters` (query/insert/update/delete/getmore), WiredTiger (cache usata, byte letti/scritti), `mem` (residente), `network`.
- `explain("executionStats")`: `nReturned`, `docsExamined`, `keysExamined`, `executionTimeMillis` per shard.
- `mongostat` per shard; latenza e throughput dal client.

## Risultati attesi
Le query che coinvolgono più shard (analitiche cross-tenant, es. L11 spesa per categoria) migliorano all'aumentare degli shard: `docsExamined` e tempo si distribuiscono e il `mongos` fa il merge. Le query mirate a un tenant colpiscono un solo shard (shard key `tenant_id` hashed) e restano ~costanti. Le scritture per tenant vanno a un solo shard: latenza ~costante, throughput aggregato in crescita coi nodi.

## Risultati ottenuti

### Il balancer non distribuisce a questa scala (finding centrale)

Il regime "più shard, stessi dati" su Mongo si è rivelato **impraticabile in modo automatico** a questa
scala, e la ragione è essa stessa il risultato più interessante. Sequenza verificata sul campo (parametri e
soglie dalla doc ufficiale MongoDB):

| passo | azione | esito |
|-------|--------|-------|
| 1 | shardata `cedolini` (già popolata, **41.57 MB**) con chunksize **default 128 MB** | **1 solo chunk** iniziale; soglia di migrazione = 3×128 = **384 MB** ≫ 41 MB → il balancer non muove nulla |
| 2 | aggiunto shard2 e atteso il balancer | 2 shard registrati, ma tutti i dati su shard1; **shard2 inattivo** (~1% CPU) |
| 3 | ridotta la chunksize a **4 MB** (soglia → 12 MB) | ancora **1 chunk**: da MongoDB 6.0 lo **split automatico su scrittura è stato rimosso**, il chunk esistente non viene spezzato |
| 4 | **split manuale** di `cedolini` in **10 chunk** (`sh.splitFind`) | 10 chunk, tutti su shard1; sbilanciamento 41 MB ≫ soglia 12 MB |
| 5 | atteso il balancer (`balancerStatus`: `mode=full`, **888 round** eseguiti) | **nessuna migrazione**: i 10 chunk restano **10/0** su shard1 |

Conclusione: il balancer di MongoDB, di design, è **estremamente conservativo** e **rifiuta di distribuire un
dataset piccolo** anche quando la soglia documentata (3× range size) è ampiamente superata — privilegia
l'evitare l'overhead delle migrazioni al bilanciamento (verosimilmente anche l'**auto-merger** ri-fonde i
chunk contigui sullo stesso shard). È il contrario di Citus, dove `rebalance_table_shards` esplicito
distribuisce **sempre** e in modo deterministico. → *Contrasto operativo CP/gestione-dati centrale del lavoro*
(cfr. `scelte_progetto §17`, `teoria §3`).

### Misure a 1 e 2 shard (dati fissi) — carico randomizzato

Suite completa delle 13 letture (media dei run). Il carico **randomizza tenant/dip/mese** (colpisce documenti
diversi), ma essendo i dati tutti su shard1 le richieste finiscono comunque su un solo shard. **CPU per shard
(a 2 shard): shard1 (`10.0.1.4`) 37.6 %, shard2 (`10.0.1.5`) 0.2 % → shard2 completamente inattivo.**

| query | lat 1 shard (ms) | tps 1 shard | lat 2 shard (ms) | tps 2 shard |
|-------|-----------------:|------------:|-----------------:|------------:|
| L01 cedolino singolo        |   2.0 | 422 |   2.0 | 434 |
| L02 cedolini ditta/periodo  |   2.0 | 354 |   2.0 | 365 |
| L03 costo per centro        |   3.0 | 317 |   2.8 | 325 |
| L04 gender gap mediano      |   7.0 | 136 |   7.0 | 138 |
| L05 top-N retribuzioni      |   3.0 | 261 |   3.0 | 268 |
| L06 assenteismo per mese    |  99.3 |  10 |  99.0 |  10 |
| L07 straordinari per centro |   2.3 | 337 |   2.0 | 342 |
| L08 trend costo del lavoro  |  10.0 |  95 |  10.0 |  97 |
| L09 organico per livello    |   6.0 | 149 |   6.0 | 153 |
| L10 cedolino completo       |   2.0 | 425 |   2.0 | 441 |
| L11 spesa per categoria     |  12.0 |  79 |  12.0 |  80 |
| L12 ferie residue           | 141.0 |   7 | 141.3 |   7 |
| L13 riepilogo assenze       |  11.0 |  90 |  10.7 |  90 |

Osservazioni:
- **Latenza identica a 1 e 2 shard** per ogni query → aggiungere lo shard **non porta alcun beneficio** (il 2°
  shard resta scarico). È l'opposto di Citus, che a 1→2 nodi **dimezza** le cross-shard (L04 72→45, L11 76→53)
  e arriva a ≈**4×** con 4 nodi (cfr. `../citus/scalabilita_nodi.md`).
- **Mongo è però molto più veloce di Citus in ASSOLUTO** sulle analitiche, perché il modello **embedded**
  evita le join: L04 **7 ms** (Mongo) vs **72 ms** (Citus, 1 nodo); L11 **12 ms** vs **76 ms**. Le mirate
  (L01/L10 `findOne`) ~2 ms.
- Le uniche Mongo lente sono **L12 ferie residue (141 ms)** e **L06 assenteismo (99 ms)**: scandiscono *tutti*
  i cedolini (con assenze/ratei annidati) su un unico shard → è dove il mancato scaling pesa di più.

**Sintesi.** Citus *scala* (distribuisce sempre col rebalance esplicito); Mongo *è più veloce di suo* ma *non
scala* a questa scala perché il balancer non distribuisce. Se a volume grande (esperimento *scalabilità
dati* a 4 shard) il balancer finalmente distribuisse, Mongo potrebbe recuperare anche lo scaling.

## Note
Shard aggiunti a mano (`mongo-add-shard.sh <rs> <ip>`). Config server e `mongos` su worker-1, che non ospita
shard. **Contrariamente all'attesa iniziale, il balancer NON sposta le chunk a questa scala** (vedi il
finding sopra): l'automatismo Mongo non è l'equivalente del rebalance esplicito di Citus.