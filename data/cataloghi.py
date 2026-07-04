"""Dati di riferimento. Settori/CCNL (CNEL), ATECO e comuni sono autoritativi (dai file
JSON); tipi voce, contributi e causali sono calibrati sui cedolini reali. I livelli e i
minimi tabellari non esistono in questi dataset e vengono sintetizzati dal generatore."""

import json
import os

_DIR = os.path.dirname(__file__)


def _leggi(*parti):
    with open(os.path.join(_DIR, *parti), encoding="utf-8") as f:
        return json.load(f)


def _carica_ccnl():
    settori = {}   # descrizione settore -> codice
    ccnl = {}      # codiceCcnl -> (codice, descrizione, settore)
    for x in _leggi("ccnl.json")["data"]:
        codice = x.get("codiceCcnl")
        settore = (x.get("settoriDescrizione") or [None])[0]
        if not codice or not settore or codice in ccnl:
            continue
        settori.setdefault(settore, f"S{len(settori) + 1:02d}")
        nome = (x.get("sottosettoriDescrizione") or [settore])[0]
        ccnl[codice] = (codice, nome[:120], settori[settore])
    settori_list = [(cod, descr) for descr, cod in settori.items()]
    # maggiorazione straordinario sintetica (il CNEL non la espone)
    ccnl_list = [(c, d, s, 1.250) for (c, d, s) in ccnl.values()]
    return settori_list, ccnl_list


SETTORI, CCNL = _carica_ccnl()

# ATECO: solo il livello foglia (codice attività a 6 cifre)
ATECO = [(r["code"], r["title_it"][:150]) for r in _leggi("ateco-records.json") if r["level"] == 6]

# Comuni: codice catastale/Belfiore (es. E507 = Lecco), lo stesso dei cedolini reali.
# (codice_catastale, nome, provincia, residenti) — i residenti pesano il campionamento.
COMUNI = [(r["cod_fisco"], r["comune"], r["provincia"], r["num_residenti"])
          for r in _leggi("comuni", "italy_cities.json")["Foglio1"]]

# Modello sintetico dei livelli (il CNEL non espone i minimi tabellari): la stessa scala si
# applica a ogni CCNL, e per ogni indice di livello si ha una qualifica con le sue mansioni.
# (livello, descrizione, moltiplicatore_paga)
LADDER = [
    ("1", "Operaio comune",       1.00),
    ("2", "Operaio qualificato",  1.12),
    ("3", "Impiegato",            1.28),
    ("4", "Impiegato direttivo",  1.50),
    ("5", "Quadro",               1.85),
    ("6", "Dirigente",            2.70),
]

# (qualifica, [mansioni]) per lo stesso indice di livello del ladder
QUALIFICHE = [
    ("Operaio",   ["Addetto produzione", "Magazziniere", "Conduttore linea", "Manutentore"]),
    ("Operaio",   ["Operaio specializzato", "Attrezzista", "Saldatore", "Elettricista"]),
    ("Impiegato", ["Impiegato amministrativo", "Addetto contabilita", "Addetto paghe", "Addetto acquisti"]),
    ("Impiegato", ["Responsabile ufficio", "Analista", "Tecnico commerciale", "Programmatore"]),
    ("Quadro",    ["Responsabile di area", "Project manager", "Capo reparto"]),
    ("Dirigente", ["Direttore di stabilimento", "Direttore commerciale", "Direttore tecnico"]),
]

