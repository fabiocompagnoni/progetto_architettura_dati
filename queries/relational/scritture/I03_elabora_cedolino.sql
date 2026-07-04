-- I03 — Elaborazione del cedolino in un'unica transazione: intestazione + voci + ratei + contributi + addizionali.
\if :{?tenant} \else \set tenant 1 \endif
\if :{?dip}    \else \set dip 1 \endif
\if :{?cid}    \else \set cid 900001 \endif
\if :{?anno}   \else \set anno 2099 \endif
\if :{?mese}   \else \set mese 6 \endif

BEGIN;

-- idempotenza: rimuove un'eventuale esecuzione precedente dello stesso cedolino di test
DELETE FROM addizionale   WHERE tenant_id = :tenant AND cedolino_id = :cid;
DELETE FROM contributo    WHERE tenant_id = :tenant AND cedolino_id = :cid;
DELETE FROM rateo         WHERE tenant_id = :tenant AND cedolino_id = :cid;
DELETE FROM voce_cedolino WHERE tenant_id = :tenant AND cedolino_id = :cid;
DELETE FROM cedolino      WHERE tenant_id = :tenant AND cedolino_id = :cid;

INSERT INTO cedolino (tenant_id, cedolino_id, dipendente_id, anno, mese, data_elaborazione,
                      tot_competenze, tot_trattenute, netto, costo_azienda)
VALUES (:tenant, :cid, :dip, :anno, :mese, make_date(:anno, :mese, 27),
        2500.00, 700.00, 1800.00, 3300.00);

INSERT INTO voce_cedolino (tenant_id, cedolino_id, riga, tipo_voce_codice, quantita, importo) VALUES
    (:tenant, :cid, 1, '0201', NULL, 2000.00),
    (:tenant, :cid, 2, '0301', 5,     500.00);

INSERT INTO rateo (tenant_id, cedolino_id, tipo, spettante, goduto, residuo) VALUES
    (:tenant, :cid, 'FERIE', 2.16, 0, 2.16),
    (:tenant, :cid, 'ROL',   0.83, 0, 0.83);

INSERT INTO contributo (tenant_id, cedolino_id, tipo_contributo_codice,
                        imponibile, aliquota, quota_dipendente, quota_ditta) VALUES
    (:tenant, :cid, 'INPS_FPLD', 2500.00, 0.0919, 229.75, 595.25);

INSERT INTO addizionale (tenant_id, cedolino_id, tipo, imponibile, aliquota, importo) VALUES
    (:tenant, :cid, 'REGIONALE', 2270.25, 0.0173, 39.27),
    (:tenant, :cid, 'COMUNALE',  2270.25, 0.0080, 18.16);

COMMIT;
