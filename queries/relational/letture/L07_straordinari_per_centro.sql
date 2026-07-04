-- L07 — Ore di straordinario per centro di costo di una ditta, in un anno.
\if :{?tenant} \else \set tenant 1 \endif
\if :{?anno}   \else \set anno 2026 \endif

SELECT cc.codice AS centro,
       sum(g.ore_straordinario) AS ore_straordinario
FROM giorno g
JOIN cedolino c         USING (tenant_id, cedolino_id)
JOIN dipendente d       USING (tenant_id, dipendente_id)
JOIN centro_di_costo cc ON  cc.tenant_id = d.tenant_id
                        AND cc.cdc_id    = d.cdc_id
WHERE c.tenant_id = :tenant
  AND c.anno = :anno
  AND g.ore_straordinario > 0
GROUP BY cc.codice
ORDER BY ore_straordinario DESC;
