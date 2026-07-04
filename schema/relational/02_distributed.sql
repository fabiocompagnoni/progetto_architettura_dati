-- Tabelle distribuite per tenant_id (row-based). Stessa chiave di distribuzione ovunque
-- => co-locazione: join e transazioni dentro un tenant restano su un solo worker.
-- Le FK verso altre distribuite includono tenant_id (composite). Le FK verso le reference
-- table si aggiungono in fondo, a distribuzione avvenuta (Citus non le accetta prima).
-- Ogni tabella viene distribuita subito dopo la CREATE, in ordine di dipendenza.

CREATE TABLE ditta (
    tenant_id         bigint PRIMARY KEY,
    tipo              char(1) NOT NULL CHECK (tipo IN ('G', 'F')),  -- Giuridica / Fisica
    codice_fiscale    text,
    partita_iva       text,
    pec               text,
    email             text,
    telefono          text,
    data_costituzione date
);
SELECT create_distributed_table('ditta', 'tenant_id');

-- Generalizzazione (ristrutturata in relazioni 1:1): ogni ditta è persona giuridica o fisica.
CREATE TABLE persona_giuridica (
    tenant_id        bigint PRIMARY KEY REFERENCES ditta (tenant_id),
    ragione_sociale  text NOT NULL,
    forma_giuridica  text NOT NULL
);
SELECT create_distributed_table('persona_giuridica', 'tenant_id');

CREATE TABLE persona_fisica (
    tenant_id            bigint PRIMARY KEY REFERENCES ditta (tenant_id),
    cognome              text NOT NULL,
    nome                 text NOT NULL,
    sesso                char(1) NOT NULL CHECK (sesso IN ('M', 'F')),
    data_nascita         date NOT NULL,
    denominazione        text,
    comune_nascita char(4)
);
SELECT create_distributed_table('persona_fisica', 'tenant_id');

CREATE TABLE indirizzo (
    tenant_id     bigint NOT NULL REFERENCES ditta (tenant_id),
    indirizzo_id  bigint NOT NULL,
    ruolo         text NOT NULL CHECK (ruolo IN ('LEGALE', 'OPERATIVA')),
    via           text NOT NULL,
    civico        text,
    cap           char(5),
    comune  char(4) NOT NULL,
    PRIMARY KEY (tenant_id, indirizzo_id)
);
SELECT create_distributed_table('indirizzo', 'tenant_id');

CREATE TABLE centro_di_costo (
    tenant_id    bigint NOT NULL REFERENCES ditta (tenant_id),
    cdc_id       bigint NOT NULL,
    codice       text NOT NULL,
    descrizione  text NOT NULL,
    PRIMARY KEY (tenant_id, cdc_id)
);
SELECT create_distributed_table('centro_di_costo', 'tenant_id');

CREATE TABLE unita_appartenenza (
    tenant_id    bigint NOT NULL REFERENCES ditta (tenant_id),
    codice       text NOT NULL,
    descrizione  text NOT NULL,
    PRIMARY KEY (tenant_id, codice)
);
SELECT create_distributed_table('unita_appartenenza', 'tenant_id');

CREATE TABLE ditta_ateco (
    tenant_id     bigint NOT NULL REFERENCES ditta (tenant_id),
    ateco_codice  text NOT NULL,
    PRIMARY KEY (tenant_id, ateco_codice)
);
SELECT create_distributed_table('ditta_ateco', 'tenant_id');

CREATE TABLE ditta_ccnl (
    tenant_id    bigint NOT NULL REFERENCES ditta (tenant_id),
    ccnl_codice  text NOT NULL,
    PRIMARY KEY (tenant_id, ccnl_codice)
);
SELECT create_distributed_table('ditta_ccnl', 'tenant_id');

CREATE TABLE dipendente (
    tenant_id            bigint NOT NULL REFERENCES ditta (tenant_id),
    dipendente_id        bigint NOT NULL,
    codice_fiscale       text NOT NULL,
    matricola            text NOT NULL,
    cognome              text NOT NULL,
    nome                 text NOT NULL,
    sesso                char(1) NOT NULL CHECK (sesso IN ('M', 'F')),
    data_nascita         date NOT NULL,
    comune_nascita char(4),
    modalita_pagamento   text,
    iban                 text,
    banca                text,
    cdc_id               bigint,
    PRIMARY KEY (tenant_id, dipendente_id),
    UNIQUE (tenant_id, matricola),
    FOREIGN KEY (tenant_id, cdc_id) REFERENCES centro_di_costo (tenant_id, cdc_id)
);
SELECT create_distributed_table('dipendente', 'tenant_id');

