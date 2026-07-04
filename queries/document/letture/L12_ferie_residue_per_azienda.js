// L12 — Ferie residue a fine anno per azienda: giorni, ore e costo stimato.
const anno = (typeof ANNO !== 'undefined') ? ANNO : 2026;

db.cedolini.aggregate([
    { $match: { anno: anno, mese: 12 } },
    { $unwind: "$ratei" },
    { $match: { "ratei.tipo": "FERIE" } },
    { $lookup: {
        from: "dipendenti",
        let: { t: "$tenant_id", d: "$dipendente_id" },
        pipeline: [
            { $match: { $expr: { $and: [ { $eq: ["$tenant_id", "$$t"] }, { $eq: ["$dipendente_id", "$$d"] } ] } } },
            { $project: { _id: 0, paga: { $arrayElemAt: ["$contratti.paga_oraria", 0] } } }
        ],
        as: "dip"
    }},
    { $unwind: "$dip" },
    { $group: {
        _id: "$tenant_id",
        ferie_residue_giorni: { $sum: "$ratei.residuo" },
        costo_ferie_residue:  { $sum: { $multiply: ["$ratei.residuo", 8, "$dip.paga"] } }
    }},
    { $set: {
        ferie_residue_ore:    { $round: [ { $multiply: ["$ferie_residue_giorni", 8] }, 2 ] },
        ferie_residue_giorni: { $round: ["$ferie_residue_giorni", 2] },
        costo_ferie_residue:  { $round: ["$costo_ferie_residue", 2] }
    }},
    { $sort: { costo_ferie_residue: -1 } }
]).toArray();
