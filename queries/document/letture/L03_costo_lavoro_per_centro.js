// L03 — Costo del lavoro per centro di costo di una ditta, dettaglio mensile in un anno.
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2026;

db.cedolini.aggregate([
    { $match: { tenant_id: tenant, anno: anno } },
    { $group: {
        _id: { centro: "$dipendente.cdc", mese: "$mese" },
        costo:      { $sum: "$totali.costo_azienda" },
        n_cedolini: { $sum: 1 }
    }},
    { $sort: { "_id.centro": 1, "_id.mese": 1 } }
]).toArray();
