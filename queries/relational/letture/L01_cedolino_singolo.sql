-- L01 — Cedolino singolo per (dipendente, periodo).
\if :{?tenant} \else \set tenant 1 \endif
\if :{?dip}    \else \set dip 1 \endif
\if :{?anno}   \else \set anno 2026 \endif
\if :{?mese}   \else \set mese 6 \endif

SELECT tenant_id, cedolino_id, dipendente_id, anno, mese,
       tot_competenze, tot_trattenute, netto, costo_azienda
FROM cedolino
WHERE tenant_id = :tenant AND dipendente_id = :dip AND anno = :anno AND mese = :mese;
