-- I01 — Inserimento di una timbratura su un giorno esistente.
\if :{?tenant}  \else \set tenant 1 \endif
\if :{?entrata} \else \set entrata '08:00' \endif
\if :{?uscita}  \else \set uscita  '17:00' \endif

SELECT cedolino_id AS cid, data AS gdata
FROM giorno
WHERE tenant_id = :tenant
ORDER BY cedolino_id, data
LIMIT 1 \gset

INSERT INTO timbratura (tenant_id, cedolino_id, data, progressivo, ora_entrata, ora_uscita)
SELECT :tenant, :cid, :'gdata', coalesce(max(progressivo), 0) + 1, :'entrata', :'uscita'
FROM timbratura
WHERE tenant_id = :tenant AND cedolino_id = :cid AND data = :'gdata';
