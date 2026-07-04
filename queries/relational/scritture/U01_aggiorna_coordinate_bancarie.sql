-- U01 — Aggiornamento delle coordinate bancarie di un dipendente (IBAN e banca).
\if :{?tenant} \else \set tenant 1 \endif
\if :{?dip}    \else \set dip 1 \endif
\if :{?iban}   \else \set iban 'IT60X0542811101000000123456' \endif
\if :{?banca}  \else \set banca 'Intesa Sanpaolo' \endif

UPDATE dipendente
SET iban = :'iban',
    banca = :'banca'
WHERE tenant_id = :tenant AND dipendente_id = :dip;
