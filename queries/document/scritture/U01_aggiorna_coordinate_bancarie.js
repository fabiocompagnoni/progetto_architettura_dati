// U01 — Aggiornamento delle coordinate bancarie di un dipendente (IBAN e banca).
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const dip    = (typeof DIP    !== 'undefined') ? DIP    : 1;
const iban   = (typeof IBAN   !== 'undefined') ? IBAN   : "IT60X0542811101000000123456";
const banca  = (typeof BANCA  !== 'undefined') ? BANCA  : "Intesa Sanpaolo";

db.dipendenti.updateOne(
    { tenant_id: tenant, dipendente_id: dip },
    { $set: { iban: iban, banca: banca } }
);
