// L11 — Per categoria ATECO: numero di aziende, dipendenti, spesa annua/mensile e stipendio medio.
const anno = (typeof ANNO !== 'undefined') ? ANNO : 2026;

db.cedolini.aggregate([
    { $match: { anno: anno } },
    { $group: {
        _id: "$tenant_id",
        spesa:      { $sum: "$totali.competenze" },
        dipendenti: { $addToSet: "$dipendente_id" }
    }},
    { $lookup: { from: "ditte", localField: "_id", foreignField: "tenant_id", as: "d" } },
    { $unwind: "$d" },
    { $set: { categoria: { $min: "$d.ateco" } } },      // ATECO principale = codice minore
    { $group: {
        _id:          "$categoria",
        n_aziende:    { $sum: 1 },
        n_dipendenti: { $sum: { $size: "$dipendenti" } },
        spesa_annua:  { $sum: "$spesa" }
    }},
    { $set: {
        spesa_annua:           { $round: ["$spesa_annua", 2] },
        spesa_mensile_media:   { $round: [ { $divide: ["$spesa_annua", 12] }, 2 ] },
        stipendio_medio_annuo: { $round: [ { $divide: ["$spesa_annua", "$n_dipendenti"] }, 2 ] }
    }},
    { $sort: { spesa_annua: -1 } }
]).toArray();
