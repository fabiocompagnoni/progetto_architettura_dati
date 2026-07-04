-- U04 — Ri-elaborazione dello stesso cedolino (riga condivisa: test di contesa/lock).
\if :{?tenant} \else \set tenant 1 \endif
\if :{?cid}    \else \set cid 1 \endif
\if :{?data}   \else \set data '2026-06-27' \endif

UPDATE cedolino
SET data_elaborazione = :'data'
WHERE tenant_id = :tenant AND cedolino_id = :cid;
