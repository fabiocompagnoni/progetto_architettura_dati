"""Genera il dataset HR sintetico e lo esporta in due formati (COPY .sql per Citus, JSONL
per mongoimport). Le righe sono emesse nell'ordine delle colonne della DDL (COPY senza lista
colonne). Gli ID di dipendente e cedolino sono locali al tenant: (tenant_id, id) e' unico,
quindi si parallelizza e si generano lotti incrementali senza contatori condivisi. L'RNG e'
seminato da (seed, tenant_id): stesso tenant -> stessi dati.

    # primo lotto (con cataloghi), 8 processi
    python genera.py --tenant-start 1 --tenant-count 100 --jobs 8 --out generato
    # lotto incrementale (stessi nodi, piu' dati), senza ri-generare i cataloghi
    python genera.py --tenant-start 101 --tenant-count 100 --no-cataloghi --jobs 8 --out generato
"""

import argparse
import multiprocessing
import random
from datetime import date, timedelta

import cataloghi as cat
import codfisc
import nomi
from esportatore import Esportatore

# ladder sintetico dei livelli (il CNEL non espone i minimi tabellari)
LADDER = [
    ("1", "Operaio comune",       1.00),
    ("2", "Operaio qualificato",  1.12),
    ("3", "Impiegato",            1.28),
    ("4", "Impiegato direttivo",  1.50),
    ("5", "Quadro",               1.85),
    ("6", "Dirigente",            2.70),
]

_COMUNI_COD = [c[0] for c in cat.COMUNI]
_ATECO_COD = [a[0] for a in cat.ATECO]
_CCNL_COD = [c[0] for c in cat.CCNL]
_CCNL_MAGG = {c[0]: c[3] for c in cat.CCNL}
_FORME = ["SRL", "SPA", "SNC", "SAS", "SRLS"]
_PAROLE = ["Alfa", "Beta", "Nord", "Sud", "Lombarda", "Adriatica", "Tecno", "Metal",
           "Logistica", "Servizi", "Commerciale", "Industriale", "Costruzioni", "Meccanica"]
_BANCHE = ["Intesa Sanpaolo", "UniCredit", "BPER", "Banco BPM", "Credit Agricole", "MPS"]
_MODALITA = ["Bonifico", "Assegno", "Contanti"]


def _base_ccnl(cod):
    # base sintetica per CCNL, deterministica e riproducibile tra run (no hash randomizzato)
    return random.Random(f"base:{cod}").randint(1300, 1700)


def _livelli(cod):
    base = _base_ccnl(cod)
    return [(liv, round(base * mult, 2)) for liv, _d, mult in LADDER]


def _lg(v):
    return {"$numberLong": str(v)}                # intero a 64 bit per il validator Mongo


def _soldi(rng, a, b):
    return round(rng.uniform(a, b), 2)


def emetti_cataloghi(w):
    for cod, descr in cat.SETTORI:
        w.riga("settore_ccnl", cod, descr)
    for cod, descr, sett, magg in cat.CCNL:
        w.riga("ccnl", cod, descr, sett, magg)
        w.riga("suddivisione", cod, "-", None)
        base = _base_ccnl(cod)
        for liv, dliv, mult in LADDER:
            pb = round(base * mult, 2)
            w.riga("livello", cod, "-", liv, dliv, pb, round(pb / 168, 4))
    for cod, nome_c, prov, _res in cat.COMUNI:
        w.riga("comune", cod, nome_c, prov)
        w.doc("comuni", {"codice_catastale": cod, "nome": nome_c, "provincia": prov})
    for cod, descr in cat.ATECO:
        w.riga("ateco", cod, descr)
        w.doc("ateco", {"codice": cod, "descrizione": descr})
    for cod, descr, categ, segno, ip, iff in cat.TIPI_VOCE:
        w.riga("tipo_voce", cod, descr, categ, segno, ip, iff)
        w.doc("tipi_voce", {"codice": cod, "descrizione": descr, "categoria": categ, "segno": segno})
    for cod, descr, ente in cat.TIPI_CONTRIBUTO:
        w.riga("tipo_contributo", cod, descr, ente)
        w.doc("tipi_contributo", {"codice": cod, "descrizione": descr, "ente": ente})
    for cod, descr, retr, ratei in cat.CAUSALI:
        w.riga("causale_assenza", cod, descr, retr, ratei)
        w.doc("causali", {"codice": cod, "descrizione": descr, "retribuita": retr})


