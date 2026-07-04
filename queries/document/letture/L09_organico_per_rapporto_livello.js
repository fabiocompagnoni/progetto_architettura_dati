// L09 — Organico per tipo di rapporto e livello, su tutti i tenant.
db.dipendenti.aggregate([
    { $unwind: "$contratti" },
    { $group: {
        _id: { ccnl: "$contratti.ccnl", livello: "$contratti.livello", tipo: "$contratti.tipo_rapporto" },
        n_dipendenti: { $sum: 1 }
    }},
    { $sort: { "_id.ccnl": 1, "_id.livello": 1, "_id.tipo": 1 } }
]).toArray();
