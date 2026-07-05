#!/usr/bin/env python3
"""Genera le figure dei risultati (PDF vettoriali per LaTeX) dai CSV di benchmark.

Uso: python3 benchmark/grafici.py
Le figure finiscono in report/figure/fig-*.pdf. Palette coerente in tutto il report:
blu = Citus, arancio = Mongo (coppia CVD-safe, delta-E 91.9).
"""
import csv
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

# --- stile comune -----------------------------------------------------------
CITUS = "#0072B2"   # blu
MONGO = "#D55E00"   # arancio (vermiglio)
QCOL = ["#0072B2", "#D55E00", "#009E73", "#CC79A7"]  # tinte per figure per-query
GRID = "#d9d9d9"
INK = "#222222"

plt.rcParams.update({
    "font.size": 10,
    "font.family": "serif",
    "axes.edgecolor": "#555555",
    "axes.linewidth": 0.8,
    "axes.labelcolor": INK,
    "text.color": INK,
    "xtick.color": "#555555",
    "ytick.color": "#555555",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.dpi": 120,
})

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "benchmark", "results")
OUT = os.path.join(ROOT, "report", "figure")
os.makedirs(OUT, exist_ok=True)

# etichette leggibili delle query
LBL = {
    "L01_cedolino_singolo": "L01 cedolino singolo",
    "L02_cedolini_ditta_periodo": "L02 cedolini ditta/periodo",
    "L03_costo_lavoro_per_centro": "L03 costo per centro",
    "L04_gender_gap_mediano": "L04 gender gap mediano",
    "L05_topn_retribuzioni": "L05 top-N retribuzioni",
    "L06_assenteismo_per_mese": "L06 assenteismo per mese",
    "L07_straordinari_per_centro": "L07 straordinari per centro",
    "L08_trend_costo_lavoro": "L08 trend costo del lavoro",
    "L09_organico_per_rapporto_livello": "L09 organico per livello",
    "L10_cedolino_completo": "L10 cedolino completo",
    "L11_spesa_per_categoria_azienda": "L11 spesa per categoria",
    "L12_ferie_residue_per_azienda": "L12 ferie residue",
    "L13_riepilogo_assenze_dipendente": "L13 riepilogo assenze",
    "I01_insert_timbratura": "I01 insert timbratura",
    "I03_elabora_cedolino": "I03 elabora cedolino",
    "U01_aggiorna_coordinate_bancarie": "U01 coord. bancarie",
    "U02_licenziamento": "U02 licenziamento",
    "U03_modifica_dato_riferimento": "U03 dato riferimento",
    "U04_update_concorrente": "U04 update concorrente",
}


def read_lat(path, lat_idx, has_header):
    """Ritorna {query: lat_ms} prendendo la prima riga per query (lat identica per nodo)."""
    out = {}
    with open(path) as f:
        rows = list(csv.reader(f))
    if has_header:
        rows = rows[1:]
    for r in rows:
        if not r or not r[0].strip():
            continue
        q = r[0].strip()
        if q in out:
            continue
        try:
            out[q] = float(r[lat_idx])
        except (ValueError, IndexError):
            pass
    return out


def save(fig, name):
    p = os.path.join(OUT, name)
    fig.savefig(p, bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)
    print("  ->", os.path.relpath(p, ROOT))


def style_ax(ax):
    ax.grid(axis="y", color=GRID, linewidth=0.7, zorder=0)
    ax.set_axisbelow(True)


# letture per regime (shape della query, uguale sui due sistemi)
SINGLE_SHARD = {"L01_cedolino_singolo", "L02_cedolini_ditta_periodo",
                "L03_costo_lavoro_per_centro", "L07_straordinari_per_centro",
                "L13_riepilogo_assenze_dipendente"}


def read_queries_sorted(sample):
    """Chiavi delle 13 letture presenti in 'sample', ordinate L01..L13."""
    ks = [k for k in sample if k.startswith("L")]
    return sorted(ks, key=lambda k: int(k[1:3]))


