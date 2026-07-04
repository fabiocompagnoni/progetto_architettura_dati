-- D01 — Cancellazione dei cedolini di un periodo di una ditta, con le righe collegate.
\if :{?tenant} \else \set tenant 1 \endif
\if :{?anno}   \else \set anno 2026 \endif
\if :{?mese}   \else \set mese 1 \endif

BEGIN;

DELETE FROM timbratura t USING cedolino c
WHERE t.tenant_id = c.tenant_id AND t.cedolino_id = c.cedolino_id
  AND c.tenant_id = :tenant AND c.anno = :anno AND c.mese = :mese;

DELETE FROM assenza a USING cedolino c
WHERE a.tenant_id = c.tenant_id AND a.cedolino_id = c.cedolino_id
  AND c.tenant_id = :tenant AND c.anno = :anno AND c.mese = :mese;

DELETE FROM giorno g USING cedolino c
WHERE g.tenant_id = c.tenant_id AND g.cedolino_id = c.cedolino_id
  AND c.tenant_id = :tenant AND c.anno = :anno AND c.mese = :mese;

DELETE FROM voce_cedolino v USING cedolino c
WHERE v.tenant_id = c.tenant_id AND v.cedolino_id = c.cedolino_id
  AND c.tenant_id = :tenant AND c.anno = :anno AND c.mese = :mese;

DELETE FROM rateo r USING cedolino c
WHERE r.tenant_id = c.tenant_id AND r.cedolino_id = c.cedolino_id
  AND c.tenant_id = :tenant AND c.anno = :anno AND c.mese = :mese;

DELETE FROM contributo co USING cedolino c
WHERE co.tenant_id = c.tenant_id AND co.cedolino_id = c.cedolino_id
  AND c.tenant_id = :tenant AND c.anno = :anno AND c.mese = :mese;

DELETE FROM addizionale ad USING cedolino c
WHERE ad.tenant_id = c.tenant_id AND ad.cedolino_id = c.cedolino_id
  AND c.tenant_id = :tenant AND c.anno = :anno AND c.mese = :mese;

DELETE FROM cedolino
WHERE tenant_id = :tenant AND anno = :anno AND mese = :mese;

COMMIT;