CREATE TABLE contratto (
    tenant_id        bigint NOT NULL,
    contratto_id     bigint NOT NULL,
    dipendente_id    bigint NOT NULL,
    tipo_rapporto    char(2) NOT NULL CHECK (tipo_rapporto IN ('TI', 'TD')),
    qualifica        text NOT NULL,
    mansione         text,
    part_time_perc   numeric(5,2) NOT NULL DEFAULT 100,
    ore_settimanali  numeric(4,1) NOT NULL,
    ral              numeric(14,2) NOT NULL,
    paga_oraria      numeric(8,4) NOT NULL,
    data_inizio      date NOT NULL,
    data_fine        date,                                  -- NULL = tempo indeterminato
    ccnl_codice      text NOT NULL,
    cod_suddivisione text NOT NULL,
    livello          text NOT NULL,
    PRIMARY KEY (tenant_id, contratto_id),
    FOREIGN KEY (tenant_id, dipendente_id) REFERENCES dipendente (tenant_id, dipendente_id)
);
SELECT create_distributed_table('contratto', 'tenant_id');

CREATE TABLE cedolino (
    tenant_id          bigint NOT NULL,
    cedolino_id        bigint NOT NULL,
    dipendente_id      bigint NOT NULL,
    anno               smallint NOT NULL,
    mese               smallint NOT NULL CHECK (mese BETWEEN 1 AND 12),
    data_elaborazione  date,
    tot_competenze     numeric(14,2) NOT NULL DEFAULT 0,
    tot_trattenute     numeric(14,2) NOT NULL DEFAULT 0,
    netto              numeric(14,2) NOT NULL DEFAULT 0,
    imponibile_prev    numeric(14,2) NOT NULL DEFAULT 0,
    imponibile_fisc    numeric(14,2) NOT NULL DEFAULT 0,
    irpef_lorda        numeric(14,2) NOT NULL DEFAULT 0,
    irpef_netta        numeric(14,2) NOT NULL DEFAULT 0,
    tot_detrazioni     numeric(14,2) NOT NULL DEFAULT 0,
    costo_azienda      numeric(14,2) NOT NULL DEFAULT 0,
    ore_ordinarie      numeric(6,2)  NOT NULL DEFAULT 0,
    ore_straordinarie  numeric(6,2)  NOT NULL DEFAULT 0,
    tfr_quota          numeric(14,2) NOT NULL DEFAULT 0,
    tfr_rivalutazione  numeric(14,2) NOT NULL DEFAULT 0,
    tfr_fondo          numeric(14,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_id, cedolino_id),
    UNIQUE (tenant_id, dipendente_id, anno, mese),
    FOREIGN KEY (tenant_id, dipendente_id) REFERENCES dipendente (tenant_id, dipendente_id)
);
SELECT create_distributed_table('cedolino', 'tenant_id');
CREATE INDEX idx_cedolino_periodo ON cedolino (tenant_id, anno, mese);

CREATE TABLE voce_cedolino (
    tenant_id          bigint NOT NULL,
    cedolino_id        bigint NOT NULL,
    riga               int NOT NULL,
    tipo_voce_codice   text NOT NULL,
    quantita           numeric(12,2),
    importo            numeric(14,2) NOT NULL,
    costo_azienda      numeric(14,2) NOT NULL DEFAULT 0,
    conto              text,
    PRIMARY KEY (tenant_id, cedolino_id, riga),
    FOREIGN KEY (tenant_id, cedolino_id) REFERENCES cedolino (tenant_id, cedolino_id)
);
SELECT create_distributed_table('voce_cedolino', 'tenant_id');

CREATE TABLE rateo (
    tenant_id    bigint NOT NULL,
    cedolino_id  bigint NOT NULL,
    tipo         text NOT NULL CHECK (tipo IN ('FERIE', 'ROL', 'PERMESSI', 'EX_FEST')),
    spettante    numeric(8,2) NOT NULL DEFAULT 0,
    goduto       numeric(8,2) NOT NULL DEFAULT 0,
    residuo      numeric(8,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_id, cedolino_id, tipo),
    FOREIGN KEY (tenant_id, cedolino_id) REFERENCES cedolino (tenant_id, cedolino_id)
);
SELECT create_distributed_table('rateo', 'tenant_id');

