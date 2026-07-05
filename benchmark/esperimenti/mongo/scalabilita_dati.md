# Scalabilità per volume di dati — MongoDB (nodi fissi)

Si continua dal cluster a **4 shard** dell'esperimento sulla scalabilità per nodi (VM-1/2/3/4, tutti 4c e simmetrici; config server e `mongos` su worker-1): il numero di shard resta fisso e si aumenta progressivamente il volume dei dati, misurando lettura e scrittura a ogni scala fino a **saturare il disco**. Punti di scala (dipendenti, seed 42, importati a lotti): 554 → ~1100 → ~2200 → ~4400 → … fino al limite dei ~30GB/nodo.

Obiettivo (req. 5b): a parità di nodi, verificare come scalano lettura e scrittura all'aumentare dei dati e individuare i colli di bottiglia fino alla saturazione.

## Metriche raccolte (per shard, durante ogni run)
Come per la scalabilità per nodi: `serverStatus()` per shard (`opcounters`, WiredTiger cache e IO, `mem`, `network`) ed `explain("executionStats")` (`docsExamined`, `keysExamined`, `nReturned`, `executionTimeMillis` per shard); latenza e throughput dal client.

## Risultati attesi
Le query cross-shard (L11) crescono in latenza con i dati: più documenti esaminati per shard. Quando il working set non entra più nella cache WiredTiger aumentano le letture da disco e la latenza degrada più che linearmente. Le query per singolo tenant (L01) restano ~costanti perché servite da un indice. Le scritture mantengono throughput ~costante finché il disco regge; verso la saturazione degradano.

## Risultati ottenuti

Punti di scala effettivi (ditte cumulative, seed 42): **230 → 630 → 1430 → 2630 ditte** (≈4200 → 48000
dipendenti), ben oltre le 480 ditte di Citus. A differenza del regime a scala piccola (`scalabilita_nodi.md`,
dove il balancer **non** distribuiva), **qui a volume grande il balancer distribuisce**: a ogni scala i
`cedolini` sono spartiti su **tutti e 4 gli shard**, che risultano attivi (CPU media **48–65 % per shard**).
Misura a caldo; latenza media (ms) da `mongosh`. CSV in `benchmark/results/mongo/letture/scalabilita_dati/`.

### Latenza (ms) al crescere dei dati (4 shard fissi)

| ditte | dip ≈ | L01 single-shard | L04 gender gap | L11 spesa categoria | L06 assenteismo | L12 ferie residue |
|------:|------:|-----------------:|---------------:|--------------------:|----------------:|------------------:|
| 230  | ~4200  | 2.6 | 26.0  | 34.2  | 301.6  | 476.2  |
| 630  | ~11500 | 2.6 | 61.6  | 80.0  | 729.1  | 1174.1 |
| 1430 | ~26000 | 2.7 | 122.2 | 178.0 | 1684.9 | 2759.5 |
| 2630 | ~48000 | 2.7 | 185.2 | 308.0 | 2833.8 | 4786.3 |

Osservazioni:
- **Il balancer distribuisce a volume grande**: tutti e 4 gli shard lavorano (CPU 48–65 % ciascuno) → conferma
  che il mancato scaling a scala piccola era dovuto alla **soglia di migrazione** (3× range size), non a un
  limite intrinseco. È il completamento del finding di `scalabilita_nodi.md`.
- **Le cross-shard degradano super-linearmente** col volume: L04 26→185 ms (~7×), L11 34→308 ms (~9×). Le più
  pesanti sono **L06 (302→2834 ms)** e **L12 (476→4786 ms)**, che aggregano *tutti* i cedolini scorrendo gli
  array annidati (assenze, ratei): a scala grande il costo dell'embedding sull'intera collezione **esplode**.
- **Le single-shard/mirate restano piatte** (L01 ~2.6 ms; L02/L03/L07/L10 ~2.5–3.6 ms a ogni scala):
  indicizzate e servite da un solo shard → insensibili al volume globale, come su Citus.
- Le letture da disco non emergono in modo netto a queste scale (working set ancora servito dalla cache
  WiredTiger); il degrado è dominato dal numero di documenti esaminati per shard.

**Scritture su questa scala:** non ri-misurate qui; le scritture intra-tenant colpiscono un solo shard
(co-locazione), mentre U03 (mass-update denormalizzato) tocca tutti gli shard — dettaglio nel confronto con
Citus.

## Note
Shard fissi a 4 (VM-1/2/3/4). L'ultima scala è la ricerca del **collo di bottiglia/saturazione** del disco → si esegue **per ultima** perché riempie i ~30GB/nodo.