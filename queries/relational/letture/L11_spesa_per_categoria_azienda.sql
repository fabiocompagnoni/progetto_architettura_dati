-- L11 — Per categoria ATECO: numero di aziende, dipendenti, spesa annua/mensile e stipendio medio.
\if :{?anno} \else \set anno 2026 \endif

WITH azienda_categoria AS (           -- una categoria per azienda (ATECO principale = codice minore)
    SELECT tenant_id, min(ateco_codice) AS ateco_codice
    FROM ditta_ateco
    GROUP BY tenant_id
)
SELECT a.codice AS ateco,
       a.descrizione,
       count(DISTINCT c.tenant_id)                     AS n_aziende,
       count(DISTINCT (c.tenant_id, c.dipendente_id))  AS n_dipendenti,
       sum(c.tot_competenze)                           AS spesa_annua,
       round(sum(c.tot_competenze) / 12, 2)            AS spesa_mensile_media,
       round(sum(c.tot_competenze)
             / count(DISTINCT (c.tenant_id, c.dipendente_id)), 2) AS stipendio_medio_annuo
FROM cedolino c
JOIN azienda_categoria ac ON ac.tenant_id = c.tenant_id
JOIN ateco a              ON a.codice = ac.ateco_codice
WHERE c.anno = :anno
GROUP BY a.codice, a.descrizione
ORDER BY spesa_annua DESC;
