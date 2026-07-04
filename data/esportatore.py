"""Esporta il dataset nei due formati: file .sql con COPY eseguibili con
psql -f e JSONL per mongoimport. Ogni processo scrive file-parte propri (suffisso), così il
parallelo non ha contese di I/O e il caricamento carica tutte le parti."""

import json
import os


class Esportatore:
    def __init__(self, base, suffisso=""):
        self.dir_citus = os.path.join(base, "citus")
        self.dir_mongo = os.path.join(base, "mongo")
        os.makedirs(self.dir_citus, exist_ok=True)
        os.makedirs(self.dir_mongo, exist_ok=True)
        self.suffisso = suffisso
        self._sql = {}
        self._json = {}

    def _f_sql(self, tab):
        f = self._sql.get(tab)
        if f is None:
            f = open(os.path.join(self.dir_citus, f"{tab}{self.suffisso}.sql"), "w", encoding="utf-8")
            f.write(f"COPY {tab} FROM stdin;\n")
            self._sql[tab] = f
        return f

    def _f_json(self, coll):
        f = self._json.get(coll)
        if f is None:
            f = self._json[coll] = open(
                os.path.join(self.dir_mongo, f"{coll}{self.suffisso}.jsonl"), "w", encoding="utf-8")
        return f

    def riga(self, tab, *campi):
        self._f_sql(tab).write("\t".join(_cella(c) for c in campi) + "\n")

    def doc(self, coll, obj):
        self._f_json(coll).write(json.dumps(obj, ensure_ascii=False, default=str) + "\n")

    def chiudi(self):
        for f in self._sql.values():
            f.write("\\.\n")            # fine dati COPY
            f.close()
        for f in self._json.values():
            f.close()


def _cella(v):
    if v is None:
        return r"\N"
    return str(v).replace("\\", "\\\\").replace("\t", " ").replace("\n", " ")