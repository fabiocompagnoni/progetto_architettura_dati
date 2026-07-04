-- L05 — Le N retribuzioni (RAL) piu' alte, su tutti i tenant.
\if :{?n} \else \set n 20 \endif

WITH contratto_corrente AS (          -- un solo contratto per dipendente: quello piu' recente
    SELECT DISTINCT ON (tenant_id, dipendente_id)
           tenant_id, dipendente_id, ral
    FROM contratto
    ORDER BY tenant_id, dipendente_id, data_inizio DESC
)
SELECT c.tenant_id,
       c.dipendente_id,
       d.cognome,
       d.nome,
       c.ral
FROM contratto_corrente c
JOIN dipendente d USING (tenant_id, dipendente_id)
ORDER BY c.ral DESC
LIMIT :n;
