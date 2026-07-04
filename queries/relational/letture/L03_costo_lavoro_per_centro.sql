-- L03 — Costo del lavoro per centro di costo di una ditta, dettaglio mensile in un anno.
\if :{?tenant} \else \set tenant 1 \endif
\if :{?anno}   \else \set anno 2026 \endif

SELECT cc.codice      AS centro,
       cc.descrizione,
       c.mese,
       sum(c.costo_azienda) AS costo,
       count(*)             AS n_cedolini
FROM cedolino c
JOIN dipendente d       USING (tenant_id, dipendente_id)
JOIN centro_di_costo cc ON  cc.tenant_id = d.tenant_id
                        AND cc.cdc_id    = d.cdc_id
WHERE c.tenant_id = :tenant
  AND c.anno = :anno
GROUP BY cc.codice, cc.descrizione, c.mese
ORDER BY cc.codice, c.mese;
