// L05 — Le N retribuzioni (RAL) piu' alte, su tutti i tenant.
const n = (typeof N !== 'undefined') ? N : 20;

db.dipendenti.aggregate([
    { $unwind: "$contratti" },
    { $project: { _id: 0, tenant_id: 1, dipendente_id: 1, cognome: 1, nome: 1, ral: "$contratti.ral" } },
    { $sort: { ral: -1 } },
    { $limit: n }
]).toArray();
