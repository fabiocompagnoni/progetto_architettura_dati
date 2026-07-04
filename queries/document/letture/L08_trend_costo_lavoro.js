// L08 — Andamento mensile del costo del lavoro, su tutti i tenant.
const anno = (typeof ANNO !== 'undefined') ? ANNO : 2026;

db.cedolini.aggregate([
    { $match: { anno: anno } },
    { $group: {
        _id: "$mese",
        costo_totale: { $sum: "$totali.costo_azienda" },
        n_cedolini:   { $sum: 1 }
    }},
    { $sort: { _id: 1 } }
]).toArray();
