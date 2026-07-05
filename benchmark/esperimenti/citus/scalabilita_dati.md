# Scalabilità per volume di dati — Citus (nodi fissi)

Si continua dal cluster a **4 nodi-dati** dell'esperimento sulla scalabilità per nodi (VM-1, VM-2, VM-3, VM-4, tutti 4c e simmetrici; coordinator worker-1, 16c, senza shard): il numero di nodi resta fisso e si aumenta progressivamente il volume dei dati, misurando lettura e scrittura a ogni scala fino a **saturare il disco**. Punti di scala (dipendenti, seed 42, caricati a lotti incrementali): 554 → ~1100 → ~2200 → ~4400 → … fino al limite dei ~30GB/nodo.

Obiettivo (req. 5b): a parità di nodi, verificare come scalano lettura e scrittura all'aumentare dei dati e individuare i colli di bottiglia fino alla saturazione.

## Metriche raccolte (per nodo, durante ogni run)
Come per la scalabilità per nodi: contatori `pg_stat_statements` per nodo via `run_command_on_all_nodes` (righe elaborate, tempo di esecuzione, `blks_hit`/`read`, `temp_blks`, `wal_bytes`), più latenza e throughput dal client.

## Risultati attesi
Le analitiche cross-shard (L04, L11) crescono in latenza con i dati: più righe da scansionare per shard.
Quando i dati non entrano più in cache (`shared_buffers`) aumentano le letture da disco (`blks_read`) e la latenza degrada più che linearmente. Le query per singolo tenant (L01) restano ~costanti perché indicizzate. Le scritture mantengono throughput ~costante finché il disco regge; in prossimità della saturazione degradano nettamente (IO in coda, spill).

## Risultati ottenuti

Misura **a caldo** (cache piena = capacità massima del sistema; metodologia opposta alla scalabilità per nodi, che era a freddo — qui interessa vedere fin dove la cache regge e quando cede). 
Cluster **fisso a 4 nodi**, tenant aggiunti a lotti (stesso seed 42). Latenza media (ms) da `pgbench`; 
CSV in `benchmark/results/citus/letture/scalabilita_dati/`.

### Latenza (ms) al crescere dei dati

| ditte | dip ≈ | L01 single-shard | L04 gender gap | L06 assenteismo | L11 spesa categoria | disco (`blk_read`) |
|------:|------:|-----------------:|---------------:|----------------:|--------------------:|-------------------:|
| 30 (base) | 554  | 1.5 | 18.3 | 15.4 |  20.1 | 0 |
| 60        | ~1100 | 1.5 | 20.4 | 17.5 |  24.6 | 0 |
| 120       | ~2200 | 1.5 | 24.0 | 25.1 |  34.9 | 0 |
| 240       | ~4400 | 1.4 | 30.9 | 51.2 |  66.0 | 0 |
| 480       | ~8800 | 1.6 | **68.3** | **73.1** | **114.1** | 0 |

Degrado 30→480 ditte: L04 **3.7×**, L06 **4.7×**, L11 **5.7×**; L01 **invariata**.

Conclusioni:
- **Le cross-shard degradano super-linearmente** col volume: L11 20→114 ms (5.7×), L06 15→73 (4.7×), L04
  18→68 (3.7×). Più righe da scansionare per shard e cache via via più sotto pressione → il costo cresce più
  che proporzionalmente, con un **salto netto tra 240 e 480 ditte**.
- **Le single-shard restano piatte** (~1.5 ms a ogni scala): indicizzate e mirate a un tenant, **insensibili
  al volume totale**. È il vantaggio del multitenant co-locato — le query operative non risentono della
  crescita del dataset globale.
- **`blk_read` ancora 0**: i dati stanno **ancora in RAM** (`shared_buffers` + page-cache), quindi il degrado
  finora è **CPU-bound** (scan di più righe in cache), non ancora I/O da disco. Il salto a 480 ditte è il
  **preludio alla saturazione**: con ancora più dati la cache non basterebbe e comparirebbero le letture da
  disco (`blk_read > 0`), con degrado ulteriore. 

**Scritture su questa scala:** non ri-misurate qui — le scritture intra-tenant colpiscono **un solo nodo**
(cfr. `scalabilita_nodi.md`, sezione scritture), quindi il loro costo dipende dalla dimensione del **singolo tenant**, non dal volume globale del cluster.

## Note
Nodi fissi a 4 (VM-1/2/3/4, dal termine della scalabilità per nodi). L'ultima scala è la ricerca del **collo di bottiglia/saturazione** del disco → si esegue **per ultima** perché riempie i ~30GB/nodo.