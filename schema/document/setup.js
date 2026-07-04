const db = db.getSiblingDB("archdata");

db.createCollection("ditte", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["tenant_id", "tipo", "persona"],
    properties: {
      tenant_id: { bsonType: "long" },
      tipo: { enum: ["G", "F"] },
      persona: { bsonType: "object" },
      indirizzi: { bsonType: "array" },
      centri_di_costo: { bsonType: "array" },
      unita: { bsonType: "array" },
      ateco: { bsonType: "array" },
      ccnl: { bsonType: "array" }
    }
  }}
});

db.createCollection("dipendenti", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["tenant_id", "dipendente_id", "codice_fiscale", "matricola", "sesso", "contratti"],
    properties: {
      tenant_id: { bsonType: "long" },
      dipendente_id: { bsonType: "long" },
      sesso: { enum: ["M", "F"] },
      contratti: { bsonType: "array" }
    }
  }}
});

db.createCollection("cedolini", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["tenant_id", "cedolino_id", "dipendente_id", "anno", "mese", "dipendente", "totali", "voci"],
    properties: {
      tenant_id: { bsonType: "long" },
      cedolino_id: { bsonType: "long" },
      dipendente_id: { bsonType: "long" },
      anno: { bsonType: "int" },
      mese: { bsonType: "int", minimum: 1, maximum: 12 },
      dipendente: {
        bsonType: "object",
        required: ["sesso", "livello"],
        properties: { sesso: { enum: ["M", "F"] } }
      },
      totali: { bsonType: "object" },
      voci: { bsonType: "array" },
      ratei: { bsonType: "array" },
      contributi: { bsonType: "array" },
      addizionali: { bsonType: "array" },
      giorni: { bsonType: "array" }
    }
  }}
});

["comuni", "ateco", "ccnl", "tipi_voce", "tipi_contributo", "causali"].forEach(c => db.createCollection(c));

db.dipendenti.createIndex({ tenant_id: 1, dipendente_id: 1 });
db.dipendenti.createIndex({ tenant_id: 1, matricola: 1 });
db.dipendenti.createIndex({ tenant_id: 1, sesso: 1 });

db.cedolini.createIndex({ tenant_id: 1, dipendente_id: 1, anno: 1, mese: 1 });
db.cedolini.createIndex({ tenant_id: 1, anno: 1, mese: 1 });
db.cedolini.createIndex({ tenant_id: 1, "dipendente.sesso": 1, "dipendente.livello": 1 });

db.comuni.createIndex({ codice_catastale: 1 }, { unique: true });
db.ateco.createIndex({ codice: 1 }, { unique: true });
db.ccnl.createIndex({ codice: 1 }, { unique: true });
db.tipi_voce.createIndex({ codice: 1 }, { unique: true });
db.tipi_contributo.createIndex({ codice: 1 }, { unique: true });
db.causali.createIndex({ codice: 1 }, { unique: true });
