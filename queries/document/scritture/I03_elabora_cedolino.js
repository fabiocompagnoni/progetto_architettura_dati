// I03 — Elaborazione del cedolino: un solo documento inserito (intestazione + voci + ratei + contributi + addizionali).
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const dip    = (typeof DIP    !== 'undefined') ? DIP    : 1;
const cid    = (typeof CID    !== 'undefined') ? CID    : 900001;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2099;
const mese   = (typeof MESE   !== 'undefined') ? MESE   : 6;

db.cedolini.deleteMany({ tenant_id: NumberLong(tenant), cedolino_id: NumberLong(cid) });

db.cedolini.insertOne({
    tenant_id: NumberLong(tenant),
    cedolino_id: NumberLong(cid),
    dipendente_id: NumberLong(dip),
    anno: NumberInt(anno),
    mese: NumberInt(mese),
    dipendente: { sesso: "M", livello: "3", ccnl: "A014", cdc: 1 },
    totali: { competenze: 2500.00, trattenute: 700.00, netto: 1800.00, costo_azienda: 3300.00 },
    voci: [
        { riga: 1, tipo: "0201", importo: 2000.00 },
        { riga: 2, tipo: "0301", quantita: 5, importo: 500.00 }
    ],
    ratei: [
        { tipo: "FERIE", spettante: 2.16, goduto: 0, residuo: 2.16 },
        { tipo: "ROL",   spettante: 0.83, goduto: 0, residuo: 0.83 }
    ],
    contributi: [
        { tipo: "INPS_FPLD", imponibile: 2500.00, aliquota: 0.0919, quota_dipendente: 229.75, quota_ditta: 595.25 }
    ],
    addizionali: [
        { tipo: "REGIONALE", imponibile: 2270.25, aliquota: 0.0173, importo: 39.27 },
        { tipo: "COMUNALE",  imponibile: 2270.25, aliquota: 0.0080, importo: 18.16 }
    ]
});