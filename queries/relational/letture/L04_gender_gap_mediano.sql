-- L04 — RAL mediana per sesso e livello, su tutti i tenant.

WITH contratto_corrente AS (          -- un solo contratto per dipendente: quello piu' recente
    SELECT DISTINCT ON (tenant_id, dipendente_id)
           tenant_id, dipendente_id, ccnl_codice, cod_suddivisione, livello, ral
    FROM contratto
    ORDER BY tenant_id, dipendente_id, data_inizio DESC
)
SELECT c.ccnl_codice,
       c.livello,
       l.descrizione,
       d.sesso,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY c.ral) AS ral_mediana,
       count(*)                                           AS n
FROM contratto_corrente c
JOIN dipendente d USING (tenant_id, dipendente_id)
JOIN livello l ON l.ccnl_codice      = c.ccnl_codice
              AND l.cod_suddivisione = c.cod_suddivisione
              AND l.livello          = c.livello
GROUP BY c.ccnl_codice, c.livello, l.descrizione, d.sesso
ORDER BY c.ccnl_codice, c.livello, d.sesso;
