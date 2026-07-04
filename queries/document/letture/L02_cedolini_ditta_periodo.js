// L02 — Totali dei cedolini di una ditta per un mese.
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2026;
const mese   = (typeof MESE   !== 'undefined') ? MESE   : 6;

db.cedolini.aggregate([
    { $match: { tenant_id: tenant, anno: anno, mese: mese } },
    { $group: {
        _id: null,
        n_cedolini:    { $sum: 1 },
        competenze:    { $sum: "$totali.competenze" },
        trattenute:    { $sum: "$totali.trattenute" },
        netto:         { $sum: "$totali.netto" },
        costo_azienda: { $sum: "$totali.costo_azienda" }
    }}
]).toArray();
