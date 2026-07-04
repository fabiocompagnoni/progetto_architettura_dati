// L10 — Cedolino completo (un solo documento) per (dipendente, periodo).
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const dip    = (typeof DIP    !== 'undefined') ? DIP    : 1;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2026;
const mese   = (typeof MESE   !== 'undefined') ? MESE   : 6;

db.cedolini.findOne({ tenant_id: tenant, dipendente_id: dip, anno: anno, mese: mese });
