-- L12 — Ferie residue a fine anno per azienda: giorni, ore e costo stimato.
\if :{?anno} \else \set anno 2026 \endif

WITH residuo AS (                     -- residuo ferie di ogni dipendente dal rateo di dicembre
    SELECT c.tenant_id,
           c.dipendente_id,
           max(r.residuo) FILTER (WHERE r.tipo = 'FERIE') AS ferie_gg
    FROM cedolino c
    JOIN rateo r USING (tenant_id, cedolino_id)
    WHERE c.anno = :anno AND c.mese = 12
    GROUP BY c.tenant_id, c.dipendente_id
),
contratto_corrente AS (               -- paga oraria dal contratto piu' recente di ogni dipendente
    SELECT DISTINCT ON (tenant_id, dipendente_id)
           tenant_id, dipendente_id, paga_oraria
    FROM contratto
    ORDER BY tenant_id, dipendente_id, data_inizio DESC
)
SELECT res.tenant_id,
       round(sum(res.ferie_gg), 2)                      AS ferie_residue_giorni,
       round(sum(res.ferie_gg) * 8, 2)                  AS ferie_residue_ore,
       round(sum(res.ferie_gg * 8 * ct.paga_oraria), 2) AS costo_ferie_residue
FROM residuo res
JOIN contratto_corrente ct USING (tenant_id, dipendente_id)
GROUP BY res.tenant_id
ORDER BY costo_ferie_residue DESC;
