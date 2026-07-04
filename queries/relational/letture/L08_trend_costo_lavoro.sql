-- L08 — Andamento mensile del costo del lavoro, su tutti i tenant.
\if :{?anno} \else \set anno 2026 \endif

SELECT mese,
       sum(costo_azienda) AS costo_totale,
       count(*)           AS n_cedolini
FROM cedolino
WHERE anno = :anno
GROUP BY mese
ORDER BY mese;
