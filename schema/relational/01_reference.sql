-- Cataloghi condivisi da tutti i tenant: in Citus diventano reference table, replicate su ogni worker così i join con le tabelle distribuite restano locali.
-- Creati in ordine di dipendenza (una FK verso una reference richiede che il target sia già reference).

CREATE TABLE comune (
    codice_catastale  char(4) PRIMARY KEY,
    nome          text NOT NULL,
    provincia     char(2) NOT NULL
);
SELECT create_reference_table('comune');

-- Classificazione attività economica
CREATE TABLE ateco (
    codice       text PRIMARY KEY,
    descrizione  text NOT NULL
);
SELECT create_reference_table('ateco');

-- Gerarchia del contratto collettivo: settore -> ccnl -> suddivisione -> livello
CREATE TABLE settore_ccnl (
    codice       text PRIMARY KEY,
    descrizione  text NOT NULL
);
SELECT create_reference_table('settore_ccnl');

CREATE TABLE ccnl (
    codice           text PRIMARY KEY,
    descrizione      text NOT NULL,
    settore_codice   text NOT NULL REFERENCES settore_ccnl (codice),
    -- maggiorazione dello straordinario definita dal CCNL, es. 1.25 = +25%
    maggiorazione_str numeric(5,3) NOT NULL DEFAULT 1
);
SELECT create_reference_table('ccnl');

CREATE TABLE suddivisione (
    ccnl_codice       text NOT NULL REFERENCES ccnl (codice),
    cod_suddivisione  text NOT NULL,
    descrizione       text,
    PRIMARY KEY (ccnl_codice, cod_suddivisione)
);
SELECT create_reference_table('suddivisione');

CREATE TABLE livello (
    ccnl_codice       text NOT NULL,
    cod_suddivisione  text NOT NULL,
    livello           text NOT NULL,
    descrizione       text,
    paga_base         numeric(14,2) NOT NULL,
    paga_oraria_min   numeric(8,4) NOT NULL,
    PRIMARY KEY (ccnl_codice, cod_suddivisione, livello),
    FOREIGN KEY (ccnl_codice, cod_suddivisione)
        REFERENCES suddivisione (ccnl_codice, cod_suddivisione)
);
SELECT create_reference_table('livello');

-- Cataloghi delle componenti del cedolino
CREATE TABLE tipo_voce (
    codice                    text PRIMARY KEY,
    descrizione               text NOT NULL,
    categoria                 text NOT NULL,
    segno                     char(1) NOT NULL CHECK (segno IN ('C', 'T')),
    imponibile_previdenziale  boolean NOT NULL DEFAULT false,
    imponibile_fiscale        boolean NOT NULL DEFAULT false
);
SELECT create_reference_table('tipo_voce');

CREATE TABLE tipo_contributo (
    codice       text PRIMARY KEY,
    descrizione  text NOT NULL,
    ente         text NOT NULL
);
SELECT create_reference_table('tipo_contributo');

CREATE TABLE causale_assenza (
    codice        text PRIMARY KEY,
    descrizione   text NOT NULL,
    retribuita    boolean NOT NULL,
    incide_ratei  boolean NOT NULL
);
SELECT create_reference_table('causale_assenza');