def _cedolino(w, rng, tid, did, cid, anno, mese, c):
    paga = round(c["paga_base"] * c["part_time"] / 100, 2)
    voci = [("0201", None, paga, "C", True, True)]
    ore_str = rng.choice([0, 0, 0, 4, 8, 12])
    if ore_str:
        voci.append(("0301", ore_str, round(ore_str * c["paga_oraria"] * c["magg"], 2), "C", True, True))
    if rng.random() < 0.25:
        voci.append(("0401", None, _soldi(rng, 150, 900), "C", True, True))
    if rng.random() < 0.20:
        voci.append(("0411", None, _soldi(rng, 50, 300), "C", False, False))
    if rng.random() < 0.30:
        voci.append(("9101", None, _soldi(rng, 8, 25), "T", False, False))

    competenze = round(sum(v[2] for v in voci if v[3] == "C"), 2)
    imp_prev = round(sum(v[2] for v in voci if v[3] == "C" and v[4]), 2)
    imp_fisc_lordo = sum(v[2] for v in voci if v[3] == "C" and v[5])
    q_dip = round(imp_prev * 0.0919, 2)
    q_ditta = round(imp_prev * 0.2381, 2)
    imp_fisc = round(imp_fisc_lordo - q_dip, 2)
    irpef_lorda = round(imp_fisc * (0.23 if imp_fisc * 12 <= 28000 else 0.30), 2)
    detrazioni = round(min(200, imp_fisc * 0.10), 2)
    irpef_netta = max(0.0, round(irpef_lorda - detrazioni, 2))
    add_reg = round(imp_fisc * 0.0173, 2)
    add_com = round(imp_fisc * 0.0080, 2)
    trattenute = round(q_dip + irpef_netta + add_reg + add_com + sum(v[2] for v in voci if v[3] == "T"), 2)
    netto = round(competenze - trattenute, 2)
    costo_azienda = round(competenze + q_ditta, 2)
    tfr_quota = round(competenze / 13.5, 2)
    dt = date(anno, mese, 27).isoformat()

    w.riga("cedolino", tid, cid, did, anno, mese, dt, competenze, trattenute, netto, imp_prev,
           imp_fisc, irpef_lorda, irpef_netta, detrazioni, costo_azienda, 160.0, float(ore_str),
           tfr_quota, _soldi(rng, 0, 30), _soldi(rng, 0, 5000))
    for i, v in enumerate(voci):
        w.riga("voce_cedolino", tid, cid, i + 1, v[0], v[1], v[2], 0, None)
    ratei = [("FERIE", 2.16, _soldi(rng, 0, 2)), ("ROL", 0.83, _soldi(rng, 0, 1))]
    for r in ratei:
        w.riga("rateo", tid, cid, r[0], r[1], r[2], round(r[1] - r[2], 2))
    w.riga("contributo", tid, cid, "INPS_FPLD", imp_prev, 0.0919, q_dip, q_ditta)
    w.riga("addizionale", tid, cid, "REGIONALE", imp_fisc, 0.0173, add_reg)
    w.riga("addizionale", tid, cid, "COMUNALE", imp_fisc, 0.0080, add_com)

    giorni_doc = []
    d = date(anno, mese, 1)
    while d.month == mese:
        if d.weekday() < 5:
            iso = d.isoformat()
            if rng.random() < 0.05:
                caus = rng.choice(["FE", "MA", "PR"])
                w.riga("giorno", tid, cid, iso, "assenza", 8.0, 0.0, 0.0)
                w.riga("assenza", tid, cid, iso, caus, 8.0)
                giorni_doc.append({"data": iso, "tipo_giorno": "assenza", "ore_lavorate": 0.0,
                                   "timbrature": [], "assenze": [{"causale": caus, "ore": 8.0}]})
            else:
                w.riga("giorno", tid, cid, iso, "lavorativo", 8.0, 8.0, 0.0)
                w.riga("timbratura", tid, cid, iso, 1, "08:00", "12:00")
                w.riga("timbratura", tid, cid, iso, 2, "13:00", "17:00")
                giorni_doc.append({"data": iso, "tipo_giorno": "lavorativo", "ore_lavorate": 8.0,
                                   "timbrature": [{"progressivo": 1, "ora_entrata": "08:00", "ora_uscita": "12:00"},
                                                  {"progressivo": 2, "ora_entrata": "13:00", "ora_uscita": "17:00"}],
                                   "assenze": []})
        d += timedelta(days=1)

    w.doc("cedolini", {
        "tenant_id": _lg(tid), "cedolino_id": _lg(cid), "dipendente_id": _lg(did),
        "anno": anno, "mese": mese, "data_elaborazione": dt,
        "dipendente": {"sesso": c["sesso"], "livello": c["livello"], "ccnl": c["ccnl"], "cdc": c["cdc"]},
        "totali": {"competenze": competenze, "trattenute": trattenute, "netto": netto,
                   "imponibile_prev": imp_prev, "imponibile_fisc": imp_fisc,
                   "irpef_netta": irpef_netta, "costo_azienda": costo_azienda},
        "voci": [{"riga": i + 1, "tipo": v[0], "quantita": v[1], "importo": v[2], "segno": v[3]}
                 for i, v in enumerate(voci)],
        "ratei": [{"tipo": r[0], "spettante": r[1], "goduto": r[2], "residuo": round(r[1] - r[2], 2)} for r in ratei],
        "contributi": [{"tipo": "INPS_FPLD", "imponibile": imp_prev, "aliquota": 0.0919,
                        "quota_dipendente": q_dip, "quota_ditta": q_ditta}],
        "addizionali": [{"tipo": "REGIONALE", "imponibile": imp_fisc, "aliquota": 0.0173, "importo": add_reg},
                        {"tipo": "COMUNALE", "imponibile": imp_fisc, "aliquota": 0.0080, "importo": add_com}],
        "giorni": giorni_doc,
    })


