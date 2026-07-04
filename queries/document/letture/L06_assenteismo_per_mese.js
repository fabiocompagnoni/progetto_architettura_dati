// L06 — Ore di assenza per mese e causale, su tutti i tenant.
const anno = (typeof ANNO !== 'undefined') ? ANNO : 2026;

db.cedolini.aggregate([
    { $match: { anno: anno } },
    { $unwind: "$giorni" },
    { $unwind: "$giorni.assenze" },
    { $group: {
        _id: { mese: "$mese", causale: "$giorni.assenze.causale" },
        ore:    { $sum: "$giorni.assenze.ore" },
        giorni: { $sum: 1 }
    }},
    { $sort: { "_id.mese": 1, "_id.causale": 1 } }
]).toArray();