def plot_regimi(ax, xs, data, accent):
    """Traccia tutte le letture: 'accent' per le cross-shard, grigio per le single-shard."""
    from matplotlib.lines import Line2D
    qs = read_queries_sorted(data[xs[0]])
    for q in qs:
        ys = [data[x].get(q, float("nan")) for x in xs]
        if q in SINGLE_SHARD:
            ax.plot(xs, ys, "-", color="#9a9a9a", lw=1.1, alpha=0.8, zorder=2)
        else:
            ax.plot(xs, ys, "-", color=accent, lw=1.3, alpha=0.85, marker="o", ms=3.5, zorder=3)
    handles = [Line2D([], [], color=accent, marker="o", ms=4, lw=1.4, label="cross-shard"),
               Line2D([], [], color="#9a9a9a", lw=1.2, label="single-shard")]
    ax.legend(handles=handles, frameon=False, fontsize=9)


def plot_regimi_labeled(ax, xs, data, accent):
    """Come plot_regimi ma su scala log e con il codice query in coda a ogni linea
    (de-collisione verticale delle etichette), così ogni curva è identificabile."""
    import math
    from matplotlib.lines import Line2D
    qs = read_queries_sorted(data[xs[0]])
    xend = xs[-1]
    ends = []
    for q in qs:
        ys = [data[x].get(q, float("nan")) for x in xs]
        if q in SINGLE_SHARD:
            ax.plot(xs, ys, "-", color="#9a9a9a", lw=1.1, alpha=0.85, zorder=2)
            col = "#7a7a7a"
        else:
            ax.plot(xs, ys, "-o", color=accent, lw=1.3, ms=3.5, alpha=0.9, zorder=3)
            col = accent
        ends.append([q[:3], ys[-1], col])
    ax.set_yscale("log")
    # de-collisione delle etichette in coordinate log
    ends.sort(key=lambda e: e[1])
    logy = [math.log10(e[1]) for e in ends]
    gap = 0.052
    for i in range(1, len(logy)):
        if logy[i] - logy[i - 1] < gap:
            logy[i] = logy[i - 1] + gap
    for (code, yv, col), ly in zip(ends, logy):
        ax.annotate(code, xy=(xend, yv), xytext=(xend + 0.09, 10 ** ly),
                    textcoords="data", va="center", fontsize=6.5, color=col,
                    arrowprops=dict(arrowstyle="-", color=col, lw=0.4, alpha=0.55))
    ax.set_xlim(xs[0], xend + 0.55)
    handles = [Line2D([], [], color=accent, marker="o", ms=4, lw=1.4, label="cross-shard"),
               Line2D([], [], color="#9a9a9a", lw=1.2, label="single-shard")]
    ax.legend(handles=handles, frameon=False, fontsize=9, loc="upper right")


# ---------------------------------------------------------------------------
# 1. Scaling per nodi — confronto Citus vs Mongo su L04 (finding centrale)
# ---------------------------------------------------------------------------
def fig_scaling_nodi_confronto():
    q = "L04_gender_gap_mediano"
    cit = {
        1: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/medie_1_nodo.csv", 12, False),
        2: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/media_2_nodi.csv", 12, False),
        3: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/media_3_nodi.csv", 12, False),
        4: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/media_4_nodi.csv", 12, False),
    }
    mon = {
        1: read_lat(f"{RES}/mongo/letture/scalabilita_4nodi/media_1_nodo.csv", 8, False),
        2: read_lat(f"{RES}/mongo/letture/scalabilita_4nodi/media_2_nodi.csv", 8, False),
        3: read_lat(f"{RES}/mongo/letture/scalabilita_4nodi/media_3_nodi.csv", 8, False),
    }
    cx = sorted(cit); cy = [cit[n][q] for n in cx]
    mx = sorted(mon); my = [mon[n][q] for n in mx]

    fig, ax = plt.subplots(figsize=(6, 3.7))
    style_ax(ax)
    ax.plot(cx, cy, "-o", color=CITUS, lw=2, ms=7, zorder=3, label="Citus")
    ax.plot(mx, my, "-s", color=MONGO, lw=2, ms=7, zorder=3, label="MongoDB")
    ax.set_xlabel("nodi (worker Citus / shard Mongo)")
    ax.set_ylabel("latenza L04 (ms)")
    ax.set_xticks([1, 2, 3, 4])
    ax.set_ylim(0, max(cy) * 1.2)
    ax.legend(frameon=False, loc="center right")
    save(fig, "fig-scaling-nodi-confronto.pdf")