def genera_tenant(w, tid, dip_min, dip_max, anno, mesi, seed):
    rng = random.Random(f"{seed}:{tid}")
    tipo = "G" if rng.random() < 0.8 else "F"
    cf_ditta = str(rng.randint(10**10, 10**11)) if tipo == "G" else None
    ditta_doc = {"tenant_id": _lg(tid), "tipo": tipo, "indirizzi": [], "centri_di_costo": [],
                 "unita": [], "ateco": [], "ccnl": []}

    if tipo == "F":
        sx = rng.choice("MF")
        nm = rng.choice(nomi.NOMI_M if sx == "M" else nomi.NOMI_F)
        cog = rng.choice(nomi.COGNOMI)
        nasc = date(rng.randint(1955, 1990), rng.randint(1, 12), rng.randint(1, 28))
        cn = rng.choice(_COMUNI_COD)
        cf_ditta = codfisc.codice_fiscale(cog, nm, sx, nasc, cn)
        w.riga("persona_fisica", tid, cog, nm, sx, nasc.isoformat(), f"Ditta {cog}", cn)
        ditta_doc["persona"] = {"cognome": cog, "nome": nm, "sesso": sx}
    else:
        rs = f"{rng.choice(_PAROLE)} {rng.choice(_PAROLE)} {rng.choice(_FORME)}"
        w.riga("persona_giuridica", tid, rs, rng.choice(_FORME))
        ditta_doc["persona"] = {"ragione_sociale": rs}

    w.riga("ditta", tid, tipo, cf_ditta, str(rng.randint(10**10, 10**11)),
           f"pec{tid}@pec.it", f"info{tid}@azienda.it",
           f"0{rng.randint(2,9)}{rng.randint(1000000,9999999)}",
           date(rng.randint(1980, 2015), rng.randint(1, 12), rng.randint(1, 28)).isoformat())

    cm = rng.choice(_COMUNI_COD)
    w.riga("indirizzo", tid, 1, "LEGALE", f"Via Roma {rng.randint(1,200)}", str(rng.randint(1,200)),
           f"{rng.randint(10,98)}100", cm)
    ditta_doc["indirizzi"].append({"ruolo": "LEGALE", "comune": cm})

    centri = list(range(1, rng.randint(1, 5) + 1))
    for c in centri:
        w.riga("centro_di_costo", tid, c, f"CDC{c:02d}", f"Centro di costo {c}")
        ditta_doc["centri_di_costo"].append({"cdc_id": c, "codice": f"CDC{c:02d}"})

    atec = rng.sample(_ATECO_COD, k=rng.randint(1, 3))
    for a in atec:
        w.riga("ditta_ateco", tid, a)
    ditta_doc["ateco"] = atec

    ccnl_ditta = rng.sample(_CCNL_COD, k=rng.randint(1, 2))
    for cc in ccnl_ditta:
        w.riga("ditta_ccnl", tid, cc)
    ditta_doc["ccnl"] = ccnl_ditta
    w.doc("ditte", ditta_doc)

    for did in range(1, rng.randint(dip_min, dip_max) + 1):
        sx = "F" if rng.random() < 0.45 else "M"
        nm = rng.choice(nomi.NOMI_F if sx == "F" else nomi.NOMI_M)
        cog = rng.choice(nomi.COGNOMI)
        nasc = date(rng.randint(1960, 2004), rng.randint(1, 12), rng.randint(1, 28))
        cn = rng.choice(_COMUNI_COD)
        cf = codfisc.codice_fiscale(cog, nm, sx, nasc, cn)
        cdc = rng.choice(centri)
        w.riga("dipendente", tid, did, cf, f"M{did:06d}", cog, nm, sx, nasc.isoformat(), cn,
               rng.choice(_MODALITA), f"IT{rng.randint(10,99)}X{rng.randint(10**10,10**11)}",
               rng.choice(_BANCHE), cdc)

        cc = rng.choice(ccnl_ditta)
        livs = _livelli(cc)
        idx = rng.randint(0, len(livs) - 1)
        if sx == "F" and idx > 0 and rng.random() < 0.35:      # lieve skew di genere (sintetico)
            idx -= 1
        liv_cod, paga_base = livs[idx]
        pt = rng.choice([100, 100, 100, 80, 50])
        paga_oraria = round(paga_base / 168, 4)
        ral = round(paga_base * 13 * pt / 100, 2)
        w.riga("contratto", tid, did, did, rng.choice(["TI", "TI", "TD"]), "Operaio", "Mansione generica",
               pt, round(40 * pt / 100, 1), ral, paga_oraria,
               date(rng.randint(2015, 2023), rng.randint(1, 12), 1).isoformat(), None, cc, "-", liv_cod)
        w.doc("dipendenti", {"tenant_id": _lg(tid), "dipendente_id": _lg(did), "codice_fiscale": cf,
                             "matricola": f"M{did:06d}", "cognome": cog, "nome": nm, "sesso": sx,
                             "contratti": [{"ccnl": cc, "livello": liv_cod, "tipo_rapporto": "TI",
                                            "ral": ral, "paga_oraria": paga_oraria}]})

        c = {"paga_base": paga_base, "paga_oraria": paga_oraria, "magg": _CCNL_MAGG[cc], "part_time": pt,
             "sesso": sx, "livello": liv_cod, "ccnl": cc, "cdc": cdc}
        for m in range(1, mesi + 1):
            _cedolino(w, rng, tid, did, (did - 1) * mesi + m, anno, m, c)


