-- L13 — Riepilogo ferie/permessi/malattia a fine anno, per dipendente di una ditta.
\if :{?tenant} \else \set tenant 1 \endif
\if :{?anno}   \else \set anno 2026 \endif

WITH goduto AS (                      -- ore godute nell'anno, dalle assenze registrate
    SELECT c.dipendente_id,
           sum(a.ore) FILTER (WHERE a.causale_codice = 'FE')           AS ferie_ore,
           sum(a.ore) FILTER (WHERE a.causale_codice IN ('PR','P104')) AS permessi_ore,
           sum(a.ore) FILTER (WHERE a.causale_codice = 'MA')           AS malattia_ore
    FROM cedolino c
    JOIN assenza a USING (tenant_id, cedolino_id)
    WHERE c.tenant_id = :tenant AND c.anno = :anno
    GROUP BY c.dipendente_id
),
residuo AS (                          -- residuo a fine anno, dai ratei di dicembre (in giorni)
    SELECT c.dipendente_id,
           max(r.residuo) FILTER (WHERE r.tipo = 'FERIE')    AS ferie_gg,
           max(r.residuo) FILTER (WHERE r.tipo = 'PERMESSI') AS permessi_gg
    FROM cedolino c
    JOIN rateo r USING (tenant_id, cedolino_id)
    WHERE c.tenant_id = :tenant AND c.anno = :anno AND c.mese = 12
    GROUP BY c.dipendente_id
)
SELECT d.dipendente_id,
       d.cognome,
       d.nome,
       coalesce(g.ferie_ore, 0)                   AS ferie_godute_ore,
       round(coalesce(r.ferie_gg, 0) * 8, 2)      AS ferie_residue_ore,
       coalesce(g.permessi_ore, 0)                AS permessi_goduti_ore,
       round(coalesce(r.permessi_gg, 0) * 8, 2)   AS permessi_residui_ore,
       coalesce(g.malattia_ore, 0)                AS malattia_ore
FROM dipendente d
LEFT JOIN goduto  g ON g.dipendente_id = d.dipendente_id
LEFT JOIN residuo r ON r.dipendente_id = d.dipendente_id
WHERE d.tenant_id = :tenant
ORDER BY d.dipendente_id;
