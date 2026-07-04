// U02 — Licenziamento: imposta la data di fine sul contratto di un dipendente.
const tenant   = (typeof TENANT    !== 'undefined') ? TENANT    : 1;
const dip      = (typeof DIP       !== 'undefined') ? DIP       : 1;
const dataFine = (typeof DATA_FINE !== 'undefined') ? DATA_FINE : "2026-12-31";

db.dipendenti.updateOne(
    { tenant_id: tenant, dipendente_id: dip },
    { $set: { "contratti.$[].data_fine": dataFine } }
);