def _lavora_blocco(arg):
    tids, par, out, idx = arg
    w = Esportatore(out, suffisso=f"_p{idx}")
    for tid in tids:
        genera_tenant(w, tid, par["dip_min"], par["dip_max"], par["anno"], par["mesi"], par["seed"])
    w.chiudi()
    return len(tids)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tenant-start", type=int, default=1)
    ap.add_argument("--tenant-count", type=int, default=5)
    ap.add_argument("--dip-min", type=int, default=30)
    ap.add_argument("--dip-max", type=int, default=80)
    ap.add_argument("--anno", type=int, default=2024)
    ap.add_argument("--mesi", type=int, default=12)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--jobs", type=int, default=multiprocessing.cpu_count())
    ap.add_argument("--no-cataloghi", action="store_true")
    ap.add_argument("--out", default="generato")
    args = ap.parse_args()

    if not args.no_cataloghi:
        w = Esportatore(args.out, suffisso="_cat")
        emetti_cataloghi(w)
        w.chiudi()

    tids = list(range(args.tenant_start, args.tenant_start + args.tenant_count))
    jobs = max(1, min(args.jobs, len(tids)))
    par = {"dip_min": args.dip_min, "dip_max": args.dip_max, "anno": args.anno,
           "mesi": args.mesi, "seed": args.seed}
    blocchi = [(tids[i::jobs], par, args.out, i) for i in range(jobs)]

    with multiprocessing.Pool(jobs) as pool:
        pool.map(_lavora_blocco, blocchi)

    print(f"generati {len(tids)} tenant ({args.tenant_start}..{args.tenant_start + args.tenant_count - 1}) "
          f"in '{args.out}' con {jobs} processi")


if __name__ == "__main__":
    main()
