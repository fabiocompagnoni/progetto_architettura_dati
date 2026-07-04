// U03 — Riclassifica un tipo voce: aggiorna la categoria denormalizzata nelle voci dei cedolini.
const codiceVoce = (typeof CODICE_VOCE !== 'undefined') ? CODICE_VOCE : "0401";
const categoria  = (typeof CATEGORIA   !== 'undefined') ? CATEGORIA   : "WELFARE";

const res = db.cedolini.updateMany(
    { "voci.tipo": codiceVoce },
    { $set: { "voci.$[e].categoria": categoria } },
    { arrayFilters: [ { "e.tipo": codiceVoce } ] }
);
print("cedolini toccati: " + res.modifiedCount + " (trovati: " + res.matchedCount + ")");