# ---------------------------------------------------------------------------
# 2. Scaling per nodi — Citus, i due regimi (cross-shard vs single-shard)
# ---------------------------------------------------------------------------
def fig_scaling_nodi_citus():
    files = {
        1: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/medie_1_nodo.csv", 12, False),
        2: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/media_2_nodi.csv", 12, False),
        3: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/media_3_nodi.csv", 12, False),
        4: read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/media_4_nodi.csv", 12, False),
    }
    xs = sorted(files)
    fig, ax = plt.subplots(figsize=(6.4, 3.9))
    ax.grid(axis="y", color=GRID, linewidth=0.7, which="both", zorder=0)
    ax.set_axisbelow(True)
    plot_regimi_labeled(ax, xs, files, CITUS)
    ax.set_xlabel("worker")
    ax.set_ylabel("latenza (ms, scala log)")
    ax.set_xticks(xs)
    save(fig, "fig-scaling-nodi-citus.pdf")


# ---------------------------------------------------------------------------
# 3. Scaling per dati — Citus (latenza vs volume, nodi fissi = 4)
# ---------------------------------------------------------------------------
def fig_scaling_dati_citus():
    pts = [(30, f"{RES}/citus/letture/scalabilita_dati_4nodi/media_4_nodi.csv", 12, False)]
    for d in (60, 120, 240, 480):
        pts.append((d, f"{RES}/citus/letture/scalabilita_dati/scala_dati_{d}ditte.csv", 12, True))
    data = {d: read_lat(p, i, h) for d, p, i, h in pts}
    xs = sorted(data)
    fig, ax = plt.subplots(figsize=(6, 3.7))
    style_ax(ax)
    plot_regimi(ax, xs, data, CITUS)
    ax.set_xlabel("ditte (tenant) — 4 nodi")
    ax.set_ylabel("latenza (ms)")
    ax.set_xticks(xs)
    ax.set_ylim(0, None)
    save(fig, "fig-scaling-dati-citus.pdf")


# ---------------------------------------------------------------------------
# 4. Scaling per dati — Mongo (latenza vs volume, 4 shard fissi)
# ---------------------------------------------------------------------------
def fig_scaling_dati_mongo():
    from matplotlib.lines import Line2D
    data = {d: read_lat(f"{RES}/mongo/letture/scalabilita_dati/media_dati_mongo_{d}ditte.csv", 8, False)
            for d in (230, 630, 1430, 2630)}
    xs = sorted(data)
    fig, ax = plt.subplots(figsize=(6.2, 3.9))
    ax.grid(axis="y", color=GRID, linewidth=0.7, which="both", zorder=0)
    ax.set_axisbelow(True)
    qs = read_queries_sorted(data[xs[0]])
    xmax = xs[-1]
    for q in qs:
        ys = [data[x].get(q, float("nan")) for x in xs]
        if q in SINGLE_SHARD:
            ax.plot(xs, ys, "-", color="#9a9a9a", lw=1.1, alpha=0.8, zorder=2)
            continue
        ax.plot(xs, ys, "-o", color=MONGO, lw=1.3, ms=3.5, alpha=0.9, zorder=3)
        # etichetta il codice query in coda alle sole cross-shard
        ax.annotate(q[:3], xy=(xmax, ys[-1]), xytext=(4, 0), textcoords="offset points",
                    va="center", fontsize=6.5, color=MONGO)
    ax.set_yscale("log")
    ax.set_xlabel("ditte (tenant) — 4 shard")
    ax.set_ylabel("latenza (ms, scala log)")
    ax.set_xticks(xs)
    ax.set_xlim(xs[0], xmax * 1.12)
    handles = [Line2D([], [], color=MONGO, marker="o", ms=4, lw=1.4, label="cross-shard"),
               Line2D([], [], color="#9a9a9a", lw=1.2, label="single-shard")]
    ax.legend(handles=handles, frameon=False, fontsize=9, loc="upper left")
    save(fig, "fig-scaling-dati-mongo.pdf")


