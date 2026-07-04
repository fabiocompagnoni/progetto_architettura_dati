// L04 — RAL mediana per sesso e livello, su tutti i tenant.
db.dipendenti.aggregate([
    { $unwind: "$contratti" },
    { $group: {
        _id: { ccnl: "$contratti.ccnl", livello: "$contratti.livello", sesso: "$sesso" },
        ral_mediana: { $median: { input: "$contratti.ral", method: "approximate" } },
        n: { $sum: 1 }
    }},
    { $sort: { "_id.ccnl": 1, "_id.livello": 1, "_id.sesso": 1 } }
]).toArray();
