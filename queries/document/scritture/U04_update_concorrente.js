// U04 — Ri-elaborazione dello stesso cedolino (documento condiviso: test di contesa).
const tenant = (typeof TENANT !== 'undefined') ? TENANT : 1;
const cid    = (typeof CID    !== 'undefined') ? CID    : 1;
const data   = (typeof DATA   !== 'undefined') ? DATA   : "2026-06-27";

db.cedolini.updateOne(
    { tenant_id: tenant, cedolino_id: cid },
    { $set: { data_elaborazione: data } }
);
