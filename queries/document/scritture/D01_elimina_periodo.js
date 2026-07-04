// D01 — Cancellazione dei cedolini di un periodo di una ditta.
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2026;
const mese   = (typeof MESE   !== 'undefined') ? MESE   : 1;

db.cedolini.deleteMany({ tenant_id: tenant, anno: anno, mese: mese });
