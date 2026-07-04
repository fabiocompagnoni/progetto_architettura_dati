"""Calcolo del codice fiscale con l'algoritmo ufficiale."""

VOCALI = "AEIOU"
MESI = "ABCDEHLMPRST"  # gennaio..dicembre

_ACCENTI = str.maketrans("ÀÁÈÉÌÍÒÓÙÚ", "AAEEIIOOUU")

_DISPARI = {
    "0": 1, "1": 0, "2": 5, "3": 7, "4": 9, "5": 13, "6": 15, "7": 17, "8": 19, "9": 21,
    "A": 1, "B": 0, "C": 5, "D": 7, "E": 9, "F": 13, "G": 15, "H": 17, "I": 19, "J": 21,
    "K": 2, "L": 4, "M": 18, "N": 20, "O": 11, "P": 3, "Q": 6, "R": 8, "S": 12, "T": 14,
    "U": 16, "V": 10, "W": 22, "X": 25, "Y": 24, "Z": 23,
}


def _pari(c):
    return int(c) if c.isdigit() else ord(c) - ord("A")


def _pulisci(s):
    return "".join(ch for ch in s.upper().translate(_ACCENTI) if ch.isalpha())


def _consonanti(s):
    return "".join(ch for ch in s if ch not in VOCALI)


def _cod_cognome(cognome):
    c = _consonanti(cognome) + "".join(ch for ch in cognome if ch in VOCALI)
    return (c + "XXX")[:3]


def _cod_nome(nome):
    cons = _consonanti(nome)
    if len(cons) >= 4:
        cons = cons[0] + cons[2] + cons[3]
    c = cons + "".join(ch for ch in nome if ch in VOCALI)
    return (c + "XXX")[:3]


def _controllo(quindici):
    tot = sum(_DISPARI[c] if i % 2 == 0 else _pari(c) for i, c in enumerate(quindici))
    return chr(ord("A") + tot % 26)


def codice_fiscale(cognome, nome, sesso, data_nascita, comune_catastale):
    """data_nascita: date; sesso 'M'/'F'; comune_catastale: codice Belfiore (es. E507)."""
    giorno = data_nascita.day + (40 if sesso == "F" else 0)
    cf = (_cod_cognome(_pulisci(cognome)) + _cod_nome(_pulisci(nome)) +
          f"{data_nascita.year % 100:02d}" + MESI[data_nascita.month - 1] +
          f"{giorno:02d}" + comune_catastale.upper())
    return cf + _controllo(cf)