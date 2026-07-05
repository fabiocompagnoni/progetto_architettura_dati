# Scalabilità per numero di nodi — Citus (dati fissi)

Regime a parità di dati: 30 ditte, 554 dipendenti, 12 mesi (anno 2026, seed 42). Si parte da un solo nodo-dati e se ne aggiunge uno alla volta fino a quattro, misurando a ogni passo lettura e scrittura non solo come tempo, ma anche come **coinvolgimento di ciascun nodo** (CPU, RAM, IO, rete) e contatori interni del DB. 
Sequenza dei nodi-dati: VM-1 (`10.0.1.4`) → +VM-2 (`10.0.1.5`) → +VM-3 (`10.0.1.7`) → +VM-4 (`10.0.1.6`), tutti da 4c e quindi **simmetrici**. Il coordinator è worker-1 (`10.0.1.8`, 16c), che funge solo da aggregatore e non ospita shard; il client di carico gira sul coordinator (non c'è una VM dedicata al driver). Dopo ogni aggiunta gli shard vengono ridistribuiti (`citus_rebalance`).

Obiettivo (req. 5a): verificare se, a parità di dati, l'aggiunta di nodi migliora lettura e scrittura, e come si ridistribuisce il carico tra i nodi.

## Metriche raccolte (per nodo, durante ogni run)
- **Risorse OS**: CPU (media e picco), RAM usata, IO disco (lettura/scrittura), rete (in/out) → carico di ciascun nodo e traffico coordinator↔worker.
- **PostgreSQL/Citus** (`run_command_on_all_nodes`, reset→run→delta): righe elaborate, `shared_blks_hit` vs `read` (cache vs disco), `temp_blks` (spill), `wal_bytes` (WAL, per le scritture), tempo di esecuzione — da `pg_stat_statements` e `pg_stat_database`.
- **Distribuzione del lavoro**: `citus_stat_activity` (`nodeid`, `is_worker_query`) e `EXPLAIN (ANALYZE, BUFFERS)` (task per nodo, righe e tempo per shard).
- **Latenza** (media / p95) e **throughput** dal driver.

## Risultati attesi
Cross-shard (L04, L11): aggiungendo nodi la latenza cala e il lavoro si distribuisce → la quota di CPU e di righe elaborate **per singolo nodo diminuisce**, mentre il traffico di rete verso il coordinator (raccolta dei risultati parziali) e il costo del merge sul coordinator restano circa costanti. 
Single-shard (L01): la latenza resta costante e il lavoro si concentra su **un solo nodo** (gli altri a CPU ~0), a prescindere dal
numero di nodi. Scritture intra-tenant: la latenza della singola operazione è poco sensibile ai nodi (una sola partizione scrive, WAL sul solo nodo dello shard), mentre il **throughput aggregato** cresce coi nodi.

## Risultati ottenuti

Medie su **3 run a freddo** (`shared_buffers` svuotata prima di ogni giro). Metriche per nodo dal collector
(`pg_stat_statements` via `run_command_on_all_nodes` + `docker stats` + `/proc/diskstats`). CSV completo in
`benchmark/results/citus/`.

> **Nota sul disco.** `disk_read` è **0** a ogni scala qui: il dataset (554 dipendenti, ~decine di MB) entra
> tutto in RAM (`shared_buffers` + page-cache del SO), quindi le letture non toccano mai il disco fisico,
> per quante se ne facciano (misurate centinaia di migliaia di letture, sempre 0). Le letture da disco
> emergono solo quando i dati superano la RAM → è l'esperimento *scalabilità dati*, dov'è il vero collo del
> disco. Qui il "disco" visibile è solo `disk_write` ~1 MB (flush WAL/checkpoint di background).

### 1 nodo (worker `10.0.1.5`, coordinator `10.0.1.8`)

| query | lat (ms) | tps | CPU coord % | CPU worker % | exec worker (ms) | righe worker |
|-------|---------:|----:|------------:|-------------:|-----------------:|-------------:|
| L01 cedolino singolo        |  1.5 | 680 | 13 |  11 |  138 |   6797 |
| L02 cedolini ditta/periodo  |  1.5 | 669 | 14 |  15 |  171 |   6699 |
| L03 costo per centro        |  2.3 | 438 | 25 |  27 |  646 | 210192 |
| L04 gender gap mediano      | 71.9 |  14 | 40 | 142 |  531 |  77375 |
| L05 top-N retribuzioni      | 65.8 |  15 | 38 | 129 |  327 |  54840 |
| L06 assenteismo per mese    | 61.4 |  16 | 37 | 122 | 1700 | 245000 |
| L07 straordinari per centro |  3.1 | 321 | 22 |  41 | 1631 |  12843 |
| L08 trend costo del lavoro  | 56.1 |  18 | 36 | 106 |  466 |  42880 |
| L09 organico per livello    | 57.7 |  17 | 36 | 107 |  186 |  51852 |
| L10 cedolino completo       | 82.7 |  12 | 42 | 189 |  169 |    121 |
| L11 spesa per categoria     | 75.6 |  13 | 42 | 154 | 1464 |  73497 |
| L12 ferie residue           | 75.4 |  13 | 40 | 165 |  909 |   3990 |
| L13 riepilogo assenze       |  3.4 | 291 | 31 |  38 |  923 |  29320 |

Osservazioni: due regimi netti. Le **single-shard** (L01/L02/L03/L07/L13) restano a **~1.5-3.4 ms** (fino a
680 tps): il worker fa poco (CPU 11-41%), il coordinator ha un overhead fisso (~13-31% CPU per il routing).
Le **cross-shard** (L04/L05/L06/L08/L09/L11/L12) stanno a **~56-83 ms** (13-18 tps) e saturano il worker
(**CPU 100-190%**, usa più core per lo scan), mentre il coordinator resta a ~40% (il merge). **L10 cedolino
completo** è la più lenta (83 ms, worker **189% CPU**) pur essendo single-tenant: l'assemblaggio JSON da 7
tabelle è CPU-intensivo → è il caso *pro-documentale* (in Mongo sarà una `findOne`).

### 2 nodi (worker `10.0.1.5`, `10.0.1.7`; coordinator `10.0.1.8`)

Le colonne per-worker sono la **media sui 2 worker** (ognuno tiene ~metà degli shard).

| query | lat (ms) | tps | CPU coord % | CPU worker % | exec worker (ms) | righe worker |
|-------|---------:|----:|------------:|-------------:|-----------------:|-------------:|
| L01 cedolino singolo        |  1.5 | 666 | 12 |  6 |  63 |  3331 |
| L02 cedolini ditta/periodo  |  1.6 | 636 | 12 |  7 |  82 |  3182 |
| L03 costo per centro        |  2.3 | 431 | 23 | 14 | 315 | 103456 |
| L04 gender gap mediano      | 45.0 |  23 | 37 | 57 | 335 |  63064 |
| L05 top-N retribuzioni      | 33.7 |  31 | 21 | 33 | 237 |  55080 |
| L06 assenteismo per mese    | 31.2 |  32 | 17 | 30 | 1225 | 242750 |
| L07 straordinari per centro |  3.1 | 322 | 22 | 21 | 889 |  6435 |
| L08 trend costo del lavoro  | 24.0 |  42 |  9 | 14 | 368 |  50080 |
| L09 organico per livello    | 24.5 |  41 | 11 | 15 | 134 |  60991 |
| L10 cedolino completo       | 63.3 |  16 | 52 | 91 |  97 |    79 |
| L11 spesa per categoria     | 52.7 |  19 | 44 | 68 | 535 |  52907 |
| L12 ferie residue           | 59.7 |  17 | 49 | 82 | 439 |   2520 |
| L13 riepilogo assenze       |  3.5 | 290 | 29 | 19 | 453 |  14487 |

Osservazioni (1→2 nodi): le **cross-shard migliorano nettamente** — L04 72→45 ms (tps 14→23), L06 61→31,
L08 56→24, L11 76→53, L10 83→63. Il lavoro si **distribuisce**: la CPU e l'`exec` **per worker si dimezzano**
(L04: worker 142%→57%, exec 531→335 ms). Le **single-shard restano piatte** (L01 1.5 ms, L02/L03/L07/L13
invariate): colpiscono un solo shard su un solo nodo, aggiungere worker non le tocca. È esattamente lo
scaling atteso (req. 5a): più nodi aiutano le query che parallelizzano, non quelle mirate a un tenant.

### 3 nodi (worker `10.0.1.5/6/7`; media per-worker su 3 nodi)

| query | lat (ms) | tps | CPU coord % | CPU worker % | exec worker (ms) | righe worker |
|-------|---------:|----:|------------:|-------------:|-----------------:|-------------:|
| L01 cedolino singolo        |  1.5 | 669 | 12 |  4 |  47 |  2230 |
| L02 cedolini ditta/periodo  |  1.6 | 638 | 12 |  5 |  56 |  2127 |
| L03 costo per centro        |  2.3 | 437 | 23 |  9 | 213 | 69909 |
| L04 gender gap mediano      | 23.2 |  43 | 21 | 26 | 367 | 79899 |
| L05 top-N retribuzioni      | 19.4 |  52 | 15 | 20 | 244 | 61960 |
| L06 assenteismo per mese    | 19.9 |  50 | 15 | 21 | 1224 | 251667 |
| L07 straordinari per centro |  3.1 | 326 | 21 | 14 | 603 |  4343 |
| L08 trend costo del lavoro  | 15.9 |  63 | 12 | 12 | 360 | 50267 |
| L09 organico per livello    | 17.0 |  59 | 15 | 14 | 127 | 58640 |
| L10 cedolino completo       | 27.9 |  36 | 21 | 33 | 116 |   120 |
| L11 spesa per categoria     | 25.3 |  40 | 23 | 27 | 525 | 73066 |
| L12 ferie residue           | 25.2 |  40 | 18 | 32 | 545 |  3963 |
| L13 riepilogo assenze       |  3.5 | 289 | 28 | 13 | 305 |  9628 |

### 4 nodi (worker `10.0.1.4/5/6/7`; media per-worker su 4 nodi)

| query | lat (ms) | tps | CPU coord % | CPU worker % | exec worker (ms) | righe worker |
|-------|---------:|----:|------------:|-------------:|-----------------:|-------------:|
| L01 cedolino singolo        |  1.5 | 688 | 12 |  3 |  34 |  1718 |
| L02 cedolini ditta/periodo  |  1.5 | 654 | 12 |  4 |  43 |  1636 |
| L03 costo per centro        |  2.3 | 433 | 22 |  7 | 161 | 51988 |
| L04 gender gap mediano      | 18.3 |  55 | 25 | 24 | 347 | 75667 |
| L05 top-N retribuzioni      | 14.9 |  67 | 18 | 20 | 266 | 60240 |
| L06 assenteismo per mese    | 15.4 |  65 | 17 | 17 | 923 | 187125 |
| L07 straordinari per centro |  3.2 | 317 | 20 | 11 | 441 |  3165 |
| L08 trend costo del lavoro  | 12.1 |  83 | 14 | 12 | 351 | 49500 |
| L09 organico per livello    | 12.8 |  78 | 18 | 13 | 125 | 58234 |
| L10 cedolino completo       | 21.7 |  46 | 26 | 31 | 113 |   115 |
| L11 spesa per categoria     | 20.1 |  50 | 27 | 25 | 543 | 69158 |
| L12 ferie residue           | 19.5 |  51 | 21 | 30 | 528 |  3842 |
| L13 riepilogo assenze       |  3.4 | 291 | 26 | 10 | 230 |  7281 |

### Sintesi: scaling della latenza (ms) 1→4 nodi

| query | 1 nodo | 2 nodi | 3 nodi | 4 nodi | speedup 1→4 |
|-------|-------:|-------:|-------:|-------:|------------:|
| L04 gender gap mediano  | 71.9 | 45.0 | 23.2 | 18.3 | **3.9×** |
| L05 top-N retribuzioni  | 65.8 | 33.7 | 19.4 | 14.9 | **4.4×** |
| L06 assenteismo/mese    | 61.4 | 31.2 | 19.9 | 15.4 | **4.0×** |
| L08 trend costo lavoro  | 56.1 | 24.0 | 15.9 | 12.1 | **4.6×** |
| L09 organico/livello    | 57.7 | 24.5 | 17.0 | 12.8 | **4.5×** |
| L10 cedolino completo   | 82.7 | 63.3 | 27.9 | 21.7 | **3.8×** |
| L11 spesa/categoria     | 75.6 | 52.7 | 25.3 | 20.1 | **3.8×** |
| L12 ferie residue       | 75.4 | 59.7 | 25.2 | 19.5 | **3.9×** |
| L01 cedolino singolo *(single-shard)* | 1.5 | 1.5 | 1.5 | 1.5 | 1.0× |
| L13 riepilogo *(single-shard)* | 3.4 | 3.5 | 3.5 | 3.4 | 1.0× |

Conclusione (req. 5a): per le query **cross-shard** l'aggiunta di nodi dà uno **speedup quasi lineare**
(≈3.8-4.6× con 4 nodi): il lavoro si spartisce tra i worker, ciascuno scandisce meno shard e la latenza
crolla (L04 72→18 ms). Le query **single-shard** restano **costanti**: colpiscono un solo shard su un solo
nodo, quindi più nodi non le toccano. Citus scala ciò che parallelizza (le analitiche cross-tenant), non le
query mirate a un singolo tenant — che però erano già velocissime (~1-3 ms).

### Scritture (a 4 nodi, N=300 operazioni per query)

| query | lat (ms/op) | tps (op/s) | dove scrive | WAL sul nodo | righe |
|-------|------------:|-----------:|-------------|-------------:|------:|
| U02 licenziamento         |  1.7 | 605 | solo `10.0.1.4` |   6 KB | 1 |
| U01 coordinate bancarie   |  3.7 | 273 | solo `10.0.1.4` |  22 KB | 300 |
| U04 update concorrente    |  3.8 | 266 | solo `10.0.1.4` |  29 KB | 300 |
| I01 insert timbratura     | 10.6 |  94 | solo `10.0.1.4` | 129 KB | 1500 |
| I03 elabora cedolino (tx) | 57.4 |  17 | solo `10.0.1.4` | 955 KB | 8400 |
| U03 modifica riferimento  | 21.1 |  47 | **tutti i 5 nodi** | ~35 KB ×5 | ~600 ×5 |

Osservazioni (fondamentale per il confronto con Mongo):
- **5 scritture su 6 colpiscono un solo nodo** (`10.0.1.4`, dove vive lo shard del tenant 1); gli altri 3
  worker restano **inattivi** (CPU ~0, WAL 0). Per la co-locazione un tenant vive su uno shard → le sue
  scritture **non si parallelizzano** aggiungendo nodi. Il throughput aggregato di scrittura cresce coi nodi
  **solo** distribuendo scritture su **tenant diversi** (che finiscono su shard diversi). Contrasto netto con
  le letture cross-shard, che invece usano tutti i nodi.
- **I03 (transazione multi-tabella)** è la più costosa: 57 ms/op, 8400 righe e ~1 MB di WAL sul nodo del
  tenant. È il *pro-documentale*: in Mongo è un solo documento inserito (un `insertOne`).
- **U03 (modifica di un dato di riferimento)** è l'unica che tocca **tutti i nodi**: `tipo_voce` è una
  **reference table** replicata ovunque, quindi l'UPDATE si applica su ogni nodo (WAL su tutti). È il
  *pro-relazionale killer*: **1 riga logica** aggiornata (replicata a 5 nodi), contro il **mass-update di
  centinaia di documenti** che servirebbe in Mongo se il dato fosse denormalizzato nei cedolini.

_(D01 cancellazione periodo: misurata a parte con reload — è distruttiva.)_

## Note
Nodi aggiunti a mano dal coordinator (`citus-add-node.sh <ip>` seguito da `citus-rebalance.sh`). I quattro nodi-dati (VM-1/2/3/4) sono simmetrici (4c): lo scaling è onesto. worker-1 resta il coordinator (16c) e non ospita shard.