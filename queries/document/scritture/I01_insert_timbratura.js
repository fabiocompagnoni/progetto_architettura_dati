// I01 — Inserimento di una timbratura su un giorno esistente.
const tenant  = (typeof TENANT  !== 'undefined') ? TENANT  : 1;
const entrata = (typeof ENTRATA !== 'undefined') ? ENTRATA : "08:00";
const uscita  = (typeof USCITA  !== 'undefined') ? USCITA  : "17:00";

const doc = db.cedolini.findOne({ tenant_id: tenant, "giorni.0": { $exists: true } });
const gdata = doc.giorni[0].data;
const progressivo = doc.giorni[0].timbrature.length + 1;

db.cedolini.updateOne(
    { tenant_id: tenant, cedolino_id: doc.cedolino_id, "giorni.data": gdata },
    { $push: { "giorni.$.timbrature": { progressivo: progressivo, ora_entrata: entrata, ora_uscita: uscita } } }
);
