-- U02 — Licenziamento: imposta la data di fine sul contratto attivo di un dipendente.
\if :{?tenant}    \else \set tenant 1 \endif
\if :{?dip}       \else \set dip 1 \endif
\if :{?data_fine} \else \set data_fine '2026-12-31' \endif

UPDATE contratto
SET data_fine = :'data_fine'
WHERE tenant_id = :tenant
  AND dipendente_id = :dip
  AND data_fine IS NULL;
