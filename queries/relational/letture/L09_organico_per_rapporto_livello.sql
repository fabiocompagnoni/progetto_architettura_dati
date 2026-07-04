-- L09 — Organico per tipo di rapporto e livello, su tutti i tenant.
WITH contratto_corrente AS (          -- un solo contratto per dipendente: quello piu' recente
    SELECT DISTINCT ON (tenant_id, dipendente_id)
           tenant_id, dipendente_id, ccnl_codice, livello, tipo_rapporto
    FROM contratto
    ORDER BY tenant_id, dipendente_id, data_inizio DESC
)
SELECT ccnl_codice,
       livello,
       tipo_rapporto,
       count(*) AS n_dipendenti
FROM contratto_corrente
GROUP BY ccnl_codice, livello, tipo_rapporto
ORDER BY ccnl_codice, livello, tipo_rapporto;