# ---------------------------------------------------------------------------
# 5. Scritture — confronto latenza per operazione (Citus vs Mongo)
# ---------------------------------------------------------------------------
def fig_scritture():
    cit = read_lat(f"{RES}/citus/scritture/4nodi.csv", 10, True)
    mon = read_lat(f"{RES}/mongo/scritture/risultato_test_scritture.csv", 6, True)
    order = ["U02_licenziamento", "U01_aggiorna_coordinate_bancarie", "U04_update_concorrente",
             "I01_insert_timbratura", "U03_modifica_dato_riferimento", "I03_elabora_cedolino"]
    order = [q for q in order if q in cit and q in mon]
    labels = [LBL[q] for q in order]
    cy = [cit[q] for q in order]
    my = [mon[q] for q in order]

    import numpy as np
    x = np.arange(len(order)); w = 0.38
    fig, ax = plt.subplots(figsize=(6.6, 3.8))
    style_ax(ax)
    b1 = ax.bar(x - w / 2, cy, w, color=CITUS, zorder=3, label="Citus")
    b2 = ax.bar(x + w / 2, my, w, color=MONGO, zorder=3, label="MongoDB")
    ax.bar_label(b1, fmt="%.1f", padding=2, fontsize=7.5, color=CITUS)
    ax.bar_label(b2, fmt="%.1f", padding=2, fontsize=7.5, color=MONGO)
    ax.set_ylabel("latenza (ms/op)")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=25, ha="right", fontsize=8.5)
    ax.set_ylim(0, max(cy + my) * 1.15)
    ax.legend(frameon=False)
    save(fig, "fig-scritture.pdf")


# ---------------------------------------------------------------------------
# 6. Letture assolute a scala base — Citus (4 nodi) vs Mongo (scala log)
# ---------------------------------------------------------------------------
def fig_letture_assolute():
    cit = read_lat(f"{RES}/citus/letture/scalabilita_dati_4nodi/media_4_nodi.csv", 12, False)
    mon = read_lat(f"{RES}/mongo/letture/scalabilita_4nodi/media_1_nodo.csv", 8, False)
    order = [f"L{n:02d}" for n in range(1, 14)]
    keys = [k for k in LBL if k.startswith("L")]
    order_keys = []
    for n in range(1, 14):
        pref = f"L{n:02d}_"
        m = [k for k in keys if k.startswith(pref)]
        if m and m[0] in cit and m[0] in mon:
            order_keys.append(m[0])
    labels = [f"L{int(k[1:3])}" for k in order_keys]
    cy = [cit[k] for k in order_keys]
    my = [mon[k] for k in order_keys]

    import numpy as np
    x = np.arange(len(order_keys)); w = 0.38
    fig, ax = plt.subplots(figsize=(6.6, 3.6))
    ax.grid(axis="y", color=GRID, linewidth=0.7, which="both", zorder=0)
    ax.set_axisbelow(True)
    ax.bar(x - w / 2, cy, w, color=CITUS, zorder=3, label="Citus (4 nodi)")
    ax.bar(x + w / 2, my, w, color=MONGO, zorder=3, label="MongoDB")
    ax.set_yscale("log")
    ax.set_ylabel("latenza (ms, scala log)")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=8.5)
    ax.legend(frameon=False)
    save(fig, "fig-letture-assolute.pdf")


# ---------------------------------------------------------------------------
# 7. Guasti — timeline righe restituite (CP): crollo a 0 durante il down
# ---------------------------------------------------------------------------
def read_fault(path):
    t, righe = [], []
    with open(path) as f:
        for r in csv.DictReader(f):
            try:
                t.append(float(r["t_s"])); righe.append(float(r["righe"]))
            except (ValueError, KeyError):
                pass
    m = max(righe) or 1
    return t, [x / m for x in righe]

def fig_guasti():
    ct, cr = read_fault(f"{RES}/citus/guasti/guasto_L04_gender_gap_mediano_10-0-1-6_162124.csv")
    mt, mr = read_fault(f"{RES}/mongo/guasti/guasto_mongo_L04_gender_gap_mediano_10-0-1-4_211407.csv")

    fig, ax = plt.subplots(figsize=(6.4, 3.5))
    style_ax(ax)
    ax.axvspan(10, 25, color="#f2c9b3", alpha=0.5, zorder=0, label="nodo down")
    ax.plot(ct, cr, "-o", color=CITUS, lw=1.6, ms=4, zorder=3, label="Citus")
    ax.plot(mt, mr, "-s", color=MONGO, lw=1.6, ms=4, zorder=3, label="MongoDB")
    ax.set_xlabel("tempo (s)")
    ax.set_ylabel("righe restituite (norm.)")
    ax.set_ylim(-0.05, 1.15)
    ax.set_xlim(0, max(max(ct), max(mt)))
    ax.legend(frameon=False, loc="center left")
    save(fig, "fig-guasti.pdf")


if __name__ == "__main__":
    print("Genero le figure in report/figure/ ...")
    fig_scaling_nodi_confronto()
    fig_scaling_nodi_citus()
    fig_scaling_dati_citus()
    fig_scaling_dati_mongo()
    fig_scritture()
    fig_letture_assolute()
    fig_guasti()
    print("Fatto.")