CREATE TABLE contributo (
    tenant_id              bigint NOT NULL,
    cedolino_id            bigint NOT NULL,
    tipo_contributo_codice text NOT NULL,
    imponibile             numeric(14,2) NOT NULL,
    aliquota               numeric(6,3) NOT NULL,
    quota_dipendente       numeric(14,2) NOT NULL DEFAULT 0,
    quota_ditta            numeric(14,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_id, cedolino_id, tipo_contributo_codice),
    FOREIGN KEY (tenant_id, cedolino_id) REFERENCES cedolino (tenant_id, cedolino_id)
);
SELECT create_distributed_table('contributo', 'tenant_id');

CREATE TABLE addizionale (
    tenant_id    bigint NOT NULL,
    cedolino_id  bigint NOT NULL,
    tipo         text NOT NULL CHECK (tipo IN ('REGIONALE', 'COMUNALE', 'ACCONTO')),
    imponibile   numeric(14,2) NOT NULL,
    aliquota     numeric(6,3) NOT NULL,
    importo      numeric(14,2) NOT NULL,
    PRIMARY KEY (tenant_id, cedolino_id, tipo),
    FOREIGN KEY (tenant_id, cedolino_id) REFERENCES cedolino (tenant_id, cedolino_id)
);
SELECT create_distributed_table('addizionale', 'tenant_id');

CREATE TABLE giorno (
    tenant_id          bigint NOT NULL,
    cedolino_id        bigint NOT NULL,
    data               date NOT NULL,
    tipo_giorno        text NOT NULL,
    ore_teoriche       numeric(4,2) NOT NULL DEFAULT 0,
    ore_lavorate       numeric(4,2) NOT NULL DEFAULT 0,
    ore_straordinario  numeric(4,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_id, cedolino_id, data),
    FOREIGN KEY (tenant_id, cedolino_id) REFERENCES cedolino (tenant_id, cedolino_id)
);
SELECT create_distributed_table('giorno', 'tenant_id');

CREATE TABLE timbratura (
    tenant_id    bigint NOT NULL,
    cedolino_id  bigint NOT NULL,
    data         date NOT NULL,
    progressivo  smallint NOT NULL,
    ora_entrata  time NOT NULL,
    ora_uscita   time,
    PRIMARY KEY (tenant_id, cedolino_id, data, progressivo),
    FOREIGN KEY (tenant_id, cedolino_id, data) REFERENCES giorno (tenant_id, cedolino_id, data)
);
SELECT create_distributed_table('timbratura', 'tenant_id');

CREATE TABLE assenza (
    tenant_id       bigint NOT NULL,
    cedolino_id     bigint NOT NULL,
    data            date NOT NULL,
    causale_codice  text NOT NULL,
    ore             numeric(4,2) NOT NULL,
    PRIMARY KEY (tenant_id, cedolino_id, data, causale_codice),
    FOREIGN KEY (tenant_id, cedolino_id, data) REFERENCES giorno (tenant_id, cedolino_id, data)
);
SELECT create_distributed_table('assenza', 'tenant_id');

-- Aggiunte a distribuzione avvenuta
ALTER TABLE persona_fisica ADD FOREIGN KEY (comune_nascita) REFERENCES comune (codice_catastale);
ALTER TABLE indirizzo      ADD FOREIGN KEY (comune)         REFERENCES comune (codice_catastale);
ALTER TABLE dipendente     ADD FOREIGN KEY (comune_nascita) REFERENCES comune (codice_catastale);
ALTER TABLE ditta_ateco    ADD FOREIGN KEY (ateco_codice)         REFERENCES ateco (codice);
ALTER TABLE ditta_ccnl     ADD FOREIGN KEY (ccnl_codice)          REFERENCES ccnl (codice);
ALTER TABLE contratto      ADD FOREIGN KEY (ccnl_codice, cod_suddivisione, livello)
                               REFERENCES livello (ccnl_codice, cod_suddivisione, livello);
ALTER TABLE voce_cedolino  ADD FOREIGN KEY (tipo_voce_codice)        REFERENCES tipo_voce (codice);
ALTER TABLE contributo     ADD FOREIGN KEY (tipo_contributo_codice) REFERENCES tipo_contributo (codice);
ALTER TABLE assenza        ADD FOREIGN KEY (causale_codice)          REFERENCES causale_assenza (codice);