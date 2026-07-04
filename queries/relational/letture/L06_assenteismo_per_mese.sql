-- L06 — Ore di assenza per mese e causale, su tutti i tenant.
\if :{?anno} \else \set anno 2026 \endif

SELECT extract(month FROM data)::int AS mese,
       causale_codice,
       sum(ore) AS ore,
       count(*) AS giorni
FROM assenza
WHERE extract(year FROM data) = :anno
GROUP BY mese, causale_codice
ORDER BY mese, causale_codice;
