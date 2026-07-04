-- L02 — Totali dei cedolini di una ditta per un mese.
\if :{?tenant} \else \set tenant 1 \endif
\if :{?anno}   \else \set anno 2026 \endif
\if :{?mese}   \else \set mese 6 \endif

SELECT count(*)            AS n_cedolini,
       sum(tot_competenze) AS competenze,
       sum(tot_trattenute) AS trattenute,
       sum(netto)          AS netto,
       sum(costo_azienda)  AS costo_azienda
FROM cedolino
WHERE tenant_id = :tenant
  AND anno = :anno
  AND mese = :mese;
