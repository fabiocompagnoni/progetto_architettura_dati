// L13 — Riepilogo ferie/permessi/malattia a fine anno, per dipendente di una ditta.
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const anno   = (typeof ANNO   !== 'undefined') ? ANNO   : 2026;

db.cedolini.aggregate([
    { $match: { tenant_id: tenant, anno: anno } },
    { $unwind: "$giorni" },
    { $unwind: { path: "$giorni.assenze", preserveNullAndEmptyArrays: true } },
    { $group: {
        _id: "$dipendente_id",
        ferie_godute_ore:    { $sum: { $cond: [ { $eq: ["$giorni.assenze.causale", "FE"] }, "$giorni.assenze.ore", 0 ] } },
        permessi_goduti_ore: { $sum: { $cond: [ { $in: ["$giorni.assenze.causale", ["PR", "P104"]] }, "$giorni.assenze.ore", 0 ] } },
        malattia_ore:        { $sum: { $cond: [ { $eq: ["$giorni.assenze.causale", "MA"] }, "$giorni.assenze.ore", 0 ] } }
    }},
    { $lookup: {                          // residuo a fine anno dai ratei di dicembre
        from: "cedolini",
        let: { d: "$_id" },
        pipeline: [
            { $match: { $expr: { $and: [ { $eq: ["$tenant_id", tenant] }, { $eq: ["$anno", anno] },
                                         { $eq: ["$mese", 12] }, { $eq: ["$dipendente_id", "$$d"] } ] } } },
            { $unwind: "$ratei" },
            { $group: {
                _id: null,
                ferie_gg:    { $sum: { $cond: [ { $eq: ["$ratei.tipo", "FERIE"] }, "$ratei.residuo", 0 ] } },
                permessi_gg: { $sum: { $cond: [ { $eq: ["$ratei.tipo", "PERMESSI"] }, "$ratei.residuo", 0 ] } }
            }}
        ],
        as: "res"
    }},
    { $set: {
        ferie_residue_ore:    { $round: [ { $multiply: [ { $ifNull: [ { $arrayElemAt: ["$res.ferie_gg", 0] }, 0 ] }, 8 ] }, 2 ] },
        permessi_residui_ore: { $round: [ { $multiply: [ { $ifNull: [ { $arrayElemAt: ["$res.permessi_gg", 0] }, 0 ] }, 8 ] }, 2 ] }
    }},
    { $project: { _id: 0, dipendente_id: "$_id",
                  ferie_godute_ore: 1, ferie_residue_ore: 1,
                  permessi_goduti_ore: 1, permessi_residui_ore: 1, malattia_ore: 1 } },
    { $sort: { dipendente_id: 1 } }
]).toArray();
