// L07 — Ore di straordinario per centro di costo di una ditta, in un anno.
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2026;

db.cedolini.aggregate([
    { $match: { tenant_id: tenant, anno: anno } },
    { $unwind: "$voci" },
    { $match: { "voci.tipo": "0301" } },
    { $group: {
        _id: "$dipendente.cdc",
        ore_straordinario: { $sum: "$voci.quantita" }
    }},
    { $sort: { ore_straordinario: -1 } }
]).toArray();