# (codice, descrizione, categoria, segno, imponibile_previdenziale, imponibile_fiscale)
TIPI_VOCE = [
    ("0201", "Retribuzione ordinaria",       "retribuzione",  "C", True,  True),
    ("0202", "Tredicesima mensilita",        "retribuzione",  "C", True,  True),
    ("0203", "Quattordicesima mensilita",    "retribuzione",  "C", True,  True),
    ("0204", "Scatti di anzianita",          "retribuzione",  "C", True,  True),
    ("0205", "Superminimo individuale",      "retribuzione",  "C", True,  True),
    ("0210", "Ferie godute",                 "retribuzione",  "C", True,  True),
    ("0211", "Festivita godute",             "retribuzione",  "C", True,  True),
    ("0212", "ROL godute",                   "retribuzione",  "C", True,  True),
    ("0301", "Straordinario diurno",         "straordinario", "C", True,  True),
    ("0302", "Ore straordinario forfait",    "straordinario", "C", True,  True),
    ("0303", "Lavoro supplementare",         "straordinario", "C", True,  True),
    ("0304", "Ore con maggiorazione",        "straordinario", "C", True,  True),
    ("0305", "Maggiorazione notturna",       "straordinario", "C", True,  True),
    ("0306", "Indennita di turno",           "indennita",     "C", True,  True),
    ("0307", "Indennita di trasferta",       "indennita",     "C", True,  True),
    ("0401", "Bonus",                        "bonus",         "C", True,  True),
    ("0402", "Premio di risultato",          "bonus",         "C", True,  True),
    ("0410", "Premio a welfare-benefit",     "welfare",       "C", False, False),
    ("0411", "Welfare CCNL",                 "welfare",       "C", False, False),
    ("0412", "Welfare beni e servizi",       "welfare",       "C", False, False),
    ("0413", "Welfare istruzione",           "welfare",       "C", False, False),
    ("0420", "Fringe benefit",               "benefit",       "C", True,  True),
    ("0421", "Ticket restaurant",            "benefit",       "C", False, False),
    ("0501", "Integrazione malattia ditta",  "malattia",      "C", True,  True),
    ("0502", "Carenza malattia",             "malattia",      "C", True,  True),
    ("0503", "Integrazione festivita malattia", "malattia",   "C", True,  True),
    ("0601", "Rimborso spese figurativo",    "rimborso",      "C", False, False),
    ("9101", "Trattenuta sindacale",         "trattenuta",    "T", False, False),
    ("9102", "Trattenuta mensa",             "trattenuta",    "T", False, False),
    ("9103", "Trattenuta ore assenza",       "trattenuta",    "T", False, False),
    ("9104", "Trattenuta pignoramento",      "trattenuta",    "T", False, False),
    ("9105", "Trattenuta prestito",          "trattenuta",    "T", False, False),
    ("9106", "Contravvenzione",              "trattenuta",    "T", False, False),
    ("9201", "Contributo FPC dipendente",    "contributo",    "T", False, False),
    ("9302", "Imposta sostitutiva 15%",      "imposta",       "T", False, False),
    ("9401", "Storno TFR a FPC",             "tfr",           "T", False, False),
    ("9402", "Anticipo TFR",                 "tfr",           "T", False, False),
]

# (codice, descrizione, ente)
TIPI_CONTRIBUTO = [
    ("INPS_FPLD",  "INPS Fondo Pensione Lavoratori Dipendenti", "INPS"),
    ("INPS_CIGO",  "INPS Cassa Integrazione Ordinaria",         "INPS"),
    ("INPS_CIGS",  "INPS Cassa Integrazione Straordinaria",     "INPS"),
    ("INPS_MAT",   "INPS Maternita",                            "INPS"),
    ("INPS_MAL",   "INPS Malattia",                             "INPS"),
    ("INPS_TFR",   "INPS Fondo Tesoreria TFR",                  "INPS"),
    ("INAIL",      "INAIL premio assicurativo",                 "INAIL"),
    ("FPC",        "Fondo Pensione Complementare",              "FONDO"),
    ("SOLID",      "Contributo di solidarieta",                 "INPS"),
]

# (codice, descrizione, retribuita, incide_ratei)
CAUSALI = [
    ("FE",   "Ferie",                   True,  True),
    ("RO",   "ROL",                     True,  True),
    ("EF",   "Ex festivita",            True,  True),
    ("MA",   "Malattia",                True,  False),
    ("IN",   "Infortunio",              True,  False),
    ("P104", "Permesso L.104/92",       True,  False),
    ("PR",   "Permesso retribuito",     True,  False),
    ("PNR",  "Permesso non retribuito", False, False),
    ("CO",   "Congedo parentale",       True,  False),
    ("MAT",  "Maternita",               True,  False),
    ("PAT",  "Paternita",               True,  False),
    ("SC",   "Sciopero",                False, False),
    ("AS",   "Aspettativa",             False, False),
    ("LU",   "Permesso lutto",          True,  False),
    ("MATR", "Permesso matrimonio",     True,  False),
    ("ST",   "Permesso studio",         True,  False),
    ("DS",   "Donazione sangue",        True,  False),
]
