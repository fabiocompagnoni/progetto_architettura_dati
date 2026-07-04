// L01 — Cedolino singolo per (dipendente, periodo).
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const dip    = (typeof DIP    !== 'undefined') ? DIP    : 1;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2026;
const mese   = (typeof MESE   !== 'undefined') ? MESE   : 6;

db.cedolini.find(
    { tenant_id: tenant, dipendente_id: dip, anno: anno, mese: mese },
    { _id: 0, cedolino_id: 1, dipendente_id: 1, anno: 1, mese: 1, totali: 1 }
).toArray();